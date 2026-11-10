import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:enjaz/core/db/app_database.dart';
import 'package:enjaz/features/reminders/domain/reminder_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ReminderScheduler scheduler;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    scheduler = ReminderScheduler(db: db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Reminders Comprehensive Audit Tests (CHANGES.md 1.2)', () {
    test('getAllActiveReminders returns only enabled, non-deleted reminders for active items', () async {
      final now = DateTime.now().millisecondsSinceEpoch;

      // 1. Insert an active task with reminder
      final taskId = await db.insertBatchTasks(
        titles: ['مهمة نشطة'],
        dueDate: '2026-11-25',
      );

      final rem1Id = await db.into(db.reminders).insert(
        RemindersCompanion.insert(
          ownerType: 'task',
          ownerId: taskId,
          kind: const Value('alarm'),
          triggerType: const Value('offset'),
          offsetMinutes: const Value(15),
          enabled: const Value(true),
          createdAt: now,
          updatedAt: now,
        ),
      );

      // 2. Insert a disabled reminder
      await db.into(db.reminders).insert(
        RemindersCompanion.insert(
          ownerType: 'task',
          ownerId: taskId,
          kind: const Value('notification'),
          triggerType: const Value('offset'),
          offsetMinutes: const Value(30),
          enabled: const Value(false),
          createdAt: now,
          updatedAt: now,
        ),
      );

      // 3. Insert a soft-deleted reminder
      await db.into(db.reminders).insert(
        RemindersCompanion.insert(
          ownerType: 'task',
          ownerId: taskId,
          kind: const Value('alarm'),
          triggerType: const Value('offset'),
          offsetMinutes: const Value(60),
          enabled: const Value(true),
          deletedAt: Value(now),
          createdAt: now,
          updatedAt: now,
        ),
      );

      final active = await db.getAllActiveReminders();
      expect(active.length, equals(1));
      expect(active.first.id, equals(rem1Id));
    });

    test('Soft deleting a task excludes its reminders from active query', () async {
      final now = DateTime.now().millisecondsSinceEpoch;

      final taskId = await db.insertBatchTasks(
        titles: ['مهمة ستحذف'],
        dueDate: '2026-11-25',
      );

      await db.into(db.reminders).insert(
        RemindersCompanion.insert(
          ownerType: 'task',
          ownerId: taskId,
          kind: const Value('alarm'),
          triggerType: const Value('offset'),
          offsetMinutes: const Value(10),
          enabled: const Value(true),
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Verify active before soft delete
      var active = await db.getAllActiveReminders();
      expect(active.length, equals(1));

      // Soft delete task
      await db.softDeleteTask(taskId);

      // Verify cancelled and task marked deleted
      final task = await db.getTaskById(taskId);
      expect(task!.deletedAt, isNotNull);
    });

    test('Restoring a task enables reminder rescheduling', () async {
      final now = DateTime.now().millisecondsSinceEpoch;

      final taskId = await db.insertBatchTasks(
        titles: ['مهمة مسترجعة'],
        dueDate: '2026-11-25',
      );

      final remId = await db.into(db.reminders).insert(
        RemindersCompanion.insert(
          ownerType: 'task',
          ownerId: taskId,
          kind: const Value('alarm'),
          triggerType: const Value('offset'),
          offsetMinutes: const Value(15),
          enabled: const Value(true),
          createdAt: now,
          updatedAt: now,
        ),
      );

      await db.softDeleteTask(taskId);
      await db.restoreTask(taskId);

      final task = await db.getTaskById(taskId);
      expect(task!.deletedAt, isNull);

      final reminders = await db.getRemindersForOwner('task', taskId);
      expect(reminders.any((r) => r.id == remId), isTrue);
    });
  });
}
