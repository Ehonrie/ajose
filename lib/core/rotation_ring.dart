import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/circle.dart';
import 'theme.dart';

/// The circular "who's paid, whose turn is it" visualizer used on both the
/// Circle Detail screen and the Home screen's featured circle card:  a
/// progress ring behind evenly-spaced member status nodes, with an
/// arbitrary [center] widget (a recipient spotlight, a "current turn"
/// label — whatever the caller needs) placed in the middle.
class RotationRing extends StatelessWidget {
  const RotationRing({super.key, required this.circle, required this.center, this.size = 240});

  final Circle circle;
  final Widget center;
  final double size;

  double get _nodeSize => size * (32 / 240);
  double get _recipientNodeSize => size * (40 / 240);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final recipient = circle.currentRecipient;
    final orbitRadius = size / 2 * 0.82;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size * 0.8,
            height: size * 0.8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.secondaryContainer.withValues(alpha: 0.15),
            ),
          ),
          CustomPaint(
            size: Size(size, size),
            painter: _ProgressRingPainter(
              trackColor: scheme.surfaceContainer,
              progressColor: scheme.primary,
              progress: circle.rotationProgress,
            ),
          ),
          for (var i = 0; i < circle.members.length; i++)
            _ringNode(scheme, i, orbitRadius, recipient),
          center,
        ],
      ),
    );
  }

  Widget _ringNode(ColorScheme scheme, int index, double orbitRadius, Member recipient) {
    final member = circle.members[index];
    final angle = -math.pi / 2 + (2 * math.pi * index / circle.members.length);
    final offset = Offset(orbitRadius * math.cos(angle), orbitRadius * math.sin(angle));
    final isRecipient = member == recipient;
    final nodeSize = isRecipient ? _recipientNodeSize : _nodeSize;

    Widget node;
    if (isRecipient) {
      node = _BouncingNode(
        child: _StatusNode(
          size: nodeSize,
          color: scheme.secondary,
          foreground: scheme.onSecondary,
          icon: Icons.payments,
          shadow: true,
        ),
      );
    } else if (member.isCurrentUser) {
      node = Container(
        width: nodeSize,
        height: nodeSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.secondaryFixedDim,
          shape: BoxShape.circle,
          border: Border.all(color: scheme.backgroundWarm, width: 2),
        ),
        child: Text(
          'YOU',
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: scheme.onSecondaryFixed),
        ),
      );
    } else if (member.status == MemberPaymentStatus.overdue) {
      node = _StatusNode(
        size: nodeSize,
        color: scheme.error,
        foreground: scheme.onError,
        icon: Icons.priority_high,
      );
    } else if (member.status == MemberPaymentStatus.paid) {
      node = _StatusNode(
        size: nodeSize,
        color: scheme.primary,
        foreground: scheme.onPrimary,
        icon: Icons.check,
      );
    } else {
      node = _StatusNode(
        size: nodeSize,
        color: scheme.surfaceContainerHighest,
        foreground: scheme.onSurfaceVariant,
        icon: Icons.hourglass_empty,
      );
    }

    return Positioned(
      left: size / 2 + offset.dx - nodeSize / 2,
      top: size / 2 + offset.dy - nodeSize / 2,
      child: node,
    );
  }
}

class _StatusNode extends StatelessWidget {
  const _StatusNode({
    required this.size,
    required this.color,
    required this.foreground,
    required this.icon,
    this.shadow = false,
  });

  final double size;
  final Color color;
  final Color foreground;
  final IconData icon;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: shadow
            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 6, offset: const Offset(0, 2))]
            : null,
      ),
      child: Icon(icon, size: size * 0.45, color: foreground),
    );
  }
}

/// A gentle up-and-down bob — draws the eye to the current round's
/// recipient node.
class _BouncingNode extends StatefulWidget {
  const _BouncingNode({required this.child});

  final Widget child;

  @override
  State<_BouncingNode> createState() => _BouncingNodeState();
}

class _BouncingNodeState extends State<_BouncingNode> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, -4 * _controller.value),
        child: child,
      ),
      child: widget.child,
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  const _ProgressRingPainter({
    required this.trackColor,
    required this.progressColor,
    required this.progress,
  });

  final Color trackColor;
  final Color progressColor;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 * 0.82;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(center, radius, track);

    final fill = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * progress.clamp(0, 1), false, fill);
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.progressColor != progressColor;
}
