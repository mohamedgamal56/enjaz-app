import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:enjaz/core/db/app_database.dart';
import 'package:enjaz/core/theme/app_theme.dart';
import 'package:enjaz/core/utils/date_formatter.dart';
import 'package:enjaz/features/assistant/action_plan.dart';
import 'package:enjaz/features/assistant/assistant_intent.dart';
import 'package:enjaz/features/assistant/answer_service.dart';
import 'package:enjaz/features/assistant/presentation/widgets/confirmation_card.dart';
import 'package:enjaz/features/assistant/presentation/widgets/answer_card.dart';
import 'package:enjaz/features/tasks/presentation/widgets/task_card.dart';

class _MockNumeralsNotifier extends StateNotifier<NumeralsFormat> implements NumeralsNotifier {
  _MockNumeralsNotifier() : super(NumeralsFormat.western);

  @override
  Future<void> setFormat(NumeralsFormat format) async {
    state = format;
  }
}

class _FakeAppDatabase extends AppDatabase {
  _FakeAppDatabase() : super(NativeDatabase.memory());

  @override
  Stream<int> watchVoiceNotesCount(String parentType, int parentId) {
    return const Stream.empty();
  }

  @override
  Stream<int> watchVoiceNoteCount(String parentType, int parentId) {
    return const Stream.empty();
  }
}

void main() {
  late AppDatabase db;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = _FakeAppDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  group('Font Scale 1.3 & Theme Overflow Verification (PLAN.md Section 7 Batch 4)', () {
    Widget buildScaledHarness({
      required Widget child,
      required bool isDark,
      double fontScale = 1.3,
    }) {
      return ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          numeralsProvider.overrideWith((ref) => _MockNumeralsNotifier()),
        ],
        child: MaterialApp(
          theme: isDark ? AppTheme.dark('ar') : AppTheme.light('ar'),
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(390, 844), // Typical modern viewport
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
        ),
      );
    }

    for (final isDark in [false, true]) {
      final themeName = isDark ? 'Dark Theme' : 'Light Theme';

      testWidgets('ConfirmationCard renders without overflow under font scale 1.3 in $themeName', (tester) async {
        final plan = ActionPlan(
          intent: const AssistantIntent(
            type: AssistantIntentType.createTask,
            rawText: 'سجل مهمة تسليم التقرير السنوي غداً',
            normalizedText: 'سجل مهمة تسليم التقرير السنوي غدا',
          ),
          actionType: 'task',
          actionTitle: 'إنشاء مهمة جديدة',
          descriptionInWords: 'مهمة — تسليم التقرير السنوي — الأحد 15 نوفمبر 2026 — 5:00 م',
          slots: const {
            'title': 'تسليم التقرير السنوي',
            'date': '2026-11-15',
            'time': '17:00',
          },
        );

        await tester.pumpWidget(
          buildScaledHarness(
            isDark: isDark,
            fontScale: 1.3,
            child: ConfirmationCard(
              plan: plan,
              onConfirm: () {},
              onEdit: () {},
              onCancel: () {},
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(tester.takeException(), isNull, reason: 'No RenderFlex overflow should occur in $themeName');
        expect(find.byType(ConfirmationCard), findsOneWidget);
      });

      testWidgets('AnswerCard renders without overflow under font scale 1.3 in $themeName', (tester) async {
        final data = AnswerCardData(
          intent: const AssistantIntent(
            type: AssistantIntentType.agenda,
            rawText: 'ورايا ايه النهارده؟',
            normalizedText: 'ورايا ايه النهارده',
          ),
          title: 'جدول المواعيد (اليوم)',
          speechText: 'وراك في اليوم الحالي: مهمتان قيد الانتظار ومهمة تم تأجيلها سابقاً',
          metricChips: const ['3 مهام مجدولة', 'مهمة واحدة منجزة', 'لا توجد متأخرات حرجة'],
          detailItems: const [
            'مراجعة الميزانية المالية السنوية — 11:00 ص',
            'اجتماع فريق التطوير والتحسين — 2:00 م',
            'شراء المستلزمات الطبية والوقائية — 6:00 م',
          ],
          navTarget: 'tasks',
          navLabel: 'عرض المهام بالتفصيل',
          icon: Icons.calendar_today_rounded,
        );

        await tester.pumpWidget(
          buildScaledHarness(
            isDark: isDark,
            fontScale: 1.3,
            child: AnswerCard(
              data: data,
              onNavigate: () {},
              onClose: () {},
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(tester.takeException(), isNull, reason: 'No overflow in AnswerCard in $themeName');
        expect(find.byType(AnswerCard), findsOneWidget);
      });

      testWidgets('TaskCard renders without overflow under font scale 1.3 in $themeName', (tester) async {
        final sampleTask = Task(
          id: 101,
          title: 'مراجعة التصاميم الجديدة وتطبيق مواصفات قابلية الوصول والألوان',
          kind: 'task',
          priority: 'high',
          dueDate: '2026-11-12',
          dueTime: '15:30',
          status: 'in_progress',
          progress: 60,
          postponeCount: 2,
          reasonText: 'اجتماع طارئ مع الإدارة',
          createdAt: DateTime.now().millisecondsSinceEpoch - 100000,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );

        await tester.pumpWidget(
          buildScaledHarness(
            isDark: isDark,
            fontScale: 1.3,
            child: TaskCard(task: sampleTask),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(tester.takeException(), isNull, reason: 'No overflow in TaskCard in $themeName');
        expect(find.byType(TaskCard), findsOneWidget);
      });
    }
  });
}
