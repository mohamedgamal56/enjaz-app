import '../../../core/db/app_database.dart';
import '../../../core/utils/numerals_formatter.dart';

class HealthWaitingDuration {
  final int totalDays;
  final int months;
  final int remainingDays;

  const HealthWaitingDuration({
    required this.totalDays,
    required this.months,
    required this.remainingDays,
  });

  String format(bool isArabic, {NumeralsFormat numerals = NumeralsFormat.western}) {
    if (totalDays <= 0) {
      return isArabic ? 'اليوم' : 'Today';
    }
    if (months >= 1) {
      final mStr = NumeralsFormatter.format(months.toString(), numerals);
      return isArabic ? 'محتاج من $mStr شهر' : 'needed for $mStr mo';
    }
    final dStr = NumeralsFormatter.format(totalDays.toString(), numerals);
    return isArabic ? 'محتاج من $dStr يوم' : 'needed for $dStr d';
  }
}

class TreatmentAdherenceMetrics {
  final int totalDays;
  final int takenDays;
  final double adherencePercent;

  const TreatmentAdherenceMetrics({
    required this.totalDays,
    required this.takenDays,
    required this.adherencePercent,
  });

  String formatPercent({NumeralsFormat numerals = NumeralsFormat.western}) {
    final rounded = adherencePercent.round();
    final pStr = NumeralsFormatter.format(rounded.toString(), numerals);
    return '$pStr%';
  }
}

class HealthStatsMetrics {
  final int neededCount;
  final int scheduledCount;
  final int postponedCount;
  final int doneCount;
  final int checkupsDoneThisYear;
  final List<HealthItem> longestWaitingItems;
  final List<HealthItem> upcomingAppointments;
  final double overallTreatmentAdherence;

  const HealthStatsMetrics({
    required this.neededCount,
    required this.scheduledCount,
    required this.postponedCount,
    required this.doneCount,
    required this.checkupsDoneThisYear,
    required this.longestWaitingItems,
    required this.upcomingAppointments,
    required this.overallTreatmentAdherence,
  });
}
