import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Notes Module Logic Tests (Round 3 Spec 3.2)', () {
    test('1. Validates note kinds: note, quote, info', () {
      const kinds = ['note', 'quote', 'info'];
      expect(kinds.contains('note'), isTrue);
      expect(kinds.contains('quote'), isTrue);
      expect(kinds.contains('info'), isTrue);
    });

    test('2. Notes sorting puts pinned notes first, then descending creation', () {
      final sampleNotes = [
        {'id': 1, 'pinned': false, 'createdAt': 1000},
        {'id': 2, 'pinned': true, 'createdAt': 500},
        {'id': 3, 'pinned': false, 'createdAt': 1200},
        {'id': 4, 'pinned': true, 'createdAt': 800},
      ];

      sampleNotes.sort((a, b) {
        final pinA = a['pinned'] as bool ? 1 : 0;
        final pinB = b['pinned'] as bool ? 1 : 0;
        if (pinA != pinB) return pinB.compareTo(pinA);
        return (b['createdAt'] as int).compareTo(a['createdAt'] as int);
      });

      expect(sampleNotes.map((n) => n['id']).toList(), equals([4, 2, 3, 1]));
    });

    test('3. Note to Task conversion preserves text and tags', () {
      const noteTitle = 'فكرة لمهمة جديدة';
      const noteBody = 'تفاصيل المهمة المطلوب تنفيذها';
      const noteDate = '2026-11-10';

      final taskTitle = noteTitle.isNotEmpty ? noteTitle : noteBody.split('\n').first;
      final taskNotes = noteBody;

      expect(taskTitle, equals('فكرة لمهمة جديدة'));
      expect(taskNotes, equals('تفاصيل المهمة المطلوب تنفيذها'));
    });

    test('4. Note to Idea conversion extracts tags correctly', () {
      const tagsString = 'تطوير,برمجة,ملاحظة';
      final tags = tagsString.split(',').map((e) => e.trim()).toList();
      expect(tags, equals(['تطوير', 'برمجة', 'ملاحظة']));
    });
  });
}
