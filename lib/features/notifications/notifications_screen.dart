import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/date_formatting.dart';
import '../../core/initials_avatar.dart';
import '../../core/providers.dart';
import '../../core/text_formatting.dart';
import '../../core/theme.dart';
import '../../models/circle.dart';
import '../circles/circle_detail_screen.dart';
import '../contribute/contribute_screen.dart';

/// A feed of what's happened across the user's circles, plus a due-soon
/// reminder banner. There's no persisted event log yet (no backend for
/// one), so every card here is derived live from the same [Circle]/
/// [Member] data the rest of the app reads — a payout card appears
/// because a round is fully funded, a contribution card because a member
/// has a `paidAt`, and so on. Nothing is stored between visits; "Mark all
/// read" only changes what's shown on this screen, not any underlying
/// state.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  String? _selectedCircleId;
  bool _allRead = false;

  @override
  Widget build(BuildContext context) {
    final circlesAsync = ref.watch(myCirclesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: circlesAsync.when(
        data: (circles) => _NotificationsBody(
          circles: circles,
          selectedCircleId: _selectedCircleId,
          allRead: _allRead,
          onSelectCircle: (id) => setState(() => _selectedCircleId = id),
          onMarkAllRead: () => setState(() => _allRead = true),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load activity: $e')),
      ),
    );
  }
}

class _NotificationsBody extends StatelessWidget {
  const _NotificationsBody({
    required this.circles,
    required this.selectedCircleId,
    required this.allRead,
    required this.onSelectCircle,
    required this.onMarkAllRead,
  });

  final List<Circle> circles;
  final String? selectedCircleId;
  final bool allRead;
  final ValueChanged<String?> onSelectCircle;
  final VoidCallback onMarkAllRead;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final visibleCircles =
        selectedCircleId == null ? circles : circles.where((c) => c.id == selectedCircleId).toList();

    // A rough "how many things happened" count for the header badge —
    // every payout/contribution/upcoming-turn card generated below,
    // across all circles regardless of the current filter.
    final newCount = circles.fold<int>(0, (sum, c) => sum + _feedItemCount(c));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text('Circle Activity', style: textTheme.headlineMedium),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: allRead ? scheme.surfaceContainer : scheme.secondaryFixed,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    allRead ? 'All caught up' : '$newCount new',
                    style: textTheme.labelSmall?.copyWith(
                      color: allRead ? scheme.onSurfaceVariant : scheme.onSecondaryFixed,
                    ),
                  ),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: allRead ? null : onMarkAllRead,
              icon: Icon(allRead ? Icons.check : Icons.done_all, size: 18),
              label: Text(allRead ? 'Cleared' : 'Mark all read'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _FilterChip(
                label: 'All Circles',
                selected: selectedCircleId == null,
                scheme: scheme,
                textTheme: textTheme,
                onTap: () => onSelectCircle(null),
              ),
              for (final circle in circles) ...[
                const SizedBox(width: 8),
                _FilterChip(
                  label: circle.name,
                  selected: selectedCircleId == circle.id,
                  scheme: scheme,
                  textTheme: textTheme,
                  onTap: () => onSelectCircle(circle.id),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _DueReminderBanner(circles: circles, scheme: scheme, textTheme: textTheme),
        if (visibleCircles.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text('No circles yet.', style: textTheme.bodyMedium),
          )
        else
          for (final circle in visibleCircles) ...[
            const SizedBox(height: 20),
            _CircleFeedSection(circle: circle, index: circles.indexOf(circle), scheme: scheme, textTheme: textTheme),
          ],
        const SizedBox(height: 24),
        _EndOfFeedMessage(scheme: scheme, textTheme: textTheme),
      ],
    );
  }

  static int _feedItemCount(Circle circle) {
    var count = 0;
    final fullyFunded = circle.membersPaidThisRound == circle.members.length;
    if (fullyFunded) count++;
    count += circle.members.where((m) => m.status == MemberPaymentStatus.paid && m != circle.currentRecipient).length.clamp(0, 2);
    if (!circle.currentRecipient.isCurrentUser && circle.nextRecipient.isCurrentUser) count++;
    return count;
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.scheme,
    required this.textTheme,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final ColorScheme scheme;
  final TextTheme textTheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? scheme.primary : scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// The circle where the connected user has an unpaid contribution due
/// soonest — surfaced above the feed regardless of the active filter,
/// since it's the one actionable thing on this screen.
class _DueReminderBanner extends StatelessWidget {
  const _DueReminderBanner({required this.circles, required this.scheme, required this.textTheme});

  final List<Circle> circles;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    Circle? dueCircle;
    for (final circle in circles) {
      final me = circle.currentUserMember;
      if (me == null || me.hasPaidCurrentRound) continue;
      if (dueCircle == null || circle.currentRoundDeadline.isBefore(dueCircle.currentRoundDeadline)) {
        dueCircle = circle;
      }
    }

    if (dueCircle == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'You\'re all caught up — every contribution is in.',
                style: textTheme.bodyMedium?.copyWith(color: scheme.onSurface),
              ),
            ),
          ],
        ),
      );
    }

    final me = dueCircle.currentUserMember!;
    final overdue = me.status == MemberPaymentStatus.overdue;
    final daysLeft = dueCircle.currentRoundDeadline.difference(DateTime.now()).inDays;
    final circle = dueCircle;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: overdue ? scheme.errorContainer : scheme.secondaryFixed,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: overdue ? scheme.error.withValues(alpha: 0.2) : scheme.secondaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              overdue ? Icons.priority_high : Icons.alarm_on,
              color: overdue ? scheme.onErrorContainer : scheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  overdue ? 'OVERDUE' : (daysLeft <= 0 ? 'DUE TODAY' : 'DUE IN $daysLeft DAY${daysLeft == 1 ? '' : 'S'}'),
                  style: textTheme.labelSmall?.copyWith(
                    color: overdue ? scheme.onErrorContainer : scheme.onSecondaryFixed,
                  ),
                ),
                Text(
                  circle.name,
                  style: textTheme.titleMedium?.copyWith(
                    color: overdue ? scheme.onErrorContainer : scheme.onSecondaryFixed,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Your scheduled contribution of \$${circle.contributionAmountUsdc.toStringAsFixed(2)} '
                  '${overdue ? 'is overdue' : 'is due ${formatShortDate(circle.currentRoundDeadline)}'}.',
                  style: textTheme.bodySmall?.copyWith(
                    color: overdue ? scheme.onErrorContainer : scheme.onSecondaryFixedVariant,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    FilledButton(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                      ),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => ContributeScreen(circle: circle)),
                      ),
                      child: const Text('Contribute Now'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => CircleDetailScreen(circleId: circle.id)),
                      ),
                      child: Text(
                        'Details',
                        style: TextStyle(color: overdue ? scheme.onErrorContainer : scheme.onSecondaryFixed),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleFeedSection extends StatelessWidget {
  const _CircleFeedSection({required this.circle, required this.index, required this.scheme, required this.textTheme});

  final Circle circle;
  final int index;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final dotColor = index.isEven ? scheme.primary : scheme.secondary;
    final fullyFunded = circle.membersPaidThisRound == circle.members.length;
    final recentContributors = circle.members
        .where((m) => m.status == MemberPaymentStatus.paid && m != circle.currentRecipient)
        .toList()
      ..sort((a, b) => (b.paidAt ?? DateTime(0)).compareTo(a.paidAt ?? DateTime(0)));
    final showUpcomingTurn = !circle.currentRecipient.isCurrentUser && circle.nextRecipient.isCurrentUser;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(circle.name, style: textTheme.titleMedium, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(999)),
                child: Text(
                  'Round ${circle.currentRoundNumber} of ${circle.totalRounds}',
                  style: textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (fullyFunded)
          _PayoutCard(circle: circle, scheme: scheme, textTheme: textTheme)
        else
          for (final member in recentContributors.take(2)) ...[
            _ContributionCard(circle: circle, member: member, scheme: scheme, textTheme: textTheme),
            const SizedBox(height: 8),
          ],
        if (!fullyFunded) ...[
          _MilestoneCard(circle: circle, scheme: scheme, textTheme: textTheme),
          const SizedBox(height: 8),
        ],
        if (showUpcomingTurn) _UpcomingTurnCard(circle: circle, scheme: scheme, textTheme: textTheme),
      ],
    );
  }
}

class _PayoutCard extends StatelessWidget {
  const _PayoutCard({required this.circle, required this.scheme, required this.textTheme});

  final Circle circle;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final recipient = circle.currentRecipient;
    final youReceived = recipient.isCurrentUser;
    final timeAgo = recipient.paidAt != null ? formatRelativeTime(recipient.paidAt!) : 'recently';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border(left: BorderSide(color: scheme.secondaryContainer, width: 4)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: scheme.secondaryFixed, borderRadius: BorderRadius.circular(16)),
            child: Icon(Icons.celebration, color: scheme.secondary, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 6, height: 6, decoration: BoxDecoration(color: scheme.secondary, shape: BoxShape.circle)),
                        const SizedBox(width: 4),
                        Text('PAYOUT DISBURSED', style: textTheme.labelSmall?.copyWith(color: scheme.secondary)),
                      ],
                    ),
                    Text(timeAgo, style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        youReceived ? 'Payout sent to you' : '${shortName(recipient.displayName)} received the pot',
                        style: textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      '+\$${circle.potTotalUsdc.toStringAsFixed(2)}',
                      style: textTheme.titleLarge?.copyWith(color: scheme.primary, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                Text(
                  youReceived
                      ? 'Round ${circle.currentRoundNumber} rotation settled directly to your balance. '
                          'Funds are verified and fully protected.'
                      : 'Sent successfully to their protected wallet.',
                  style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Receipt view is coming soon.')),
                      ),
                      icon: const Icon(Icons.receipt_long, size: 16),
                      label: const Text('View Receipt'),
                    ),
                    if (!youReceived)
                      TextButton.icon(
                        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Cheered for ${shortName(recipient.displayName)}! 🎉')),
                        ),
                        icon: const Text('🎉'),
                        label: const Text('Cheer'),
                      )
                    else
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified, size: 16, color: scheme.primary),
                          const SizedBox(width: 4),
                          Text('Confirmed', style: textTheme.labelSmall?.copyWith(color: scheme.primary)),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContributionCard extends StatelessWidget {
  const _ContributionCard({required this.circle, required this.member, required this.scheme, required this.textTheme});

  final Circle circle;
  final Member member;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 1))],
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              InitialsAvatar(name: member.displayName, size: 44, paletteIndex: member.payoutPosition),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
                  child: Icon(Icons.check, size: 11, color: scheme.onPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        member.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      '\$${circle.contributionAmountUsdc.toStringAsFixed(2)}',
                      style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Contributed for Round ${circle.currentRoundNumber}',
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                    Text(
                      member.paidAt != null ? formatRelativeTime(member.paidAt!) : '',
                      style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MilestoneCard extends StatelessWidget {
  const _MilestoneCard({required this.circle, required this.scheme, required this.textTheme});

  final Circle circle;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final progress = circle.roundProgress.clamp(0.0, 1.0);
    final paidAmount = circle.contributionAmountUsdc * circle.membersPaidThisRound;
    final pending = circle.members.length - circle.membersPaidThisRound;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: scheme.surfaceContainerLow, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.pie_chart, size: 16, color: scheme.onPrimary),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Round ${circle.currentRoundNumber} pot is ${(progress * 100).round()}% funded',
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '\$${paidAmount.toStringAsFixed(0)} / \$${circle.potTotalUsdc.toStringAsFixed(0)}',
                style: textTheme.labelLarge?.copyWith(color: scheme.primary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: scheme.surfaceContainerHighest,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.groups, size: 16, color: scheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    '${circle.membersPaidThisRound} of ${circle.members.length} members completed on time',
                    style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
              if (pending > 0)
                Text(
                  '$pending pending',
                  style: textTheme.labelSmall?.copyWith(color: scheme.secondary, fontWeight: FontWeight.bold),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UpcomingTurnCard extends StatelessWidget {
  const _UpcomingTurnCard({required this.circle, required this.scheme, required this.textTheme});

  final Circle circle;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final targetDate = circle.followingRoundDeadline;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 1))],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: scheme.secondaryFixed, borderRadius: BorderRadius.circular(16)),
            child: Icon(Icons.upcoming, color: scheme.onSecondaryFixed, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 6, height: 6, decoration: BoxDecoration(color: scheme.secondary, shape: BoxShape.circle)),
                        const SizedBox(width: 4),
                        Text('YOUR TURN APPROACHING', style: textTheme.labelSmall?.copyWith(color: scheme.secondary)),
                      ],
                    ),
                    Text(formatShortDate(targetDate), style: textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ),
                Text('Round ${circle.currentRoundNumber + 1} Pot Collection', style: textTheme.titleMedium),
                Text(
                  'You are scheduled to receive the full rotation pot '
                  '(\$${circle.potTotalUsdc.toStringAsFixed(2)}). Keep an eye on the deadline.',
                  style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EndOfFeedMessage extends StatelessWidget {
  const _EndOfFeedMessage({required this.scheme, required this.textTheme});

  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: scheme.surfaceContainer, shape: BoxShape.circle),
          child: Icon(Icons.shield, size: 20, color: scheme.primary),
        ),
        const SizedBox(height: 8),
        Text('All transactions protected & verified', style: textTheme.labelLarge),
        const SizedBox(height: 2),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: Text(
            'Your group activity is tracked on-chain and confirmed by every member.',
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
