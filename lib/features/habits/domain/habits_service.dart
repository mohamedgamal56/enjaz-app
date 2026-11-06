import 'package:intl/intl.dart';

class HabitProgress {
  final double current;
  final double? target;
  final bool isCompleted;
  final String displayProgress;

  const HabitProgress({
    required this.current,
    this.target,
    required this.isCompleted,
    required this.displayProgress,
  });
}

class SuggestedHabitTemplate {
  final String builtinKey;
  final String nameAr;
  final String nameEn;
  final String type; // count | check | amount | checklist
  final String? unit;
  final double? dailyTarget;
  final String icon;
  final String colorHex;
  final List<String> checklistItems;

  const SuggestedHabitTemplate({
    required this.builtinKey,
    required this.nameAr,
    required this.nameEn,
    required this.type,
    this.unit,
    this.dailyTarget,
    required this.icon,
    required this.colorHex,
    this.checklistItems = const [],
  });
}

class HabitsService {
  const HabitsService();

  /// Default 6 suggested habits per CHANGES.md Spec 4.3
  static const List<SuggestedHabitTemplate> suggestedHabits = [
    SuggestedHabitTemplate(
      builtinKey: 'coffee',
      nameAr: 'قهوة',
      nameEn: 'Coffee',
      type: 'count',
      unit: 'كوب',
      dailyTarget: 3,
      icon: 'local_cafe_rounded',
      colorHex: '#795548',
    ),
    SuggestedHabitTemplate(
      builtinKey: 'five_prayers',
      nameAr: 'الصلوات الخمس',
      nameEn: 'Five daily prayers',
      type: 'checklist',
      icon: 'mosque_rounded',
      colorHex: '#2E7D32',
      checklistItems: ['الفجر', 'الظهر', 'العصر', 'المغرب', 'العشاء'],
    ),
    SuggestedHabitTemplate(
      builtinKey: 'quran',
      nameAr: 'قراءة القرآن',
      nameEn: 'Quran reading',
      type: 'amount',
      unit: 'صفحة',
      dailyTarget: 10,
      icon: 'menu_book_rounded',
      colorHex: '#00796B',
    ),
    SuggestedHabitTemplate(
      builtinKey: 'adhkar',
      nameAr: 'الأذكار',
      nameEn: 'Daily adhkar',
      type: 'checklist',
      icon: 'auto_awesome_rounded',
      colorHex: '#0288D1',
      checklistItems: ['أذكار الصباح', 'أذكار المساء'],
    ),
    SuggestedHabitTemplate(
      builtinKey: 'water',
      nameAr: 'شرب الماء',
      nameEn: 'Water',
      type: 'count',
      unit: 'كوب',
      dailyTarget: 8,
      icon: 'water_drop_rounded',
      colorHex: '#1976D2',
    ),
    SuggestedHabitTemplate(
      builtinKey: 'exercise',
      nameAr: 'رياضة',
      nameEn: 'Exercise',
      type: 'check',
      icon: 'fitness_center_rounded',
      colorHex: '#E64A19',
    ),
  ];

  /// Checks if a date matches the schedule_days bitmask (1..127)
  /// Monday=1, Tuesday=2, Wednesday=4, Thursday=8, Friday=16, Saturday=32, Sunday=64
  static bool isScheduledForDay(int scheduleDays, DateTime date) {
    if (scheduleDays <= 0) return true;
    final bit = 1 << (date.weekday - 1);
    return (scheduleDays & bit) != 0;
  }

  /// Evaluates whether a habit is completed on a specific day
  static bool isDayCompleted({
    required String type,
    required double? dailyTarget,
    required double totalLoggedValue,
    required int totalChecklistItems,
    required int doneChecklistItems,
  }) {
    switch (type) {
      case 'check':
        return totalLoggedValue >= 1.0;
      case 'count':
      case 'amount':
        if (dailyTarget != null && dailyTarget > 0) {
          return totalLoggedValue >= dailyTarget;
        }
        return totalLoggedValue > 0;
      case 'checklist':
        if (totalChecklistItems == 0) return false;
        return doneChecklistItems >= totalChecklistItems;
      default:
        return false;
    }
  }

  /// Calculates habit progress summary for a given day
  static HabitProgress calculateProgress({
    required String type,
    required double? dailyTarget,
    required String? unit,
    required double totalLoggedValue,
    required int totalChecklistItems,
    required int doneChecklistItems,
  }) {
    final completed = isDayCompleted(
      type: type,
      dailyTarget: dailyTarget,
      totalLoggedValue: totalLoggedValue,
      totalChecklistItems: totalChecklistItems,
      doneChecklistItems: doneChecklistItems,
    );

    String display;
    final unitStr = (unit != null && unit.isNotEmpty) ? ' $unit' : '';

    if (type == 'checklist') {
      display = '$doneChecklistItems / $totalChecklistItems';
    } else if (type == 'check') {
      display = completed ? 'تمت' : 'لم تكتمل';
    } else {
      final curVal = totalLoggedValue % 1 == 0 ? totalLoggedValue.toInt().toString() : totalLoggedValue.toStringAsFixed(1);
      if (dailyTarget != null && dailyTarget > 0) {
        final tarVal = dailyTarget % 1 == 0 ? dailyTarget.toInt().toString() : dailyTarget.toStringAsFixed(1);
        display = '$curVal / $tarVal$unitStr';
      } else {
        display = '$curVal$unitStr';
      }
    }

    return HabitProgress(
      current: type == 'checklist' ? doneChecklistItems.toDouble() : totalLoggedValue,
      target: type == 'checklist' ? totalChecklistItems.toDouble() : dailyTarget,
      isCompleted: completed,
      displayProgress: display,
    );
  }

  /// Formats date to local YYYY-MM-DD
  static String formatDate(DateTime dt) {
    return DateFormat('yyyy-MM-dd').format(dt);
  }

  /// Parses date string YYYY-MM-DD
  static DateTime parseDate(String yyyymmdd) {
    return DateFormat('yyyy-MM-dd').parseStrict(yyyymmdd);
  }

  /// Computes current streak and best streak
  /// [completionMap] maps 'YYYY-MM-DD' to bool (completed or not)
  static (int currentStreak, int bestStreak) calculateStreaks({
    required int scheduleDays,
    required Map<String, bool> completionMap,
    required DateTime today,
    int lookbackDays = 365,
  }) {
    final todayClean = DateTime(today.year, today.month, today.day);
    final todayStr = formatDate(todayClean);
    final todayScheduled = isScheduledForDay(scheduleDays, todayClean);
    final todayDone = completionMap[todayStr] ?? false;

    // 1. Current streak
    int current = 0;
    DateTime checkDate = todayClean;

    if (todayScheduled && todayDone) {
      current++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    } else {
      // If today is not done (or not scheduled), check starting from yesterday
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    // Traverse backwards
    while (true) {
      if (isScheduledForDay(scheduleDays, checkDate)) {
        final dStr = formatDate(checkDate);
        if (completionMap[dStr] == true) {
          current++;
          checkDate = checkDate.subtract(const Duration(days: 1));
        } else {
          break;
        }
      } else {
        // Skip unscheduled days without breaking streak
        checkDate = checkDate.subtract(const Duration(days: 1));
      }

      if (todayClean.difference(checkDate).inDays > lookbackDays) break;
    }

    // 2. Best streak over history
    int best = 0;
    int running = 0;

    // Check history in chronological order
    final startHistory = todayClean.subtract(Duration(days: lookbackDays));
    DateTime cur = startHistory;

    while (!cur.isAfter(todayClean)) {
      if (isScheduledForDay(scheduleDays, cur)) {
        final curStr = formatDate(cur);
        if (completionMap[curStr] == true) {
          running++;
          if (running > best) best = running;
        } else {
          running = 0;
        }
      }
      cur = cur.add(const Duration(days: 1));
    }

    if (current > best) best = current;

    return (current, best);
  }

  /// Calculates completion rate in date range
  static double calculateCompletionRate({
    required int scheduleDays,
    required Map<String, bool> completionMap,
    required DateTime start,
    required DateTime end,
  }) {
    int totalScheduled = 0;
    int completed = 0;

    DateTime cur = DateTime(start.year, start.month, start.day);
    final endClean = DateTime(end.year, end.month, end.day);

    while (!cur.isAfter(endClean)) {
      if (isScheduledForDay(scheduleDays, cur)) {
        totalScheduled++;
        final dStr = formatDate(cur);
        if (completionMap[dStr] == true) {
          completed++;
        }
      }
      cur = cur.add(const Duration(days: 1));
    }

    if (totalScheduled == 0) return 0.0;
    return (completed / totalScheduled) * 100.0;
  }

  /// Counts missed days in range (past scheduled days that were not completed)
  static int countMissedDays({
    required int scheduleDays,
    required Map<String, bool> completionMap,
    required DateTime start,
    required DateTime end,
  }) {
    int missed = 0;
    DateTime cur = DateTime(start.year, start.month, start.day);
    final endClean = DateTime(end.year, end.month, end.day);
    final now = DateTime.now();
    final todayClean = DateTime(now.year, now.month, now.day);

    while (!cur.isAfter(endClean)) {
      // Only count past days as missed
      if (cur.isBefore(todayClean) && isScheduledForDay(scheduleDays, cur)) {
        final dStr = formatDate(cur);
        if (completionMap[dStr] != true) {
          missed++;
        }
      }
      cur = cur.add(const Duration(days: 1));
    }

    return missed;
  }
}
