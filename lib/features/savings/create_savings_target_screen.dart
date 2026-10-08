import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/date_formatting.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../services/anchor_service.dart';
import '../../services/wallet_service.dart';

/// Creates a new time-locked savings target: a label, an unlock date, and
/// optionally a goal amount and an opening deposit. When an opening deposit
/// is given, creating and funding the target happen in one transaction —
/// one wallet approval, not two.
class CreateSavingsTargetScreen extends ConsumerStatefulWidget {
  const CreateSavingsTargetScreen({super.key});

  @override
  ConsumerState<CreateSavingsTargetScreen> createState() => _CreateSavingsTargetScreenState();
}

class _CreateSavingsTargetScreenState extends ConsumerState<CreateSavingsTargetScreen> {
  final _labelController = TextEditingController();
  final _targetController = TextEditingController();
  final _depositController = TextEditingController();
  DateTime? _unlockAt;
  bool _submitting = false;

  @override
  void dispose() {
    _labelController.dispose();
    _targetController.dispose();
    _depositController.dispose();
    super.dispose();
  }

  Future<void> _pickUnlockDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 30)),
      firstDate: now.add(const Duration(minutes: 1)),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
    );
    if (!mounted) return;

    setState(() {
      _unlockAt = DateTime(date.year, date.month, date.day, time?.hour ?? 0, time?.minute ?? 0);
    });
  }

  Future<void> _submit() async {
    final label = _labelController.text.trim();
    final unlockAt = _unlockAt;

    if (label.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Give this target a name.')),
      );
      return;
    }
    if (unlockAt == null || !unlockAt.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick an unlock date in the future.')),
      );
      return;
    }

    final session = ref.read(walletSessionProvider).value;
    if (session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connect your wallet first.')),
      );
      return;
    }

    final targetAmount = double.tryParse(_targetController.text.trim()) ?? 0;
    final initialDeposit = double.tryParse(_depositController.text.trim()) ?? 0;

    setState(() => _submitting = true);
    try {
      final anchor = ref.read(anchorServiceProvider);
      final result = await anchor.buildCreateSavingsTargetTransaction(
        owner: session.publicKey,
        label: label,
        unlockAt: unlockAt,
        targetAmountUsdc: targetAmount,
        initialDepositUsdc: initialDeposit,
      );

      final walletService = ref.read(walletServiceProvider);
      final signature = await walletService.signAndSendTransaction(session, result.transactionBytes);

      try {
        final rpc = ref.read(rpcServiceProvider);
        await rpc.waitForSignatureStatus(signature);
      } catch (_) {
        // Best-effort — see ContributeScreen for why this doesn't mean the
        // transaction itself failed.
      }

      ref.invalidate(mySavingsTargetsProvider);
      if (initialDeposit > 0) ref.invalidate(walletBalancesProvider);

      if (mounted) Navigator.of(context).pop();
    } on AnchorException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } on WalletException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create savings target: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('New Savings Target')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('What are you saving for?', style: textTheme.titleMedium),
              const SizedBox(height: 10),
              TextField(
                controller: _labelController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'e.g. Rent, Waec fees, New phone',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              Text('When can you withdraw?', style: textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                'Deposits are allowed anytime before this date. Withdrawals only after.',
                style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: _pickUnlockDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: scheme.surfaceCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lock_clock_outlined, color: scheme.secondary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _unlockAt == null
                              ? 'Choose a date and time'
                              : '${formatWeekdayDate(_unlockAt!)} · ${_formatTime(_unlockAt!)}',
                          style: textTheme.bodyLarge,
                        ),
                      ),
                      Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('Goal amount', style: textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Optional — leave blank for an open-ended target.',
                style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _targetController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(prefixText: '\$ ', hintText: '0.00', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 24),
              Text('Deposit now', style: textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Optional — fund it right away, or come back and add to it later.',
                style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _depositController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(prefixText: '\$ ', hintText: '0.00', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: scheme.onPrimary),
                        )
                      : const Icon(Icons.lock_outline),
                  label: Text(_submitting ? 'Creating…' : 'Create Savings Target'),
                ),
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
