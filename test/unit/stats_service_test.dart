import 'package:flutter_test/flutter_test.dart';
import 'package:enjaz/features/stats/domain/stats_service.dart';
import 'package:enjaz/core/db/app_database.dart';

void main() {
  group('StatsService - Range Resolution', () {
    test('Week range correctly starts on Saturday by default', () {
      // Wednesday 2026-11-04
      final ref = DateTime(2026, 11, 4);
      final range = StatsService.resolveRange(
        type: StatsRangeType.week,
        referenceDate: ref,
        firstDayOfWeek: DateTime.saturday,
      );

      // Saturday prior to Nov 4 is Oct 31
      expect(range.start.year, 2026);
      expect(range.start.month, 10);
      expect(range.start.day, 31);
      expect(range.start.weekday, DateTime.saturday);

      // Ends on Friday Nov 6
      expect(range.end.year, 2026);
      expect(range.end.month, 11);
      expect(range.end.day, 6);
      expect(range.end.weekday, DateTime.friday);
    });

    test('Month range covers first to last day', () {
      final ref = DateTime(2026, 2, 15);
      final range = StatsService.resolveRange(
        type: StatsRangeType.month,
        referenceDate: ref,
      );

      expect(range.start, DateTime(2026, 2, 1));
      expect(range.end.day, 28);
    });

    test('Previous week range shifts exactly 7 days back', () {
      final ref = DateTime(2026, 11, 4);
      final range = StatsService.resolveRange(
        type: StatsRangeType.week,
        referenceDate: ref,
      );
      final prev = range.getPreviousRange();

      expect(prev.start.day, 24);
      expect(prev.end.day, 30);
    });
  });

  group('StatsService - Streaks Calculation', () {
    test('Calculates current streak ending today', () {
      final today = DateTime(2026, 11, 3);
      final events = [
        TaskEvent(
          id: 1,
          taskId: 10,
          at: DateTime(2026, 11, 1, 10).millisecondsSinceEpoch,
          fromStatus: 'todo',
          toStatus: 'done',
          progress: 100,
          createdAt: 0,
          updatedAt: 0,
        ),
        TaskEvent(
          id: 2,
          taskId: 11,
          at: DateTime(2026, 11, 2, 14).millisecondsSinceEpoch,
          fromStatus: 'todo',
          toStatus: 'done',
          progress: 100,
          createdAt: 0,
          updatedAt: 0,
        ),
        TaskEvent(
          id: 3,
          taskId: 12,
          at: DateTime(2026, 11, 3, 9).millisecondsSinceEpoch,
          fromStatus: 'todo',
          toStatus: 'done',
          progress: 100,
          createdAt: 0,
          updatedAt: 0,
        ),
      ];

      final streak = StatsService.calculateStreaks(events, today: today);
      expect(streak.current, 3);
      expect(streak.best, 3);
    });

    test('Streak sustains if today has no done tasks yet but yesterday had', () {
      final today = DateTime(2026, 11, 3);
      final events = [
        TaskEvent(
          id: 1,
          taskId: 10,
          at: DateTime(2026, 11, 1, 10).millisecondsSinceEpoch,
          fromStatus: 'todo',
          toStatus: 'done',
          progress: 100,
          createdAt: 0,
          updatedAt: 0,
        ),
        TaskEvent(
          id: 2,
          taskId: 11,
          at: DateTime(2026, 11, 2, 14).millisecondsSinceEpoch,
          fromStatus: 'todo',
          toStatus: 'done',
          progress: 100,
          createdAt: 0,
          updatedAt: 0,
        ),
      ];

      final streak = StatsService.calculateStreaks(events, today: today);
      expect(streak.current, 2);
    });

    test('Streak resets to 0 if gap is larger than 1 day', () {
      final today = DateTime(2026, 11, 3);
      final events = [
        TaskEvent(
          id: 1,
          taskId: 10,
          at: DateTime(2026, 10, 31, 10).millisecondsSinceEpoch,
          fromStatus: 'todo',
          toStatus: 'done',
          progress: 100,
          createdAt: 0,
          updatedAt: 0,
        ),
      ];

      final streak = StatsService.calculateStreaks(events, today: today);
      expect(streak.current, 0);
      expect(streak.best, 1);
    });
  });

  group('StatsService - Metrics & Completion Rate', () {
    test('Excludes future scheduled tasks from completion rate denominator', () {
      final now = DateTime(2026, 11, 3, 12, 0);
      final range = StatsDateRange(
        type: StatsRangeType.week,
        start: DateTime(2026, 11, 1),
        end: DateTime(2026, 11, 7, 23, 59, 59),
      );

      final tasks = [
        // Task 1: Due today, done
        Task(
          id: 1,
          title: 'T1',
          kind: 'task',
          status: 'done',
          progress: 100,
          priority: 'normal',
          dueDate: '2026-11-03',
          createdAt: DateTime(2026, 11, 1).millisecondsSinceEpoch,
          updatedAt: DateTime(2026, 11, 1).millisecondsSinceEpoch,
          postponeCount: 0,
        ),
        // Task 2: Due yesterday, todo
        Task(
          id: 2,
          title: 'T2',
          kind: 'task',
          status: 'todo',
          progress: 0,
          priority: 'normal',
          dueDate: '2026-11-02',
          createdAt: DateTime(2026, 11, 1).millisecondsSinceEpoch,
          updatedAt: DateTime(2026, 11, 1).millisecondsSinceEpoch,
          postponeCount: 0,
        ),
        // Task 3: Due tomorrow (future), should be excluded from denominator!
        Task(
          id: 3,
          title: 'T3',
          kind: 'task',
          status: 'todo',
          progress: 0,
          priority: 'normal',
          dueDate: '2026-11-05',
          createdAt: DateTime(2026, 11, 1).millisecondsSinceEpoch,
          updatedAt: DateTime(2026, 11, 1).millisecondsSinceEpoch,
          postponeCount: 0,
        ),
      ];

      final events = [
        TaskEvent(
          id: 1,
          taskId: 1,
          at: DateTime(2026, 11, 3, 11).millisecondsSinceEpoch,
          fromStatus: 'todo',
          toStatus: 'done',
          progress: 100,
          createdAt: 0,
          updatedAt: 0,
        ),
      ];

      final service = const StatsService();
      final result = service.computeStats(
        range: range,
        tasks: tasks,
        rangeEvents: events,
        allDoneEvents: events,
        previousPeriodCompletedCount: 0,
        now: now,
      );

      // Denominator should be 2 (tasks 1 and 2), numerator 1 (task 1) => 50.0%
      expect(result.completionRate, 50.0);
      expect(result.scheduledCount, 3);
      expect(result.completedCount, 1);
    });

    test('Calculates average duration in minutes for completed tasks', () {
      final range = StatsDateRange(
        type: StatsRangeType.week,
        start: DateTime(2026, 11, 1),
        end: DateTime(2026, 11, 7, 23, 59, 59),
      );

      final start1 = DateTime(2026, 11, 2, 10, 0).millisecondsSinceEpoch;
      final finish1 = DateTime(2026, 11, 2, 10, 30).millisecondsSinceEpoch; // 30 mins

      final start2 = DateTime(2026, 11, 3, 14, 0).millisecondsSinceEpoch;
      final finish2 = DateTime(2026, 11, 3, 15, 30).millisecondsSinceEpoch; // 90 mins

      final tasks = [
        Task(
          id: 1,
          title: 'Task 1',
          kind: 'task',
          status: 'done',
          progress: 100,
          priority: 'normal',
          startedAt: start1,
          finishedAt: finish1,
          createdAt: 0,
          updatedAt: 0,
          postponeCount: 0,
        ),
        Task(
          id: 2,
          title: 'Task 2',
          kind: 'task',
          status: 'done',
          progress: 100,
          priority: 'normal',
          startedAt: start2,
          finishedAt: finish2,
          createdAt: 0,
          updatedAt: 0,
          postponeCount: 0,
        ),
      ];

      final events = [
        TaskEvent(id: 1, taskId: 1, at: finish1, fromStatus: 'todo', toStatus: 'done', progress: 100, createdAt: 0, updatedAt: 0),
        TaskEvent(id: 2, taskId: 2, at: finish2, fromStatus: 'todo', toStatus: 'done', progress: 100, createdAt: 0, updatedAt: 0),
      ];

      final service = const StatsService();
      final result = service.computeStats(
        range: range,
        tasks: tasks,
        rangeEvents: events,
        allDoneEvents: events,
        previousPeriodCompletedCount: 1,
      );

      // (30 + 90) / 2 = 60 mins
      expect(result.averageDurationMinutes, 60.0);
      expect(result.completedDiff, 1); // 2 - 1 = +1
    });
  });
}
