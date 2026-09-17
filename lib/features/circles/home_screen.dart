import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/providers.dart';
import '../../models/circle.dart';
import '../create_circle/create_circle_screen.dart';
import '../onboarding/onboarding_screen.dart';
import 'circle_detail_screen.dart';

/// Landing screen once a wallet is connected: proof the wallet + RPC
/// plumbing works (pubkey + live devnet balances up top), then the list of
/// circles the user is part of (mock data this phase).
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajose'),
        actions: [
          IconButton(
            tooltip: 'Disconnect wallet',
            icon: const Icon(Icons.logout),
            onPressed: () => _disconnect(context, ref),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(walletBalancesProvider);
          ref.invalidate(myCirclesProvider);
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            _WalletCard(address: session.address, truncated: session.truncatedAddress),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Text(
                'Your circles',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            circlesAsync.when(
              data: (circles) => circles.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No circles yet. Create one to get started.'),
                    )
                  : Column(
                      children: [
                        for (final circle in circles)
                          _CircleTile(
                            circle: circle,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => CircleDetailScreen(circleId: circle.id),
                              ),
                            ),
                          ),
                      ],
                    ),
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load circles: $e'),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CreateCircleScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('New circle'),
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

class _WalletCard extends ConsumerWidget {
  const _WalletCard({required this.address, required this.truncated});

  final String address;
  final String truncated;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balancesAsync = ref.watch(walletBalancesProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_balance_wallet,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(truncated, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        AppConfig.cluster.label,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            balancesAsync.when(
              data: (balances) => Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _BalanceStat(
                    label: 'SOL',
                    value: balances == null ? '—' : balances.sol.toStringAsFixed(4),
                  ),
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
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        ),
      ),
    );
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

class _CircleTile extends StatelessWidget {
  const _CircleTile({required this.circle, required this.onTap});

  final Circle circle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(child: Text(circle.members.length.toString())),
        title: Text(circle.name),
        subtitle: Text(
          '\$${circle.contributionAmountUsdc.toStringAsFixed(0)} USDC · '
          'next round ${_formatDate(circle.nextRoundDate)}',
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  static String _formatDate(DateTime date) {
    final diff = date.difference(DateTime.now()).inDays;
    if (diff <= 0) return 'today';
    if (diff == 1) return 'tomorrow';
    return 'in $diff days';
  }
}
