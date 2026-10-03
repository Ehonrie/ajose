import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;
import 'package:solana/encoder.dart';
import 'package:solana/solana.dart';

import '../core/constants.dart';
import '../models/circle.dart';
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
  }) async {
    final circleKeypair = await Ed25519HDKeyPair.random();

    final contributionAmount =
        (contributionAmountUsdc * _usdcBaseUnitsPerToken).round();
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
      ),
    );

    final blockhash = await _rpc.getLatestBlockhash();
    final message = Message(instructions: [instruction]);
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

  /// Builds a `cancel_circle` transaction, closing the circle account and
  /// refunding its rent to [authority]. The program itself rejects this
  /// once any member has paid — this is just the (argument-free)
  /// instruction call, not an extra client-side guard.
  Future<List<int>> buildCancelCircleTransaction({
    required Ed25519HDPublicKey authority,
    required String circleId,
  }) async {
    final circlePubkey = Ed25519HDPublicKey.fromBase58(circleId);

    final instruction = Instruction(
      programId: _programId,
      accounts: [
        AccountMeta.writeable(pubKey: circlePubkey, isSigner: false),
        AccountMeta.writeable(pubKey: authority, isSigner: true),
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

  ByteArray _encodeCreateCircleArgs({
    required String name,
    required int contributionAmount,
    required ContributionFrequency frequency,
    required List<Ed25519HDPublicKey?> seatReservations,
    required int firstRoundDeadline,
  }) {
    return ByteArray.merge([
      ByteArray(_instructionDiscriminator('create_circle')),
      _borshString(name),
      ByteArray.u64(contributionAmount),
      ByteArray.u8(frequency.index),
      _borshOptionPubkeyVec(seatReservations),
      ByteArray.i64(firstRoundDeadline),
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
