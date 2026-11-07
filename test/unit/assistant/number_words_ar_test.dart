import 'package:flutter_test/flutter_test.dart';
import 'package:enjaz/features/assistant/number_words_ar.dart';

void main() {
  group('NumberWordsAr Tests (VOICE.md Section 4.3 & 10.2)', () {
    test('1. Parses single units, teens, and tens', () {
      expect(NumberWordsAr.parseNumber('واحد'), 1.0);
      expect(NumberWordsAr.parseNumber('اتنين'), 2.0);
      expect(NumberWordsAr.parseNumber('تلاتة'), 3.0);
      expect(NumberWordsAr.parseNumber('أربعة'), 4.0);
      expect(NumberWordsAr.parseNumber('عشرة'), 10.0);
      expect(NumberWordsAr.parseNumber('حداشر'), 11.0);
      expect(NumberWordsAr.parseNumber('خمستاشر'), 15.0);
      expect(NumberWordsAr.parseNumber('عشرين'), 20.0);
      expect(NumberWordsAr.parseNumber('خمسين'), 50.0);
    });

    test('2. Parses hundreds, thousands, and compound phrases', () {
      expect(NumberWordsAr.parseNumber('مية'), 100.0);
      expect(NumberWordsAr.parseNumber('ميتين'), 200.0);
      expect(NumberWordsAr.parseNumber('خمسمية'), 500.0);
      expect(NumberWordsAr.parseNumber('ألف'), 1000.0);
      expect(NumberWordsAr.parseNumber('ألفين'), 2000.0);
      expect(NumberWordsAr.parseNumber('تلات تلاف'), 3000.0);

      // Section 10.2 explicit test cases: 'ألف وخمسمية' and 'اتنين ونص'
      expect(NumberWordsAr.parseNumber('ألف وخمسمية'), 1500.0);
      expect(NumberWordsAr.parseNumber('الف وخمسميه'), 1500.0);
      expect(NumberWordsAr.parseNumber('اتنين ونص'), 2.5);
      expect(NumberWordsAr.parseNumber('الف ونص'), 1500.0);
      expect(NumberWordsAr.parseNumber('مية وخمسين'), 150.0);
      expect(NumberWordsAr.parseNumber('خمسة وعشرين'), 25.0);
      expect(NumberWordsAr.parseNumber('عشرة وربع'), 10.25);
    });

    test('3. Parses Egyptian duals automatically', () {
      expect(NumberWordsAr.parseNumber('يومين'), 2.0);
      expect(NumberWordsAr.parseNumber('ساعتين'), 2.0);
      expect(NumberWordsAr.parseNumber('جنيهين'), 2.0);
      expect(NumberWordsAr.parseNumber('كوبايتين'), 2.0);
    });

    test('4. Extracts money and currency accurately', () {
      final res1 = NumberWordsAr.extractMoney('صرفت 100 جنيه بنزين');
      expect(res1?.amount, 100.0);
      expect(res1?.currency, 'EGP');

      final res2 = NumberWordsAr.extractMoney('سجل شاي وقهوة بـ 25 جنيه');
      expect(res2?.amount, 25.0);
      expect(res2?.currency, 'EGP');

      final res3 = NumberWordsAr.extractMoney('اشتريت حاجات بألف وخمسمية جنيه');
      expect(res3?.amount, 1500.0);
      expect(res3?.currency, 'EGP');

      final res4 = NumberWordsAr.extractMoney('دفعنا بعشرة جنيه');
      expect(res4?.amount, 10.0);
      expect(res4?.currency, 'EGP');

      final res5 = NumberWordsAr.extractMoney('اشتريت بجنيهين');
      expect(res5?.amount, 2.0);
      expect(res5?.currency, 'EGP');

      final res6 = NumberWordsAr.extractMoney('50 قرش');
      expect(res6?.amount, 0.5);
      expect(res6?.currency, 'EGP');
    });

    test('5. Converts written number words to digits in sentences', () {
      final conv = NumberWordsAr.convertNumberWordsToDigits('فكرني بعد تلات ايام');
      expect(conv, 'فكرني بعد 3 ايام');
    });
  });
}
