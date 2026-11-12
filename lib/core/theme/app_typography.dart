import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTypography {
  AppTypography._();

  static const String fontArabic = 'Cairo';
  static const String fontEnglish = 'Inter';

  // Context-aware typography accessors (UI.md Section 3)
  static TextStyle greeting(BuildContext context) {
    final theme = Theme.of(context);
    return TextStyle(
      fontFamily: theme.textTheme.bodyMedium?.fontFamily,
      fontSize: 22,
      fontWeight: FontWeight.w700,
      height: 1.4,
      color: theme.colorScheme.onSurface,
    );
  }

  static TextStyle cardTitle(BuildContext context) {
    final theme = Theme.of(context);
    return TextStyle(
      fontFamily: theme.textTheme.bodyMedium?.fontFamily,
      fontSize: 15,
      fontWeight: FontWeight.w600,
      height: 1.4,
      color: theme.colorScheme.onSurface,
    );
  }

  static TextStyle keyValue(BuildContext context) {
    final theme = Theme.of(context);
    return TextStyle(
      fontFamily: theme.textTheme.bodyMedium?.fontFamily,
      fontSize: 22,
      fontWeight: FontWeight.w700,
      height: 1.4,
      color: theme.colorScheme.onSurface,
    );
  }

  static TextStyle body(BuildContext context, {Color? color}) {
    final theme = Theme.of(context);
    return TextStyle(
      fontFamily: theme.textTheme.bodyMedium?.fontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.5,
      color: color ?? theme.colorScheme.onSurface,
    );
  }

  static TextStyle caption(BuildContext context, {Color? color}) {
    final theme = Theme.of(context);
    return TextStyle(
      fontFamily: theme.textTheme.bodyMedium?.fontFamily,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.4,
      color: color ?? AppColors.of(context).textSecondary,
    );
  }

  static TextStyle titleLarge(BuildContext context) =>
      Theme.of(context).textTheme.titleLarge ?? const TextStyle();
  static TextStyle titleMedium(BuildContext context) =>
      Theme.of(context).textTheme.titleMedium ?? const TextStyle();
  static TextStyle bodyLarge(BuildContext context) =>
      Theme.of(context).textTheme.bodyLarge ?? const TextStyle();
  static TextStyle bodyMedium(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
  static TextStyle bodySmall(BuildContext context) =>
      Theme.of(context).textTheme.bodySmall ?? const TextStyle();

  static String getFontFamily(String languageCode) {
    return languageCode == 'ar' ? fontArabic : fontEnglish;
  }

  static TextTheme createTextTheme(Color textColor, Color mutedColor, String fontFamily) {
    return TextTheme(
      // Title 22 bold / semi-bold (UI.md Section 3: Greeting / Key Value 22/700)
      headlineSmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.4,
        color: textColor,
      ),
      titleLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.4,
        color: textColor,
        letterSpacing: -0.2,
      ),
      // Section header 16 semi-bold
      titleMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: textColor,
      ),
      // Card title 15 semi-bold (UI.md Section 3: Card title 15/600)
      titleSmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: textColor,
      ),
      // Body 15 regular
      bodyLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: textColor,
      ),
      // Body 14 regular (UI.md Section 3: Body 14)
      bodyMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: textColor,
      ),
      // Caption 12 regular (UI.md Section 3: Caption 12, min text size 12)
      bodySmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: mutedColor,
      ),
      labelSmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: mutedColor,
      ),
    );
  }
}
