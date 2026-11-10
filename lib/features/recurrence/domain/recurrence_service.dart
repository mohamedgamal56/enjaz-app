import 'dart:math';

import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';

class RecurrenceService {
  const RecurrenceService();

  /// Clamps target day to the maximum available days in the target month/year
  /// e.g. Feb in non-leap year (day 31 -> 28), Apr (day 31 -> 30)
  static int clampDayOfMonth(int year, int month, int targetDay) {
    final lastDay = DateTime(year, month + 1, 0).day;
    return min(targetDay, lastDay);
  }

  /// Checks if a weekday (1 = Monday ... 7 = Sunday) is selected in the bitmask
  static bool isWeekdaySelected(int bitmask, int weekday) {
    if (weekday < 1 || weekday > 7) return false;
    return (bitmask & (1 << weekday)) != 0;
  }

  /// Toggles or sets a weekday bitmask
  static int setWeekday(int bitmask, int weekday, bool selected) {
    if (weekday < 1 || weekday > 7) return bitmask;
    if (selected) {
      return bitmask | (1 << weekday);
    } else {
      return bitmask & ~(1 << weekday);
    }
  }

  /// Evaluates if a given date matches the recurrence rule
  static bool shouldGenerateOnDate({
    required String rule, // 'daily' | 'weekly' | 'monthly'
    required int weekdaysBitmask,
    int? dayOfMonth,
    required String startsOn, // YYYY-MM-DD
    String? endsOn, // YYYY-MM-DD
    required DateTime targetDate,
  }) {
    final dateStr = _formatDate(targetDate);

    // Date must be >= startsOn
    if (dateStr.compareTo(startsOn) < 0) return false;

    // If endsOn is specified, date must be <= endsOn
    if (endsOn != null && endsOn.isNotEmpty && dateStr.compareTo(endsOn) > 0) {
      return false;
    }

    switch (rule) {
      case 'daily':
        return true;

      case 'weekly':
        return isWeekdaySelected(weekdaysBitmask, targetDate.weekday);

      case 'monthly':
        final targetDay = dayOfMonth ?? 1;
        final clamped = clampDayOfMonth(
          targetDate.year,
          targetDate.month,
          targetDay,
        );
        return targetDate.day == clamped;

      default:
        return false;
    }
  }

  /// Resolves candidate dates within a range (inclusive) that match the recurrence rule
  static List<DateTime> getCandidateDatesForRange({
    required Recurrence recurrence,
    required DateTime fromDate,
    required DateTime toDate,
  }) {
    final results = <DateTime>[];
    DateTime current = DateTime(fromDate.year, fromDate.month, fromDate.day);
    final end = DateTime(toDate.year, toDate.month, toDate.day);

    while (!current.isAfter(end)) {
      if (shouldGenerateOnDate(
        rule: recurrence.rule,
        weekdaysBitmask: recurrence.weekdays,
        dayOfMonth: recurrence.dayOfMonth,
        startsOn: recurrence.startsOn,
        endsOn: recurrence.endsOn,
        targetDate: current,
      )) {
        results.add(current);
      }
      current = current.add(const Duration(days: 1));
    }

    return results;
  }

  /// Generates real task instances for today and the next 7 days for all active recurrences
  static Future<int> generateAllUpcomingInstances(AppDatabase db) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final endWindow = today.add(const Duration(days: 7));

    final activeRecurrences = await db.getAllActiveRecurrences();
    if (activeRecurrences.isEmpty) return 0;

    int generatedCount = 0;
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    for (final rec in activeRecurrences) {
      final existingTasks = await db.getTasksForRecurrence(rec.id);
      final existingDates = existingTasks
          .where((t) => t.dueDate != null)
          .map((t) => t.dueDate!)
          .toSet();

      final candidateDates = getCandidateDatesForRange(
        recurrence: rec,
        fromDate: today,
        toDate: endWindow,
      );

      for (final date in candidateDates) {
        final dateStr = _formatDate(date);
        if (!existingDates.contains(dateStr)) {
          final taskId = await db.insertNewTask(
            TasksCompanion.insert(
              title: rec.title,
              kind: Value(rec.kind),
              status: const Value('todo'),
              priority: Value(rec.priority),
              dueDate: Value(dateStr),
              dueTime: rec.dueTime != null
                  ? Value(rec.dueTime)
                  : const Value.absent(),
              notes: rec.notes != null
                  ? Value(rec.notes)
                  : const Value.absent(),
              reminderOffsetMinutes: rec.reminderOffsetMinutes != null
                  ? Value(rec.reminderOffsetMinutes)
                  : const Value.absent(),
              recurrenceId: Value(rec.id),
              createdAt: nowMs,
              updatedAt: nowMs,
            ),
          );
          if (rec.reminderOffsetMinutes != null) {
            await db.insertReminder(
              ownerType: 'task',
              ownerId: taskId,
              kind: await db.getSetting('default_reminder_kind') ?? 'alarm',
              offsetMinutes: rec.reminderOffsetMinutes,
            );
          }
          existingDates.add(dateStr);
          generatedCount++;
        }
      }

      // Update lastGeneratedUntil
      await db.updateRecurrence(
        rec
            .toCompanion(true)
            .copyWith(
              lastGeneratedUntil: Value(_formatDate(endWindow)),
              updatedAt: Value(nowMs),
            ),
      );
    }

    return generatedCount;
  }

  static String _formatDate(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}
