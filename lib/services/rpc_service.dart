import 'package:solana/dto.dart';
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

  static double _pow10(int exponent) {
    var result = 1.0;
    for (var i = 0; i < exponent; i++) {
      result *= 10;
    }
    return result;
  }
}
