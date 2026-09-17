import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/circle.dart';
import '../services/circle_repository.dart';
import '../services/rpc_service.dart';
import '../services/wallet_service.dart';
import 'mwa_session_manager.dart';
import 'notification_service.dart';

// --- Services (stateless-ish singletons for the app's lifetime) ---

final mwaSessionManagerProvider = Provider<MwaSessionManager>((ref) => MwaSessionManager());

final notificationServiceProvider = Provider<NotificationService>((ref) => NotificationService());

final walletServiceProvider = Provider<WalletService>((ref) {
  return WalletService(ref.watch(mwaSessionManagerProvider));
});

final rpcServiceProvider = Provider<RpcService>((ref) => RpcService());

/// Swap this single provider for one returning an on-chain-backed
/// repository once the Anchor program exists — every screen reading
/// circles goes through this provider, not the concrete class.
final circleRepositoryProvider = Provider<CircleRepository>((ref) => MockCircleRepository());

// --- Wallet connection state ---

final walletSessionProvider =
    AsyncNotifierProvider<WalletSessionNotifier, WalletSession?>(WalletSessionNotifier.new);

class WalletSessionNotifier extends AsyncNotifier<WalletSession?> {
  @override
  Future<WalletSession?> build() async {
    // On app start, try to silently restore a previously-approved session
    // (persisted auth token) before ever showing the Onboarding screen.
    final service = ref.watch(walletServiceProvider);
    return service.reauthorize();
  }

  Future<void> connect() async {
    state = const AsyncLoading();
    final service = ref.read(walletServiceProvider);
    state = await AsyncValue.guard(() => service.authorize());
  }

  Future<void> disconnect() async {
    final session = state.value;
    if (session == null) return;
    state = const AsyncLoading();
    final service = ref.read(walletServiceProvider);
    await service.deauthorize(session);
    state = const AsyncData(null);
  }
}

/// True once we've either restored a session or confirmed there isn't one —
/// i.e. it's safe to route to Onboarding vs. Home.
final walletSessionReadyProvider = Provider<bool>((ref) {
  return !ref.watch(walletSessionProvider).isLoading;
});

// --- On-chain reads for the connected wallet ---

final walletBalancesProvider = FutureProvider.autoDispose<WalletBalances?>((ref) async {
  final session = ref.watch(walletSessionProvider).value;
  if (session == null) return null;
  final rpc = ref.watch(rpcServiceProvider);
  return rpc.getBalances(session.publicKey);
});

// --- Circle data (mock today, on-chain reads later — same provider) ---

final myCirclesProvider = FutureProvider.autoDispose<List<Circle>>((ref) async {
  final session = ref.watch(walletSessionProvider).value;
  final repo = ref.watch(circleRepositoryProvider);
  return repo.getMyCircles(session?.address ?? '');
});

final circleByIdProvider = FutureProvider.autoDispose.family<Circle?, String>((ref, id) async {
  final repo = ref.watch(circleRepositoryProvider);
  return repo.getCircleById(id);
});
