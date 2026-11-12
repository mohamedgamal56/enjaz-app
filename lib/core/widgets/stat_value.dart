import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// StatValue (UI.md Section 3 & Section 9)
/// Key numerical metric display: value in 22/700, label in 12 caption,
/// with optional icon or trend indicator.
class StatValue extends StatelessWidget {
  final String value;
  final String label;
  final Widget? icon;
  final String? trend;
  final Color? valueColor;
  final CrossAxisAlignment crossAxisAlignment;

  const StatValue({
    super.key,
    required this.value,
    required this.label,
    this.icon,
    this.trend,
    this.valueColor,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final valColor = valueColor ?? colors.text;

    return Column(
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (icon != null) ...[
              icon!,
              const SizedBox(width: 6.0),
            ],
            Text(
              value,
              style: AppTypography.keyValue(context).copyWith(color: valColor),
            ),
            if (trend != null) ...[
              const SizedBox(width: 6.0),
              Text(
                trend!,
                style: AppTypography.caption(context, color: colors.accent).copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 2.0),
        Text(
          label,
          style: AppTypography.caption(context),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
