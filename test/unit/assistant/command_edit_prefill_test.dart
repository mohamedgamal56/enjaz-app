import 'package:flutter_test/flutter_test.dart';
import 'package:enjaz/features/assistant/action_planner.dart';
import 'package:enjaz/features/assistant/rule_based_intent_parser.dart';

void main() {
  group('Command Edit Pre-fill Slots Tests (Batch 2)', () {
    final fixedNow = DateTime(2026, 11, 7, 10, 0); // Saturday
    late RuleBasedIntentParser parser;
    late ActionPlanner planner;

    setUp(() {
      parser = RuleBasedIntentParser(nowProvider: () => fixedNow);
      planner = ActionPlanner(nowProvider: () => fixedNow);
    });

    test('extracts expense slots ready for AddTransactionSheet pre-fill', () {
      final intent = parser.parse('صرفت 50 جنيه على أكل بره', referenceNow: fixedNow);
      final plan = planner.plan(intent);

      expect(plan.actionType, equals('expense'));
      expect(plan.slots['amount'], equals(50.0));
      final amountMinor = ((plan.slots['amount'] as num) * 100).round();
      expect(amountMinor, equals(5000));
      expect(plan.slots['nature'], equals('side'));
    });

    test('extracts essential expense slots correctly', () {
      final intent = parser.parse('دفعت 300 فاتورة النت امبارح', referenceNow: fixedNow);
      final plan = planner.plan(intent);

      expect(plan.actionType, equals('expense'));
      expect(plan.slots['amount'], equals(300.0));
      expect(plan.slots['date'], equals('2026-11-06')); // Yesterday
      expect(plan.slots['isEssential'], isTrue);
      expect(plan.slots['nature'], equals('essential'));
    });

    test('extracts note slots ready for AddNoteSheet pre-fill', () {
      final intent = parser.parse('ملاحظة اللي بيذاكر بيتعلم الصبر', referenceNow: fixedNow);
      final plan = planner.plan(intent);

      expect(plan.actionType, equals('note'));
      expect(plan.slots['title'], contains('الصبر'));
      expect(plan.slots['noteKind'], equals('note'));
    });

    test('extracts quote note slots ready for AddNoteSheet pre-fill', () {
      final intent = parser.parse('سجّل حكمة الصبر مفتاح الفرج', referenceNow: fixedNow);
      final plan = planner.plan(intent);

      expect(plan.actionType, equals('note'));
      expect(plan.slots['noteKind'], equals('quote'));
      expect(plan.slots['title'], contains('الصبر مفتاح الفرج'));
    });

    test('extracts idea slots ready for AddIdeaSheet pre-fill', () {
      final intent = parser.parse('فكرة تطبيق للمشاوير في مصر', referenceNow: fixedNow);
      final plan = planner.plan(intent);

      expect(plan.actionType, equals('idea'));
      expect(plan.slots['title'], contains('تطبيق للمشاوير'));
    });

    test('extracts task slots ready for QuickAddSheet pre-fill', () {
      final intent = parser.parse('سجّل بكرة أكلم العميل الساعة 5', referenceNow: fixedNow);
      final plan = planner.plan(intent);

      expect(plan.actionType, equals('task'));
      expect(plan.slots['title'], contains('أكلم العميل'));
      expect(plan.slots['date'], equals('2026-11-08')); // Tomorrow
      expect(plan.slots['time'], equals('17:00')); // 5 PM
    });
  });
}
