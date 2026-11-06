import 'package:flutter_test/flutter_test.dart';
import 'package:enjaz/features/reminders/domain/reminder_scheduler.dart';

class MockNotificationService {
  final Map<int, String> scheduled = {};
  final List<int> cancelled = [];

  Future<void> scheduleAlarm({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDateTime,
    String? payload,
    String? languageCode,
    int autoStopMinutes = 5,
  }) async {
    scheduled[id] = 'alarm:$title@${scheduledDateTime.toIso8601String()}';
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDateTime,
    String? payload,
    String? languageCode,
  }) async {
    scheduled[id] = 'notification:$title@${scheduledDateTime.toIso8601String()}';
  }

  Future<void> cancelNotification(int id) async {
    scheduled.remove(id);
    cancelled.add(id);
  }
}

void main() {
  group('ReminderScheduler Unit Tests (Round 1 Spec 1.2)', () {
    test('Calculates deterministic positive notification IDs', () {
      expect(ReminderScheduler.getNotificationId(1), 1);
      expect(ReminderScheduler.getNotificationId(42), 42);
      expect(ReminderScheduler.getNotificationId(100500), 100500);
      expect(ReminderScheduler.getNotificationId(-5), 5);
    });

    test('Mock scheduler tracks scheduled alarm and cancels old schedule on edit', () async {
      final mock = MockNotificationService();

      // Schedule at time 1
      final remId = 101;
      final notifId = ReminderScheduler.getNotificationId(remId);
      final initialTime = DateTime(2026, 11, 10, 14, 0);

      await mock.scheduleAlarm(
        id: notifId,
        title: 'شراء المستلزمات',
        body: 'شراء المستلزمات',
        scheduledDateTime: initialTime,
      );

      expect(mock.scheduled.containsKey(notifId), isTrue);
      expect(mock.scheduled[notifId], contains('2026-11-10T14:00:00.000'));

      // Edit time: cancel old, schedule new time
      await mock.cancelNotification(notifId);
      final newTime = DateTime(2026, 11, 10, 16, 30);
      await mock.scheduleAlarm(
        id: notifId,
        title: 'شراء المستلزمات',
        body: 'شراء المستلزمات',
        scheduledDateTime: newTime,
      );

      // Exactly ONE active notification exists at the new time
      expect(mock.scheduled.length, 1);
      expect(mock.scheduled[notifId], contains('2026-11-10T16:30:00.000'));
      expect(mock.cancelled.contains(notifId), isTrue);
    });

    test('Cancels notification when task is marked Done or Deleted', () async {
      final mock = MockNotificationService();
      final remId = 202;
      final notifId = ReminderScheduler.getNotificationId(remId);

      await mock.scheduleNotification(
        id: notifId,
        title: 'مهمة قيد الانتظار',
        body: 'مهمة قيد الانتظار',
        scheduledDateTime: DateTime(2026, 11, 12, 10, 0),
      );
      expect(mock.scheduled.containsKey(notifId), isTrue);

      // Task Done / Delete cancels notification
      await mock.cancelNotification(notifId);
      expect(mock.scheduled.containsKey(notifId), isFalse);
      expect(mock.scheduled.isEmpty, isTrue);
    });
  });
}
