import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/circle.dart';
import '../models/invite.dart';
import '../models/savings_target.dart';
import '../services/anchor_service.dart';
import '../services/circle_repository.dart';
import '../services/invite_repository.dart';
import '../services/profile_service.dart';
import '../services/rpc_service.dart';
import '../services/savings_repository.dart';
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

final anchorServiceProvider = Provider<AnchorService>(
  (ref) => AnchorService(ref.watch(rpcServiceProvider)),
);

final circleRepositoryProvider = Provider<CircleRepository>(
  (ref) => OnChainCircleRepository(ref.watch(rpcServiceProvider)),
);

final savingsRepositoryProvider = Provider<SavingsRepository>(
  (ref) => SavingsRepository(ref.watch(rpcServiceProvider)),
);

/// Same swap-later story as [circleRepositoryProvider]: today an invite
/// code always resolves to the same demo preview; later this resolves a
/// real invite (on-chain PDA or off-chain link service).
final inviteRepositoryProvider = Provider<InviteRepository>((ref) => MockInviteRepository());

final profileServiceProvider = Provider<ProfileService>((ref) => ProfileService());

// --- Display name (local-only nickname) ---

final displayNameProvider = AsyncNotifierProvider<DisplayNameNotifier, String?>(DisplayNameNotifier.new);

class DisplayNameNotifier extends AsyncNotifier<String?> {
  @override
  Future<String?> build() => ref.watch(profileServiceProvider).loadDisplayName();

  Future<void> setName(String? name) async {
    await ref.read(profileServiceProvider).setDisplayName(name);
    final trimmed = name?.trim();
    state = AsyncData(trimmed == null || trimmed.isEmpty ? null : trimmed);
  }
}

// --- Wallet connection state ---

final walletSessionProvider =
    AsyncNotifierProvider<WalletSessionNotifier, WalletSession?>(WalletSessionNotifier.new);

class WalletSessionNotifier extends AsyncNotifier<WalletSession?> {
  @override
  Future<WalletSession?> build() async {
    // Always start disconnected — the wallet should prompt for approval
    // every time the user connects, not silently restore a past session.
    return null;
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
  final session = ref.watch(walletSessionProvider).value;
  final repo = ref.watch(circleRepositoryProvider);
  return repo.getCircleById(id, viewerPubkey: session?.address);
});

final inviteByCodeProvider = FutureProvider.autoDispose.family<CircleInvite?, String>((ref, code) async {
  final repo = ref.watch(inviteRepositoryProvider);
  return repo.resolveCode(code);
});

// --- Savings targets (personal, time-locked vaults — separate from circles) ---

final mySavingsTargetsProvider = FutureProvider.autoDispose<List<SavingsTarget>>((ref) async {
  final session = ref.watch(walletSessionProvider).value;
  if (session == null) return [];
  final repo = ref.watch(savingsRepositoryProvider);
  return repo.getMySavingsTargets(session.address);
});

final savingsTargetByIdProvider = FutureProvider.autoDispose.family<SavingsTarget?, String>((ref, id) async {
  final repo = ref.watch(savingsRepositoryProvider);
  return repo.getSavingsTargetById(id);
});

/// Whether the Activity feed has been marked all-read. Deliberately a
/// plain (non-autoDispose) provider: it needs to survive leaving and
/// re-entering the Notifications screen, which a value held in that
/// screen's own State would not — that was reset on every re-navigation.
/// Still just in-memory, so it resets when the app itself restarts; a real
/// "seen" concept tied to actual new activity is future work.
class NotificationsAllReadNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void markAllRead() => state = true;
}

final notificationsAllReadProvider =
    NotifierProvider<NotificationsAllReadNotifier, bool>(NotificationsAllReadNotifier.new);
