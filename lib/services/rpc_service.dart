import 'package:solana/dto.dart';
import 'package:solana/encoder.dart';
import 'package:solana/solana.dart';

import '../core/constants.dart';

/// SOL balance plus, optionally, the devnet USDC balance for one wallet —
/// what the Home screen needs to prove RPC + wallet plumbing actually
/// works end to end.
class WalletBalances {
  const WalletBalances({required this.solLamports, required this.usdc});

  final int solLamports;

  /// Null when the wallet has no USDC associated token account yet (a
  /// brand-new devnet wallet, before it's ever received USDC) — treated as
  /// zero everywhere it's displayed, but kept distinct so the UI can hint
  /// "no USDC account yet" if useful later.
  final double? usdc;

  double get sol => solLamports / lamportsPerSol;

  double get usdcOrZero => usdc ?? 0;
}

/// Wraps the `solana` Dart RPC client, pointed at [AppConfig.cluster]. This
/// is the one place in the app that talks to the Solana JSON-RPC endpoint
/// directly — everything else (balances, and later, circle account reads)
/// goes through here.
class RpcService {
  RpcService({SolanaClient? client})
      : client = client ??
            SolanaClient(
              rpcUrl: Uri.parse(AppConfig.cluster.rpcUrl),
              websocketUrl: Uri.parse(AppConfig.cluster.websocketUrl),
            );

  final SolanaClient client;

  Future<int> getSolBalanceLamports(Ed25519HDPublicKey pubkey) {
    return client.rpcClient.getBalance(pubkey.toBase58()).value;
  }

  /// Devnet USDC balance, or null if the wallet has no associated token
  /// account for the USDC mint yet (RPC throws in that case — a brand new
  /// wallet that has never received USDC — so it's treated as "no balance"
  /// rather than an error).
  Future<double?> getUsdcBalance(Ed25519HDPublicKey pubkey) async {
    try {
      final mint = Ed25519HDPublicKey.fromBase58(AppConfig.usdcMintDevnet);
      final amount = await client.getTokenBalance(owner: pubkey, mint: mint);
      final uiAmount = amount.uiAmountString;
      if (uiAmount != null) return double.tryParse(uiAmount);
      // Fall back to computing from the raw integer amount if the RPC
      // response omitted uiAmountString.
      final raw = int.tryParse(amount.amount);
      if (raw == null) return null;
      return raw / _pow10(amount.decimals);
    } catch (_) {
      return null;
    }
  }

  Future<WalletBalances> getBalances(Ed25519HDPublicKey pubkey) async {
    final results = await Future.wait([
      getSolBalanceLamports(pubkey),
      getUsdcBalance(pubkey),
    ]);
    return WalletBalances(
      solLamports: results[0] as int,
      usdc: results[1] as double?,
    );
  }

  /// Raw account bytes for every account owned by [programId]. Used to read
  /// back Anchor program state (e.g. `Circle` accounts) client-side, since
  /// there's no generated Dart Anchor client to decode them for us.
  ///
  /// Reads at [Commitment.confirmed] rather than the client's default
  /// [Commitment.finalized] — a circle the user just created should show up
  /// in a couple of seconds, not the ~15-20s finalization can take.
  Future<List<ProgramAccount>> getProgramAccountsRaw(String programId) {
    return client.rpcClient.getProgramAccounts(
      programId,
      encoding: Encoding.base64,
      commitment: Commitment.confirmed,
    );
  }

  /// Raw bytes for a single account, or null if it doesn't exist. See
  /// [getProgramAccountsRaw] for why this reads at [Commitment.confirmed].
  Future<List<int>?> getAccountDataRaw(String pubkey) async {
    final result = await client.rpcClient.getAccountInfo(
      pubkey,
      encoding: Encoding.base64,
      commitment: Commitment.confirmed,
    );
    final data = result.value?.data;
    return data is BinaryAccountData ? data.data : null;
  }

  Future<String> getLatestBlockhash() async {
    final response = await client.rpcClient.getLatestBlockhash();
    return response.value.blockhash;
  }

  Future<void> waitForSignatureStatus(String signature) async {
    await client.waitForSignatureStatus(
      signature,
      status: Commitment.confirmed,
    );
  }

  List<int> buildTransferTransaction({
    required Ed25519HDPublicKey from,
    required Ed25519HDPublicKey to,
    required int lamports,
    required String recentBlockhash,
  }) {
    final instruction = SystemInstruction.transfer(
      fundingAccount: from,
      recipientAccount: to,
      lamports: lamports,
    );

    final message = Message(instructions: [instruction]);
    final compiledMessage = message.compile(
      recentBlockhash: recentBlockhash,
      feePayer: from,
    );

    final zeroSignatures = List.generate(
      compiledMessage.header.numRequiredSignatures,
      (i) => Signature(
        List<int>.filled(64, 0),
        publicKey: compiledMessage.accountKeys[i],
      ),
    );

    final signedTx = SignedTx(
      signatures: zeroSignatures,
      compiledMessage: compiledMessage,
    );

    return signedTx.toByteArray().toList();
  }

  static double _pow10(int exponent) {
    var result = 1.0;
    for (var i = 0; i < exponent; i++) {
      result *= 10;
    }
    return result;
  }
}
