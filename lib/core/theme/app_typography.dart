import 'package:flutter/material.dart';

class AppTypography {
  AppTypography._();

  static const String fontArabic = 'Cairo';
  static const String fontEnglish = 'Inter';

  static String getFontFamily(String languageCode) {
    return languageCode == 'ar' ? fontArabic : fontEnglish;
  }

  static TextTheme createTextTheme(Color textColor, Color mutedColor, String fontFamily) {
    return TextTheme(
      // Title 22 semi-bold
      titleLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: textColor,
        letterSpacing: -0.2,
      ),
      // Section header 16 semi-bold
      titleMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      // Body 15 regular
      bodyLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: textColor,
      ),
      // Body 14 regular
      bodyMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: textColor,
      ),
      // Caption 12 regular
      bodySmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: mutedColor,
      ),
      labelSmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: mutedColor,
      ),
    );
  }
}
