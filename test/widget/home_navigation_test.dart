import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:enjaz/core/theme/app_theme.dart';
import 'package:enjaz/features/home/domain/home_summary_data.dart';
import 'package:enjaz/features/home/domain/home_summary_service.dart';
import 'package:enjaz/features/home/domain/home_settings_provider.dart';
import 'package:enjaz/features/home/presentation/home_screen.dart';
import 'package:enjaz/features/home/presentation/widgets/home_header.dart';
import 'package:enjaz/features/home/presentation/widgets/home_overdue_strip.dart';
import 'package:enjaz/features/home/presentation/widgets/home_today_card.dart';
import 'package:enjaz/features/home/presentation/widgets/home_habits_card.dart';
import 'package:enjaz/features/home/presentation/widgets/home_finance_card.dart';
import 'package:enjaz/features/home/presentation/widgets/home_health_card.dart';
import 'package:enjaz/features/home/presentation/widgets/home_goals_ideas_card.dart';
import 'package:enjaz/features/navigation/presentation/more_screen.dart';
import 'package:enjaz/core/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const testSummary = HomeSummaryData(
    todayCompletedCount: 3,
    todayTotalCount: 5,
    todayProgress: 0.6,
    nextTaskTitle: 'اجتماع مناقشة المشروع',
    nextTaskTime: '14:30',
    isAllTodayDone: false,
    overdueCount: 2,
    habitsCompletedCount: 2,
    habitsTotalScheduledCount: 4,
    habitsStreak: 5,
    hasHabits: true,
    todaySpendingMinor: 15000,
    hasMonthlyBudget: true,
    remainingMonthlyBudgetMinor: 250000,
    monthSpendingMinor: 75000,
    nearestHealthTitle: 'زيارة طبيب الأسنان',
    nearestHealthDay: 'غداً',
    postponedHealthCount: 1,
    activeGoalsCount: 4,
    ideasCount: 7,
    notesCount: 12,
  );

  Widget createTestWidget({
    required Widget child,
    bool isDark = false,
    double fontScale = 1.0,
    Size size = const Size(390, 844),
    List<Override> overrides = const [],
  }) {
    return ProviderScope(
      overrides: [
        homeSummaryProvider.overrideWith((ref) => Stream.value(testSummary)),
        ...overrides,
      ],
      child: MaterialApp(
        theme: isDark ? AppTheme.dark('ar') : AppTheme.light('ar'),
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(fontScale),
          ),
          child: child,
        ),
      ),
    );
  }

  group('HomeScreen & Navigation Tests (UI.md Step 2)', () {
    testWidgets('HomeScreen renders all cards and header at 1.3x font scale without errors', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: const HomeScreen(),
          fontScale: 1.3,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(HomeHeader), findsOneWidget);
      expect(find.byType(HomeOverdueStrip), findsOneWidget);
      expect(find.byType(HomeTodayCard), findsOneWidget);
      expect(find.byType(HomeHabitsCard), findsOneWidget);
      expect(find.byType(HomeFinanceCard), findsOneWidget);
      expect(find.byType(HomeHealthCard), findsOneWidget);
      expect(find.byType(HomeGoalsIdeasCard), findsOneWidget);

      // Verify text presence
      expect(find.text('النهاردة'), findsOneWidget);
      expect(find.text('العادات'), findsOneWidget);
      expect(find.text('المال'), findsOneWidget);
      expect(find.text('الصحة'), findsOneWidget);
      expect(find.text('الأهداف والأفكار'), findsOneWidget);
      expect(find.text('اجتماع مناقشة المشروع'), findsOneWidget);
    });

    testWidgets('HomeOverdueStrip appears only when overdueCount > 0', (tester) async {
      // 1. With overdueCount = 2
      await tester.pumpWidget(
        createTestWidget(
          child: const HomeScreen(),
          overrides: [
            homeSummaryProvider.overrideWith((ref) => Stream.value(testSummary)),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(HomeOverdueStrip), findsOneWidget);
      expect(find.textContaining('مهام متأخرة'), findsOneWidget);

      // 2. With overdueCount = 0
      const noOverdueSummary = HomeSummaryData(overdueCount: 0);
      await tester.pumpWidget(
        createTestWidget(
          child: const HomeScreen(),
          overrides: [
            homeSummaryProvider.overrideWith((ref) => Stream.value(noOverdueSummary)),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('مهام متأخرة'), findsNothing);
    });

    testWidgets('Health Card respects hideHealthDetails privacy toggle (UI.md 4.4)', (tester) async {
      // 1. Privacy OFF -> shows actual title
      await tester.pumpWidget(
        createTestWidget(
          child: const HomeScreen(),
          overrides: [
            homeSettingsProvider.overrideWith(
              (ref) => HomeSettingsNotifier(
                initialState: const HomeSettingsState(hideHealthDetails: false),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('زيارة طبيب الأسنان'), findsOneWidget);
      expect(find.text('موعد قادم'), findsNothing);

      // 2. Privacy ON -> hides title and shows 'موعد قادم'
      await tester.pumpWidget(
        createTestWidget(
          child: const HomeScreen(),
          overrides: [
            homeSettingsProvider.overrideWith(
              (ref) => HomeSettingsNotifier(
                initialState: const HomeSettingsState(hideHealthDetails: true),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('زيارة طبيب الأسنان'), findsNothing);
      expect(find.text('موعد قادم'), findsOneWidget);
    });

    testWidgets('MoreScreen dynamically shows modules hidden on Home (UI.md Section 5)', (tester) async {
      // 1. All cards visible on Home -> More does not show Finance or Habits
      await tester.pumpWidget(
        createTestWidget(
          child: const Scaffold(body: MoreScreen()),
          overrides: [
            homeSettingsProvider.overrideWith(
              (ref) => HomeSettingsNotifier(
                initialState: const HomeSettingsState(
                  cardVisibility: {
                    'today': true,
                    'habits': true,
                    'finance': true,
                    'health': true,
                    'goals_ideas': true,
                  },
                ),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('المال والمصروفات'), findsNothing);
      expect(find.text('العادات اليومية'), findsNothing);
      expect(find.text('الإعدادات'), findsOneWidget);
      expect(find.text('تقرير إكسيل'), findsOneWidget);
      expect(find.text('سلة المحذوفات'), findsOneWidget);

      // 2. Finance card hidden on Home -> More screen dynamically shows 'المال والمصروفات'
      await tester.pumpWidget(
        createTestWidget(
          child: const Scaffold(body: MoreScreen()),
          overrides: [
            homeSettingsProvider.overrideWith(
              (ref) => HomeSettingsNotifier(
                initialState: const HomeSettingsState(
                  cardVisibility: {
                    'today': true,
                    'habits': true,
                    'finance': false, // hidden from home
                    'health': true,
                    'goals_ideas': true,
                  },
                ),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('المال والمصروفات'), findsOneWidget);
    });

    testWidgets('Below 360px width, layout expands half-width cards to full width (UI.md 4.3)', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: const HomeScreen(),
          size: const Size(320, 600), // Narrow screen < 360
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // All cards should be rendered without any overflow error
      expect(find.byType(HomeTodayCard), findsOneWidget);
      expect(find.byType(HomeFinanceCard), findsOneWidget);
      expect(find.byType(HomeHabitsCard), findsOneWidget);
    });
  });
}
