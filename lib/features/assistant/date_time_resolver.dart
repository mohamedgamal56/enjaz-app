import 'package:intl/intl.dart';
import 'text_normalizer.dart';
import 'number_words_ar.dart';

/// Resolved date result from [DateTimeResolver].
class DateResolution {
  final DateTime date;
  final String dateStr; // 'yyyy-MM-dd'
  final bool isPast;
  final bool isPeriod;
  final DateTime? periodStart;
  final DateTime? periodEnd;

  const DateResolution({
    required this.date,
    required this.dateStr,
    this.isPast = false,
    this.isPeriod = false,
    this.periodStart,
    this.periodEnd,
  });

  @override
  String toString() => 'DateResolution(dateStr: $dateStr, isPast: $isPast, isPeriod: $isPeriod)';
}

/// Resolved time result from [DateTimeResolver].
class TimeResolution {
  final int hour; // 0..23
  final int minute; // 0..59
  final String timeStr; // 'HH:mm'

  const TimeResolution({
    required this.hour,
    required this.minute,
    required this.timeStr,
  });

  @override
  String toString() => 'TimeResolution(timeStr: $timeStr)';
}

/// Resolved date range for periods (e.g. "الأسبوع ده", "الشهر اللي فات").
class PeriodResolution {
  final DateTime start;
  final DateTime end;
  final String startStr; // 'yyyy-MM-dd'
  final String endStr; // 'yyyy-MM-dd'

  const PeriodResolution({
    required this.start,
    required this.end,
    required this.startStr,
    required this.endStr,
  });

  @override
  String toString() => 'PeriodResolution($startStr to $endStr)';
}

/// Pure Dart Resolver for Arabic dates and times (VOICE.md Section 4.4).
class DateTimeResolver {
  final DateTime Function() _nowProvider;
  final int weekStartWeekday; // DateTime.saturday (6) by default in Egypt/Settings

  const DateTimeResolver({
    DateTime Function()? nowProvider,
    this.weekStartWeekday = DateTime.saturday,
  }) : _nowProvider = nowProvider ?? _defaultNow;

  static DateTime _defaultNow() => DateTime.now();

  DateTime get now => _nowProvider();

  static const Map<String, int> _weekdayMap = {
    'السبت': DateTime.saturday,
    'سبت': DateTime.saturday,
    'الاحد': DateTime.sunday,
    'الأحد': DateTime.sunday,
    'حد': DateTime.sunday,
    'الاتنين': DateTime.monday,
    'الإثنين': DateTime.monday,
    'اثنين': DateTime.monday,
    'تنين': DateTime.monday,
    'التلات': DateTime.tuesday,
    'الثلاثاء': DateTime.tuesday,
    'تلات': DateTime.tuesday,
    'الاربع': DateTime.wednesday,
    'الأربعاء': DateTime.wednesday,
    'اربع': DateTime.wednesday,
    'الخميس': DateTime.thursday,
    'خميس': DateTime.thursday,
    'الجمعه': DateTime.friday,
    'الجمعة': DateTime.friday,
    'جمعه': DateTime.friday,
  };

  static const Map<String, int> _arabicMonths = {
    'يناير': 1,
    'فبراير': 2,
    'مارس': 3,
    'ابريل': 4,
    'أبريل': 4,
    'مايو': 5,
    'يونيو': 6,
    'يوليو': 7,
    'اغسطس': 8,
    'أغسطس': 8,
    'سبتمبر': 9,
    'اكتوبر': 10,
    'أكتوبر': 10,
    'نوفمبر': 11,
    'ديسمبر': 12,
  };

  /// Resolves a date from text. If no date is found, returns null.
  DateResolution? resolveDate(String text) {
    if (text.isEmpty) return null;
    final norm = TextNormalizer.normalize(text);
    final nowDate = DateTime(now.year, now.month, now.day);

    // 1. Relative day words
    if (norm.contains('بعد بكره') || norm.contains('بعد بكرة')) {
      final target = nowDate.add(const Duration(days: 2));
      return _makeDateRes(target, nowDate);
    }
    if (norm.contains('بعد يومين')) {
      final target = nowDate.add(const Duration(days: 2));
      return _makeDateRes(target, nowDate);
    }
    // "بعد N يوم / أيام" (e.g. "بعد 3 ايام", "بعد 5 ايام")
    final afterNDaysMatch = RegExp(r'بعد\s*(\d+)\s*(?:يوم|ايام|أيام)').firstMatch(norm);
    if (afterNDaysMatch != null) {
      final n = int.parse(afterNDaysMatch.group(1)!);
      final target = nowDate.add(Duration(days: n));
      return _makeDateRes(target, nowDate);
    }
    // "بعد N يوم / أيام" with words (e.g. "بعد تلات ايام", "بعد تلاتة ايام")
    final afterWordDaysMatch = RegExp(r'بعد\s*([أ-ي]+)\s*(?:يوم|ايام|أيام)').firstMatch(norm);
    if (afterWordDaysMatch != null) {
      final word = afterWordDaysMatch.group(1)!;
      final n = NumberWordsAr.parseNumber(word);
      if (n != null && n > 0) {
        final target = nowDate.add(Duration(days: n.toInt()));
        return _makeDateRes(target, nowDate);
      }
    }
    if (norm.contains('بعد اسبوع') || norm.contains('بعد أسبوع')) {
      final target = nowDate.add(const Duration(days: 7));
      return _makeDateRes(target, nowDate);
    }
    if (norm.contains('النهارده') || norm.contains('النهاردة') || norm.contains('اليوم')) {
      return _makeDateRes(nowDate, nowDate);
    }
    if (norm.contains('بكرة') || norm.contains('بكره') || norm.contains('غدا')) {
      final target = nowDate.add(const Duration(days: 1));
      return _makeDateRes(target, nowDate);
    }
    if (norm.contains('اول امبارح') || norm.contains('أول امبارح')) {
      final target = nowDate.subtract(const Duration(days: 2));
      return _makeDateRes(target, nowDate);
    }
    if (norm.contains('امبارح') || norm.contains('أمس')) {
      final target = nowDate.subtract(const Duration(days: 1));
      return _makeDateRes(target, nowDate);
    }

    // 2. Explicit numeric date: e.g. "12/9/2026", "يوم 12/9", "12/9"
    final slashDateMatch = RegExp(r'(?:يوم\s*)?(\d{1,2})\/(\d{1,2})(?:\/(\d{4}))?').firstMatch(norm);
    if (slashDateMatch != null) {
      final d = int.parse(slashDateMatch.group(1)!);
      final m = int.parse(slashDateMatch.group(2)!);
      final y = slashDateMatch.group(3) != null ? int.parse(slashDateMatch.group(3)!) : nowDate.year;
      final target = DateTime(y, m, d);
      return _makeDateRes(target, nowDate);
    }

    // 3. Explicit named date: e.g. "12 سبتمبر 2026", "يوم 12 سبتمبر"
    for (final entry in _arabicMonths.entries) {
      final pattern = RegExp('(?:يوم\\s*)?(\\d{1,2})\\s*${entry.key}(?:\\s*(\\d{4}))?');
      final match = pattern.firstMatch(norm);
      if (match != null) {
        final d = int.parse(match.group(1)!);
        final m = entry.value;
        final y = match.group(2) != null ? int.parse(match.group(2)!) : nowDate.year;
        final target = DateTime(y, m, d);
        return _makeDateRes(target, nowDate);
      }
    }

    // 4. Weekdays (السبت..الجمعة):
    // Next upcoming, today excluded (e.g. today Saturday -> next Saturday = 7 days ahead)
    for (final entry in _weekdayMap.entries) {
      // Check if weekday is mentioned
      final reg = RegExp('(?:يوم\\s*)?${entry.key}(?:\\s*(اللي\\s*فات|الماضي|الجاي|القادم))?');
      final match = reg.firstMatch(norm);
      if (match != null) {
        final targetWeekday = entry.value;
        final modifier = match.group(1);
        final isPastModifier = modifier != null && (modifier.contains('فات') || modifier.contains('ماضي'));

        DateTime target;
        if (isPastModifier) {
          // Most recent past occurrence (strictly before today)
          var diff = nowDate.weekday - targetWeekday;
          if (diff <= 0) diff += 7;
          target = nowDate.subtract(Duration(days: diff));
        } else {
          // Next upcoming occurrence (strictly after today, today excluded per Spec 4.4)
          var diff = targetWeekday - nowDate.weekday;
          if (diff <= 0) diff += 7;
          target = nowDate.add(Duration(days: diff));
        }
        return _makeDateRes(target, nowDate);
      }
    }

    // 5. Periods in command: "الاسبوع الجاي" / "الشهر الجاي"
    if (norm.contains('الاسبوع الجاي') || norm.contains('الأسبوع الجاي')) {
      final period = resolvePeriod('الاسبوع الجاي');
      if (period != null) {
        return DateResolution(
          date: period.start,
          dateStr: period.startStr,
          isPeriod: true,
          periodStart: period.start,
          periodEnd: period.end,
        );
      }
    }

    return null;
  }

  /// Resolves date periods for questions and range views (VOICE.md Section 4.4).
  PeriodResolution? resolvePeriod(String text) {
    if (text.isEmpty) return null;
    final norm = TextNormalizer.normalize(text);
    final nowDate = DateTime(now.year, now.month, now.day);

    // Week calculations (Week starts on weekStartWeekday, default Saturday in Egypt)
    // Offset from start of week:
    // Saturday = 6 in Dart. If weekStart = Saturday:
    // If today is Saturday (6), dayOffset = 0.
    // If today is Sunday (7), dayOffset = 1.
    // In general: (nowDate.weekday - weekStartWeekday) % 7.
    int getWeekOffset(DateTime dt) {
      return (dt.weekday - weekStartWeekday + 7) % 7;
    }

    if (norm.contains('الاسبوع ده') || norm.contains('الأسبوع ده') || norm.contains('هذا الاسبوع')) {
      final offset = getWeekOffset(nowDate);
      final start = nowDate.subtract(Duration(days: offset));
      final end = start.add(const Duration(days: 6));
      return _makePeriodRes(start, end);
    }

    if (norm.contains('الاسبوع اللي فات') || norm.contains('الأسبوع اللي فات') || norm.contains('الاسبوع الماضي')) {
      final offset = getWeekOffset(nowDate);
      final thisWeekStart = nowDate.subtract(Duration(days: offset));
      final lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));
      final lastWeekEnd = lastWeekStart.add(const Duration(days: 6));
      return _makePeriodRes(lastWeekStart, lastWeekEnd);
    }

    if (norm.contains('الاسبوع الجاي') || norm.contains('الأسبوع الجاي') || norm.contains('الاسبوع القادم')) {
      final offset = getWeekOffset(nowDate);
      final thisWeekStart = nowDate.subtract(Duration(days: offset));
      final nextWeekStart = thisWeekStart.add(const Duration(days: 7));
      final nextWeekEnd = nextWeekStart.add(const Duration(days: 6));
      return _makePeriodRes(nextWeekStart, nextWeekEnd);
    }

    // Month calculations
    if (norm.contains('الشهر ده') || norm.contains('هذا الشهر')) {
      final start = DateTime(nowDate.year, nowDate.month, 1);
      final daysInMonth = DateTime(nowDate.year, nowDate.month + 1, 0).day;
      final end = DateTime(nowDate.year, nowDate.month, daysInMonth);
      return _makePeriodRes(start, end);
    }

    if (norm.contains('الشهر اللي فات') || norm.contains('الشهر الماضي')) {
      final prevMonthYear = nowDate.month == 1 ? nowDate.year - 1 : nowDate.year;
      final prevMonth = nowDate.month == 1 ? 12 : nowDate.month - 1;
      final start = DateTime(prevMonthYear, prevMonth, 1);
      final daysInMonth = DateTime(prevMonthYear, prevMonth + 1, 0).day;
      final end = DateTime(prevMonthYear, prevMonth, daysInMonth);
      return _makePeriodRes(start, end);
    }

    if (norm.contains('الشهر الجاي') || norm.contains('الشهر القادم')) {
      final nextMonthYear = nowDate.month == 12 ? nowDate.year + 1 : nowDate.year;
      final nextMonth = nowDate.month == 12 ? 1 : nowDate.month + 1;
      final start = DateTime(nextMonthYear, nextMonth, 1);
      final daysInMonth = DateTime(nextMonthYear, nextMonth + 1, 0).day;
      final end = DateTime(nextMonthYear, nextMonth, daysInMonth);
      return _makePeriodRes(start, end);
    }

    // Year calculations
    if (norm.contains('السنة دي') || norm.contains('هذه السنة')) {
      final start = DateTime(nowDate.year, 1, 1);
      final end = DateTime(nowDate.year, 12, 31);
      return _makePeriodRes(start, end);
    }

    if (norm.contains('السنة اللي فاتت') || norm.contains('السنة الماضية')) {
      final start = DateTime(nowDate.year - 1, 1, 1);
      final end = DateTime(nowDate.year - 1, 12, 31);
      return _makePeriodRes(start, end);
    }

    return null;
  }

  /// Resolves clock time from text (VOICE.md Section 4.4).
  /// Rules:
  /// - Exact times: "5:30", "17:00"
  /// - Markers: الصبح / صباحاً = AM, العصر / بعد الضهر / مساءً / بالليل = PM, الضهر = 12:00
  /// - Unmarked rule: 1..6 = PM (13..18), 7..11 = AM (07..11), 12 = 12:00
  /// - Word times: "ستة وربع", "الساعة 5", "5 العصر", "8 بالليل"
  TimeResolution? resolveTime(String text) {
    if (text.isEmpty) return null;
    final norm = TextNormalizer.normalize(text);

    // 1. Explicit 24-hour or colon format (e.g. "17:00", "09:00", "5:30")
    final colonMatch = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(norm);
    if (colonMatch != null) {
      var h = int.parse(colonMatch.group(1)!);
      final m = int.parse(colonMatch.group(2)!);
      final hasAmMarker = norm.contains('الصبح') || norm.contains('صباحا') || norm.contains('صباح');
      final hasPmMarker = norm.contains('بالليل') || norm.contains('مساء') || norm.contains('العصر') || norm.contains('بعد الضهر');

      if (hasPmMarker && h < 12) h += 12;
      if (hasAmMarker && h == 12) h = 0;

      return TimeResolution(hour: h, minute: m, timeStr: _formatTime(h, m));
    }

    // 2. Keyword "الضهر" alone or with "الساعة 12"
    if (norm.contains('الضهر') && !norm.contains('بعد الضهر') && !RegExp(r'\d+').hasMatch(norm)) {
      return const TimeResolution(hour: 12, minute: 0, timeStr: '12:00');
    }

    // 3. Patterns like "الساعة 5", "5 العصر", "الساعة 9 الصبح", "8 بالليل"
    // Also with fractions: "الساعة 5 ونص", "ستة وربع", "خمسة الا ربع", "خمسة الا تلت"
    final timeWordReg = RegExp(
      r'(?:الساعة\s*)?(\d+|واحد|اتنين|تلاته|تلاتة|اربعه|اربعة|خمسه|خمسة|سته|ستة|سبعه|سبعة|تمانيه|تمانية|تمنيه|تمنية|تسعه|تسعة|عشره|عشرة|حداشر|اتناشر)\s*(?:و\s*(نص|ربع|تلت)|الا\s*(ربع|تلت))?\s*(الصبح|صباحا|صباحاً|العصر|الظهر|الضهر|بعد الضهر|المغرب|العشا|بالليل|مساء|مساءً)?',
    );

    for (final match in timeWordReg.allMatches(norm)) {
      final hourStr = match.group(1);
      final fractionAdd = match.group(2); // ونص, ورابع, وتلت
      final fractionSub = match.group(3); // الا ربع, الا تلت
      final marker = match.group(4);

      if (hourStr == null) continue;

      double? hourVal = double.tryParse(hourStr);
      hourVal ??= NumberWordsAr.parseNumber(hourStr);
      if (hourVal == null || hourVal < 1 || hourVal > 12) continue;

      int h = hourVal.toInt();
      int m = 0;

      // Handle fractions
      if (fractionAdd != null) {
        if (fractionAdd == 'نص') m = 30;
        if (fractionAdd == 'ربع') m = 15;
        if (fractionAdd == 'تلت') m = 20;
      } else if (fractionSub != null) {
        if (fractionSub == 'ربع') {
          m = 45;
          h = (h - 1) <= 0 ? 12 : (h - 1);
        } else if (fractionSub == 'تلت') {
          m = 40;
          h = (h - 1) <= 0 ? 12 : (h - 1);
        }
      }

      // Determine AM / PM
      if (marker != null) {
        if (marker.contains('الصبح') || marker.contains('صباح')) {
          if (h == 12) h = 0; // 12 AM
        } else if (marker.contains('العصر') ||
            marker.contains('بعد الضهر') ||
            marker.contains('بالليل') ||
            marker.contains('المغرب') ||
            marker.contains('العشا') ||
            marker.contains('مساء')) {
          if (h < 12) h += 12; // PM
        } else if (marker.contains('الضهر') || marker.contains('الظهر')) {
          if (h != 12) h = 12; // Noon
        }
      } else {
        // Default rule from Spec Section 4.4:
        // "With no marker: 1 to 6 = PM, 7 to 11 = AM, 12 = noon."
        if (h >= 1 && h <= 6) {
          h += 12;
        } else if (h == 12) {
          h = 12;
        }
        // 7 to 11 stay AM (07 to 11)
      }

      return TimeResolution(hour: h, minute: m, timeStr: _formatTime(h, m));
    }

    return null;
  }

  /// Resolves reminder offset minutes from phrases like "قبلها بساعة", "قبلها بنص ساعة" (VOICE.md Section 4.4).
  int? resolveReminderOffsetMinutes(String text) {
    if (text.isEmpty) return null;
    final norm = TextNormalizer.normalize(text);

    if (norm.contains('قبلها بساعه') || norm.contains('قبلها بساعة')) {
      return 60;
    }
    if (norm.contains('قبلها بنص ساعه') || norm.contains('قبلها بنص ساعة') || norm.contains('قبلها بنصف ساعة')) {
      return 30;
    }
    if (norm.contains('قبلها بربع ساعه') || norm.contains('قبلها بربع ساعة')) {
      return 15;
    }
    if (norm.contains('قبلها بساعتين')) {
      return 120;
    }
    if (norm.contains('قبلها بيوم')) {
      return 1440; // 24 hours
    }
    if (norm.contains('قبلها بيومين')) {
      return 2880; // 48 hours
    }

    // Match "قبلها بـ X دقيقة/ساعة"
    final minMatch = RegExp(r'قبلها\s*بـ?\s*(\d+)\s*دقيق').firstMatch(norm);
    if (minMatch != null) {
      return int.tryParse(minMatch.group(1)!);
    }
    final hourMatch = RegExp(r'قبلها\s*بـ?\s*(\d+)\s*ساع').firstMatch(norm);
    if (hourMatch != null) {
      final hours = int.tryParse(hourMatch.group(1)!);
      if (hours != null) return hours * 60;
    }

    return null;
  }

  DateResolution _makeDateRes(DateTime target, DateTime nowDate) {
    final yyyymmdd = DateFormat('yyyy-MM-dd').format(target);
    final isPast = target.isBefore(nowDate);
    return DateResolution(
      date: target,
      dateStr: yyyymmdd,
      isPast: isPast,
    );
  }

  PeriodResolution _makePeriodRes(DateTime start, DateTime end) {
    return PeriodResolution(
      start: start,
      end: end,
      startStr: DateFormat('yyyy-MM-dd').format(start),
      endStr: DateFormat('yyyy-MM-dd').format(end),
    );
  }

  String _formatTime(int hour, int minute) {
    final hStr = hour.toString().padLeft(2, '0');
    final mStr = minute.toString().padLeft(2, '0');
    return '$hStr:$mStr';
  }
}
