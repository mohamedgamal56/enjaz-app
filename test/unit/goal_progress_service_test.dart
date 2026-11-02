import 'package:flutter_test/flutter_test.dart';
import 'package:enjaz/features/goals/domain/goal_progress_service.dart';

void main() {
  group('GoalProgressService Tests (Spec Section 4 & 6.6)', () {
    test('Milestones progress with equal weights', () {
      final weights = [1, 1, 1, 1];
      final done = [true, true, false, false];

      final progress = GoalProgressService.calculateMilestonesProgress(
        weights: weights,
        isDoneList: done,
      );

      expect(progress, 50.0);
    });

    test('Milestones progress with custom weights', () {
      // weights: 1, 3, 6 (total = 10)
      final weights = [1, 3, 6];
      final done = [true, true, false]; // done weights: 1 + 3 = 4

      final progress = GoalProgressService.calculateMilestonesProgress(
        weights: weights,
        isDoneList: done,
      );

      expect(progress, 40.0);
    });

    test('Milestones progress returns 0 when empty', () {
      final progress = GoalProgressService.calculateMilestonesProgress(
        weights: [],
        isDoneList: [],
      );

      expect(progress, 0.0);
    });

    test('Numeric progress normal and capped at 100', () {
      expect(
        GoalProgressService.calculateNumericProgress(
          currentValue: 1200,
          targetValue: 5000,
        ),
        24.0,
      );

      // Capped at 100
      expect(
        GoalProgressService.calculateNumericProgress(
          currentValue: 6000,
          targetValue: 5000,
        ),
        100.0,
      );

      // Target <= 0
      expect(
        GoalProgressService.calculateNumericProgress(
          currentValue: 100,
          targetValue: 0,
        ),
        0.0,
      );
    });

    test('Days left and overdue calculation', () {
      final now = DateTime(2026, 11, 2);

      // 5 days left
      expect(
        GoalProgressService.calculateDaysLeft(
          targetDateStr: '2026-11-07',
          now: now,
        ),
        5,
      );

      // Today (0 days left)
      expect(
        GoalProgressService.calculateDaysLeft(
          targetDateStr: '2026-11-02',
          now: now,
        ),
        0,
      );

      // Overdue (-3 days)
      expect(
        GoalProgressService.calculateDaysLeft(
          targetDateStr: '2026-10-30',
          now: now,
        ),
        -3,
      );

      expect(
        GoalProgressService.isOverdue(
          targetDateStr: '2026-10-30',
          status: 'active',
          now: now,
        ),
        isTrue,
      );

      expect(
        GoalProgressService.isOverdue(
          targetDateStr: '2026-10-30',
          status: 'done',
          now: now,
        ),
        isFalse,
      );
    });
  });
}
