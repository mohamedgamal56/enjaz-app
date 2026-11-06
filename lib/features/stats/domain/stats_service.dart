import 'package:intl/intl.dart';
import '../../../core/db/app_database.dart';

enum StatsRangeType {
  week,
  month,
  year,
  allTime,
  custom,
}

class StatsDateRange {
  final StatsRangeType type;
  final DateTime start;
  final DateTime end;

  const StatsDateRange({
    required this.type,
    required this.start,
    required this.end,
  });

  /// Format localized label (e.g. "25 أكتوبر – 1 نوفمبر")
  String getLocalizedLabel(String locale) {
    final formatDayMonth = DateFormat('d MMM', locale);
    final formatMonthYear = DateFormat('MMMM yyyy', locale);
    final formatYear = DateFormat('yyyy', locale);

    switch (type) {
      case StatsRangeType.week:
        return '${formatDayMonth.format(start)} – ${formatDayMonth.format(end)}';
      case StatsRangeType.month:
        return formatMonthYear.format(start);
      case StatsRangeType.year:
        return formatYear.format(start);
      case StatsRangeType.allTime:
        return locale == 'ar' ? 'كل الأوقات' : 'All Time';
      case StatsRangeType.custom:
        return '${formatDayMonth.format(start)} – ${formatDayMonth.format(end)}';
    }
  }

  /// Get immediately preceding date range for diff comparison
  StatsDateRange getPreviousRange({int firstDayOfWeek = DateTime.saturday}) {
    switch (type) {
      case StatsRangeType.week:
        final prevStart = start.subtract(const Duration(days: 7));
        final prevEnd = start.subtract(const Duration(milliseconds: 1));
        return StatsDateRange(
          type: StatsRangeType.week,
          start: DateTime(prevStart.year, prevStart.month, prevStart.day),
          end: DateTime(prevEnd.year, prevEnd.month, prevEnd.day, 23, 59, 59, 999),
        );
      case StatsRangeType.month:
        final prevMonth = DateTime(start.year, start.month - 1, 1);
        final lastDay = DateTime(prevMonth.year, prevMonth.month + 1, 0);
        return StatsDateRange(
          type: StatsRangeType.month,
          start: prevMonth,
          end: DateTime(lastDay.year, lastDay.month, lastDay.day, 23, 59, 59, 999),
        );
      case StatsRangeType.year:
        return StatsDateRange(
          type: StatsRangeType.year,
          start: DateTime(start.year - 1, 1, 1),
          end: DateTime(start.year - 1, 12, 31, 23, 59, 59, 999),
        );
      case StatsRangeType.allTime:
      case StatsRangeType.custom:
        final duration = end.difference(start);
        return StatsDateRange(
          type: type,
          start: start.subtract(duration),
          end: start.subtract(const Duration(milliseconds: 1)),
        );
    }
  }
}

class ReasonCount {
  final String reason;
  final int count;
  final int postponed;
  final int waiting;
  final int stopped;
  final int partial;

  const ReasonCount({
    required this.reason,
    required this.count,
    this.postponed = 0,
    this.waiting = 0,
    this.stopped = 0,
    this.partial = 0,
  });
}

class StatsResult {
  final StatsDateRange range;
  final int scheduledCount;
  final int completedCount;
  final int completedDiff; // vs previous period
  final double completionRate;
  final int postponedCount;
  final int partialCount;
  final int waitingStoppedCount;
  final double averageDurationMinutes;
  final int currentStreak;
  final int bestStreak;
  final Map<String, int> statusDistribution;
  final List<ReasonCount> topReasons;
  final Map<int, int> weekdayProductivity; // 1 (Mon) to 7 (Sun) or Sat-Fri
  final Map<DateTime, int> dailyCompletedCounts;
  final List<Task> highlights;
  final int goalsCompletedCount;
  final int milestonesCompletedCount;
  final int goalsWithProgressChange;
  final int ideasCreatedCount;
  final int ideasConvertedCount;

  const StatsResult({
    required this.range,
    required this.scheduledCount,
    required this.completedCount,
    required this.completedDiff,
    required this.completionRate,
    required this.postponedCount,
    required this.partialCount,
    required this.waitingStoppedCount,
    required this.averageDurationMinutes,
    required this.currentStreak,
    required this.bestStreak,
    required this.statusDistribution,
    required this.topReasons,
    required this.weekdayProductivity,
    required this.dailyCompletedCounts,
    required this.highlights,
    required this.goalsCompletedCount,
    required this.milestonesCompletedCount,
    required this.goalsWithProgressChange,
    required this.ideasCreatedCount,
    required this.ideasConvertedCount,
  });

  bool get isEmpty =>
      scheduledCount == 0 &&
      completedCount == 0 &&
      postponedCount == 0 &&
      partialCount == 0 &&
      waitingStoppedCount == 0;
}

class StatsService {
  const StatsService();

  /// Resolve date range for given reference date and range type
  static StatsDateRange resolveRange({
    required StatsRangeType type,
    required DateTime referenceDate,
    int firstDayOfWeek = DateTime.saturday,
    DateTime? customStart,
    DateTime? customEnd,
  }) {
    final ref = DateTime(referenceDate.year, referenceDate.month, referenceDate.day);

    switch (type) {
      case StatsRangeType.week:
        // Calculate offset to week start
        int diff = ref.weekday - firstDayOfWeek;
        if (diff < 0) diff += 7;
        final weekStart = ref.subtract(Duration(days: diff));
        final weekEnd = weekStart.add(const Duration(days: 6));
        return StatsDateRange(
          type: StatsRangeType.week,
          start: DateTime(weekStart.year, weekStart.month, weekStart.day, 0, 0, 0),
          end: DateTime(weekEnd.year, weekEnd.month, weekEnd.day, 23, 59, 59, 999),
        );

      case StatsRangeType.month:
        final monthStart = DateTime(ref.year, ref.month, 1);
        final lastDay = DateTime(ref.year, ref.month + 1, 0);
        return StatsDateRange(
          type: StatsRangeType.month,
          start: monthStart,
          end: DateTime(lastDay.year, lastDay.month, lastDay.day, 23, 59, 59, 999),
        );

      case StatsRangeType.year:
        return StatsDateRange(
          type: StatsRangeType.year,
          start: DateTime(ref.year, 1, 1),
          end: DateTime(ref.year, 12, 31, 23, 59, 59, 999),
        );

      case StatsRangeType.allTime:
        return StatsDateRange(
          type: StatsRangeType.allTime,
          start: DateTime(1970, 1, 1),
          end: DateTime(2100, 12, 31, 23, 59, 59, 999),
        );

      case StatsRangeType.custom:
        final s = customStart ?? ref;
        final e = customEnd ?? ref;
        return StatsDateRange(
          type: StatsRangeType.custom,
          start: DateTime(s.year, s.month, s.day, 0, 0, 0),
          end: DateTime(e.year, e.month, e.day, 23, 59, 59, 999),
        );
    }
  }

  /// Compute full statistics matching Spec Section 7 and Addendum v1.2
  StatsResult computeStats({
    required StatsDateRange range,
    required List<Task> tasks,
    required List<TaskEvent> rangeEvents,
    required List<TaskEvent> allDoneEvents,
    required int previousPeriodCompletedCount,
    List<Goal> goals = const [],
    List<GoalUpdate> goalUpdates = const [],
    List<Milestone> milestones = const [],
    List<Idea> ideas = const [],
    DateTime? now,
  }) {
    final currentMoment = now ?? DateTime.now();
    final today = DateTime(currentMoment.year, currentMoment.month, currentMoment.day);
    final startMs = range.start.millisecondsSinceEpoch;
    final endMs = range.end.millisecondsSinceEpoch;

    // 1. Scheduled set = non-deleted tasks whose due_date falls inside range,
    // or if due_date is null, created_at inside range.
    final scheduledSet = tasks.where((t) {
      if (t.deletedAt != null) return false;
      if (t.dueDate != null && t.dueDate!.isNotEmpty) {
        try {
          final due = DateTime.parse(t.dueDate!);
          final dueDay = DateTime(due.year, due.month, due.day);
          final startDay = DateTime(range.start.year, range.start.month, range.start.day);
          final endDay = DateTime(range.end.year, range.end.month, range.end.day);
          return !dueDay.isBefore(startDay) && !dueDay.isAfter(endDay);
        } catch (_) {
          return false;
        }
      } else {
        return t.createdAt >= startMs && t.createdAt <= endMs;
      }
    }).toList();

    // 2. Completed tasks = tasks that have a 'done' event whose timestamp falls inside range
    final doneEventsInRange = rangeEvents.where((e) => e.toStatus == 'done').toList();
    final completedTaskIdsInRange = doneEventsInRange.map((e) => e.taskId).toSet();
    final completedTasks = tasks.where((t) => completedTaskIdsInRange.contains(t.id)).toList();

    // 3. Completion rate = (scheduled-set tasks that are done) / (scheduled-set size excluding future tasks)
    final eligibleScheduled = scheduledSet.where((t) {
      if (t.dueDate != null && t.dueDate!.isNotEmpty) {
        try {
          final due = DateTime.parse(t.dueDate!);
          final dueDay = DateTime(due.year, due.month, due.day);
          return !dueDay.isAfter(today);
        } catch (_) {}
      }
      return true;
    }).toList();

    final scheduledDoneCount = eligibleScheduled.where((t) => t.status == 'done').length;
    final completionRate = eligibleScheduled.isEmpty
        ? 0.0
        : (scheduledDoneCount / eligibleScheduled.length) * 100.0;

    // 4. Postponed count = distinct tasks that have a postponed event in range
    final postponedTaskIds = rangeEvents
        .where((e) => e.toStatus == 'postponed')
        .map((e) => e.taskId)
        .toSet();

    // 5. Partial count = distinct tasks with a partial event in range
    final partialTaskIds = rangeEvents
        .where((e) => e.toStatus == 'partial')
        .map((e) => e.taskId)
        .toSet();

    // 6. Waiting + Stopped count = distinct tasks with waiting or stopped in range
    final waitingStoppedTaskIds = rangeEvents
        .where((e) => e.toStatus == 'waiting' || e.toStatus == 'stopped')
        .map((e) => e.taskId)
        .toSet();

    // 7. Average duration = mean of (finished_at - started_at) in minutes for completed tasks
    double totalDurationMinutes = 0;
    int durationCount = 0;
    for (final t in completedTasks) {
      if (t.finishedAt != null && t.startedAt != null && t.finishedAt! >= t.startedAt!) {
        final diffMin = (t.finishedAt! - t.startedAt!) / (1000 * 60);
        totalDurationMinutes += diffMin;
        durationCount++;
      }
    }
    final avgDuration = durationCount > 0 ? (totalDurationMinutes / durationCount) : 0.0;

    // 8. Streak calculation from allDoneEvents
    final streaks = calculateStreaks(allDoneEvents, today: today);

    // 9. Completed diff vs previous period
    final completedDiff = completedTasks.length - previousPeriodCompletedCount;

    // 10. Status distribution of the scheduled set
    final statusDist = <String, int>{
      'todo': 0,
      'in_progress': 0,
      'partial': 0,
      'done': 0,
      'postponed': 0,
      'waiting': 0,
      'stopped': 0,
    };
    for (final t in scheduledSet) {
      final st = statusDist.containsKey(t.status) ? t.status : 'todo';
      statusDist[st] = (statusDist[st] ?? 0) + 1;
    }

    // 11. Top 5 reasons across postponed / waiting / stopped / partial
    final reasonStats = <String, Map<String, int>>{};
    for (final e in rangeEvents) {
      if (['postponed', 'waiting', 'stopped', 'partial'].contains(e.toStatus)) {
        final r = (e.reasonText ?? '').trim();
        if (r.isNotEmpty) {
          reasonStats.putIfAbsent(r, () => {'total': 0, 'postponed': 0, 'waiting': 0, 'stopped': 0, 'partial': 0});
          reasonStats[r]!['total'] = (reasonStats[r]!['total'] ?? 0) + 1;
          reasonStats[r]![e.toStatus] = (reasonStats[r]![e.toStatus] ?? 0) + 1;
        }
      }
    }

    final topReasons = reasonStats.entries.map((entry) {
      return ReasonCount(
        reason: entry.key,
        count: entry.value['total'] ?? 0,
        postponed: entry.value['postponed'] ?? 0,
        waiting: entry.value['waiting'] ?? 0,
        stopped: entry.value['stopped'] ?? 0,
        partial: entry.value['partial'] ?? 0,
      );
    }).toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    // 12. Most productive weekday (count by finished day of week)
    final weekdayProductivity = <int, int>{
      DateTime.saturday: 0,
      DateTime.sunday: 0,
      DateTime.monday: 0,
      DateTime.tuesday: 0,
      DateTime.wednesday: 0,
      DateTime.thursday: 0,
      DateTime.friday: 0,
    };
    final dailyCompletedCounts = <DateTime, int>{};

    for (final e in doneEventsInRange) {
      final dt = DateTime.fromMillisecondsSinceEpoch(e.at);
      final dayKey = DateTime(dt.year, dt.month, dt.day);
      weekdayProductivity[dt.weekday] = (weekdayProductivity[dt.weekday] ?? 0) + 1;
      dailyCompletedCounts[dayKey] = (dailyCompletedCounts[dayKey] ?? 0) + 1;
    }

    // 13. Highlights = latest up to 10 completed tasks in range
    final sortedCompleted = List<Task>.from(completedTasks)
      ..sort((a, b) => (b.finishedAt ?? 0).compareTo(a.finishedAt ?? 0));
    final highlights = sortedCompleted.take(10).toList();

    // 14. Goals metrics
    final goalsCompleted = goals.where((g) {
      if (g.status != 'done') return false;
      final upd = g.updatedAt;
      return upd >= startMs && upd <= endMs;
    }).length;

    final milestonesCompleted = milestones.where((m) {
      if (m.status != 'done') return false;
      final upd = m.updatedAt;
      return upd >= startMs && upd <= endMs;
    }).length;

    final goalsChangedIds = goalUpdates
        .where((u) => u.at >= startMs && u.at <= endMs)
        .map((u) => u.goalId)
        .toSet();

    // 15. Ideas metrics
    final ideasCreated = ideas.where((i) => i.createdAt >= startMs && i.createdAt <= endMs).length;
    final ideasConverted = ideas.where((i) {
      if (i.status != 'converted') return false;
      final upd = i.updatedAt;
      return upd >= startMs && upd <= endMs;
    }).length;

    return StatsResult(
      range: range,
      scheduledCount: scheduledSet.length,
      completedCount: completedTasks.length,
      completedDiff: completedDiff,
      completionRate: double.parse(completionRate.toStringAsFixed(1)),
      postponedCount: postponedTaskIds.length,
      partialCount: partialTaskIds.length,
      waitingStoppedCount: waitingStoppedTaskIds.length,
      averageDurationMinutes: double.parse(avgDuration.toStringAsFixed(1)),
      currentStreak: streaks.current,
      bestStreak: streaks.best,
      statusDistribution: statusDist,
      topReasons: topReasons.take(5).toList(),
      weekdayProductivity: weekdayProductivity,
      dailyCompletedCounts: dailyCompletedCounts,
      highlights: highlights,
      goalsCompletedCount: goalsCompleted,
      milestonesCompletedCount: milestonesCompleted,
      goalsWithProgressChange: goalsChangedIds.length,
      ideasCreatedCount: ideasCreated,
      ideasConvertedCount: ideasConverted,
    );
  }

  /// Calculate current streak and best streak across all done events
  static ({int current, int best}) calculateStreaks(
    List<TaskEvent> allDoneEvents, {
    DateTime? today,
  }) {
    if (allDoneEvents.isEmpty) {
      return (current: 0, best: 0);
    }

    final now = today ?? DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    final yesterdayDate = todayDate.subtract(const Duration(days: 1));

    // Extract sorted unique done dates
    final uniqueDoneDates = allDoneEvents
        .map((e) {
          final dt = DateTime.fromMillisecondsSinceEpoch(e.at);
          return DateTime(dt.year, dt.month, dt.day);
        })
        .toSet()
        .toList()
      ..sort();

    if (uniqueDoneDates.isEmpty) {
      return (current: 0, best: 0);
    }

    // 1. Calculate best streak ever
    int bestStreak = 0;
    int currentRun = 0;
    DateTime? lastDate;

    for (final d in uniqueDoneDates) {
      if (lastDate == null) {
        currentRun = 1;
      } else {
        final diff = d.difference(lastDate).inDays;
        if (diff == 1) {
          currentRun++;
        } else if (diff > 1) {
          currentRun = 1;
        }
      }
      if (currentRun > bestStreak) {
        bestStreak = currentRun;
      }
      lastDate = d;
    }

    // 2. Calculate current streak (ending today, or ending yesterday if today has none yet)
    final dateSet = uniqueDoneDates.toSet();
    int currentStreak = 0;
    DateTime checkDate = dateSet.contains(todayDate) ? todayDate : yesterdayDate;

    while (dateSet.contains(checkDate)) {
      currentStreak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    return (current: currentStreak, best: bestStreak);
  }
}
