import 'dart:math';

import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

/// Circular "X of Y doses taken" progress indicator with a smoothly
/// animated arc and a completion checkmark.
final class ProgressRing extends StatelessWidget {
  const ProgressRing({
    required this.taken,
    required this.total,
    this.size = 104,
    super.key,
  });

  final int taken;
  final int total;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = total == 0 ? 0.0 : taken / total;
    final complete = total > 0 && taken == total;

    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: progress),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) => CustomPaint(
          painter: _RingPainter(
            progress: value,
            trackColor: theme.colorScheme.surfaceContainerHighest,
            progressColor: theme.colorScheme.primary,
          ),
          child: child,
        ),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: complete
                ? Icon(
                    Icons.check_rounded,
                    key: const ValueKey('done'),
                    size: size * 0.36,
                    color: theme.colorScheme.primary,
                  )
                : Column(
                    key: const ValueKey('count'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$taken/$total',
                        style: AppTextStyles.numberLarge.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontSize: size * 0.24,
                        ),
                      ),
                      Text('taken', style: theme.textTheme.labelMedium),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

final class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
  });

  final double progress;
  final Color trackColor;
  final Color progressColor;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 10.0;
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, paint..color = trackColor);
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        2 * pi * progress.clamp(0.0, 1.0),
        false,
        paint..color = progressColor,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.progressColor != progressColor;
}
