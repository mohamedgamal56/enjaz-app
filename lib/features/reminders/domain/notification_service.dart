import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../../core/db/app_database.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) async {
  final actionId = notificationResponse.actionId;
  final payload = notificationResponse.payload;

  if (payload == null) return;

  final db = AppDatabase();
  try {
    int? taskId;
    if (payload.startsWith('task:')) {
      taskId = int.tryParse(payload.substring(5));
    } else {
      taskId = int.tryParse(payload);
    }

    if (actionId == 'action_done' && taskId != null) {
      final task = await db.getTaskById(taskId);
      if (task != null) {
        await db.updateTaskStatus(task: task, newStatus: 'done');
      }
    } else if (actionId == 'action_snooze' && taskId != null) {
      // Snooze default: 10 minutes
      final snoozeSetting = await db.getSetting('reminder_snooze_duration');
      final snoozeMinutes = int.tryParse(snoozeSetting ?? '10') ?? 10;
      final task = await db.getTaskById(taskId);
      if (task != null) {
        final snoozeTime = DateTime.now().add(Duration(minutes: snoozeMinutes));
        await NotificationService.instance.scheduleAlarm(
          id: (taskId.abs() % 2000000000),
          title: task.title,
          body: 'تأجيل المنبه ($snoozeMinutes د)',
          scheduledDateTime: snoozeTime,
          payload: 'task:$taskId',
        );
      }
    } else if (actionId == 'action_stop') {
      if (taskId != null) {
        await NotificationService.instance.cancelNotification(taskId.abs() % 2000000000);
      }
    }
  } catch (_) {} finally {
    await db.close();
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  static NotificationService get instance => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // Fixed Notification IDs
  static const int idDailySummary = 99901;
  static const int idEveningReview = 99902;
  static const int idWeeklyExcel = 99903;
  static const int idAlarmTest = 99999;

  // New Channel IDs (Roadmap v2.0 Section 5)
  static const String channelAlarmV2 = 'enjaz_alarm_v2';
  static const String channelRemindersV2 = 'enjaz_reminders_v2';

  // For in-memory testing or tracking
  final Map<int, String> activeScheduledPayloads = {};

  /// Initialize notifications plugin and timezone database
  Future<void> initialize({Function(String? payload)? onSelectNotification}) async {
    if (_initialized) return;

    try {
      tz.initializeTimeZones();
    } catch (_) {}

    const androidSettings = AndroidInitializationSettings('@drawable/ic_stat_enjaz');

    const initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) async {
        final actionId = response.actionId;
        final payload = response.payload;
        if (payload != null && actionId != null) {
          notificationTapBackground(response);
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
        // Delete legacy channels so new settings/sounds take effect
        try {
          await androidImplementation.deleteNotificationChannel('enjaz_task_reminders');
          await androidImplementation.deleteNotificationChannel('enjaz_daily_reminders');
          await androidImplementation.deleteNotificationChannel('enjaz_weekly_report');
        } catch (_) {}

        // 1. Dedicated Alarm Channel (Importance.max, alarm audio attributes, ongoing, insistent)
        await androidImplementation.createNotificationChannel(
          const AndroidNotificationChannel(
            channelAlarmV2,
            'تنبيهات المنبه',
            description: 'منبه رنان بصوت واهتزاز متواصل حتى التفاعل',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
            audioAttributesUsage: AudioAttributesUsage.alarm,
          ),
        );

        // 2. High-importance Reminders Channel for normal notifications and summaries
        await androidImplementation.createNotificationChannel(
          const AndroidNotificationChannel(
            channelRemindersV2,
            'تنبيهات المهام والإشعارات',
            description: 'إشعارات المهام والموجز اليومي ومراجعة المساء',
            importance: Importance.high,
            playSound: true,
            enableVibration: true,
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

  /// Schedule an Alarm-type reminder (Insistent, Ongoing, Alarm Category & Audio)
  Future<void> scheduleAlarm({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDateTime,
    String? payload,
    String? languageCode,
    int autoStopMinutes = 5,
  }) async {
    await initialize();
    await cancelNotification(id);

    final isArabic = languageCode != 'en';
    final doneLabel = isArabic ? 'تمت' : 'Done';
    final snoozeLabel = isArabic ? 'تأجيل' : 'Snooze';
    final stopLabel = isArabic ? 'إيقاف' : 'Stop';

    final tzDateTime = tz.TZDateTime.from(scheduledDateTime, tz.local);

    // FLAG_INSISTENT = 4 makes audio/vibration repeat until dismissed
    final androidDetails = AndroidNotificationDetails(
      channelAlarmV2,
      'تنبيهات المنبه',
      channelDescription: 'منبه رنان بصوت واهتزاز متواصل حتى التفاعل',
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.alarm,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      ongoing: true,
      autoCancel: false,
      additionalFlags: Int32List.fromList([4]),
      icon: '@drawable/ic_stat_enjaz',
      timeoutAfter: autoStopMinutes * 60 * 1000,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'action_done',
          doneLabel,
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'action_snooze',
          snoozeLabel,
          showsUserInterface: false,
        ),
        AndroidNotificationAction(
          'action_stop',
          stopLabel,
          showsUserInterface: false,
        ),
      ],
    );

    try {
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tzDateTime,
        NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
      activeScheduledPayloads[id] = payload ?? title;
    } catch (_) {
      try {
        await _notificationsPlugin.zonedSchedule(
          id,
          title,
          body,
          tzDateTime,
          NotificationDetails(android: androidDetails),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: payload,
        );
        activeScheduledPayloads[id] = payload ?? title;
      } catch (_) {}
    }
  }

  /// Schedule a standard Notification-type reminder
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDateTime,
    String? payload,
    String? languageCode,
  }) async {
    await initialize();
    await cancelNotification(id);

    final isArabic = languageCode != 'en';
    final doneLabel = isArabic ? 'تمت' : 'Done';
    final openLabel = isArabic ? 'فتح' : 'Open';

    final tzDateTime = tz.TZDateTime.from(scheduledDateTime, tz.local);

    final androidDetails = AndroidNotificationDetails(
      channelRemindersV2,
      'تنبيهات المهام والإشعارات',
      channelDescription: 'إشعارات المهام والموجز اليومي ومراجعة المساء',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@drawable/ic_stat_enjaz',
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'action_done',
          doneLabel,
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'action_open',
          openLabel,
          showsUserInterface: true,
        ),
      ],
    );

    try {
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tzDateTime,
        NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
      activeScheduledPayloads[id] = payload ?? title;
    } catch (_) {
      try {
        await _notificationsPlugin.zonedSchedule(
          id,
          title,
          body,
          tzDateTime,
          NotificationDetails(android: androidDetails),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: payload,
        );
        activeScheduledPayloads[id] = payload ?? title;
      } catch (_) {}
    }
  }

  /// Test alarm firing in 10 seconds for user verification
  Future<void> testAlarmIn10Seconds({bool isArabic = true}) async {
    final title = isArabic ? 'اختبار المنبه ⏰' : 'Alarm Test ⏰';
    final body = isArabic
        ? 'المنبه يعمل بنجاح! اضغط إيقاف أو تأجيل'
        : 'Alarm test is working! Tap Stop or Snooze';
    final targetTime = DateTime.now().add(const Duration(seconds: 10));

    await scheduleAlarm(
      id: idAlarmTest,
      title: title,
      body: body,
      scheduledDateTime: targetTime,
      payload: 'test_alarm',
      languageCode: isArabic ? 'ar' : 'en',
    );
  }

  /// Cancel notification by ID
  Future<void> cancelNotification(int id) async {
    activeScheduledPayloads.remove(id);
    await _notificationsPlugin.cancel(id);
  }

  /// Schedule Daily Morning Summary (configurable time)
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
    final title = isArabic ? 'الموجز الصباحي ☀️' : 'Morning Summary ☀️';
    final body = isArabic
        ? (todayItemsCount > 0
            ? 'لديك اليوم $todayItemsCount مهمة ومشوار'
            : 'يومك يبدو هادئاً، خطط لأولوياتك')
        : (todayItemsCount > 0
            ? 'You have $todayItemsCount items planned for today'
            : 'Your day looks clear, plan your priorities');

    final now = DateTime.now();
    var scheduledDate = DateTime(now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    final tzDateTime = tz.TZDateTime.from(scheduledDate, tz.local);

    const androidDetails = AndroidNotificationDetails(
      channelRemindersV2,
      'الموجز الصباحي',
      importance: Importance.high,
      priority: Priority.high,
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

  /// Schedule Evening Review (configurable time)
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
      channelRemindersV2,
      'مراجعة المساء',
      importance: Importance.high,
      priority: Priority.high,
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

  /// Schedule Weekly Excel Report reminder (configurable time)
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
      channelRemindersV2,
      'تقرير الإكسيل الأسبوعي',
      importance: Importance.high,
      priority: Priority.high,
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

  /// Reschedule all active reminders
  Future<void> rescheduleAll(AppDatabase db, {String? languageCode}) async {
    await initialize();

    final todayStr = _formatDate(DateTime.now());
    final todayTasks = await db.watchTasksForDate(todayStr).first;

    final morningHour = int.tryParse(await db.getSetting('morning_summary_hour') ?? '8') ?? 8;
    final morningMinute = int.tryParse(await db.getSetting('morning_summary_minute') ?? '0') ?? 0;
    final morningEnabled = (await db.getSetting('morning_summary_enabled')) != 'false';

    await scheduleDailySummary(
      enabled: morningEnabled,
      hour: morningHour,
      minute: morningMinute,
      todayItemsCount: todayTasks.length,
      languageCode: languageCode,
    );

    final eveningHour = int.tryParse(await db.getSetting('evening_review_hour') ?? '21') ?? 21;
    final eveningMinute = int.tryParse(await db.getSetting('evening_review_minute') ?? '0') ?? 0;
    final eveningEnabled = (await db.getSetting('evening_review_enabled')) == 'true';

    await scheduleEveningReview(
      enabled: eveningEnabled,
      hour: eveningHour,
      minute: eveningMinute,
      languageCode: languageCode,
    );

    final weeklyHour = int.tryParse(await db.getSetting('weekly_excel_hour') ?? '18') ?? 18;
    final weeklyMinute = int.tryParse(await db.getSetting('weekly_excel_minute') ?? '0') ?? 0;
    final weeklyEnabled = (await db.getSetting('weekly_excel_enabled')) != 'false';

    await scheduleWeeklyExcelReminder(
      enabled: weeklyEnabled,
      hour: weeklyHour,
      minute: weeklyMinute,
      languageCode: languageCode,
    );
  }

  static String _formatDate(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}
