import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/date_formatting.dart';
import '../../core/initials_avatar.dart';
import '../../core/providers.dart';
import '../../core/rotation_ring.dart';
import '../../core/theme.dart';
import '../../models/circle.dart';
import '../contribute/contribute_screen.dart';

class CircleDetailScreen extends ConsumerWidget {
  const CircleDetailScreen({super.key, required this.circleId});

  final String circleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final circleAsync = ref.watch(circleByIdProvider(circleId));

    return Scaffold(
      appBar: AppBar(title: const Text('Circle Details')),
      body: circleAsync.when(
        data: (circle) {
          if (circle == null) {
            return const Center(child: Text('Circle not found.'));
          }
          return _CircleDetailBody(circle: circle);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load circle: $e')),
      ),
    );
  }
}

class _CircleDetailBody extends StatelessWidget {
  const _CircleDetailBody({required this.circle});

  final Circle circle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            children: [
              _ContextHeaderCard(circle: circle, scheme: scheme, textTheme: textTheme),
              const SizedBox(height: 16),
              _RotationCard(circle: circle, scheme: scheme, textTheme: textTheme),
              const SizedBox(height: 16),
              _CountdownCard(circle: circle, scheme: scheme, textTheme: textTheme),
              const SizedBox(height: 16),
              _MemberListSection(circle: circle, scheme: scheme, textTheme: textTheme),
            ],
          ),
        ),
        _BottomCta(circle: circle, scheme: scheme, textTheme: textTheme),
      ],
    );
  }
}

/// A small dot that gently fades in and out — used for "this is live"
/// indicators (the Active status pill, a pending-payment marker).
class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color});

  final Color color;
  static const double _size = 6;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 1.0, end: 0.25).animate(_controller),
      child: Container(
        width: _PulsingDot._size,
        height: _PulsingDot._size,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}

class _ContextHeaderCard extends StatelessWidget {
  const _ContextHeaderCard({required this.circle, required this.scheme, required this.textTheme});

  final Circle circle;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -40,
              top: -40,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.secondaryFixed.withValues(alpha: 0.35),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _PulsingDot(color: scheme.primary),
                          const SizedBox(width: 6),
                          Text(
                            'ACTIVE • CYCLE ${circle.currentRoundNumber} OF ${circle.totalRounds}',
                            style: textTheme.labelSmall?.copyWith(color: scheme.primary),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.verified_user, size: 16, color: scheme.secondary),
                    const SizedBox(width: 4),
                    Text(
                      'Escrow Protected',
                      style: textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(circle.name, style: textTheme.headlineMedium),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TOTAL ROUND POT',
                            style: textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                          RichText(
                            text: TextSpan(
                              style: AppTheme.numericCurrency.copyWith(color: scheme.primary),
                              children: [
                                TextSpan(text: '\$${circle.potTotalUsdc.toStringAsFixed(2)} '),
                                TextSpan(
                                  text: 'USDC',
                                  style: textTheme.labelLarge?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'YOUR SHARE',
                          style: textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        RichText(
                          text: TextSpan(
                            style: textTheme.titleLarge,
                            children: [
                              TextSpan(text: '\$${circle.contributionAmountUsdc.toStringAsFixed(2)}'),
                              TextSpan(
                                text: '/${_frequencyShortLabel(circle.frequency)}',
                                style: textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _frequencyShortLabel(ContributionFrequency f) => switch (f) {
        ContributionFrequency.weekly => 'wk',
        ContributionFrequency.biweekly => '2wk',
        ContributionFrequency.monthly => 'mo',
      };
}

class _RotationCard extends StatelessWidget {
  const _RotationCard({required this.circle, required this.scheme, required this.textTheme});

  final Circle circle;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Round ${circle.currentRoundNumber} Rotation',
                  style: textTheme.titleMedium,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: scheme.secondaryFixed.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${circle.currentRoundNumber} of ${circle.totalRounds} Turns',
                  style: textTheme.labelSmall?.copyWith(color: scheme.secondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          RotationRing(
            circle: circle,
            center: _RecipientSpotlight(
              recipient: circle.currentRecipient,
              potTotal: circle.potTotalUsdc,
              scheme: scheme,
              textTheme: textTheme,
            ),
          ),
          const SizedBox(height: 12),
          _UpNextBanner(circle: circle, scheme: scheme, textTheme: textTheme),
        ],
      ),
    );
  }
}

class _RecipientSpotlight extends StatelessWidget {
  const _RecipientSpotlight({
    required this.recipient,
    required this.potTotal,
    required this.scheme,
    required this.textTheme,
  });

  final Member recipient;
  final double potTotal;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 108,
      height: 108,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              InitialsAvatar(name: recipient.displayName, size: 40, paletteIndex: recipient.payoutPosition),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 16,
                  height: 16,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: scheme.secondary, shape: BoxShape.circle),
                  child: Icon(Icons.celebration, size: 10, color: scheme.onSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'RECIPIENT',
            style: textTheme.labelSmall?.copyWith(color: scheme.secondary, fontSize: 9),
          ),
          Text(
            recipient.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleMedium?.copyWith(fontSize: 12),
          ),
          Text(
            '\$${potTotal.toStringAsFixed(0)}',
            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: scheme.primary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _UpNextBanner extends StatelessWidget {
  const _UpNextBanner({required this.circle, required this.scheme, required this.textTheme});

  final Circle circle;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final next = circle.nextRecipient;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.secondary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.arrow_forward, size: 18, color: scheme.secondary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'UP NEXT (ROUND ${circle.currentRoundNumber + 1})',
                  style: textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant, fontSize: 10),
                ),
                Text(
                  next.isCurrentUser ? '${next.displayName} (You)' : next.displayName,
                  style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 2)],
            ),
            child: Text(
              formatUpcoming(circle.followingRoundDeadline),
              style: textTheme.labelSmall?.copyWith(color: scheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountdownCard extends StatelessWidget {
  const _CountdownCard({required this.circle, required this.scheme, required this.textTheme});

  final Circle circle;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final progress = circle.roundProgress.clamp(0.0, 1.0);
    final paidTotal = circle.contributionAmountUsdc * circle.membersPaidThisRound;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('⏱️', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ROUND ${circle.currentRoundNumber} DEADLINE',
                      style: textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    Text(formatCountdown(circle.currentRoundDeadline), style: textTheme.headlineMedium),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${(progress * 100).floor()}%',
                  style: textTheme.titleLarge?.copyWith(color: scheme.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: scheme.surfaceContainer,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${circle.membersPaidThisRound} of ${circle.members.length} members contributed',
                style: textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              Text(
                '\$${paidTotal.toStringAsFixed(0)} / \$${circle.potTotalUsdc.toStringAsFixed(0)} USDC',
                style: textTheme.labelSmall?.copyWith(color: scheme.primary, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MemberListSection extends StatelessWidget {
  const _MemberListSection({required this.circle, required this.scheme, required this.textTheme});

  final Circle circle;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Member Status', style: textTheme.titleLarge),
              Text(
                'Round ${circle.currentRoundNumber} of ${circle.totalRounds}',
                style: textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            color: AppTheme.surfaceCard,
            child: Column(
              children: [
                for (var i = 0; i < circle.members.length; i++) ...[
                  if (i != 0) const Divider(height: 1),
                  _MemberRow(
                    member: circle.members[i],
                    index: i,
                    isRecipient: circle.members[i] == circle.currentRecipient,
                    contributionAmount: circle.contributionAmountUsdc,
                    scheme: scheme,
                    textTheme: textTheme,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.index,
    required this.isRecipient,
    required this.contributionAmount,
    required this.scheme,
    required this.textTheme,
  });

  final Member member;
  final int index;
  final bool isRecipient;
  final double contributionAmount;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final Color rowColor;
    if (isRecipient) {
      rowColor = scheme.secondaryFixed.withValues(alpha: 0.2);
    } else if (member.isCurrentUser) {
      rowColor = scheme.secondaryFixed.withValues(alpha: 0.35);
    } else if (member.status == MemberPaymentStatus.overdue) {
      rowColor = scheme.errorContainer.withValues(alpha: 0.3);
    } else {
      rowColor = index.isEven ? AppTheme.surfaceCard : scheme.surfaceContainerLow.withValues(alpha: 0.4);
    }

    return Container(
      color: rowColor,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              InitialsAvatar(name: member.displayName, size: 44, paletteIndex: index),
              Positioned(
                right: -2,
                bottom: -2,
                child: _badgeIcon(),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        member.isCurrentUser ? '${member.displayName} (You)' : member.displayName,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (isRecipient) ...[
                      const SizedBox(width: 6),
                      _tinyTag('RECIPIENT', scheme.secondary, scheme.onSecondary),
                    ] else if (member.isCurrentUser) ...[
                      const SizedBox(width: 6),
                      _tinyTag('YOU', scheme.primary, scheme.onPrimary),
                    ],
                  ],
                ),
                Text(_subtitleFor(member), style: textTheme.bodySmall?.copyWith(color: _subtitleColor())),
              ],
            ),
          ),
          _statusPill(),
        ],
      ),
    );
  }

  Widget _tinyTag(String label, Color background, Color foreground) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(4)),
      child: Text(
        label,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: foreground),
      ),
    );
  }

  Widget _badgeIcon() {
    final (color, foreground, icon) = switch (member.status) {
      MemberPaymentStatus.paid => (scheme.primary, scheme.onPrimary, Icons.check),
      MemberPaymentStatus.overdue => (scheme.error, scheme.onError, Icons.warning),
      MemberPaymentStatus.pending => isRecipient
          ? (scheme.secondary, scheme.onSecondary, Icons.payments)
          : (scheme.secondary, scheme.onSecondary, Icons.schedule),
    };
    return Container(
      width: 16,
      height: 16,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.surfaceCard, width: 1.5),
      ),
      child: Icon(icon, size: 9, color: foreground),
    );
  }

  String _subtitleFor(Member m) {
    final amount = contributionAmount.toStringAsFixed(0);
    return switch (m.status) {
      MemberPaymentStatus.paid =>
        'Paid ${m.paidAt != null ? formatShortDate(m.paidAt!) : ''} • \$$amount',
      MemberPaymentStatus.pending =>
        m.isCurrentUser ? 'Your contribution due • \$$amount' : 'Contribution due • \$$amount',
      MemberPaymentStatus.overdue => '1 day overdue • Reminder sent',
    };
  }

  Color _subtitleColor() => switch (member.status) {
        MemberPaymentStatus.paid => scheme.onSurfaceVariant,
        MemberPaymentStatus.pending => scheme.secondary,
        MemberPaymentStatus.overdue => AppTheme.statusOverdue,
      };

  Widget _statusPill() {
    final (label, background, foreground) = switch (member.status) {
      MemberPaymentStatus.paid => ('Paid', scheme.primary.withValues(alpha: 0.1), scheme.primary),
      MemberPaymentStatus.pending => ('Pending', scheme.secondary.withValues(alpha: 0.15), scheme.secondary),
      MemberPaymentStatus.overdue => ('Overdue', scheme.error.withValues(alpha: 0.1), AppTheme.statusOverdue),
    };
    final icon = switch (member.status) {
      MemberPaymentStatus.paid => Icons.check_circle,
      MemberPaymentStatus.pending => null,
      MemberPaymentStatus.overdue => null,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: foreground),
            const SizedBox(width: 3),
          ] else ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: foreground, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
          ],
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: foreground)),
        ],
      ),
    );
  }
}

class _BottomCta extends ConsumerWidget {
  const _BottomCta({required this.circle, required this.scheme, required this.textTheme});

  final Circle circle;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final youPaid = circle.currentUserMember?.hasPaidCurrentRound ?? false;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: AppTheme.backgroundWarm,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, -4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (youPaid)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: scheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Paid for Round ${circle.currentRoundNumber} '
                    '(\$${circle.contributionAmountUsdc.toStringAsFixed(0)} USDC)',
                    style: textTheme.titleMedium?.copyWith(color: scheme.primary),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.primaryContainer,
                  foregroundColor: scheme.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ContributeScreen(circle: circle)),
                ),
                icon: const Icon(Icons.account_balance_wallet),
                label: Text(
                  'Contribute This Round (\$${circle.contributionAmountUsdc.toStringAsFixed(2)} USDC)',
                ),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock, size: 14, color: scheme.outline),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Funds held in multi-sig circle escrow until '
                  '${formatShortDate(circle.currentRoundDeadline)} payout',
                  textAlign: TextAlign.center,
                  style: textTheme.labelSmall?.copyWith(color: scheme.outline),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
