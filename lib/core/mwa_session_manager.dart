import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:solana/solana.dart';

import 'constants.dart';

/// An active Mobile Wallet Adapter authorization: the wallet's public key
/// plus the auth token that lets us skip the connect-approval UI on future
/// calls (via `reauthorize`), and the wallet's own deep-link base (used to
/// route association intents straight back to the same wallet app instead
/// of showing the wallet picker every time).
class WalletSession {
  const WalletSession({
    required this.authToken,
    required this.publicKey,
    this.accountLabel,
    this.walletUriBase,
  });

  final String authToken;
  final Ed25519HDPublicKey publicKey;
  final String? accountLabel;
  final Uri? walletUriBase;

  String get address => publicKey.toBase58();

  String get truncatedAddress {
    final a = address;
    if (a.length <= 10) return a;
    return '${a.substring(0, 4)}…${a.substring(a.length - 4)}';
  }

  WalletSession copyWith({
    String? authToken,
    Ed25519HDPublicKey? publicKey,
    String? accountLabel,
    Uri? walletUriBase,
  }) {
    return WalletSession(
      authToken: authToken ?? this.authToken,
      publicKey: publicKey ?? this.publicKey,
      accountLabel: accountLabel ?? this.accountLabel,
      walletUriBase: walletUriBase ?? this.walletUriBase,
    );
  }
}

/// Persists the current [WalletSession] in the platform secure storage
/// (Android Keystore-backed EncryptedSharedPreferences) so a user isn't
/// re-prompted to connect their wallet every time they open the app —
/// only [WalletService.reauthorize] needs to run on startup.
class MwaSessionManager {
  MwaSessionManager({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  Future<void> save(WalletSession session) async {
    await Future.wait([
      _storage.write(key: AppConfig.storageKeyAuthToken, value: session.authToken),
      _storage.write(key: AppConfig.storageKeyPublicKey, value: session.address),
      if (session.accountLabel != null)
        _storage.write(key: AppConfig.storageKeyAccountLabel, value: session.accountLabel)
      else
        _storage.delete(key: AppConfig.storageKeyAccountLabel),
      if (session.walletUriBase != null)
        _storage.write(
          key: AppConfig.storageKeyWalletUriBase,
          value: session.walletUriBase.toString(),
        )
      else
        _storage.delete(key: AppConfig.storageKeyWalletUriBase),
    ]);
  }

  /// Loads whatever was last persisted. This is a *cached* session: the
  /// auth token may have been revoked wallet-side since, so callers should
  /// still run [WalletService.reauthorize] before trusting it for anything
  /// beyond showing a "connecting…" placeholder.
  Future<WalletSession?> load() async {
    final authToken = await _storage.read(key: AppConfig.storageKeyAuthToken);
    final publicKeyBase58 = await _storage.read(key: AppConfig.storageKeyPublicKey);
    if (authToken == null || publicKeyBase58 == null) return null;

    final accountLabel = await _storage.read(key: AppConfig.storageKeyAccountLabel);
    final walletUriBaseRaw = await _storage.read(key: AppConfig.storageKeyWalletUriBase);

    return WalletSession(
      authToken: authToken,
      publicKey: Ed25519HDPublicKey.fromBase58(publicKeyBase58),
      accountLabel: accountLabel,
      walletUriBase: walletUriBaseRaw != null ? Uri.tryParse(walletUriBaseRaw) : null,
    );
  }

  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: AppConfig.storageKeyAuthToken),
      _storage.delete(key: AppConfig.storageKeyPublicKey),
      _storage.delete(key: AppConfig.storageKeyAccountLabel),
      _storage.delete(key: AppConfig.storageKeyWalletUriBase),
    ]);
  }
}
