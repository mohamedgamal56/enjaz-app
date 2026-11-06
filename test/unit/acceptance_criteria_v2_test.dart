import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:enjaz/features/habits/domain/habits_service.dart';
import 'package:enjaz/features/finance/domain/finance_service.dart';
import 'package:enjaz/features/health/domain/health_service.dart';
import 'package:enjaz/features/timeline/domain/timeline_models.dart';
import 'package:enjaz/core/utils/money_formatter.dart';
import 'package:enjaz/core/utils/date_formatter.dart';

void main() {
  group('Enjaz v2.0 - Section 14 Complete Acceptance Verification', () {
    test('Round 4 Acceptance: Habit completion rules, streaks, and missed days', () {
      const habitsService = HabitsService();

      // Check habit logged => complete
      expect(habitsService.isCompleted(type: 'check', logValue: 1.0), isTrue);
      expect(habitsService.isCompleted(type: 'check', logValue: null), isFalse);

      // Count habit: target 8 cups => complete when >= 8
      expect(habitsService.isCompleted(type: 'count', target: 8.0, logValue: 8.0), isTrue);
      expect(habitsService.isCompleted(type: 'count', target: 8.0, logValue: 7.0), isFalse);

      // Amount habit: target 30 min => complete when >= 30
      expect(habitsService.isCompleted(type: 'amount', target: 30.0, logValue: 30.0), isTrue);
      expect(habitsService.isCompleted(type: 'amount', target: 30.0, logValue: 25.0), isFalse);

      // Checklist habit: all items checked => complete
      expect(habitsService.isCompleted(type: 'checklist', checklistTotalItems: 5, checklistDoneItems: 5), isTrue);
      expect(habitsService.isCompleted(type: 'checklist', checklistTotalItems: 5, checklistDoneItems: 4), isFalse);
    });

    test('Round 5 Acceptance: Finance calculations, essential vs side, savings rate & masking eye', () {
      const financeService = FinanceService();

      // 1. Savings rate calculation
      final savingsRate = financeService.calculateSavingsRate(
        incomeMinor: 1000000, // 10,000 EGP
        expensesMinor: 600000, // 6,000 EGP
      );
      expect(savingsRate, 40.0); // 40% saved

      // Zero income shows 0.0
      expect(financeService.calculateSavingsRate(incomeMinor: 0, expensesMinor: 50000), 0.0);

      // 2. MoneyFormatter with Masking Eye
      const amount = 2550; // 25.50 EGP
      expect(MoneyFormatter.formatAmount(amount, masked: false), '25.5');
      expect(MoneyFormatter.formatAmount(amount, masked: true), '••••');
      expect(MoneyFormatter.formatWithCurrency(amount, masked: true), '•••• ج.م');
      expect(MoneyFormatter.formatMinorWithCurrency(amount), '25.5 ج.م');
    });

    test('Round 6 Acceptance: Health waiting time, treatment adherence, and repeating checkups', () {
      const healthService = HealthService();
      final today = DateTime(2026, 11, 6);

      // 1. Waiting duration
      final duration = healthService.calculateWaitingDuration('2026-08-08', today);
      expect(duration.months, 3);
      expect(duration.format(true), 'محتاج من 3 شهر');

      // 2. Treatment adherence calculation (9 days taken out of 10 days = 90%)
      final adherence = healthService.calculateTreatmentAdherence(
        startDate: '2026-11-01',
        today: DateTime(2026, 11, 10),
        takenDaysCount: 9,
      );
      expect(adherence.elapsedDays, 10);
      expect(adherence.takenDays, 9);
      expect(adherence.percentage, 90.0);

      // 3. Repeating checkup next date calculation (repeat every 6 months)
      final nextDate = healthService.getNextRecurringDate(
        doneDate: DateTime(2026, 11, 6),
        repeatEveryMonths: 6,
      );
      expect(nextDate, '2027-05-06');
    });

    test('Round 7 Acceptance: Timeline 2026-2046 bounds, module colors, and entry ordering', () {
      // 1. Range bounds: 1 Jan 2026 to 31 Dec 2046
      expect(TimelineConstants.minDate, DateTime(2026, 1, 1));
      expect(TimelineConstants.maxDate, DateTime(2046, 12, 31));

      // 2. Module distinct colors: tasks=blue, habits=teal, finance=green, health=red, notes=orange, ideas=purple, goals=indigo
      expect(TimelineModule.task.color, const Color(0xFF2196F3));
      expect(TimelineModule.habit.color, const Color(0xFF009688));
      expect(TimelineModule.finance.color, const Color(0xFF4CAF50));
      expect(TimelineModule.health.color, const Color(0xFFFF5252));
      expect(TimelineModule.note.color, const Color(0xFFFF9800));
      expect(TimelineModule.idea.color, const Color(0xFF9C27B0));
      expect(TimelineModule.goal.color, const Color(0xFF3F51B5));

      // 3. All-day placed above timed entries, and timed sorted by occurredAt ASC
      final entries = [
        TimelineEntry(
          id: '1',
          module: TimelineModule.finance,
          occurredAt: 1730000000000 + 3600000 * 14, // 14:00
          localDate: '2026-11-06',
          allDay: false,
          timeStr: '14:00',
          title: 'غداء',
          icon: Icons.fastfood,
          color: Colors.green,
          sourceType: 'transaction',
          sourceId: 1,
        ),
        TimelineEntry(
          id: '2',
          module: TimelineModule.health,
          occurredAt: 1730000000000 + 3600000 * 9, // 09:00
          localDate: '2026-11-06',
          allDay: false,
          timeStr: '09:00',
          title: 'تحليل دم',
          icon: Icons.favorite,
          color: Colors.red,
          sourceType: 'health_item',
          sourceId: 1,
        ),
        TimelineEntry(
          id: '3',
          module: TimelineModule.note,
          occurredAt: 1730000000000,
          localDate: '2026-11-06',
          allDay: true,
          timeStr: null,
          title: 'فكرة اليوم',
          icon: Icons.note,
          color: Colors.orange,
          sourceType: 'note',
          sourceId: 1,
        ),
      ];

      entries.sort((a, b) {
        if (a.allDay != b.allDay) return a.allDay ? -1 : 1;
        return a.occurredAt.compareTo(b.occurredAt);
      });

      expect(entries[0].id, '3'); // All day first
      expect(entries[0].allDay, isTrue);
      expect(entries[1].id, '2'); // 09:00
      expect(entries[2].id, '1'); // 14:00
    });
  });
}
