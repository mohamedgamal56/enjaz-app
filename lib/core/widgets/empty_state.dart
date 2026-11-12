import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// EmptyState (UI.md Section 3 & Section 9)
/// Calm and minimal empty state placeholder featuring an outlined icon (size 36-40),
/// 15/600 title, secondary description, and an optional action button.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Padding(
      padding: padding,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 56.0,
              height: 56.0,
              decoration: BoxDecoration(
                color: colors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 28.0,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 12.0),
            Text(
              title,
              style: AppTypography.cardTitle(context),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6.0),
              Text(
                subtitle!,
                style: AppTypography.caption(context),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16.0),
              OutlinedButton(
                onPressed: onAction,
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.accent,
                  side: BorderSide(color: colors.accent, width: 1.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999.0),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                ),
                child: Text(
                  actionLabel!,
                  style: AppTypography.caption(context, color: colors.accent).copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
