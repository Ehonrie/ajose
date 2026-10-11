import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/countdown_text.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/mwa_session_manager.dart';
import '../../models/savings_target.dart';
import '../../services/anchor_service.dart';
import '../../services/wallet_service.dart';
import 'create_savings_target_screen.dart';

/// Personal, time-locked USDC vaults — separate from circles. A target has
/// a label and an unlock date; deposits land anytime, a withdrawal only
/// once that date passes. A locked target reads in the brand's gold
/// (`scheme.secondary`) — the same "muted means not actionable yet" signal
/// already used for overdue/pending states elsewhere in the app — and
/// flips to the vivid primary green the moment it unlocks.
class SavingsScreen extends ConsumerWidget {
  const SavingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final targetsAsync = ref.watch(mySavingsTargetsProvider);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Savings')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(mySavingsTargetsProvider),
        child: targetsAsync.when(
          data: (targets) => _SavingsBody(targets: targets, scheme: scheme, textTheme: textTheme),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Could not load savings: $e'),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CreateSavingsTargetScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('New Target'),
      ),
    );
  }
}

class _SavingsBody extends StatelessWidget {
  const _SavingsBody({required this.targets, required this.scheme, required this.textTheme});

  final List<SavingsTarget> targets;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    if (targets.isEmpty) {
      return _EmptySavingsState(scheme: scheme, textTheme: textTheme);
    }

    final totalSaved = targets.fold<double>(0, (sum, t) => sum + t.balanceUsdc);
    final lockedCount = targets.where((t) => !t.isUnlocked).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        _TotalSavedCard(totalSaved: totalSaved, lockedCount: lockedCount, scheme: scheme, textTheme: textTheme),
        const SizedBox(height: 24),
        Text('Your Targets', style: textTheme.titleLarge),
        const SizedBox(height: 12),
        for (final target in targets) ...[
          _SavingsTargetCard(target: target, scheme: scheme, textTheme: textTheme),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _TotalSavedCard extends StatelessWidget {
  const _TotalSavedCard({
    required this.totalSaved,
    required this.lockedCount,
    required this.scheme,
    required this.textTheme,
  });

  final double totalSaved;
  final int lockedCount;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.secondary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: scheme.secondaryFixed, shape: BoxShape.circle),
                child: Icon(Icons.savings_rounded, color: scheme.onSecondaryFixed, size: 20),
              ),
              const SizedBox(width: 10),
              Text('Total saved', style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('\$${totalSaved.toStringAsFixed(2)}', style: AppTheme.numericCurrency.copyWith(color: scheme.secondary)),
              const SizedBox(width: 6),
              Text('USDC', style: textTheme.titleMedium?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ),
          if (lockedCount > 0) ...[
            const SizedBox(height: 4),
            Text(
              '$lockedCount ${lockedCount == 1 ? 'target' : 'targets'} still locked',
              style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptySavingsState extends StatelessWidget {
  const _EmptySavingsState({required this.scheme, required this.textTheme});

  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: scheme.secondaryFixed, shape: BoxShape.circle),
              child: Icon(Icons.savings_rounded, color: scheme.onSecondaryFixed, size: 34),
            ),
            const SizedBox(height: 16),
            Text('No savings targets yet', style: textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              'Set some USDC aside, name what it\'s for, and lock it until a date you choose.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CreateSavingsTargetScreen()),
              ),
              icon: const Icon(Icons.add),
              label: const Text('New Savings Target'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavingsTargetCard extends ConsumerWidget {
  const _SavingsTargetCard({required this.target, required this.scheme, required this.textTheme});

  final SavingsTarget target;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unlocked = target.isUnlocked;
    // The one visual idea this screen leans on: the badge itself changes
    // state — a sealed gold padlock while locked, an open green one the
    // moment it isn't — rather than a separate status chip doing that job.
    final accent = unlocked ? scheme.primary : scheme.secondary;
    final badgeBg = unlocked ? scheme.primaryFixed : scheme.secondaryFixed;
    final badgeFg = unlocked ? scheme.onPrimaryFixed : scheme.onSecondaryFixed;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border(left: BorderSide(color: accent, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: badgeBg, shape: BoxShape.circle),
                child: Icon(unlocked ? Icons.lock_open_rounded : Icons.lock_rounded, color: badgeFg, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(target.label, style: textTheme.titleMedium),
                    const SizedBox(height: 2),
                    if (unlocked)
                      Text('Ready to withdraw', style: textTheme.bodySmall?.copyWith(color: scheme.primary))
                    else
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Unlocks in ', style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                          CountdownText(
                            target.unlockAt,
                            style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              Text(
                '\$${target.balanceUsdc.toStringAsFixed(2)}',
                style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: accent),
              ),
            ],
          ),
          if (target.hasGoal) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: target.progress,
                minHeight: 6,
                backgroundColor: scheme.surfaceContainerHigh,
                color: accent,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Goal: \$${target.targetAmountUsdc.toStringAsFixed(2)} USDC',
              style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showDepositDialog(context, ref),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Deposit'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                // Always shown so the layout doesn't jump when a target
                // unlocks — just disabled (null onPressed) until then,
                // rather than appearing out of nowhere.
                child: FilledButton.icon(
                  onPressed: unlocked ? () => _confirmWithdraw(context, ref) : null,
                  icon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
                  label: const Text('Withdraw'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showDepositDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final amount = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Deposit into ${target.label}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Amount (USDC)', prefixText: '\$ '),
          onSubmitted: (value) {
            FocusManager.instance.primaryFocus?.unfocus();
            Navigator.of(dialogContext).pop(double.tryParse(value));
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              FocusManager.instance.primaryFocus?.unfocus();
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              FocusManager.instance.primaryFocus?.unfocus();
              Navigator.of(dialogContext).pop(double.tryParse(controller.text));
            },
            child: const Text('Deposit'),
          ),
        ],
      ),
    );
    // Deferred rather than disposed immediately: showDialog's Future can
    // resolve before the dialog's own exit-transition finishes its final
    // frame, and that frame still rebuilds a TextField bound to this
    // controller — disposing synchronously here raced that rebuild and
    // crashed with "A TextEditingController was used after being disposed."
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());

    if (amount == null || amount <= 0 || !context.mounted) return;
    await _runTransaction(
      context,
      ref,
      build: (anchor, session) => anchor.buildDepositSavingsTransaction(
        owner: session.publicKey,
        savingsTarget: target,
        amountUsdc: amount,
      ),
      successMessage: 'Deposited \$${amount.toStringAsFixed(2)} into ${target.label}.',
    );
  }

  Future<void> _confirmWithdraw(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Withdraw savings'),
        content: Text(
          'This sends \$${target.balanceUsdc.toStringAsFixed(2)} USDC from "${target.label}" to your wallet '
          'and closes this target out.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Withdraw')),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    await _runTransaction(
      context,
      ref,
      build: (anchor, session) => anchor.buildWithdrawSavingsTransaction(
        owner: session.publicKey,
        savingsTarget: target,
      ),
      successMessage: '${target.label} withdrawn.',
    );
  }

  Future<void> _runTransaction(
    BuildContext context,
    WidgetRef ref, {
    required Future<List<int>> Function(AnchorService anchor, WalletSession session) build,
    required String successMessage,
  }) async {
    final session = ref.read(walletSessionProvider).value;
    if (session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connect your wallet first.')),
      );
      return;
    }

    try {
      final anchor = ref.read(anchorServiceProvider);
      final txBytes = await build(anchor, session);

      final walletService = ref.read(walletServiceProvider);
      final signature = await walletService.signAndSendTransaction(session, txBytes);

      try {
        final rpc = ref.read(rpcServiceProvider);
        await rpc.waitForSignatureStatus(signature);
      } catch (_) {
        // Best-effort confirmation wait — see ContributeScreen for why a
        // failure here doesn't mean the transaction itself failed.
      }

      ref.invalidate(mySavingsTargetsProvider);
      ref.invalidate(walletBalancesProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMessage)));
      }
    } catch (e) {
      final message = e is WalletException || e is AnchorException ? e.toString() : 'Something went wrong: $e';
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }
}
