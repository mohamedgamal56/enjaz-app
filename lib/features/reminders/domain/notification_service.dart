import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:drift/drift.dart' as drift;

import '../../../core/db/app_database.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) async {
  // Handle background actions like marking a task as done
  final actionId = notificationResponse.actionId;
  final payload = notificationResponse.payload;

  if (actionId == 'action_done' && payload != null) {
    final taskId = int.tryParse(payload);
    if (taskId != null) {
      final db = AppDatabase();
      final task = await db.getTaskById(taskId);
      if (task != null) {
        await db.updateTaskStatus(task: task, newStatus: 'done');
      }
      await db.close();
    }
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // Fixed Notification IDs
  static const int idDailySummary = 99901;
  static const int idEveningReview = 99902;
  static const int idWeeklyExcel = 99903;

  // Channel IDs
  static const String channelTaskReminders = 'enjaz_task_reminders';
  static const String channelDailyReminders = 'enjaz_daily_reminders';
  static const String channelWeeklyReport = 'enjaz_weekly_report';

  /// Initialize notifications plugin and timezone database
  Future<void> initialize({Function(String? payload)? onSelectNotification}) async {
    if (_initialized) return;

    tz.initializeTimeZones();

    // Android Settings
    const androidSettings = AndroidInitializationSettings('@drawable/ic_stat_enjaz');

    const initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) async {
        if (response.actionId == 'action_done' && response.payload != null) {
          final taskId = int.tryParse(response.payload!);
          if (taskId != null) {
            final db = AppDatabase();
            final task = await db.getTaskById(taskId);
            if (task != null) {
              await db.updateTaskStatus(task: task, newStatus: 'done');
            }
            await db.close();
          }
        } else if (onSelectNotification != null) {
          onSelectNotification(response.payload);
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // Create Notification Channels for Android 8.0+
    if (Platform.isAndroid) {
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        await androidImplementation.createNotificationChannel(
          const AndroidNotificationChannel(
            channelTaskReminders,
            'تنبيهات المهام (Task Reminders)',
            description: 'تنبيهات مواعيد المهام والمشاوير المحددة',
            importance: Importance.max,
            enableVibration: true,
          ),
        );

        await androidImplementation.createNotificationChannel(
          const AndroidNotificationChannel(
            channelDailyReminders,
            'الموجز اليومي والمراجعة (Daily Summary & Review)',
            description: 'ملخص الصباح ومراجعة المساء لمهام اليوم',
            importance: Importance.defaultImportance,
          ),
        );

        await androidImplementation.createNotificationChannel(
          const AndroidNotificationChannel(
            channelWeeklyReport,
            'تذكير تقرير الإكسيل (Weekly Report)',
            description: 'تذكير مراجعة وتصدير تقرير الإكسيل الأسبوعي',
            importance: Importance.defaultImportance,
          ),
        );
      }
    }

    _initialized = true;
  }

  /// Request POST_NOTIFICATIONS permission on Android 13+
  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        final granted = await androidImplementation.requestNotificationsPermission();
        return granted ?? false;
      }
    }
    return true;
  }

  /// Check if exact alarms are allowed
  Future<bool> areExactAlarmsPermitted() async {
    if (Platform.isAndroid) {
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        final granted = await androidImplementation.requestExactAlarmsPermission();
        return granted ?? false;
      }
    }
    return true;
  }

  /// Schedule a reminder for a specific task
  Future<void> scheduleTaskReminder({
    required Task task,
    int defaultDateOnlyHour = 9,
    int defaultDateOnlyMinute = 0,
    String? languageCode,
  }) async {
    if (task.reminderOffsetMinutes == null || task.dueDate == null) {
      await cancelTaskReminder(task.id);
      return;
    }

    // Parse dueDate: YYYY-MM-DD
    final dateParts = task.dueDate!.split('-');
    if (dateParts.length != 3) return;
    final year = int.tryParse(dateParts[0]) ?? 0;
    final month = int.tryParse(dateParts[1]) ?? 0;
    final day = int.tryParse(dateParts[2]) ?? 0;

    int hour = defaultDateOnlyHour;
    int minute = defaultDateOnlyMinute;

    if (task.dueTime != null && task.dueTime!.contains(':')) {
      final timeParts = task.dueTime!.split(':');
      hour = int.tryParse(timeParts[0]) ?? defaultDateOnlyHour;
      minute = int.tryParse(timeParts[1]) ?? defaultDateOnlyMinute;
    }

    DateTime targetDateTime = DateTime(year, month, day, hour, minute);

    // Apply offset minutes
    final offset = task.reminderOffsetMinutes ?? 0;
    targetDateTime = targetDateTime.subtract(Duration(minutes: offset));

    if (targetDateTime.isBefore(DateTime.now())) {
      // Past reminder time, do not schedule
      return;
    }

    final tzDateTime = tz.TZDateTime.from(targetDateTime, tz.local);

    final isArabic = languageCode != 'en';
    final doneLabel = isArabic ? 'تمت' : 'Done';
    final openLabel = isArabic ? 'فتح' : 'Open';

    final androidDetails = AndroidNotificationDetails(
      channelTaskReminders,
      'تنبيهات المهام',
      channelDescription: 'تنبيهات مواعيد المهام والمشاوير المحددة',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@drawable/ic_stat_enjaz',
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'action_done',
          doneLabel,
          showsUserInterface: false,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          'action_open',
          openLabel,
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ],
    );

    final details = NotificationDetails(android: androidDetails);

    final body = task.kind == 'errand'
        ? (task.locationText != null && task.locationText!.isNotEmpty
            ? '${isArabic ? "مشوار في: " : "Errand at: "}${task.locationText}'
            : (isArabic ? 'مشوار موعده اقترب' : 'Errand due soon'))
        : (task.notes != null && task.notes!.isNotEmpty
            ? task.notes!
            : (isArabic ? 'موعد إنجاز المهمة' : 'Task due now'));

    try {
      await _notificationsPlugin.zonedSchedule(
        task.id,
        task.title,
        body,
        tzDateTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: task.id.toString(),
      );
    } catch (_) {
      // Fallback to inexact if exact alarm permission is not granted
      await _notificationsPlugin.zonedSchedule(
        task.id,
        task.title,
        body,
        tzDateTime,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: task.id.toString(),
      );
    }
  }

  /// Cancel reminder for a task
  Future<void> cancelTaskReminder(int taskId) async {
    await _notificationsPlugin.cancel(taskId);
  }

  /// Schedule Daily Morning Summary (default 08:00)
  Future<void> scheduleDailySummary({
    required bool enabled,
    required int hour,
    required int minute,
    int todayItemsCount = 0,
    String? languageCode,
  }) async {
    await _notificationsPlugin.cancel(idDailySummary);
    if (!enabled) return;

    final isArabic = languageCode != 'en';
    final title = isArabic ? 'صباح الإنجاز ☀️' : 'Good Morning ☀️';
    final body = todayItemsCount > 0
        ? (isArabic
            ? 'عندك $todayItemsCount مهام ومشاوير النهارده'
            : 'You have $todayItemsCount items today')
        : (isArabic
            ? 'يوم جديد! راجع مهامك ورتب أولوياتك'
            : 'A new day! Check your tasks and set priorities');

    final now = DateTime.now();
    var scheduledDate = DateTime(now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    final tzDateTime = tz.TZDateTime.from(scheduledDate, tz.local);

    const androidDetails = AndroidNotificationDetails(
      channelDailyReminders,
      'الموجز اليومي',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@drawable/ic_stat_enjaz',
    );

    try {
      await _notificationsPlugin.zonedSchedule(
        idDailySummary,
        title,
        body,
        tzDateTime,
        const NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'today_summary',
      );
    } catch (_) {}
  }

  /// Schedule Evening Review (default 21:00)
  Future<void> scheduleEveningReview({
    required bool enabled,
    required int hour,
    required int minute,
    String? languageCode,
  }) async {
    await _notificationsPlugin.cancel(idEveningReview);
    if (!enabled) return;

    final isArabic = languageCode != 'en';
    final title = isArabic ? 'مراجعة المساء 🌙' : 'Evening Review 🌙';
    final body = isArabic
        ? 'راجع يومك وحدّث حالة مهامك'
        : 'Review your day and update your tasks';

    final now = DateTime.now();
    var scheduledDate = DateTime(now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    final tzDateTime = tz.TZDateTime.from(scheduledDate, tz.local);

    const androidDetails = AndroidNotificationDetails(
      channelDailyReminders,
      'مراجعة المساء',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@drawable/ic_stat_enjaz',
    );

    try {
      await _notificationsPlugin.zonedSchedule(
        idEveningReview,
        title,
        body,
        tzDateTime,
        const NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'evening_review',
      );
    } catch (_) {}
  }

  /// Schedule Weekly Excel Report reminder (Friday 18:00)
  Future<void> scheduleWeeklyExcelReminder({
    required bool enabled,
    required int hour,
    required int minute,
    String? languageCode,
  }) async {
    await _notificationsPlugin.cancel(idWeeklyExcel);
    if (!enabled) return;

    final isArabic = languageCode != 'en';
    final title = isArabic ? 'تقرير إنجاز الأسبوعي 📊' : 'Weekly Excel Report 📊';
    final body = isArabic
        ? 'تقرير الأسبوع جاهز، اضغط للمراجعة والتصدير'
        : 'Your weekly report is ready. Tap to review and export';

    final now = DateTime.now();
    // Friday is weekday 5
    int daysUntilFriday = (DateTime.friday - now.weekday) % 7;
    var scheduledDate = DateTime(
      now.year,
      now.month,
      now.day + daysUntilFriday,
      hour,
      minute,
    );
    if (daysUntilFriday == 0 && scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 7));
    }

    final tzDateTime = tz.TZDateTime.from(scheduledDate, tz.local);

    const androidDetails = AndroidNotificationDetails(
      channelWeeklyReport,
      'تقرير الإكسيل الأسبوعي',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@drawable/ic_stat_enjaz',
    );

    try {
      await _notificationsPlugin.zonedSchedule(
        idWeeklyExcel,
        title,
        body,
        tzDateTime,
        const NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: 'weekly_excel',
      );
    } catch (_) {}
  }

  /// Reschedule all active reminders (on app start, reboot, or timezone change)
  Future<void> rescheduleAll(AppDatabase db, {String? languageCode}) async {
    await initialize();

    final todayStr = _formatDate(DateTime.now());
    final upcomingTasks = await db.getUpcomingTasksWithReminders(todayStr);

    for (final task in upcomingTasks) {
      await scheduleTaskReminder(task: task, languageCode: languageCode);
    }

    // Schedule default daily reminders
    final todayTasks = await db.watchTasksForDate(todayStr).first;
    await scheduleDailySummary(
      enabled: true,
      hour: 8,
      minute: 0,
      todayItemsCount: todayTasks.length,
      languageCode: languageCode,
    );

    await scheduleEveningReview(
      enabled: false,
      hour: 21,
      minute: 0,
      languageCode: languageCode,
    );

    await scheduleWeeklyExcelReminder(
      enabled: true,
      hour: 18,
      minute: 0,
      languageCode: languageCode,
    );
  }

  static String _formatDate(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}
