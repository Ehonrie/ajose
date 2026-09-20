import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/date_formatting.dart';
import '../../core/initials_avatar.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/circle.dart';
import '../../models/invite.dart';
import 'slot_swap_sheet.dart';

/// Previews a circle from an invite code before the user commits to a
/// seat. Reached from Home's "Enter Code" action.
///
/// Joining doesn't touch the chain yet — there's no Anchor program to
/// submit a join-circle instruction against, so accepting here shows a
/// confirmation state but doesn't add anything to [MockCircleRepository].
/// The next phase wires this button to a real instruction the same way
/// Contribute's "Confirm & Pay" is already wired to `WalletService`.
class JoinInviteScreen extends ConsumerStatefulWidget {
  const JoinInviteScreen({super.key, required this.code});

  final String code;

  @override
  ConsumerState<JoinInviteScreen> createState() => _JoinInviteScreenState();
}

class _JoinInviteScreenState extends ConsumerState<JoinInviteScreen> {
  bool _joining = false;
  bool _joined = false;

  @override
  Widget build(BuildContext context) {
    final inviteAsync = ref.watch(inviteByCodeProvider(widget.code));

    return Scaffold(
      appBar: AppBar(title: const Text('Join Via Invite')),
      body: inviteAsync.when(
        data: (invite) {
          if (invite == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('This invite code is invalid or has expired.'),
              ),
            );
          }
          return _JoinInviteBody(
            invite: invite,
            joining: _joining,
            joined: _joined,
            onJoin: _join,
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load invite: $e')),
      ),
    );
  }

  Future<void> _join() async {
    setState(() => _joining = true);
    await Future.delayed(const Duration(milliseconds: 700));
    if (mounted) setState(() => _joined = true);
  }
}

class _JoinInviteBody extends StatelessWidget {
  const _JoinInviteBody({
    required this.invite,
    required this.joining,
    required this.joined,
    required this.onJoin,
  });

  final CircleInvite invite;
  final bool joining;
  final bool joined;
  final VoidCallback onJoin;

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
              _InviteEyebrowChip(scheme: scheme, textTheme: textTheme),
              const SizedBox(height: 16),
              _InviterBannerCard(invite: invite, scheme: scheme, textTheme: textTheme),
              const SizedBox(height: 16),
              _CircleSpotlightCard(invite: invite, scheme: scheme, textTheme: textTheme),
              const SizedBox(height: 16),
              _MembersClusterCard(invite: invite, scheme: scheme, textTheme: textTheme),
              const SizedBox(height: 16),
              _TrustGuaranteesCard(scheme: scheme, textTheme: textTheme),
              const SizedBox(height: 16),
              _FaqRow(invite: invite, scheme: scheme, textTheme: textTheme),
            ],
          ),
        ),
        _BottomCta(
          invite: invite,
          joining: joining,
          joined: joined,
          onJoin: onJoin,
          scheme: scheme,
          textTheme: textTheme,
        ),
      ],
    );
  }
}

class _InviteEyebrowChip extends StatelessWidget {
  const _InviteEyebrowChip({required this.scheme, required this.textTheme});

  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: scheme.secondaryFixed,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_user, size: 16, color: scheme.secondary),
            const SizedBox(width: 6),
            Text(
              'PRIVATE CIRCLE INVITATION',
              style: textTheme.labelSmall?.copyWith(color: scheme.onSecondaryFixed),
            ),
          ],
        ),
      ),
    );
  }
}

class _InviterBannerCard extends StatelessWidget {
  const _InviterBannerCard({required this.invite, required this.scheme, required this.textTheme});

  final CircleInvite invite;
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
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              InitialsAvatar(name: invite.inviterName, size: 56, paletteIndex: 0),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
                  child: Icon(Icons.favorite, size: 11, color: scheme.onPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Invited by', style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                Text(invite.inviterName, style: textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Circle Leader • ${invite.inviterReliabilityLabel}',
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.labelSmall?.copyWith(color: scheme.primary),
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

class _CircleSpotlightCard extends StatelessWidget {
  const _CircleSpotlightCard({required this.invite, required this.scheme, required this.textTheme});

  final CircleInvite invite;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final yourSeat = invite.yourSeat;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4))],
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
                    Text(
                      invite.circleCategory.toUpperCase(),
                      style: textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    Text(invite.circleName, style: textTheme.headlineLarge),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${invite.filledSeats} of ${invite.totalSeats} seats filled',
                  style: textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your Contribution', style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                      const SizedBox(height: 4),
                      Text(
                        '\$${invite.contributionAmountUsdc.toStringAsFixed(2)}',
                        style: textTheme.headlineMedium?.copyWith(color: scheme.primary),
                      ),
                      Text(
                        'USDC / ${_frequencyLabel(invite.frequency)}',
                        style: textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: scheme.secondaryFixed.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lump Sum Payout',
                        style: textTheme.bodySmall?.copyWith(color: scheme.secondary, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '\$${invite.lumpSumPayoutUsdc.toStringAsFixed(2)}',
                        style: textTheme.headlineMedium?.copyWith(color: scheme.onSecondaryFixed),
                      ),
                      Text(
                        'USDC full pot',
                        style: textTheme.labelSmall?.copyWith(color: scheme.secondary, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.secondaryFixed.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.stars, size: 20, color: scheme.secondary),
                        const SizedBox(width: 6),
                        Text('Your Reserved Slot', style: textTheme.labelLarge?.copyWith(color: scheme.secondary)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: scheme.secondary, borderRadius: BorderRadius.circular(6)),
                      child: Text(
                        'Turn ${invite.yourTurnNumber} of ${invite.totalSeats}',
                        style: textTheme.labelSmall?.copyWith(color: scheme.onSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            formatWeekdayDate(yourSeat.turnDate!),
                            style: textTheme.headlineMedium,
                          ),
                          Text(
                            'Full \$${invite.lumpSumPayoutUsdc.toStringAsFixed(2)} pot delivered direct to you',
                            style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: scheme.secondary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.savings, color: scheme.secondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _RotationTimeline(invite: invite, scheme: scheme, textTheme: textTheme),
        ],
      ),
    );
  }

  static String _frequencyLabel(ContributionFrequency frequency) {
    return switch (frequency) {
      ContributionFrequency.weekly => 'weekly',
      ContributionFrequency.biweekly => 'bi-weekly',
      ContributionFrequency.monthly => 'monthly',
    };
  }
}

class _RotationTimeline extends StatelessWidget {
  const _RotationTimeline({required this.invite, required this.scheme, required this.textTheme});

  final CircleInvite invite;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'CIRCLE ROTATION TIMELINE',
              style: textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            Text(
              '${invite.totalSeats} ${_unitLabel(invite.frequency)} Total',
              style: textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final seat in invite.seats) ...[
              Expanded(child: _segment(seat)),
              if (seat != invite.seats.last) const SizedBox(width: 6),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Turn 1', style: textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
            Text(
              'Turn ${invite.yourTurnNumber} (You)',
              style: textTheme.labelSmall?.copyWith(color: scheme.secondary, fontWeight: FontWeight.bold),
            ),
            Text('Turn ${invite.totalSeats}', style: textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
          ],
        ),
      ],
    );
  }

  Widget _segment(InviteSeat seat) {
    final Color color = switch (seat.status) {
      SeatStatus.completed => scheme.primary,
      SeatStatus.current => scheme.secondaryContainer,
      SeatStatus.reservedForYou => scheme.secondary,
      SeatStatus.open => scheme.surfaceContainerHighest,
    };
    final isYours = seat.status == SeatStatus.reservedForYou;
    return Container(
      height: isYours ? 12 : 8,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        boxShadow: isYours ? [BoxShadow(color: scheme.secondary.withValues(alpha: 0.4), blurRadius: 4)] : null,
      ),
    );
  }

  static String _unitLabel(ContributionFrequency f) => switch (f) {
        ContributionFrequency.weekly => 'Weeks',
        ContributionFrequency.biweekly => 'Fortnights',
        ContributionFrequency.monthly => 'Months',
      };
}

class _MembersClusterCard extends StatelessWidget {
  const _MembersClusterCard({required this.invite, required this.scheme, required this.textTheme});

  final CircleInvite invite;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    // The inviter (turn 1) already has prominent placement above, so the
    // grid covers the remaining seats — every one of them, so the seat
    // count here always matches the "N of M filled" figure above it.
    final otherSeats = invite.seats.where((s) => s.turnNumber != 1).toList();

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Circle Members', style: textTheme.titleMedium),
                    Text(
                      'Reliable kinfolk and trusted family circle',
                      style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Verified Group',
                  style: textTheme.labelSmall?.copyWith(color: scheme.primary, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 2.6,
            children: [for (final seat in otherSeats) _seatCard(seat)],
          ),
        ],
      ),
    );
  }

  Widget _seatCard(InviteSeat seat) {
    if (seat.status == SeatStatus.reservedForYou) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: scheme.secondaryFixed.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: scheme.secondary, shape: BoxShape.circle),
              child: Text(
                'YOU',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: scheme.onSecondary),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Your Reserved Seat',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelLarge?.copyWith(color: scheme.onSecondaryFixed, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Turn ${seat.turnNumber}',
                    style: textTheme.labelSmall?.copyWith(color: scheme.secondary, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (seat.status == SeatStatus.open) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: scheme.surfaceContainerHighest, shape: BoxShape.circle),
              child: Icon(Icons.person_add, size: 18, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '1 Open Seat',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  Text(
                    'Turn ${seat.turnNumber}',
                    style: textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final name = seat.memberName ?? 'Member';
    final isCurrent = seat.status == SeatStatus.current;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(color: scheme.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              InitialsAvatar(name: name, size: 36, paletteIndex: seat.turnNumber),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 14,
                  height: 14,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isCurrent ? scheme.secondaryContainer : scheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isCurrent ? Icons.hourglass_top : Icons.check,
                    size: 9,
                    color: isCurrent ? scheme.onSecondaryContainer : scheme.onPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: textTheme.labelLarge),
                Text(
                  isCurrent ? 'Current • Turn ${seat.turnNumber}' : 'Active • Turn ${seat.turnNumber}',
                  style: textTheme.labelSmall?.copyWith(
                    color: isCurrent ? scheme.secondary : scheme.primary,
                    fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
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

class _TrustGuaranteesCard extends StatelessWidget {
  const _TrustGuaranteesCard({required this.scheme, required this.textTheme});

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
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Icon(Icons.lock, size: 18, color: scheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Circle Protection & Guarantees', style: textTheme.titleMedium),
                    Text(
                      'Safe, honest, automated community fund',
                      style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _guarantee(
            Icons.check_circle,
            'Protected Group Escrow',
            'Every contribution lands in an automated vault. No single '
                'member or organizer can access or hold communal cash.',
          ),
          const SizedBox(height: 12),
          _guarantee(
            Icons.verified,
            'Punctual Rotation Guarantee',
            'Each payout turn is designed to distribute directly to your '
                'confirmed wallet on the scheduled date.',
          ),
          const SizedBox(height: 12),
          _guarantee(
            Icons.history,
            'Transparent Ledger',
            'All contributions and clearances are visible to every member '
                'instantly.',
          ),
        ],
      ),
    );
  }

  Widget _guarantee(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 20, color: scheme.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: textTheme.labelLarge),
              Text(
                description,
                style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FaqRow extends StatelessWidget {
  const _FaqRow({required this.invite, required this.scheme, required this.textTheme});

  final CircleInvite invite;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => showSlotSwapSheet(context, invite),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: scheme.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Icon(Icons.help_outline, color: scheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Need to swap your turn slot?', style: textTheme.labelLarge),
                  Text(
                    'You can request a slot swap after joining',
                    style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _BottomCta extends StatelessWidget {
  const _BottomCta({
    required this.invite,
    required this.joining,
    required this.joined,
    required this.onJoin,
    required this.scheme,
    required this.textTheme,
  });

  final CircleInvite invite;
  final bool joining;
  final bool joined;
  final VoidCallback onJoin;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: scheme.backgroundWarm,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
              onPressed: joining || joined ? null : onJoin,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: switch ((joining, joined)) {
                  (true, _) => [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: scheme.onPrimary),
                      ),
                      const SizedBox(width: 10),
                      Text('Securing Turn ${invite.yourTurnNumber} Slot…'),
                    ],
                  (_, true) => [
                      const Icon(Icons.check_circle),
                      const SizedBox(width: 10),
                      Text('Welcome to ${invite.circleName}!'),
                    ],
                  _ => const [
                      Text('Join Circle & Accept Slot'),
                      SizedBox(width: 10),
                      Icon(Icons.arrow_forward),
                    ],
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            joined
                ? 'You\'re on the list — the organizer will confirm your seat soon.'
                : 'No money deducted today • First contribution due '
                    '${formatShortDate(invite.firstContributionDueDate)}',
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
