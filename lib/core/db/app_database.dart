import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables.dart';
import 'seed_reasons.dart';
import 'seed_finance.dart';
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
  VoiceNotes,
  Reminders,
  Notes,
  Habits,
  HabitItems,
  HabitLogs,
  HabitItemLogs,
  FinanceCategories,
  Transactions,
  QuickExpenses,
  WishlistItems,
  Obligations,
  ObligationInstances,
  Budgets,
  HealthItems,
  HealthEvents,
  Treatments,
  TreatmentChecks,
  UnrecognizedPhrases,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 8;

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

          // Seed default finance categories and quick expenses (Roadmap v2.0 Round 5)
          await _seedFinanceDefaults();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          if (from >= 7 && from < 8) {
            await m.createTable(unrecognizedPhrases);
            await customStatement('''
              INSERT INTO reminders (owner_type, owner_id, kind, trigger_type, offset_minutes, enabled, created_at, updated_at)
              SELECT 'task', t.id, 'alarm', 'offset', t.reminder_offset_minutes, 1, t.created_at, t.updated_at
              FROM tasks t WHERE t.reminder_offset_minutes IS NOT NULL AND t.deleted_at IS NULL
              AND NOT EXISTS (SELECT 1 FROM reminders r WHERE r.owner_type = 'task' AND r.owner_id = t.id)
            ''');
          } else if (from < 7) {
            await m.createTable(unrecognizedPhrases);
          }
          if (from < 2) {
            await m.createTable(voiceNotes);
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_voice_notes_parent ON voice_notes (parent_type, parent_id);',
            );
          }
          if (from < 3) {
            await m.createTable(reminders);
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_reminders_owner ON reminders (owner_type, owner_id);',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_reminders_enabled ON reminders (enabled);',
            );

            // Migrate existing tasks with reminder_offset_minutes
            final now = DateTime.now().millisecondsSinceEpoch;
            await customStatement('''
              INSERT INTO reminders (owner_type, owner_id, kind, trigger_type, offset_minutes, message, enabled, created_at, updated_at)
              SELECT 'task', id, 'alarm', 'offset', reminder_offset_minutes, title, 1, $now, $now
              FROM tasks
              WHERE reminder_offset_minutes IS NOT NULL AND deleted_at IS NULL;
            ''');
          }
          if (from < 4) {
            await m.createTable(notes);
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_notes_date ON notes (note_date);',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_notes_pinned ON notes (pinned);',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_notes_deleted ON notes (deleted_at);',
            );
          }
          if (from < 5) {
            await m.createTable(habits);
            await m.createTable(habitItems);
            await m.createTable(habitLogs);
            await m.createTable(habitItemLogs);
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_habits_deleted ON habits (deleted_at);',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_habits_archived ON habits (archived);',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_habit_items_habit ON habit_items (habit_id);',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_habit_logs_habit_date ON habit_logs (habit_id, log_date);',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_habit_logs_date ON habit_logs (log_date);',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_habit_logs_deleted ON habit_logs (deleted_at);',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_habit_item_logs_habit_item_date ON habit_item_logs (habit_id, item_id, log_date);',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_habit_item_logs_date ON habit_item_logs (log_date);',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_habit_item_logs_deleted ON habit_item_logs (deleted_at);',
            );
          }
          if (from < 6) {
            await m.createTable(financeCategories);
            await m.createTable(transactions);
            await m.createTable(quickExpenses);
            await m.createTable(wishlistItems);
            await m.createTable(obligations);
            await m.createTable(obligationInstances);
            await m.createTable(budgets);

            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_fin_cat_kind ON finance_categories (kind);',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_fin_cat_archived ON finance_categories (archived);',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_transactions_date_kind ON transactions (local_date, kind);',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_transactions_category ON transactions (category_id);',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_transactions_deleted ON transactions (deleted_at);',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_transactions_occurred ON transactions (occurred_at);',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_quick_expenses_sort ON quick_expenses (sort_order);',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_wishlist_status ON wishlist_items (status);',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_wishlist_deleted ON wishlist_items (deleted_at);',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_obligations_deleted ON obligations (deleted_at);',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_obligation_instances_due_status ON obligation_instances (due_date, status);',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_obligation_instances_obligation ON obligation_instances (obligation_id);',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_budgets_month_category ON budgets (month, category_id);',
            );

            await _seedFinanceDefaults();
          }
          if (from < 7) {
            await m.createTable(healthItems);
            await m.createTable(healthEvents);
            await m.createTable(treatments);
            await m.createTable(treatmentChecks);

            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_health_items_status ON health_items (status);',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_health_items_local_date ON health_items (local_date);',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_health_items_deleted ON health_items (deleted_at);',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_health_events_item_id ON health_events (health_item_id);',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_health_events_at ON health_events (at);',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_treatments_adherence ON treatments (adherence);',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_treatments_deleted ON treatments (deleted_at);',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_treatment_checks_treatment_date ON treatment_checks (treatment_id, check_date);',
            );
          }
        },
      );

  Future<void> _seedFinanceDefaults() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final catMap = <String, int>{};

    for (final c in initialSeedFinanceCategories) {
      final id = await into(financeCategories).insert(
        FinanceCategoriesCompanion.insert(
          nameAr: c.nameAr,
          nameEn: Value(c.nameEn),
          kind: c.kind,
          nature: Value(c.nature),
          icon: Value(c.icon),
          color: Value(c.color),
          isDefault: const Value(true),
          archived: const Value(false),
          sortOrder: Value(c.sortOrder),
          createdAt: now,
          updatedAt: now,
        ),
      );
      catMap[c.nameAr] = id;
    }

    for (final q in initialSeedQuickExpenses) {
      final catId = catMap[q.categoryNameAr] ?? 1;
      await into(quickExpenses).insert(
        QuickExpensesCompanion.insert(
          label: q.label,
          categoryId: catId,
          defaultAmountMinor: q.defaultAmountMinor,
          nature: Value(q.nature),
          sortOrder: Value(q.sortOrder),
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
  }

  // -------------------------------------------------------------
  // TASKS QUERIES
  // -------------------------------------------------------------

  /// Get all active non-deleted tasks
  Future<List<Task>> getAllActiveTasks() {
    return (select(tasks)..where((t) => t.deletedAt.isNull())).get();
  }

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
  /// Insert a task event into the append-only log
  Future<int> insertTaskEvent(TaskEventsCompanion companion) {
    return into(taskEvents).insert(companion);
  }

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

  /// Watch all reasons for Reasons Manager
  Stream<List<Reason>> watchAllReasons({bool includeArchived = false}) {
    final q = select(reasons);
    if (!includeArchived) {
      q.where((r) => r.archived.equals(false));
    }
    q.orderBy([
      (r) => OrderingTerm(expression: r.category, mode: OrderingMode.asc),
      (r) => OrderingTerm(expression: r.usageCount, mode: OrderingMode.desc),
      (r) => OrderingTerm(expression: r.id, mode: OrderingMode.asc),
    ]);
    return q.watch();
  }

  /// Watch tasks for History Screen with search and multi-criteria filters
  Stream<List<Task>> watchHistoryTasks({
    String? query,
    List<String>? statusFilter,
    String? kindFilter,
    bool oldestFirst = false,
  }) {
    final q = select(tasks)..where((t) => t.deletedAt.isNull());
    if (query != null && query.trim().isNotEmpty) {
      final pattern = '%${query.trim()}%';
      q.where((t) => t.title.like(pattern) | t.notes.like(pattern) | t.reasonText.like(pattern));
    }
    if (statusFilter != null && statusFilter.isNotEmpty) {
      q.where((t) => t.status.isIn(statusFilter));
    }
    if (kindFilter != null && kindFilter.isNotEmpty) {
      q.where((t) => t.kind.equals(kindFilter));
    }
    q.orderBy([
      (t) => OrderingTerm(
            expression: t.createdAt,
            mode: oldestFirst ? OrderingMode.asc : OrderingMode.desc,
          ),
    ]);
    return q.watch();
  }

  /// Watch soft-deleted tasks for Trash Screen
  Stream<List<Task>> watchTrashTasks() {
    return (select(tasks)
          ..where((t) => t.deletedAt.isNotNull())
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.deletedAt,
                  mode: OrderingMode.desc,
                ),
          ]))
        .watch();
  }

  // -------------------------------------------------------------
  // GOALS & MILESTONES QUERIES
  // -------------------------------------------------------------

  /// Watch goals by status (active, paused, done, abandoned)
  Stream<List<Goal>> watchGoals({String? status}) {
    final q = select(goals)..where((g) => g.deletedAt.isNull());
    if (status != null && status.isNotEmpty) {
      q.where((g) => g.status.equals(status));
    }
    q.orderBy([(g) => OrderingTerm(expression: g.id, mode: OrderingMode.desc)]);
    return q.watch();
  }

  /// Watch single goal by ID
  Stream<Goal?> watchGoalById(int id) {
    return (select(goals)..where((g) => g.id.equals(id))).watchSingleOrNull();
  }

  /// Get single goal by ID
  Future<Goal?> getGoalById(int id) {
    return (select(goals)..where((g) => g.id.equals(id))).getSingleOrNull();
  }

  /// Watch milestones for a goal ordered by sortOrder
  Stream<List<Milestone>> watchMilestonesForGoal(int goalId) {
    return (select(milestones)
          ..where((m) => m.goalId.equals(goalId) & m.deletedAt.isNull())
          ..orderBy([
            (m) => OrderingTerm(expression: m.sortOrder, mode: OrderingMode.asc),
            (m) => OrderingTerm(expression: m.id, mode: OrderingMode.asc),
          ]))
        .watch();
  }

  /// Watch numeric progress updates for a goal
  Stream<List<GoalUpdate>> watchGoalUpdates(int goalId) {
    return (select(goalUpdates)
          ..where((u) => u.goalId.equals(goalId) & u.deletedAt.isNull())
          ..orderBy([
            (u) => OrderingTerm(expression: u.at, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  /// Watch tasks linked to a goal
  Stream<List<Task>> watchTasksForGoal(int goalId) {
    return (select(tasks)
          ..where((t) => t.goalId.equals(goalId) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc)]))
        .watch();
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

  /// Multi-line paste import: inserts multiple tasks in a single atomic transaction
  Future<int> insertBatchTasks({
    required List<String> titles,
    String kind = 'task',
    String? dueDate,
  }) async {
    return transaction(() async {
      int count = 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final raw in titles) {
        final trimmed = raw.trim();
        if (trimmed.isEmpty) continue;

        final companion = TasksCompanion.insert(
          title: trimmed,
          kind: Value(kind),
          dueDate: dueDate != null ? Value(dueDate) : const Value.absent(),
          createdAt: now,
          updatedAt: now,
          status: const Value('todo'),
          progress: const Value(0),
        );
        await insertNewTask(companion);
        count++;
      }
      return count;
    });
  }

  /// Add custom reason
  Future<int> insertCustomReason({
    required String labelAr,
    String? labelEn,
    required String category,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    return into(reasons).insert(
      ReasonsCompanion.insert(
        labelAr: labelAr,
        labelEn: Value(labelEn),
        category: category,
        isDefault: const Value(false),
        usageCount: const Value(0),
        archived: const Value(false),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  /// Update existing reason
  Future<void> updateReasonData({
    required int id,
    required String labelAr,
    String? labelEn,
    required String category,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(reasons)..where((r) => r.id.equals(id))).write(
      ReasonsCompanion(
        labelAr: Value(labelAr),
        labelEn: Value(labelEn),
        category: Value(category),
        updatedAt: Value(now),
      ),
    );
  }

  /// Archive reason (Spec Section 4: reasons are archived, never hard deleted)
  Future<void> archiveReason(int id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(reasons)..where((r) => r.id.equals(id))).write(
      ReasonsCompanion(
        archived: const Value(true),
        updatedAt: Value(now),
      ),
    );
  }

  /// Permanently purge soft-deleted trash tasks
  Future<void> purgeTrash() async {
    await purgeTrashDetailed();
  }

  /// Permanently purge soft-deleted records from tasks, goals, milestones, ideas, voice notes
  /// AND deletes orphaned audio files from disk.
  /// Returns (itemsCount, filesCount, bytesFreed).
  Future<(int, int, int)> purgeTrashDetailed() async {
    final deletedTaskIds = (await (select(tasks)..where((t) => t.deletedAt.isNotNull())).get()).map((t) => t.id).toSet();
    final deletedGoalIds = (await (select(goals)..where((g) => g.deletedAt.isNotNull())).get()).map((g) => g.id).toSet();
    final deletedIdeaIds = (await (select(ideas)..where((i) => i.deletedAt.isNotNull())).get()).map((i) => i.id).toSet();
    final deletedNoteIds = (await (select(notes)..where((n) => n.deletedAt.isNotNull())).get()).map((n) => n.id).toSet();
    final deletedHealthItemIds = (await (select(healthItems)..where((h) => h.deletedAt.isNotNull())).get()).map((h) => h.id).toSet();

    final allVoiceNotes = await select(voiceNotes).get();
    final toDeleteVoiceNotes = allVoiceNotes.where((v) {
      if (v.deletedAt != null) return true;
      if (v.parentType == 'task' && deletedTaskIds.contains(v.parentId)) return true;
      if (v.parentType == 'goal' && deletedGoalIds.contains(v.parentId)) return true;
      if (v.parentType == 'idea' && deletedIdeaIds.contains(v.parentId)) return true;
      if (v.parentType == 'note' && deletedNoteIds.contains(v.parentId)) return true;
      if (v.parentType == 'health_item' && deletedHealthItemIds.contains(v.parentId)) return true;
      return false;
    }).toList();

    int filesDeleted = 0;
    int bytesFreed = 0;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      for (final vn in toDeleteVoiceNotes) {
        bytesFreed += vn.sizeBytes;
        final filePath = p.join(appDir.path, vn.fileName);
        final file = File(filePath);
        if (await file.exists()) {
          try {
            await file.delete();
            filesDeleted++;
          } catch (_) {}
        }
      }
    } catch (_) {}

    int itemsPurged = 0;
    await transaction(() async {
      final deletedVoiceIds = toDeleteVoiceNotes.map((v) => v.id).toSet();
      if (deletedVoiceIds.isNotEmpty) {
        itemsPurged += await (delete(voiceNotes)..where((v) => v.id.isIn(deletedVoiceIds))).go();
      }
      itemsPurged += await (delete(tasks)..where((t) => t.deletedAt.isNotNull())).go();
      itemsPurged += await (delete(goals)..where((g) => g.deletedAt.isNotNull())).go();
      itemsPurged += await (delete(milestones)..where((m) => m.deletedAt.isNotNull())).go();
      itemsPurged += await (delete(ideas)..where((i) => i.deletedAt.isNotNull())).go();
      itemsPurged += await (delete(notes)..where((n) => n.deletedAt.isNotNull())).go();
      itemsPurged += await (delete(habitLogs)..where((l) => l.deletedAt.isNotNull())).go();
      itemsPurged += await (delete(habitItemLogs)..where((l) => l.deletedAt.isNotNull())).go();
      itemsPurged += await (delete(habitItems)..where((i) => i.deletedAt.isNotNull())).go();
      itemsPurged += await (delete(habits)..where((h) => h.deletedAt.isNotNull())).go();
      itemsPurged += await (delete(transactions)..where((t) => t.deletedAt.isNotNull())).go();
      itemsPurged += await (delete(wishlistItems)..where((w) => w.deletedAt.isNotNull())).go();
      itemsPurged += await (delete(obligations)..where((o) => o.deletedAt.isNotNull())).go();
      itemsPurged += await (delete(healthEvents)..where((e) => e.deletedAt.isNotNull())).go();
      itemsPurged += await (delete(healthItems)..where((h) => h.deletedAt.isNotNull())).go();
      itemsPurged += await (delete(treatmentChecks)..where((c) => c.deletedAt.isNotNull())).go();
      itemsPurged += await (delete(treatments)..where((t) => t.deletedAt.isNotNull())).go();
    });

    return (itemsPurged, filesDeleted, bytesFreed);
  }

  // -------------------------------------------------------------
  // GOALS & MILESTONES MUTATIONS
  // -------------------------------------------------------------

  /// Insert a new goal
  Future<int> insertNewGoal(GoalsCompanion goal) async {
    return into(goals).insert(goal);
  }

  /// Update goal fields
  Future<void> updateGoalData(GoalsCompanion goal) async {
    await (update(goals)..where((g) => g.id.equals(goal.id.value))).write(goal);
  }

  /// Update goal status (active, paused, done, abandoned) with optional reason
  Future<void> updateGoalStatus(
    int goalId,
    String newStatus, {
    String? reason,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(goals)..where((g) => g.id.equals(goalId))).write(
      GoalsCompanion(
        status: Value(newStatus),
        statusReason: reason != null ? Value(reason) : const Value.absent(),
        completedAt: newStatus == 'done' ? Value(now) : const Value(null),
        updatedAt: Value(now),
      ),
    );
  }

  /// Soft delete goal
  Future<void> softDeleteGoal(int goalId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(goals)..where((g) => g.id.equals(goalId))).write(
      GoalsCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  /// Insert milestone
  Future<int> insertNewMilestone(MilestonesCompanion milestone) async {
    return into(milestones).insert(milestone);
  }

  /// Update milestone
  Future<void> updateMilestoneData(MilestonesCompanion milestone) async {
    await (update(milestones)..where((m) => m.id.equals(milestone.id.value))).write(milestone);
  }

  /// Toggle milestone pending / done
  Future<void> toggleMilestoneStatus(int milestoneId, bool isDone) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(milestones)..where((m) => m.id.equals(milestoneId))).write(
      MilestonesCompanion(
        status: Value(isDone ? 'done' : 'pending'),
        completedAt: isDone ? Value(now) : const Value(null),
        updatedAt: Value(now),
      ),
    );
  }

  /// Delete milestone (soft delete)
  Future<void> deleteMilestoneSoft(int milestoneId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(milestones)..where((m) => m.id.equals(milestoneId))).write(
      MilestonesCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  /// Log numeric goal progress (valueDelta + optional note) and update goal's currentValue
  Future<void> logGoalProgress(
    int goalId,
    double delta, {
    String? note,
  }) async {
    return transaction(() async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final goal = await getGoalById(goalId);
      if (goal == null) return;

      final newCurrent = (goal.currentValue ?? 0.0) + delta;

      // 1. Update goal currentValue
      await (update(goals)..where((g) => g.id.equals(goalId))).write(
        GoalsCompanion(
          currentValue: Value(newCurrent),
          updatedAt: Value(now),
        ),
      );

      // 2. Insert goal_updates entry
      await into(goalUpdates).insert(
        GoalUpdatesCompanion.insert(
          goalId: goalId,
          at: now,
          note: note != null ? Value(note) : const Value.absent(),
          valueDelta: Value(delta),
          createdAt: now,
          updatedAt: now,
        ),
      );
    });
  }

  // -------------------------------------------------------------
  // IDEAS & TAGS QUERIES & MUTATIONS (Phase 4)
  // -------------------------------------------------------------

  /// Watch ideas by status (new, exploring, converted, archived) with optional search query and tag
  Stream<List<Idea>> watchIdeas({String? status, String? searchQuery, int? tagId}) {
    final q = select(ideas)..where((i) => i.deletedAt.isNull());
    if (status != null && status.isNotEmpty) {
      q.where((i) => i.status.equals(status));
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final term = '%${searchQuery.trim()}%';
      q.where((i) => i.title.like(term) | i.description.like(term));
    }
    q.orderBy([(i) => OrderingTerm(expression: i.id, mode: OrderingMode.desc)]);

    if (tagId != null) {
      return q.watch().asyncMap((ideaList) async {
        final filtered = <Idea>[];
        for (final idea in ideaList) {
          final count = await (select(ideaTags)
                ..where((it) => it.ideaId.equals(idea.id) & it.tagId.equals(tagId)))
              .get();
          if (count.isNotEmpty) {
            filtered.add(idea);
          }
        }
        return filtered;
      });
    }

    return q.watch();
  }

  /// Watch single idea by ID
  Stream<Idea?> watchIdeaById(int id) {
    return (select(ideas)..where((i) => i.id.equals(id))).watchSingleOrNull();
  }

  Future<Idea?> getIdeaById(int id) {
    return (select(ideas)..where((i) => i.id.equals(id))).getSingleOrNull();
  }

  /// Watch all non-deleted tags
  Stream<List<Tag>> watchAllTags() {
    return (select(tags)..where((t) => t.deletedAt.isNull())).watch();
  }

  /// Watch tags for a specific idea
  Stream<List<Tag>> watchTagsForIdea(int ideaId) {
    final q = select(tags).join([
      innerJoin(ideaTags, ideaTags.tagId.equalsExp(tags.id)),
    ])..where(ideaTags.ideaId.equals(ideaId) & tags.deletedAt.isNull());

    return q.watch().map((rows) => rows.map((r) => r.readTable(tags)).toList());
  }

  /// Insert new idea with optional tags
  Future<int> insertNewIdea({
    required String title,
    String? description,
    List<String>? tagNames,
  }) async {
    return transaction(() async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final ideaId = await into(ideas).insert(
        IdeasCompanion.insert(
          title: title,
          description: description != null && description.isNotEmpty
              ? Value(description)
              : const Value.absent(),
          status: const Value('new'),
          createdAt: now,
          updatedAt: now,
        ),
      );

      if (tagNames != null && tagNames.isNotEmpty) {
        await syncIdeaTags(ideaId, tagNames);
      }

      return ideaId;
    });
  }

  /// Update idea fields
  Future<void> updateIdeaData(IdeasCompanion idea) async {
    await (update(ideas)..where((i) => i.id.equals(idea.id.value))).write(idea);
  }

  /// Update idea status
  Future<void> updateIdeaStatus(int ideaId, String status) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(ideas)..where((i) => i.id.equals(ideaId))).write(
      IdeasCompanion(
        status: Value(status),
        updatedAt: Value(now),
      ),
    );
  }

  /// Soft delete idea
  Future<void> softDeleteIdea(int ideaId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(ideas)..where((i) => i.id.equals(ideaId))).write(
      IdeasCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  /// Convert idea to Task or Goal
  Future<void> convertIdea({
    required int ideaId,
    required String targetType, // task | goal
    required int targetId,
  }) async {
    return transaction(() async {
      final now = DateTime.now().millisecondsSinceEpoch;
      // 1. Mark idea as converted
      await (update(ideas)..where((i) => i.id.equals(ideaId))).write(
        IdeasCompanion(
          status: const Value('converted'),
          convertedType: Value(targetType),
          convertedId: Value(targetId),
          updatedAt: Value(now),
        ),
      );

      // 2. Move attached voice notes to target (Spec 14.4)
      await moveVoiceNotes(
        fromType: 'idea',
        fromId: ideaId,
        toType: targetType,
        toId: targetId,
      );
    });
  }

  /// Sync idea tags
  Future<void> syncIdeaTags(int ideaId, List<String> tagNames) async {
    return transaction(() async {
      final now = DateTime.now().millisecondsSinceEpoch;
      // remove existing
      await (delete(ideaTags)..where((it) => it.ideaId.equals(ideaId))).go();

      for (final raw in tagNames) {
        final name = raw.trim();
        if (name.isEmpty) continue;

        var tag = await (select(tags)..where((t) => t.name.equals(name) & t.deletedAt.isNull())).getSingleOrNull();
        if (tag == null) {
          final tid = await into(tags).insert(
            TagsCompanion.insert(
              name: name,
              createdAt: now,
              updatedAt: now,
            ),
          );
          tag = await (select(tags)..where((t) => t.id.equals(tid))).getSingle();
        }

        await into(ideaTags).insert(
          IdeaTag(ideaId: ideaId, tagId: tag.id),
        );
      }
    });
  }

  // -------------------------------------------------------------
  // VOICE NOTES QUERIES & MUTATIONS (Addendum v1.1)
  // -------------------------------------------------------------

  /// Watch voice notes for a specific parent (task, idea, goal)
  Stream<List<VoiceNote>> watchVoiceNotes(String parentType, int parentId) {
    return (select(voiceNotes)
          ..where((v) =>
              v.parentType.equals(parentType) &
              v.parentId.equals(parentId) &
              v.deletedAt.isNull())
          ..orderBy([(v) => OrderingTerm(expression: v.id, mode: OrderingMode.asc)]))
        .watch();
  }

  /// Watch count of voice notes for an item
  Stream<int> watchVoiceNotesCount(String parentType, int parentId) {
    return (select(voiceNotes)
          ..where((v) =>
              v.parentType.equals(parentType) &
              v.parentId.equals(parentId) &
              v.deletedAt.isNull()))
        .watch()
        .map((list) => list.length);
  }

  /// Insert voice note
  Future<int> insertVoiceNote(VoiceNotesCompanion note) async {
    return into(voiceNotes).insert(note);
  }

  /// Update label of voice note
  Future<void> updateVoiceNoteLabel(int id, String label) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(voiceNotes)..where((v) => v.id.equals(id))).write(
      VoiceNotesCompanion(
        label: Value(label),
        updatedAt: Value(now),
      ),
    );
  }

  /// Soft delete voice note
  Future<void> softDeleteVoiceNote(int id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(voiceNotes)..where((v) => v.id.equals(id))).write(
      VoiceNotesCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  /// Move voice notes from one item to another (e.g. idea -> task/goal)
  Future<void> moveVoiceNotes({
    required String fromType,
    required int fromId,
    required String toType,
    required int toId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(voiceNotes)
          ..where((v) => v.parentType.equals(fromType) & v.parentId.equals(fromId)))
        .write(
      VoiceNotesCompanion(
        parentType: Value(toType),
        parentId: Value(toId),
        updatedAt: Value(now),
      ),
    );
  }

  /// Storage statistics: (count, totalBytes)
  Future<(int, int)> getVoiceStorageStats() async {
    final all = await (select(voiceNotes)..where((v) => v.deletedAt.isNull())).get();
    int totalBytes = 0;
    for (final v in all) {
      totalBytes += v.sizeBytes;
    }
    return (all.length, totalBytes);
  }

  // --- Phase 5: Stats & Excel Export Queries ---

  /// Get all task events occurring in a date range
  Future<List<TaskEvent>> getEventsForRange(DateTime start, DateTime end) {
    final startMs = start.millisecondsSinceEpoch;
    final endMs = end.millisecondsSinceEpoch;
    return (select(taskEvents)
          ..where((e) =>
              e.at.isBiggerOrEqualValue(startMs) &
              e.at.isSmallerOrEqualValue(endMs) &
              e.deletedAt.isNull())
          ..orderBy([(e) => OrderingTerm(expression: e.at, mode: OrderingMode.asc)]))
        .get();
  }

  /// Get all done events for global streak calculation
  Future<List<TaskEvent>> getAllDoneEvents() {
    return (select(taskEvents)
          ..where((e) => e.toStatus.equals('done') & e.deletedAt.isNull())
          ..orderBy([(e) => OrderingTerm(expression: e.at, mode: OrderingMode.asc)]))
        .get();
  }

  /// Get tasks relevant for statistics and export in a date range
  Future<List<Task>> getTasksForStatsRange(DateTime start, DateTime end) async {
    final startMs = start.millisecondsSinceEpoch;
    final endMs = end.millisecondsSinceEpoch;
    final all = await (select(tasks)..where((t) => t.deletedAt.isNull())).get();

    // If all time range (e.g. from <= 1970 to >= 2099), return all non-deleted tasks
    if (start.year <= 1970 && end.year >= 2099) {
      return all;
    }

    // Get task IDs with any status change event in the range
    final eventsInRange = await (select(taskEvents)
          ..where((e) =>
              e.at.isBiggerOrEqualValue(startMs) &
              e.at.isSmallerOrEqualValue(endMs)))
        .get();
    final eventTaskIds = eventsInRange.map((e) => e.taskId).toSet();

    return all.where((task) {
      // 1. Finished inside range
      if (task.finishedAt != null && task.finishedAt! >= startMs && task.finishedAt! <= endMs) {
        return true;
      }

      // 2. Has an event inside range (postponed, completed, partial, waiting, etc.)
      if (eventTaskIds.contains(task.id)) {
        return true;
      }

      // 3. Scheduled inside range
      if (task.dueDate != null && task.dueDate!.isNotEmpty) {
        try {
          final due = DateTime.parse(task.dueDate!);
          final dueDay = DateTime(due.year, due.month, due.day);
          final startDay = DateTime(start.year, start.month, start.day);
          final endDay = DateTime(end.year, end.month, end.day);
          if (!dueDay.isBefore(startDay) && !dueDay.isAfter(endDay)) {
            return true;
          }
        } catch (_) {}
      } else {
        // No due date: counted by created_at
        if (task.createdAt >= startMs && task.createdAt <= endMs) {
          return true;
        }
      }

      return false;
    }).toList();
  }

  /// Get all active goals (not deleted, status = active)
  Future<List<Goal>> getAllActiveGoals() {
    return (select(goals)..where((g) => g.deletedAt.isNull() & g.status.equals('active'))).get();
  }

  /// Alias for watchVoiceNotesCount
  Stream<int> watchVoiceNoteCount(String parentType, int parentId) => watchVoiceNotesCount(parentType, parentId);

  /// Get all active goals
  Future<List<Goal>> getAllGoalsList() {
    return (select(goals)..where((g) => g.deletedAt.isNull())).get();
  }

  /// Get goal updates in date range
  Future<List<GoalUpdate>> getGoalUpdatesForRange(DateTime start, DateTime end) {
    final startMs = start.millisecondsSinceEpoch;
    final endMs = end.millisecondsSinceEpoch;
    return (select(goalUpdates)
          ..where((u) =>
              u.at.isBiggerOrEqualValue(startMs) &
              u.at.isSmallerOrEqualValue(endMs)))
        .get();
  }

  /// Get all milestones
  Future<List<Milestone>> getAllMilestonesList() {
    return (select(milestones)..where((m) => m.deletedAt.isNull())).get();
  }

  /// Get all ideas
  Future<List<Idea>> getAllIdeasList() {
    return (select(ideas)..where((i) => i.deletedAt.isNull())).get();
  }

  /// Get all active voice notes
  Future<List<VoiceNote>> getAllVoiceNotesList() {
    return (select(voiceNotes)..where((v) => v.deletedAt.isNull())).get();
  }

  /// Get all active reasons
  Future<List<Reason>> getAllReasonsList() {
    return (select(reasons)..where((r) => r.deletedAt.isNull())).get();
  }

  // -------------------------------------------------------------
  // RECURRENCES & REMINDERS QUERIES (Phase 6)
  // -------------------------------------------------------------

  /// Get all active recurrence rules
  Future<List<Recurrence>> getAllActiveRecurrences() {
    return (select(recurrences)..where((r) => r.deletedAt.isNull())).get();
  }

  /// Get recurrence rule by ID
  Future<Recurrence?> getRecurrenceById(int id) {
    return (select(recurrences)..where((r) => r.id.equals(id))).getSingleOrNull();
  }

  /// Insert new recurrence rule
  Future<int> insertRecurrence(RecurrencesCompanion entry) {
    return into(recurrences).insert(entry);
  }

  /// Update recurrence rule
  Future<void> updateRecurrence(RecurrencesCompanion entry) {
    return (update(recurrences)..where((r) => r.id.equals(entry.id.value))).write(entry);
  }

  /// Soft delete recurrence rule
  Future<void> softDeleteRecurrence(int id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(recurrences)..where((r) => r.id.equals(id))).write(
      RecurrencesCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  /// Get existing tasks for a recurrence rule
  Future<List<Task>> getTasksForRecurrence(int recurrenceId) {
    return (select(tasks)..where((t) => t.recurrenceId.equals(recurrenceId) & t.deletedAt.isNull())).get();
  }

  /// Delete future uncompleted tasks for a recurrence rule starting from a specific date
  Future<int> deleteFutureTasksForRecurrence(int recurrenceId, String fromDate) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    return (update(tasks)
          ..where((t) =>
              t.recurrenceId.equals(recurrenceId) &
              t.dueDate.isBiggerOrEqualValue(fromDate) &
              t.status.equals('todo') &
              t.deletedAt.isNull()))
        .write(
      TasksCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  /// Update future uncompleted tasks for a recurrence rule starting from a specific date
  Future<int> updateFutureTasksForRecurrence(
    int recurrenceId,
    String fromDate, {
    required String title,
    String? kind,
    String? dueTime,
    String? priority,
    String? notes,
    int? reminderOffsetMinutes,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    return (update(tasks)
          ..where((t) =>
              t.recurrenceId.equals(recurrenceId) &
              t.dueDate.isBiggerOrEqualValue(fromDate) &
              t.status.isNotValue('done') &
              t.deletedAt.isNull()))
        .write(
      TasksCompanion(
        title: Value(title),
        kind: kind != null ? Value(kind) : const Value.absent(),
        dueTime: Value(dueTime),
        priority: priority != null ? Value(priority) : const Value.absent(),
        notes: Value(notes),
        reminderOffsetMinutes: Value(reminderOffsetMinutes),
        updatedAt: Value(now),
      ),
    );
  }

  /// Get all upcoming uncompleted tasks with reminders
  Future<List<Task>> getUpcomingTasksWithReminders(String minDueDate) {
    return (select(tasks)
          ..where((t) =>
              t.reminderOffsetMinutes.isNotNull() &
              t.dueDate.isBiggerOrEqualValue(minDueDate) &
              t.status.isNotValue('done') &
              t.deletedAt.isNull()))
        .get();
  }


  // -------------------------------------------------------------
  // PHASE 7: SETTINGS, BACKUP & RESTORE
  // -------------------------------------------------------------

  /// Get setting by key
  Future<String?> getSetting(String key) async {
    final row = await (select(settings)..where((s) => s.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  /// Set setting value
  Future<void> setSetting(String key, String value) async {
    await into(settings).insertOnConflictUpdate(
      SettingsCompanion.insert(key: key, value: value),
    );
  }

  /// Get map of task id to voice notes count for tasks.csv
  Future<Map<int, int>> getTaskVoiceNotesCounts() async {
    final vns = await (select(voiceNotes)..where((v) => v.parentType.equals('task') & v.deletedAt.isNull())).get();
    final map = <int, int>{};
    for (final vn in vns) {
      map[vn.parentId] = (map[vn.parentId] ?? 0) + 1;
    }
    return map;
  }

  /// Export all database tables to a single JSON map
  Future<Map<String, dynamic>> exportAllData() async {
    final tasksList = await select(tasks).get();
    final eventsList = await select(taskEvents).get();
    final reasonsList = await select(reasons).get();
    final goalsList = await select(goals).get();
    final milestonesList = await select(milestones).get();
    final goalUpdatesList = await select(goalUpdates).get();
    final ideasList = await select(ideas).get();
    final tagsList = await select(tags).get();
    final ideaTagsList = await select(ideaTags).get();
    final recurrencesList = await select(recurrences).get();
    final settingsList = await select(settings).get();
    final voiceNotesList = await select(voiceNotes).get();
    final notesList = await select(notes).get();
    final remindersList = await select(reminders).get();
    final habitsList = await select(habits).get();
    final habitItemsList = await select(habitItems).get();
    final habitLogsList = await select(habitLogs).get();
    final habitItemLogsList = await select(habitItemLogs).get();
    final finCategoriesList = await select(financeCategories).get();
    final transactionsList = await select(transactions).get();
    final quickExpensesList = await select(quickExpenses).get();
    final wishlistItemsList = await select(wishlistItems).get();
    final obligationsList = await select(obligations).get();
    final obligationInstancesList = await select(obligationInstances).get();
    final budgetsList = await select(budgets).get();
    final healthItemsList = await select(healthItems).get();
    final healthEventsList = await select(healthEvents).get();
    final treatmentsList = await select(treatments).get();
    final treatmentChecksList = await select(treatmentChecks).get();

    return {
      'unrecognized_phrases': (await select(unrecognizedPhrases).get()).map((e) => e.toJson()).toList(),
      'schema_version': schemaVersion,
      'exported_at': DateTime.now().toIso8601String(),
      'tasks': tasksList.map((e) => e.toJson()).toList(),
      'task_events': eventsList.map((e) => e.toJson()).toList(),
      'reasons': reasonsList.map((e) => e.toJson()).toList(),
      'goals': goalsList.map((e) => e.toJson()).toList(),
      'milestones': milestonesList.map((e) => e.toJson()).toList(),
      'goal_updates': goalUpdatesList.map((e) => e.toJson()).toList(),
      'ideas': ideasList.map((e) => e.toJson()).toList(),
      'tags': tagsList.map((e) => e.toJson()).toList(),
      'idea_tags': ideaTagsList.map((e) => e.toJson()).toList(),
      'recurrences': recurrencesList.map((e) => e.toJson()).toList(),
      'settings': settingsList.map((e) => e.toJson()).toList(),
      'voice_notes': voiceNotesList.map((e) => e.toJson()).toList(),
      'notes': notesList.map((e) => e.toJson()).toList(),
      'reminders': remindersList.map((e) => e.toJson()).toList(),
      'habits': habitsList.map((e) => e.toJson()).toList(),
      'habit_items': habitItemsList.map((e) => e.toJson()).toList(),
      'habit_logs': habitLogsList.map((e) => e.toJson()).toList(),
      'habit_item_logs': habitItemLogsList.map((e) => e.toJson()).toList(),
      'finance_categories': finCategoriesList.map((e) => e.toJson()).toList(),
      'transactions': transactionsList.map((e) => e.toJson()).toList(),
      'quick_expenses': quickExpensesList.map((e) => e.toJson()).toList(),
      'wishlist_items': wishlistItemsList.map((e) => e.toJson()).toList(),
      'obligations': obligationsList.map((e) => e.toJson()).toList(),
      'obligation_instances': obligationInstancesList.map((e) => e.toJson()).toList(),
      'budgets': budgetsList.map((e) => e.toJson()).toList(),
      'health_items': healthItemsList.map((e) => e.toJson()).toList(),
      'health_events': healthEventsList.map((e) => e.toJson()).toList(),
      'treatments': treatmentsList.map((e) => e.toJson()).toList(),
      'treatment_checks': treatmentChecksList.map((e) => e.toJson()).toList(),
    };
  }

  /// Import and replace all database tables from a JSON map in a transaction
  Future<void> importAllData(Map<String, dynamic> data) async {
    await transaction(() async {
      await delete(unrecognizedPhrases).go();
      if (data['unrecognized_phrases'] is List) {
        for (final item in data['unrecognized_phrases']) {
          await into(unrecognizedPhrases).insert(UnrecognizedPhrase.fromJson(Map<String, dynamic>.from(item)).toCompanion(false));
        }
      }
      await delete(treatmentChecks).go();
      await delete(treatments).go();
      await delete(healthEvents).go();
      await delete(healthItems).go();
      await delete(budgets).go();
      await delete(obligationInstances).go();
      await delete(obligations).go();
      await delete(wishlistItems).go();
      await delete(quickExpenses).go();
      await delete(transactions).go();
      await delete(financeCategories).go();
      await delete(ideaTags).go();
      await delete(tags).go();
      await delete(voiceNotes).go();
      await delete(taskEvents).go();
      await delete(tasks).go();
      await delete(recurrences).go();
      await delete(goalUpdates).go();
      await delete(milestones).go();
      await delete(goals).go();
      await delete(reasons).go();
      await delete(ideas).go();
      await delete(settings).go();
      await delete(notes).go();
      await delete(reminders).go();
      await delete(habitItemLogs).go();
      await delete(habitLogs).go();
      await delete(habitItems).go();
      await delete(habits).go();

      if (data['reasons'] is List) {
        for (final item in (data['reasons'] as List)) {
          await into(reasons).insert(Reason.fromJson(Map<String, dynamic>.from(item)).toCompanion(false));
        }
      }
      if (data['goals'] is List) {
        for (final item in (data['goals'] as List)) {
          await into(goals).insert(Goal.fromJson(Map<String, dynamic>.from(item)).toCompanion(false));
        }
      }
      if (data['milestones'] is List) {
        for (final item in (data['milestones'] as List)) {
          await into(milestones).insert(Milestone.fromJson(Map<String, dynamic>.from(item)).toCompanion(false));
        }
      }
      if (data['goal_updates'] is List) {
        for (final item in (data['goal_updates'] as List)) {
          await into(goalUpdates).insert(GoalUpdate.fromJson(Map<String, dynamic>.from(item)).toCompanion(false));
        }
      }
      if (data['recurrences'] is List) {
        for (final item in (data['recurrences'] as List)) {
          await into(recurrences).insert(Recurrence.fromJson(Map<String, dynamic>.from(item)).toCompanion(false));
        }
      }
      if (data['tasks'] is List) {
        for (final item in (data['tasks'] as List)) {
          await into(tasks).insert(Task.fromJson(Map<String, dynamic>.from(item)).toCompanion(false));
        }
      }
      if (data['task_events'] is List) {
        for (final item in (data['task_events'] as List)) {
          await into(taskEvents).insert(TaskEvent.fromJson(Map<String, dynamic>.from(item)).toCompanion(false));
        }
      }
      if (data['ideas'] is List) {
        for (final item in (data['ideas'] as List)) {
          await into(ideas).insert(Idea.fromJson(Map<String, dynamic>.from(item)).toCompanion(false));
        }
      }
      if (data['tags'] is List) {
        for (final item in (data['tags'] as List)) {
          await into(tags).insert(Tag.fromJson(Map<String, dynamic>.from(item)).toCompanion(false));
        }
      }
      if (data['idea_tags'] is List) {
        for (final item in (data['idea_tags'] as List)) {
          await into(ideaTags).insert(IdeaTag.fromJson(Map<String, dynamic>.from(item)).toCompanion(false));
        }
      }
      if (data['voice_notes'] is List) {
        for (final item in (data['voice_notes'] as List)) {
          await into(voiceNotes).insert(VoiceNote.fromJson(Map<String, dynamic>.from(item)).toCompanion(false));
        }
      }
      if (data['settings'] is List) {
        for (final item in (data['settings'] as List)) {
          await into(settings).insert(Setting.fromJson(Map<String, dynamic>.from(item)).toCompanion(false));
        }
      }
      if (data['notes'] is List) {
        for (final item in (data['notes'] as List)) {
          await into(notes).insert(Note.fromJson(Map<String, dynamic>.from(item)).toCompanion(false));
        }
      }
      if (data['reminders'] is List) {
        for (final item in (data['reminders'] as List)) {
          await into(reminders).insert(Reminder.fromJson(Map<String, dynamic>.from(item)).toCompanion(false));
        }
      }
      if (data['habits'] is List) {
        for (final item in (data['habits'] as List)) {
          await into(habits).insert(Habit.fromJson(Map<String, dynamic>.from(item)).toCompanion(false));
        }
      }
      if (data['habit_items'] is List) {
        for (final item in (data['habit_items'] as List)) {
          await into(habitItems).insert(HabitItem.fromJson(Map<String, dynamic>.from(item)).toCompanion(false));
        }
      }
      if (data['habit_logs'] is List) {
        for (final item in (data['habit_logs'] as List)) {
          await into(habitLogs).insert(HabitLog.fromJson(Map<String, dynamic>.from(item)).toCompanion(false));
        }
      }
      if (data['habit_item_logs'] is List) {
        for (final item in (data['habit_item_logs'] as List)) {
          await into(habitItemLogs).insert(HabitItemLog.fromJson(Map<String, dynamic>.from(item)).toCompanion(false));
        }
      }
      if (data['finance_categories'] is List) {
        for (final item in (data['finance_categories'] as List)) {
          await into(financeCategories).insert(FinanceCategory.fromJson(Map<String, dynamic>.from(item)).toCompanion(false));
        }
      }
      if (data['transactions'] is List) {
        for (final item in (data['transactions'] as List)) {
          await into(transactions).insert(Transaction.fromJson(Map<String, dynamic>.from(item)).toCompanion(false));
        }
      }
      if (data['quick_expenses'] is List) {
        for (final item in (data['quick_expenses'] as List)) {
          await into(quickExpenses).insert(QuickExpense.fromJson(Map<String, dynamic>.from(item)).toCompanion(false));
        }
      }
      if (data['wishlist_items'] is List) {
        for (final item in (data['wishlist_items'] as List)) {
          await into(wishlistItems).insert(WishlistItem.fromJson(Map<String, dynamic>.from(item)).toCompanion(false));
        }
      }
      if (data['obligations'] is List) {
        for (final item in (data['obligations'] as List)) {
          await into(obligations).insert(Obligation.fromJson(Map<String, dynamic>.from(item)).toCompanion(false));
        }
      }
      if (data['obligation_instances'] is List) {
        for (final item in (data['obligation_instances'] as List)) {
          await into(obligationInstances).insert(ObligationInstance.fromJson(Map<String, dynamic>.from(item)).toCompanion(false));
        }
      }
      if (data['budgets'] is List) {
        for (final item in (data['budgets'] as List)) {
          await into(budgets).insert(Budget.fromJson(Map<String, dynamic>.from(item)).toCompanion(false));
        }
      }
      if (data['health_items'] is List) {
        for (final item in (data['health_items'] as List)) {
          await into(healthItems).insert(HealthItem.fromJson(Map<String, dynamic>.from(item)).toCompanion(false));
        }
      }
      if (data['health_events'] is List) {
        for (final item in (data['health_events'] as List)) {
          await into(healthEvents).insert(HealthEvent.fromJson(Map<String, dynamic>.from(item)).toCompanion(false));
        }
      }
      if (data['treatments'] is List) {
        for (final item in (data['treatments'] as List)) {
          await into(treatments).insert(Treatment.fromJson(Map<String, dynamic>.from(item)).toCompanion(false));
        }
      }
      if (data['treatment_checks'] is List) {
        for (final item in (data['treatment_checks'] as List)) {
          await into(treatmentChecks).insert(TreatmentCheck.fromJson(Map<String, dynamic>.from(item)).toCompanion(false));
        }
      }
    });
  }

  // -------------------------------------------------------------
  // ROADMAP V2.0 ROUND 1: SHARED REMINDERS, BULK & TRASH
  // -------------------------------------------------------------

  /// Watch reminders for a specific owner (e.g. task, goal, idea)
  Stream<List<Reminder>> watchRemindersForOwner(String ownerType, int ownerId) {
    return (select(reminders)
          ..where((r) =>
              r.ownerType.equals(ownerType) &
              r.ownerId.equals(ownerId) &
              r.deletedAt.isNull())
          ..orderBy([(r) => OrderingTerm.asc(r.createdAt)]))
        .watch();
  }

  /// Get reminders for a specific owner
  Future<List<Reminder>> getRemindersForOwner(String ownerType, int ownerId) {
    return (select(reminders)
          ..where((r) =>
              r.ownerType.equals(ownerType) &
              r.ownerId.equals(ownerId) &
              r.deletedAt.isNull())
          ..orderBy([(r) => OrderingTerm.asc(r.createdAt)]))
        .get();
  }

  /// Insert a new reminder
  Future<int> insertReminder({
    required String ownerType,
    required int ownerId,
    required String kind,
    String triggerType = 'offset',
    int? offsetMinutes,
    DateTime? absoluteTime,
    String? message,
    bool enabled = true,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return into(reminders).insert(
      RemindersCompanion.insert(
        ownerType: ownerType,
        ownerId: ownerId,
        kind: Value(kind),
        triggerType: Value(triggerType),
        offsetMinutes: Value(offsetMinutes),
        absoluteTime: Value(absoluteTime),
        message: Value(message),
        enabled: Value(enabled),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  /// Update an existing reminder
  Future<bool> updateReminder({
    required int id,
    String? kind,
    String? triggerType,
    int? offsetMinutes,
    DateTime? absoluteTime,
    String? message,
    bool? enabled,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final count = await (update(reminders)..where((r) => r.id.equals(id))).write(
      RemindersCompanion(
        kind: kind != null ? Value(kind) : const Value.absent(),
        triggerType: triggerType != null ? Value(triggerType) : const Value.absent(),
        offsetMinutes: offsetMinutes != null ? Value(offsetMinutes) : const Value.absent(),
        absoluteTime: absoluteTime != null ? Value(absoluteTime) : const Value.absent(),
        message: message != null ? Value(message) : const Value.absent(),
        enabled: enabled != null ? Value(enabled) : const Value.absent(),
        updatedAt: Value(now),
      ),
    );
    return count > 0;
  }

  /// Delete a single reminder
  Future<int> deleteReminder(int id) {
    return (delete(reminders)..where((r) => r.id.equals(id))).go();
  }

  Future<Reminder?> getReminderById(int id) {
    return (select(reminders)..where((r) => r.id.equals(id))).getSingleOrNull();
  }

  /// Delete all reminders for a specific owner
  Future<int> deleteRemindersForOwner(String ownerType, int ownerId) {
    return (delete(reminders)
          ..where((r) => r.ownerType.equals(ownerType) & r.ownerId.equals(ownerId)))
        .go();
  }

  /// Get all active reminders across all modules
  Future<List<Reminder>> getAllActiveReminders() {
    return (select(reminders)
          ..where((r) => r.enabled.equals(true) & r.deletedAt.isNull()))
        .get();
  }

  /// Bulk soft delete tasks (move to trash)
  Future<int> bulkSoftDeleteTasks(List<int> taskIds) async {
    if (taskIds.isEmpty) return 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    return (update(tasks)..where((t) => t.id.isIn(taskIds))).write(
      TasksCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  /// Bulk restore tasks from trash
  Future<int> bulkRestoreTasks(List<int> taskIds) async {
    if (taskIds.isEmpty) return 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    return (update(tasks)..where((t) => t.id.isIn(taskIds))).write(
      TasksCompanion(
        deletedAt: const Value(null),
        updatedAt: Value(now),
      ),
    );
  }

  /// Bulk update tasks status (e.g. mark done or change status)
  Future<int> bulkUpdateTasksStatus(
    List<int> taskIds,
    String newStatus, {
    int? reasonId,
    String? reasonText,
    String? outcomeNote,
  }) async {
    if (taskIds.isEmpty) return 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    int affected = 0;
    for (final id in taskIds) {
      final task = await (select(tasks)..where((t) => t.id.equals(id))).getSingleOrNull();
      if (task != null) {
        await updateTaskStatus(
          task: task,
          newStatus: newStatus,
          reasonId: reasonId,
          reasonText: reasonText,
          outcomeNote: outcomeNote,
        );
        affected++;
      }
    }
    return affected;
  }

  /// Bulk move tasks due date
  Future<int> bulkMoveTasksDueDate(List<int> taskIds, String? newDueDate) async {
    if (taskIds.isEmpty) return 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    return (update(tasks)..where((t) => t.id.isIn(taskIds))).write(
      TasksCompanion(
        dueDate: Value(newDueDate),
        updatedAt: Value(now),
      ),
    );
  }

  /// Permanently delete a single task from trash, removing voice note files & reminders
  Future<void> permanentlyDeleteTask(int taskId) async {
    // 1. Delete voice notes and audio files
    final vns = await (select(voiceNotes)
          ..where((v) => v.parentType.equals('task') & v.parentId.equals(taskId)))
        .get();
    try {
      final appDir = await getApplicationDocumentsDirectory();
      for (final vn in vns) {
        final f = File(p.join(appDir.path, vn.fileName));
        if (await f.exists()) await f.delete();
      }
    } catch (_) {}
    await (delete(voiceNotes)
          ..where((v) => v.parentType.equals('task') & v.parentId.equals(taskId)))
        .go();

    // 2. Delete reminders
    await (delete(reminders)
          ..where((r) => r.ownerType.equals('task') & r.ownerId.equals(taskId)))
        .go();

    // 3. Delete task events & task
    await (delete(taskEvents)..where((e) => e.taskId.equals(taskId))).go();
    await (delete(tasks)..where((t) => t.id.equals(taskId))).go();
  }

  /// Auto-purge trash items deleted more than 30 days ago
  Future<int> purgeTrashOlderThan30Days() async {
    final thirtyDaysAgoMs = DateTime.now().subtract(const Duration(days: 30)).millisecondsSinceEpoch;
    final oldTasks = await (select(tasks)
          ..where((t) => t.deletedAt.isNotNull() & t.deletedAt.isSmallerOrEqualValue(thirtyDaysAgoMs)))
        .get();
    int purged = 0;
    for (final task in oldTasks) {
      await permanentlyDeleteTask(task.id);
      purged++;
    }
    final oldNotes = await (select(notes)
          ..where((n) => n.deletedAt.isNotNull() & n.deletedAt.isSmallerOrEqualValue(thirtyDaysAgoMs)))
        .get();
    for (final note in oldNotes) {
      await permanentlyDeleteNote(note.id);
      purged++;
    }
    final oldHabits = await (select(habits)
          ..where((h) => h.deletedAt.isNotNull() & h.deletedAt.isSmallerOrEqualValue(thirtyDaysAgoMs)))
        .get();
    for (final habit in oldHabits) {
      await permanentlyDeleteHabit(habit.id);
      purged++;
    }
    final oldTxs = await (select(transactions)
          ..where((t) => t.deletedAt.isNotNull() & t.deletedAt.isSmallerOrEqualValue(thirtyDaysAgoMs)))
        .get();
    for (final tx in oldTxs) {
      await permanentlyDeleteTransaction(tx.id);
      purged++;
    }
    final oldWish = await (select(wishlistItems)
          ..where((w) => w.deletedAt.isNotNull() & w.deletedAt.isSmallerOrEqualValue(thirtyDaysAgoMs)))
        .get();
    for (final w in oldWish) {
      await permanentlyDeleteWishlistItem(w.id);
      purged++;
    }
    final oldObs = await (select(obligations)
          ..where((o) => o.deletedAt.isNotNull() & o.deletedAt.isSmallerOrEqualValue(thirtyDaysAgoMs)))
        .get();
    for (final o in oldObs) {
      await permanentlyDeleteObligation(o.id);
      purged++;
    }
    final oldHealth = await (select(healthItems)
          ..where((h) => h.deletedAt.isNotNull() & h.deletedAt.isSmallerOrEqualValue(thirtyDaysAgoMs)))
        .get();
    for (final h in oldHealth) {
      await permanentlyDeleteHealthItem(h.id);
      purged++;
    }
    final oldTreatments = await (select(treatments)
          ..where((t) => t.deletedAt.isNotNull() & t.deletedAt.isSmallerOrEqualValue(thirtyDaysAgoMs)))
        .get();
    for (final t in oldTreatments) {
      await permanentlyDeleteTreatment(t.id);
      purged++;
    }
    return purged;
  }
  // -------------------------------------------------------------
  // NOTES QUERIES (Roadmap v2.0 Round 3)
  // -------------------------------------------------------------
  Stream<List<Note>> watchNotes({
    String? searchQuery,
    String? kind,
    String? tag,
  }) {
    var query = select(notes)..where((n) => n.deletedAt.isNull());

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final term = '%${searchQuery.trim()}%';
      query = query..where((n) => n.title.like(term) | n.body.like(term));
    }
    if (kind != null && kind.isNotEmpty && kind != 'all') {
      query = query..where((n) => n.kind.equals(kind));
    }
    if (tag != null && tag.isNotEmpty) {
      query = query..where((n) => n.tags.like('%$tag%'));
    }

    return (query
          ..orderBy([
            (n) => OrderingTerm(expression: n.pinned, mode: OrderingMode.desc),
            (n) => OrderingTerm(expression: n.createdAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  Future<List<Note>> getAllActiveNotes() {
    return (select(notes)
          ..where((n) => n.deletedAt.isNull())
          ..orderBy([
            (n) => OrderingTerm(expression: n.pinned, mode: OrderingMode.desc),
            (n) => OrderingTerm(expression: n.createdAt, mode: OrderingMode.desc),
          ]))
        .get();
  }

  Stream<List<Note>> watchTrashNotes() {
    return (select(notes)
          ..where((n) => n.deletedAt.isNotNull())
          ..orderBy([(n) => OrderingTerm(expression: n.deletedAt, mode: OrderingMode.desc)]))
        .watch();
  }

  Future<Note?> getNoteById(int id) {
    return (select(notes)..where((n) => n.id.equals(id))).getSingleOrNull();
  }

  Future<int> insertNote(NotesCompanion entry) {
    return into(notes).insert(entry);
  }

  Future<bool> updateNote(NotesCompanion entry) {
    return update(notes).replace(entry);
  }

  Future<int> togglePinNote(int id, bool pinned) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return (update(notes)..where((n) => n.id.equals(id))).write(
      NotesCompanion(
        pinned: Value(pinned),
        updatedAt: Value(now),
      ),
    );
  }

  Future<int> softDeleteNote(int id) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return (update(notes)..where((n) => n.id.equals(id))).write(
      NotesCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  Future<int> restoreNote(int id) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return (update(notes)..where((n) => n.id.equals(id))).write(
      NotesCompanion(
        deletedAt: const Value(null),
        updatedAt: Value(now),
      ),
    );
  }

  Future<int> permanentlyDeleteNote(int id) async {
    final vns = await (select(voiceNotes)
          ..where((v) => v.parentType.equals('note') & v.parentId.equals(id)))
        .get();
    try {
      final appDir = await getApplicationDocumentsDirectory();
      for (final vn in vns) {
        final f = File(p.join(appDir.path, vn.fileName));
        if (await f.exists()) await f.delete();
      }
    } catch (_) {}
    await (delete(voiceNotes)
          ..where((v) => v.parentType.equals('note') & v.parentId.equals(id)))
        .go();
    return (delete(notes)..where((n) => n.id.equals(id))).go();
  }

  // -------------------------------------------------------------
  // ROADMAP V2.0 ROUND 4: HABITS QUERIES
  // -------------------------------------------------------------

  /// Watch active habits ordered by sortOrder then id
  Stream<List<Habit>> watchActiveHabits() {
    return (select(habits)
          ..where((h) => h.deletedAt.isNull() & h.archived.equals(false))
          ..orderBy([
            (h) => OrderingTerm(expression: h.sortOrder, mode: OrderingMode.asc),
            (h) => OrderingTerm(expression: h.id, mode: OrderingMode.asc),
          ]))
        .watch();
  }

  /// Get all active habits
  Future<List<Habit>> getAllActiveHabits() {
    return (select(habits)
          ..where((h) => h.deletedAt.isNull() & h.archived.equals(false))
          ..orderBy([
            (h) => OrderingTerm(expression: h.sortOrder, mode: OrderingMode.asc),
            (h) => OrderingTerm(expression: h.id, mode: OrderingMode.asc),
          ]))
        .get();
  }

  /// Get habit by id
  Future<Habit?> getHabitById(int id) {
    return (select(habits)..where((h) => h.id.equals(id))).getSingleOrNull();
  }

  /// Insert habit
  Future<int> insertHabit(HabitsCompanion habit) {
    return into(habits).insert(habit);
  }

  /// Update habit
  Future<bool> updateHabit(HabitsCompanion habit) {
    return update(habits).replace(habit);
  }

  /// Archive or unarchive habit
  Future<void> archiveHabit(int id, bool isArchived) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(habits)..where((h) => h.id.equals(id))).write(
      HabitsCompanion(
        archived: Value(isArchived),
        updatedAt: Value(now),
      ),
    );
  }

  /// Soft delete habit and its items & logs to trash
  Future<void> softDeleteHabit(int id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await transaction(() async {
      await (update(habits)..where((h) => h.id.equals(id))).write(
        HabitsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      await (update(habitItems)..where((i) => i.habitId.equals(id))).write(
        HabitItemsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      await (update(habitLogs)..where((l) => l.habitId.equals(id))).write(
        HabitLogsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      await (update(habitItemLogs)..where((l) => l.habitId.equals(id))).write(
        HabitItemLogsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      // Cancel reminders
      await (delete(reminders)..where((r) => r.ownerType.equals('habit') & r.ownerId.equals(id))).go();
    });
  }

  /// Restore habit from trash
  Future<void> restoreHabit(int id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await transaction(() async {
      await (update(habits)..where((h) => h.id.equals(id))).write(
        HabitsCompanion(
          deletedAt: const Value(null),
          updatedAt: Value(now),
        ),
      );
      await (update(habitItems)..where((i) => i.habitId.equals(id))).write(
        HabitItemsCompanion(
          deletedAt: const Value(null),
          updatedAt: Value(now),
        ),
      );
      await (update(habitLogs)..where((l) => l.habitId.equals(id))).write(
        HabitLogsCompanion(
          deletedAt: const Value(null),
          updatedAt: Value(now),
        ),
      );
      await (update(habitItemLogs)..where((l) => l.habitId.equals(id))).write(
        HabitItemLogsCompanion(
          deletedAt: const Value(null),
          updatedAt: Value(now),
        ),
      );
    });
  }

  /// Permanently delete habit from trash
  Future<void> permanentlyDeleteHabit(int id) async {
    await transaction(() async {
      await (delete(habitItemLogs)..where((l) => l.habitId.equals(id))).go();
      await (delete(habitLogs)..where((l) => l.habitId.equals(id))).go();
      await (delete(habitItems)..where((i) => i.habitId.equals(id))).go();
      await (delete(reminders)..where((r) => r.ownerType.equals('habit') & r.ownerId.equals(id))).go();
      await (delete(habits)..where((h) => h.id.equals(id))).go();
    });
  }

  /// Watch trash habits
  Stream<List<Habit>> watchTrashHabits() {
    return (select(habits)
          ..where((h) => h.deletedAt.isNotNull())
          ..orderBy([(h) => OrderingTerm(expression: h.deletedAt, mode: OrderingMode.desc)]))
        .watch();
  }

  /// Watch items for a habit
  Stream<List<HabitItem>> watchHabitItems(int habitId) {
    return (select(habitItems)
          ..where((i) => i.habitId.equals(habitId) & i.deletedAt.isNull())
          ..orderBy([(i) => OrderingTerm(expression: i.sortOrder, mode: OrderingMode.asc)]))
        .watch();
  }

  /// Get items for a habit
  Future<List<HabitItem>> getHabitItems(int habitId) {
    return (select(habitItems)
          ..where((i) => i.habitId.equals(habitId) & i.deletedAt.isNull())
          ..orderBy([(i) => OrderingTerm(expression: i.sortOrder, mode: OrderingMode.asc)]))
        .get();
  }

  /// Insert habit item
  Future<int> insertHabitItem(HabitItemsCompanion item) {
    return into(habitItems).insert(item);
  }

  Future<int> deleteHabitItem(int itemId) {
    return (delete(habitItems)..where((i) => i.id.equals(itemId))).go();
  }

  /// Watch logs for a specific date
  Stream<List<HabitLog>> watchHabitLogsForDate(String date) {
    return (select(habitLogs)
          ..where((l) => l.logDate.equals(date) & l.deletedAt.isNull())
          ..orderBy([(l) => OrderingTerm(expression: l.at, mode: OrderingMode.asc)]))
        .watch();
  }

  /// Watch item logs for a specific date
  Stream<List<HabitItemLog>> watchHabitItemLogsForDate(String date) {
    return (select(habitItemLogs)
          ..where((l) => l.logDate.equals(date) & l.deletedAt.isNull())
          ..orderBy([(l) => OrderingTerm(expression: l.doneAt, mode: OrderingMode.asc)]))
        .watch();
  }

  /// Get all logs for a habit in date range
  Future<List<HabitLog>> getHabitLogsForRange(int habitId, String startDate, String endDate) {
    return (select(habitLogs)
          ..where((l) =>
              l.habitId.equals(habitId) &
              l.logDate.isBiggerOrEqualValue(startDate) &
              l.logDate.isSmallerOrEqualValue(endDate) &
              l.deletedAt.isNull())
          ..orderBy([(l) => OrderingTerm(expression: l.at, mode: OrderingMode.asc)]))
        .get();
  }

  /// Get all item logs for a habit in date range
  Future<List<HabitItemLog>> getHabitItemLogsForRange(int habitId, String startDate, String endDate) {
    return (select(habitItemLogs)
          ..where((l) =>
              l.habitId.equals(habitId) &
              l.logDate.isBiggerOrEqualValue(startDate) &
              l.logDate.isSmallerOrEqualValue(endDate) &
              l.deletedAt.isNull())
          ..orderBy([(l) => OrderingTerm(expression: l.doneAt, mode: OrderingMode.asc)]))
        .get();
  }

  /// Get all logs across all habits in date range
  Future<List<HabitLog>> getAllHabitLogsForRange(String startDate, String endDate) {
    return (select(habitLogs)
          ..where((l) =>
              l.logDate.isBiggerOrEqualValue(startDate) &
              l.logDate.isSmallerOrEqualValue(endDate) &
              l.deletedAt.isNull())
          ..orderBy([(l) => OrderingTerm(expression: l.at, mode: OrderingMode.asc)]))
        .get();
  }

  /// Get all item logs across all habits in date range
  Future<List<HabitItemLog>> getAllHabitItemLogsForRange(String startDate, String endDate) {
    return (select(habitItemLogs)
          ..where((l) =>
              l.logDate.isBiggerOrEqualValue(startDate) &
              l.logDate.isSmallerOrEqualValue(endDate) &
              l.deletedAt.isNull())
          ..orderBy([(l) => OrderingTerm(expression: l.doneAt, mode: OrderingMode.asc)]))
        .get();
  }

  /// Log a count tap (+1) with timestamp
  Future<int> logHabitCount(int habitId, String logDate) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return into(habitLogs).insert(
      HabitLogsCompanion.insert(
        habitId: habitId,
        logDate: logDate,
        value: const Value(1.0),
        at: now,
        occurredAt: Value(now),
        localDate: Value(logDate),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  /// Decrement count: remove last log entry for date
  Future<void> decrementHabitCount(int habitId, String logDate) async {
    final lastLog = await (select(habitLogs)
          ..where((l) => l.habitId.equals(habitId) & l.logDate.equals(logDate) & l.deletedAt.isNull())
          ..orderBy([(l) => OrderingTerm(expression: l.at, mode: OrderingMode.desc)])
          ..limit(1))
        .getSingleOrNull();
    if (lastLog != null) {
      await (delete(habitLogs)..where((l) => l.id.equals(lastLog.id))).go();
    }
  }

  /// Toggle check habit (done / not done)
  Future<void> setHabitCheck(int habitId, String logDate, bool done) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (done) {
      final existing = await (select(habitLogs)
            ..where((l) => l.habitId.equals(habitId) & l.logDate.equals(logDate) & l.deletedAt.isNull()))
          .getSingleOrNull();
      if (existing == null) {
        await into(habitLogs).insert(
          HabitLogsCompanion.insert(
            habitId: habitId,
            logDate: logDate,
            value: const Value(1.0),
            at: now,
            occurredAt: Value(now),
            localDate: Value(logDate),
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
    } else {
      await (delete(habitLogs)..where((l) => l.habitId.equals(habitId) & l.logDate.equals(logDate))).go();
    }
  }

  /// Set amount habit value for date
  Future<void> setHabitAmount(int habitId, String logDate, double amount, {String? note}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await (select(habitLogs)
          ..where((l) => l.habitId.equals(habitId) & l.logDate.equals(logDate) & l.deletedAt.isNull()))
        .getSingleOrNull();
    if (existing != null) {
      await (update(habitLogs)..where((l) => l.id.equals(existing.id))).write(
        HabitLogsCompanion(
          value: Value(amount),
          note: Value(note),
          updatedAt: Value(now),
        ),
      );
    } else {
      await into(habitLogs).insert(
        HabitLogsCompanion.insert(
          habitId: habitId,
          logDate: logDate,
          value: Value(amount),
          at: now,
          note: Value(note),
          occurredAt: Value(now),
          localDate: Value(logDate),
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
  }

  /// Toggle checklist item for date
  Future<void> toggleHabitItem(int habitId, int itemId, String logDate, bool done) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (done) {
      final existing = await (select(habitItemLogs)
            ..where((l) =>
                l.habitId.equals(habitId) &
                l.itemId.equals(itemId) &
                l.logDate.equals(logDate) &
                l.deletedAt.isNull()))
          .getSingleOrNull();
      if (existing == null) {
        await into(habitItemLogs).insert(
          HabitItemLogsCompanion.insert(
            habitId: habitId,
            itemId: itemId,
            logDate: logDate,
            doneAt: now,
            occurredAt: Value(now),
            localDate: Value(logDate),
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
    } else {
      await (delete(habitItemLogs)
            ..where((l) =>
                l.habitId.equals(habitId) &
                l.itemId.equals(itemId) &
                l.logDate.equals(logDate)))
          .go();
    }
  }

  /// Delete a single habit log entry
  Future<int> deleteHabitLog(int logId) {
    return (delete(habitLogs)..where((l) => l.id.equals(logId))).go();
  }

  // -------------------------------------------------------------
  // ROADMAP V2.0 ROUND 5: FINANCE (المال)
  // -------------------------------------------------------------

  // --- CATEGORIES ---
  Stream<List<FinanceCategory>> watchActiveFinanceCategories({String? kind}) {
    var q = select(financeCategories)..where((c) => c.archived.equals(false) & c.deletedAt.isNull());
    if (kind != null) {
      q = q..where((c) => c.kind.equals(kind));
    }
    return (q..orderBy([(c) => OrderingTerm.asc(c.sortOrder), (c) => OrderingTerm.asc(c.id)])).watch();
  }

  Future<List<FinanceCategory>> getAllFinanceCategories({String? kind}) {
    var q = select(financeCategories)..where((c) => c.deletedAt.isNull());
    if (kind != null) {
      q = q..where((c) => c.kind.equals(kind));
    }
    return (q..orderBy([(c) => OrderingTerm.asc(c.sortOrder)])).get();
  }

  Future<FinanceCategory?> getFinanceCategoryById(int id) {
    return (select(financeCategories)..where((c) => c.id.equals(id))).getSingleOrNull();
  }

  Future<int> insertFinanceCategory(FinanceCategoriesCompanion cat) {
    return into(financeCategories).insert(cat);
  }

  Future<bool> updateFinanceCategory(FinanceCategoriesCompanion cat) {
    return update(financeCategories).replace(cat);
  }

  Future<void> archiveFinanceCategory(int id, bool isArchived) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(financeCategories)..where((c) => c.id.equals(id))).write(
      FinanceCategoriesCompanion(
        archived: Value(isArchived),
        updatedAt: Value(now),
      ),
    );
  }

  // --- QUICK EXPENSES ---
  Stream<List<QuickExpense>> watchQuickExpenses() {
    return (select(quickExpenses)..orderBy([(q) => OrderingTerm.asc(q.sortOrder)])).watch();
  }

  Future<List<QuickExpense>> getAllQuickExpenses() {
    return (select(quickExpenses)..orderBy([(q) => OrderingTerm.asc(q.sortOrder)])).get();
  }

  Future<int> insertQuickExpense(QuickExpensesCompanion qe) {
    return into(quickExpenses).insert(qe);
  }

  Future<bool> updateQuickExpense(QuickExpensesCompanion qe) {
    return update(quickExpenses).replace(qe);
  }

  Future<int> deleteQuickExpense(int id) {
    return (delete(quickExpenses)..where((q) => q.id.equals(id))).go();
  }

  // --- TRANSACTIONS ---
  Stream<List<Transaction>> watchTransactionsForMonth(String yearMonth) {
    return (select(transactions)
          ..where((t) => t.localDate.like('$yearMonth%') & t.deletedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm.desc(t.localDate),
            (t) => OrderingTerm.desc(t.occurredAt),
            (t) => OrderingTerm.desc(t.id),
          ]))
        .watch();
  }

  Stream<List<Transaction>> watchTransactionsForDate(String date) {
    return (select(transactions)
          ..where((t) => t.localDate.equals(date) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)]))
        .watch();
  }

  Future<List<Transaction>> getTransactionsForRange(String startDate, String endDate) {
    return (select(transactions)
          ..where((t) =>
              t.localDate.isBiggerOrEqualValue(startDate) &
              t.localDate.isSmallerOrEqualValue(endDate) &
              t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.localDate), (t) => OrderingTerm.asc(t.occurredAt)]))
        .get();
  }

  Future<List<Transaction>> getAllActiveTransactions() {
    return (select(transactions)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.localDate), (t) => OrderingTerm.desc(t.occurredAt)]))
        .get();
  }

  Future<Transaction?> getTransactionById(int id) {
    return (select(transactions)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<int> insertTransaction(TransactionsCompanion tx) {
    return into(transactions).insert(tx);
  }

  Future<bool> updateTransaction(TransactionsCompanion tx) {
    return update(transactions).replace(tx);
  }

  Future<void> softDeleteTransaction(int id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(transactions)..where((t) => t.id.equals(id))).write(
      TransactionsCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> restoreTransaction(int id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(transactions)..where((t) => t.id.equals(id))).write(
      TransactionsCompanion(
        deletedAt: const Value(null),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> permanentlyDeleteTransaction(int id) async {
    await (delete(transactions)..where((t) => t.id.equals(id))).go();
  }

  Stream<List<Transaction>> watchTrashTransactions() {
    return (select(transactions)
          ..where((t) => t.deletedAt.isNotNull())
          ..orderBy([(t) => OrderingTerm.desc(t.deletedAt)]))
        .watch();
  }

  // --- WISHLIST ITEMS ---
  Stream<List<WishlistItem>> watchWishlistItems() {
    return (select(wishlistItems)
          ..where((w) => w.deletedAt.isNull())
          ..orderBy([(w) => OrderingTerm.asc(w.status), (w) => OrderingTerm.desc(w.createdAt)]))
        .watch();
  }

  Future<List<WishlistItem>> getAllWishlistItems() {
    return (select(wishlistItems)
          ..where((w) => w.deletedAt.isNull())
          ..orderBy([(w) => OrderingTerm.desc(w.createdAt)]))
        .get();
  }

  Future<WishlistItem?> getWishlistItemById(int id) {
    return (select(wishlistItems)..where((w) => w.id.equals(id))).getSingleOrNull();
  }

  Future<int> insertWishlistItem(WishlistItemsCompanion item) {
    return into(wishlistItems).insert(item);
  }

  Future<bool> updateWishlistItem(WishlistItemsCompanion item) {
    return update(wishlistItems).replace(item);
  }

  Future<void> markWishlistItemBought(int id, int boughtPriceMinor, int transactionId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(wishlistItems)..where((w) => w.id.equals(id))).write(
      WishlistItemsCompanion(
        status: const Value('bought'),
        boughtAt: Value(now),
        boughtPriceMinor: Value(boughtPriceMinor),
        transactionId: Value(transactionId),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> softDeleteWishlistItem(int id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(wishlistItems)..where((w) => w.id.equals(id))).write(
      WishlistItemsCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> restoreWishlistItem(int id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(wishlistItems)..where((w) => w.id.equals(id))).write(
      WishlistItemsCompanion(
        deletedAt: const Value(null),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> permanentlyDeleteWishlistItem(int id) async {
    await (delete(wishlistItems)..where((w) => w.id.equals(id))).go();
  }

  Stream<List<WishlistItem>> watchTrashWishlistItems() {
    return (select(wishlistItems)
          ..where((w) => w.deletedAt.isNotNull())
          ..orderBy([(w) => OrderingTerm.desc(w.deletedAt)]))
        .watch();
  }

  // --- OBLIGATIONS & INSTANCES ---
  Stream<List<Obligation>> watchObligations() {
    return (select(obligations)
          ..where((o) => o.deletedAt.isNull())
          ..orderBy([(o) => OrderingTerm.asc(o.name)]))
        .watch();
  }

  Future<List<Obligation>> getAllObligations() {
    return (select(obligations)
          ..where((o) => o.deletedAt.isNull())
          ..orderBy([(o) => OrderingTerm.asc(o.name)]))
        .get();
  }

  Future<Obligation?> getObligationById(int id) {
    return (select(obligations)..where((o) => o.id.equals(id))).getSingleOrNull();
  }

  Future<int> insertObligation(ObligationsCompanion ob) {
    return into(obligations).insert(ob);
  }

  Future<bool> updateObligation(ObligationsCompanion ob) {
    return update(obligations).replace(ob);
  }

  Future<void> softDeleteObligation(int id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await transaction(() async {
      await (update(obligations)..where((o) => o.id.equals(id))).write(
        ObligationsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      // Cancel shared reminders for this obligation
      await (delete(reminders)..where((r) => r.ownerType.equals('obligation') & r.ownerId.equals(id))).go();
    });
  }

  Future<void> restoreObligation(int id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(obligations)..where((o) => o.id.equals(id))).write(
      ObligationsCompanion(
        deletedAt: const Value(null),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> permanentlyDeleteObligation(int id) async {
    await transaction(() async {
      await (delete(obligationInstances)..where((i) => i.obligationId.equals(id))).go();
      await (delete(reminders)..where((r) => r.ownerType.equals('obligation') & r.ownerId.equals(id))).go();
      await (delete(obligations)..where((o) => o.id.equals(id))).go();
    });
  }

  Stream<List<Obligation>> watchTrashObligations() {
    return (select(obligations)
          ..where((o) => o.deletedAt.isNotNull())
          ..orderBy([(o) => OrderingTerm.desc(o.deletedAt)]))
        .watch();
  }

  Stream<List<ObligationInstance>> watchObligationInstancesForMonth(String yearMonth) {
    return (select(obligationInstances)
          ..where((i) => i.dueDate.like('$yearMonth%'))
          ..orderBy([(i) => OrderingTerm.asc(i.dueDate)]))
        .watch();
  }

  Future<List<ObligationInstance>> getObligationInstancesForRange(String startDate, String endDate) {
    return (select(obligationInstances)
          ..where((i) =>
              i.dueDate.isBiggerOrEqualValue(startDate) &
              i.dueDate.isSmallerOrEqualValue(endDate))
          ..orderBy([(i) => OrderingTerm.asc(i.dueDate)]))
        .get();
  }

  Future<List<ObligationInstance>> getAllActiveObligationInstances() {
    return (select(obligationInstances)..orderBy([(i) => OrderingTerm.asc(i.dueDate)])).get();
  }

  Future<void> markObligationInstancePaid(int id, int paidAmountMinor, int? transactionId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(obligationInstances)..where((i) => i.id.equals(id))).write(
      ObligationInstancesCompanion(
        status: const Value('paid'),
        paidAt: Value(now),
        paidAmountMinor: Value(paidAmountMinor),
        transactionId: Value(transactionId),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> skipObligationInstance(int id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(obligationInstances)..where((i) => i.id.equals(id))).write(
      ObligationInstancesCompanion(
        status: const Value('skipped'),
        updatedAt: Value(now),
      ),
    );
  }

  // --- BUDGETS ---
  Stream<List<Budget>> watchBudgetsForMonth(String month) {
    return (select(budgets)..where((b) => b.month.equals(month) | b.month.equals('recurring'))).watch();
  }

  Future<List<Budget>> getBudgetsForMonth(String month) {
    return (select(budgets)..where((b) => b.month.equals(month) | b.month.equals('recurring'))).get();
  }

  Future<void> setBudget({int? categoryId, required String month, required int limitMinor}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await (select(budgets)
          ..where((b) =>
              b.month.equals(month) &
              (categoryId == null ? b.categoryId.isNull() : b.categoryId.equals(categoryId))))
        .getSingleOrNull();

    if (existing != null) {
      await (update(budgets)..where((b) => b.id.equals(existing.id))).write(
        BudgetsCompanion(
          limitMinor: Value(limitMinor),
          updatedAt: Value(now),
        ),
      );
    } else {
      await into(budgets).insert(
        BudgetsCompanion.insert(
          categoryId: Value(categoryId),
          month: month,
          limitMinor: limitMinor,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
  }

  Future<int> deleteBudget(int id) {
    return (delete(budgets)..where((b) => b.id.equals(id))).go();
  }

  // -------------------------------------------------------------
  // ROADMAP V2.0 ROUND 6: HEALTH QUERIES & MUTATIONS
  // -------------------------------------------------------------

  Stream<List<HealthItem>> watchActiveHealthItems() {
    return (select(healthItems)
          ..where((h) =>
              h.deletedAt.isNull() &
              h.status.isNotIn(['done', 'skipped']))
          ..orderBy([
            (h) => OrderingTerm.asc(h.neededSince),
            (h) => OrderingTerm.asc(h.id),
          ]))
        .watch();
  }

  Stream<List<HealthItem>> watchDoneHealthItems() {
    return (select(healthItems)
          ..where((h) => h.deletedAt.isNull() & h.status.equals('done'))
          ..orderBy([(h) => OrderingTerm.desc(h.doneAt)]))
        .watch();
  }

  Stream<List<HealthItem>> watchTrashHealthItems() {
    return (select(healthItems)
          ..where((h) => h.deletedAt.isNotNull())
          ..orderBy([(h) => OrderingTerm.desc(h.deletedAt)]))
        .watch();
  }

  Future<List<HealthItem>> getAllActiveHealthItems() {
    return (select(healthItems)..where((h) => h.deletedAt.isNull())).get();
  }

  Future<HealthItem?> getHealthItemById(int id) {
    return (select(healthItems)..where((h) => h.id.equals(id))).getSingleOrNull();
  }

  Future<int> insertHealthItemWithEvent(
    HealthItemsCompanion item, {
    String? eventNote,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final insertedId = await into(healthItems).insert(item);
    final targetStatus = item.status.present ? item.status.value : 'needed';
    await into(healthEvents).insert(
      HealthEventsCompanion.insert(
        healthItemId: insertedId,
        at: now,
        fromStatus: 'none',
        toStatus: targetStatus,
        note: Value(eventNote ?? 'تمت الإضافة'),
        createdAt: now,
        updatedAt: now,
      ),
    );
    return insertedId;
  }

  Future<bool> updateHealthItem(HealthItemsCompanion item) {
    return update(healthItems).replace(item);
  }

  Future<void> scheduleHealthItem(
    int id, {
    required DateTime scheduledAt,
    String? placeOrDoctor,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final item = await getHealthItemById(id);
    if (item == null) return;

    await (update(healthItems)..where((h) => h.id.equals(id))).write(
      HealthItemsCompanion(
        status: const Value('scheduled'),
        scheduledAt: Value(scheduledAt.millisecondsSinceEpoch),
        placeOrDoctor: placeOrDoctor != null ? Value(placeOrDoctor) : const Value.absent(),
        updatedAt: Value(now),
      ),
    );

    await into(healthEvents).insert(
      HealthEventsCompanion.insert(
        healthItemId: id,
        at: now,
        fromStatus: item.status,
        toStatus: 'scheduled',
        note: Value(placeOrDoctor != null ? 'تم تحديد موعد عند: $placeOrDoctor' : 'تم تحديد موعد'),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> postponeHealthItem(
    int id, {
    required String reason,
    String? newDueBy,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final item = await getHealthItemById(id);
    if (item == null) return;

    await (update(healthItems)..where((h) => h.id.equals(id))).write(
      HealthItemsCompanion(
        status: const Value('postponed'),
        postponedReason: Value(reason),
        postponeCount: Value(item.postponeCount + 1),
        dueBy: newDueBy != null ? Value(newDueBy) : const Value.absent(),
        updatedAt: Value(now),
      ),
    );

    await into(healthEvents).insert(
      HealthEventsCompanion.insert(
        healthItemId: id,
        at: now,
        fromStatus: item.status,
        toStatus: 'postponed',
        note: Value(reason),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<int?> completeHealthItem(
    int id, {
    required DateTime doneDate,
    String? resultNote,
    bool followUpNeeded = false,
    int? costMinor,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final item = await getHealthItemById(id);
    if (item == null) return null;

    final doneMs = doneDate.millisecondsSinceEpoch;
    await (update(healthItems)..where((h) => h.id.equals(id))).write(
      HealthItemsCompanion(
        status: const Value('done'),
        doneAt: Value(doneMs),
        resultNote: Value(resultNote),
        followUpNeeded: Value(followUpNeeded),
        costMinor: costMinor != null ? Value(costMinor) : const Value.absent(),
        updatedAt: Value(now),
      ),
    );

    await into(healthEvents).insert(
      HealthEventsCompanion.insert(
        healthItemId: id,
        at: now,
        fromStatus: item.status,
        toStatus: 'done',
        note: Value(resultNote ?? 'تم الإنجاز بنجاح'),
        createdAt: now,
        updatedAt: now,
      ),
    );

    // If repeatEveryMonths is set, create the next needed item!
    if (item.repeatEveryMonths != null && item.repeatEveryMonths! > 0) {
      final months = item.repeatEveryMonths!;
      final nextDate = DateTime(doneDate.year, doneDate.month + months, doneDate.day);
      final nextDateStr = '${nextDate.year}-${nextDate.month.toString().padLeft(2, '0')}-${nextDate.day.toString().padLeft(2, '0')}';
      final nextItemId = await into(healthItems).insert(
        HealthItemsCompanion.insert(
          title: item.title,
          kind: item.kind,
          status: const Value('needed'),
          neededSince: nextDateStr,
          dueBy: Value(nextDateStr),
          placeOrDoctor: Value(item.placeOrDoctor),
          repeatEveryMonths: Value(item.repeatEveryMonths),
          occurredAt: nextDate.millisecondsSinceEpoch,
          localDate: nextDateStr,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await into(healthEvents).insert(
        HealthEventsCompanion.insert(
          healthItemId: nextItemId,
          at: now,
          fromStatus: 'none',
          toStatus: 'needed',
          note: const Value('تكرار دوري تلقائي بعد الإنجاز'),
          createdAt: now,
          updatedAt: now,
        ),
      );
      return nextItemId;
    }
    return null;
  }

  Future<void> softDeleteHealthItem(int id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(healthItems)..where((h) => h.id.equals(id))).write(
      HealthItemsCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    // Cancel reminders for this health item
    await (delete(reminders)..where((r) => r.ownerType.equals('health_item') & r.ownerId.equals(id))).go();
  }

  Future<void> restoreHealthItem(int id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(healthItems)..where((h) => h.id.equals(id))).write(
      HealthItemsCompanion(
        deletedAt: const Value(null),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> permanentlyDeleteHealthItem(int id) async {
    // 1. Delete cascaded voice notes
    final vns = await (select(voiceNotes)
          ..where((v) => v.parentType.equals('health_item') & v.parentId.equals(id)))
        .get();
    try {
      final appDir = await getApplicationDocumentsDirectory();
      for (final vn in vns) {
        final f = File(p.join(appDir.path, vn.fileName));
        if (await f.exists()) await f.delete();
      }
    } catch (_) {}
    await (delete(voiceNotes)
          ..where((v) => v.parentType.equals('health_item') & v.parentId.equals(id)))
        .go();

    // 2. Delete reminders & events
    await (delete(reminders)..where((r) => r.ownerType.equals('health_item') & r.ownerId.equals(id))).go();
    await (delete(healthEvents)..where((e) => e.healthItemId.equals(id))).go();
    await (delete(healthItems)..where((h) => h.id.equals(id))).go();
  }

  Stream<List<HealthEvent>> watchHealthEventsForItem(int healthItemId) {
    return (select(healthEvents)
          ..where((e) => e.healthItemId.equals(healthItemId))
          ..orderBy([(e) => OrderingTerm.asc(e.at)]))
        .watch();
  }

  Future<List<HealthEvent>> getHealthEventsForItem(int healthItemId) {
    return (select(healthEvents)
          ..where((e) => e.healthItemId.equals(healthItemId))
          ..orderBy([(e) => OrderingTerm.asc(e.at)]))
        .get();
  }

  Future<List<HealthEvent>> getHealthEventsForRange(int startMs, int endMs) {
    return (select(healthEvents)
          ..where((e) =>
              e.at.isBiggerOrEqualValue(startMs) &
              e.at.isSmallerOrEqualValue(endMs))
          ..orderBy([(e) => OrderingTerm.asc(e.at)]))
        .get();
  }

  // --- TREATMENTS ---

  Stream<List<Treatment>> watchActiveTreatments() {
    return (select(treatments)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Stream<List<Treatment>> watchTrashTreatments() {
    return (select(treatments)
          ..where((t) => t.deletedAt.isNotNull())
          ..orderBy([(t) => OrderingTerm.desc(t.deletedAt)]))
        .watch();
  }

  Future<List<Treatment>> getAllActiveTreatments() {
    return (select(treatments)..where((t) => t.deletedAt.isNull())).get();
  }

  Future<Treatment?> getTreatmentById(int id) {
    return (select(treatments)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<int> insertTreatment(TreatmentsCompanion treatment) {
    return into(treatments).insert(treatment);
  }

  Future<bool> updateTreatment(TreatmentsCompanion treatment) {
    return update(treatments).replace(treatment);
  }

  Future<void> updateTreatmentAdherence(
    int id, {
    required String adherence,
    String? stoppedReason,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(treatments)..where((t) => t.id.equals(id))).write(
      TreatmentsCompanion(
        adherence: Value(adherence),
        stoppedReason: stoppedReason != null ? Value(stoppedReason) : const Value.absent(),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> markTreatmentPurchased(int id, {int? purchaseCostMinor}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(treatments)..where((t) => t.id.equals(id))).write(
      TreatmentsCompanion(
        purchased: const Value(true),
        purchasedAt: Value(now),
        purchaseCostMinor: purchaseCostMinor != null ? Value(purchaseCostMinor) : const Value.absent(),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> softDeleteTreatment(int id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(treatments)..where((t) => t.id.equals(id))).write(
      TreatmentsCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    await (delete(reminders)..where((r) => r.ownerType.equals('treatment') & r.ownerId.equals(id))).go();
  }

  Future<void> restoreTreatment(int id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(treatments)..where((t) => t.id.equals(id))).write(
      TreatmentsCompanion(
        deletedAt: const Value(null),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> permanentlyDeleteTreatment(int id) async {
    await (delete(reminders)..where((r) => r.ownerType.equals('treatment') & r.ownerId.equals(id))).go();
    await (delete(treatmentChecks)..where((c) => c.treatmentId.equals(id))).go();
    await (delete(treatments)..where((t) => t.id.equals(id))).go();
  }

  // --- TREATMENT CHECKS ---

  Stream<List<TreatmentCheck>> watchTreatmentChecks(int treatmentId) {
    return (select(treatmentChecks)
          ..where((c) => c.treatmentId.equals(treatmentId))
          ..orderBy([(c) => OrderingTerm.desc(c.checkDate)]))
        .watch();
  }

  Future<List<TreatmentCheck>> getTreatmentChecksForRange(
    int treatmentId,
    String startDate,
    String endDate,
  ) {
    return (select(treatmentChecks)
          ..where((c) =>
              c.treatmentId.equals(treatmentId) &
              c.checkDate.isBiggerOrEqualValue(startDate) &
              c.checkDate.isSmallerOrEqualValue(endDate)))
        .get();
  }

  Future<List<TreatmentCheck>> getAllTreatmentChecksForRange(
    String startDate,
    String endDate,
  ) {
    return (select(treatmentChecks)
          ..where((c) =>
              c.checkDate.isBiggerOrEqualValue(startDate) &
              c.checkDate.isSmallerOrEqualValue(endDate) &
              c.taken.equals(true)))
        .get();
  }

  Future<void> toggleTreatmentCheck({
    required int treatmentId,
    required String checkDate,
    required bool taken,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await (select(treatmentChecks)
          ..where((c) =>
              c.treatmentId.equals(treatmentId) & c.checkDate.equals(checkDate)))
        .getSingleOrNull();

    if (existing != null) {
      if (!taken) {
        // If unticked, remove check or set taken = false
        await (delete(treatmentChecks)..where((c) => c.id.equals(existing.id))).go();
      } else {
        await (update(treatmentChecks)..where((c) => c.id.equals(existing.id))).write(
          TreatmentChecksCompanion(
            taken: const Value(true),
            updatedAt: Value(now),
          ),
        );
      }
    } else if (taken) {
      await into(treatmentChecks).insert(
        TreatmentChecksCompanion.insert(
          treatmentId: treatmentId,
          checkDate: checkDate,
          taken: const Value(true),
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
  }

  Future<bool> isTreatmentCheckedToday(int treatmentId, String todayDate) async {
    final existing = await (select(treatmentChecks)
          ..where((c) =>
              c.treatmentId.equals(treatmentId) &
              c.checkDate.equals(todayDate) &
              c.taken.equals(true)))
        .getSingleOrNull();
    return existing != null;
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
