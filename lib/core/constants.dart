/// App-wide configuration: active Solana cluster, dapp identity (used by
/// Mobile Wallet Adapter's `authorize` call), and token addresses.
///
/// Everything that should change when moving from devnet to mainnet-beta
/// lives here, in one place — nothing else in the app should hardcode a
/// cluster URL or mint address.
library;

/// A Solana cluster the app can talk to, bundling the RPC/websocket
/// endpoints together with the cluster identifier MWA expects.
enum SolanaCluster {
  devnet(
    label: 'Devnet',
    mwaClusterName: 'devnet',
    rpcUrl: 'https://api.devnet.solana.com',
    websocketUrl: 'wss://api.devnet.solana.com',
  ),
  testnet(
    label: 'Testnet',
    mwaClusterName: 'testnet',
    rpcUrl: 'https://api.testnet.solana.com',
    websocketUrl: 'wss://api.testnet.solana.com',
  ),
  mainnetBeta(
    label: 'Mainnet Beta',
    mwaClusterName: 'mainnet-beta',
    rpcUrl: 'https://api.mainnet-beta.solana.com',
    websocketUrl: 'wss://api.mainnet-beta.solana.com',
  );

  const SolanaCluster({
    required this.label,
    required this.mwaClusterName,
    required this.rpcUrl,
    required this.websocketUrl,
  });

  /// Human-readable name, e.g. for a debug banner.
  final String label;

  /// The exact string MWA's `authorize`/`reauthorize` calls expect.
  final String mwaClusterName;

  final String rpcUrl;
  final String websocketUrl;
}

class AppConfig {
  AppConfig._();

  /// Single switch for which cluster the whole app targets. This build
  /// phase is devnet-only per the project brief; flip this (and nothing
  /// else) to move to testnet/mainnet-beta later.
  static const SolanaCluster cluster = SolanaCluster.devnet;

  // --- Dapp identity, sent to the wallet app during MWA authorize() ---
  static final Uri identityUri = Uri.parse('https://ajose.app');
  static final Uri iconUri = Uri.parse('favicon.ico');
  static const String identityName = 'Ajose';

  // --- Devnet USDC ---
  // Circle's official devnet USDC-Dev mint (mintable via the devnet USDC
  // faucet). Swap for the mainnet USDC mint
  // (EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v) when moving clusters.
  static const String usdcMintDevnet =
      '4zMMC9srt5Ri5X14GAgXhaHii3GnPAEERYPJgZJDncDU';
  static const int usdcDecimals = 6;

  // --- Secure storage keys for the persisted MWA session ---
  static const String storageKeyAuthToken = 'ajose.mwa.auth_token';
  static const String storageKeyPublicKey = 'ajose.mwa.public_key';
  static const String storageKeyAccountLabel = 'ajose.mwa.account_label';
  static const String storageKeyWalletUriBase = 'ajose.mwa.wallet_uri_base';
}
