import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:enjaz/features/reminders/domain/alarm_payload.dart';
import 'package:enjaz/features/reminders/domain/notification_diagnostics.dart';
import 'package:enjaz/features/reminders/presentation/alarm_ring_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting());
  const notifications =
      MethodChannel('dexterous.com/flutter/local_notifications');
  const native = MethodChannel('com.enjaz.app/assistant');
  final calls = <MethodCall>[];
  final screenFlags = <bool>[];
  final pending = <int>{};
  bool enabled = true, retained = true, exact = true, closed = false;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({});
    calls.clear();
    screenFlags.clear();
    pending.clear();
    pending.addAll([4, 73, 92]);
    enabled = retained = exact = true;
    closed = false;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(native, (call) async {
      if (call.method == 'setAlarmScreen')
        screenFlags.add(call.arguments['enabled'] as bool);
      if (call.method == 'isDeviceLocked') return true;
      return null;
    });
    messenger.setMockMethodCallHandler(notifications, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'initialize':
          return true;
        case 'areNotificationsEnabled':
          return enabled;
        case 'canScheduleExactNotifications':
          return exact;
        case 'getNotificationChannels':
          return [];
        case 'cancel':
          pending.remove(call.arguments['id']);
          return null;
        case 'zonedSchedule':
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

  Future<void> show(WidgetTester tester) async {
    NotificationDiagnostics.resetPendingWritesForTest();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.binding.setSurfaceSize(const Size(450, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        home: AlarmRingScreen(
            alarm: const AlarmPayload(
                id: 73, owner: 'task:4', title: 'Secret task'),
            appLocked: true,
            onClosed: () {
              closed = true;
            })));
    await tester.pump();
  }

  Future<void> remove(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    debugDefaultTargetPlatformOverride = null;
  }

  testWidgets('Stop cancels only the actual alarm, then releases wake flags',
      (tester) async {
    await show(tester);
    expect(find.text('Secret task'), findsNothing);
    expect(screenFlags, contains(true));
    await tester.tap(find.text('Stop Alarm'));
    await tester.pump();
    expect(closed, isTrue);
    expect(pending, containsAll([4, 92]));
    expect(pending, isNot(contains(73)));
    expect(
        calls.where((c) => c.method == 'cancel').map((c) => c.arguments['id']),
        [73]);
    await remove(tester);
    expect(screenFlags.last, isFalse);
  });
  testWidgets(
      'Snooze preserves ID, confirms success and leaves other reminders alone',
      (tester) async {
    await show(tester);
    await tester.tap(find.text('Snooze 5 min'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump();
    await tester.pump();
    final scheduled = calls.singleWhere((c) => c.method == 'zonedSchedule');
    expect(scheduled.arguments['id'], 73);
    expect(AlarmPayload.decode(scheduled.arguments['payload'])!.taskId, 4);
    expect(pending, containsAll([4, 73, 92]));
    expect(find.text('Alarm snoozed for 5 minutes.'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pump();
    expect(closed, isTrue);
    expect(pending, contains(73));
    await remove(tester);
  });
  for (final reason in ['permission', 'missing request']) {
    testWidgets('Failed snooze ($reason) remains visible and permits retry',
        (tester) async {
      await show(tester);
      if (reason == 'permission') {
        enabled = false;
      } else {
        retained = false;
      }
      await tester.tap(find.text('Snooze 5 min'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pump();
      await tester.pump();
      expect(closed, isFalse);
      expect(find.textContaining('Could not snooze.'), findsOneWidget);
      enabled = retained = true;
      await tester.tap(find.text('Snooze 5 min'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pump();
      await tester.pump();
      expect(find.text('Alarm snoozed for 5 minutes.'), findsOneWidget);
      await remove(tester);
    });
  }
  testWidgets('Inexact fallback shows a warning rather than an exact promise',
      (tester) async {
    exact = false;
    await show(tester);
    await tester.tap(find.text('Snooze 5 min'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Delivery may be late'), findsOneWidget);
    await remove(tester);
  });
}
