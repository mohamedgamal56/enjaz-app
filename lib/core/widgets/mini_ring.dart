import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// MiniRing (UI.md Section 3 & Section 9)
/// Circular progress ring (stroke 2.5 - 3 px) for habit/completion metrics,
/// with optional center child (text, fraction or icon).
class MiniRing extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final double size;
  final double strokeWidth;
  final Color? progressColor;
  final Color? trackColor;
  final Widget? child;

  const MiniRing({
    super.key,
    required this.progress,
    this.size = 40.0,
    this.strokeWidth = 3.0,
    this.progressColor,
    this.trackColor,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final clampedProgress = progress.clamp(0.0, 1.0);
    final activeColor = progressColor ?? colors.accent;
    final baseTrackColor = trackColor ?? colors.surfaceVariant;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _MiniRingPainter(
              progress: clampedProgress,
              strokeWidth: strokeWidth,
              progressColor: activeColor,
              trackColor: baseTrackColor,
            ),
          ),
          if (child != null) child!,
        ],
      ),
    );
  }
}

class _MiniRingPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color progressColor;
  final Color trackColor;

  _MiniRingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.progressColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    // Track circle
    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = progressColor
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      // Start at top (-pi / 2)
      const startAngle = -math.pi / 2;
      final sweepAngle = 2 * math.pi * progress;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MiniRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.trackColor != trackColor;
  }
}
