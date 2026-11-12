import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:enjaz/core/theme/app_theme.dart';
import 'package:enjaz/core/widgets/widgets.dart';

void main() {
  group('Shared Widgets & Design Tokens Verification (UI.md Section 3 & 9 Step 1)', () {
    Widget buildHarness({
      required Widget child,
      required bool isDark,
      double fontScale = 1.0,
      Size size = const Size(390, 844),
    }) {
      return MaterialApp(
        theme: isDark ? AppTheme.dark('ar') : AppTheme.light('ar'),
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(fontScale),
          ),
          child: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: child,
              ),
            ),
          ),
        ),
      );
    }

    for (final isDark in [false, true]) {
      final themeName = isDark ? 'Dark Theme' : 'Light Theme';

      testWidgets('AppCard renders child and triggers onTap in $themeName', (tester) async {
        bool tapped = false;
        await tester.pumpWidget(
          buildHarness(
            isDark: isDark,
            fontScale: 1.3,
            child: AppCard(
              onTap: () => tapped = true,
              child: const Text('محتوى كارت إنجاز التجريبي'),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text('محتوى كارت إنجاز التجريبي'), findsOneWidget);

        await tester.tap(find.byType(AppCard));
        await tester.pump();
        expect(tapped, isTrue);
      });

      testWidgets('CardHeader renders title and triggers action in $themeName', (tester) async {
        bool actionTriggered = false;
        await tester.pumpWidget(
          buildHarness(
            isDark: isDark,
            fontScale: 1.3,
            child: CardHeader(
              title: 'المهام اليومية المجدولة',
              leading: const Icon(Icons.check_circle_outline),
              actionLabel: 'عرض الكل',
              onAction: () => actionTriggered = true,
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text('المهام اليومية المجدولة'), findsOneWidget);
        expect(find.text('عرض الكل'), findsOneWidget);

        await tester.tap(find.text('عرض الكل'));
        await tester.pump();
        expect(actionTriggered, isTrue);
      });

      testWidgets('ProgressBar renders smoothly across ratios in $themeName', (tester) async {
        await tester.pumpWidget(
          buildHarness(
            isDark: isDark,
            fontScale: 1.3,
            child: const Column(
              children: [
                ProgressBar(progress: 0.0),
                SizedBox(height: 12),
                ProgressBar(progress: 0.65),
                SizedBox(height: 12),
                ProgressBar(progress: 1.0),
              ],
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        expect(tester.takeException(), isNull);
        expect(find.byType(ProgressBar), findsNWidgets(3));
      });

      testWidgets('MiniRing renders smoothly with center child in $themeName', (tester) async {
        await tester.pumpWidget(
          buildHarness(
            isDark: isDark,
            fontScale: 1.3,
            child: const MiniRing(
              progress: 0.75,
              child: Text('٧٥٪'),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.byType(MiniRing), findsOneWidget);
        expect(find.text('٧٥٪'), findsOneWidget);
      });

      testWidgets('StatValue renders key value and caption without overflow in $themeName', (tester) async {
        await tester.pumpWidget(
          buildHarness(
            isDark: isDark,
            fontScale: 1.3,
            child: const StatValue(
              value: '١,٤٥٠ ج.م',
              label: 'إجمالي المصروفات الشهرية',
              trend: '+١٢٪',
              icon: Icon(Icons.trending_up, size: 20),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text('١,٤٥٠ ج.م'), findsOneWidget);
        expect(find.text('إجمالي المصروفات الشهرية'), findsOneWidget);
        expect(find.text('+١٢٪'), findsOneWidget);
      });

      testWidgets('StatusChip renders and responds to tap in $themeName', (tester) async {
        bool tapped = false;
        await tester.pumpWidget(
          buildHarness(
            isDark: isDark,
            fontScale: 1.3,
            child: StatusChip(
              label: 'قيد التنفيذ',
              icon: Icons.sync_rounded,
              selected: true,
              onTap: () => tapped = true,
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text('قيد التنفيذ'), findsOneWidget);

        await tester.tap(find.byType(StatusChip));
        await tester.pump();
        expect(tapped, isTrue);
      });

      testWidgets('EmptyState renders icon, title, subtitle, and action button in $themeName', (tester) async {
        bool actionTriggered = false;
        await tester.pumpWidget(
          buildHarness(
            isDark: isDark,
            fontScale: 1.3,
            child: EmptyState(
              icon: Icons.checklist_rounded,
              title: 'مفيش مهام مسجلة اليوم',
              subtitle: 'ابدأ يومك بإضافة أول مهمة أو مشوار لتنظيمه بوضوح',
              actionLabel: 'إضافة مهمة جديدة',
              onAction: () => actionTriggered = true,
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text('مفيش مهام مسجلة اليوم'), findsOneWidget);
        expect(find.text('ابدأ يومك بإضافة أول مهمة أو مشوار لتنظيمه بوضوح'), findsOneWidget);
        expect(find.text('إضافة مهمة جديدة'), findsOneWidget);

        await tester.tap(find.text('إضافة مهمة جديدة'));
        await tester.pump();
        expect(actionTriggered, isTrue);
      });

      testWidgets('AppBottomBar renders 4 tabs and center + button in $themeName', (tester) async {
        int selectedTab = 0;
        bool addPressed = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: isDark ? AppTheme.dark('ar') : AppTheme.light('ar'),
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(390, 844),
                textScaler: TextScaler.linear(1.3),
              ),
              child: Scaffold(
                bottomNavigationBar: AppBottomBar(
                  currentIndex: selectedTab,
                  onTabSelected: (idx) => selectedTab = idx,
                  onAddPressed: () => addPressed = true,
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text('الرئيسية'), findsOneWidget);
        expect(find.text('التخطيط'), findsOneWidget);
        expect(find.text('الإحصائيات'), findsOneWidget);
        expect(find.text('المزيد'), findsOneWidget);
        expect(find.byIcon(Icons.add_rounded), findsOneWidget);

        // Tap on Center +
        await tester.tap(find.byIcon(Icons.add_rounded));
        await tester.pump();
        expect(addPressed, isTrue);

        // Tap on Plan tab (index 1)
        await tester.tap(find.text('التخطيط'));
        await tester.pump();
        expect(selectedTab, equals(1));
      });

      testWidgets('QuickAddMenu renders all 7 options in $themeName', (tester) async {
        QuickAddOption? selected;
        await tester.pumpWidget(
          MaterialApp(
            theme: isDark ? AppTheme.dark('ar') : AppTheme.light('ar'),
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(390, 844),
                textScaler: TextScaler.linear(1.3),
              ),
              child: Scaffold(
                body: QuickAddMenu(
                  onSelect: (opt) => selected = opt,
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text('إضافة سريعة'), findsOneWidget);
        expect(find.text('مهمة'), findsOneWidget);
        expect(find.text('مشوار'), findsOneWidget);
        expect(find.text('مصروف'), findsOneWidget);
        expect(find.text('عادة'), findsOneWidget);
        expect(find.text('ملاحظة'), findsOneWidget);
        expect(find.text('فكرة'), findsOneWidget);
        expect(find.text('تسجيل صوتي'), findsOneWidget);

        await tester.tap(find.text('مشوار'));
        await tester.pump();
        expect(selected, equals(QuickAddOption.errand));
      });
    }
  });
}
