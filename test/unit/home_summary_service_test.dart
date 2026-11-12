import 'package:flutter_test/flutter_test.dart';
import 'package:enjaz/core/db/app_database.dart';
import 'package:enjaz/features/home/domain/home_summary_service.dart';

void main() {
  group('HomeSummaryService - Pure Logic Rules', () {
    group('Next-task rule (UI.md Section 4.2 & Section 8 Rule 4)', () {
      test('selects earlier task with time over task without time', () {
        final tasks = [
          Task(
            id: 1,
            title: 'Task without time',
            dueDate: '2026-11-12',
            dueTime: null,
            status: 'pending',
            createdAt: DateTime.now(),
          ),
          Task(
            id: 2,
            title: 'Meeting at 14:00',
            dueDate: '2026-11-12',
            dueTime: '14:00',
            status: 'pending',
            createdAt: DateTime.now(),
          ),
          Task(
            id: 3,
            title: 'Morning review at 09:00',
            dueDate: '2026-11-12',
            dueTime: '09:00',
            status: 'pending',
            createdAt: DateTime.now(),
          ),
        ];

        final result = HomeSummaryService.findNextTask(tasks);
        expect(result.nextTaskTitle, 'Morning review at 09:00');
        expect(result.nextTaskTime, '09:00');
        expect(result.isAllDone, isFalse);
      });

      test('falls back to first unfinished task when none have dueTime', () {
        final tasks = [
          Task(
            id: 1,
            title: 'General task 1',
            dueDate: '2026-11-12',
            status: 'pending',
            createdAt: DateTime.now(),
          ),
          Task(
            id: 2,
            title: 'General task 2',
            dueDate: '2026-11-12',
            status: 'pending',
            createdAt: DateTime.now(),
          ),
        ];

        final result = HomeSummaryService.findNextTask(tasks);
        expect(result.nextTaskTitle, 'General task 1');
        expect(result.nextTaskTime, isNull);
        expect(result.isAllDone, isFalse);
      });

      test('ignores completed tasks when selecting next task', () {
        final tasks = [
          Task(
            id: 1,
            title: 'Done task at 08:00',
            dueDate: '2026-11-12',
            dueTime: '08:00',
            status: 'done',
            createdAt: DateTime.now(),
          ),
          Task(
            id: 2,
            title: 'Upcoming task at 10:00',
            dueDate: '2026-11-12',
            dueTime: '10:00',
            status: 'pending',
            createdAt: DateTime.now(),
          ),
        ];

        final result = HomeSummaryService.findNextTask(tasks);
        expect(result.nextTaskTitle, 'Upcoming task at 10:00');
        expect(result.nextTaskTime, '10:00');
        expect(result.isAllDone, isFalse);
      });

      test('returns isAllDone = true and nextTaskTitle = null when all tasks done', () {
        final tasks = [
          Task(
            id: 1,
            title: 'Task 1',
            dueDate: '2026-11-12',
            status: 'done',
            createdAt: DateTime.now(),
          ),
          Task(
            id: 2,
            title: 'Task 2',
            dueDate: '2026-11-12',
            dueTime: '12:00',
            status: 'done',
            createdAt: DateTime.now(),
          ),
        ];

        final result = HomeSummaryService.findNextTask(tasks);
        expect(result.nextTaskTitle, isNull);
        expect(result.nextTaskTime, isNull);
        expect(result.isAllDone, isTrue);
      });

      test('returns null and isAllDone = false when today has no tasks at all', () {
        final result = HomeSummaryService.findNextTask([]);
        expect(result.nextTaskTitle, isNull);
        expect(result.nextTaskTime, isNull);
        expect(result.isAllDone, isFalse);
      });
    });

    group('Streak rule (UI.md Section 4.2 & Section 8 Rule 4)', () {
      final today = DateTime(2026, 11, 12);

      test('consecutive days ending today returns full count (e.g. 3 days)', () {
        final map = {
          '2026-11-12': true,
          '2026-11-11': true,
          '2026-11-10': true,
          '2026-11-09': false,
        };

        final streak = HomeSummaryService.calculateStreak(
          allScheduledHabitsDoneByDate: map,
          today: today,
        );
        expect(streak, 3);
      });

      test('when today is incomplete, streak counts consecutive days ending yesterday (e.g. 2 days)', () {
        final map = {
          '2026-11-12': false, // today incomplete
          '2026-11-11': true,  // yesterday done
          '2026-11-10': true,  // day before done
          '2026-11-09': false,
        };

        final streak = HomeSummaryService.calculateStreak(
          allScheduledHabitsDoneByDate: map,
          today: today,
        );
        expect(streak, 2);
      });

      test('broken streak when day before yesterday is missed', () {
        final map = {
          '2026-11-12': false,
          '2026-11-11': true,
          '2026-11-10': false,
        };

        final streak = HomeSummaryService.calculateStreak(
          allScheduledHabitsDoneByDate: map,
          today: today,
        );
        expect(streak, 1);
      });

      test('returns 0 when yesterday was missed and today is incomplete', () {
        final map = {
          '2026-11-12': false,
          '2026-11-11': false,
          '2026-11-10': true,
        };

        final streak = HomeSummaryService.calculateStreak(
          allScheduledHabitsDoneByDate: map,
          today: today,
        );
        expect(streak, 0);
      });
    });

    group('Budget rule (UI.md Section 4.2 & Section 8 Rule 4)', () {
      test('calculates remaining budget when overall monthly limit exists', () {
        final remaining = HomeSummaryService.calculateRemainingBudget(
          overallMonthlyLimitMinor: 500000, // 5000.00
          monthlyExpensesMinor: 320000,     // 3200.00
        );
        expect(remaining, 180000); // 1800.00
      });

      test('handles over-budget as negative remaining value', () {
        final remaining = HomeSummaryService.calculateRemainingBudget(
          overallMonthlyLimitMinor: 500000,
          monthlyExpensesMinor: 600000,
        );
        expect(remaining, -100000);
      });

      test('returns null when no overall budget limit is set', () {
        final remaining = HomeSummaryService.calculateRemainingBudget(
          overallMonthlyLimitMinor: null,
          monthlyExpensesMinor: 320000,
        );
        expect(remaining, isNull);
      });
    });
  });
}
