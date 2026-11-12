import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// CardHeader (UI.md Section 3 & Section 9)
/// Standard card header featuring a 15/600 title, optional leading icon,
/// and an optional trailing text link or custom action button.
class CardHeader extends StatelessWidget {
  final String title;
  final Widget? leading;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const CardHeader({
    super.key,
    required this.title,
    this.leading,
    this.actionLabel,
    this.onAction,
    this.trailing,
    this.padding = const EdgeInsets.only(bottom: 12.0),
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    Widget? actionWidget;
    if (trailing != null) {
      actionWidget = trailing;
    } else if (actionLabel != null && onAction != null) {
      actionWidget = InkWell(
        onTap: onAction,
        borderRadius: BorderRadius.circular(8.0),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
          child: Text(
            actionLabel!,
            style: AppTypography.caption(context, color: colors.accent).copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 8.0),
          ],
          Expanded(
            child: Text(
              title,
              style: AppTypography.cardTitle(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (actionWidget != null) actionWidget,
        ],
      ),
    );
  }
}
