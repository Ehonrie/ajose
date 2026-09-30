import 'package:flutter/services.dart';
import 'package:solana/base58.dart';
import 'package:solana/solana.dart';

import '../core/constants.dart';
import '../core/mwa_session_manager.dart';

/// Thrown for any MWA flow failure that should surface a message to the
/// user (no compatible wallet installed, user rejected the request, wallet
/// dropped the local-socket connection, etc).
class WalletException implements Exception {
  WalletException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Bridges to the native Mobile Wallet Adapter integration in
/// `MainActivity.kt`, which wraps `mobile-wallet-adapter-clientlib-ktx`
/// (MWA 2.0) directly.
///
/// This replaces the earlier `solana_mobile_client` package-based
/// implementation: that package pins the old MWA 1.x native clientlib
/// (1.1.0), which current MWA-2.0-only wallets (Solflare, and current
/// Phantom builds — confirmed via device logs showing Phantom's own
/// `[ClientGate] Failed to resolve status` error right after receiving the
/// old-format connection request) silently fail to process rather than
/// showing an approve screen. The native clientlib-ktx integration speaks
/// whichever protocol version the wallet negotiates, v1 or v2,
/// automatically.
class WalletService {
  WalletService(this._sessionManager);

  static const MethodChannel _channel = MethodChannel('app.ajose/mwa');

  final MwaSessionManager _sessionManager;

  /// Every native MWA call ultimately waits on the wallet app (a whole
  /// separate process/activity) to respond. If that app never launches
  /// properly, never responds, or the local session handshake stalls
  /// silently, the platform channel call would otherwise hang forever with
  /// nothing on the Dart side to time it out. Every call below wraps
  /// itself in this so the UI is guaranteed to leave its loading state one
  /// way or another, instead of spinning indefinitely.
  Future<T> _withTimeout<T>(
    Future<T> Function() action, {
    Duration timeout = const Duration(seconds: 30),
    required String timeoutMessage,
  }) {
    return action().timeout(
      timeout,
      onTimeout: () => throw WalletException(timeoutMessage),
    );
  }

  /// Whether an MWA-compatible wallet app is installed and reachable. Worth
  /// checking before [authorize] so the user gets a clear message instead
  /// of a silent hang if, e.g., they're on an emulator with no wallet app.
  Future<bool> isWalletAvailable() async {
    final available = await _channel.invokeMethod<bool>('isWalletAvailable');
    return available ?? false;
  }

  /// Returns the last-persisted session without talking to the wallet.
  /// Callers should still confirm it's live via [reauthorize] before
  /// relying on it for anything beyond an optimistic "connecting…" UI.
  Future<WalletSession?> loadPersistedSession() => _sessionManager.load();

  WalletSession _sessionFromResult(Map<Object?, Object?> result) {
    return WalletSession(
      authToken: result['authToken'] as String,
      publicKey: Ed25519HDPublicKey(result['publicKey'] as List<int>),
      accountLabel: result['accountLabel'] as String?,
      walletUriBase: (result['walletUriBase'] as String?) != null
          ? Uri.tryParse(result['walletUriBase'] as String)
          : null,
    );
  }

  /// Opens the wallet app and asks the user to approve a new connection.
  Future<WalletSession> authorize() async {
    if (!await isWalletAvailable()) {
      throw WalletException(
        'No Mobile Wallet Adapter-compatible wallet app was found on this '
        'device. Install a wallet that supports MWA (e.g. the Seeker wallet, '
        'Phantom, or Solflare) and try again.',
      );
    }

    return _withTimeout(
      () async {
        try {
          final result = await _channel.invokeMethod<Map<Object?, Object?>>(
            'authorize',
            {'cluster': AppConfig.cluster.mwaClusterName},
          );
          final session = _sessionFromResult(result!);
          await _sessionManager.save(session);
          return session;
        } on PlatformException catch (e) {
          if (e.code == 'NO_WALLET_FOUND') {
            throw WalletException(
              'No Mobile Wallet Adapter-compatible wallet app was found on '
              'this device. Install a wallet that supports MWA (e.g. the '
              'Seeker wallet, Phantom, or Solflare) and try again.',
            );
          }
          throw WalletException(e.message ?? 'Wallet connection was cancelled or rejected.');
        }
      },
      timeoutMessage: 'Connecting to the wallet timed out. Make sure a '
          'compatible wallet app is installed and able to respond, then '
          'try again.',
    );
  }

  /// Silently re-establishes a previously authorized session (no approval
  /// UI shown to the user, unless the wallet decides the token is stale).
  /// Returns null if there's nothing persisted, no wallet app is reachable,
  /// or the wallet has revoked the token — in every such case the caller
  /// should fall back to [authorize].
  Future<WalletSession?> reauthorize() async {
    final stored = await _sessionManager.load();
    if (stored == null) return null;
    if (!await isWalletAvailable()) return null;

    try {
      return await _withTimeout(
        () async {
          final result = await _channel.invokeMethod<Map<Object?, Object?>>(
            'reauthorize',
            {'authToken': stored.authToken, 'cluster': AppConfig.cluster.mwaClusterName},
          );
          final session = _sessionFromResult(result!);
          await _sessionManager.save(session);
          return session;
        },
        // Shorter than authorize()'s — this runs silently on every app
        // launch, so fail fast to Onboarding rather than leaving the user
        // stuck on the startup loading screen.
        timeout: const Duration(seconds: 12),
        timeoutMessage: 'Silent reauthorization timed out.',
      );
    } catch (_) {
      await _sessionManager.clear();
      return null;
    }
  }

  /// Best-effort: the local session is cleared regardless of whether the
  /// wallet round trip succeeds, times out, or throws, since the user has
  /// already asked to disconnect and shouldn't be stuck waiting on a wallet
  /// app that may never respond.
  Future<void> deauthorize(WalletSession session) async {
    try {
      await _withTimeout(
        () => _channel.invokeMethod('deauthorize', {'authToken': session.authToken}),
        timeout: const Duration(seconds: 12),
        timeoutMessage: 'Deauthorization timed out.',
      );
    } catch (_) {
      // Ignored — the local session is cleared below either way.
    } finally {
      await _sessionManager.clear();
    }
  }

  /// Signs and sends a raw wire transaction via the wallet.
  Future<String> signAndSendTransaction(
    WalletSession session,
    List<int> transactionBytes,
  ) async {
    final signatures = await signAndSendTransactions(session, [transactionBytes]);
    return signatures.first;
  }

  /// Signs and sends multiple raw wire transactions via the wallet.
  Future<List<String>> signAndSendTransactions(
    WalletSession session,
    List<List<int>> transactionsBytes,
  ) async {
    return _withTimeout(
      () async {
        try {
          final result = await _channel.invokeMapMethod<String, dynamic>(
            'signAndSendTransactions',
            {
              'authToken': session.authToken,
              'cluster': AppConfig.cluster.mwaClusterName,
              'transactions': transactionsBytes
                  .map((tx) => Uint8List.fromList(tx))
                  .toList(),
            },
          );
          if (result == null) {
            throw WalletException('Wallet returned an empty response.');
          }
          final newAuthToken = result['authToken'] as String?;
          if (newAuthToken != null &&
              newAuthToken.isNotEmpty &&
              newAuthToken != session.authToken) {
            final updatedSession = session.copyWith(authToken: newAuthToken);
            await _sessionManager.save(updatedSession);
          }
          final rawSignatures = (result['signatures'] as List<dynamic>?)
              ?.cast<Uint8List>();
          if (rawSignatures == null || rawSignatures.isEmpty) {
            throw WalletException('Wallet returned no transaction signatures.');
          }
          return rawSignatures.map((sig) => base58encode(sig)).toList();
        } on PlatformException catch (e) {
          if (e.code == 'NO_WALLET_FOUND') {
            throw WalletException(
              'No Mobile Wallet Adapter-compatible wallet app was found on '
              'this device.',
            );
          }
          throw WalletException(
            e.message ?? 'Transaction signing was cancelled or rejected.',
          );
        }
      },
      timeout: const Duration(seconds: 120),
      timeoutMessage: 'Transaction signing timed out. Please check your wallet app.',
    );
  }
}
