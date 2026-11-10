import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:enjaz/core/db/app_database.dart';
import 'package:enjaz/features/reminders/domain/alarm_payload.dart';
import 'package:enjaz/features/reminders/domain/active_alarm.dart';
import 'package:enjaz/features/reminders/domain/reminder_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  final cancelled = <int>[];
  const reminder = Reminder(id: 73, createdAt: 1, updatedAt: 1,
    ownerType: 'task', ownerId: 4, kind: 'alarm', triggerType: 'absolute', enabled: true);
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    db = AppDatabase(NativeDatabase.memory());
    cancelled.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('dexterous.com/flutter/local_notifications'), (call) async {
      if (call.method == 'initialize') return true;
      if (call.method == 'cancel') cancelled.add(call.arguments['id'] as int);
      if (call.method == 'pendingNotificationRequests') return [{
        'id': 73, 'title': null, 'body': null,
        'payload': AlarmPayload(id: 73, owner: 'task:4', snoozed: true,
          expiresAt: DateTime.now().add(const Duration(minutes: 10))).encode(),
      }];
      return null;
    });
  });
  tearDown(() async {
    activeAlarm.value = null;
    await db.close();
    debugDefaultTargetPlatformOverride = null;
  });
  test('startup keeps a future snooze instead of cancelling it', () async {
    await ReminderScheduler(db: db).scheduleReminder(
      reminder: reminder, title: 'Task', preservePending: true);
    expect(cancelled, isEmpty);
  });
  test('an explicit reminder edit can replace the pending snooze', () async {
    await ReminderScheduler(db: db).scheduleReminder(reminder: reminder, title: 'Task');
    expect(cancelled, [73]);
  });
  test('startup does not cancel the currently ringing alarm', () async {
    activeAlarm.value = const AlarmPayload(id: 73, owner: 'task:4');
    await ReminderScheduler(db: db).scheduleReminder(
      reminder: reminder, title: 'Task', preservePending: true);
    expect(cancelled, isEmpty);
  });
}
