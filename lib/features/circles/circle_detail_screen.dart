import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../models/circle.dart';
import '../contribute/contribute_screen.dart';

class CircleDetailScreen extends ConsumerWidget {
  const CircleDetailScreen({super.key, required this.circleId});

  final String circleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final circleAsync = ref.watch(circleByIdProvider(circleId));

    return Scaffold(
      appBar: AppBar(title: const Text('Circle')),
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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(circle.name, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          '${_frequencyLabel(circle.frequency)} · '
          '\$${circle.contributionAmountUsdc.toStringAsFixed(0)} USDC per member',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatRow(
                  label: 'This round\'s pot',
                  value: '\$${circle.potTotalUsdc.toStringAsFixed(0)} USDC',
                ),
                _StatRow(
                  label: 'Goes to',
                  value: circle.currentRecipient.displayName,
                ),
                _StatRow(
                  label: 'Next round',
                  value: _formatDate(circle.nextRoundDate),
                ),
                _StatRow(
                  label: 'Paid so far',
                  value: '${circle.membersPaidThisRound}/${circle.members.length} members',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text('Members', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final member in circle.members)
          Card(
            child: ListTile(
              leading: CircleAvatar(child: Text(member.displayName.characters.first)),
              title: Text(member.displayName),
              subtitle: Text(member.truncatedPubkey),
              trailing: member.hasPaidCurrentRound
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : const Icon(Icons.hourglass_empty),
            ),
          ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ContributeScreen(circle: circle)),
          ),
          icon: const Icon(Icons.payments_outlined),
          label: const Text('Contribute'),
        ),
      ],
    );
  }

  static String _frequencyLabel(ContributionFrequency f) => switch (f) {
        ContributionFrequency.weekly => 'Weekly',
        ContributionFrequency.biweekly => 'Every 2 weeks',
        ContributionFrequency.monthly => 'Monthly',
      };

  static String _formatDate(DateTime date) {
    final diff = date.difference(DateTime.now()).inDays;
    if (diff <= 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
