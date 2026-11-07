import 'package:flutter_test/flutter_test.dart';
import 'package:enjaz/features/assistant/assistant_intent.dart';
import 'package:enjaz/features/assistant/rule_based_intent_parser.dart';

void main() {
  // Fixed reference date: Saturday 7 Nov 2026 10:00 AM (Africa/Cairo)
  final fixedNow = DateTime(2026, 11, 7, 10, 0);
  final parser = RuleBasedIntentParser(nowProvider: () => fixedNow);

  group('RuleBasedIntentParser - Commands', () {
    test('create_task with explicit date and time', () {
      final res = parser.parse('سجّل بكرة أكلم العميل الساعة 5', referenceNow: fixedNow);
      expect(res.type, equals(AssistantIntentType.createTask));
      expect(res.dateStr, equals('2026-11-08'));
      expect(res.timeStr, equals('17:00'));
      expect(res.title, contains('أكلم العميل'));
    });

    test('create_task without command verb (implicit intent)', () {
      final res = parser.parse('أنا بكرة عايز أعمل مونتاج الإعلان الساعة 4 العصر', referenceNow: fixedNow);
      expect(res.type, equals(AssistantIntentType.createTask));
      expect(res.dateStr, equals('2026-11-08'));
      expect(res.timeStr, equals('16:00'));
      expect(res.title, contains('مونتاج الإعلان'));
    });

    test('create_errand requires مشوار and extracts location and time', () {
      final res = parser.parse('سجل مشوار النهارده أروح السنترال الساعة 1', referenceNow: fixedNow);
      expect(res.type, equals(AssistantIntentType.createErrand));
      expect(res.dateStr, equals('2026-11-07'));
      expect(res.timeStr, equals('13:00'));
      expect(res.title, contains('السنترال'));
    });

    test('create_errand with "عند"', () {
      final res = parser.parse('مشوار بكرة عند المحامي الساعة 5', referenceNow: fixedNow);
      expect(res.type, equals(AssistantIntentType.createErrand));
      expect(res.dateStr, equals('2026-11-08'));
      expect(res.timeStr, equals('17:00'));
      expect(res.location, equals('المحامي'));
    });

    test('create_reminder with reminder offset', () {
      final res = parser.parse('فكرني قبلها بساعة اتصل بالبنك', referenceNow: fixedNow);
      expect(res.type, equals(AssistantIntentType.createReminder));
      expect(res.reminderOffsetMinutes, equals(60));
      expect(res.title, contains('اتصل بالبنك'));
    });

    test('create_reminder on weekday night', () {
      final res = parser.parse('فكرني يوم الخميس أكلم دكتور أحمد الساعة 7 بالليل', referenceNow: fixedNow);
      expect(res.type, equals(AssistantIntentType.createReminder));
      expect(res.dateStr, equals('2026-11-12'));
      expect(res.timeStr, equals('19:00'));
      expect(res.title, contains('أكلم دكتور أحمد'));
    });

    test('update_status: done', () {
      final res = parser.parse('خلصت مهمة تسليم الفيديوهات', referenceNow: fixedNow);
      expect(res.type, equals(AssistantIntentType.updateStatus));
      expect(res.status, equals('done'));
      expect(res.title, contains('تسليم الفيديوهات'));
    });

    test('update_status: in_progress', () {
      final res = parser.parse('ابتديت المونتاج', referenceNow: fixedNow);
      expect(res.type, equals(AssistantIntentType.updateStatus));
      expect(res.status, equals('in_progress'));
      expect(res.title, contains('المونتاج'));
    });

    test('update_status: postponed with target date and reason', () {
      final res = parser.parse('أجل مهمة مراجعة الحسابات لبكرة عشان مضغوط في الشغل', referenceNow: fixedNow);
      expect(res.type, equals(AssistantIntentType.updateStatus));
      expect(res.status, equals('postponed'));
      expect(res.dateStr, equals('2026-11-08'));
      expect(res.reason, equals('مضغوط في الشغل'));
      expect(res.title, contains('مراجعة الحسابات'));
    });

    test('update_status: waiting with reason', () {
      final res = parser.parse('مهمة العميل مستنية رد الدكتور', referenceNow: fixedNow);
      expect(res.type, equals(AssistantIntentType.updateStatus));
      expect(res.status, equals('waiting'));
      expect(res.reason, contains('رد الدكتور'));
      expect(res.title, contains('العميل'));
    });

    test('update_status: stopped with reason', () {
      final res = parser.parse('وقفت مهمة الاعلان بسبب الميزانية', referenceNow: fixedNow);
      expect(res.type, equals(AssistantIntentType.updateStatus));
      expect(res.status, equals('stopped'));
      expect(res.reason, equals('مفيش فلوس')); // Canonical reason match for الميزانية
      expect(res.title, contains('الاعلان'));
    });

    test('update_status: partial progress', () {
      final res = parser.parse('عملت نص مهمة التصميم لاني تعبت', referenceNow: fixedNow);
      expect(res.type, equals(AssistantIntentType.updateStatus));
      expect(res.status, equals('partial'));
      expect(res.progress, equals(0.5));
      expect(res.reason, equals('تعبت'));
      expect(res.title, contains('التصميم'));
    });

    test('log_expense with category and amount', () {
      final res = parser.parse('صرفت 100 جنيه بنزين للموتوسيكل النهارده', referenceNow: fixedNow);
      expect(res.type, equals(AssistantIntentType.logExpense));
      expect(res.amount, equals(100.0));
      expect(res.category, equals('بنزين ومواصلات'));
      expect(res.isEssential, isTrue);
      expect(res.dateStr, equals('2026-11-07'));
    });

    test('log_expense cafe side expense', () {
      final res = parser.parse('سجل شاي وقهوة بـ 25 جنيه', referenceNow: fixedNow);
      expect(res.type, equals(AssistantIntentType.logExpense));
      expect(res.amount, equals(25.0));
      expect(res.category, equals('شاي وقهوة'));
      expect(res.isEssential, isFalse);
    });

    test('log_income salary', () {
      final res = parser.parse('قبضت 8000 مرتب', referenceNow: fixedNow);
      expect(res.type, equals(AssistantIntentType.logIncome));
      expect(res.amount, equals(8000.0));
      expect(res.title, contains('مرتب'));
    });

    test('log_habit with count', () {
      final res = parser.parse('كوبايتين قهوة', referenceNow: fixedNow);
      expect(res.type, equals(AssistantIntentType.logHabit));
      expect(res.habitKey, equals('coffee'));
      expect(res.quantity, equals(2.0));
    });

    test('log_habit checkbox tick', () {
      final res = parser.parse('صليت الفجر', referenceNow: fixedNow);
      expect(res.type, equals(AssistantIntentType.logHabit));
      expect(res.habitKey, equals('fajr'));
      expect(res.slots['action'], equals('tick'));
    });

    test('create_note: quote', () {
      final res = parser.parse('حكمة اللي ما يشوفش من الغربال', referenceNow: fixedNow);
      expect(res.type, equals(AssistantIntentType.createNote));
      expect(res.noteKind, equals('quote'));
      expect(res.title, contains('اللي ما يشوفش من الغربال'));
    });

    test('create_idea', () {
      final res = parser.parse('فكرة تطبيق للمشاوير', referenceNow: fixedNow);
      expect(res.type, equals(AssistantIntentType.createIdea));
      expect(res.title, contains('تطبيق للمشاوير'));
    });

    test('record_voice_note idea', () {
      final res = parser.parse('سجّل فكرة صوتية', referenceNow: fixedNow);
      expect(res.type, equals(AssistantIntentType.recordVoiceNote));
      expect(res.voiceNoteKind, equals('idea'));
    });

    test('record_voice_note note', () {
      final res = parser.parse('سجّل ملاحظة صوتية', referenceNow: fixedNow);
      expect(res.type, equals(AssistantIntentType.recordVoiceNote));
      expect(res.voiceNoteKind, equals('note'));
    });

    test('create_wishlist_item with price', () {
      final res = parser.parse('ضيف للمشتريات سماعة بألف وخمسمية', referenceNow: fixedNow);
      expect(res.type, equals(AssistantIntentType.createWishlistItem));
      expect(res.title, contains('سماعة'));
      expect(res.amount, equals(1500.0));
    });

    test('create_health_item scheduled', () {
      final res = parser.parse('فكرني اروح كشف الاسنان يوم الخميس', referenceNow: fixedNow);
      expect(res.type, equals(AssistantIntentType.createHealthItem));
      expect(res.title, contains('كشف الاسنان'));
      expect(res.dateStr, equals('2026-11-12'));
      expect(res.healthStatus, equals('scheduled'));
    });

    test('create_health_item needed', () {
      final res = parser.parse('محتاج اعمل تحليل سكر', referenceNow: fixedNow);
      expect(res.type, equals(AssistantIntentType.createHealthItem));
      expect(res.title, contains('تحليل سكر'));
      expect(res.healthStatus, equals('needed'));
    });
  });

  group('RuleBasedIntentParser - Questions', () {
    test('agenda today', () {
      final res = parser.parse('ورايا إيه النهارده؟', referenceNow: fixedNow);
      expect(res.type, equals(AssistantIntentType.agenda));
      expect(res.dateStr, equals('2026-11-07'));
    });

    test('recap yesterday', () {
      final res = parser.parse('ايه عملت امبارح؟', referenceNow: fixedNow);
      expect(res.type, equals(AssistantIntentType.recap));
      expect(res.dateStr, equals('2026-11-06'));
    });

    test('recap last week', () {
      final res = parser.parse('الاسبوع اللي فات عملت ايه؟', referenceNow: fixedNow);
      expect(res.type, equals(AssistantIntentType.recap));
      expect(res.slots['period'], contains('2026-10-31 to 2026-11-06'));
    });

    test('spending this month', () {
      final res = parser.parse('صرفت كام الشهر ده؟', referenceNow: fixedNow);
      expect(res.type, equals(AssistantIntentType.spending));
      expect(res.slots['period'], contains('2026-11-01 to 2026-11-30'));
    });

    test('habit_status coffee', () {
      final res = parser.parse('شربت كام قهوة النهارده؟', referenceNow: fixedNow);
      expect(res.type, equals(AssistantIntentType.habitStatus));
      expect(res.habitKey, equals('coffee'));
      expect(res.dateStr, equals('2026-11-07'));
    });

    test('pending overdue', () {
      final res = parser.parse('إيه المهام المتأخرة عندي؟', referenceNow: fixedNow);
      expect(res.type, equals(AssistantIntentType.pending));
      expect(res.statusFilter, equals('overdue'));
    });

    test('obligations this month', () {
      final res = parser.parse('ايه عليا الشهر ده؟', referenceNow: fixedNow);
      expect(res.type, equals(AssistantIntentType.obligations));
      expect(res.slots['period'], contains('2026-11-01 to 2026-11-30'));
    });

    test('health_pending', () {
      final res = parser.parse('ايه الكشوفات المؤجلة؟', referenceNow: fixedNow);
      expect(res.type, equals(AssistantIntentType.healthPending));
    });

    test('wishlist total', () {
      final res = parser.parse('اجمالي المشتريات اللي عايزها كام؟', referenceNow: fixedNow);
      expect(res.type, equals(AssistantIntentType.wishlist));
    });
  });

  group('RuleBasedIntentParser - Safety & Blocked', () {
    test('unsupported_delete blocks deleting tasks', () {
      final res = parser.parse('امسح مهمة التقرير', referenceNow: fixedNow);
      expect(res.type, equals(AssistantIntentType.unsupportedDelete));
      expect(res.isBlocked, isTrue);
    });

    test('unsupported_delete blocks deleting expenses', () {
      final res = parser.parse('احذف مصروف الشاي', referenceNow: fixedNow);
      expect(res.type, equals(AssistantIntentType.unsupportedDelete));
      expect(res.isBlocked, isTrue);
    });

    test('unsupported_delete blocks deleting all items', () {
      final res = parser.parse('امسح كل المهام', referenceNow: fixedNow);
      expect(res.type, equals(AssistantIntentType.unsupportedDelete));
      expect(res.isBlocked, isTrue);
    });
  });
}
