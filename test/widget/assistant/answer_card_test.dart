import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:enjaz/features/assistant/answer_service.dart';
import 'package:enjaz/features/assistant/assistant_intent.dart';
import 'package:enjaz/features/assistant/presentation/widgets/answer_card.dart';

void main() {
  group('AnswerCard Widget Tests (VOICE.md Step 4 & Section 6)', () {
    testWidgets('Renders answer details, metric chips, items, and invokes onNavigate and onClose', (tester) async {
      bool navigateCalled = false;
      bool closeCalled = false;

      const intent = AssistantIntent(
        type: AssistantIntentType.agenda,
        rawText: 'ورايا ايه النهارده؟',
        normalizedText: 'ورايا ايه النهارده',
        slots: {},
      );

      final data = AnswerCardData(
        intent: intent,
        title: 'جدول المواعيد (النهارده)',
        speechText: 'وراك في النهارده: مهمة (تسليم التقرير)',
        metricChips: const ['مهمة واحدة', 'لا توجد متأخرات'],
        detailItems: const ['تسليم التقرير الساعة 4:00 م'],
        navTarget: 'tasks',
        navLabel: 'فتح قائمة المهام',
        icon: Icons.calendar_today_rounded,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AnswerCard(
                data: data,
                onNavigate: () => navigateCalled = true,
                onClose: () => closeCalled = true,
              ),
            ),
          ),
        ),
      );

      // Verify header title and speech text rendered
      expect(find.text('جدول المواعيد (النهارده)'), findsOneWidget);
      expect(find.text('وراك في النهارده: مهمة (تسليم التقرير)'), findsOneWidget);

      // Verify metric chips
      expect(find.text('مهمة واحدة'), findsOneWidget);
      expect(find.text('لا توجد متأخرات'), findsOneWidget);

      // Verify detail item
      expect(find.text('تسليم التقرير الساعة 4:00 م'), findsOneWidget);

      // Verify action button
      expect(find.text('فتح قائمة المهام'), findsOneWidget);

      // Tap navigation button
      await tester.tap(find.text('فتح قائمة المهام'));
      await tester.pump();
      expect(navigateCalled, isTrue);

      // Tap close button
      await tester.tap(find.text('إغلاق'));
      await tester.pump();
      expect(closeCalled, isTrue);
    });
  });
}
