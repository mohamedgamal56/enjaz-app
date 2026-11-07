import 'package:flutter_test/flutter_test.dart';
import 'package:enjaz/features/assistant/plural_ar.dart';

void main() {
  group('PluralAr Tests (VOICE.md Section 10.2)', () {
    test('1. Day counts pluralization', () {
      expect(PluralAr.formatDays(0), 'صفر يوم');
      expect(PluralAr.formatDays(1), 'يوم');
      expect(PluralAr.formatDays(2), 'يومين');
      expect(PluralAr.formatDays(3), '3 أيام');
      expect(PluralAr.formatDays(5), '5 أيام');
      expect(PluralAr.formatDays(10), '10 أيام');
      expect(PluralAr.formatDays(15), '15 يوم');
      expect(PluralAr.formatDays(30), '30 يوم');
    });

    test('2. Hour counts pluralization', () {
      expect(PluralAr.formatHours(1), 'ساعة');
      expect(PluralAr.formatHours(2), 'ساعتين');
      expect(PluralAr.formatHours(4), '4 ساعات');
      expect(PluralAr.formatHours(12), '12 ساعة');
    });

    test('3. Minute counts pluralization', () {
      expect(PluralAr.formatMinutes(1), 'دقيقة');
      expect(PluralAr.formatMinutes(2), 'دقيقتين');
      expect(PluralAr.formatMinutes(5), '5 دقائق');
      expect(PluralAr.formatMinutes(20), '20 دقيقة');
    });

    test('4. Task counts pluralization', () {
      expect(PluralAr.formatTasks(0), 'لا توجد مهام');
      expect(PluralAr.formatTasks(1), 'مهمة');
      expect(PluralAr.formatTasks(2), 'مهمتين');
      expect(PluralAr.formatTasks(4), '4 مهام');
      expect(PluralAr.formatTasks(15), '15 مهمة');
    });

    test('5. Egyptian pounds formatting', () {
      expect(PluralAr.formatPounds(1), 'جنيه');
      expect(PluralAr.formatPounds(2), 'جنيهين');
      expect(PluralAr.formatPounds(5), '5 جنيه');
      expect(PluralAr.formatPounds(25), '25 جنيه');
      expect(PluralAr.formatPounds(1500), '1500 جنيه');
    });
  });
}
