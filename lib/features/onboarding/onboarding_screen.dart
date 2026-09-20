import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../circles/home_screen.dart';

/// First screen a user with no active wallet session sees. A single
/// "Connect Wallet" button drives the whole MWA authorize() round trip via
/// [WalletSessionNotifier.connect]; on success it hands off to Home.
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionState = ref.watch(walletSessionProvider);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    ref.listen(walletSessionProvider, (previous, next) {
      if (next.hasValue && next.value != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    });

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              _BrandHeader(scheme: scheme, textTheme: textTheme),
              const SizedBox(height: 24),
              _IllustrationCard(scheme: scheme),
              const SizedBox(height: 24),
              _ValueHighlights(scheme: scheme, textTheme: textTheme),
              const SizedBox(height: 32),
              _ConnectWalletButton(sessionState: sessionState),
              if (sessionState.hasError) ...[
                const SizedBox(height: 12),
                Text(
                  sessionState.error.toString(),
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall?.copyWith(color: scheme.error),
                ),
              ],
              const SizedBox(height: 12),
              _NonCustodialNote(scheme: scheme, textTheme: textTheme),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.scheme, required this.textTheme});

  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 80,
              height: 80,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.surfaceCard,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.savings_rounded,
                color: scheme.primary,
                size: 40,
              ),
            ),
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.auto_awesome,
                  size: 13,
                  color: scheme.onSecondaryFixed,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: scheme.surfaceContainer,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            'COMMUNITY WEALTH REIMAGINED',
            style: textTheme.labelSmall,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Save together, grow together',
          textAlign: TextAlign.center,
          style: textTheme.headlineLarge,
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Text(
            'Transparent community savings circles with zero hassle. '
            'Rebuilding traditional Ajo and Esusu circles for modern trust '
            'and automated payouts.',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _IllustrationCard extends StatelessWidget {
  const _IllustrationCard({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _CircleIllustration(scheme: scheme),
          const SizedBox(height: 8),
          _InviteHintPill(scheme: scheme),
        ],
      ),
    );
  }
}

/// A stand-in for the design's central "pot" + orbiting member avatars
/// illustration — hand-drawn with a CustomPainter + positioned circles
/// rather than an SVG asset, matching the same layout and palette.
class _CircleIllustration extends StatelessWidget {
  const _CircleIllustration({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    const height = 200.0;
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(width, height),
                painter: _OrbitRingsPainter(
                  dashed: scheme.primaryContainer,
                  solid: scheme.secondaryContainer,
                ),
              ),
              _PotGlow(scheme: scheme),
              _avatarNode(
                width: width,
                height: height,
                centerXFrac: 0.5,
                centerYFrac: 30 / 220,
                background: scheme.primaryContainer,
                iconColor: scheme.onPrimaryContainer,
              ),
              _avatarNode(
                width: width,
                height: height,
                centerXFrac: 206 / 280,
                centerYFrac: 150 / 220,
                background: scheme.secondaryContainer,
                iconColor: scheme.onSecondaryContainer,
              ),
              _avatarNode(
                width: width,
                height: height,
                centerXFrac: 74 / 280,
                centerYFrac: 150 / 220,
                background: scheme.tertiaryContainer,
                iconColor: scheme.onTertiaryContainer,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _avatarNode({
    required double width,
    required double height,
    required double centerXFrac,
    required double centerYFrac,
    required Color background,
    required Color iconColor,
  }) {
    const size = 40.0;
    return Positioned(
      left: width * centerXFrac - size / 2,
      top: height * centerYFrac - size / 2,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: background,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Center(child: Icon(Icons.person, size: 18, color: iconColor)),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primaryFixed,
                  border: Border.all(color: background, width: 1.5),
                ),
                child: Icon(Icons.check, size: 9, color: scheme.onPrimaryFixed),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PotGlow extends StatelessWidget {
  const _PotGlow({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: scheme.backgroundWarm,
        boxShadow: [
          BoxShadow(
            color: scheme.secondaryContainer.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: scheme.secondaryContainer.withValues(alpha: 0.2),
          ),
          child: Icon(Icons.savings_rounded, color: scheme.secondary, size: 30),
        ),
      ),
    );
  }
}

/// Two concentric orbit rings behind the pot — one dashed, one solid —
/// standing in for the design's connecting-pulse motif.
class _OrbitRingsPainter extends CustomPainter {
  const _OrbitRingsPainter({required this.dashed, required this.solid});

  final Color dashed;
  final Color solid;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.height / 2 - 6;

    final dashedPaint = Paint()
      ..color = dashed.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    _drawDashedCircle(canvas, center, radius * 0.86, dashedPaint);

    final solidPaint = Paint()
      ..color = solid.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius, solidPaint);
  }

  void _drawDashedCircle(
    Canvas canvas,
    Offset center,
    double radius,
    Paint paint,
  ) {
    const dashDegrees = 8.0;
    const gapDegrees = 10.0;
    var angleDegrees = 0.0;
    final rect = Rect.fromCircle(center: center, radius: radius);
    while (angleDegrees < 360) {
      canvas.drawArc(
        rect,
        angleDegrees * math.pi / 180,
        dashDegrees * math.pi / 180,
        false,
        paint,
      );
      angleDegrees += dashDegrees + gapDegrees;
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitRingsPainter oldDelegate) =>
      oldDelegate.dashed != dashed || oldDelegate.solid != solid;
}

class _InviteHintPill extends StatelessWidget {
  const _InviteHintPill({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 24 + 16 * 2,
            height: 24,
            child: Stack(
              children: [
                _initialAvatar('A', scheme.primary, scheme.onPrimary),
                Positioned(
                  left: 16,
                  child: _initialAvatar(
                    'Z',
                    scheme.secondary,
                    scheme.onSecondary,
                  ),
                ),
                Positioned(
                  left: 32,
                  child: _initialAvatar(
                    'M',
                    scheme.tertiaryContainer,
                    scheme.onTertiary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Invite friends and start your first circle together',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _initialAvatar(String letter, Color background, Color foreground) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: background),
      child: Text(
        letter,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: foreground,
        ),
      ),
    );
  }
}

class _ValueHighlights extends StatelessWidget {
  const _ValueHighlights({required this.scheme, required this.textTheme});

  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ValueHighlightTile(
          iconBackground: scheme.surfaceContainerLow,
          iconColor: scheme.primary,
          icon: Icons.verified_user,
          title: 'Automated Protection',
          subtitle:
              'Locked round rules guarantee zero missed contributions or delays.',
          textTheme: textTheme,
          scheme: scheme,
        ),
        const SizedBox(height: 8),
        _ValueHighlightTile(
          iconBackground: scheme.secondaryFixed,
          iconColor: scheme.secondary,
          icon: Icons.bolt,
          title: 'Instant Direct Payouts',
          subtitle:
              'Your turn comes, your pot lands instantly with complete transparency.',
          textTheme: textTheme,
          scheme: scheme,
        ),
        const SizedBox(height: 8),
        _ValueHighlightTile(
          iconBackground: scheme.surfaceContainer,
          iconColor: scheme.onSurface,
          icon: Icons.diversity_3,
          title: 'Save with Friends & Family',
          subtitle:
              'Form private circles with trusted peers or join verified neighborhood groups.',
          textTheme: textTheme,
          scheme: scheme,
        ),
      ],
    );
  }
}

class _ValueHighlightTile extends StatelessWidget {
  const _ValueHighlightTile({
    required this.iconBackground,
    required this.iconColor,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.textTheme,
    required this.scheme,
  });

  final Color iconBackground;
  final Color iconColor;
  final IconData icon;
  final String title;
  final String subtitle;
  final TextTheme textTheme;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 24, color: iconColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectWalletButton extends ConsumerWidget {
  const _ConnectWalletButton({required this.sessionState});

  final AsyncValue<dynamic> sessionState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = sessionState.isLoading;
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primaryContainer,
          foregroundColor: scheme.onPrimary,
        ),
        onPressed: isLoading
            ? null
            : () => ref.read(walletSessionProvider.notifier).connect(),
        icon: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: scheme.onPrimary,
                ),
              )
            : const Icon(Icons.account_balance_wallet),
        label: Text(isLoading ? 'Connecting securely…' : 'Connect Wallet'),
      ),
    );
  }
}

class _NonCustodialNote extends StatelessWidget {
  const _NonCustodialNote({required this.scheme, required this.textTheme});

  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.lock, size: 16, color: scheme.primary),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            'No transaction fees to start. Your funds remain non-custodial and protected.',
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
