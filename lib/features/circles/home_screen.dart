import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/date_formatting.dart';
import '../../core/initials_avatar.dart';
import '../../core/mwa_session_manager.dart';
import '../../core/providers.dart';
import '../../core/rotation_ring.dart';
import '../../core/text_formatting.dart';
import '../../core/theme.dart';
import '../../models/circle.dart';
import '../contribute/contribute_screen.dart';
import '../create_circle/create_circle_screen.dart';
import '../join_circle/join_invite_screen.dart';
import '../notifications/notifications_screen.dart';
import '../onboarding/onboarding_screen.dart';
import 'circle_detail_screen.dart';

String _frequencyLabel(ContributionFrequency f) => switch (f) {
      ContributionFrequency.weekly => 'weekly',
      ContributionFrequency.biweekly => 'bi-weekly',
      ContributionFrequency.monthly => 'monthly',
    };

String _greetingFirstName(List<Circle> circles, WalletSession? session) {
  for (final circle in circles) {
    final me = circle.currentUserMember;
    if (me != null) return me.displayName.split(RegExp(r'\s+')).first;
  }
  return session?.truncatedAddress ?? 'there';
}

void _showComingSoon(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

/// Prompts for an invite code, then previews it on [JoinInviteScreen].
/// [MockInviteRepository] resolves any non-empty code to the same demo
/// invite for now — there's no real invite-link/code backend yet.
Future<void> _showEnterCodeDialog(BuildContext context) async {
  final controller = TextEditingController();
  final code = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Enter Invite Code'),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(hintText: 'e.g. FAMILY2024'),
        onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(controller.text),
          child: const Text('Preview'),
        ),
      ],
    ),
  );
  controller.dispose();

  if (code == null || code.trim().isEmpty || !context.mounted) return;
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => JoinInviteScreen(code: code.trim())),
  );
}

/// Whether this round is paid up, needs an overdue nudge, or is normally
/// in-progress — drives the small status pill both circle cards share.
Widget _fundingStatusPill(Circle circle, ColorScheme scheme, TextTheme textTheme) {
  final paid = circle.membersPaidThisRound;
  final total = circle.members.length;
  final hasOverdue = circle.members.any((m) => m.status == MemberPaymentStatus.overdue);

  final String label;
  final Color background;
  final Color foreground;
  final IconData? icon;
  if (paid == total) {
    label = 'Fully Funded';
    background = scheme.primaryFixed.withValues(alpha: 0.6);
    foreground = scheme.onPrimaryFixedVariant;
    icon = Icons.check_circle;
  } else if (hasOverdue) {
    label = 'Needs Attention • $paid/$total Paid';
    background = scheme.error.withValues(alpha: 0.1);
    foreground = scheme.statusOverdue;
    icon = null;
  } else {
    label = 'On Track • $paid/$total Paid';
    background = scheme.primary.withValues(alpha: 0.1);
    foreground = scheme.primary;
    icon = null;
  }

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: foreground),
          const SizedBox(width: 4),
        ] else ...[
          Container(width: 6, height: 6, decoration: BoxDecoration(color: foreground, shape: BoxShape.circle)),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: textTheme.labelSmall?.copyWith(color: foreground),
          ),
        ),
      ],
    ),
  );
}

/// Landing screen once a wallet is connected: circles the user is part of
/// (mock data this phase), sorted so the most time-sensitive one gets the
/// full rotation-ring treatment and the rest get a compact summary card.
///
/// The live wallet balance (SOL + devnet USDC via RPC) has moved from a
/// prominent card here into the profile sheet (tap the header avatar) to
/// match this design's layout — it's still one tap away, proving the RPC
/// plumbing still works, just no longer front and center.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(walletSessionProvider).value;

    // A session can briefly be null right after disconnect, mid-navigation
    // back to Onboarding — render nothing rather than crash on session!.
    if (session == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final circlesAsync = ref.watch(myCirclesProvider);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Icon(Icons.savings_rounded, color: scheme.primary, size: 28),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ajo', style: textTheme.titleMedium?.copyWith(color: scheme.primary)),
                Text(
                  'Circles',
                  style: textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Send a round reminder',
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => _sendReminder(context, ref),
          ),
          IconButton(
            tooltip: 'Wallet',
            icon: CircleAvatar(
              radius: 16,
              backgroundColor: scheme.primaryContainer,
              child: Icon(Icons.person, size: 18, color: scheme.onPrimary),
            ),
            onPressed: () => _showWalletSheet(context, ref, session),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(walletBalancesProvider);
          ref.invalidate(myCirclesProvider);
        },
        child: circlesAsync.when(
          data: (circles) => _HomeBody(circles: circles, session: session, scheme: scheme, textTheme: textTheme),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Could not load circles: $e'),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CreateCircleScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('New Circle'),
      ),
      bottomNavigationBar: const _BottomNav(),
    );
  }

  Future<void> _sendReminder(BuildContext context, WidgetRef ref) async {
    final circles = ref.read(myCirclesProvider).value ?? const [];
    if (circles.isEmpty) {
      _showComingSoon(context, 'No circles to remind yet.');
      return;
    }
    final sorted = [...circles]..sort(
        (a, b) => a.currentRoundDeadline.compareTo(b.currentRoundDeadline),
      );
    try {
      await ref.read(notificationServiceProvider).showRoundReminder(sorted.first);
      if (context.mounted) _showComingSoon(context, 'Reminder sent for ${sorted.first.name}.');
    } catch (e) {
      if (context.mounted) _showComingSoon(context, 'Could not send reminder: $e');
    }
  }

  void _showWalletSheet(BuildContext context, WidgetRef ref, WalletSession session) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => Consumer(
        builder: (context, ref, _) {
          final balancesAsync = ref.watch(walletBalancesProvider);
          final scheme = Theme.of(context).colorScheme;
          final textTheme = Theme.of(context).textTheme;

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.account_balance_wallet, color: scheme.primary),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(session.truncatedAddress, style: textTheme.titleMedium),
                          Text(AppConfig.cluster.label, style: textTheme.bodySmall),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  balancesAsync.when(
                    data: (balances) => Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _BalanceStat(label: 'SOL', value: balances == null ? '—' : balances.sol.toStringAsFixed(4)),
                        _BalanceStat(
                          label: 'USDC (devnet)',
                          value: balances == null ? '—' : balances.usdcOrZero.toStringAsFixed(2),
                        ),
                      ],
                    ),
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: LinearProgressIndicator(),
                    ),
                    error: (e, _) => Text(
                      'Balance fetch failed: $e',
                      style: TextStyle(color: scheme.error),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        _disconnect(context, ref);
                      },
                      icon: const Icon(Icons.logout),
                      label: const Text('Disconnect Wallet'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _disconnect(BuildContext context, WidgetRef ref) async {
    await ref.read(walletSessionProvider.notifier).disconnect();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        (route) => false,
      );
    }
  }
}

class _BalanceStat extends StatelessWidget {
  const _BalanceStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody({
    required this.circles,
    required this.session,
    required this.scheme,
    required this.textTheme,
  });

  final List<Circle> circles;
  final WalletSession session;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final sorted = [...circles]..sort(
        (a, b) => a.currentRoundDeadline.compareTo(b.currentRoundDeadline),
      );
    final featured = sorted.isNotEmpty ? sorted.first : null;
    final rest = sorted.skip(1).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      children: [
        _GreetingCard(circles: circles, session: session, scheme: scheme, textTheme: textTheme),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text('Active Circles', style: textTheme.titleLarge),
                const SizedBox(width: 8),
                _CountBadge(count: circles.length, scheme: scheme, textTheme: textTheme),
              ],
            ),
            TextButton(
              onPressed: () => _showComingSoon(context, 'Circle history is coming soon.'),
              child: Text('History', style: textTheme.labelLarge?.copyWith(color: scheme.primary)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (circles.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text('No circles yet. Create one to get started.', style: textTheme.bodyMedium),
          )
        else ...[
          if (featured != null) _FeaturedCircleCard(circle: featured, scheme: scheme, textTheme: textTheme),
          for (final circle in rest) ...[
            const SizedBox(height: 16),
            _CompactCircleCard(circle: circle, scheme: scheme, textTheme: textTheme),
          ],
        ],
        const SizedBox(height: 20),
        _InviteCard(scheme: scheme, textTheme: textTheme),
      ],
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count, required this.scheme, required this.textTheme});

  final int count;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: scheme.surfaceContainerHighest, shape: BoxShape.circle),
      child: Text('$count', style: textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
    );
  }
}

class _GreetingCard extends StatelessWidget {
  const _GreetingCard({
    required this.circles,
    required this.session,
    required this.scheme,
    required this.textTheme,
  });

  final List<Circle> circles;
  final WalletSession session;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final totalRotating = circles.fold<double>(0, (sum, c) => sum + c.potTotalUsdc);
    final weeklyFlow = circles
        .where((c) => c.frequency == ContributionFrequency.weekly)
        .fold<double>(0, (sum, c) => sum + c.contributionAmountUsdc);
    final circlesNeedingAttention =
        circles.where((c) => c.members.any((m) => m.status == MemberPaymentStatus.overdue)).length;
    final name = _greetingFirstName(circles, session);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surfaceCard,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 14, offset: const Offset(0, 3)),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              bottom: -30,
              child: _glow(scheme.secondaryContainer.withValues(alpha: 0.25), 130),
            ),
            Positioned(left: -30, top: -30, child: _glow(scheme.primary.withValues(alpha: 0.08), 110)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ékàábò, $name 👋',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.headlineLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${circles.length} active circle${circles.length == 1 ? '' : 's'} • '
                            '${circlesNeedingAttention > 0 ? '$circlesNeedingAttention '
                                '${circlesNeedingAttention == 1 ? 'circle needs' : 'circles need'} attention' : 'All contributions on track'}',
                            style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: scheme.primaryFixed, shape: BoxShape.circle),
                      child: Icon(Icons.verified_user, color: scheme.onPrimaryFixed),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              'TOTAL SAVED & ROTATING',
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ),
                          if (weeklyFlow > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: scheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.trending_up, size: 14, color: scheme.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    '+\$${weeklyFlow.toStringAsFixed(0)} this week',
                                    style: textTheme.labelSmall?.copyWith(color: scheme.primary),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '\$${totalRotating.toStringAsFixed(2)}',
                            style: AppTheme.numericCurrency.copyWith(color: scheme.primary),
                          ),
                          const SizedBox(width: 6),
                          Text('USDC', style: textTheme.titleMedium?.copyWith(color: scheme.onSurfaceVariant)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _glow(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _FeaturedCircleCard extends StatelessWidget {
  const _FeaturedCircleCard({required this.circle, required this.scheme, required this.textTheme});

  final Circle circle;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: scheme.surfaceCard,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => CircleDetailScreen(circleId: circle.id)),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 3)),
            ],
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(circle.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: textTheme.titleLarge),
                        Text(
                          '\$${circle.contributionAmountUsdc.toStringAsFixed(0)} USDC • '
                          '${_frequencyLabel(circle.frequency)}',
                          style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _fundingStatusPill(circle, scheme, textTheme),
                ],
              ),
              const SizedBox(height: 12),
              RotationRing(
                circle: circle,
                center: _CurrentTurnCenter(circle: circle, scheme: scheme, textTheme: textTheme),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.schedule, size: 20, color: scheme.secondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Next Pot Payout',
                            style: textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                          Text(formatCountdown(circle.currentRoundDeadline), style: textTheme.labelLarge),
                        ],
                      ),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                      ),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => ContributeScreen(circle: circle)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Contribute'),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward, size: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurrentTurnCenter extends StatelessWidget {
  const _CurrentTurnCenter({required this.circle, required this.scheme, required this.textTheme});

  final Circle circle;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final recipient = circle.currentRecipient;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 130),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'CURRENT TURN',
            style: textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant, fontSize: 9),
          ),
          Text(
            shortName(recipient.displayName),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleMedium,
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '\$${circle.potTotalUsdc.toStringAsFixed(0)}',
                style: textTheme.titleMedium?.copyWith(color: scheme.primary, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 2),
              Text('USDC', style: textTheme.labelSmall?.copyWith(color: scheme.primary, fontSize: 9)),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: scheme.surfaceContainer, borderRadius: BorderRadius.circular(999)),
            child: Text(
              'Round ${circle.currentRoundNumber} of ${circle.totalRounds}',
              style: textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant, fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactCircleCard extends StatelessWidget {
  const _CompactCircleCard({required this.circle, required this.scheme, required this.textTheme});

  final Circle circle;
  final ColorScheme scheme;
  final TextTheme textTheme;

  static const _maxAvatars = 4;
  static const _avatarStep = 26.0;

  @override
  Widget build(BuildContext context) {
    final recipient = circle.currentRecipient;
    final visible = circle.members.take(_maxAvatars).toList();
    final overflow = circle.members.length - visible.length;

    return Material(
      color: scheme.surfaceCard,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => CircleDetailScreen(circleId: circle.id)),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 3)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(circle.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: textTheme.titleLarge),
                        Text(
                          '\$${circle.contributionAmountUsdc.toStringAsFixed(0)} USDC • '
                          '${_frequencyLabel(circle.frequency)}',
                          style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _fundingStatusPill(circle, scheme, textTheme),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      height: 44,
                      width: 44 + (visible.length - 1) * _avatarStep + (overflow > 0 ? _avatarStep : 0),
                      child: Stack(
                        children: [
                          for (var i = 0; i < visible.length; i++)
                            Positioned(
                              left: i * _avatarStep,
                              child: _memberAvatar(visible[i], i, recipient),
                            ),
                          if (overflow > 0)
                            Positioned(
                              left: visible.length * _avatarStep,
                              child: Container(
                                width: 40,
                                height: 40,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: scheme.surfaceContainerHighest,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: scheme.surfaceCard, width: 2),
                                ),
                                child: Text(
                                  '+$overflow',
                                  style: textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Round ${circle.currentRoundNumber} of ${circle.totalRounds}',
                          style: textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        Text('Turn: ${shortName(recipient.displayName)}', style: textTheme.titleMedium),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.event_repeat, size: 18, color: scheme.secondary),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Next collection in ${formatRelativeDays(circle.currentRoundDeadline)}',
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '\$${circle.potTotalUsdc.toStringAsFixed(2)} Pot',
                    style: textTheme.labelLarge?.copyWith(color: scheme.primary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _memberAvatar(Member member, int index, Member recipient) {
    final isRecipient = member == recipient;
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: scheme.surfaceCard, width: 2),
        boxShadow: isRecipient
            ? [BoxShadow(color: scheme.secondaryContainer.withValues(alpha: 0.6), blurRadius: 10)]
            : null,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          InitialsAvatar(name: member.displayName, size: 36, paletteIndex: index),
          if (isRecipient)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 14,
                height: 14,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: scheme.secondary, shape: BoxShape.circle),
                child: Icon(Icons.star, size: 8, color: scheme.onSecondary),
              ),
            )
          else if (member.hasPaidCurrentRound)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 14,
                height: 14,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
                child: Icon(Icons.check, size: 8, color: scheme.onPrimary),
              ),
            ),
        ],
      ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({required this.scheme, required this.textTheme});

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
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: scheme.secondaryFixed, shape: BoxShape.circle),
                child: Icon(Icons.diversity_3, color: scheme.onSecondaryFixed),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Start or join another circle', style: textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      'Want to start a new savings group? Invite friends or join an '
                      'existing circle with an invite code.',
                      style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: scheme.surfaceCard,
                    foregroundColor: scheme.primary,
                    side: BorderSide.none,
                  ),
                  onPressed: () => _showEnterCodeDialog(context),
                  icon: const Icon(Icons.key, size: 18),
                  label: const Text('Enter Code'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _showComingSoon(context, 'Inviting friends is coming soon.'),
                  icon: const Icon(Icons.person_add, size: 18),
                  label: const Text('Invite Friends'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceCard,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.group_work,
                label: 'Circles',
                selected: true,
                scheme: scheme,
                onTap: () {},
              ),
              _NavItem(
                icon: Icons.dynamic_feed,
                label: 'Activity',
                selected: false,
                scheme: scheme,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CreateCircleScreen()),
                ),
                child: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
                  child: Icon(Icons.add, color: scheme.onPrimary),
                ),
              ),
              _NavItem(
                icon: Icons.account_balance_wallet,
                label: 'Savings',
                selected: false,
                scheme: scheme,
                onTap: () => _showComingSoon(context, 'A dedicated savings view is coming soon.'),
              ),
              _NavItem(
                icon: Icons.notifications,
                label: 'Alerts',
                selected: false,
                scheme: scheme,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.scheme,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final ColorScheme scheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
