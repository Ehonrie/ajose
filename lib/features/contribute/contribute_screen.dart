import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/initials_avatar.dart';
import '../../core/text_formatting.dart';
import '../../core/theme.dart';
import '../../models/circle.dart';

/// Contribution confirmation flow: a summary of what's being paid and to
/// whom, a biometric-gated "Confirm & Pay", then a success celebration.
///
/// The biometric confirmation itself is real (local_auth). What happens
/// after it is not: this phase has no Anchor program to build a real SPL
/// transfer against, so there's nothing to actually sign and send. The
/// success screen below is a preview of that future state — same as every
/// "Paid" badge elsewhere in this app, which comes from mock data, not a
/// real transaction. Nothing here is persisted; leaving and reopening this
/// screen resets it.
class ContributeScreen extends StatefulWidget {
  const ContributeScreen({super.key, required this.circle});

  final Circle circle;

  @override
  State<ContributeScreen> createState() => _ContributeScreenState();
}

class _ContributeScreenState extends State<ContributeScreen> {
  final _localAuth = LocalAuthentication();
  bool _confirming = false;
  bool _confirmed = false;

  @override
  Widget build(BuildContext context) {
    final circle = widget.circle;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Deposit Confirmation')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            children: [
              _RoundMetaBadge(circle: circle, scheme: scheme, textTheme: textTheme),
              const SizedBox(height: 20),
              if (!_confirmed) ...[
                _SummaryCard(circle: circle, scheme: scheme, textTheme: textTheme),
                const SizedBox(height: 20),
                _SignAndPayButton(
                  confirming: _confirming,
                  amount: circle.contributionAmountUsdc,
                  onPressed: _confirmAndPay,
                ),
              ] else
                _SuccessCard(
                  circle: circle,
                  scheme: scheme,
                  textTheme: textTheme,
                  onViewCircle: () => Navigator.of(context).pop(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmAndPay() async {
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
      // WalletService.signAndSendTransaction(session, tx.encode()). No
      // Anchor program exists yet, so there's nothing real to send — the
      // success view is a preview of the post-signing UI, not a real
      // on-chain confirmation.
      if (mounted) setState(() => _confirmed = true);
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }
}

class _RoundMetaBadge extends StatelessWidget {
  const _RoundMetaBadge({required this.circle, required this.scheme, required this.textTheme});

  final Circle circle;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.diversity_3, size: 18, color: scheme.primary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    circle.name.toUpperCase(),
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: scheme.secondaryFixed, borderRadius: BorderRadius.circular(999)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.replay, size: 13, color: scheme.onSecondaryFixed),
                const SizedBox(width: 4),
                Text(
                  'Round ${circle.currentRoundNumber} of ${circle.totalRounds}',
                  style: textTheme.labelSmall?.copyWith(color: scheme.onSecondaryFixed),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.circle, required this.scheme, required this.textTheme});

  final Circle circle;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final recipient = circle.currentRecipient;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: scheme.surfaceCard,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4)),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -40,
              top: -40,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primaryFixed.withValues(alpha: 0.2),
                ),
              ),
            ),
            Column(
              children: [
                Column(
                  children: [
                    Text(
                      'YOUR CONTRIBUTION',
                      style: textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '\$${circle.contributionAmountUsdc.toStringAsFixed(2)}',
                          style: AppTheme.numericCurrency.copyWith(color: scheme.onSurface),
                        ),
                        const SizedBox(width: 6),
                        Text('USDC', style: textTheme.titleMedium?.copyWith(color: scheme.primary)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: scheme.primaryFixed.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_user, size: 16, color: scheme.primary),
                          const SizedBox(width: 4),
                          Text(
                            '1-Click Direct Settlement',
                            style: textTheme.bodySmall?.copyWith(color: scheme.primary, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          InitialsAvatar(
                            name: recipient.displayName,
                            size: 56,
                            paletteIndex: recipient.payoutPosition,
                          ),
                          Positioned(
                            right: -2,
                            bottom: -2,
                            child: Container(
                              width: 20,
                              height: 20,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: scheme.secondaryContainer,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.star, size: 12, color: scheme.onSecondaryContainer),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              recipient.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: scheme.secondaryFixed,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Payout Recipient',
                                style: textTheme.labelSmall?.copyWith(color: scheme.onSecondaryFixed),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Receives Pot',
                            style: textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                          Text(
                            '\$${circle.potTotalUsdc.toStringAsFixed(2)}',
                            style: textTheme.titleMedium?.copyWith(color: scheme.primary, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      _ledgerRow(textTheme, scheme, 'Automated Pot Total', '\$${circle.potTotalUsdc.toStringAsFixed(2)} USDC'),
                      const SizedBox(height: 8),
                      _feeRow(textTheme, scheme),
                      const SizedBox(height: 8),
                      _ledgerRow(textTheme, scheme, 'Escrow Smart Protocol', 'Solana Non-Custodial v2'),
                      const SizedBox(height: 8),
                      _ledgerRow(
                        textTheme,
                        scheme,
                        'Pot Release Trigger',
                        '${circle.membersPaidThisRound}/${circle.members.length} Members Signed',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.shield, size: 18, color: scheme.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Automated Group Escrow', style: textTheme.labelLarge),
                            const SizedBox(height: 2),
                            Text(
                              'Protected by non-custodial smart protocol. Funds transfer '
                              'directly to ${recipient.displayName}\'s wallet upon all '
                              'confirmations.',
                              style: textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _ledgerRow(TextTheme textTheme, ColorScheme scheme, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(child: Text(label, style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant))),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold, color: scheme.onSurface),
          ),
        ),
      ],
    );
  }

  Widget _feeRow(TextTheme textTheme, ColorScheme scheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Network Processing Fee', style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(width: 4),
            Icon(Icons.bolt, size: 14, color: scheme.primary),
          ],
        ),
        Flexible(
          child: RichText(
            textAlign: TextAlign.end,
            text: TextSpan(
              style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold, color: scheme.primary),
              children: [
                const TextSpan(text: '\$0.00 '),
                TextSpan(
                  text: '(Solana Mobile Sponsored)',
                  style: textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SignAndPayButton extends StatelessWidget {
  const _SignAndPayButton({required this.confirming, required this.amount, required this.onPressed});

  final bool confirming;
  final double amount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            ),
            onPressed: confirming ? null : onPressed,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: confirming
                  ? [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: scheme.onPrimary),
                      ),
                      const SizedBox(width: 10),
                      const Text('Signing Transaction…'),
                    ]
                  : [
                      const Icon(Icons.fingerprint),
                      const SizedBox(width: 10),
                      Text('Confirm & Pay \$${amount.toStringAsFixed(2)} USDC'),
                    ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock, size: 15, color: scheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                'Authorized securely via Solana Mobile Seed Vault',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SuccessCard extends StatelessWidget {
  const _SuccessCard({
    required this.circle,
    required this.scheme,
    required this.textTheme,
    required this.onViewCircle,
  });

  final Circle circle;
  final ColorScheme scheme;
  final TextTheme textTheme;
  final VoidCallback onViewCircle;

  @override
  Widget build(BuildContext context) {
    final recipient = circle.currentRecipient;
    final currentUserAlreadyPaid = circle.currentUserMember?.hasPaidCurrentRound ?? false;
    final totalMembers = circle.members.length;
    // Locally-computed preview only — nothing here is written back to the
    // repository, so this resets if you leave and reopen the screen.
    final fundedCount =
        (circle.membersPaidThisRound + (currentUserAlreadyPaid ? 0 : 1)).clamp(0, totalMembers);
    final remaining = totalMembers - fundedCount;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: scheme.primary.withValues(alpha: 0.12), blurRadius: 24, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                _PulsingRing(color: scheme.primary),
                Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 3)),
                    ],
                  ),
                  child: Icon(Icons.check_circle, color: scheme.onPrimary, size: 36),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Payment Confirmed!', style: textTheme.headlineMedium, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(
            'You\'re all set for this round. Your contribution has been locked in the community pot.',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _receiptRow(textTheme, scheme, 'Amount Deposited', '\$${circle.contributionAmountUsdc.toStringAsFixed(2)} USDC'),
                const SizedBox(height: 8),
                _receiptRow(textTheme, scheme, 'Recipient', recipient.displayName),
                const SizedBox(height: 8),
                _receiptTimeRow(textTheme, scheme),
                const SizedBox(height: 8),
                _receiptRow(
                  textTheme,
                  scheme,
                  'Round Status',
                  '$fundedCount of $totalMembers Funded',
                  valueColor: scheme.secondary,
                ),
              ],
            ),
          ),
          if (remaining > 0) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.secondaryFixed.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Text('🎉', style: TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${shortName(recipient.displayName)} is almost at the goal!',
                          style: textTheme.titleMedium?.copyWith(color: scheme.onSecondaryFixed),
                        ),
                        Text(
                          'Only $remaining member${remaining == 1 ? '' : 's'} left to finalize '
                          'this round\'s release.',
                          style: textTheme.bodySmall?.copyWith(color: scheme.onSecondaryFixedVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: scheme.secondaryContainer,
                foregroundColor: scheme.onSecondaryContainer,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Cheer sent to ${recipient.displayName}! 🎊')),
              ),
              icon: const Icon(Icons.celebration),
              label: Text('Send Congrats to ${firstName(recipient.displayName)} 🎉'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
              onPressed: onViewCircle,
              icon: const Icon(Icons.groups),
              label: const Text('View Circle Detail'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _receiptRow(
    TextTheme textTheme,
    ColorScheme scheme,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold, color: valueColor ?? scheme.onSurface),
          ),
        ),
      ],
    );
  }

  Widget _receiptTimeRow(TextTheme textTheme, ColorScheme scheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Transaction Time', style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bolt, size: 14, color: scheme.primary),
            const SizedBox(width: 4),
            Text(
              'Confirmed in 0.4s',
              style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold, color: scheme.primary),
            ),
          ],
        ),
      ],
    );
  }
}

/// An expanding, fading ring behind the success checkmark — a "ping" pulse.
class _PulsingRing extends StatefulWidget {
  const _PulsingRing({required this.color});

  final Color color;

  @override
  State<_PulsingRing> createState() => _PulsingRingState();
}

class _PulsingRingState extends State<_PulsingRing> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return Opacity(
          opacity: (1 - t).clamp(0.0, 1.0) * 0.6,
          child: Transform.scale(
            scale: 1 + t,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color.withValues(alpha: 0.2)),
            ),
          ),
        );
      },
    );
  }
}
