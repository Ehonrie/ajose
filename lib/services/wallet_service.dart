import 'dart:typed_data';

import 'package:solana/base58.dart';
import 'package:solana/solana.dart';
import 'package:solana_mobile_client/solana_mobile_client.dart';

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

/// Thin wrapper around `solana_mobile_client` (the MWA reference client for
/// Flutter). Every call opens a fresh local-association session with the
/// wallet app, does one round trip, then closes it — that's the pattern MWA
/// itself expects, rather than holding one session open across the app
/// lifetime.
class WalletService {
  WalletService(this._sessionManager);

  final MwaSessionManager _sessionManager;

  /// Whether an MWA-compatible wallet app is installed and reachable. Worth
  /// checking before [authorize] so the user gets a clear message instead
  /// of a silent hang if, e.g., they're on an emulator with no wallet app.
  Future<bool> isWalletAvailable() => LocalAssociationScenario.isAvailable();

  /// Returns the last-persisted session without talking to the wallet.
  /// Callers should still confirm it's live via [reauthorize] before
  /// relying on it for anything beyond an optimistic "connecting…" UI.
  Future<WalletSession?> loadPersistedSession() => _sessionManager.load();

  /// Opens the wallet app and asks the user to approve a new connection.
  Future<WalletSession> authorize() async {
    if (!await isWalletAvailable()) {
      throw WalletException(
        'No Mobile Wallet Adapter-compatible wallet app was found on this '
        'device. Install a wallet that supports MWA (e.g. the Seeker wallet, '
        'Phantom, or Solflare) and try again.',
      );
    }

    final scenario = await LocalAssociationScenario.create();
    await scenario.startActivityForResult(null);
    try {
      final client = await scenario.start();
      final result = await client.authorize(
        identityUri: AppConfig.identityUri,
        iconUri: AppConfig.iconUri,
        identityName: AppConfig.identityName,
        cluster: AppConfig.cluster.mwaClusterName,
      );
      if (result == null) {
        throw WalletException('Wallet connection was cancelled or rejected.');
      }

      final session = WalletSession(
        authToken: result.authToken,
        publicKey: Ed25519HDPublicKey(result.publicKey),
        accountLabel: result.accountLabel,
        walletUriBase: result.walletUriBase,
      );
      await _sessionManager.save(session);
      return session;
    } finally {
      await scenario.close();
    }
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

    final scenario = await LocalAssociationScenario.create();
    await scenario.startActivityForResult(stored.walletUriBase?.toString());
    try {
      final client = await scenario.start();
      final result = await client.reauthorize(
        identityUri: AppConfig.identityUri,
        iconUri: AppConfig.iconUri,
        identityName: AppConfig.identityName,
        authToken: stored.authToken,
      );
      if (result == null) {
        await _sessionManager.clear();
        return null;
      }

      final session = WalletSession(
        authToken: result.authToken,
        publicKey: Ed25519HDPublicKey(result.publicKey),
        accountLabel: result.accountLabel,
        walletUriBase: result.walletUriBase,
      );
      await _sessionManager.save(session);
      return session;
    } catch (_) {
      await _sessionManager.clear();
      return null;
    } finally {
      await scenario.close();
    }
  }

  Future<void> deauthorize(WalletSession session) async {
    final scenario = await LocalAssociationScenario.create();
    await scenario.startActivityForResult(session.walletUriBase?.toString());
    try {
      final client = await scenario.start();
      await client.deauthorize(authToken: session.authToken);
    } finally {
      await scenario.close();
      await _sessionManager.clear();
    }
  }

  /// Signs and sends a raw transaction via the wallet.
  ///
  /// Not called anywhere yet — this phase has no Anchor program to build a
  /// transaction against, so there is nothing real to sign. Wired up now,
  /// following the same open/use/close session pattern as the calls above,
  /// so the *next* phase (contribute flow, once the program exists) is a
  /// matter of building the instruction and calling this — not inventing a
  /// new MWA integration.
  Future<String> signAndSendTransaction(
    WalletSession session,
    Uint8List transactionBytes,
  ) async {
    final scenario = await LocalAssociationScenario.create();
    await scenario.startActivityForResult(session.walletUriBase?.toString());
    try {
      final client = await scenario.start();
      await client.reauthorize(
        identityUri: AppConfig.identityUri,
        iconUri: AppConfig.iconUri,
        identityName: AppConfig.identityName,
        authToken: session.authToken,
      );

      final result = await client.signAndSendTransactions(
        transactions: [transactionBytes],
      );
      if (result.signatures.isEmpty) {
        throw WalletException('The wallet did not return a transaction signature.');
      }
      return base58encode(result.signatures.first);
    } finally {
      await scenario.close();
    }
  }
}
