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
  VoiceNotes,
  Reminders,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 3;

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

    final allVoiceNotes = await select(voiceNotes).get();
    final toDeleteVoiceNotes = allVoiceNotes.where((v) {
      if (v.deletedAt != null) return true;
      if (v.parentType == 'task' && deletedTaskIds.contains(v.parentId)) return true;
      if (v.parentType == 'goal' && deletedGoalIds.contains(v.parentId)) return true;
      if (v.parentType == 'idea' && deletedIdeaIds.contains(v.parentId)) return true;
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

    return {
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
    };
  }

  /// Import and replace all database tables from a JSON map in a transaction
  Future<void> importAllData(Map<String, dynamic> data) async {
    await transaction(() async {
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
    return purged;
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
