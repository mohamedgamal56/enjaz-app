import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables.dart';
import 'seed_reasons.dart';
import '../../features/tasks/domain/task_status_service.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  Tasks,
  TaskEvents,
  Reasons,
  Goals,
  Milestones,
  GoalUpdates,
  Ideas,
  Tags,
  IdeaTags,
  Recurrences,
  Settings,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();

          // Seed default reasons
          final now = DateTime.now().millisecondsSinceEpoch;
          for (final r in initialSeedReasons) {
            await into(reasons).insert(
              ReasonsCompanion.insert(
                labelAr: r.labelAr,
                labelEn: Value(r.labelEn),
                category: r.category,
                createdAt: now,
                updatedAt: now,
                isDefault: const Value(true),
                usageCount: const Value(0),
                archived: const Value(false),
              ),
            );
          }
        },
        onUpgrade: (Migrator m, int from, int to) async {
          // Versioned migrations go here
        },
      );

  // -------------------------------------------------------------
  // TASKS QUERIES
  // -------------------------------------------------------------

  /// Watch active tasks scheduled for a specific date (YYYY-MM-DD)
  Stream<List<Task>> watchTasksForDate(String date) {
    return (select(tasks)
          ..where((t) => t.dueDate.equals(date) & t.deletedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.status.equals('done'),
                  mode: OrderingMode.asc,
                ),
            (t) => OrderingTerm(
                  expression: t.dueTime,
                  mode: OrderingMode.asc,
                ),
            (t) => OrderingTerm(
                  expression: t.id,
                  mode: OrderingMode.asc,
                ),
          ]))
        .watch();
  }

  /// Watch overdue tasks (due before today, not done or stopped, not deleted)
  Stream<List<Task>> watchOverdueTasks(String todayDate) {
    return (select(tasks)
          ..where((t) =>
              t.dueDate.isNotNull() &
              t.dueDate.isSmallerThanValue(todayDate) &
              t.status.isNotIn(const ['done', 'stopped']) &
              t.deletedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.dueDate,
                  mode: OrderingMode.asc,
                ),
          ]))
        .watch();
  }

  /// Watch postponed tasks whose postponedUntil date is today or earlier
  Stream<List<Task>> watchPostponedDueTasks(String todayDate) {
    return (select(tasks)
          ..where((t) =>
              t.status.equals('postponed') &
              t.postponedUntil.isNotNull() &
              t.postponedUntil.isSmallerOrEqualValue(todayDate) &
              t.deletedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.postponedUntil,
                  mode: OrderingMode.asc,
                ),
          ]))
        .watch();
  }

  /// Watch count of undated active tasks in the Inbox
  Stream<int> watchUndatedTasksCount() {
    return (select(tasks)
          ..where((t) =>
              t.dueDate.isNull() &
              t.deletedAt.isNull() &
              t.status.isNotIn(const ['done', 'stopped'])))
        .watch()
        .map((list) => list.length);
  }

  /// Watch undated tasks for Inbox sheet / screen
  Stream<List<Task>> watchUndatedTasks() {
    return (select(tasks)
          ..where((t) => t.dueDate.isNull() & t.deletedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.id,
                  mode: OrderingMode.desc,
                ),
          ]))
        .watch();
  }

  /// Watch a single task by ID
  Stream<Task?> watchTaskById(int id) {
    return (select(tasks)..where((t) => t.id.equals(id))).watchSingleOrNull();
  }

  /// Get single task by ID
  Future<Task?> getTaskById(int id) {
    return (select(tasks)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Watch all events for a given task
  Stream<List<TaskEvent>> watchTaskEvents(int taskId) {
    return (select(taskEvents)
          ..where((e) => e.taskId.equals(taskId) & e.deletedAt.isNull())
          ..orderBy([
            (e) => OrderingTerm(
                  expression: e.at,
                  mode: OrderingMode.asc,
                ),
          ]))
        .watch();
  }

  /// Watch reasons, optionally filtered by category
  Stream<List<Reason>> watchReasons({String? category}) {
    final query = select(reasons)..where((r) => r.archived.equals(false));
    if (category != null && category.isNotEmpty && category != 'any') {
      query.where((r) => r.category.equals(category) | r.category.equals('any'));
    }
    query.orderBy([
      (r) => OrderingTerm(expression: r.usageCount, mode: OrderingMode.desc),
      (r) => OrderingTerm(expression: r.id, mode: OrderingMode.asc),
    ]);
    return query.watch();
  }

  // -------------------------------------------------------------
  // MUTATIONS & TRANSACTIONS
  // -------------------------------------------------------------

  /// Create a new task and record its initial event
  Future<int> insertNewTask(TasksCompanion task) async {
    return transaction(() async {
      final taskId = await into(tasks).insert(task);
      final now = task.createdAt.present
          ? task.createdAt.value
          : DateTime.now().millisecondsSinceEpoch;
      final st = task.status.present ? task.status.value : 'todo';
      final pr = task.progress.present ? task.progress.value : 0;

      await into(taskEvents).insert(
        TaskEventsCompanion.insert(
          taskId: taskId,
          at: now,
          fromStatus: '',
          toStatus: st,
          progress: pr,
          createdAt: now,
          updatedAt: now,
          reasonText: task.reasonText,
          reasonId: task.reasonId,
          note: task.notes,
        ),
      );

      return taskId;
    });
  }

  /// Update task status and write audit task_event adhering to Section 5
  Future<int> updateTaskStatus({
    required Task task,
    required String newStatus,
    int? progress,
    int? reasonId,
    String? reasonText,
    String? note,
    String? postponedUntil,
    String? outcomeNote,
  }) async {
    return transaction(() async {
      final now = DateTime.now().millisecondsSinceEpoch;

      final transition = TaskStatusService.applyTransition(
        currentStatus: task.status,
        targetStatus: newStatus,
        currentStartedAt: task.startedAt,
        currentFinishedAt: task.finishedAt,
        currentProgress: task.progress,
        currentPostponeCount: task.postponeCount,
        currentPostponedUntil: task.postponedUntil,
        newProgress: progress,
        newPostponedUntil: postponedUntil,
        nowMs: now,
      );

      // 1. Update task row
      await (update(tasks)..where((t) => t.id.equals(task.id))).write(
        TasksCompanion(
          status: Value(transition.status),
          startedAt: Value(transition.startedAt),
          finishedAt: Value(transition.finishedAt),
          progress: Value(transition.progress),
          postponeCount: Value(transition.postponeCount),
          postponedUntil: Value(transition.postponedUntil),
          reasonId: Value(reasonId ?? task.reasonId),
          reasonText: Value(reasonText ?? task.reasonText),
          outcomeNote: outcomeNote != null ? Value(outcomeNote) : const Value.absent(),
          updatedAt: Value(now),
        ),
      );

      // 2. Increment usage count on Reason if used
      if (reasonId != null && reasonId > 0) {
        await customUpdate(
          'UPDATE reasons SET usage_count = usage_count + 1 WHERE id = ?',
          variables: [Variable.withInt(reasonId)],
          updates: {reasons},
        );
      }

      // 3. Write task event log
      final eventId = await into(taskEvents).insert(
        TaskEventsCompanion.insert(
          taskId: task.id,
          at: now,
          fromStatus: task.status,
          toStatus: newStatus,
          progress: transition.progress,
          createdAt: now,
          updatedAt: now,
          reasonId: Value(reasonId),
          reasonText: Value(reasonText),
          note: Value(note ?? outcomeNote),
        ),
      );

      return eventId;
    });
  }

  /// Undo the last status change for a task (Rule 7)
  Future<void> undoStatusChange(int taskId, int eventId) async {
    await transaction(() async {
      // Find the event
      final event = await (select(taskEvents)..where((e) => e.id.equals(eventId))).getSingleOrNull();
      if (event == null) return;

      final currentTask = await getTaskById(taskId);
      if (currentTask == null) return;

      // Delete the event
      await (delete(taskEvents)..where((e) => e.id.equals(eventId))).go();

      // Look for previous event to restore prior state
      final prevEvent = await (select(taskEvents)
            ..where((e) => e.taskId.equals(taskId) & e.deletedAt.isNull())
            ..orderBy([(e) => OrderingTerm(expression: e.at, mode: OrderingMode.desc)])
            ..limit(1))
          .getSingleOrNull();

      final targetStatus = event.fromStatus.isNotEmpty ? event.fromStatus : 'todo';
      final prevProgress = prevEvent?.progress ?? 0;

      await (update(tasks)..where((t) => t.id.equals(taskId))).write(
        TasksCompanion(
          status: Value(targetStatus),
          progress: Value(prevProgress),
          finishedAt: targetStatus == 'done' ? Value(currentTask.finishedAt) : const Value(null),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );
    });
  }

  /// Move task to a new date (e.g. Move to Today)
  Future<void> moveTaskToDate(int taskId, String newDate) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(tasks)..where((t) => t.id.equals(taskId))).write(
      TasksCompanion(
        dueDate: Value(newDate),
        updatedAt: Value(now),
      ),
    );
  }

  /// Soft delete task
  Future<void> softDeleteTask(int taskId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(tasks)..where((t) => t.id.equals(taskId))).write(
      TasksCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  /// Restore soft-deleted task
  Future<void> restoreTask(int taskId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(tasks)..where((t) => t.id.equals(taskId))).write(
      TasksCompanion(
        deletedAt: const Value(null),
        updatedAt: Value(now),
      ),
    );
  }

  /// Update task general fields (title, notes, priority, time, location)
  Future<void> updateTaskFields(TasksCompanion task) async {
    await (update(tasks)..where((t) => t.id.equals(task.id.value))).write(task);
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'enjaz.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});
