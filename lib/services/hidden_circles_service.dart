import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Locally dismisses circles the user never wants to see again — in
/// practice, ones stuck forever on-chain (a round closed with zero
/// contributions, so it can never auto-settle, past the point where the
/// creator can still cancel it either). Hiding never touches the chain or
/// the circle account itself; it's purely a per-device filter over what
/// [CircleRepository.getMyCircles] returns.
class HiddenCirclesService {
  static const _key = 'hidden_circle_ids';
  final _storage = const FlutterSecureStorage();

  Future<Set<String>> loadHiddenIds() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return {};
    return raw.split(',').where((id) => id.isNotEmpty).toSet();
  }

  Future<void> hide(String circleId) async {
    final ids = await loadHiddenIds();
    if (!ids.add(circleId)) return;
    await _storage.write(key: _key, value: ids.join(','));
  }
}
