import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../../models/circle.dart';

/// Contribution confirmation flow. This phase has no Anchor program to
/// build a real transfer instruction against, so "Confirm & Pay" stops
/// short of calling `WalletService.signAndSendTransaction` — everything
/// upstream of that (biometric confirmation, then the MWA sign-and-send
/// call already implemented in `WalletService`) is wired and ready for the
/// next phase to plug a real instruction into.
class ContributeScreen extends StatefulWidget {
  const ContributeScreen({super.key, required this.circle});

  final Circle circle;

  @override
  State<ContributeScreen> createState() => _ContributeScreenState();
}

class _ContributeScreenState extends State<ContributeScreen> {
  final _localAuth = LocalAuthentication();
  bool _confirming = false;

  @override
  Widget build(BuildContext context) {
    final circle = widget.circle;

    return Scaffold(
      appBar: AppBar(title: const Text('Contribute')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(circle.name, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(
                      'You are about to contribute '
                      '\$${circle.contributionAmountUsdc.toStringAsFixed(2)} USDC '
                      'to this round\'s pot.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _confirming ? null : () => _confirmAndPay(context),
              icon: _confirming
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.fingerprint),
              label: Text(_confirming ? 'Confirming…' : 'Confirm & Pay'),
            ),
            const SizedBox(height: 8),
            Text(
              'Transaction signing is not wired up yet — this build phase only '
              'covers wallet connect and balance reads. Once the Anchor program '
              'exists, this button will sign and send the real contribution '
              'transfer via Mobile Wallet Adapter.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAndPay(BuildContext context) async {
    setState(() => _confirming = true);
    try {
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      if (canCheckBiometrics || isDeviceSupported) {
        final authenticated = await _localAuth.authenticate(
          localizedReason: 'Confirm this contribution',
          biometricOnly: false,
        );
        if (!authenticated) return;
      }
      // TODO(next phase): build the SPL-token transfer instruction against
      // the circle's on-chain pool account, then call
      // WalletService.signAndSendTransaction(session, tx.encode()).
      if (context.mounted) {
        showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Not available yet'),
            content: const Text(
              'Signing and sending the contribution requires the circle\'s '
              'Anchor program, which is not deployed in this build phase. '
              'Wallet connection and biometric confirmation above are already '
              'fully wired for when it lands.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }
}
