import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:enjaz/core/l10n/app_localizations.dart';
import 'package:enjaz/features/reminders/domain/active_alarm.dart';
import 'package:enjaz/features/reminders/presentation/alarm_overlay.dart';
import 'package:enjaz/features/security/presentation/app_lock_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('cold legacy alarm works while locked and closing restores lock',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({'app_lock_enabled': true});
    await tester.binding.setSurfaceSize(const Size(450, 1000));
    final cancelled = <int>[];
    final flags = <bool>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/local_auth'), (call) async {
      if (call.method == 'getAvailableBiometrics') return <String>[];
      return false;
    });
    messenger.setMockMethodCallHandler(
        const MethodChannel('com.enjaz.app/privacy'), (call) async => null);
    messenger.setMockMethodCallHandler(
        const MethodChannel('com.enjaz.app/assistant'), (call) async {
      if (call.method == 'setAlarmScreen')
        flags.add(call.arguments['enabled'] as bool);
      if (call.method == 'isDeviceLocked') return true;
      return null;
    });
    messenger.setMockMethodCallHandler(
        const MethodChannel('dexterous.com/flutter/local_notifications'),
        (call) async {
      if (call.method == 'initialize') return true;
      if (call.method == 'getNotificationAppLaunchDetails') {
        return {
          'notificationLaunchedApp': true,
          'notificationResponse': {
            'notificationId': 73,
            'notificationResponseType': 0,
            'payload': 'alarm:task:4',
          }
        };
      }
      if (call.method == 'cancel') cancelled.add(call.arguments['id'] as int);
      return null;
    });
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate
      ],
      builder: (context, child) => AlarmOverlay(child: child!),
      home: const Scaffold(body: Text('Private app content')),
    )));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(activeAlarm.value?.id, 73);
    expect(find.text('Stop Alarm'), findsOneWidget);
    expect(find.text('Private app content'), findsNothing);
    await tester.tap(find.text('Stop Alarm'));
    await tester.pump();
    await tester.pump();
    expect(cancelled, [73]);
    expect(activeAlarm.value, isNull);
    expect(find.byType(AppLockScreen), findsOneWidget);
    expect(find.text('Private app content'), findsNothing);
    expect(flags.last, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.binding.setSurfaceSize(null);
    debugDefaultTargetPlatformOverride = null;
  });
}
