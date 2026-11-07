import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:enjaz/core/db/app_database.dart';
import 'package:enjaz/features/assistant/answer_service.dart';
import 'package:enjaz/features/assistant/rule_based_intent_parser.dart';

void main() {
  group('AnswerService Unit Tests (VOICE.md Step 4 & Section 6)', () {
    late AppDatabase db;
    final fixedNow = DateTime(2026, 11, 7, 10, 0);
    late RuleBasedIntentParser parser;
    late AnswerService answerService;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      db = AppDatabase(NativeDatabase.memory());
      parser = RuleBasedIntentParser(nowProvider: () => fixedNow);
      answerService = AnswerService(db: db, nowProvider: () => fixedNow);
    });

    tearDown(() async {
      await db.close();
    });

    test('builds agenda answer matching today tasks and overdue count', () async {
      // 1. Task for today
      await db.insertNewTask(
        TasksCompanion.insert(
          title: 'مونتاج الإعلان',
          status: const Value('todo'),
          dueDate: const Value('2026-11-07'),
          dueTime: const Value('16:00'),
          createdAt: fixedNow.millisecondsSinceEpoch,
          updatedAt: fixedNow.millisecondsSinceEpoch,
        ),
      );

      // 2. Overdue task from 2 days ago
      await db.insertNewTask(
        TasksCompanion.insert(
          title: 'تسليم الفيديوهات',
          status: const Value('in_progress'),
          dueDate: const Value('2026-11-05'),
          createdAt: fixedNow.subtract(const Duration(days: 2)).millisecondsSinceEpoch,
          updatedAt: fixedNow.millisecondsSinceEpoch,
        ),
      );

      final intent = parser.parse('ورايا ايه النهارده؟', referenceNow: fixedNow);
      final card = await answerService.buildAnswer(intent);

      expect(card.title, contains('جدول المواعيد'));
      expect(card.speechText, contains('مونتاج الإعلان'));
      expect(card.speechText, contains('متأخرة'));
      expect(card.metricChips, contains('مهمة'));
      expect(card.metricChips, contains('مهمة متأخرة'));
      expect(card.navTarget, equals('tasks'));
    });

    test('builds recap answer matching done tasks and spending', () async {
      final yest = fixedNow.subtract(const Duration(days: 1));

      // Task completed yesterday
      final taskId = await db.insertNewTask(
        TasksCompanion.insert(
          title: 'مراجعة الميزانية',
          status: const Value('done'),
          createdAt: yest.millisecondsSinceEpoch,
          updatedAt: yest.millisecondsSinceEpoch,
        ),
      );
      await db.insertTaskEvent(
        TaskEventsCompanion.insert(
          taskId: taskId,
          at: yest.millisecondsSinceEpoch,
          fromStatus: 'in_progress',
          toStatus: 'done',
          progress: 100,
          createdAt: yest.millisecondsSinceEpoch,
          updatedAt: yest.millisecondsSinceEpoch,
        ),
      );

      // Spending yesterday
      final yestDateStr =
          '${yest.year.toString().padLeft(4, '0')}-${yest.month.toString().padLeft(2, '0')}-${yest.day.toString().padLeft(2, '0')}';
      await db.insertTransaction(
        TransactionsCompanion.insert(
          kind: 'expense',
          amountMinor: 25000, // 250 EGP
          categoryId: 1,
          localDate: yestDateStr,
          occurredAt: yest.millisecondsSinceEpoch,
          createdAt: yest.millisecondsSinceEpoch,
          updatedAt: yest.millisecondsSinceEpoch,
        ),
      );

      final intent = parser.parse('عملت ايه امبارح؟', referenceNow: fixedNow);
      final card = await answerService.buildAnswer(intent);

      expect(card.title, contains('ملخص الإنجاز'));
      expect(card.speechText, contains('أنجزت مهمة'));
      expect(card.speechText, contains('250 جنيه'));
      expect(card.navTarget, equals('timeline'));
    });

    test('builds spending answer matching monthly totals and categories', () async {
      final todayDateStr =
          '${fixedNow.year.toString().padLeft(4, '0')}-${fixedNow.month.toString().padLeft(2, '0')}-${fixedNow.day.toString().padLeft(2, '0')}';
      await db.insertTransaction(
        TransactionsCompanion.insert(
          kind: 'expense',
          amountMinor: 50000, // 500 EGP
          categoryId: 1,
          localDate: todayDateStr,
          nature: const Value('essential'),
          occurredAt: fixedNow.millisecondsSinceEpoch,
          createdAt: fixedNow.millisecondsSinceEpoch,
          updatedAt: fixedNow.millisecondsSinceEpoch,
        ),
      );

      final intent = parser.parse('صرفت كام الشهر ده؟', referenceNow: fixedNow);
      final card = await answerService.buildAnswer(intent);

      expect(card.title, contains('تقرير المصروفات'));
      expect(card.speechText, contains('500 جنيه'));
      expect(card.navTarget, equals('finance'));
    });

    test('builds habit_status answer with count and streak', () async {
      final habitId = await db.insertHabit(
        HabitsCompanion.insert(
          nameAr: 'قهوة',
          builtinKey: const Value('coffee'),
          type: 'count',
          dailyTarget: const Value(2),
          createdAt: fixedNow.millisecondsSinceEpoch,
          updatedAt: fixedNow.millisecondsSinceEpoch,
        ),
      );

      await db.logHabitCount(habitId, '2026-11-07');
      await db.logHabitCount(habitId, '2026-11-07');

      final intent = parser.parse('شربت كام قهوة النهارده؟', referenceNow: fixedNow);
      final card = await answerService.buildAnswer(intent);

      expect(card.title, contains('حالة العادة'));
      expect(card.speechText, contains('فنجانين'));
      expect(card.navTarget, equals('habits'));
    });

    test('builds pending answer for overdue tasks', () async {
      await db.insertNewTask(
        TasksCompanion.insert(
          title: 'مراجعة الضرائب',
          status: const Value('todo'),
          dueDate: const Value('2026-11-01'),
          reasonText: const Value('مفيش وقت'),
          createdAt: fixedNow.subtract(const Duration(days: 6)).millisecondsSinceEpoch,
          updatedAt: fixedNow.millisecondsSinceEpoch,
        ),
      );

      final intent = parser.parse('ايه المتأخر عندي؟', referenceNow: fixedNow);
      final card = await answerService.buildAnswer(intent);

      expect(card.title, contains('المهام المعلقة والمتأخرة'));
      expect(card.speechText, contains('مراجعة الضرائب'));
      expect(card.navTarget, equals('tasks'));
    });

    test('builds obligations answer with late and upcoming', () async {
      final obId = await db.insertObligation(
        ObligationsCompanion.insert(
          name: 'فاتورة الكهرباء',
          kind: 'bill',
          amountMinor: 30000,
          startDate: '2026-01-01',
          createdAt: fixedNow.millisecondsSinceEpoch,
          updatedAt: fixedNow.millisecondsSinceEpoch,
        ),
      );

      await db.into(db.obligationInstances).insert(
        ObligationInstancesCompanion.insert(
          obligationId: obId,
          dueDate: '2026-11-20',
          amountMinor: 30000,
          status: const Value('pending'),
          createdAt: fixedNow.millisecondsSinceEpoch,
          updatedAt: fixedNow.millisecondsSinceEpoch,
        ),
      );

      final intent = parser.parse('ايه اللي عليا الشهر ده؟', referenceNow: fixedNow);
      final card = await answerService.buildAnswer(intent);

      expect(card.title, contains('الالتزامات المالية المستحقة'));
      expect(card.speechText, contains('300 جنيه'));
      expect(card.navTarget, equals('finance'));
    });

    test('builds health_pending answer with waiting duration', () async {
      await db.insertHealthItemWithEvent(
        HealthItemsCompanion.insert(
          title: 'كشف أسنان',
          kind: 'dental',
          status: const Value('needed'),
          neededSince: '2026-10-07', // 31 days ago (~ 1 month)
          occurredAt: fixedNow.millisecondsSinceEpoch,
          localDate: '2026-10-07',
          createdAt: fixedNow.millisecondsSinceEpoch,
          updatedAt: fixedNow.millisecondsSinceEpoch,
        ),
      );

      final intent = parser.parse('ايه الكشوفات المؤجلة؟', referenceNow: fixedNow);
      final card = await answerService.buildAnswer(intent);

      expect(card.title, contains('الكشوفات والتحاليل الطبية المؤجلة'));
      expect(card.speechText, contains('كشف أسنان'));
      expect(card.speechText, contains('شهر'));
      expect(card.navTarget, equals('health'));
    });

    test('builds wishlist answer with totals', () async {
      await db.insertWishlistItem(
        WishlistItemsCompanion.insert(
          name: 'سماعة سوني',
          estimatedPriceMinor: 150000, // 1500 EGP
          createdAt: fixedNow.millisecondsSinceEpoch,
          updatedAt: fixedNow.millisecondsSinceEpoch,
        ),
      );

      final intent = parser.parse('اجمالي المشتريات اللي عايزها كام؟', referenceNow: fixedNow);
      final card = await answerService.buildAnswer(intent);

      expect(card.title, contains('قائمة أمنيات المشتريات'));
      expect(card.speechText, contains('1500 جنيه'));
      expect(card.navTarget, equals('finance'));
    });
  });
}
