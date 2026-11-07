import 'package:flutter_test/flutter_test.dart';
import 'package:enjaz/features/assistant/date_time_resolver.dart';

void main() {
  group('DateTimeResolver Tests with Fixed Now (VOICE.md Section 4.4 & 10.2)', () {
    // Fixed reference now: Saturday 7 Nov 2026 10:00 AM (Cairo time zone, week starts Saturday)
    final fixedNow = DateTime(2026, 11, 7, 10, 0);
    final resolver = DateTimeResolver(
      nowProvider: () => fixedNow,
      weekStartWeekday: DateTime.saturday,
    );

    test('1. Day words match expected dates from Section 4.4', () {
      // النهارده -> 2026-11-07
      expect(resolver.resolveDate('النهارده')?.dateStr, '2026-11-07');
      expect(resolver.resolveDate('النهاردة')?.dateStr, '2026-11-07');

      // بكرة -> 2026-11-08 (Sunday)
      expect(resolver.resolveDate('بكرة')?.dateStr, '2026-11-08');
      expect(resolver.resolveDate('بكره')?.dateStr, '2026-11-08');

      // بعد بكرة -> 2026-11-09
      expect(resolver.resolveDate('بعد بكرة')?.dateStr, '2026-11-09');
      expect(resolver.resolveDate('بعد بكره')?.dateStr, '2026-11-09');

      // بعد يومين -> 2026-11-09
      expect(resolver.resolveDate('بعد يومين')?.dateStr, '2026-11-09');

      // بعد 3 أيام -> 2026-11-10
      expect(resolver.resolveDate('بعد 3 أيام')?.dateStr, '2026-11-10');
      expect(resolver.resolveDate('بعد تلات ايام')?.dateStr, '2026-11-10');

      // امبارح -> 2026-11-06
      expect(resolver.resolveDate('امبارح')?.dateStr, '2026-11-06');

      // أول امبارح -> 2026-11-05
      expect(resolver.resolveDate('أول امبارح')?.dateStr, '2026-11-05');
      expect(resolver.resolveDate('اول امبارح')?.dateStr, '2026-11-05');
    });

    test('2. Weekday names match expected dates (today excluded per Spec 4.4)', () {
      // الخميس -> 2026-11-12
      expect(resolver.resolveDate('الخميس')?.dateStr, '2026-11-12');
      expect(resolver.resolveDate('يوم الخميس')?.dateStr, '2026-11-12');

      // السبت -> 2026-11-14 (today excluded)
      expect(resolver.resolveDate('السبت')?.dateStr, '2026-11-14');
      expect(resolver.resolveDate('السبت الجاي')?.dateStr, '2026-11-14');

      // الجمعه اللي فاتت -> 2026-11-06
      expect(resolver.resolveDate('الجمعة اللي فات')?.dateStr, '2026-11-06');
    });

    test('3. Explicit dates (day/month) match expected values', () {
      // يوم 12/9 -> 2026-09-12 (day/month)
      expect(resolver.resolveDate('يوم 12/9')?.dateStr, '2026-09-12');
      expect(resolver.resolveDate('12/9/2026')?.dateStr, '2026-09-12');
      expect(resolver.resolveDate('12 سبتمبر')?.dateStr, '2026-09-12');
      expect(resolver.resolveDate('يوم 12 سبتمبر 2026')?.dateStr, '2026-09-12');
    });

    test('4. Periods match Section 4.4 date ranges', () {
      // الأسبوع ده -> 2026-11-07 to 2026-11-13 (week starts Saturday)
      final thisWeek = resolver.resolvePeriod('الأسبوع ده');
      expect(thisWeek?.startStr, '2026-11-07');
      expect(thisWeek?.endStr, '2026-11-13');

      // الأسبوع اللي فات -> 2026-10-31 to 2026-11-06
      final lastWeek = resolver.resolvePeriod('الأسبوع اللي فات');
      expect(lastWeek?.startStr, '2026-10-31');
      expect(lastWeek?.endStr, '2026-11-06');

      // الشهر ده -> 2026-11-01 to 2026-11-30
      final thisMonth = resolver.resolvePeriod('الشهر ده');
      expect(thisMonth?.startStr, '2026-11-01');
      expect(thisMonth?.endStr, '2026-11-30');

      // الشهر اللي فات -> 2026-10-01 to 2026-10-31
      final lastMonth = resolver.resolvePeriod('الشهر اللي فات');
      expect(lastMonth?.startStr, '2026-10-01');
      expect(lastMonth?.endStr, '2026-10-31');

      // السنة دي -> 2026-01-01 to 2026-12-31
      final thisYear = resolver.resolvePeriod('السنة دي');
      expect(thisYear?.startStr, '2026-01-01');
      expect(thisYear?.endStr, '2026-12-31');
    });

    test('5. Clock times match Section 4.4 & 10.2 specifications', () {
      // الساعة 9 -> 09:00 (7..11 default AM)
      expect(resolver.resolveTime('الساعة 9')?.timeStr, '09:00');
      expect(resolver.resolveTime('9 الصبح')?.timeStr, '09:00');

      // الساعة 5 -> 17:00 (1..6 default PM)
      expect(resolver.resolveTime('الساعة 5')?.timeStr, '17:00');
      expect(resolver.resolveTime('5 العصر')?.timeStr, '17:00');

      // 8 بالليل -> 20:00
      expect(resolver.resolveTime('8 بالليل')?.timeStr, '20:00');

      // الضهر -> 12:00
      expect(resolver.resolveTime('الضهر')?.timeStr, '12:00');

      // ستة وربع -> 18:15 (6 PM default + 15 min)
      expect(resolver.resolveTime('ستة وربع')?.timeStr, '18:15');

      // 5:30 -> 17:30 with PM context or default
      expect(resolver.resolveTime('5:30')?.timeStr, '05:30');
      expect(resolver.resolveTime('5:30 العصر')?.timeStr, '17:30');
    });

    test('6. Reminder offsets match Section 4.4', () {
      expect(resolver.resolveReminderOffsetMinutes('فكرني قبلها بساعة'), 60);
      expect(resolver.resolveReminderOffsetMinutes('قبلها بنص ساعة'), 30);
      expect(resolver.resolveReminderOffsetMinutes('قبلها بيوم'), 1440);
    });
  });
}
