import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// AppCard (UI.md Section 3 & Section 9)
/// Calm and minimal card widget: 16px radius, 1px token border, 0 elevation,
/// no shadows, no glow, no gradients.
class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? color;
  final Color? borderColor;
  final double radius;

  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16.0),
    this.margin = EdgeInsets.zero,
    this.color,
    this.borderColor,
    this.radius = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final cardColor = color ?? colors.surface;
    final cardBorderColor = borderColor ?? colors.border;
    final borderRadius = BorderRadius.circular(radius);

    final cardContent = Container(
      padding: padding,
      child: child,
    );

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: borderRadius,
        border: Border.all(
          color: cardBorderColor,
          width: 1.0,
        ),
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: onTap != null
            ? Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  child: cardContent,
                ),
              )
            : cardContent,
      ),
    );
  }
}
