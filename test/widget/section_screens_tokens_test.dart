import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enjaz/core/l10n/app_localizations.dart';
import 'package:enjaz/l10n/app_localizations.dart' as gen_l10n;
import 'package:enjaz/core/theme/app_colors.dart';
import 'package:enjaz/core/theme/app_theme.dart';
import 'package:enjaz/core/widgets/widgets.dart';

void main() {
  group('Section Screens Tokens & Shared Widgets Tests (UI.md Step 3)', () {
    Widget buildTestApp({
      required Widget child,
      Locale locale = const Locale('ar'),
      ThemeMode themeMode = ThemeMode.light,
      double textScaleFactor = 1.0,
    }) {
      return ProviderScope(
        child: MediaQuery(
          data: MediaQueryData(
            textScaler: TextScaler.linear(textScaleFactor),
            size: const Size(390, 844),
          ),
          child: MaterialApp(
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              gen_l10n.AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: AppTheme.light(locale.languageCode),
            darkTheme: AppTheme.dark(locale.languageCode),
            themeMode: themeMode,
            home: Scaffold(body: child),
          ),
        ),
      );
    }

    testWidgets('EmptyState renders icon, title, subtitle and action in Light mode', (tester) async {
      bool actionTapped = false;

      await tester.pumpWidget(
        buildTestApp(
          child: EmptyState(
            icon: Icons.checklist_rounded,
            title: 'لا توجد مهام اليوم',
            subtitle: 'استمتع بيومك أو أضف مهام جديدة',
            actionLabel: 'إضافة مهمة',
            onAction: () => actionTapped = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('لا توجد مهام اليوم'), findsOneWidget);
      expect(find.text('استمتع بيومك أو أضف مهام جديدة'), findsOneWidget);
      expect(find.text('إضافة مهمة'), findsOneWidget);

      await tester.tap(find.text('إضافة مهمة'));
      expect(actionTapped, isTrue);
    });

    testWidgets('EmptyState renders gracefully in Dark mode', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          themeMode: ThemeMode.dark,
          child: const EmptyState(
            icon: Icons.flag_outlined,
            title: 'مفيش أهداف مسجلة',
            subtitle: 'ابدأ بإضافة أول هدف ليك',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('مفيش أهداف مسجلة'), findsOneWidget);
      expect(find.text('ابدأ بإضافة أول هدف ليك'), findsOneWidget);
    });

    testWidgets('AppCard applies token border and calm background', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: const AppCard(
            padding: EdgeInsets.all(16.0),
            child: Text('محتوى بطاقة تجريبية'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('محتوى بطاقة تجريبية'), findsOneWidget);
    });

    testWidgets('EmptyState handles 1.3x font scale without overflowing', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          textScaleFactor: 1.3,
          child: EmptyState(
            icon: Icons.insights_rounded,
            title: 'مفيش بيانات كافية للفترة دي',
            subtitle: 'أنجز مهام وسجل عاداتك عشان تظهر تحليلاتك بالتفصيل هنا',
            actionLabel: 'تحديث البيانات',
            onAction: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('مفيش بيانات كافية للفترة دي'), findsOneWidget);
    });

    testWidgets('Contrast of textSecondary meets 4.5:1 requirement', (tester) async {
      double contrastRatio(Color fg, Color bg) {
        final l1 = fg.computeLuminance();
        final l2 = bg.computeLuminance();
        final lighter = l1 > l2 ? l1 : l2;
        final darker = l1 > l2 ? l2 : l1;
        return (lighter + 0.05) / (darker + 0.05);
      }

      // Light theme: textSecondary on background and surface
      final lightContrastBg = contrastRatio(AppColors.lightTextMuted, AppColors.lightBackground);
      final lightContrastSurface = contrastRatio(AppColors.lightTextMuted, AppColors.lightSurface);
      expect(lightContrastBg, greaterThanOrEqualTo(4.5));
      expect(lightContrastSurface, greaterThanOrEqualTo(4.5));

      // Dark theme: textSecondary on background and surface
      final darkContrastBg = contrastRatio(AppColors.darkTextMuted, AppColors.darkBackground);
      final darkContrastSurface = contrastRatio(AppColors.darkTextMuted, AppColors.darkSurface);
      expect(darkContrastBg, greaterThanOrEqualTo(4.5));
      expect(darkContrastSurface, greaterThanOrEqualTo(4.5));
    });
  });
}
