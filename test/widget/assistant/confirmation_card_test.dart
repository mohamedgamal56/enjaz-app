import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:enjaz/features/assistant/action_plan.dart';
import 'package:enjaz/features/assistant/assistant_intent.dart';
import 'package:enjaz/features/assistant/presentation/widgets/confirmation_card.dart';

void main() {
  group('ConfirmationCard Widget Tests (VOICE.md Section 2.4)', () {
    const sampleIntent = AssistantIntent(
      type: AssistantIntentType.createTask,
      rawText: 'سجل مهمة مونتاج الإعلان',
      normalizedText: 'سجل مهمة مونتاج الإعلان',
    );

    testWidgets('Renders card details and calls onConfirm, onEdit, onCancel', (tester) async {
      bool confirmed = false;
      bool edited = false;
      bool cancelled = false;

      final plan = ActionPlan(
        intent: sampleIntent,
        actionType: 'task',
        actionTitle: 'إنشاء مهمة جديدة',
        descriptionInWords: 'مهمة — مونتاج الإعلان — الأحد 8 نوفمبر 2026 — 4:00 م',
        slots: const {
          'title': 'مونتاج الإعلان',
          'date': '2026-11-08',
          'time': '16:00',
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConfirmationCard(
              plan: plan,
              onConfirm: () => confirmed = true,
              onEdit: () => edited = true,
              onCancel: () => cancelled = true,
            ),
          ),
        ),
      );

      expect(find.text('إنشاء مهمة جديدة'), findsOneWidget);
      expect(find.text('مهمة — مونتاج الإعلان — الأحد 8 نوفمبر 2026 — 4:00 م'), findsOneWidget);
      expect(find.text('تأكيد'), findsOneWidget);
      expect(find.text('تعديل'), findsOneWidget);

      // Tap Confirm
      await tester.tap(find.text('تأكيد'));
      expect(confirmed, isTrue);

      // Tap Edit
      await tester.tap(find.text('تعديل'));
      expect(edited, isTrue);

      // Tap Cancel icon
      await tester.tap(find.byTooltip('إلغاء'));
      expect(cancelled, isTrue);
    });

    testWidgets('Renders missing date chips and invokes onDateChipSelected', (tester) async {
      String? selectedDateChip;

      final plan = ActionPlan(
        intent: sampleIntent,
        actionType: 'task',
        actionTitle: 'إنشاء مهمة جديدة',
        descriptionInWords: 'مهمة — مراجعة التقرير',
        slots: const {'title': 'مراجعة التقرير'},
        hasMissingDate: true,
        selectedDateChip: 'none',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConfirmationCard(
              plan: plan,
              onConfirm: () {},
              onEdit: () {},
              onCancel: () {},
              onDateChipSelected: (chip) => selectedDateChip = chip,
            ),
          ),
        ),
      );

      expect(find.text('تاريخ المهمة:'), findsOneWidget);
      expect(find.text('بدون تاريخ'), findsOneWidget);
      expect(find.text('اليوم'), findsOneWidget);
      expect(find.text('بكرة'), findsOneWidget);
      expect(find.text('اختر تاريخ'), findsOneWidget);

      await tester.tap(find.text('بكرة'));
      expect(selectedDateChip, equals('tomorrow'));
    });

    testWidgets('Renders missing reason chips and invokes onReasonSelected', (tester) async {
      String? selectedReason;

      final plan = ActionPlan(
        intent: sampleIntent,
        actionType: 'status_update',
        actionTitle: 'تحديث حالة مهمة',
        descriptionInWords: 'تحديث مهمة — التقرير — مؤجلة',
        slots: const {'status': 'postponed', 'title': 'التقرير'},
        hasMissingReason: true,
        reasonChips: const ['مضغوط في الشغل', 'مفيش فلوس'],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConfirmationCard(
              plan: plan,
              onConfirm: () {},
              onEdit: () {},
              onCancel: () {},
              onReasonSelected: (r) => selectedReason = r,
            ),
          ),
        ),
      );

      expect(find.text('السبب مطلوب، اختر سبباً:'), findsOneWidget);
      expect(find.text('مضغوط في الشغل'), findsOneWidget);
      expect(find.text('مفيش فلوس'), findsOneWidget);

      await tester.tap(find.text('مضغوط في الشغل'));
      expect(selectedReason, equals('مضغوط في الشغل'));
    });

    testWidgets('Renders blocked card when isBlocked is true', (tester) async {
      final plan = const ActionPlan(
        intent: sampleIntent,
        actionType: 'blocked',
        actionTitle: 'إجراء محظور',
        descriptionInWords: 'ده مش متاح بالصوت: حذف العناصر غير متاح لحماية بياناتك',
        slots: {},
        isBlocked: true,
        blockedMessage: 'ده مش متاح بالصوت: حذف العناصر غير متاح لحماية بياناتك',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConfirmationCard(
              plan: plan,
              onConfirm: () {},
              onEdit: () {},
              onCancel: () {},
            ),
          ),
        ),
      );

      expect(find.text('إجراء محظور بالصوت'), findsOneWidget);
      expect(find.text('ده مش متاح بالصوت: حذف العناصر غير متاح لحماية بياناتك'), findsOneWidget);
      expect(find.text('تأكيد'), findsNothing);
    });
  });
}
