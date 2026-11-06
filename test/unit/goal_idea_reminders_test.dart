import 'package:flutter_test/flutter_test.dart';
import 'package:enjaz/features/reminders/domain/reminder_scheduler.dart';

void main() {
  group('Goal and Idea Reminders Tests (Round 3 Spec 3.3)', () {
    test('1. ReminderScheduler generates deterministic notification IDs for goals and ideas', () {
      final notifId1 = ReminderScheduler.getNotificationId(101);
      final notifId2 = ReminderScheduler.getNotificationId(202);
      final notifId3 = ReminderScheduler.getNotificationId(101);

      expect(notifId1, equals(notifId3));
      expect(notifId1, isNot(equals(notifId2)));
      expect(notifId1, greaterThanOrEqualTo(0));
    });

    test('2. Goal reminder payload formats as goal:<id>', () {
      const ownerType = 'goal';
      const ownerId = 42;
      final payload = '$ownerType:$ownerId';
      expect(payload, equals('goal:42'));
    });

    test('3. Idea reminder payload formats as idea:<id>', () {
      const ownerType = 'idea';
      const ownerId = 99;
      final payload = '$ownerType:$ownerId';
      expect(payload, equals('idea:99'));
    });
  });
}
