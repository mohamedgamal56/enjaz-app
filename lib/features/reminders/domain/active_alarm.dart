import 'package:flutter/foundation.dart';
import 'alarm_payload.dart';

/// Lives above the app navigator so Stop/Snooze remain available while locked.
final activeAlarm = ValueNotifier<AlarmPayload?>(null);
