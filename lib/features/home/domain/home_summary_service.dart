import 'package:async/async.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/db/app_database.dart';
import 'home_summary_data.dart';

/// HomeSummaryService (UI.md Section 4 & Section 8 Rule 4)
/// Provides aggregated queries and calculations for the Home screen.
class HomeSummaryService {
  final AppDatabase db;

  const HomeSummaryService(this.db);

  /// Next-task selection rule (UI.md Section 4.2 & Section 8 Rule 4):
  /// Finds the next unfinished task with its time (or first unfinished without time).
  /// If all tasks are completed, returns isAllDone = true and nextTaskTitle = null.
  static ({String? nextTaskTitle, String? nextTaskTime, bool isAllDone}) findNextTask(
    List<Task> todayTasks,
  ) {
    if (todayTasks.isEmpty) {
      return (nextTaskTitle: null, nextTaskTime: null, isAllDone: false);
    }

    final unfinished = todayTasks.where((t) => t.status != 'done').toList();
    if (unfinished.isEmpty) {
      return (nextTaskTitle: null, nextTaskTime: null, isAllDone: true);
    }

    // Filter tasks with non-empty dueTime
    final withTime = unfinished
        .where((t) => t.dueTime != null && t.dueTime!.trim().isNotEmpty)
        .toList();

    if (withTime.isNotEmpty) {
      withTime.sort((a, b) => a.dueTime!.compareTo(b.dueTime!));
      final next = withTime.first;
      return (nextTaskTitle: next.title, nextTaskTime: next.dueTime, isAllDone: false);
    }

    final first = unfinished.first;
    return (nextTaskTitle: first.title, nextTaskTime: null, isAllDone: false);
  }

  /// Streak calculation rule (UI.md Section 4.2 & Section 8 Rule 4):
  /// Consecutive days on which all scheduled habits were completed
  /// (ending today, or yesterday while today is not complete).
  static int calculateStreak({
    required Map<String, bool> allScheduledHabitsDoneByDate,
    required DateTime today,
    int maxLookbackDays = 365,
  }) {
    final dateFormat = DateFormat('yyyy-MM-dd');
    final todayClean = DateTime(today.year, today.month, today.day);
    final todayStr = dateFormat.format(todayClean);

    final todayDone = allScheduledHabitsDoneByDate[todayStr] ?? false;

    if (todayDone) {
      int streak = 1;
      for (int i = 1; i <= maxLookbackDays; i++) {
        final prevDay = todayClean.subtract(Duration(days: i));
        final prevStr = dateFormat.format(prevDay);
        if (allScheduledHabitsDoneByDate[prevStr] == true) {
          streak++;
        } else {
          break;
        }
      }
      return streak;
    } else {
      // Today is not complete yet, count ending yesterday
      final yesterday = todayClean.subtract(const Duration(days: 1));
      final yesterdayStr = dateFormat.format(yesterday);
      if (allScheduledHabitsDoneByDate[yesterdayStr] == true) {
        int streak = 1;
        for (int i = 2; i <= maxLookbackDays; i++) {
          final prevDay = todayClean.subtract(Duration(days: i));
          final prevStr = dateFormat.format(prevDay);
          if (allScheduledHabitsDoneByDate[prevStr] == true) {
            streak++;
          } else {
            break;
          }
        }
        return streak;
      }
      return 0;
    }
  }

  /// Budget calculation rule (UI.md Section 4.2 & Section 8 Rule 4):
  /// Remaining monthly budget if an overall budget exists, otherwise null.
  static int? calculateRemainingBudget({
    int? overallMonthlyLimitMinor,
    required int monthlyExpensesMinor,
  }) {
    if (overallMonthlyLimitMinor != null) {
      return overallMonthlyLimitMinor - monthlyExpensesMinor;
    }
    return null;
  }

  /// Aggregated computation for Home screen
  Future<HomeSummaryData> getSummary({DateTime? referenceDate}) async {
    final now = referenceDate ?? DateTime.now();
    final todayClean = DateTime(now.year, now.month, now.day);
    final dateFormat = DateFormat('yyyy-MM-dd');
    final monthFormat = DateFormat('yyyy-MM');
    final todayStr = dateFormat.format(todayClean);
    final currentMonth = monthFormat.format(todayClean);

    // 1. Today tasks & overdue
    final todayTasks = await (db.select(db.tasks)
          ..where((t) => t.dueDate.equals(todayStr) & t.deletedAt.isNull()))
        .get();

    final overdueTasks = await (db.select(db.tasks)
          ..where((t) =>
              t.dueDate.isSmallerThanValue(todayStr) &
              t.status.isNotValue('done') &
              t.deletedAt.isNull()))
        .get();

    final todayCompleted = todayTasks.where((t) => t.status == 'done').length;
    final todayTotal = todayTasks.length;
    final todayProgress = todayTotal > 0 ? (todayCompleted / todayTotal) : 0.0;
    final nextTaskInfo = findNextTask(todayTasks);

    // 2. Habits summary
    final activeHabits = await (db.select(db.habits)
          ..where((h) => h.deletedAt.isNull() & h.archived.equals(false)))
        .get();

    int habitsTotalToday = 0;
    int habitsCompletedToday = 0;
    final habitCompletionByDate = <String, bool>{};

    if (activeHabits.isNotEmpty) {
      // Evaluate habit logs for recent window (last 60 days)
      final sinceDate = todayClean.subtract(const Duration(days: 60));
      final sinceStr = dateFormat.format(sinceDate);

      final logs = await (db.select(db.habitLogs)
            ..where((l) => l.date.isBiggerOrEqualValue(sinceStr)))
          .get();

      final checklistItemLogs = await (db.select(db.habitItemLogs)
            ..where((l) => l.date.isBiggerOrEqualValue(sinceStr)))
          .get();

      final allHabitItems = await db.select(db.habitItems).get();

      // Check which habits are scheduled for today
      for (final h in activeHabits) {
        final bit = 1 << (todayClean.weekday - 1);
        final isScheduledToday = h.scheduleDays <= 0 || (h.scheduleDays & bit) != 0;
        if (isScheduledToday) {
          habitsTotalToday++;
          // Check if done today
          final hLogs = logs.where((l) => l.habitId == h.id && l.date == todayStr);
          final loggedVal = hLogs.fold<double>(0.0, (acc, l) => acc + l.value);
          final items = allHabitItems.where((i) => i.habitId == h.id).toList();
          final doneItemLogs = checklistItemLogs.where(
            (l) => l.habitId == h.id && l.date == todayStr && l.completed,
          );

          bool isDone = false;
          if (h.type == 'check') {
            isDone = loggedVal >= 1.0;
          } else if (h.type == 'count' || h.type == 'amount') {
            isDone = h.dailyTarget != null && h.dailyTarget! > 0
                ? loggedVal >= h.dailyTarget!
                : loggedVal > 0;
          } else if (h.type == 'checklist') {
            isDone = items.isNotEmpty && doneItemLogs.length >= items.length;
          }

          if (isDone) habitsCompletedToday++;
        }
      }

      // Check daily habit completion across recent window for streak calculation
      for (int d = 0; d <= 60; d++) {
        final date = todayClean.subtract(Duration(days: d));
        final dateStr = dateFormat.format(date);
        int dayScheduled = 0;
        int dayDone = 0;

        for (final h in activeHabits) {
          final bit = 1 << (date.weekday - 1);
          final isScheduled = h.scheduleDays <= 0 || (h.scheduleDays & bit) != 0;
          if (isScheduled) {
            dayScheduled++;
            final hLogs = logs.where((l) => l.habitId == h.id && l.date == dateStr);
            final loggedVal = hLogs.fold<double>(0.0, (acc, l) => acc + l.value);
            final items = allHabitItems.where((i) => i.habitId == h.id).toList();
            final doneItemLogs = checklistItemLogs.where(
              (l) => l.habitId == h.id && l.date == dateStr && l.completed,
            );

            bool isDone = false;
            if (h.type == 'check') {
              isDone = loggedVal >= 1.0;
            } else if (h.type == 'count' || h.type == 'amount') {
              isDone = h.dailyTarget != null && h.dailyTarget! > 0
                  ? loggedVal >= h.dailyTarget!
                  : loggedVal > 0;
            } else if (h.type == 'checklist') {
              isDone = items.isNotEmpty && doneItemLogs.length >= items.length;
            }

            if (isDone) dayDone++;
          }
        }

        habitCompletionByDate[dateStr] = dayScheduled > 0 && dayDone >= dayScheduled;
      }
    }

    final habitsStreak = calculateStreak(
      allScheduledHabitsDoneByDate: habitCompletionByDate,
      today: todayClean,
    );

    // 3. Finance summary
    final todayExpenses = await (db.select(db.transactions)
          ..where((t) =>
              t.date.equals(todayStr) &
              t.type.equals('expense') &
              t.deletedAt.isNull()))
        .get();

    final monthExpenses = await (db.select(db.transactions)
          ..where((t) =>
              t.date.like('$currentMonth%') &
              t.type.equals('expense') &
              t.deletedAt.isNull()))
        .get();

    final todaySpendingMinor =
        todayExpenses.fold<int>(0, (acc, t) => acc + t.amountMinor);
    final monthSpendingMinor =
        monthExpenses.fold<int>(0, (acc, t) => acc + t.amountMinor);

    final overallBudgets = await (db.select(db.budgets)
          ..where((b) =>
              b.categoryId.isNull() &
              (b.month.equals(currentMonth) | b.month.equals('recurring')) &
              b.deletedAt.isNull()))
        .get();

    final int? overallLimitMinor =
        overallBudgets.isNotEmpty ? overallBudgets.first.limitMinor : null;
    final int? remainingBudget = calculateRemainingBudget(
      overallMonthlyLimitMinor: overallLimitMinor,
      monthlyExpensesMinor: monthSpendingMinor,
    );

    // 4. Health summary
    final nearestItems = await (db.select(db.healthItems)
          ..where((h) =>
              h.localDate.isBiggerOrEqualValue(todayStr) &
              h.status.isNotValue('done') &
              h.deletedAt.isNull())
          ..orderBy([
            (h) => OrderingTerm.asc(h.localDate),
            (h) => OrderingTerm.asc(h.dueTime),
          ])
          ..limit(1))
        .get();

    final postponedHealthItems = await (db.select(db.healthItems)
          ..where((h) => h.status.equals('postponed') & h.deletedAt.isNull()))
        .get();

    String? nearestHealthTitle;
    String? nearestHealthDay;

    if (nearestItems.isNotEmpty) {
      final item = nearestItems.first;
      nearestHealthTitle = item.title;
      if (item.localDate == todayStr) {
        nearestHealthDay = 'اليوم';
      } else {
        try {
          final dt = dateFormat.parse(item.localDate);
          final diff = dt.difference(todayClean).inDays;
          if (diff == 1) {
            nearestHealthDay = 'غداً';
          } else {
            nearestHealthDay = DateFormat('EEEE d MMMM', 'ar').format(dt);
          }
        } catch (_) {
          nearestHealthDay = item.localDate;
        }
      }
    }

    // 5. Goals & Ideas summary
    final activeGoals = await (db.select(db.goals)
          ..where((g) => g.status.equals('active') & g.deletedAt.isNull()))
        .get();

    final activeIdeas = await (db.select(db.ideas)
          ..where((i) => i.status.isNotValue('archived') & i.deletedAt.isNull()))
        .get();

    final activeNotes = await (db.select(db.notes)
          ..where((n) => n.deletedAt.isNull()))
        .get();

    return HomeSummaryData(
      todayCompletedCount: todayCompleted,
      todayTotalCount: todayTotal,
      todayProgress: todayProgress,
      nextTaskTitle: nextTaskInfo.nextTaskTitle,
      nextTaskTime: nextTaskInfo.nextTaskTime,
      isAllTodayDone: nextTaskInfo.isAllDone,
      overdueCount: overdueTasks.length,
      habitsCompletedCount: habitsCompletedToday,
      habitsTotalScheduledCount: habitsTotalToday,
      habitsStreak: habitsStreak,
      hasHabits: activeHabits.isNotEmpty,
      todaySpendingMinor: todaySpendingMinor,
      hasMonthlyBudget: overallLimitMinor != null,
      remainingMonthlyBudgetMinor: remainingBudget ?? 0,
      monthSpendingMinor: monthSpendingMinor,
      nearestHealthTitle: nearestHealthTitle,
      nearestHealthDay: nearestHealthDay,
      postponedHealthCount: postponedHealthItems.length,
      activeGoalsCount: activeGoals.length,
      ideasCount: activeIdeas.length,
      notesCount: activeNotes.length,
    );
  }

  /// Reactive stream for Home screen
  Stream<HomeSummaryData> watchSummary({DateTime? referenceDate}) async* {
    yield await getSummary(referenceDate: referenceDate);
    final merged = StreamGroup.merge([
      db.select(db.tasks).watch(),
      db.select(db.habits).watch(),
      db.select(db.habitLogs).watch(),
      db.select(db.transactions).watch(),
      db.select(db.budgets).watch(),
      db.select(db.healthItems).watch(),
      db.select(db.goals).watch(),
      db.select(db.ideas).watch(),
      db.select(db.notes).watch(),
    ]);

    await for (final _ in merged) {
      yield await getSummary(referenceDate: referenceDate);
    }
  }
}

final homeSummaryServiceProvider = Provider<HomeSummaryService>((ref) {
  final db = ref.watch(databaseProvider);
  return HomeSummaryService(db);
});

final homeSummaryProvider = StreamProvider<HomeSummaryData>((ref) {
  final service = ref.watch(homeSummaryServiceProvider);
  return service.watchSummary();
});
