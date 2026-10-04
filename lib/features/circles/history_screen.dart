import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/date_formatting.dart';
import '../../core/providers.dart';
import '../../models/circle.dart';
import 'circle_detail_screen.dart';

/// One thing that happened in one of the user's circles: launching it, or a
/// member contributing to it. Derived entirely from [Circle]/[Member] data
/// already on-chain — there's no separate event log, so this is rebuilt
/// fresh from whatever `myCirclesProvider` currently holds every time the
/// screen opens.
class _HistoryEvent {
  const _HistoryEvent({
    required this.time,
    required this.circleId,
    required this.circleName,
    required this.description,
    required this.icon,
  });

  final DateTime time;
  final String circleId;
  final String circleName;
  final String description;
  final IconData icon;
}

List<_HistoryEvent> _buildEvents(List<Circle> circles) {
  final events = <_HistoryEvent>[];
  for (final circle in circles) {
    events.add(
      _HistoryEvent(
        time: circle.createdAt,
        circleId: circle.id,
        circleName: circle.name,
        description: 'Launched "${circle.name}"',
        icon: Icons.celebration_outlined,
      ),
    );
    for (final member in circle.members) {
      final paidAt = member.paidAt;
      if (paidAt == null) continue;
      events.add(
        _HistoryEvent(
          time: paidAt,
          circleId: circle.id,
          circleName: circle.name,
          description:
              '${member.displayName} contributed \$${circle.contributionAmountUsdc.toStringAsFixed(0)} '
              'to "${circle.name}"',
          icon: Icons.volunteer_activism_outlined,
        ),
      );
    }
  }
  events.sort((a, b) => b.time.compareTo(a.time));
  return events;
}

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final circlesAsync = ref.watch(myCirclesProvider);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(myCirclesProvider),
        child: circlesAsync.when(
          data: (circles) {
            final events = _buildEvents(circles);
            if (events.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 80),
                  Icon(Icons.history, size: 40, color: scheme.onSurfaceVariant),
                  const SizedBox(height: 12),
                  Text(
                    'Nothing here yet',
                    textAlign: TextAlign.center,
                    style: textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Launching a circle or contributing to one will show up here.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              itemCount: events.length,
              separatorBuilder: (_, _) => Divider(height: 1, color: scheme.outlineVariant),
              itemBuilder: (context, index) {
                final event = events[index];
                return InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => CircleDetailScreen(circleId: event.circleId)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(event.icon, size: 20, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(event.description, style: textTheme.bodyMedium),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formatRelativeTime(event.time),
                          style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Could not load history: $e')),
        ),
      ),
    );
  }
}
