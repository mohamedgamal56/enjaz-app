import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:enjaz/core/db/app_database.dart';
import 'package:enjaz/features/stats/domain/stats_service.dart';

void main() {
  group('Performance Benchmark (PLAN.md Section 7 Batch 4)', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('5,000 tasks and 5 years of data benchmark: queries remain fast and responsive', () async {
      const totalTasks = 5000;
      final baseDate = DateTime(2021, 1, 1);
      final daysSpan = 5 * 365; // ~5 years

      // Batch insert 5,000 tasks inside a single SQLite transaction
      final stopwatchBatchInsert = Stopwatch()..start();
      await db.transaction(() async {
        for (int i = 0; i < totalTasks; i++) {
          final taskDate = baseDate.add(Duration(days: i % daysSpan));
          final dateStr =
              '${taskDate.year}-${taskDate.month.toString().padLeft(2, '0')}-${taskDate.day.toString().padLeft(2, '0')}';
          final status = i % 5 == 0
              ? 'done'
              : (i % 7 == 0
                  ? 'postponed'
                  : (i % 11 == 0 ? 'partial' : 'todo'));

          await db.into(db.tasks).insert(
                TasksCompanion.insert(
                  title: 'المهمة الاختبارية رقم $i لأداء النظام',
                  kind: drift.Value(i % 3 == 0 ? 'errand' : 'task'),
                  priority: drift.Value(i % 2 == 0 ? 'normal' : 'high'),
                  dueDate: drift.Value(dateStr),
                  dueTime: drift.Value(i % 4 == 0 ? '14:00' : null),
                  status: drift.Value(status),
                  progress: drift.Value(status == 'done' ? 100 : (status == 'partial' ? 50 : 0)),
                  postponeCount: drift.Value(status == 'postponed' ? 2 : 0),
                  createdAt: taskDate.millisecondsSinceEpoch,
                  updatedAt: taskDate.millisecondsSinceEpoch,
                ),
              );
        }
      });
      stopwatchBatchInsert.stop();

      // Assert database contains all 5,000 tasks
      final countResult = await db.customSelect('SELECT count(*) as c FROM tasks').getSingle();
      final totalInDb = countResult.read<int>('c');
      expect(totalInDb, equals(totalTasks));

      // 1. Query tasks for a specific target date (e.g. 2024-06-15)
      final swDateQuery = Stopwatch()..start();
      final dayTasks = await db.watchTasksForDate('2024-06-15').first;
      swDateQuery.stop();

      // 2. Query overdue tasks relative to 2026-01-01
      final swOverdueQuery = Stopwatch()..start();
      final overdueTasks = await db.watchOverdueTasks('2026-01-01').first;
      swOverdueQuery.stop();

      // 3. Query undated tasks count
      final swUndatedQuery = Stopwatch()..start();
      final undatedCount = await db.watchUndatedTasksCount().first;
      swUndatedQuery.stop();

      // 4. Query paginated history (first page of 50 tasks)
      final swHistoryQuery = Stopwatch()..start();
      final historyPage = await (db.select(db.tasks)
            ..where((t) => t.status.equals('done') | t.status.equals('postponed'))
            ..orderBy([(t) => drift.OrderingTerm(expression: t.updatedAt, mode: drift.OrderingMode.desc)])
            ..limit(50))
          .get();
      swHistoryQuery.stop();

      // 5. Measure StatsService aggregation for Month range across 5,000 tasks
      final allTasks = await db.select(db.tasks).get();
      final statsService = StatsService();
      final targetRange = StatsDateRange(
        type: StatsRangeType.month,
        start: DateTime(2024, 6, 1),
        end: DateTime(2024, 6, 30),
      );

      final swStatsComputation = Stopwatch()..start();
      final statsResult = statsService.computeStats(
        range: targetRange,
        tasks: allTasks,
        rangeEvents: [],
        allDoneEvents: [],
        previousPeriodCompletedCount: 10,
        now: DateTime(2024, 6, 15),
      );
      swStatsComputation.stop();

      // Output performance numbers to test log
      // ignore: avoid_print
      print('=== Performance Benchmark Results (5,000 tasks / 5 years) ===');
      // ignore: avoid_print
      print('  Batch Insert Time (5,000 rows): ${stopwatchBatchInsert.elapsedMilliseconds} ms');
      // ignore: avoid_print
      print('  Day Query (watchTasksForDate): ${swDateQuery.elapsedMilliseconds} ms (returned ${dayTasks.length} tasks)');
      // ignore: avoid_print
      print('  Overdue Query (watchOverdueTasks): ${swOverdueQuery.elapsedMilliseconds} ms (returned ${overdueTasks.length} tasks)');
      // ignore: avoid_print
      print('  Undated Count Query: ${swUndatedQuery.elapsedMilliseconds} ms ($undatedCount tasks)');
      // ignore: avoid_print
      print('  History Page Query (50 items): ${swHistoryQuery.elapsedMilliseconds} ms');
      // ignore: avoid_print
      print('  StatsService Computation (5,000 tasks): ${swStatsComputation.elapsedMilliseconds} ms');

      // Verify responsiveness thresholds: individual queries must be sub-100ms
      expect(swDateQuery.elapsedMilliseconds, lessThan(100), reason: 'Daily task query must remain sub-100ms');
      expect(swOverdueQuery.elapsedMilliseconds, lessThan(100), reason: 'Overdue task query must remain sub-100ms');
      expect(swHistoryQuery.elapsedMilliseconds, lessThan(100), reason: 'Paginated history query must remain sub-100ms');
      expect(swStatsComputation.elapsedMilliseconds, lessThan(250), reason: 'Stats computation across 5,000 tasks must remain fast (< 250ms)');
      expect(statsResult.scheduledCount, greaterThan(0));
    });
  });
}
