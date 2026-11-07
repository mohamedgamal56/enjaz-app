import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:enjaz/core/db/app_database.dart';
import 'package:enjaz/features/assistant/action_plan.dart';
import 'package:enjaz/features/assistant/action_executor.dart';
import 'package:enjaz/features/assistant/action_planner.dart';
import 'package:enjaz/features/assistant/rule_based_intent_parser.dart';

void main() {
  group('ActionExecutor Tests (VOICE.md Step 3 & Section 7)', () {
    late AppDatabase db;
    final fixedNow = DateTime(2026, 11, 7, 10, 0);
    late RuleBasedIntentParser parser;
    late ActionPlanner planner;
    late ActionExecutor executor;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      parser = RuleBasedIntentParser(nowProvider: () => fixedNow);
      planner = ActionPlanner(nowProvider: () => fixedNow);
      executor = ActionExecutor(db: db, nowProvider: () => fixedNow);
    });

    tearDown(() async {
      await db.close();
    });

    test('Executes create_task and undo', () async {
      final intent = parser.parse('أنا بكرة عايز أعمل مونتاج الإعلان الساعة 4 العصر', referenceNow: fixedNow);
      final plan = planner.plan(intent, referenceNow: fixedNow);

      final result = await executor.execute(plan);
      expect(result.success, isTrue);
      expect(result.createdId, isNotNull);

      // Verify task in DB
      final task = await db.getTaskById(result.createdId!);
      expect(task, isNotNull);
      expect(task!.title, contains('مونتاج الإعلان'));
      expect(task.dueDate, equals('2026-11-08'));
      expect(task.dueTime, equals('16:00'));
      expect(task.status, equals('todo'));

      // Test Undo
      expect(result.undoAction, isNotNull);
      await result.undoAction!.undo();

      // Verify task is soft deleted
      final taskAfterUndo = await db.getTaskById(result.createdId!);
      expect(taskAfterUndo!.deletedAt, isNotNull);
    });

    test('Executes create_errand', () async {
      final intent = parser.parse('سجل مشوار النهارده أروح السنترال الساعة 1', referenceNow: fixedNow);
      final plan = planner.plan(intent, referenceNow: fixedNow);

      final result = await executor.execute(plan);
      expect(result.success, isTrue);

      final task = await db.getTaskById(result.createdId!);
      expect(task, isNotNull);
      expect(task!.kind, equals('errand'));
      expect(task.title, contains('أروح السنترال'));
      expect(task.dueDate, equals('2026-11-07'));
      expect(task.dueTime, equals('13:00'));
    });

    test('Executes update_status (done) and undo', () async {
      // Create initial task
      final initialTaskId = await db.insertNewTask(
        TasksCompanion.insert(
          title: 'تسليم الفيديوهات',
          status: const Value('in_progress'),
          progress: const Value(50),
          createdAt: fixedNow.millisecondsSinceEpoch,
          updatedAt: fixedNow.millisecondsSinceEpoch,
        ),
      );

      final intent = parser.parse('خلصت مهمة تسليم الفيديوهات', referenceNow: fixedNow);
      final candidate = CandidateTask(id: initialTaskId, title: 'تسليم الفيديوهات', status: 'in_progress');
      final plan = planner.plan(intent, existingOpenTasks: [candidate], referenceNow: fixedNow);

      final result = await executor.execute(plan);
      expect(result.success, isTrue);

      // Verify task transitioned to done with progress 100
      final updated = await db.getTaskById(initialTaskId);
      expect(updated!.status, equals('done'));
      expect(updated.progress, equals(100));
      expect(updated.finishedAt, isNotNull);

      // Verify TaskEvent row created
      final events = await (db.select(db.taskEvents)..where((e) => e.taskId.equals(initialTaskId))).get();
      expect(events.length, equals(1));
      expect(events.first.toStatus, equals('done'));

      // Test Undo
      await result.undoAction!.undo();

      // Verify previous status restored
      final restored = await db.getTaskById(initialTaskId);
      expect(restored!.status, equals('in_progress'));
      expect(restored.progress, equals(50));
      expect(restored.finishedAt, isNull);

      // Verify TaskEvent was cleaned up
      final eventsAfterUndo = await (db.select(db.taskEvents)..where((e) => e.taskId.equals(initialTaskId))).get();
      expect(eventsAfterUndo.isEmpty, isTrue);
    });

    test('Executes update_status postponement with reason and target date', () async {
      final taskId = await db.insertNewTask(
        TasksCompanion.insert(
          title: 'مراجعة الحسابات',
          status: const Value('todo'),
          createdAt: fixedNow.millisecondsSinceEpoch,
          updatedAt: fixedNow.millisecondsSinceEpoch,
        ),
      );

      final intent = parser.parse('أجل مهمة مراجعة الحسابات لبكرة عشان مضغوط في الشغل', referenceNow: fixedNow);
      final candidate = CandidateTask(id: taskId, title: 'مراجعة الحسابات', status: 'todo');
      final plan = planner.plan(intent, existingOpenTasks: [candidate], referenceNow: fixedNow);

      final result = await executor.execute(plan);
      expect(result.success, isTrue);

      final task = await db.getTaskById(taskId);
      expect(task!.status, equals('postponed'));
      expect(task.postponedUntil, equals('2026-11-08'));
      expect(task.postponeCount, equals(1));
      expect(task.reasonText, equals('مضغوط في الشغل'));
    });

    test('Executes log_expense and undo', () async {
      final intent = parser.parse('صرفت 100 جنيه بنزين للموتوسيكل النهارده', referenceNow: fixedNow);
      final plan = planner.plan(intent, referenceNow: fixedNow);

      final result = await executor.execute(plan);
      expect(result.success, isTrue);
      expect(result.createdId, isNotNull);

      // Verify transaction in DB
      final tx = await (db.select(db.transactions)..where((t) => t.id.equals(result.createdId!))).getSingle();
      expect(tx.kind, equals('expense'));
      expect(tx.amountMinor, equals(10000)); // 100 EGP = 10000 piasters
      expect(tx.nature, equals('essential'));

      // Test Undo
      await result.undoAction!.undo();
      final txAfterUndo = await (db.select(db.transactions)..where((t) => t.id.equals(result.createdId!))).getSingle();
      expect(txAfterUndo.deletedAt, isNotNull);
    });

    test('Executes log_income', () async {
      final intent = parser.parse('قبضت 8000 مرتب', referenceNow: fixedNow);
      final plan = planner.plan(intent, referenceNow: fixedNow);

      final result = await executor.execute(plan);
      expect(result.success, isTrue);

      final tx = await (db.select(db.transactions)..where((t) => t.id.equals(result.createdId!))).getSingle();
      expect(tx.kind, equals('income'));
      expect(tx.amountMinor, equals(800000));
    });

    test('Executes log_habit count and undo', () async {
      final intent = parser.parse('شربت كوبايتين قهوة', referenceNow: fixedNow);
      final plan = planner.plan(intent, referenceNow: fixedNow);

      final result = await executor.execute(plan);
      expect(result.success, isTrue);

      // Verify Habit in DB
      final habitLogs = await (db.select(db.habitLogs)..where((l) => l.habitId.equals(result.createdId!))).get();
      expect(habitLogs.length, equals(2)); // +2 cups

      // Test Undo
      await result.undoAction!.undo();
      final logsAfterUndo = await (db.select(db.habitLogs)..where((l) => l.habitId.equals(result.createdId!))).get();
      expect(logsAfterUndo.length, equals(0));
    });

    test('Executes create_note and undo', () async {
      final intent = parser.parse('ملاحظة اللي بيذاكر بيتعلم الصبر', referenceNow: fixedNow);
      final plan = planner.plan(intent, referenceNow: fixedNow);

      final result = await executor.execute(plan);
      expect(result.success, isTrue);

      final note = await (db.select(db.notes)..where((n) => n.id.equals(result.createdId!))).getSingle();
      expect(note.body, contains('اللي بيذاكر بيتعلم الصبر'));

      await result.undoAction!.undo();
      final noteAfterUndo = await (db.select(db.notes)..where((n) => n.id.equals(result.createdId!))).getSingle();
      expect(noteAfterUndo.deletedAt, isNotNull);
    });

    test('Executes create_idea', () async {
      final intent = parser.parse('فكرة تطبيق للمشاوير', referenceNow: fixedNow);
      final plan = planner.plan(intent, referenceNow: fixedNow);

      final result = await executor.execute(plan);
      expect(result.success, isTrue);

      final idea = await (db.select(db.ideas)..where((i) => i.id.equals(result.createdId!))).getSingle();
      expect(idea.title, contains('تطبيق للمشاوير'));
    });

    test('Executes create_wishlist_item and undo', () async {
      final intent = parser.parse('ضيف للمشتريات سماعة بـ 1500 جنيه', referenceNow: fixedNow);
      final plan = planner.plan(intent, referenceNow: fixedNow);

      final result = await executor.execute(plan);
      expect(result.success, isTrue);

      final item = await (db.select(db.wishlistItems)..where((w) => w.id.equals(result.createdId!))).getSingle();
      expect(item.name, contains('سماعة'));
      expect(item.estimatedPriceMinor, equals(150000));

      await result.undoAction!.undo();
      final itemAfterUndo = await (db.select(db.wishlistItems)..where((w) => w.id.equals(result.createdId!))).getSingle();
      expect(itemAfterUndo.deletedAt, isNotNull);
    });

    test('Executes create_health_item and undo', () async {
      final intent = parser.parse('محتاج كشف أسنان يوم الخميس', referenceNow: fixedNow);
      final plan = planner.plan(intent, referenceNow: fixedNow);

      final result = await executor.execute(plan);
      expect(result.success, isTrue);

      final health = await (db.select(db.healthItems)..where((h) => h.id.equals(result.createdId!))).getSingle();
      expect(health.title, contains('أسنان'));
      expect(health.dueBy, equals('2026-11-12'));

      await result.undoAction!.undo();
      final healthAfterUndo = await (db.select(db.healthItems)..where((h) => h.id.equals(result.createdId!))).getSingle();
      expect(healthAfterUndo.deletedAt, isNotNull);
    });
  });
}
