import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;
import 'package:solana/encoder.dart';
import 'package:solana/solana.dart';

import '../core/constants.dart';
import '../models/circle.dart';
import '../models/savings_target.dart';
import 'rpc_service.dart';

/// A built-and-signed `create_circle` transaction, plus the fresh circle
/// account address it targets (needed to show the user and, later, to read
/// the circle back).
class CreateCircleResult {
  const CreateCircleResult({
    required this.transactionBytes,
    required this.circleAddress,
  });

  final List<int> transactionBytes;
  final String circleAddress;
}

/// A built-and-signed `create_savings_target` transaction, plus the fresh
/// account address it targets.
class CreateSavingsTargetResult {
  const CreateSavingsTargetResult({
    required this.transactionBytes,
    required this.savingsTargetAddress,
  });

  final List<int> transactionBytes;
  final String savingsTargetAddress;
}

/// Thrown for an `AnchorService` failure that should surface a message to
/// the user, as opposed to a bug — e.g. no USDC token account yet.
class AnchorException implements Exception {
  AnchorException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Builds instructions for the deployed `ajose` Anchor program and compiles
/// them into transactions ready for [WalletService.signAndSendTransaction].
///
/// There's no Anchor client generator for Dart, so instruction data is
/// encoded by hand here following Borsh + Anchor's own conventions: an
/// 8-byte sighash discriminator (`sha256("global:<ix_name>")[0:8]`) followed
/// by the Borsh-serialized arguments in declaration order, matching
/// `programs/ajose/src/instructions/create_circle.rs` exactly.
class AnchorService {
  AnchorService(this._rpc);

  final RpcService _rpc;

  static final Ed25519HDPublicKey _programId =
      Ed25519HDPublicKey.fromBase58(AppConfig.ajoseProgramId);

  static final Ed25519HDPublicKey _usdcMint =
      Ed25519HDPublicKey.fromBase58(AppConfig.usdcMintDevnet);

  // AppConfig.usdcDecimals is 6; spelled out rather than computed with a
  // pow() so contribution_amount math stays exact integer arithmetic.
  static const int _usdcBaseUnitsPerToken = 1000000;

  /// Builds a `create_circle` transaction. The connected wallet
  /// ([authority]) is the fee payer and circle authority; seat 0 is
  /// reserved for it, every other seat is left open (`None`) for later
  /// holders to claim via `join_circle`, since there's no service yet that
  /// maps an invited contact to their wallet address up front.
  Future<CreateCircleResult> buildCreateCircleTransaction({
    required Ed25519HDPublicKey authority,
    required String name,
    required double contributionAmountUsdc,
    required ContributionFrequency frequency,
    required int memberCount,
    double collateralAmountUsdc = 0,
  }) async {
    final circleKeypair = await Ed25519HDKeyPair.random();

    final contributionAmount =
        (contributionAmountUsdc * _usdcBaseUnitsPerToken).round();
    final collateralAmount = (collateralAmountUsdc * _usdcBaseUnitsPerToken).round();
    final firstRoundDeadline =
        DateTime.now().add(frequency.interval).millisecondsSinceEpoch ~/ 1000;

    final seatReservations = List<Ed25519HDPublicKey?>.filled(memberCount, null);
    seatReservations[0] = authority;

    final instruction = Instruction(
      programId: _programId,
      accounts: [
        AccountMeta.writeable(pubKey: circleKeypair.publicKey, isSigner: true),
        AccountMeta.writeable(pubKey: authority, isSigner: true),
        AccountMeta.readonly(pubKey: _usdcMint, isSigner: false),
        AccountMeta.readonly(pubKey: SystemProgram.id, isSigner: false),
      ],
      data: _encodeCreateCircleArgs(
        name: name,
        contributionAmount: contributionAmount,
        frequency: frequency,
        seatReservations: seatReservations,
        firstRoundDeadline: firstRoundDeadline,
        collateralAmount: collateralAmount,
      ),
    );

    final instructions = [instruction];

    // Collateral enabled: the creator posts their own bond in the same
    // transaction, right after the circle (and their seat 0) exist —
    // same "create then immediately use" pattern as the savings target's
    // optional opening deposit.
    if (collateralAmount > 0) {
      instructions.add(await _buildPostCollateralInstruction(
        circlePubkey: circleKeypair.publicKey,
        member: authority,
      ));
    }

    final blockhash = await _rpc.getLatestBlockhash();
    final message = Message(instructions: instructions);
    final compiledMessage = message.compile(
      recentBlockhash: blockhash,
      feePayer: authority,
    );

    // The circle account is brand new (no seeds/PDA), so Solana requires
    // its own keypair to sign the creation — produced locally and in full
    // right away, since we hold its private key for only this moment. The
    // wallet's own slot is left zeroed for Mobile Wallet Adapter to fill in
    // when it signs and submits; MWA preserves any signatures already
    // present rather than overwriting them.
    final signatures = <Signature>[];
    for (var i = 0; i < compiledMessage.header.numRequiredSignatures; i++) {
      final signerKey = compiledMessage.accountKeys[i];
      if (signerKey == circleKeypair.publicKey) {
        signatures.add(await circleKeypair.sign(compiledMessage.toByteArray()));
      } else {
        signatures.add(Signature(List<int>.filled(64, 0), publicKey: signerKey));
      }
    }

    final signedTx = SignedTx(signatures: signatures, compiledMessage: compiledMessage);

    return CreateCircleResult(
      transactionBytes: signedTx.toByteArray().toList(),
      circleAddress: circleKeypair.publicKey.toBase58(),
    );
  }

  /// Builds a `contribute` transaction: transfers this round's contribution
  /// in USDC from [contributor]'s own associated token account into the
  /// circle's vault (a token account owned by a PDA derived from the circle
  /// itself), and marks their seat paid. Only [contributor] signs — unlike
  /// [buildCreateCircleTransaction], nothing new is being initialized that
  /// needs its own keypair.
  ///
  /// This only ever deposits — nothing is paid back out here. A round's pot
  /// is disbursed once its deadline passes, via [buildSettleRoundTransaction].
  Future<List<int>> buildContributeTransaction({
    required Ed25519HDPublicKey contributor,
    required String circleId,
  }) async {
    final circlePubkey = Ed25519HDPublicKey.fromBase58(circleId);

    final hasUsdcAccount = await _rpc.client.hasAssociatedTokenAccount(
      owner: contributor,
      mint: _usdcMint,
    );
    if (!hasUsdcAccount) {
      throw AnchorException(
        'Your wallet has no USDC token account yet — you need to receive '
        'some devnet USDC before you can contribute.',
      );
    }

    final vaultAuthority = await Ed25519HDPublicKey.findProgramAddress(
      seeds: [utf8.encode('vault'), circlePubkey.bytes],
      programId: _programId,
    );
    final contributorTokenAccount = await findAssociatedTokenAddress(
      owner: contributor,
      mint: _usdcMint,
    );
    final circleVault = await findAssociatedTokenAddress(
      owner: vaultAuthority,
      mint: _usdcMint,
    );

    final instruction = Instruction(
      programId: _programId,
      accounts: [
        AccountMeta.writeable(pubKey: circlePubkey, isSigner: false),
        AccountMeta.writeable(pubKey: contributor, isSigner: true),
        AccountMeta.writeable(pubKey: contributorTokenAccount, isSigner: false),
        AccountMeta.writeable(pubKey: circleVault, isSigner: false),
        AccountMeta.readonly(pubKey: vaultAuthority, isSigner: false),
        AccountMeta.readonly(pubKey: _usdcMint, isSigner: false),
        AccountMeta.readonly(pubKey: TokenProgram.id, isSigner: false),
        AccountMeta.readonly(pubKey: AssociatedTokenAccountProgram.id, isSigner: false),
        AccountMeta.readonly(pubKey: SystemProgram.id, isSigner: false),
      ],
      data: ByteArray(_instructionDiscriminator('contribute')),
    );

    final blockhash = await _rpc.getLatestBlockhash();
    final message = Message(instructions: [instruction]);
    final compiledMessage = message.compile(
      recentBlockhash: blockhash,
      feePayer: contributor,
    );

    // Single signer (the contributor's wallet) — left zeroed for Mobile
    // Wallet Adapter to fill in, same as the simple-transfer path in
    // RpcService.buildTransferTransaction.
    final signatures = List.generate(
      compiledMessage.header.numRequiredSignatures,
      (i) => Signature(List<int>.filled(64, 0), publicKey: compiledMessage.accountKeys[i]),
    );

    final signedTx = SignedTx(signatures: signatures, compiledMessage: compiledMessage);
    return signedTx.toByteArray().toList();
  }

  /// Builds a `settle_round` transaction: once a circle's round deadline has
  /// passed, pays whatever accumulated in its vault to that round's
  /// recipient and opens the next round (or marks the circle complete).
  /// Permissionless — [payer] need not be a circle member, just whichever
  /// wallet happens to notice the round is overdue and is willing to cover
  /// the small fee (see `AutoSettleTicker`, which calls this automatically
  /// while a circle screen is open).
  Future<List<int>> buildSettleRoundTransaction({
    required Ed25519HDPublicKey payer,
    required Circle circle,
  }) async {
    final circlePubkey = Ed25519HDPublicKey.fromBase58(circle.id);

    final vaultAuthority = await Ed25519HDPublicKey.findProgramAddress(
      seeds: [utf8.encode('vault'), circlePubkey.bytes],
      programId: _programId,
    );
    final circleVault = await findAssociatedTokenAddress(
      owner: vaultAuthority,
      mint: _usdcMint,
    );
    final bondAuthority = await Ed25519HDPublicKey.findProgramAddress(
      seeds: [utf8.encode('bond'), circlePubkey.bytes],
      programId: _programId,
    );
    final bondVault = await findAssociatedTokenAddress(
      owner: bondAuthority,
      mint: _usdcMint,
    );
    final recipient = Ed25519HDPublicKey.fromBase58(circle.currentRecipient.pubkey);
    final recipientTokenAccount = await findAssociatedTokenAddress(
      owner: recipient,
      mint: _usdcMint,
    );

    final instruction = Instruction(
      programId: _programId,
      accounts: [
        AccountMeta.writeable(pubKey: circlePubkey, isSigner: false),
        AccountMeta.writeable(pubKey: payer, isSigner: true),
        AccountMeta.writeable(pubKey: circleVault, isSigner: false),
        AccountMeta.readonly(pubKey: vaultAuthority, isSigner: false),
        AccountMeta.writeable(pubKey: bondVault, isSigner: false),
        AccountMeta.readonly(pubKey: bondAuthority, isSigner: false),
        AccountMeta.readonly(pubKey: recipient, isSigner: false),
        AccountMeta.writeable(pubKey: recipientTokenAccount, isSigner: false),
        AccountMeta.readonly(pubKey: _usdcMint, isSigner: false),
        AccountMeta.readonly(pubKey: TokenProgram.id, isSigner: false),
        AccountMeta.readonly(pubKey: AssociatedTokenAccountProgram.id, isSigner: false),
        AccountMeta.readonly(pubKey: SystemProgram.id, isSigner: false),
      ],
      data: ByteArray(_instructionDiscriminator('settle_round')),
    );

    final blockhash = await _rpc.getLatestBlockhash();
    final message = Message(instructions: [instruction]);
    final compiledMessage = message.compile(
      recentBlockhash: blockhash,
      feePayer: payer,
    );

    final signatures = List.generate(
      compiledMessage.header.numRequiredSignatures,
      (i) => Signature(List<int>.filled(64, 0), publicKey: compiledMessage.accountKeys[i]),
    );

    final signedTx = SignedTx(signatures: signatures, compiledMessage: compiledMessage);
    return signedTx.toByteArray().toList();
  }

  /// Builds a `cancel_circle` transaction, closing the circle account and
  /// refunding its rent to [authority] — along with any collateral the
  /// creator posted for their own seat, and the (now-empty) bond vault's
  /// own rent. The program itself rejects this once any member has paid,
  /// or once any round has completed — this is just the instruction call,
  /// not an extra client-side guard.
  Future<List<int>> buildCancelCircleTransaction({
    required Ed25519HDPublicKey authority,
    required String circleId,
  }) async {
    final circlePubkey = Ed25519HDPublicKey.fromBase58(circleId);
    final authorityTokenAccount = await findAssociatedTokenAddress(owner: authority, mint: _usdcMint);
    final bondAuthority = await Ed25519HDPublicKey.findProgramAddress(
      seeds: [utf8.encode('bond'), circlePubkey.bytes],
      programId: _programId,
    );
    final bondVault = await findAssociatedTokenAddress(owner: bondAuthority, mint: _usdcMint);

    final instruction = Instruction(
      programId: _programId,
      accounts: [
        AccountMeta.writeable(pubKey: circlePubkey, isSigner: false),
        AccountMeta.writeable(pubKey: authority, isSigner: true),
        AccountMeta.writeable(pubKey: authorityTokenAccount, isSigner: false),
        AccountMeta.writeable(pubKey: bondVault, isSigner: false),
        AccountMeta.readonly(pubKey: bondAuthority, isSigner: false),
        AccountMeta.readonly(pubKey: _usdcMint, isSigner: false),
        AccountMeta.readonly(pubKey: TokenProgram.id, isSigner: false),
        AccountMeta.readonly(pubKey: AssociatedTokenAccountProgram.id, isSigner: false),
        AccountMeta.readonly(pubKey: SystemProgram.id, isSigner: false),
      ],
      data: ByteArray(_instructionDiscriminator('cancel_circle')),
    );

    final blockhash = await _rpc.getLatestBlockhash();
    final message = Message(instructions: [instruction]);
    final compiledMessage = message.compile(
      recentBlockhash: blockhash,
      feePayer: authority,
    );

    final signatures = List.generate(
      compiledMessage.header.numRequiredSignatures,
      (i) => Signature(List<int>.filled(64, 0), publicKey: compiledMessage.accountKeys[i]),
    );

    final signedTx = SignedTx(signatures: signatures, compiledMessage: compiledMessage);
    return signedTx.toByteArray().toList();
  }

  /// Builds a `join_circle` transaction, claiming the open seat at
  /// [seatIndex] for [joiningWallet] and paying that seat's first
  /// contribution in the same transaction — the program rejects a seat
  /// claim without it, so joining and free-riding (holding a seat without
  /// ever paying in) aren't separable here. Also rejected if that seat is
  /// already filled, the wallet already holds a seat, the index is out of
  /// range, or the current round has already closed.
  Future<List<int>> buildJoinCircleTransaction({
    required Ed25519HDPublicKey joiningWallet,
    required String circleId,
    required int seatIndex,
    double collateralAmountUsdc = 0,
  }) async {
    final circlePubkey = Ed25519HDPublicKey.fromBase58(circleId);

    final hasUsdcAccount = await _rpc.client.hasAssociatedTokenAccount(
      owner: joiningWallet,
      mint: _usdcMint,
    );
    if (!hasUsdcAccount) {
      throw AnchorException(
        'Your wallet has no USDC token account yet — you need to receive '
        'some devnet USDC before you can join this circle.',
      );
    }

    final vaultAuthority = await Ed25519HDPublicKey.findProgramAddress(
      seeds: [utf8.encode('vault'), circlePubkey.bytes],
      programId: _programId,
    );
    final joiningWalletTokenAccount = await findAssociatedTokenAddress(
      owner: joiningWallet,
      mint: _usdcMint,
    );
    final circleVault = await findAssociatedTokenAddress(
      owner: vaultAuthority,
      mint: _usdcMint,
    );

    final instruction = Instruction(
      programId: _programId,
      accounts: [
        AccountMeta.writeable(pubKey: circlePubkey, isSigner: false),
        AccountMeta.writeable(pubKey: joiningWallet, isSigner: true),
        AccountMeta.writeable(pubKey: joiningWalletTokenAccount, isSigner: false),
        AccountMeta.writeable(pubKey: circleVault, isSigner: false),
        AccountMeta.readonly(pubKey: vaultAuthority, isSigner: false),
        AccountMeta.readonly(pubKey: _usdcMint, isSigner: false),
        AccountMeta.readonly(pubKey: TokenProgram.id, isSigner: false),
        AccountMeta.readonly(pubKey: AssociatedTokenAccountProgram.id, isSigner: false),
        AccountMeta.readonly(pubKey: SystemProgram.id, isSigner: false),
      ],
      data: ByteArray.merge([
        ByteArray(_instructionDiscriminator('join_circle')),
        ByteArray.u8(seatIndex),
      ]),
    );

    final instructions = [instruction];

    // Collateral enabled: post the joining member's bond in the same
    // transaction as claiming the seat — one signature covers both.
    if (collateralAmountUsdc > 0) {
      instructions.add(await _buildPostCollateralInstruction(
        circlePubkey: circlePubkey,
        member: joiningWallet,
      ));
    }

    final blockhash = await _rpc.getLatestBlockhash();
    final message = Message(instructions: instructions);
    final compiledMessage = message.compile(
      recentBlockhash: blockhash,
      feePayer: joiningWallet,
    );

    final signatures = List.generate(
      compiledMessage.header.numRequiredSignatures,
      (i) => Signature(List<int>.filled(64, 0), publicKey: compiledMessage.accountKeys[i]),
    );

    final signedTx = SignedTx(signatures: signatures, compiledMessage: compiledMessage);
    return signedTx.toByteArray().toList();
  }

  /// Builds a `create_savings_target` transaction: a new, personal,
  /// time-locked USDC vault for [owner]. If [initialDepositUsdc] is
  /// positive, a `deposit_savings` instruction for that amount rides along
  /// in the same transaction — one signature covers both creating the
  /// target and funding it, rather than two separate approvals.
  Future<CreateSavingsTargetResult> buildCreateSavingsTargetTransaction({
    required Ed25519HDPublicKey owner,
    required String label,
    required DateTime unlockAt,
    double targetAmountUsdc = 0,
    double initialDepositUsdc = 0,
  }) async {
    final savingsKeypair = await Ed25519HDKeyPair.random();
    final targetAmount = (targetAmountUsdc * _usdcBaseUnitsPerToken).round();
    final unlockAtSeconds = unlockAt.millisecondsSinceEpoch ~/ 1000;

    final createInstruction = Instruction(
      programId: _programId,
      accounts: [
        AccountMeta.writeable(pubKey: savingsKeypair.publicKey, isSigner: true),
        AccountMeta.writeable(pubKey: owner, isSigner: true),
        AccountMeta.readonly(pubKey: _usdcMint, isSigner: false),
        AccountMeta.readonly(pubKey: SystemProgram.id, isSigner: false),
      ],
      data: ByteArray.merge([
        ByteArray(_instructionDiscriminator('create_savings_target')),
        _borshString(label),
        ByteArray.i64(unlockAtSeconds),
        ByteArray.u64(targetAmount),
      ]),
    );

    final instructions = [createInstruction];

    if (initialDepositUsdc > 0) {
      final hasUsdcAccount = await _rpc.client.hasAssociatedTokenAccount(
        owner: owner,
        mint: _usdcMint,
      );
      if (!hasUsdcAccount) {
        throw AnchorException(
          'Your wallet has no USDC token account yet — you need to receive '
          'some devnet USDC before you can deposit.',
        );
      }

      final vaultAuthority = await Ed25519HDPublicKey.findProgramAddress(
        seeds: [utf8.encode('savings_vault'), savingsKeypair.publicKey.bytes],
        programId: _programId,
      );
      final ownerTokenAccount = await findAssociatedTokenAddress(owner: owner, mint: _usdcMint);
      final savingsVault = await findAssociatedTokenAddress(owner: vaultAuthority, mint: _usdcMint);
      final depositAmount = (initialDepositUsdc * _usdcBaseUnitsPerToken).round();

      instructions.add(Instruction(
        programId: _programId,
        accounts: [
          AccountMeta.readonly(pubKey: savingsKeypair.publicKey, isSigner: false),
          AccountMeta.writeable(pubKey: owner, isSigner: true),
          AccountMeta.writeable(pubKey: ownerTokenAccount, isSigner: false),
          AccountMeta.writeable(pubKey: savingsVault, isSigner: false),
          AccountMeta.readonly(pubKey: vaultAuthority, isSigner: false),
          AccountMeta.readonly(pubKey: _usdcMint, isSigner: false),
          AccountMeta.readonly(pubKey: TokenProgram.id, isSigner: false),
          AccountMeta.readonly(pubKey: AssociatedTokenAccountProgram.id, isSigner: false),
          AccountMeta.readonly(pubKey: SystemProgram.id, isSigner: false),
        ],
        data: ByteArray.merge([
          ByteArray(_instructionDiscriminator('deposit_savings')),
          ByteArray.u64(depositAmount),
        ]),
      ));
    }

    final blockhash = await _rpc.getLatestBlockhash();
    final message = Message(instructions: instructions);
    final compiledMessage = message.compile(
      recentBlockhash: blockhash,
      feePayer: owner,
    );

    // Same two-signer pattern as buildCreateCircleTransaction: the fresh
    // savings-target keypair signs right away locally, the wallet's own
    // slot is left zeroed for Mobile Wallet Adapter to fill in.
    final signatures = <Signature>[];
    for (var i = 0; i < compiledMessage.header.numRequiredSignatures; i++) {
      final signerKey = compiledMessage.accountKeys[i];
      if (signerKey == savingsKeypair.publicKey) {
        signatures.add(await savingsKeypair.sign(compiledMessage.toByteArray()));
      } else {
        signatures.add(Signature(List<int>.filled(64, 0), publicKey: signerKey));
      }
    }

    final signedTx = SignedTx(signatures: signatures, compiledMessage: compiledMessage);

    return CreateSavingsTargetResult(
      transactionBytes: signedTx.toByteArray().toList(),
      savingsTargetAddress: savingsKeypair.publicKey.toBase58(),
    );
  }

  /// Builds a `deposit_savings` transaction, adding [amountUsdc] to an
  /// existing savings target's vault. Allowed anytime — unlike a
  /// withdrawal, a deposit never needs to wait on the target's unlock date.
  Future<List<int>> buildDepositSavingsTransaction({
    required Ed25519HDPublicKey owner,
    required SavingsTarget savingsTarget,
    required double amountUsdc,
  }) async {
    final hasUsdcAccount = await _rpc.client.hasAssociatedTokenAccount(
      owner: owner,
      mint: _usdcMint,
    );
    if (!hasUsdcAccount) {
      throw AnchorException(
        'Your wallet has no USDC token account yet — you need to receive '
        'some devnet USDC before you can deposit.',
      );
    }

    final savingsTargetPubkey = Ed25519HDPublicKey.fromBase58(savingsTarget.id);
    final vaultAuthority = await Ed25519HDPublicKey.findProgramAddress(
      seeds: [utf8.encode('savings_vault'), savingsTargetPubkey.bytes],
      programId: _programId,
    );
    final ownerTokenAccount = await findAssociatedTokenAddress(owner: owner, mint: _usdcMint);
    final savingsVault = await findAssociatedTokenAddress(owner: vaultAuthority, mint: _usdcMint);
    final amount = (amountUsdc * _usdcBaseUnitsPerToken).round();

    final instruction = Instruction(
      programId: _programId,
      accounts: [
        AccountMeta.readonly(pubKey: savingsTargetPubkey, isSigner: false),
        AccountMeta.writeable(pubKey: owner, isSigner: true),
        AccountMeta.writeable(pubKey: ownerTokenAccount, isSigner: false),
        AccountMeta.writeable(pubKey: savingsVault, isSigner: false),
        AccountMeta.readonly(pubKey: vaultAuthority, isSigner: false),
        AccountMeta.readonly(pubKey: _usdcMint, isSigner: false),
        AccountMeta.readonly(pubKey: TokenProgram.id, isSigner: false),
        AccountMeta.readonly(pubKey: AssociatedTokenAccountProgram.id, isSigner: false),
        AccountMeta.readonly(pubKey: SystemProgram.id, isSigner: false),
      ],
      data: ByteArray.merge([
        ByteArray(_instructionDiscriminator('deposit_savings')),
        ByteArray.u64(amount),
      ]),
    );

    final blockhash = await _rpc.getLatestBlockhash();
    final message = Message(instructions: [instruction]);
    final compiledMessage = message.compile(
      recentBlockhash: blockhash,
      feePayer: owner,
    );

    final signatures = List.generate(
      compiledMessage.header.numRequiredSignatures,
      (i) => Signature(List<int>.filled(64, 0), publicKey: compiledMessage.accountKeys[i]),
    );

    final signedTx = SignedTx(signatures: signatures, compiledMessage: compiledMessage);
    return signedTx.toByteArray().toList();
  }

  /// Builds a `withdraw_savings` transaction: pulls a savings target's full
  /// balance back to [owner] and closes the target out, refunding its rent
  /// too. The program itself rejects this before the target's unlock date —
  /// this is just the (argument-free) instruction call, not an extra
  /// client-side guard.
  Future<List<int>> buildWithdrawSavingsTransaction({
    required Ed25519HDPublicKey owner,
    required SavingsTarget savingsTarget,
  }) async {
    final savingsTargetPubkey = Ed25519HDPublicKey.fromBase58(savingsTarget.id);
    final vaultAuthority = await Ed25519HDPublicKey.findProgramAddress(
      seeds: [utf8.encode('savings_vault'), savingsTargetPubkey.bytes],
      programId: _programId,
    );
    final ownerTokenAccount = await findAssociatedTokenAddress(owner: owner, mint: _usdcMint);
    final savingsVault = await findAssociatedTokenAddress(owner: vaultAuthority, mint: _usdcMint);

    final instruction = Instruction(
      programId: _programId,
      accounts: [
        AccountMeta.writeable(pubKey: savingsTargetPubkey, isSigner: false),
        AccountMeta.writeable(pubKey: owner, isSigner: true),
        AccountMeta.writeable(pubKey: ownerTokenAccount, isSigner: false),
        AccountMeta.writeable(pubKey: savingsVault, isSigner: false),
        AccountMeta.writeable(pubKey: vaultAuthority, isSigner: false),
        AccountMeta.readonly(pubKey: _usdcMint, isSigner: false),
        AccountMeta.readonly(pubKey: TokenProgram.id, isSigner: false),
      ],
      data: ByteArray(_instructionDiscriminator('withdraw_savings')),
    );

    final blockhash = await _rpc.getLatestBlockhash();
    final message = Message(instructions: [instruction]);
    final compiledMessage = message.compile(
      recentBlockhash: blockhash,
      feePayer: owner,
    );

    final signatures = List.generate(
      compiledMessage.header.numRequiredSignatures,
      (i) => Signature(List<int>.filled(64, 0), publicKey: compiledMessage.accountKeys[i]),
    );

    final signedTx = SignedTx(signatures: signatures, compiledMessage: compiledMessage);
    return signedTx.toByteArray().toList();
  }

  /// Builds the `post_collateral` instruction for [member] on [circlePubkey]
  /// — shared by [buildCreateCircleTransaction] (the creator's own bond,
  /// bundled right after `create_circle`) and [buildJoinCircleTransaction]
  /// (a joining member's bond, bundled right after `join_circle`). The
  /// amount isn't passed in — the program reads it straight off the
  /// circle's own `collateral_amount`, so caller and program can't disagree
  /// on how much is owed.
  Future<Instruction> _buildPostCollateralInstruction({
    required Ed25519HDPublicKey circlePubkey,
    required Ed25519HDPublicKey member,
  }) async {
    final hasUsdcAccount = await _rpc.client.hasAssociatedTokenAccount(
      owner: member,
      mint: _usdcMint,
    );
    if (!hasUsdcAccount) {
      throw AnchorException(
        'Your wallet has no USDC token account yet — you need to receive '
        'some devnet USDC before you can post collateral.',
      );
    }

    final bondAuthority = await Ed25519HDPublicKey.findProgramAddress(
      seeds: [utf8.encode('bond'), circlePubkey.bytes],
      programId: _programId,
    );
    final memberTokenAccount = await findAssociatedTokenAddress(owner: member, mint: _usdcMint);
    final bondVault = await findAssociatedTokenAddress(owner: bondAuthority, mint: _usdcMint);

    return Instruction(
      programId: _programId,
      accounts: [
        AccountMeta.writeable(pubKey: circlePubkey, isSigner: false),
        AccountMeta.writeable(pubKey: member, isSigner: true),
        AccountMeta.writeable(pubKey: memberTokenAccount, isSigner: false),
        AccountMeta.writeable(pubKey: bondVault, isSigner: false),
        AccountMeta.readonly(pubKey: bondAuthority, isSigner: false),
        AccountMeta.readonly(pubKey: _usdcMint, isSigner: false),
        AccountMeta.readonly(pubKey: TokenProgram.id, isSigner: false),
        AccountMeta.readonly(pubKey: AssociatedTokenAccountProgram.id, isSigner: false),
        AccountMeta.readonly(pubKey: SystemProgram.id, isSigner: false),
      ],
      data: ByteArray(_instructionDiscriminator('post_collateral')),
    );
  }

  /// Builds a `claim_collateral` transaction: returns [member]'s remaining
  /// bond once the circle has finished its full rotation. The program
  /// rejects this earlier, or a second time for the same seat — this is
  /// just the instruction call.
  Future<List<int>> buildClaimCollateralTransaction({
    required Ed25519HDPublicKey member,
    required Circle circle,
  }) async {
    final circlePubkey = Ed25519HDPublicKey.fromBase58(circle.id);
    final bondAuthority = await Ed25519HDPublicKey.findProgramAddress(
      seeds: [utf8.encode('bond'), circlePubkey.bytes],
      programId: _programId,
    );
    final memberTokenAccount = await findAssociatedTokenAddress(owner: member, mint: _usdcMint);
    final bondVault = await findAssociatedTokenAddress(owner: bondAuthority, mint: _usdcMint);

    final instruction = Instruction(
      programId: _programId,
      accounts: [
        AccountMeta.writeable(pubKey: circlePubkey, isSigner: false),
        AccountMeta.readonly(pubKey: member, isSigner: true),
        AccountMeta.writeable(pubKey: memberTokenAccount, isSigner: false),
        AccountMeta.writeable(pubKey: bondVault, isSigner: false),
        AccountMeta.readonly(pubKey: bondAuthority, isSigner: false),
        AccountMeta.readonly(pubKey: _usdcMint, isSigner: false),
        AccountMeta.readonly(pubKey: TokenProgram.id, isSigner: false),
      ],
      data: ByteArray(_instructionDiscriminator('claim_collateral')),
    );

    final blockhash = await _rpc.getLatestBlockhash();
    final message = Message(instructions: [instruction]);
    final compiledMessage = message.compile(
      recentBlockhash: blockhash,
      feePayer: member,
    );

    final signatures = List.generate(
      compiledMessage.header.numRequiredSignatures,
      (i) => Signature(List<int>.filled(64, 0), publicKey: compiledMessage.accountKeys[i]),
    );

    final signedTx = SignedTx(signatures: signatures, compiledMessage: compiledMessage);
    return signedTx.toByteArray().toList();
  }

  ByteArray _encodeCreateCircleArgs({
    required String name,
    required int contributionAmount,
    required ContributionFrequency frequency,
    required List<Ed25519HDPublicKey?> seatReservations,
    required int firstRoundDeadline,
    required int collateralAmount,
  }) {
    return ByteArray.merge([
      ByteArray(_instructionDiscriminator('create_circle')),
      _borshString(name),
      ByteArray.u64(contributionAmount),
      ByteArray.u8(frequency.index),
      _borshOptionPubkeyVec(seatReservations),
      ByteArray.i64(firstRoundDeadline),
      ByteArray.u64(collateralAmount),
    ]);
  }

  static List<int> _instructionDiscriminator(String instructionName) {
    final hash = crypto.sha256.convert(utf8.encode('global:$instructionName'));
    return hash.bytes.sublist(0, 8);
  }

  /// Borsh's `String`: u32 byte-length prefix + raw utf8 bytes. Not the
  /// same as [ByteArray.fromString], which this package uses for a
  /// different (u64-length-prefixed) on-chain convention.
  static ByteArray _borshString(String value) {
    final bytes = utf8.encode(value);
    return ByteArray.merge([ByteArray.u32(bytes.length), ByteArray(bytes)]);
  }

  /// Borsh's `Vec<Option<Pubkey>>`: u32 length prefix, then per element a
  /// 1-byte None(0)/Some(1) tag followed by the 32-byte pubkey when present.
  static ByteArray _borshOptionPubkeyVec(List<Ed25519HDPublicKey?> items) {
    final parts = <ByteArray>[ByteArray.u32(items.length)];
    for (final item in items) {
      if (item == null) {
        parts.add(ByteArray.u8(0));
      } else {
        parts.add(ByteArray.u8(1));
        parts.add(item.toByteArray());
      }
    }
    return ByteArray.merge(parts);
  }
}
