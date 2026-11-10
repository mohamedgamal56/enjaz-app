import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/db/app_database.dart';
import '../../../core/l10n/app_localizations.dart';
import '../domain/notification_service.dart';
import '../domain/reminder_scheduler.dart';

/// Full-screen intent UI displayed when an alarm rings
class AlarmRingScreen extends StatefulWidget {
  final int alarmId;
  final String initialTitle;
  final int? taskId;
  final String payload;

  const AlarmRingScreen({
    super.key,
    required this.alarmId,
    required this.initialTitle,
    this.taskId,
    required this.payload,
  });

  factory AlarmRingScreen.fromPayload(String payload) {
    int? taskId;
    int alarmId = NotificationService.idAlarmTest;
    String title = 'منبه إنجاز';

    if (payload.startsWith('alarm:task:')) {
      taskId = int.tryParse(payload.substring(11));
      if (taskId != null) alarmId = taskId.abs() % 2000000000;
    } else if (payload.startsWith('task:')) {
      taskId = int.tryParse(payload.substring(5));
      if (taskId != null) alarmId = taskId.abs() % 2000000000;
    } else if (payload == 'alarm:test_alarm' || payload == 'test_alarm') {
      alarmId = NotificationService.idAlarmTest;
      title = 'اختبار المنبه ⏰';
    }

    return AlarmRingScreen(
      alarmId: alarmId,
      initialTitle: title,
      taskId: taskId,
      payload: payload,
    );
  }

  @override
  State<AlarmRingScreen> createState() => _AlarmRingScreenState();
}

class _AlarmRingScreenState extends State<AlarmRingScreen>
    with SingleTickerProviderStateMixin {
  late String _taskTitle;
  String? _taskDueDate;
  String? _taskDueTime;
  Task? _loadedTask;
  late Timer _clockTimer;
  late DateTime _currentTime;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _actionInProgress = false;

  @override
  void initState() {
    super.initState();
    _taskTitle = widget.initialTitle;
    _currentTime = DateTime.now();

    // Turn screen on and keep it lit over lock screen
    _acquireScreen();

    // Clock update every second
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _currentTime = DateTime.now());
    });

    // Pulse animation for alarm bell
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadTaskDetails();
  }

  Future<void> _acquireScreen() async {
    try {
      await const MethodChannel('com.enjaz.app/assistant').invokeMethod('turnScreenOn');
    } catch (_) {}
  }

  Future<void> _loadTaskDetails() async {
    if (widget.taskId == null) return;
    try {
      final db = AppDatabase();
      final task = await db.getTaskById(widget.taskId!);
      if (task != null && mounted) {
        setState(() {
          _loadedTask = task;
          _taskTitle = task.title;
          _taskDueDate = task.dueDate;
          _taskDueTime = task.dueTime;
        });
      }
      await db.close();
    } catch (_) {}
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _stopAlarm() async {
    if (_actionInProgress) return;
    setState(() => _actionInProgress = true);

    try {
      await NotificationService.instance.cancelNotification(widget.alarmId);
      if (widget.taskId != null) {
        await NotificationService.instance.cancelNotification(
          widget.taskId!.abs() % 2000000000,
        );
      }
    } catch (_) {}

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _snoozeAlarm() async {
    if (_actionInProgress) return;
    setState(() => _actionInProgress = true);

    try {
      await NotificationService.instance.cancelNotification(widget.alarmId);
      if (widget.taskId != null) {
        await NotificationService.instance.cancelNotification(
          widget.taskId!.abs() % 2000000000,
        );
      }

      final snoozeTime = DateTime.now().add(const Duration(minutes: 5));
      final isAr = Localizations.localeOf(context).languageCode == 'ar';
      await NotificationService.instance.scheduleAlarm(
        id: widget.alarmId,
        title: _taskTitle,
        body: isAr ? 'تأجيل المنبه (5 دقائق)' : 'Alarm Snooze (5 min)',
        scheduledDateTime: snoozeTime,
        payload: widget.payload,
      );
    } catch (_) {}

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _markDoneAndClose() async {
    if (_actionInProgress || _loadedTask == null) return;
    setState(() => _actionInProgress = true);

    try {
      final db = AppDatabase();
      await db.updateTaskStatus(task: _loadedTask!, newStatus: 'done');
      await ReminderScheduler(db: db).cancelAllForOwner('task', widget.taskId!);
      await NotificationService.instance.cancelNotification(widget.alarmId);
      await db.close();
    } catch (_) {}

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final timeStr = DateFormat.jm(isAr ? 'ar' : 'en').format(_currentTime);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _stopAlarm();
      },
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              children: [
                const Spacer(flex: 1),

                // Pulsing Alarm Icon
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.error.withValues(alpha: 0.25),
                          blurRadius: 36,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.alarm_on_rounded,
                      size: 72,
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Large Digital Time
                Text(
                  timeStr,
                  style: theme.textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),

                // Subtitle
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isAr ? 'حان موعد التنبيه ⏰' : 'Alarm Due Now ⏰',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),

                const Spacer(flex: 1),

                // Task Title Card
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    child: Column(
                      children: [
                        Text(
                          _taskTitle,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            height: 1.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (_taskDueTime != null || _taskDueDate != null) ...[
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 16,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${_taskDueDate ?? ''} ${_taskDueTime ?? ''}'.trim(),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const Spacer(flex: 2),

                // Primary Stop Alarm Button (Big, Prominent)
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: FilledButton.icon(
                    onPressed: _actionInProgress ? null : _stopAlarm,
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.error,
                      foregroundColor: theme.colorScheme.onError,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.alarm_off_rounded, size: 26),
                    label: Text(
                      isAr ? 'إيقاف المنبه' : 'Stop Alarm',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Snooze 5 Minutes Button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton.tonalIcon(
                    onPressed: _actionInProgress ? null : _snoozeAlarm,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    icon: const Icon(Icons.snooze_rounded, size: 24),
                    label: Text(
                      isAr ? 'تأجيل 5 دقائق' : 'Snooze 5 min',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                // Optional: Mark Done Button if linked to a task
                if (_loadedTask != null && _loadedTask!.status != 'done') ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _actionInProgress ? null : _markDoneAndClose,
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                    label: Text(isAr ? 'تمت المهمة وإغلاق' : 'Mark as Done & Close'),
                  ),
                ],

                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
