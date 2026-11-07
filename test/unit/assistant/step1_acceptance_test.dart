import 'package:flutter_test/flutter_test.dart';
import 'package:enjaz/features/assistant/text_normalizer.dart';
import 'package:enjaz/features/assistant/number_words_ar.dart';
import 'package:enjaz/features/assistant/date_time_resolver.dart';
import 'package:enjaz/features/assistant/plural_ar.dart';

void main() {
  group('Voice Assistant Step 1 Foundations Acceptance Tests (VOICE.md Section 10.2)', () {
    final fixedNow = DateTime(2026, 11, 7, 10, 0); // Saturday 7 Nov 2026 10:00 AM
    final resolver = DateTimeResolver(
      nowProvider: () => fixedNow,
      weekStartWeekday: DateTime.saturday,
    );

    test('Verification of User-Provided 10 Egyptian Corpus Sentences with Step 1 Foundations', () {
      // 1. "أنا بكرة عايز أعمل مونتاج الإعلان الساعة 4 العصر"
      const s1 = 'أنا بكرة عايز أعمل مونتاج الإعلان الساعة 4 العصر';
      final n1 = TextNormalizer.normalize(s1);
      expect(n1, contains('بكرة'));
      expect(resolver.resolveDate(n1)?.dateStr, '2026-11-08');
      expect(resolver.resolveTime(n1)?.timeStr, '16:00');

      // 2. "سجل مشوار النهارده أروح السنترال الساعة 1"
      const s2 = 'سجل مشوار النهارده أروح السنترال الساعة 1';
      final n2 = TextNormalizer.normalize(s2);
      expect(resolver.resolveDate(n2)?.dateStr, '2026-11-07');
      expect(resolver.resolveTime(n2)?.timeStr, '13:00'); // Unmarked 1..6 = PM

      // 3. "فكرني يوم الخميس أكلم دكتور أحمد الساعة 7 بالليل"
      const s3 = 'فكرني يوم الخميس أكلم دكتور أحمد الساعة 7 بالليل';
      final n3 = TextNormalizer.normalize(s3);
      expect(resolver.resolveDate(n3)?.dateStr, '2026-11-12');
      expect(resolver.resolveTime(n3)?.timeStr, '19:00'); // 7 PM

      // 4. "صرفت 100 جنيه بنزين للموتوسيكل النهارده"
      const s4 = 'صرفت 100 جنيه بنزين للموتوسيكل النهارده';
      final money4 = NumberWordsAr.extractMoney(s4);
      expect(money4?.amount, 100.0);
      expect(money4?.currency, 'EGP');
      expect(resolver.resolveDate(s4)?.dateStr, '2026-11-07');

      // 5. "سجل شاي وقهوة بـ 25 جنيه"
      const s5 = 'سجل شاي وقهوة بـ 25 جنيه';
      final money5 = NumberWordsAr.extractMoney(s5);
      expect(money5?.amount, 25.0);
      expect(money5?.currency, 'EGP');

      // 6. "خلصت مهمة تسليم الفيديوهات"
      const s6 = 'خلصت مهمة تسليم الفيديوهات';
      final n6 = TextNormalizer.normalize(s6);
      expect(n6, 'خلصت مهمه تسليم الفيديوهات');

      // 7. "أجل مهمة مراجعة الحسابات لبكرة عشان مضغوط في الشغل"
      const s7 = 'أجل مهمة مراجعة الحسابات لبكرة عشان مضغوط في الشغل';
      final n7 = TextNormalizer.normalize(s7);
      expect(resolver.resolveDate(n7)?.dateStr, '2026-11-08');

      // 8. "ورايا إيه النهارده؟"
      const s8 = 'ورايا إيه النهارده؟';
      final n8 = TextNormalizer.normalize(s8);
      expect(resolver.resolveDate(n8)?.dateStr, '2026-11-07');

      // 9. "صرفت كام الشهر ده؟"
      const s9 = 'صرفت كام الشهر ده؟';
      final p9 = resolver.resolvePeriod(s9);
      expect(p9?.startStr, '2026-11-01');
      expect(p9?.endStr, '2026-11-30');

      // 10. "إيه المهام المتأخرة عندي؟"
      const s10 = 'إيه المهام المتأخرة عندي؟';
      final n10 = TextNormalizer.normalize(s10);
      expect(n10, 'ايه المهام المتاخره عندي');
    });

    test('Section 10.2 specific numbers: ألف وخمسمية and اتنين ونص', () {
      expect(NumberWordsAr.parseNumber('ألف وخمسمية'), 1500.0);
      expect(NumberWordsAr.parseNumber('اتنين ونص'), 2.5);
    });

    test('Section 10.2 specific times: الساعة 9, الساعة 5, 5 العصر, 8 بالليل, الضهر, ستة وربع', () {
      expect(resolver.resolveTime('الساعة 9')?.timeStr, '09:00');
      expect(resolver.resolveTime('الساعة 5')?.timeStr, '17:00');
      expect(resolver.resolveTime('5 العصر')?.timeStr, '17:00');
      expect(resolver.resolveTime('8 بالليل')?.timeStr, '20:00');
      expect(resolver.resolveTime('الضهر')?.timeStr, '12:00');
      expect(resolver.resolveTime('ستة وربع')?.timeStr, '18:15');
    });
  });
}
