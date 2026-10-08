import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/circle.dart';
import 'mwa_session_manager.dart';
import 'providers.dart';

/// Invisible widget that periodically checks whether [circle]'s round
/// deadline has passed and, if so, settles it on-chain via the
/// permissionless `settle_round` instruction — the payout and round-advance
/// only happen once that lands.
///
/// There's no server-side cron here: this is the closest a client-only app
/// can get to "automatic" time-triggered payouts. It only fires while a
/// screen showing this circle is open and a wallet is connected, so a
/// round that's due while nobody has the app open simply waits for the
/// next time someone does. Drop one of these into any screen that renders
/// a non-complete [Circle].
///
/// When the connected wallet is itself the round's recipient, this doesn't
/// settle silently — it asks first (a dialog with a "Receive" button),
/// since that's the one case where auto-firing would reach into the
/// viewer's own wallet without them having asked for it. Settling someone
/// else's round stays silent, since it only spends a small network fee to
/// move the circle forward.
class AutoSettleTicker extends ConsumerStatefulWidget {
  const AutoSettleTicker({super.key, required this.circle, this.onFinalSettlement});

  final Circle circle;

  /// Called once this ticker settles the round that finishes the circle's
  /// whole rotation — a screen dedicated to this one circle (the detail
  /// screen) has nothing left to show once that happens, so it can use this
  /// to step itself away rather than leave the user sitting on a "complete"
  /// screen they didn't ask to see mid-read. Leave null anywhere a circle is
  /// just one of several on screen (e.g. Home's list).
  final VoidCallback? onFinalSettlement;

  @override
  ConsumerState<AutoSettleTicker> createState() => _AutoSettleTickerState();
}

class _AutoSettleTickerState extends ConsumerState<AutoSettleTicker> with WidgetsBindingObserver {
  // Shared across every instance — a circle can be on-screen in more than
  // one place at once (Home's card stays mounted underneath when its detail
  // screen is pushed on top, each running its own 5s timer), so without
  // this two tickers can each decide the round is due and prompt the
  // wallet (or the receive dialog) back-to-back for the same settlement.
  // Keyed by circle id, the value is "don't attempt this circle again
  // before this moment" — set *before* the wallet round-trip or dialog
  // starts, not just while it's pending, so a slow approval (or someone
  // sitting on the dialog) doesn't leave a window for another instance's
  // tick to also fire.
  static final Map<String, DateTime> _cooldownUntil = {};
  static const _cooldown = Duration(seconds: 20);

  Timer? _timer;
  bool _resumed = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    if (_resumed) {
      // The circle this widget was built with may be stale by however long
      // the app was backgrounded — e.g. this round settled while away, via
      // another device or the recipient's own app. Refresh before the next
      // periodic _check() re-evaluates it, so a stale "still due" snapshot
      // can't trigger a redundant settle attempt (and the wallet-app
      // hand-off that comes with it) the instant the app regains focus.
      ref.invalidate(myCirclesProvider);
      ref.invalidate(circleByIdProvider(widget.circle.id));
    }
  }

  Future<void> _check() async {
    if (!_resumed) return;
    final circle = widget.circle;
    if (circle.isComplete) return;
    if (!circle.currentRoundDeadline.isBefore(DateTime.now())) return;
    // Nobody contributed this round at all — rather than auto-skip it (and
    // burn the recipient's turn for nothing), leave it unsettled so the
    // creator still has the option to cancel the circle instead. A round
    // with at least one real contribution still settles automatically,
    // disbursing whatever's there and moving the circle forward.
    if (circle.membersPaidThisRound == 0) return;

    final now = DateTime.now();
    final until = _cooldownUntil[circle.id];
    if (until != null && now.isBefore(until)) return;

    final session = ref.read(walletSessionProvider).value;
    if (session == null) return;

    _cooldownUntil[circle.id] = now.add(_cooldown);

    if (circle.currentRecipient.isCurrentUser) {
      if (mounted) await _promptToReceive(circle, session);
      return;
    }

    try {
      await _settle(circle, session);
    } catch (_) {
      // Best-effort background crank: another device may have already
      // settled this round, or the wallet may be busy elsewhere. The
      // cooldown above still applies, so this just waits for the next
      // window rather than retrying immediately.
    }
  }

  Future<void> _promptToReceive(Circle circle, WalletSession session) async {
    final receive = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.celebration, color: Colors.green, size: 40),
        title: const Text("It's your turn!"),
        content: Text(
          'Round ${circle.currentRoundNumber}\'s pot of '
          '\$${circle.potTotalUsdc.toStringAsFixed(2)} USDC is ready to collect.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Receive'),
          ),
        ],
      ),
    );

    if (receive != true || !mounted) return;

    try {
      await _settle(circle, session);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not collect payout: $e')),
        );
      }
    }
  }

  /// Builds, sends, and confirms the `settle_round` transaction, refreshes
  /// the providers it affects, and fires [AutoSettleTicker.onFinalSettlement]
  /// if this was the round that finished the circle's rotation. Shared by
  /// the silent background path and the "Receive" dialog's confirm action.
  Future<void> _settle(Circle circle, WalletSession session) async {
    final anchor = ref.read(anchorServiceProvider);
    final txBytes = await anchor.buildSettleRoundTransaction(
      payer: session.publicKey,
      circle: circle,
    );

    final walletService = ref.read(walletServiceProvider);
    final signature = await walletService.signAndSendTransaction(session, txBytes);

    final rpc = ref.read(rpcServiceProvider);
    await rpc.waitForSignatureStatus(signature);

    ref.invalidate(myCirclesProvider);
    ref.invalidate(circleByIdProvider(circle.id));
    ref.invalidate(walletBalancesProvider);

    final wasFinalRound = circle.completedRounds + 1 >= circle.totalRounds;
    if (wasFinalRound && mounted) {
      widget.onFinalSettlement?.call();
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
