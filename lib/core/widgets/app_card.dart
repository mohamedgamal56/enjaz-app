import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/enjaz_appearance.dart';

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
    final appearance = EnjazAppearanceTheme.of(context);
    final glow = appearance.hasGlow && colors.isDark;
    final cardBorderColor = borderColor ??
        (glow ? colors.accent.withValues(alpha: .32) : colors.border);
    final borderRadius = BorderRadius.circular(
      radius == 16 ? appearance.radius : radius,
    );

    final cardContent = Container(
      padding: padding,
      child: child,
    );

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: cardColor,
        gradient: glow && color == null
            ? LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: [
                  Color.alphaBlend(
                      colors.accent.withValues(alpha: .10), cardColor),
                  cardColor,
                ],
              )
            : null,
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
