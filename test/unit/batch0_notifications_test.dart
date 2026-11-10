import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:enjaz/features/reminders/domain/notification_service.dart';
import 'package:enjaz/features/reminders/domain/notification_diagnostics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final service = NotificationService.instance;
  var enabled = true, exact = true, retained = true, blocked = false;
  String? failure;
  final calls = <MethodCall>[];
  final pending = <int>{};
  Future<void> schedule() => service.scheduleAlarm(
      id: 12,
      title: 'Private',
      body: 'Private',
      scheduledDateTime: DateTime.now().add(const Duration(minutes: 5)));
  Future<List<String>> codes() async => (await NotificationDiagnostics.read())
      .map((s) => jsonDecode(s)['code'] as String)
      .toList();
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({});
    enabled = exact = retained = true;
    blocked = false;
    failure = null;
    calls.clear();
    pending.clear();
    service.activeScheduledPayloads.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'initialize':
          return true;
        case 'areNotificationsEnabled':
          return enabled;
        case 'canScheduleExactNotifications':
          return exact;
        case 'getNotificationChannels':
          return blocked
              ? [
                  {
                    'id': NotificationService.channelAlarmV2,
                    'name': 'Alarm',
                    'importance': 0,
                    'playSound': true,
                    'enableVibration': true,
                    'enableLights': false,
                    'ledColor': 0,
                    'showBadge': true
                  }
                ]
              : [];
        case 'cancel':
          pending.remove(call.arguments['id']);
          return null;
        case 'zonedSchedule':
          if (failure != null &&
              (failure != 'exact_alarms_not_permitted' ||
                  call.arguments['platformSpecifics']['scheduleMode'] ==
                      'exactAllowWhileIdle'))
            throw PlatformException(code: failure!);
          if (retained) pending.add(call.arguments['id'] as int);
          return null;
        case 'pendingNotificationRequests':
          return pending
              .map((id) =>
                  {'id': id, 'title': null, 'body': null, 'payload': null})
              .toList();
        default:
          return null;
      }
    });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });
  test('disabled notifications never report a scheduled alarm', () async {
    enabled = false;
    await schedule();
    expect(calls.where((c) => c.method == 'zonedSchedule'), isEmpty);
    expect(service.activeScheduledPayloads, isEmpty);
    expect(await codes(), contains('notifications_disabled'));
  });
  test('without exact permission uses inexact and records warning', () async {
    exact = false;
    await schedule();
    expect(
        calls
            .firstWhere((c) => c.method == 'zonedSchedule')
            .arguments['platformSpecifics']['scheduleMode'],
        'inexactAllowWhileIdle');
    expect(await codes(), contains('inexact_fallback'));
    expect(service.activeScheduledPayloads, contains(12));
    expect(calls.where((c) => c.method == 'requestExactAlarmsPermission'),
        isEmpty);
  });
  test('revoked exact permission retries inexact and never logs exact success',
      () async {
    failure = 'exact_alarms_not_permitted';
    await schedule();
    expect(calls.where((c) => c.method == 'zonedSchedule').length, 2);
    expect(await codes(), contains('inexact_fallback'));
    expect(await codes(), isNot(contains('scheduled')));
  });
  test('platform failure preserves code without false success', () async {
    failure = 'invalid_icon';
    await schedule();
    expect(await codes(), contains('invalid_icon'));
    expect(service.activeScheduledPayloads, isEmpty);
  });
  test('missing Android pending request is a failure', () async {
    retained = false;
    await schedule();
    expect(await codes(), contains('schedule_not_found'));
    expect(service.activeScheduledPayloads, isEmpty);
  });
  test('blocked channel is reported before scheduling', () async {
    blocked = true;
    await schedule();
    expect(await codes(), contains('channel_disabled'));
    expect(service.activeScheduledPayloads, isEmpty);
  });
  test('accepted scheduling means pending, not delivered', () async {
    await schedule();
    expect(await codes(), contains('scheduled'));
    expect((await service.pendingRequests()).single.id, 12);
  });
  test('immediate test respects notification permission', () async {
    enabled = false;
    expect(await service.testImmediateNotification('Test', 'Test'), false);
    expect(calls.where((c) => c.method == 'show'), isEmpty);
  });
  test('diagnostics are bounded and retain concurrent failures without content',
      () async {
    await Future.wait(List.generate(
        40, (i) => NotificationDiagnostics.record('failure_$i', id: i)));
    final log = await NotificationDiagnostics.read();
    expect(log.length, 30);
    expect(jsonDecode(log.first)['id'], 39);
    expect(jsonDecode(log.last)['id'], 10);
    expect(log.join(), isNot(contains('Private')));
  });
}
