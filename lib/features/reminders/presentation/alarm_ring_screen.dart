import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/db/app_database.dart';
import '../domain/notification_service.dart';
import '../domain/alarm_payload.dart';
import '../domain/reminder_scheduler.dart';

/// Full-screen intent UI displayed when an alarm rings
class AlarmRingScreen extends StatefulWidget {
  final AlarmPayload alarm;
  final bool appLocked;
  final VoidCallback onClosed;

  const AlarmRingScreen(
      {super.key,
      required this.alarm,
      required this.appLocked,
      required this.onClosed});

  int get alarmId => alarm.id;
  int? get taskId => alarm.taskId;
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
  String? _error;
  String? _notice;
  Timer? _expiryTimer;
  late String _motivationalPhrase;

  static const _motivationalPhrasesAr = [
    'يلا نبدأ يا بطل! 🚀',
    'وقت الإنجاز حان! ⏱️',
    'خطوة جديدة نحو هدفك! 🎯',
    'أنت قدها.. ابدأ الآن! 💪',
    'تركيز وإنجاز.. يومك مميز! ✨',
    'كل دقيقة تصنع فارقاً! 🌟',
  ];

  static const _motivationalPhrasesEn = [
    "Let's get started, champion! 🚀",
    "Time to achieve! ⏱️",
    "A new step towards your goal! 🎯",
    "You got this.. start now! 💪",
    "Focus and execute.. your day is special! ✨",
    "Every minute makes a difference! 🌟",
  ];

  @override
  void initState() {
    super.initState();
    _taskTitle = widget.alarm.title;
    _currentTime = DateTime.now();

    final isArabic = widget.alarm.languageCode != 'en';
    final phrases = isArabic ? _motivationalPhrasesAr : _motivationalPhrasesEn;
    final index = (widget.alarm.id.abs() + DateTime.now().minute) % phrases.length;
    _motivationalPhrase = phrases[index];

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

    final expires = widget.alarm.expiresAt ??
        DateTime.now().add(const Duration(minutes: 5));
    final remaining = expires.difference(DateTime.now());
    _expiryTimer =
        Timer(remaining.isNegative ? Duration.zero : remaining, _stopAlarm);

    _loadTaskDetails();
  }

  Future<void> _acquireScreen() async {
    const channel = MethodChannel('com.enjaz.app/assistant');
    try {
      await channel.invokeMethod('setAlarmScreen', {'enabled': true});
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
    _expiryTimer?.cancel();
    const MethodChannel('com.enjaz.app/assistant').invokeMethod<void>(
        'setAlarmScreen', {'enabled': false}).catchError((_) {});
    _clockTimer.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _stopAlarm() async {
    if (_actionInProgress) return;
    setState(() {
      _actionInProgress = true;
      _error = null;
    });
    try {
      await NotificationService.instance.cancelNotification(widget.alarmId);
      if (mounted) widget.onClosed();
    } catch (_) {
      if (mounted)
        setState(() {
          _actionInProgress = false;
          _error = Localizations.localeOf(context).languageCode == 'ar'
              ? 'تعذّر إيقاف المنبّه. حاول مرة أخرى.'
              : 'Could not stop the alarm. Try again.';
        });
    }
  }

  Future<void> _startExecutingOrStop() async {
    if (_actionInProgress) return;
    setState(() {
      _actionInProgress = true;
      _error = null;
    });
    try {
      await NotificationService.instance.cancelNotification(widget.alarmId);

      // If linked to a task that is 'todo', transition it to 'in_progress'
      if (widget.taskId != null && _loadedTask != null && _loadedTask!.status == 'todo') {
        try {
          final db = AppDatabase();
          await db.updateTaskStatus(task: _loadedTask!, newStatus: 'in_progress');
          await db.close();
        } catch (_) {}
      }

      if (mounted) widget.onClosed();
    } catch (_) {
      if (mounted) {
        setState(() {
          _actionInProgress = false;
          _error = Localizations.localeOf(context).languageCode == 'ar'
              ? 'تعذّر إيقاف المنبّه. حاول مرة أخرى.'
              : 'Could not stop the alarm. Try again.';
        });
      }
    }
  }

  Future<void> _snoozeAlarm() async {
    if (_actionInProgress) return;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    setState(() {
      _actionInProgress = true;
      _error = null;
      _notice = null;
    });
    try {
      final result = await NotificationService.instance.scheduleAlarm(
        id: widget.alarmId,
        title: widget.alarm.title,
        body: isAr ? 'تأجيل المنبه (5 دقائق)' : 'Alarm Snooze (5 min)',
        scheduledDateTime: DateTime.now().add(const Duration(minutes: 5)),
        payload: widget.alarm.owner,
        languageCode: widget.alarm.languageCode,
        isSensitive: widget.alarm.sensitive,
        isSnooze: true,
      );
      if (!mounted) return;
      if (result == AlarmScheduleResult.failed)
        throw StateError('snooze_failed');
      _expiryTimer?.cancel();
      // Keep a visible confirmation until dismissed; release screen wake now.
      await const MethodChannel('com.enjaz.app/assistant').invokeMethod<void>(
          'setAlarmScreen', {'enabled': false}).catchError((_) {});
      if (!mounted) return;
      setState(() {
        _notice = result == AlarmScheduleResult.exact
            ? (isAr
                ? 'تم تأجيل المنبّه 5 دقائق.'
                : 'Alarm snoozed for 5 minutes.')
            : (isAr
                ? 'تم التأجيل، لكن قد يتأخر التنبيه لعدم توفر إذن التوقيت الدقيق.'
                : 'Snoozed. Delivery may be late without exact alarm permission.');
      });
    } catch (_) {
      if (mounted)
        setState(() {
          _actionInProgress = false;
          _error = isAr
              ? 'تعذّر تأجيل المنبّه. تحقق من صلاحيات التنبيهات وحاول مرة أخرى.'
              : 'Could not snooze. Check notification permissions and try again.';
        });
    }
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
    } catch (_) {
      if (mounted)
        setState(() {
          _actionInProgress = false;
          _error = 'تعذّر إكمال المهمة. حاول مرة أخرى.';
        });
      return;
    }

    if (mounted) widget.onClosed();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final timeStr = DateFormat.jm(isAr ? 'ar' : 'en').format(_currentTime);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          if (_notice != null) {
            widget.onClosed();
          } else {
            _stopAlarm();
          }
        }
      },
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                        child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 20),
                      child: Column(
                        children: [
                          const Spacer(flex: 1),

                          // Pulsing Alarm Icon
                          ScaleTransition(
                            scale: _pulseAnimation,
                            child: Container(
                              padding: const EdgeInsets.all(26),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.errorContainer
                                    .withValues(alpha: 0.3),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.colorScheme.error
                                        .withValues(alpha: 0.25),
                                    blurRadius: 36,
                                    spreadRadius: 8,
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.alarm_on_rounded,
                                size: 68,
                                color: theme.colorScheme.error,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Large Digital Time
                          Text(
                            timeStr,
                            style: theme.textTheme.displayMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Subtitle Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondaryContainer
                                  .withValues(alpha: 0.6),
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

                          // Motivational Badge
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer
                                  .withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: theme.colorScheme.primary
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.auto_awesome_rounded,
                                    size: 18, color: theme.colorScheme.primary),
                                const SizedBox(width: 8),
                                Text(
                                  _motivationalPhrase,
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Task Title Card (Always bold & center)
                          Card(
                            elevation: 0,
                            color: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.65),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22),
                              side: BorderSide(
                                color: theme.colorScheme.outlineVariant
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 24),
                              child: Column(
                                children: [
                                  Text(
                                    _taskTitle,
                                    style: theme.textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      height: 1.35,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  if (_taskDueTime != null || _taskDueDate != null) ...[
                                    const SizedBox(height: 12),
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
                                          '${_taskDueDate ?? ''} ${_taskDueTime ?? ''}'
                                              .trim(),
                                          style: theme.textTheme.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.w600,
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

                          if (_error != null)
                            Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(_error!,
                                    style: TextStyle(
                                        color: theme.colorScheme.error,
                                        fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.center)),
                          if (_notice != null) ...[
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Text(_notice!,
                                  style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center),
                            ),
                            TextButton(
                                onPressed: widget.onClosed,
                                child: Text(isAr ? 'إغلاق' : 'Close')),
                          ],

                          // Primary Action Button: [تمام.. هبدأ التنفيذ] (Big, Prominent)
                          SizedBox(
                            width: double.infinity,
                            height: 60,
                            child: FilledButton.icon(
                              onPressed: _actionInProgress ? null : _startExecutingOrStop,
                              style: FilledButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                foregroundColor: theme.colorScheme.onPrimary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                elevation: 3,
                              ),
                              icon: const Icon(Icons.play_circle_filled_rounded, size: 28),
                              label: Text(
                                isAr ? 'تمام.. هبدأ التنفيذ' : 'Stop Alarm',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Secondary Snooze Button: [تأجيل 5 دقائق]
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
                              icon: const Icon(
                                  Icons.check_circle_outline_rounded,
                                  size: 20),
                              label: Text(isAr
                                  ? 'تمت المهمة وإغلاق'
                                  : 'Mark as Done & Close'),
                            ),
                          ],

                          const SizedBox(height: 12),
                        ],
                      ),
                    )))),
          ),
        ),
      ),
    );
  }
}
