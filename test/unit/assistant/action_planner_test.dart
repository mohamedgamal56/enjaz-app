import 'package:flutter_test/flutter_test.dart';
import 'package:enjaz/features/assistant/action_plan.dart';
import 'package:enjaz/features/assistant/action_planner.dart';
import 'package:enjaz/features/assistant/assistant_intent.dart';
import 'package:enjaz/features/assistant/rule_based_intent_parser.dart';

void main() {
  group('ActionPlanner Tests (VOICE.md Step 3 & Section 2.4)', () {
    final fixedNow = DateTime(2026, 11, 7, 10, 0); // Saturday 7 Nov 2026
    final parser = RuleBasedIntentParser(nowProvider: () => fixedNow);
    final planner = ActionPlanner(nowProvider: () => fixedNow);

    test('Formats date in Arabic words correctly', () {
      expect(
        ActionPlanner.formatDateInArabicWords('2026-11-08'),
        equals('الأحد 8 نوفمبر 2026'),
      );
      expect(
        ActionPlanner.formatDateInArabicWords('2026-11-07'),
        equals('السبت 7 نوفمبر 2026'),
      );
      expect(
        ActionPlanner.formatDateInArabicWords('2026-11-12'),
        equals('الخميس 12 نوفمبر 2026'),
      );
    });

    test('Formats time in Arabic correctly', () {
      expect(ActionPlanner.formatTimeInArabic('17:00'), equals('5:00 م'));
      expect(ActionPlanner.formatTimeInArabic('09:30'), equals('9:30 ص'));
      expect(ActionPlanner.formatTimeInArabic('12:00'), equals('12:00 م'));
      expect(ActionPlanner.formatTimeInArabic('00:00'), equals('12:00 ص'));
    });

    test('Formats reminder offset in Arabic words correctly', () {
      expect(ActionPlanner.formatReminderOffset(0), equals('تنبيه في نفس الوقت'));
      expect(ActionPlanner.formatReminderOffset(10), equals('منبه قبلها 10 دقايق'));
      expect(ActionPlanner.formatReminderOffset(30), equals('منبه قبلها نص ساعة'));
      expect(ActionPlanner.formatReminderOffset(60), equals('منبه قبلها بساعة'));
      expect(ActionPlanner.formatReminderOffset(1440), equals('منبه قبلها بيوم'));
    });

    test('Plans create_task with explicit date and time', () {
      final intent = parser.parse('أنا بكرة عايز أعمل مونتاج الإعلان الساعة 4 العصر', referenceNow: fixedNow);
      final plan = planner.plan(intent, referenceNow: fixedNow);

      expect(plan.actionType, equals('task'));
      expect(plan.actionTitle, equals('إنشاء مهمة جديدة'));
      expect(plan.slots['title'], contains('مونتاج الإعلان'));
      expect(plan.slots['date'], equals('2026-11-08'));
      expect(plan.slots['time'], equals('16:00'));
      expect(plan.hasMissingDate, isFalse);
      expect(plan.descriptionInWords, contains('مهمة'));
      expect(plan.descriptionInWords, contains('مونتاج الإعلان'));
      expect(plan.descriptionInWords, contains('الأحد 8 نوفمبر 2026'));
      expect(plan.descriptionInWords, contains('4:00 م'));
    });

    test('Plans create_task with missing date', () {
      final intent = parser.parse('ضيف مهمة أراجع التقرير', referenceNow: fixedNow);
      final plan = planner.plan(intent, referenceNow: fixedNow);

      expect(plan.actionType, equals('task'));
      expect(plan.hasMissingDate, isTrue);
      expect(plan.selectedDateChip, equals('none'));
      expect(plan.descriptionInWords, contains('مهمة'));
      expect(plan.descriptionInWords, contains('أراجع التقرير'));
    });

    test('Plans create_errand with location', () {
      final intent = parser.parse('سجل مشوار النهارده أروح السنترال الساعة 1', referenceNow: fixedNow);
      final plan = planner.plan(intent, referenceNow: fixedNow);

      expect(plan.actionType, equals('errand'));
      expect(plan.actionTitle, equals('تسجيل مشوار'));
      expect(plan.slots['title'], contains('أروح السنترال'));
      expect(plan.slots['date'], equals('2026-11-07'));
      expect(plan.slots['time'], equals('13:00'));
      expect(plan.descriptionInWords, contains('مشوار'));
    });

    test('Plans create_reminder with relative weekday and time', () {
      final intent = parser.parse('فكرني يوم الخميس أكلم دكتور أحمد الساعة 7 بالليل', referenceNow: fixedNow);
      final plan = planner.plan(intent, referenceNow: fixedNow);

      expect(plan.actionType, equals('reminder'));
      expect(plan.actionTitle, equals('إنشاء تذكير'));
      expect(plan.slots['title'], contains('أكلم دكتور أحمد'));
      expect(plan.slots['date'], equals('2026-11-12'));
      expect(plan.slots['time'], equals('19:00'));
      expect(plan.descriptionInWords, contains('الخميس 12 نوفمبر 2026'));
      expect(plan.descriptionInWords, contains('7:00 م'));
    });

    test('Plans update_status with single matching candidate task', () {
      final intent = parser.parse('خلصت مهمة تسليم الفيديوهات', referenceNow: fixedNow);
      const openTasks = [
        CandidateTask(id: 1, title: 'تسليم الفيديوهات للعميل', status: 'in_progress', dueDate: '2026-11-07'),
        CandidateTask(id: 2, title: 'شراء شاشة كمبيوتر', status: 'todo'),
      ];

      final plan = planner.plan(intent, existingOpenTasks: openTasks, referenceNow: fixedNow);

      expect(plan.actionType, equals('status_update'));
      expect(plan.actionTitle, equals('تحديث حالة مهمة'));
      expect(plan.slots['status'], equals('done'));
      expect(plan.slots['taskId'], equals(1));
      expect(plan.isAmbiguous, isFalse);
      expect(plan.descriptionInWords, contains('تمت'));
    });

    test('Plans update_status postponement with reason and target date', () {
      final intent = parser.parse('أجل مهمة مراجعة الحسابات لبكرة عشان مضغوط في الشغل', referenceNow: fixedNow);
      const openTasks = [
        CandidateTask(id: 5, title: 'مراجعة الحسابات الشهرية', status: 'todo', dueDate: '2026-11-07'),
      ];

      final plan = planner.plan(intent, existingOpenTasks: openTasks, referenceNow: fixedNow);

      expect(plan.actionType, equals('status_update'));
      expect(plan.slots['status'], equals('postponed'));
      expect(plan.slots['date'], equals('2026-11-08'));
      expect(plan.slots['reason'], equals('مضغوط في الشغل'));
      expect(plan.hasMissingReason, isFalse);
      expect(plan.descriptionInWords, contains('مؤجلة إلى الأحد 8 نوفمبر 2026'));
      expect(plan.descriptionInWords, contains('مضغوط في الشغل'));
    });

    test('Plans update_status with missing reason shows reason chips', () {
      final intent = parser.parse('أجل مهمة مراجعة الحسابات لبكرة', referenceNow: fixedNow);
      const openTasks = [
        CandidateTask(id: 5, title: 'مراجعة الحسابات', status: 'todo'),
      ];

      final plan = planner.plan(intent, existingOpenTasks: openTasks, referenceNow: fixedNow);

      expect(plan.slots['status'], equals('postponed'));
      expect(plan.hasMissingReason, isTrue);
      expect(plan.reasonChips, contains('مضغوط في الشغل'));
      expect(plan.reasonChips, contains('مفيش فلوس'));
    });

    test('Plans update_status with multiple ambiguous matching tasks', () {
      final intent = parser.parse('خلصت مهمة التقرير', referenceNow: fixedNow);
      const openTasks = [
        CandidateTask(id: 10, title: 'تقرير المبيعات', status: 'in_progress'),
        CandidateTask(id: 11, title: 'تقرير المشتريات', status: 'todo'),
      ];

      final plan = planner.plan(intent, existingOpenTasks: openTasks, referenceNow: fixedNow);

      expect(plan.actionType, equals('status_update'));
      expect(plan.isAmbiguous, isTrue);
      expect(plan.candidateTasks.length, greaterThanOrEqualTo(2));
    });

    test('Plans log_expense with essential category', () {
      final intent = parser.parse('صرفت 100 جنيه بنزين للموتوسيكل النهارده', referenceNow: fixedNow);
      final plan = planner.plan(intent, referenceNow: fixedNow);

      expect(plan.actionType, equals('expense'));
      expect(plan.actionTitle, equals('تسجيل مصروف'));
      expect(plan.slots['amount'], equals(100.0));
      expect(plan.slots['category'], equals('بنزين ومواصلات'));
      expect(plan.slots['isEssential'], isTrue);
      expect(plan.descriptionInWords, contains('100 جنيه'));
      expect(plan.descriptionInWords, contains('بنزين ومواصلات'));
      expect(plan.descriptionInWords, contains('أساسي'));
    });

    test('Plans log_expense for tea and coffee (side nature)', () {
      final intent = parser.parse('سجل شاي وقهوة بـ 25 جنيه', referenceNow: fixedNow);
      final plan = planner.plan(intent, referenceNow: fixedNow);

      expect(plan.actionType, equals('expense'));
      expect(plan.slots['amount'], equals(25.0));
      expect(plan.slots['category'], equals('شاي وقهوة'));
      expect(plan.slots['isEssential'], isFalse);
      expect(plan.descriptionInWords, contains('25 جنيه'));
      expect(plan.descriptionInWords, contains('جانبي'));
    });

    test('Plans log_habit with count quantity', () {
      final intent = parser.parse('شربت كوبايتين قهوة', referenceNow: fixedNow);
      final plan = planner.plan(intent, referenceNow: fixedNow);

      expect(plan.actionType, equals('habit'));
      expect(plan.slots['habitKey'], equals('coffee'));
      expect(plan.slots['quantity'], equals(2.0));
      expect(plan.descriptionInWords, contains('شرب القهوة'));
      expect(plan.descriptionInWords, contains('+2'));
    });

    test('Plans log_habit with checklist tick', () {
      final intent = parser.parse('صليت الفجر', referenceNow: fixedNow);
      final plan = planner.plan(intent, referenceNow: fixedNow);

      expect(plan.actionType, equals('habit'));
      expect(plan.slots['habitKey'], equals('fajr'));
      expect(plan.slots['action'], equals('tick'));
      expect(plan.descriptionInWords, contains('صلاة الفجر'));
      expect(plan.descriptionInWords, contains('تم الإنجاز'));
    });

    test('Plans create_wishlist_item with estimated price', () {
      final intent = parser.parse('ضيف للمشتريات سماعة بـ 1500 جنيه', referenceNow: fixedNow);
      final plan = planner.plan(intent, referenceNow: fixedNow);

      expect(plan.actionType, equals('wishlist'));
      expect(plan.slots['amount'], equals(1500.0));
      expect(plan.descriptionInWords, contains('سماعة'));
      expect(plan.descriptionInWords, contains('1500 جنيه'));
    });

    test('Plans create_health_item with date', () {
      final intent = parser.parse('محتاج كشف أسنان يوم الخميس', referenceNow: fixedNow);
      final plan = planner.plan(intent, referenceNow: fixedNow);

      expect(plan.actionType, equals('health'));
      expect(plan.slots['title'], contains('أسنان'));
      expect(plan.slots['date'], equals('2026-11-12'));
      expect(plan.descriptionInWords, contains('الخميس 12 نوفمبر 2026'));
    });

    test('Plans unsupported_delete as strictly blocked', () {
      final intent = parser.parse('امسح مهمة التقرير', referenceNow: fixedNow);
      final plan = planner.plan(intent, referenceNow: fixedNow);

      expect(plan.isBlocked, isTrue);
      expect(plan.actionType, equals('blocked'));
      expect(plan.descriptionInWords, contains('ده مش متاح بالصوت'));
    });

    test('Plans unrecognized phrase with fallback', () {
      final intent = parser.parse('ازيك عامل ايه النهاردة؟', referenceNow: fixedNow);
      final plan = planner.plan(intent, referenceNow: fixedNow);

      expect(plan.isUnrecognized, isTrue);
      expect(plan.actionType, equals('unrecognized'));
      expect(plan.descriptionInWords, contains('سمعت'));
      expect(plan.descriptionInWords, contains('مفهمتش'));
    });
  });
}
