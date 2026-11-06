import '../../../core/db/app_database.dart';
import 'health_models.dart';

class HealthService {
  const HealthService();

  /// Calculate waiting duration from neededSince date to today
  HealthWaitingDuration calculateWaitingDuration(String neededSinceDate, [DateTime? today]) {
    final now = today ?? DateTime.now();
    final parts = neededSinceDate.split('-');
    if (parts.length != 3) {
      return const HealthWaitingDuration(totalDays: 0, months: 0, remainingDays: 0);
    }
    final year = int.tryParse(parts[0]) ?? now.year;
    final month = int.tryParse(parts[1]) ?? now.month;
    final day = int.tryParse(parts[2]) ?? now.day;

    final neededDate = DateTime(year, month, day);
    final todayClean = DateTime(now.year, now.month, now.day);

    final diff = todayClean.difference(neededDate).inDays;
    if (diff <= 0) {
      return const HealthWaitingDuration(totalDays: 0, months: 0, remainingDays: 0);
    }

    final months = diff ~/ 30;
    final remainingDays = diff % 30;

    return HealthWaitingDuration(
      totalDays: diff,
      months: months,
      remainingDays: remainingDays,
    );
  }

  /// Calculate adherence metrics for a treatment
  TreatmentAdherenceMetrics calculateTreatmentAdherence({
    required String startDate,
    String? endDate,
    required List<TreatmentCheck> checks,
    DateTime? today,
  }) {
    final now = today ?? DateTime.now();
    final startParts = startDate.split('-');
    if (startParts.length != 3) {
      return const TreatmentAdherenceMetrics(totalDays: 0, takenDays: 0, adherencePercent: 0.0);
    }
    final startYear = int.tryParse(startParts[0]) ?? now.year;
    final startMonth = int.tryParse(startParts[1]) ?? now.month;
    final startDay = int.tryParse(startParts[2]) ?? now.day;
    final start = DateTime(startYear, startMonth, startDay);

    DateTime end = DateTime(now.year, now.month, now.day);
    if (endDate != null && endDate.isNotEmpty) {
      final endParts = endDate.split('-');
      if (endParts.length == 3) {
        final endYear = int.tryParse(endParts[0]) ?? now.year;
        final endMonth = int.tryParse(endParts[1]) ?? now.month;
        final endDay = int.tryParse(endParts[2]) ?? now.day;
        final parsedEnd = DateTime(endYear, endMonth, endDay);
        if (parsedEnd.isBefore(end)) {
          end = parsedEnd;
        }
      }
    }

    if (end.isBefore(start)) {
      return const TreatmentAdherenceMetrics(totalDays: 0, takenDays: 0, adherencePercent: 0.0);
    }

    final totalDays = end.difference(start).inDays + 1;
    if (totalDays <= 0) {
      return const TreatmentAdherenceMetrics(totalDays: 0, takenDays: 0, adherencePercent: 0.0);
    }

    // Taken days: count unique check dates where taken is true
    final takenDates = checks.where((c) => c.taken).map((c) => c.checkDate).toSet();
    final takenCount = takenDates.length;

    final percent = (takenCount / totalDays) * 100.0;
    final clampedPercent = percent > 100.0 ? 100.0 : percent;

    return TreatmentAdherenceMetrics(
      totalDays: totalDays,
      takenDays: takenCount,
      adherencePercent: clampedPercent,
    );
  }

  /// Calculate next recurring date by adding months to completion date
  DateTime getNextRecurringDate(DateTime doneDate, int repeatEveryMonths) {
    var newYear = doneDate.year;
    var newMonth = doneDate.month + repeatEveryMonths;
    while (newMonth > 12) {
      newYear += 1;
      newMonth -= 12;
    }
    // Handle days overflow (e.g. Feb 30 -> Feb 28)
    final daysInMonth = DateTime(newYear, newMonth + 1, 0).day;
    final newDay = doneDate.day > daysInMonth ? daysInMonth : doneDate.day;
    return DateTime(newYear, newMonth, newDay);
  }

  /// Compute high-level stats metrics for Health tab
  HealthStatsMetrics computeHealthMetrics({
    required List<HealthItem> items,
    required List<Treatment> treatments,
    required List<TreatmentCheck> allChecks,
    DateTime? today,
  }) {
    final now = today ?? DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;
    final currentYear = now.year;

    int needed = 0;
    int scheduled = 0;
    int postponed = 0;
    int done = 0;
    int checkupsDoneThisYear = 0;

    for (final item in items) {
      if (item.deletedAt != null) continue;
      switch (item.status) {
        case 'needed':
          needed++;
          break;
        case 'scheduled':
          scheduled++;
          break;
        case 'postponed':
          postponed++;
          break;
        case 'done':
          done++;
          if (item.doneAt != null) {
            final doneDate = DateTime.fromMillisecondsSinceEpoch(item.doneAt!);
            if (doneDate.year == currentYear) {
              checkupsDoneThisYear++;
            }
          }
          break;
      }
    }

    // Longest waiting items (needed or postponed), sorted by neededSince asc
    final activeWaiting = items
        .where((i) => i.deletedAt == null && (i.status == 'needed' || i.status == 'postponed'))
        .toList()
      ..sort((a, b) => a.neededSince.compareTo(b.neededSince));

    final longestWaiting = activeWaiting.take(5).toList();

    // Upcoming appointments (status scheduled and scheduledAt >= nowMs)
    final upcoming = items
        .where((i) =>
            i.deletedAt == null &&
            i.status == 'scheduled' &&
            i.scheduledAt != null &&
            i.scheduledAt! >= nowMs - (1000 * 60 * 60 * 2)) // within last 2 hours or in future
        .toList()
      ..sort((a, b) => (a.scheduledAt ?? 0).compareTo(b.scheduledAt ?? 0));

    final upcomingAppointments = upcoming.take(5).toList();

    // Overall adherence across all treatments
    double totalAdherence = 0.0;
    int countedTreatments = 0;

    for (final t in treatments) {
      if (t.deletedAt != null) continue;
      final checksForT = allChecks.where((c) => c.treatmentId == t.id).toList();
      final metrics = calculateTreatmentAdherence(
        startDate: t.startDate,
        endDate: t.endDate,
        checks: checksForT,
        today: now,
      );
      if (metrics.totalDays > 0) {
        totalAdherence += metrics.adherencePercent;
        countedTreatments++;
      }
    }

    final avgAdherence = countedTreatments > 0 ? (totalAdherence / countedTreatments) : 0.0;

    return HealthStatsMetrics(
      neededCount: needed,
      scheduledCount: scheduled,
      postponedCount: postponed,
      doneCount: done,
      checkupsDoneThisYear: checkupsDoneThisYear,
      longestWaitingItems: longestWaiting,
      upcomingAppointments: upcomingAppointments,
      overallTreatmentAdherence: avgAdherence,
    );
  }
}
