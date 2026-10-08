import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/circle.dart';
import '../../services/anchor_service.dart';
import '../../services/wallet_service.dart';
import '../circles/circle_detail_screen.dart';

/// Previews a real circle by its on-chain address (typed in, pasted, or
/// scanned from its QR) and claims the first open seat for the connected
/// wallet via the program's own `join_circle` instruction.
class JoinCircleScreen extends ConsumerStatefulWidget {
  const JoinCircleScreen({super.key, required this.circleId});

  final String circleId;

  @override
  ConsumerState<JoinCircleScreen> createState() => _JoinCircleScreenState();
}

class _JoinCircleScreenState extends ConsumerState<JoinCircleScreen> {
  bool _joining = false;

  @override
  Widget build(BuildContext context) {
    final circleAsync = ref.watch(circleByIdProvider(widget.circleId));

    return Scaffold(
      appBar: AppBar(title: const Text('Join Circle')),
      body: circleAsync.when(
        data: (circle) {
          if (circle == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No circle found at that address. Double-check the code or QR and try again.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            );
          }
          return _JoinCircleBody(
            circle: circle,
            joining: _joining,
            onJoin: () => _join(circle),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load circle: $e')),
      ),
    );
  }

  Future<void> _join(Circle circle) async {
    final session = ref.read(walletSessionProvider).value;
    if (session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connect your wallet first.')),
      );
      return;
    }

    final seatIndex = circle.members.indexWhere((m) => m.pubkey.isEmpty);
    if (seatIndex == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This circle is already full.')),
      );
      return;
    }
    if (circle.members.any((m) => m.pubkey == session.address)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You already have a seat in this circle.')),
      );
      return;
    }

    setState(() => _joining = true);
    try {
      final anchor = ref.read(anchorServiceProvider);
      final txBytes = await anchor.buildJoinCircleTransaction(
        joiningWallet: session.publicKey,
        circleId: circle.id,
        seatIndex: seatIndex,
        collateralAmountUsdc: circle.collateralAmountUsdc,
      );

      final walletService = ref.read(walletServiceProvider);
      await walletService.signAndSendTransaction(session, txBytes);

      ref.invalidate(myCirclesProvider);
      ref.invalidate(circleByIdProvider(circle.id));

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => CircleDetailScreen(circleId: circle.id)),
        );
      }
    } catch (e) {
      if (mounted) {
        final message = e is WalletException || e is AnchorException ? e.toString() : 'Could not join circle: $e';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }
}

class _JoinCircleBody extends StatelessWidget {
  const _JoinCircleBody({required this.circle, required this.joining, required this.onJoin});

  final Circle circle;
  final bool joining;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final openSeats = circle.members.where((m) => m.pubkey.isEmpty).length;
    final filledSeats = circle.members.length - openSeats;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: scheme.surfaceCard, borderRadius: BorderRadius.circular(20)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(circle.name, style: textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(
                '\$${circle.contributionAmountUsdc.toStringAsFixed(0)} USDC • ${_frequencyLabel(circle.frequency)}',
                style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.groups, size: 18, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text(
                    '$filledSeats of ${circle.members.length} seats filled',
                    style: textTheme.bodyMedium,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: scheme.primaryFixed.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(Icons.verified_user, size: 18, color: scheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        openSeats > 0
                            ? 'Joining claims the next open seat and pays this round\'s '
                                '\$${circle.contributionAmountUsdc.toStringAsFixed(0)} USDC contribution in the '
                                'same transaction. Your payout turn follows the same on-chain rules as every '
                                'other member.'
                            : 'This circle has no open seats left.',
                        style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
              if (circle.requiresCollateral && openSeats > 0) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: scheme.secondaryFixed.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lock_outline, size: 18, color: scheme.secondary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'This circle also requires a \$${circle.collateralAmountUsdc.toStringAsFixed(2)} USDC '
                          'collateral bond to join — refunded once the circle finishes, minus anything forfeited '
                          'to cover a missed round of your own.',
                          style: textTheme.bodySmall?.copyWith(color: scheme.onSecondaryFixedVariant),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: (joining || openSeats == 0) ? null : onJoin,
          icon: joining
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: scheme.onPrimary),
                )
              : const Icon(Icons.group_add),
          label: Text(
            joining
                ? 'Joining…'
                : 'Join & Pay \$${(circle.contributionAmountUsdc + circle.collateralAmountUsdc).toStringAsFixed(2)} USDC',
          ),
        ),
      ],
    );
  }
}

String _frequencyLabel(ContributionFrequency frequency) => switch (frequency) {
      ContributionFrequency.weekly => 'Weekly',
      ContributionFrequency.biweekly => 'Bi-weekly',
      ContributionFrequency.monthly => 'Monthly',
      ContributionFrequency.testFast => 'Every 10 min',
    };
