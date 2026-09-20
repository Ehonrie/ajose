import 'package:flutter/material.dart';

import '../../core/date_formatting.dart';
import '../../core/initials_avatar.dart';
import '../../core/text_formatting.dart';
import '../../core/theme.dart';
import '../../models/circle.dart';
import '../../models/invite.dart';

/// Shown after a member-to-member swap request goes out (not the instant
/// open-seat claim, which has nothing to wait on). There's no backend to
/// actually deliver this request or track its response, so "24h" / "~2
/// hrs" are illustrative copy, not live countdowns tied to real state —
/// same honesty rule as the rest of this app's mock-data screens.
class SlotSwapSentScreen extends StatelessWidget {
  const SlotSwapSentScreen({super.key, required this.invite, required this.targetSeat});

  final CircleInvite invite;
  final InviteSeat targetSeat;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final yourSeat = invite.yourSeat;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Swap Request'),
        actions: [
          IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _HeroCard(invite: invite, targetSeat: targetSeat, scheme: scheme, textTheme: textTheme),
          const SizedBox(height: 16),
          _ExchangeCard(invite: invite, yourSeat: yourSeat, targetSeat: targetSeat, scheme: scheme, textTheme: textTheme),
          const SizedBox(height: 16),
          _PeerResponseCard(targetSeat: targetSeat, scheme: scheme, textTheme: textTheme),
          const SizedBox(height: 16),
          _PeaceOfMindCard(yourSeat: yourSeat, targetSeat: targetSeat, scheme: scheme, textTheme: textTheme),
          const SizedBox(height: 16),
          _TrustSeal(invite: invite, scheme: scheme, textTheme: textTheme),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: scheme.primaryContainer,
                foregroundColor: scheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Continue to Circle Details'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: () => _confirmCancel(context, yourSeat),
              icon: const Icon(Icons.tune),
              label: const Text('Manage or Cancel Request'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context, InviteSeat yourSeat) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel this swap request?'),
        content: Text(
          'Your reserved Turn ${yourSeat.turnNumber} will stay completely secure.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Keep request')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Cancel it')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Swap request withdrawn. You remain safely locked into Turn '
          '${yourSeat.turnNumber} (${formatShortDate(yourSeat.turnDate!)}).',
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.invite, required this.targetSeat, required this.scheme, required this.textTheme});

  final CircleInvite invite;
  final InviteSeat targetSeat;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: scheme.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                _PulsingRing(color: scheme.secondaryContainer),
                Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainer,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 3))],
                  ),
                  child: Icon(Icons.swap_horizontal_circle, color: scheme.primaryContainer, size: 34),
                ),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
                    child: Icon(Icons.check, size: 14, color: scheme.onPrimary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.handshake, size: 14, color: scheme.primaryContainer),
                const SizedBox(width: 6),
                Text('REQUEST DISPATCHED', style: textTheme.labelSmall?.copyWith(color: scheme.primaryContainer)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text('Swap Request Sent!', style: textTheme.headlineLarge, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                children: [
                  const TextSpan(text: 'We\'ve notified '),
                  TextSpan(
                    text: targetSeat.memberName,
                    style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w600),
                  ),
                  const TextSpan(text: '. Your spot in '),
                  TextSpan(
                    text: invite.circleName,
                    style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w600),
                  ),
                  const TextSpan(text: ' is fully secured while we wait.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExchangeCard extends StatelessWidget {
  const _ExchangeCard({
    required this.invite,
    required this.yourSeat,
    required this.targetSeat,
    required this.scheme,
    required this.textTheme,
  });

  final CircleInvite invite;
  final InviteSeat yourSeat;
  final InviteSeat targetSeat;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('PROPOSED EXCHANGE', style: textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: scheme.secondaryFixed.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(999)),
                child: Text('Expires in 24h', style: textTheme.labelSmall?.copyWith(color: scheme.secondary)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: scheme.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: _slotBox(
                    label: 'Your Reserved',
                    labelColor: scheme.onSurfaceVariant,
                    dotColor: scheme.primaryContainer,
                    turn: yourSeat.turnNumber,
                    date: yourSeat.turnDate!,
                    amount: invite.lumpSumPayoutUsdc,
                    amountColor: scheme.primaryContainer,
                    footer: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock, size: 11, color: scheme.primaryContainer),
                          const SizedBox(width: 3),
                          Text('Locked for you', style: textTheme.labelSmall?.copyWith(color: scheme.primaryContainer, fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: scheme.secondaryContainer, shape: BoxShape.circle),
                  child: Icon(Icons.swap_horiz, size: 18, color: scheme.onSecondaryContainer),
                ),
                Expanded(
                  child: _slotBox(
                    label: 'Target Slot',
                    labelColor: scheme.secondary,
                    dotColor: scheme.secondaryContainer,
                    turn: targetSeat.turnNumber,
                    date: targetSeat.turnDate!,
                    amount: invite.lumpSumPayoutUsdc,
                    amountColor: scheme.secondary,
                    footer: Row(
                      children: [
                        InitialsAvatar(name: targetSeat.memberName!, size: 20, paletteIndex: targetSeat.turnNumber),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            shortName(targetSeat.memberName!),
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.event_repeat, size: 16, color: scheme.primaryContainer),
                    const SizedBox(width: 4),
                    Text(
                      '${_frequencyLabel(invite.frequency)} contribution',
                      style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
                Text(
                  '\$${invite.contributionAmountUsdc.toStringAsFixed(2)} / ${_frequencyShort(invite.frequency)}',
                  style: textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _slotBox({
    required String label,
    required Color labelColor,
    required Color dotColor,
    required int turn,
    required DateTime date,
    required double amount,
    required Color amountColor,
    required Widget footer,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: scheme.surfaceCard, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelSmall?.copyWith(color: labelColor),
                ),
              ),
              Container(width: 6, height: 6, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
            ],
          ),
          Text('Turn $turn', style: textTheme.titleMedium),
          Text(formatShortDate(date), style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('\$${amount.toStringAsFixed(2)}', style: textTheme.titleMedium?.copyWith(color: amountColor, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          footer,
        ],
      ),
    );
  }

  static String _frequencyLabel(ContributionFrequency f) {
    return switch (f) {
      ContributionFrequency.weekly => 'Weekly',
      ContributionFrequency.biweekly => 'Bi-weekly',
      ContributionFrequency.monthly => 'Monthly',
    };
  }

  static String _frequencyShort(ContributionFrequency f) {
    return switch (f) {
      ContributionFrequency.weekly => 'wk',
      ContributionFrequency.biweekly => '2wk',
      ContributionFrequency.monthly => 'mo',
    };
  }
}

class _PeerResponseCard extends StatelessWidget {
  const _PeerResponseCard({required this.targetSeat, required this.scheme, required this.textTheme});

  final InviteSeat targetSeat;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: scheme.surfaceContainerLow, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.surfaceCard,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4)],
                ),
                child: Icon(Icons.notifications_active, color: scheme.primaryContainer, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Live Response Updates', style: textTheme.titleMedium),
                    Text(
                      'We\'ll alert you the moment ${firstName(targetSeat.memberName!)} accepts or declines.',
                      style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: scheme.surfaceCard, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                InitialsAvatar(name: targetSeat.memberName!, size: 32, paletteIndex: targetSeat.turnNumber),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    targetSeat.memberName!,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 6, height: 6, decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      Text('Typically replies in hours', style: textTheme.labelSmall?.copyWith(color: scheme.primaryContainer)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PeaceOfMindCard extends StatelessWidget {
  const _PeaceOfMindCard({
    required this.yourSeat,
    required this.targetSeat,
    required this.scheme,
    required this.textTheme,
  });

  final InviteSeat yourSeat;
  final InviteSeat targetSeat;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: scheme.secondaryFixed, shape: BoxShape.circle),
                child: Icon(Icons.verified_user, size: 16, color: scheme.secondary),
              ),
              const SizedBox(width: 8),
              Text('Guaranteed Peace of Mind', style: textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 12),
          _point(1, 'Someone has 24 hours', '${targetSeat.memberName} can accept or politely decline. If time runs out, the request lapses safely.'),
          const SizedBox(height: 10),
          _point(
            2,
            'Instant settlement upon acceptance',
            'Your payout day moves to ${formatShortDate(targetSeat.turnDate!)} (Turn ${targetSeat.turnNumber}). '
                'Both seats exchange instantly in the circle.',
          ),
          const SizedBox(height: 10),
          _point(
            3,
            'You never lose your place',
            'If declined or expired, you keep Turn ${yourSeat.turnNumber} (${formatShortDate(yourSeat.turnDate!)}) automatically.',
          ),
        ],
      ),
    );
  }

  Widget _point(int number, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: scheme.surfaceContainer, shape: BoxShape.circle),
          child: Text('$number', style: textTheme.labelSmall?.copyWith(color: scheme.primaryContainer, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: textTheme.titleMedium),
              Text(description, style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}

class _TrustSeal extends StatelessWidget {
  const _TrustSeal({required this.invite, required this.scheme, required this.textTheme});

  final CircleInvite invite;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.shield, size: 16, color: scheme.primaryContainer),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            '${invite.circleName} • ${invite.filledSeats} of ${invite.totalSeats} seats filled • Protected vault',
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

/// An expanding, fading ring — a "ping" pulse behind the hero emblem.
class _PulsingRing extends StatefulWidget {
  const _PulsingRing({required this.color});

  final Color color;

  @override
  State<_PulsingRing> createState() => _PulsingRingState();
}

class _PulsingRingState extends State<_PulsingRing> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return Opacity(
          opacity: (1 - t).clamp(0.0, 1.0) * 0.5,
          child: Transform.scale(
            scale: 1 + t * 0.6,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color.withValues(alpha: 0.3)),
            ),
          ),
        );
      },
    );
  }
}
