import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/active_alarm.dart';
import '../domain/notification_service.dart';
import '../../security/domain/app_lock_provider.dart';
import '../../security/presentation/app_lock_screen.dart';
import 'alarm_ring_screen.dart';

/// Keeps notification startup and the navigator alive behind an opaque lock.
class AlarmOverlay extends ConsumerStatefulWidget {
  final Widget child;
  const AlarmOverlay({super.key, required this.child});

  @override
  ConsumerState<AlarmOverlay> createState() => _AlarmOverlayState();
}

class _AlarmOverlayState extends ConsumerState<AlarmOverlay> {
  @override
  void initState() {
    super.initState();
    NotificationService.instance.initialize().catchError((Object error) {
      NotificationService.recordFailure(error);
    });
  }

  @override
  Widget build(BuildContext context) {
    final lock = ref.watch(appLockProvider);
    final locked = lock.isLoading || (lock.isEnabled && lock.isLocked);
    return ValueListenableBuilder(
      valueListenable: activeAlarm,
      builder: (context, alarm, _) => Stack(fit: StackFit.expand, children: [
        Offstage(
            offstage: locked || alarm != null,
            child: TickerMode(
                enabled: !locked && alarm == null, child: widget.child)),
        if (locked && alarm == null)
          lock.isLoading
              ? const Scaffold(body: Center(child: CircularProgressIndicator()))
              : const AppLockScreen(),
        if (alarm != null)
          AlarmRingScreen(
              key: ValueKey(alarm),
              alarm: alarm,
              appLocked: locked,
              onClosed: () {
                if (identical(activeAlarm.value, alarm))
                  activeAlarm.value = null;
              }),
      ]),
    );
  }
}
