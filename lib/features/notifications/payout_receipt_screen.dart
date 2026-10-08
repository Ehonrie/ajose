import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/date_formatting.dart';
import '../../core/theme.dart';
import '../../models/circle.dart';

/// A receipt for a circle's most recent on-chain payout — built straight
/// from the `Circle` account's own `last_payout_*` fields, which the
/// program sets atomically the moment the payout transfer lands. There's no
/// separate receipts store; this is just a focused view of state that
/// already exists.
class PayoutReceiptScreen extends StatelessWidget {
  const PayoutReceiptScreen({super.key, required this.circle});

  final Circle circle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final recipient = circle.lastPayoutRecipientMember;
    final paidAt = circle.lastPayoutAt;
    final skipped = circle.lastPayoutAmountUsdc <= 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Receipt')),
      body: SafeArea(
        child: paidAt == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'No payout has happened in this circle yet.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium,
                  ),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: scheme.surfaceCard,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: scheme.secondaryFixed, shape: BoxShape.circle),
                            child: Icon(
                              skipped ? Icons.event_busy : Icons.receipt_long,
                              color: scheme.secondary,
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            skipped ? 'Round skipped' : '+\$${circle.lastPayoutAmountUsdc.toStringAsFixed(2)} USDC',
                            style: textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: skipped ? scheme.onSurface : scheme.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Round ${circle.completedRounds} of ${circle.totalRounds} · ${circle.name}',
                            style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: scheme.surfaceCard,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ReceiptRow(
                            label: skipped ? "Scheduled recipient" : 'Recipient',
                            value: recipient?.isCurrentUser == true ? 'You' : (recipient?.displayName ?? 'Unknown'),
                          ),
                          _ReceiptRow(label: 'Wallet', value: recipient?.truncatedPubkey ?? '—'),
                          _ReceiptRow(label: 'Settled', value: '${formatWeekdayDate(paidAt)} · ${_formatTime(paidAt)}'),
                          _ReceiptRow(
                            label: 'Status',
                            value: skipped ? 'No contributions — round skipped' : 'Confirmed on-chain',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: circle.id));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Circle address copied — paste it into Solana Explorer (devnet) to verify'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy_outlined, size: 18),
                      label: const Text('Copy circle address'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  static String _formatTime(DateTime d) {
    final hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final minute = d.minute.toString().padLeft(2, '0');
    final period = d.hour < 12 ? 'AM' : 'PM';
    return '$hour12:$minute $period';
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
          Text(value, style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
