import 'package:flutter_test/flutter_test.dart';
import 'package:enjaz/features/assistant/word_merge_helper.dart';

void main() {
  group('WordMergeHelper Unit Tests (VOICE.md Section 3.2)', () {
    test('returns segment when accumulated is empty', () {
      expect(WordMergeHelper.merge('', 'سجل مهمة جديدة'), 'سجل مهمة جديدة');
      expect(WordMergeHelper.merge('   ', 'شاي وقهوة'), 'شاي وقهوة');
    });

    test('returns accumulated when segment is empty', () {
      expect(WordMergeHelper.merge('سجل مهمة جديدة', ''), 'سجل مهمة جديدة');
      expect(WordMergeHelper.merge('شاي وقهوة', '   '), 'شاي وقهوة');
    });

    test('joins with space when no overlap exists', () {
      final res = WordMergeHelper.merge('سجل مهمة', 'مونتاج الإعلان');
      expect(res, 'سجل مهمة مونتاج الإعلان');
    });

    test('deduplicates single-word boundary overlap', () {
      final res = WordMergeHelper.merge('أروح السنترال', 'السنترال الساعة 1');
      expect(res, 'أروح السنترال الساعة 1');
    });

    test('deduplicates multi-word boundary overlap', () {
      final res = WordMergeHelper.merge('عايز أعمل مونتاج الإعلان', 'مونتاج الإعلان الساعة 4 العصر');
      expect(res, 'عايز أعمل مونتاج الإعلان الساعة 4 العصر');
    });

    test('handles cumulative speech result starting with accumulated', () {
      final res = WordMergeHelper.merge('سجل مشوار', 'سجل مشوار أروح البنك');
      expect(res, 'سجل مشوار أروح البنك');
    });

    test('returns accumulated when new segment is identical', () {
      final res = WordMergeHelper.merge('صرفت 100 جنيه', 'صرفت 100 جنيه');
      expect(res, 'صرفت 100 جنيه');
    });

    test('ignores punctuation differences in boundary overlap detection', () {
      final res = WordMergeHelper.merge('أروح السنترال،', 'السنترال الساعة 1');
      expect(res, 'أروح السنترال، الساعة 1');
    });
  });
}
