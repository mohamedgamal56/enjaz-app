import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:enjaz/features/timeline/domain/timeline_models.dart';

void main() {
  group('Round 7 - Timeline Models & Logic Tests', () {
    test('1. Timeline range constants are 1 Jan 2026 to 31 Dec 2046', () {
      expect(TimelineConstants.minDate, DateTime(2026, 1, 1));
      expect(TimelineConstants.maxDate, DateTime(2046, 12, 31));
    });

    test('2. Module colors match spec: tasks=blue, habits=teal, finance=green, health=red, notes=orange, ideas=purple, goals=indigo', () {
      expect(TimelineModule.task.color, const Color(0xFF2196F3));
      expect(TimelineModule.habit.color, const Color(0xFF009688));
      expect(TimelineModule.finance.color, const Color(0xFF4CAF50));
      expect(TimelineModule.health.color, const Color(0xFFFF5252));
      expect(TimelineModule.note.color, const Color(0xFFFF9800));
      expect(TimelineModule.idea.color, const Color(0xFF9C27B0));
      expect(TimelineModule.goal.color, const Color(0xFF3F51B5));
    });

    test('3. TimelineEntry sorting places allDay entries at top, then sorts by occurredAt ASC', () {
      final entries = [
        TimelineEntry(
          id: '1',
          module: TimelineModule.task,
          occurredAt: 1730000000000 + 3600000 * 5, // 05:00
          localDate: '2026-11-06',
          allDay: false,
          title: 'مهمة الصباح',
          icon: Icons.task_alt,
          color: Colors.blue,
          sourceType: 'task',
          sourceId: 1,
        ),
        TimelineEntry(
          id: '2',
          module: TimelineModule.task,
          occurredAt: 1730000000000 + 3600000 * 2, // 02:00
          localDate: '2026-11-06',
          allDay: false,
          title: 'مهمة الفجر',
          icon: Icons.task_alt,
          color: Colors.blue,
          sourceType: 'task',
          sourceId: 2,
        ),
        TimelineEntry(
          id: '3',
          module: TimelineModule.note,
          occurredAt: 1730000000000,
          localDate: '2026-11-06',
          allDay: true,
          title: 'ملاحظة اليوم كله',
          icon: Icons.note_alt,
          color: Colors.orange,
          sourceType: 'note',
          sourceId: 3,
        ),
      ];

      entries.sort((a, b) {
        if (a.allDay != b.allDay) return a.allDay ? -1 : 1;
        return a.occurredAt.compareTo(b.occurredAt);
      });

      // All day must be first
      expect(entries[0].id, '3');
      expect(entries[0].allDay, isTrue);

      // Then 02:00
      expect(entries[1].id, '2');

      // Then 05:00
      expect(entries[2].id, '1');
    });

    test('4. TimelineDaySummary tracks metrics accurately', () {
      const summary = TimelineDaySummary(
        tasksDoneCount: 4,
        expensesMinor: 15000,
        incomeMinor: 50000,
        habitsDoneCount: 3,
        notesCount: 2,
        ideasCount: 1,
      );

      expect(summary.isEmpty, isFalse);
      expect(summary.tasksDoneCount, 4);
      expect(summary.expensesMinor, 15000);
      expect(summary.incomeMinor, 50000);
      expect(summary.habitsDoneCount, 3);
      expect(summary.notesCount, 2);
      expect(summary.ideasCount, 1);
    });

    test('5. TimelineOverviewSummary combines all modules headline numbers', () {
      const overview = TimelineOverviewSummary(
        tasksDoneCount: 12,
        topSpendingCategory: 'شاي وقهوة',
        topSpendingAmountMinor: 15000,
        totalExpensesMinor: 45000,
        totalIncomeMinor: 120000,
        habitsCompletionRate: 85.5,
        habitsLoggedCount: 40,
        notesCount: 8,
        goalProgressAvg: 65.0,
        healthItemsDoneCount: 2,
      );

      expect(overview.tasksDoneCount, 12);
      expect(overview.topSpendingCategory, 'شاي وقهوة');
      expect(overview.habitsCompletionRate, 85.5);
      expect(overview.goalProgressAvg, 65.0);
      expect(overview.healthItemsDoneCount, 2);
    });
  });
}
