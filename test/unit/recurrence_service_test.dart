import 'package:flutter_test/flutter_test.dart';
import 'package:enjaz/features/recurrence/domain/recurrence_service.dart';

void main() {
  group('RecurrenceService - Weekdays Bitmask', () {
    test('Set and check individual weekdays correctly', () {
      int mask = 0;
      // Monday = 1, Saturday = 6, Sunday = 7
      expect(RecurrenceService.isWeekdaySelected(mask, DateTime.monday), false);

      mask = RecurrenceService.setWeekday(mask, DateTime.monday, true);
      expect(RecurrenceService.isWeekdaySelected(mask, DateTime.monday), true);
      expect(RecurrenceService.isWeekdaySelected(mask, DateTime.saturday), false);

      mask = RecurrenceService.setWeekday(mask, DateTime.saturday, true);
      expect(RecurrenceService.isWeekdaySelected(mask, DateTime.monday), true);
      expect(RecurrenceService.isWeekdaySelected(mask, DateTime.saturday), true);

      mask = RecurrenceService.setWeekday(mask, DateTime.monday, false);
      expect(RecurrenceService.isWeekdaySelected(mask, DateTime.monday), false);
      expect(RecurrenceService.isWeekdaySelected(mask, DateTime.saturday), true);
    });
  });

  group('RecurrenceService - Monthly Day Clamping', () {
    test('Clamps day 31 to 28 in February on normal years', () {
      // 2025 is not a leap year
      final clamped = RecurrenceService.clampDayOfMonth(2025, 2, 31);
      expect(clamped, 28);
    });

    test('Clamps day 31 to 29 in February on leap years', () {
      // 2024 is a leap year
      final clamped = RecurrenceService.clampDayOfMonth(2024, 2, 31);
      expect(clamped, 29);
    });

    test('Clamps day 31 to 30 in April', () {
      final clamped = RecurrenceService.clampDayOfMonth(2026, 4, 31);
      expect(clamped, 30);
    });

    test('Leaves day 15 untouched in any month', () {
      expect(RecurrenceService.clampDayOfMonth(2026, 2, 15), 15);
      expect(RecurrenceService.clampDayOfMonth(2026, 4, 15), 15);
    });
  });

  group('RecurrenceService - shouldGenerateOnDate', () {
    test('Daily rule generates on every day between startsOn and endsOn', () {
      final start = '2026-11-01';
      final end = '2026-11-05';

      expect(
        RecurrenceService.shouldGenerateOnDate(
          rule: 'daily',
          weekdaysBitmask: 0,
          startsOn: start,
          endsOn: end,
          targetDate: DateTime(2026, 10, 31), // before start
        ),
        false,
      );

      expect(
        RecurrenceService.shouldGenerateOnDate(
          rule: 'daily',
          weekdaysBitmask: 0,
          startsOn: start,
          endsOn: end,
          targetDate: DateTime(2026, 11, 1), // on start
        ),
        true,
      );

      expect(
        RecurrenceService.shouldGenerateOnDate(
          rule: 'daily',
          weekdaysBitmask: 0,
          startsOn: start,
          endsOn: end,
          targetDate: DateTime(2026, 11, 3), // inside range
        ),
        true,
      );

      expect(
        RecurrenceService.shouldGenerateOnDate(
          rule: 'daily',
          weekdaysBitmask: 0,
          startsOn: start,
          endsOn: end,
          targetDate: DateTime(2026, 11, 6), // after end
        ),
        false,
      );
    });

    test('Weekly rule generates only on matching weekdays', () {
      // Choose Saturday (6) and Tuesday (2)
      int mask = 0;
      mask = RecurrenceService.setWeekday(mask, DateTime.saturday, true);
      mask = RecurrenceService.setWeekday(mask, DateTime.tuesday, true);

      // 2026-11-07 is Saturday
      expect(
        RecurrenceService.shouldGenerateOnDate(
          rule: 'weekly',
          weekdaysBitmask: mask,
          startsOn: '2026-11-01',
          targetDate: DateTime(2026, 11, 7),
        ),
        true,
      );

      // 2026-11-08 is Sunday -> should be false
      expect(
        RecurrenceService.shouldGenerateOnDate(
          rule: 'weekly',
          weekdaysBitmask: mask,
          startsOn: '2026-11-01',
          targetDate: DateTime(2026, 11, 8),
        ),
        false,
      );

      // 2026-11-10 is Tuesday -> should be true
      expect(
        RecurrenceService.shouldGenerateOnDate(
          rule: 'weekly',
          weekdaysBitmask: mask,
          startsOn: '2026-11-01',
          targetDate: DateTime(2026, 11, 10),
        ),
        true,
      );
    });

    test('Monthly rule matches clamped day in short months', () {
      // Day 31 of month
      final feb28 = DateTime(2025, 2, 28); // last day of Feb
      final feb27 = DateTime(2025, 2, 27);

      expect(
        RecurrenceService.shouldGenerateOnDate(
          rule: 'monthly',
          weekdaysBitmask: 0,
          dayOfMonth: 31,
          startsOn: '2025-01-01',
          targetDate: feb28,
        ),
        true, // clamped to 28
      );

      expect(
        RecurrenceService.shouldGenerateOnDate(
          rule: 'monthly',
          weekdaysBitmask: 0,
          dayOfMonth: 31,
          startsOn: '2025-01-01',
          targetDate: feb27,
        ),
        false,
      );
    });
  });
}
