import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/constants.dart';

/// A locally-chosen display name — purely a client-side nickname, never
/// written on-chain or shared with anyone, used in place of a truncated
/// wallet address wherever the app greets the user by name. Persisted the
/// same way as the MWA session (Android Keystore-backed secure storage),
/// but independently of it, so changing or reconnecting a wallet doesn't
/// reset the name the user picked.
class ProfileService {
  ProfileService({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  Future<String?> loadDisplayName() => _storage.read(key: AppConfig.storageKeyDisplayName);

  /// A null or blank [name] clears the preference, falling back to
  /// whatever the UI shows by default (a truncated wallet address).
  Future<void> setDisplayName(String? name) async {
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      await _storage.delete(key: AppConfig.storageKeyDisplayName);
    } else {
      await _storage.write(key: AppConfig.storageKeyDisplayName, value: trimmed);
    }
  }
}
