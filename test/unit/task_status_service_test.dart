import 'package:flutter_test/flutter_test.dart';
import 'package:enjaz/features/tasks/domain/task_status_service.dart';

void main() {
  group('TaskStatusService Transition Tests (Spec Section 5)', () {
    test('Moving to done sets finished_at and progress to 100', () {
      final now = 1700000000000;
      final res = TaskStatusService.applyTransition(
        currentStatus: 'todo',
        targetStatus: 'done',
        nowMs: now,
      );

      expect(res.status, 'done');
      expect(res.finishedAt, now);
      expect(res.progress, 100);
    });

    test('Moving to in_progress sets started_at if null', () {
      final now = 1700000000000;
      final res = TaskStatusService.applyTransition(
        currentStatus: 'todo',
        targetStatus: 'in_progress',
        currentStartedAt: null,
        nowMs: now,
      );

      expect(res.status, 'in_progress');
      expect(res.startedAt, now);
    });

    test('Moving to in_progress preserves existing started_at', () {
      final oldStarted = 1690000000000;
      final now = 1700000000000;
      final res = TaskStatusService.applyTransition(
        currentStatus: 'todo',
        targetStatus: 'in_progress',
        currentStartedAt: oldStarted,
        nowMs: now,
      );

      expect(res.startedAt, oldStarted);
    });

    test('Reopening done task clears finished_at', () {
      final oldFinished = 1690000000000;
      final res = TaskStatusService.applyTransition(
        currentStatus: 'done',
        targetStatus: 'todo',
        currentFinishedAt: oldFinished,
      );

      expect(res.status, 'todo');
      expect(res.finishedAt, isNull);
      expect(res.progress, 0);
    });

    test('Postponing increments postponeCount and sets postponedUntil', () {
      final res = TaskStatusService.applyTransition(
        currentStatus: 'todo',
        targetStatus: 'postponed',
        currentPostponeCount: 1,
        newPostponedUntil: '2026-11-05',
      );

      expect(res.status, 'postponed');
      expect(res.postponeCount, 2);
      expect(res.postponedUntil, '2026-11-05');
    });

    test('Moving away from postponed clears postponedUntil', () {
      final res = TaskStatusService.applyTransition(
        currentStatus: 'postponed',
        targetStatus: 'in_progress',
        currentPostponedUntil: '2026-11-05',
      );

      expect(res.status, 'in_progress');
      expect(res.postponedUntil, isNull);
    });

    test('Validating partial status requires 1-99 progress and reason', () {
      expect(
        TaskStatusService.validateTransition(
          targetStatus: 'partial',
          progress: 0,
          reasonText: 'busy',
        ),
        isNotNull,
      );

      expect(
        TaskStatusService.validateTransition(
          targetStatus: 'partial',
          progress: 50,
          reasonText: null,
        ),
        isNotNull,
      );

      expect(
        TaskStatusService.validateTransition(
          targetStatus: 'partial',
          progress: 50,
          reasonText: 'No energy',
        ),
        isNull,
      );
    });

    test('Postponed, waiting, stopped require reasons', () {
      expect(
        TaskStatusService.validateTransition(
          targetStatus: 'postponed',
          reasonText: null,
        ),
        isNotNull,
      );

      expect(
        TaskStatusService.validateTransition(
          targetStatus: 'waiting',
          reasonId: 1,
        ),
        isNull,
      );

      expect(
        TaskStatusService.validateTransition(
          targetStatus: 'stopped',
          reasonText: 'Cancelled scope',
        ),
        isNull,
      );
    });
  });
}
