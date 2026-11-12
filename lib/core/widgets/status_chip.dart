import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// StatusChip (UI.md Section 3 & Section 9)
/// Fully rounded stadium chip with a 1px border matching the status color,
/// 12px label style, and optional 14px icon.
class StatusChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;
  final VoidCallback? onTap;
  final bool selected;

  const StatusChip({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final baseColor = color ?? colors.accent;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final backgroundColor = selected
        ? baseColor.withValues(alpha: isDark ? 0.25 : 0.15)
        : baseColor.withValues(alpha: isDark ? 0.12 : 0.08);

    final borderColor = selected
        ? baseColor
        : baseColor.withValues(alpha: isDark ? 0.4 : 0.3);

    final textColor = baseColor;

    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999.0),
        border: Border.all(
          color: borderColor,
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 14.0,
              color: textColor,
            ),
            const SizedBox(width: 4.0),
          ],
          Text(
            label,
            style: AppTypography.caption(context, color: textColor).copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999.0),
        child: content,
      );
    }

    return content;
  }
}
