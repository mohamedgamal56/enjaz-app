import 'package:flutter_test/flutter_test.dart';
import 'package:enjaz/features/habits/domain/habits_service.dart';

void main() {
  group('HabitsService Logic & Rules Tests (Round 4 Spec 4.5)', () {
    test('1. Schedule days bitmask evaluation works accurately for all presets', () {
      final monday = DateTime(2026, 11, 2); // Monday (weekday=1)
      final friday = DateTime(2026, 11, 6); // Friday (weekday=5)
      final saturday = DateTime(2026, 11, 7); // Saturday (weekday=6)
      final sunday = DateTime(2026, 11, 8); // Sunday (weekday=7)

      // 127 = every day
      expect(HabitsService.isScheduledForDay(127, monday), isTrue);
      expect(HabitsService.isScheduledForDay(127, friday), isTrue);
      expect(HabitsService.isScheduledForDay(127, saturday), isTrue);
      expect(HabitsService.isScheduledForDay(127, sunday), isTrue);

      // 31 = workdays (Mon-Fri)
      expect(HabitsService.isScheduledForDay(31, monday), isTrue);
      expect(HabitsService.isScheduledForDay(31, friday), isTrue);
      expect(HabitsService.isScheduledForDay(31, saturday), isFalse);
      expect(HabitsService.isScheduledForDay(31, sunday), isFalse);

      // 96 = weekends (Sat-Sun)
      expect(HabitsService.isScheduledForDay(96, monday), isFalse);
      expect(HabitsService.isScheduledForDay(96, saturday), isTrue);
      expect(HabitsService.isScheduledForDay(96, sunday), isTrue);
    });

    test('2. Check habit completion: logged = done, unlogged = not done', () {
      expect(
        HabitsService.isDayCompleted(
          type: 'check',
          dailyTarget: null,
          totalLoggedValue: 1.0,
          totalChecklistItems: 0,
          doneChecklistItems: 0,
        ),
        isTrue,
      );

      expect(
        HabitsService.isDayCompleted(
          type: 'check',
          dailyTarget: null,
          totalLoggedValue: 0.0,
          totalChecklistItems: 0,
          doneChecklistItems: 0,
        ),
        isFalse,
      );
    });

    test('3. Count and amount completion: meets target if target exists, else > 0', () {
      // With target = 8 (e.g. cups of water)
      expect(
        HabitsService.isDayCompleted(
          type: 'count',
          dailyTarget: 8.0,
          totalLoggedValue: 8.0,
          totalChecklistItems: 0,
          doneChecklistItems: 0,
        ),
        isTrue,
      );

      expect(
        HabitsService.isDayCompleted(
          type: 'count',
          dailyTarget: 8.0,
          totalLoggedValue: 7.0,
          totalChecklistItems: 0,
          doneChecklistItems: 0,
        ),
        isFalse,
      );

      // Without target (e.g. any coffee counts)
      expect(
        HabitsService.isDayCompleted(
          type: 'count',
          dailyTarget: null,
          totalLoggedValue: 1.0,
          totalChecklistItems: 0,
          doneChecklistItems: 0,
        ),
        isTrue,
      );

      expect(
        HabitsService.isDayCompleted(
          type: 'count',
          dailyTarget: null,
          totalLoggedValue: 0.0,
          totalChecklistItems: 0,
          doneChecklistItems: 0,
        ),
        isFalse,
      );
    });

    test('4. Checklist habit completion: all items done = complete, partial = incomplete', () {
      // 5 daily prayers
      expect(
        HabitsService.isDayCompleted(
          type: 'checklist',
          dailyTarget: null,
          totalLoggedValue: 0.0,
          totalChecklistItems: 5,
          doneChecklistItems: 5,
        ),
        isTrue,
      );

      expect(
        HabitsService.isDayCompleted(
          type: 'checklist',
          dailyTarget: null,
          totalLoggedValue: 0.0,
          totalChecklistItems: 5,
          doneChecklistItems: 4,
        ),
        isFalse,
      );
    });

    test('5. Streak calculation: consecutive complete days ending today or yesterday', () {
      final today = DateTime(2026, 11, 6); // Friday
      final d6 = HabitsService.formatDate(today);
      final d5 = HabitsService.formatDate(today.subtract(const Duration(days: 1)));
      final d4 = HabitsService.formatDate(today.subtract(const Duration(days: 2)));
      final d3 = HabitsService.formatDate(today.subtract(const Duration(days: 3)));
      final d2 = HabitsService.formatDate(today.subtract(const Duration(days: 4)));

      // Scenario A: today completed, past 3 days completed -> streak = 4
      final mapA = {
        d6: true,
        d5: true,
        d4: true,
        d3: true,
        d2: false,
      };
      final (curA, bestA) = HabitsService.calculateStreaks(
        scheduleDays: 127,
        completionMap: mapA,
        today: today,
      );
      expect(curA, equals(4));
      expect(bestA, equals(4));

      // Scenario B: today not completed yet, but past 3 days completed -> streak = 3
      final mapB = {
        d6: false,
        d5: true,
        d4: true,
        d3: true,
        d2: false,
      };
      final (curB, bestB) = HabitsService.calculateStreaks(
        scheduleDays: 127,
        completionMap: mapB,
        today: today,
      );
      expect(curB, equals(3));
      expect(bestB, equals(3));

      // Scenario C: neither today nor yesterday completed -> streak = 0
      final mapC = {
        d6: false,
        d5: false,
        d4: true,
        d3: true,
      };
      final (curC, _) = HabitsService.calculateStreaks(
        scheduleDays: 127,
        completionMap: mapC,
        today: today,
      );
      expect(curC, equals(0));
    });

    test('6. Suggested habits list contains all 6 required habits', () {
      final keys = HabitsService.suggestedHabits.map((h) => h.builtinKey).toList();
      expect(keys, containsAll(['coffee', 'five_prayers', 'quran', 'adhkar', 'water', 'exercise']));

      final prayers = HabitsService.suggestedHabits.firstWhere((h) => h.builtinKey == 'five_prayers');
      expect(prayers.checklistItems, equals(['الفجر', 'الظهر', 'العصر', 'المغرب', 'العشاء']));

      final adhkar = HabitsService.suggestedHabits.firstWhere((h) => h.builtinKey == 'adhkar');
      expect(adhkar.checklistItems, equals(['أذكار الصباح', 'أذكار المساء']));
    });
  });
}
