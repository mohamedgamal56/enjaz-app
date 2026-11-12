import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// ProgressBar (UI.md Section 3 & Section 9)
/// 6px height progress bar with fully rounded capsule ends (radius 999),
/// clean fill, and zero overflow.
class ProgressBar extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final double height;
  final Color? fillColor;
  final Color? backgroundColor;
  final EdgeInsetsGeometry margin;

  const ProgressBar({
    super.key,
    required this.progress,
    this.height = 6.0,
    this.fillColor,
    this.backgroundColor,
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final clampedProgress = progress.clamp(0.0, 1.0);
    final bg = backgroundColor ?? colors.surfaceVariant;
    final fill = fillColor ?? colors.accent;
    final borderRadius = BorderRadius.circular(999.0);

    return Container(
      margin: margin,
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: borderRadius,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fillWidth = constraints.maxWidth * clampedProgress;
          return Align(
            alignment: AlignmentDirectional.centerStart,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              width: fillWidth,
              height: height,
              decoration: BoxDecoration(
                color: fill,
                borderRadius: borderRadius,
              ),
            ),
          );
        },
      ),
    );
  }
}
