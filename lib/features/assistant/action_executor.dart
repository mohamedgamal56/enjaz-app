import 'package:drift/drift.dart';

import '../../core/db/app_database.dart';
import '../reminders/domain/reminder_scheduler.dart';
import '../tasks/domain/task_status_service.dart';
import 'action_plan.dart';

/// Represents an undoable operation to revert an executed action (VOICE.md Section 2.4 & 7).
class UndoAction {
  final String description;
  final Future<void> Function() _undoFn;

  const UndoAction({
    required this.description,
    required Future<void> Function() onUndo,
  }) : _undoFn = onUndo;

  Future<void> undo() => _undoFn();
}

/// Result returned after executing an [ActionPlan]
class ExecutionResult {
  final bool success;
  final String message;
  final UndoAction? undoAction;
  final int? createdId;

  const ExecutionResult({
    required this.success,
    required this.message,
    this.undoAction,
    this.createdId,
  });

  const ExecutionResult.failure(this.message)
      : success = false,
        undoAction = null,
        createdId = null;
}

/// Executes an [ActionPlan] directly through existing services and Drift database tables (VOICE.md Section 7).
class ActionExecutor {
  final AppDatabase db;
  final DateTime Function()? nowProvider;

  const ActionExecutor({
    required this.db,
    this.nowProvider,
  });

  DateTime _getNow() {
    if (nowProvider != null) return nowProvider!();
    return DateTime.now();
  }

  String _formatToday(DateTime now) {
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<ExecutionResult> execute(ActionPlan plan) async {
    if (plan.isBlocked) {
      return ExecutionResult.failure(plan.blockedMessage ?? 'إجراء محظور');
    }
    if (plan.isUnrecognized) {
      return const ExecutionResult.failure('الأمر غير مفهوم');
    }

    final now = _getNow();
    final nowMs = now.millisecondsSinceEpoch;
    final todayStr = _formatToday(now);

    switch (plan.actionType) {
      case 'task':
      case 'errand':
      case 'reminder':
        return _executeCreateTask(plan, nowMs, todayStr);

      case 'status_update':
        return _executeUpdateStatus(plan, nowMs, todayStr);

      case 'expense':
        return _executeLogExpense(plan, nowMs, todayStr);

      case 'income':
        return _executeLogIncome(plan, nowMs, todayStr);

      case 'habit':
        return _executeLogHabit(plan, nowMs, todayStr);

      case 'note':
        return _executeCreateNote(plan, nowMs, todayStr);

      case 'idea':
        return _executeCreateIdea(plan, nowMs, todayStr);

      case 'wishlist':
        return _executeCreateWishlistItem(plan, nowMs, todayStr);

      case 'health':
        return _executeCreateHealthItem(plan, nowMs, todayStr);

      default:
        return const ExecutionResult.failure('نوع الإجراء غير مدعوم للتنفيذ المباشر');
    }
  }

  // =========================================================================
  // TASK / ERRAND / REMINDER
  // =========================================================================

  Future<ExecutionResult> _executeCreateTask(ActionPlan plan, int nowMs, String todayStr) async {
    final title = plan.slots['title'] as String? ?? 'مهمة';
    final kind = plan.slots['kind'] as String? ?? 'task';
    final date = plan.slots['date'] as String?;
    final time = plan.slots['time'] as String?;
    final location = plan.slots['location'] as String?;
    final offset = plan.slots['reminderOffsetMinutes'] as int?;

    final companion = TasksCompanion.insert(
      title: title,
      kind: Value(kind),
      dueDate: date != null ? Value(date) : const Value.absent(),
      dueTime: time != null ? Value(time) : const Value.absent(),
      locationText: location != null ? Value(location) : const Value.absent(),
      reminderOffsetMinutes: offset != null ? Value(offset) : const Value.absent(),
      status: const Value('todo'),
      priority: const Value('normal'),
      progress: const Value(0),
      createdAt: nowMs,
      updatedAt: nowMs,
    );

    final taskId = await db.insertNewTask(companion);

    // Schedule reminder if offset or time is present
    int? reminderId;
    if (offset != null) {
      final defaultKind = await db.getSetting('default_reminder_kind') ?? 'alarm';
      reminderId = await db.insertReminder(
        ownerType: 'task',
        ownerId: taskId,
        kind: defaultKind,
        offsetMinutes: offset,
      );

      final savedRem = await (db.select(db.reminders)..where((r) => r.id.equals(reminderId!))).getSingleOrNull();
      if (savedRem != null) {
        try {
          await ReminderScheduler(db: db).scheduleReminder(
            reminder: savedRem,
            title: title,
            dueDate: date,
            dueTime: time,
          );
        } catch (_) {
          // Ignore platform / notification service errors in tests or headless runners
        }
      }
    }

    final successMsg = kind == 'errand' ? 'تم تسجيل المشوار بنجاح' : 'تمت إضافة المهمة بنجاح';

    return ExecutionResult(
      success: true,
      message: successMsg,
      createdId: taskId,
      undoAction: UndoAction(
        description: 'حذف المهمة "$title"',
        onUndo: () async {
          await db.softDeleteTask(taskId);
          if (reminderId != null) {
            try {
              await ReminderScheduler(db: db).cancelReminder(reminderId);
            } catch (_) {}
            await (db.delete(db.reminders)..where((r) => r.id.equals(reminderId!))).go();
          }
        },
      ),
    );
  }

  // =========================================================================
  // STATUS UPDATE
  // =========================================================================

  Future<ExecutionResult> _executeUpdateStatus(ActionPlan plan, int nowMs, String todayStr) async {
    final taskId = plan.slots['taskId'] as int?;
    if (taskId == null) {
      return const ExecutionResult.failure('لم يتم العثور على مهمة مطابقة لتحديثها');
    }

    final currentTask = await db.getTaskById(taskId);
    if (currentTask == null) {
      return const ExecutionResult.failure('المهمة غير موجودة في قاعدة البيانات');
    }

    final targetStatus = plan.slots['status'] as String? ?? 'done';
    final targetDate = plan.slots['date'] as String?;
    final reason = plan.slots['reason'] as String?;
    final progressVal = plan.slots['progress'] as double?;
    final newProgressInt = progressVal != null ? (progressVal * 100).round() : null;

    final trans = TaskStatusService.applyTransition(
      currentStatus: currentTask.status,
      targetStatus: targetStatus,
      currentStartedAt: currentTask.startedAt,
      currentFinishedAt: currentTask.finishedAt,
      currentProgress: currentTask.progress,
      currentPostponeCount: currentTask.postponeCount,
      currentPostponedUntil: currentTask.postponedUntil,
      newProgress: newProgressInt,
      newPostponedUntil: targetDate,
      nowMs: nowMs,
    );

    // Save previous state for Undo
    final prevStatus = currentTask.status;
    final prevProgress = currentTask.progress;
    final prevFinishedAt = currentTask.finishedAt;
    final prevStartedAt = currentTask.startedAt;
    final prevPostponeCount = currentTask.postponeCount;
    final prevPostponedUntil = currentTask.postponedUntil;
    final prevReasonText = currentTask.reasonText;

    // Apply update to task
    await (db.update(db.tasks)..where((t) => t.id.equals(taskId))).write(
      TasksCompanion(
        status: Value(trans.status),
        progress: Value(trans.progress),
        finishedAt: Value(trans.finishedAt),
        startedAt: Value(trans.startedAt),
        postponeCount: Value(trans.postponeCount),
        postponedUntil: Value(trans.postponedUntil),
        reasonText: Value(reason ?? currentTask.reasonText),
        updatedAt: Value(nowMs),
      ),
    );

    // Insert task event log
    final eventId = await db.insertTaskEvent(
      TaskEventsCompanion.insert(
        taskId: taskId,
        at: nowMs,
        fromStatus: prevStatus,
        toStatus: trans.status,
        progress: trans.progress,
        reasonText: Value(reason),
        createdAt: nowMs,
        updatedAt: nowMs,
      ),
    );

    return ExecutionResult(
      success: true,
      message: 'تم تحديث حالة المهمة "${currentTask.title}"',
      createdId: taskId,
      undoAction: UndoAction(
        description: 'استعادة حالة المهمة "${currentTask.title}"',
        onUndo: () async {
          await (db.update(db.tasks)..where((t) => t.id.equals(taskId))).write(
            TasksCompanion(
              status: Value(prevStatus),
              progress: Value(prevProgress),
              finishedAt: Value(prevFinishedAt),
              startedAt: Value(prevStartedAt),
              postponeCount: Value(prevPostponeCount),
              postponedUntil: Value(prevPostponedUntil),
              reasonText: Value(prevReasonText),
              updatedAt: Value(nowMs),
            ),
          );
          await (db.delete(db.taskEvents)..where((e) => e.id.equals(eventId))).go();
        },
      ),
    );
  }

  // =========================================================================
  // EXPENSE / INCOME
  // =========================================================================

  Future<ExecutionResult> _executeLogExpense(ActionPlan plan, int nowMs, String todayStr) async {
    final amount = (plan.slots['amount'] as num?)?.toDouble() ?? 0.0;
    final amountMinor = (amount * 100).round();
    final categoryName = plan.slots['category'] as String? ?? 'طعام ومطاعم';
    final nature = plan.slots['nature'] as String? ?? 'side';
    final note = plan.slots['title'] as String? ?? categoryName;
    final date = plan.slots['date'] as String? ?? todayStr;

    // Lookup category in DB
    final allCats = await db.select(db.financeCategories).get();
    FinanceCategory? matched = allCats.cast<FinanceCategory?>().firstWhere(
      (c) => c!.nameAr == categoryName,
      orElse: () => null,
    );
    matched ??= allCats.firstWhere(
      (c) => c.kind == 'expense',
      orElse: () => allCats.first,
    );

    final txId = await db.insertTransaction(
      TransactionsCompanion.insert(
        kind: 'expense',
        amountMinor: amountMinor,
        categoryId: matched.id,
        nature: Value(nature),
        occurredAt: nowMs,
        localDate: date,
        note: Value(note),
        createdAt: nowMs,
        updatedAt: nowMs,
      ),
    );

    return ExecutionResult(
      success: true,
      message: 'تم تسجيل مصروف ${amount.round()} جنيه في $categoryName',
      createdId: txId,
      undoAction: UndoAction(
        description: 'حذف مصروف $categoryName',
        onUndo: () async {
          await db.softDeleteTransaction(txId);
        },
      ),
    );
  }

  Future<ExecutionResult> _executeLogIncome(ActionPlan plan, int nowMs, String todayStr) async {
    final amount = (plan.slots['amount'] as num?)?.toDouble() ?? 0.0;
    final amountMinor = (amount * 100).round();
    final title = plan.slots['title'] as String? ?? 'دخل';
    final date = plan.slots['date'] as String? ?? todayStr;

    final allCats = await db.select(db.financeCategories).get();
    FinanceCategory? matched = allCats.cast<FinanceCategory?>().firstWhere(
      (c) => c!.kind == 'income',
      orElse: () => null,
    );
    matched ??= allCats.first;

    final txId = await db.insertTransaction(
      TransactionsCompanion.insert(
        kind: 'income',
        amountMinor: amountMinor,
        categoryId: matched.id,
        nature: const Value('side'),
        occurredAt: nowMs,
        localDate: date,
        note: Value(title),
        createdAt: nowMs,
        updatedAt: nowMs,
      ),
    );

    return ExecutionResult(
      success: true,
      message: 'تم تسجيل دخل ${amount.round()} جنيه ($title)',
      createdId: txId,
      undoAction: UndoAction(
        description: 'حذف دخل $title',
        onUndo: () async {
          await db.softDeleteTransaction(txId);
        },
      ),
    );
  }

  // =========================================================================
  // HABIT
  // =========================================================================

  Future<ExecutionResult> _executeLogHabit(ActionPlan plan, int nowMs, String todayStr) async {
    final habitKey = plan.slots['habitKey'] as String? ?? 'coffee';
    final habitName = plan.slots['habitName'] as String? ?? 'عادة';
    final action = plan.slots['action'] as String? ?? 'add';
    final quantity = (plan.slots['quantity'] as num?)?.toDouble() ?? 1.0;

    // Lookup habit in DB
    final allHabits = await db.select(db.habits).get();
    Habit? habit = allHabits.cast<Habit?>().firstWhere(
      (h) => h!.builtinKey == habitKey || h.nameAr.contains(habitName) || habitName.contains(h.nameAr),
      orElse: () => null,
    );

    // If not found in DB, auto-create it from defaults
    int habitId;
    if (habit == null) {
      habitId = await db.insertHabit(
        HabitsCompanion.insert(
          nameAr: habitName,
          type: action == 'tick' ? 'check' : 'count',
          builtinKey: Value(habitKey),
          createdAt: nowMs,
          updatedAt: nowMs,
        ),
      );
    } else {
      habitId = habit.id;
    }

    if (action == 'tick' || (habit?.type == 'check')) {
      await db.setHabitCheck(habitId, todayStr, true);
    } else {
      final times = quantity.round().clamp(1, 100);
      for (int i = 0; i < times; i++) {
        await db.logHabitCount(habitId, todayStr);
      }
    }

    return ExecutionResult(
      success: true,
      message: 'تم تسجيل العادة "$habitName"',
      createdId: habitId,
      undoAction: UndoAction(
        description: 'التراجع عن تسجيل "$habitName"',
        onUndo: () async {
          if (action == 'tick') {
            await db.setHabitCheck(habitId, todayStr, false);
          } else {
            final times = quantity.round().clamp(1, 100);
            for (int i = 0; i < times; i++) {
              await db.decrementHabitCount(habitId, todayStr);
            }
          }
        },
      ),
    );
  }

  // =========================================================================
  // NOTE / IDEA / WISHLIST / HEALTH
  // =========================================================================

  Future<ExecutionResult> _executeCreateNote(ActionPlan plan, int nowMs, String todayStr) async {
    final title = plan.slots['title'] as String? ?? 'ملاحظة';
    final noteKind = plan.slots['noteKind'] as String? ?? 'note';

    final noteId = await db.insertNote(
      NotesCompanion.insert(
        title: Value(title),
        body: title,
        kind: Value(noteKind),
        noteDate: Value(todayStr),
        localDate: Value(todayStr),
        occurredAt: Value(nowMs),
        createdAt: nowMs,
        updatedAt: nowMs,
      ),
    );

    return ExecutionResult(
      success: true,
      message: 'تم حفظ الملاحظة بنجاح',
      createdId: noteId,
      undoAction: UndoAction(
        description: 'حذف الملاحظة',
        onUndo: () async {
          await db.softDeleteNote(noteId);
        },
      ),
    );
  }

  Future<ExecutionResult> _executeCreateIdea(ActionPlan plan, int nowMs, String todayStr) async {
    final title = plan.slots['title'] as String? ?? 'فكرة';

    final ideaId = await db.into(db.ideas).insert(
      IdeasCompanion.insert(
        title: title,
        status: const Value('new'),
        createdAt: nowMs,
        updatedAt: nowMs,
      ),
    );

    return ExecutionResult(
      success: true,
      message: 'تم حفظ الفكرة بنجاح',
      createdId: ideaId,
      undoAction: UndoAction(
        description: 'حذف الفكرة',
        onUndo: () async {
          await (db.update(db.ideas)..where((i) => i.id.equals(ideaId))).write(
            IdeasCompanion(
              deletedAt: Value(nowMs),
              updatedAt: Value(nowMs),
            ),
          );
        },
      ),
    );
  }

  Future<ExecutionResult> _executeCreateWishlistItem(ActionPlan plan, int nowMs, String todayStr) async {
    final title = plan.slots['title'] as String? ?? 'مشتريات';
    final amount = (plan.slots['amount'] as num?)?.toDouble() ?? 0.0;
    final priceMinor = (amount * 100).round();

    final wishId = await db.insertWishlistItem(
      WishlistItemsCompanion.insert(
        name: title,
        estimatedPriceMinor: priceMinor,
        status: const Value('wanted'),
        priority: const Value('normal'),
        createdAt: nowMs,
        updatedAt: nowMs,
      ),
    );

    return ExecutionResult(
      success: true,
      message: 'تمت إضافة "$title" إلى قائمة المشتريات',
      createdId: wishId,
      undoAction: UndoAction(
        description: 'حذف عنصر المشتريات',
        onUndo: () async {
          await db.softDeleteWishlistItem(wishId);
        },
      ),
    );
  }

  Future<ExecutionResult> _executeCreateHealthItem(ActionPlan plan, int nowMs, String todayStr) async {
    final title = plan.slots['title'] as String? ?? 'كشف طبي';
    final date = plan.slots['date'] as String?;

    final healthId = await db.insertHealthItemWithEvent(
      HealthItemsCompanion.insert(
        title: title,
        kind: 'checkup',
        status: const Value('needed'),
        neededSince: todayStr,
        dueBy: date != null ? Value(date) : const Value.absent(),
        occurredAt: nowMs,
        localDate: todayStr,
        createdAt: nowMs,
        updatedAt: nowMs,
      ),
      eventNote: 'تم التسجيل عبر المساعد الصوتي',
    );

    return ExecutionResult(
      success: true,
      message: 'تم تسجيل الفحص الطبي "$title"',
      createdId: healthId,
      undoAction: UndoAction(
        description: 'حذف الفحص الطبي',
        onUndo: () async {
          await db.softDeleteHealthItem(healthId);
        },
      ),
    );
  }
}
