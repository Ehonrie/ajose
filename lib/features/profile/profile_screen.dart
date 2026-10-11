import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/mwa_session_manager.dart';
import '../../core/providers.dart';
import '../circles/send_sol_sheet.dart';
import '../onboarding/onboarding_screen.dart';

/// Wallet identity and balances — a full tab now (was a bottom sheet off
/// Home's AppBar), so it stays reachable alongside Circles/Savings/Activity
/// rather than needing its own trigger button up top.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(walletSessionProvider).value;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: session == null
          ? const SizedBox.shrink()
          : SafeArea(
              child: RefreshIndicator(
                onRefresh: () async => ref.invalidate(walletBalancesProvider),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: _ProfileBody(session: session, scheme: scheme, textTheme: textTheme),
                ),
              ),
            ),
    );
  }
}

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody({required this.session, required this.scheme, required this.textTheme});

  final WalletSession session;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balancesAsync = ref.watch(walletBalancesProvider);
    final displayName = ref.watch(displayNameProvider).value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.account_balance_wallet, color: scheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(displayName ?? session.truncatedAddress, style: textTheme.titleMedium),
                  Text(AppConfig.cluster.label, style: textTheme.bodySmall),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Edit name',
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: () => _showEditNameDialog(context, ref, displayName),
            ),
            IconButton(
              tooltip: 'Copy address',
              icon: const Icon(Icons.copy, size: 20),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: session.address));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Address copied')),
                );
              },
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
          child: FilledButton.icon(
            onPressed: () => SendSolSheet.show(context, session),
            icon: const Icon(Icons.send_rounded),
            label: const Text('Send SOL'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _disconnect(context, ref),
            icon: const Icon(Icons.logout),
            label: const Text('Disconnect Wallet'),
          ),
        ),
      ],
    );
  }

  Future<void> _showEditNameDialog(BuildContext context, WidgetRef ref, String? currentName) async {
    final controller = TextEditingController(text: currentName ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Your Name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'e.g. Ada'),
          // Unfocusing before the pop keeps the keyboard's dismiss-driven
          // rebuild from racing the Navigator tearing this dialog down in
          // the same frame — that race is what throws '_dependents.isEmpty'.
          onSubmitted: (value) {
            FocusManager.instance.primaryFocus?.unfocus();
            Navigator.of(dialogContext).pop(value);
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
            style: FilledButton.styleFrom(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () {
              FocusManager.instance.primaryFocus?.unfocus();
              Navigator.of(dialogContext).pop(controller.text);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());

    if (name == null) return;
    await ref.read(displayNameProvider.notifier).setName(name);
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
