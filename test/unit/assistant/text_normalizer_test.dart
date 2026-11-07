import 'package:flutter_test/flutter_test.dart';
import 'package:enjaz/features/assistant/text_normalizer.dart';

void main() {
  group('TextNormalizer Tests (VOICE.md Section 4.2)', () {
    test('1. Removes Arabic diacritics / tashkeel', () {
      const input = 'مُهِمَّةٌ جَدِيدَةٌ مَعَ التَّشْكِيلِ';
      final result = TextNormalizer.removeDiacritics(input);
      expect(result, 'مهمة جديدة مع التشكيل');
    });

    test('2. Converts Arabic-Indic digits to Western digits', () {
      const input = 'الساعة ٥:٣٠ والمبلغ ١٥٠٠ جنيه';
      final result = TextNormalizer.convertArabicDigits(input);
      expect(result, 'الساعة 5:30 والمبلغ 1500 جنيه');
    });

    test('3. Unifies Alef variations (أ, إ, آ, ٱ -> ا)', () {
      expect(TextNormalizer.normalize('أحمد'), 'احمد');
      expect(TextNormalizer.normalize('إسلام'), 'اسلام');
      expect(TextNormalizer.normalize('آخر'), 'اخر');
      expect(TextNormalizer.normalize('ٱلله'), 'الله');
    });

    test('4. Unifies Taa Marbuta (ة -> ه) and Alef Maqsura (ى -> ي)', () {
      expect(TextNormalizer.normalize('مهمة صعبة'), 'مهمه صعبه');
      expect(TextNormalizer.normalize('علي ومصطفى'), 'علي ومصطفي');
    });

    test('5. Removes Arabic and Latin punctuation', () {
      const input = 'هل انتهيت؟، نعم!؛ شكراً: "تمام".';
      final result = TextNormalizer.normalize(input);
      expect(result, 'هل انتهيت نعم شكرا تمام');
    });

    test('6. Expands and unifies common Egyptian dialect synonyms', () {
      expect(TextNormalizer.normalize('انهارده'), 'النهارده');
      expect(TextNormalizer.normalize('النهاردة'), 'النهارده');
      expect(TextNormalizer.normalize('بكره'), 'بكرة');
      expect(TextNormalizer.normalize('غدا'), 'بكرة');
      expect(TextNormalizer.normalize('مبارح'), 'امبارح');
      expect(TextNormalizer.normalize('أمس'), 'امبارح');
      expect(TextNormalizer.normalize('دلوكتي'), 'دلوقتي');
      expect(TextNormalizer.normalize('الاسبوع اللي فاتت'), 'الاسبوع اللي فات');
      expect(TextNormalizer.normalize('السنه دي'), 'السنة دي');
    });
  });
}
