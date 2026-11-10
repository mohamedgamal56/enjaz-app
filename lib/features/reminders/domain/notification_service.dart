import 'dart:io';
import 'alarm_payload.dart';
import 'active_alarm.dart';
import 'notification_diagnostics.dart';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../../core/db/app_database.dart';
import 'reminder_scheduler.dart';

@pragma('vm:entry-point')
void notificationTapBackground(
  NotificationResponse notificationResponse,
) async {
  final actionId = notificationResponse.actionId;
  final payload = notificationResponse.payload;

  if (payload == null) return;

  final alarm =
      AlarmPayload.decode(payload, notificationId: notificationResponse.id);
  final owner = alarm?.owner ?? payload;
  final db = AppDatabase();
  try {
    int? taskId;
    if (owner.startsWith('task:')) {
      taskId = int.tryParse(owner.substring(5));
    } else {
      taskId = int.tryParse(owner);
    }

    if (actionId == 'action_done' && taskId != null) {
      final task = await db.getTaskById(taskId);
      if (task != null) {
        await db.updateTaskStatus(task: task, newStatus: 'done');
        await ReminderScheduler(db: db).cancelAllForOwner('task', taskId);
      }
    } else if (actionId == 'action_snooze' && notificationResponse.id != null) {
      final id = notificationResponse.id!;
      final result = await NotificationService.instance.scheduleAlarm(
        id: id,
        title: alarm?.title ?? 'منبه إنجاز',
        body: 'تأجيل المنبه (5 دقائق)',
        scheduledDateTime: DateTime.now().add(const Duration(minutes: 5)),
        payload: alarm?.owner ?? owner,
        languageCode: alarm?.languageCode,
        isSensitive: alarm?.sensitive ?? true,
        isSnooze: true,
      );
      if (result == AlarmScheduleResult.failed) {
        await NotificationService.instance.showSnoozeFailure(id);
      }
    } else if (actionId == 'action_stop' && notificationResponse.id != null) {
      await NotificationService.instance
          .cancelNotification(notificationResponse.id!);
    }
  } catch (_) {
  } finally {
    await db.close();
  }
}

enum AlarmScheduleResult { exact, inexact, failed }

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  static NotificationService get instance => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  Future<void>? _initializing;
  String? _pendingLaunchPayload;
  Function(String?)? _onSelectNotification;

  // Fixed Notification IDs
  static const int idDailySummary = 99901;
  static const int idEveningReview = 99902;
  static const int idWeeklyExcel = 99903;
  static const int idAlarmTest = 99999;

  // Confirmed Alarm Channel ID and Name
  static const String channelAlarm = 'enjaz_alarm_v5_music';
  static const String channelAlarmV2 = channelAlarm;
  static const String channelAlarmV3 = channelAlarm;
  static const String channelAlarmName = 'منبه إنجاز الحقيقي';
  static const String channelRemindersV2 = 'enjaz_reminders_v2';

  // For in-memory testing or tracking
  final Map<int, String> activeScheduledPayloads = {};

  /// Initialize notifications plugin and timezone database
  Future<void> initialize({
    Function(String? payload)? onSelectNotification,
  }) async {
    if (onSelectNotification != null)
      _onSelectNotification = onSelectNotification;
    if (_initialized) {
      if (_pendingLaunchPayload != null && _onSelectNotification != null) {
        final payload = _pendingLaunchPayload;
        _pendingLaunchPayload = null;
        _onSelectNotification!(payload);
      }
      return;
    }
    await (_initializing ??= _initializePlugin());
  }

  Future<void> _initializePlugin() async {
    try {
      try {
        tz.initializeTimeZones();
        final zone = await const MethodChannel('com.enjaz.app/assistant')
            .invokeMethod<String>('timezone');
        if (zone != null) tz.setLocalLocation(tz.getLocation(zone));
      } catch (_) {}

      const androidSettings = AndroidInitializationSettings(
        'ic_stat_enjaz',
      );

      const initSettings = InitializationSettings(android: androidSettings);

      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) async {
          final actionId = response.actionId;
          final payload = response.payload;
          if (actionId == 'action_stop') {
            if (response.id != null) {
              await cancelNotification(response.id!);
            }
          } else if (actionId == 'action_snooze') {
            notificationTapBackground(response);
          } else if (payload != null &&
              actionId != null &&
              actionId.isNotEmpty &&
              actionId != 'action_open') {
            notificationTapBackground(response);
          } else {
            _deliverResponse(response);
          }
        },
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );

      // Create Notification Channels for Android 8.0+
      if (Platform.isAndroid) {
        final androidImplementation =
            _notificationsPlugin.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

        if (androidImplementation != null) {
          // Delete legacy channels so new settings/sounds take effect
          try {
            await androidImplementation.deleteNotificationChannel(
              'enjaz_task_reminders',
            );
            await androidImplementation.deleteNotificationChannel(
              'enjaz_daily_reminders',
            );
            await androidImplementation.deleteNotificationChannel(
              'enjaz_weekly_report',
            );
            await androidImplementation.deleteNotificationChannel(
              'enjaz_alarm_v2',
            );
          } catch (_) {}

          try {
            await androidImplementation
                .deleteNotificationChannel('enjaz_alarm_v3');
          } catch (_) {}

          try {
            await androidImplementation.deleteNotificationChannel('enjaz_alarm_channel');
          } catch (_) {}

          // Dedicated Alarm Channel (id: enjaz_alarm_v5_music, name: منبه إنجاز الحقيقي)
          await androidImplementation.createNotificationChannel(
            const AndroidNotificationChannel(
              channelAlarm,
              channelAlarmName,
              description: 'منبه رنان بصوت واهتزاز متواصل حتى التفاعل',
              importance: Importance.max,
              playSound: true,
              enableVibration: true,
              enableLights: true,
              audioAttributesUsage: AudioAttributesUsage.alarm,
              sound: RawResourceAndroidNotificationSound('alarm_sound'),
            ),
          );

          // 2. High-importance Reminders Channel for normal notifications and summaries
          await androidImplementation.createNotificationChannel(
            const AndroidNotificationChannel(
              channelRemindersV2,
              'تنبيهات المهام والإشعارات',
              description: 'إشعارات المهام والموجز اليومي ومراجعة المساء',
              importance: Importance.max,
              playSound: true,
              enableVibration: true,
              enableLights: true,
            ),
          );
        }
      }

      _initialized = true;
      final launch =
          await _notificationsPlugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp == true) {
        final response = launch!.notificationResponse;
        if (response != null &&
            response.actionId != null &&
            response.actionId!.isNotEmpty &&
            response.actionId != 'action_open') {
          notificationTapBackground(response);
        } else {
          if (response != null) _deliverResponse(response);
        }
      }
    } catch (error) {
      _initialized = false;
      await recordFailure(error);
      rethrow;
    } finally {
      _initializing = null;
    }
  }

  void _deliverResponse(NotificationResponse response) {
    final alarm =
        AlarmPayload.decode(response.payload, notificationId: response.id);
    if (alarm != null) {
      activeAlarm.value = alarm;
    } else if (_onSelectNotification != null) {
      _onSelectNotification!(response.payload);
    } else {
      _pendingLaunchPayload = response.payload;
    }
  }

  Future<void> showSnoozeFailure(int id) async {
    await _notificationsPlugin.show(
        id,
        'تعذّر تأجيل المنبّه',
        'افتح إنجاز وتحقق من صلاحيات التنبيهات ثم أعد المحاولة.',
        const NotificationDetails(
            android: AndroidNotificationDetails(
          channelRemindersV2,
          'تنبيهات المهام والإشعارات',
          icon: 'ic_stat_enjaz',
          importance: Importance.high,
        )));
  }

  AndroidFlutterLocalNotificationsPlugin? get android =>
      _notificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  static Future<void> recordFailure(Object error, {int? id}) =>
      NotificationDiagnostics.record(
          error is PlatformException
              ? error.code
              : error.runtimeType.toString(),
          id: id);

  Future<AlarmScheduleResult> _scheduleChecked({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime date,
    required NotificationDetails details,
    String? payload,
    DateTimeComponents? repeats,
    bool exact = true,
  }) async {
    activeScheduledPayloads.remove(id);
    try {
      if (await android?.areNotificationsEnabled() == false) {
        await NotificationDiagnostics.record('notifications_disabled', id: id);
        return AlarmScheduleResult.failed;
      }
      final channels = await android?.getNotificationChannels();
      final blocked = channels?.any((c) =>
              c.id == details.android?.channelId &&
              c.importance == Importance.none) ??
          false;
      if (blocked) {
        await NotificationDiagnostics.record('channel_disabled', id: id);
        return AlarmScheduleResult.failed;
      }
      final canExact = await android?.canScheduleExactNotifications();
      final permitted = !exact || canExact != false;
      var useExact = exact && permitted;
      Future<void> schedule(bool precise) => _notificationsPlugin.zonedSchedule(
            id,
            title,
            body,
            date,
            details,
            androidScheduleMode: precise
                ? AndroidScheduleMode.exactAllowWhileIdle
                : AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            payload: payload,
            matchDateTimeComponents: repeats,
          );
      try {
        await schedule(useExact);
      } on PlatformException catch (error) {
        if (!useExact || error.code != 'exact_alarms_not_permitted') rethrow;
        await schedule(false);
        useExact = false;
      }
      final pending = await _notificationsPlugin.pendingNotificationRequests();
      if (!pending.any((request) => request.id == id)) {
        activeScheduledPayloads.remove(id);
        await NotificationDiagnostics.record('schedule_not_found', id: id);
        return AlarmScheduleResult.failed;
      }
      activeScheduledPayloads[id] = payload ?? title;
      await NotificationDiagnostics.record(
          exact && !useExact ? 'inexact_fallback' : 'scheduled',
          id: id);
      return useExact ? AlarmScheduleResult.exact : AlarmScheduleResult.inexact;
    } catch (error) {
      await recordFailure(error, id: id);
      return AlarmScheduleResult.failed;
    }
  }

  Future<List<PendingNotificationRequest>> pendingRequests() =>
      _notificationsPlugin.pendingNotificationRequests();

  Future<bool> testImmediateNotification(String title, String body) async {
    try {
      await initialize();
      if (await android?.areNotificationsEnabled() == false) {
        await NotificationDiagnostics.record('notifications_disabled',
            id: 99998);
        return false;
      }
      final channels = await android?.getNotificationChannels();
      if (channels?.any((c) =>
              c.id == channelRemindersV2 && c.importance == Importance.none) ??
          false) {
        await NotificationDiagnostics.record('channel_disabled', id: 99998);
        return false;
      }
      await _notificationsPlugin.show(
          99998,
          title,
          body,
          const NotificationDetails(
              android: AndroidNotificationDetails(
            channelRemindersV2,
            'Enjaz',
            icon: 'ic_stat_enjaz',
            importance: Importance.max,
            priority: Priority.max,
            playSound: true,
            enableVibration: true,
            enableLights: true,
            visibility: NotificationVisibility.public,
          )));
      await NotificationDiagnostics.record('show_requested', id: 99998);
      return true;
    } catch (error) {
      await recordFailure(error, id: 99998);
      return false;
    }
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    if (Platform.isAndroid) {
      final androidImplementation = android;
      if (androidImplementation != null) {
        final enabled = await androidImplementation.areNotificationsEnabled();
        return enabled ?? true;
      }
    }
    return true;
  }

  static String? _cachedAlarmSoundUri;

  /// Retrieve default system alarm sound URI
  static Future<String> getAlarmSoundUri() async {
    if (_cachedAlarmSoundUri != null) return _cachedAlarmSoundUri!;
    String uri = 'content://settings/system/alarm_alert';
    try {
      final res = await const MethodChannel('com.enjaz.app/assistant')
          .invokeMethod<String>('alarmUri');
      if (res != null && res.isNotEmpty) uri = res;
    } catch (_) {}
    _cachedAlarmSoundUri = uri;
    return uri;
  }

  /// Request POST_NOTIFICATIONS permission on Android 13+
  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      final androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        final granted =
            await androidImplementation.requestNotificationsPermission();
        return granted ?? false;
      }
    }
    return true;
  }

  /// Check if exact alarms are allowed
  Future<bool> areExactAlarmsPermitted() async {
    if (Platform.isAndroid) {
      final androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        final granted =
            await androidImplementation.canScheduleExactNotifications();
        return granted ?? false;
      }
    }
    return true;
  }

  /// Schedule an Alarm-type reminder (Insistent, Ongoing, Alarm Category & Audio)
  Future<AlarmScheduleResult> scheduleAlarm({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDateTime,
    String? payload,
    String? languageCode,
    int autoStopMinutes = 5,
    bool isSensitive = false,
    bool isSnooze = false,
  }) async {
    await initialize();
    await cancelNotification(id);

    final isArabic = languageCode != 'en';
    final stopLabel = isArabic ? 'إيقاف' : 'Stop';
    final snoozeLabel = isArabic ? 'تأجيل 5 دقائق' : 'Snooze 5 min';

    final tzDateTime = tz.TZDateTime.from(scheduledDateTime, tz.local);

    // FLAG_INSISTENT = 4 makes audio/vibration repeat until dismissed
    final androidDetails = AndroidNotificationDetails(
      channelAlarm,
      channelAlarmName,
      channelDescription: 'منبه رنان بصوت واهتزاز متواصل حتى التفاعل',
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.alarm,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      sound: const RawResourceAndroidNotificationSound('alarm_sound'),
      ongoing: true,
      autoCancel: false,
      additionalFlags: Int32List.fromList([4]),
      icon: 'ic_stat_enjaz',
      playSound: true,
      enableVibration: true,
      enableLights: true,
      fullScreenIntent: true,
      timeoutAfter: autoStopMinutes * 60 * 1000,
      visibility: (isSensitive ||
              (await SharedPreferences.getInstance()).getBool(
                    'app_lock_hide_notifications',
                  ) ==
                  true)
          ? NotificationVisibility.private
          : NotificationVisibility.public,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'action_stop',
          stopLabel,
          showsUserInterface: false,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          'action_snooze',
          snoozeLabel,
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
    );

    final oldAlarm = AlarmPayload.decode(payload);
    final owner = oldAlarm?.owner ??
        (payload?.startsWith('alarm:') == true
            ? payload!.substring(6)
            : payload) ??
        'generic';
    final actualPayload = AlarmPayload(
            id: id,
            snoozed: isSnooze,
            owner: owner,
            title: title,
            sensitive: isSensitive || (oldAlarm?.sensitive ?? false),
            languageCode: languageCode ?? oldAlarm?.languageCode ?? 'ar',
            expiresAt:
                scheduledDateTime.add(Duration(minutes: autoStopMinutes)))
        .encode();

    return _scheduleChecked(
      id: id,
      title: title,
      body: body,
      date: tzDateTime,
      details: NotificationDetails(android: androidDetails),
      payload: actualPayload,
    );
  }

  /// Schedule a standard Notification-type reminder
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDateTime,
    String? payload,
    String? languageCode,
    bool isSensitive = false,
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
      importance: Importance.max,
      priority: Priority.max,
      icon: 'ic_stat_enjaz',
      playSound: true,
      enableVibration: true,
      enableLights: true,
      visibility: (isSensitive ||
              (await SharedPreferences.getInstance()).getBool(
                    'app_lock_hide_notifications',
                  ) ==
                  true)
          ? NotificationVisibility.private
          : NotificationVisibility.public,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          payload?.startsWith('task:') == true ? 'action_done' : 'action_open',
          payload?.startsWith('task:') == true ? doneLabel : openLabel,
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'action_open',
          openLabel,
          showsUserInterface: true,
        ),
      ],
    );

    await _scheduleChecked(
      id: id,
      title: title,
      body: body,
      date: tzDateTime,
      details: NotificationDetails(android: androidDetails),
      payload: payload,
    );
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
    await initialize();
    activeScheduledPayloads.remove(id);
    await _notificationsPlugin.cancel(id);
  }

  Future<void> cancelAll() async {
    await initialize();
    await _notificationsPlugin.cancelAll();
    activeScheduledPayloads.clear();
  }

  Future<void> scheduleMonthlyBackupReminder() async {
    await initialize();
    const id = 99904;
    await cancelNotification(id);
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('backup_monthly_reminder') == false) return;
    final now = DateTime.now();
    await _scheduleChecked(
      id: id,
      title: 'نسخة احتياطية لإنجاز',
      body: 'احفظ نسخة احتياطية من بياناتك',
      date: tz.TZDateTime.from(
          DateTime(now.year, now.month + 1, 1, 10), tz.local),
      details: const NotificationDetails(
        android: AndroidNotificationDetails(
          channelRemindersV2,
          'تنبيهات المهام والإشعارات',
          icon: 'ic_stat_enjaz',
        ),
      ),
      exact: false,
      repeats: DateTimeComponents.dayOfMonthAndTime,
      payload: 'backup',
    );
  }

  /// Schedule Daily Morning Summary (configurable time)
  Future<void> scheduleDailySummary({
    required bool enabled,
    required int hour,
    required int minute,
    int todayItemsCount = 0,
    String? languageCode,
  }) async {
    await initialize();
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
      icon: 'ic_stat_enjaz',
    );

    await _scheduleChecked(
      id: idDailySummary,
      title: title,
      body: body,
      date: tzDateTime,
      details: const NotificationDetails(android: androidDetails),
      payload: 'today_summary',
      repeats: DateTimeComponents.time,
      exact: false,
    );
  }

  /// Schedule Evening Review (configurable time)
  Future<void> scheduleEveningReview({
    required bool enabled,
    required int hour,
    required int minute,
    String? languageCode,
  }) async {
    await initialize();
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
      icon: 'ic_stat_enjaz',
    );

    await _scheduleChecked(
      id: idEveningReview,
      title: title,
      body: body,
      date: tzDateTime,
      details: const NotificationDetails(android: androidDetails),
      payload: 'evening_review',
      repeats: DateTimeComponents.time,
      exact: false,
    );
  }

  /// Schedule Weekly Excel Report reminder (configurable time)
  Future<void> scheduleWeeklyExcelReminder({
    required bool enabled,
    required int hour,
    required int minute,
    String? languageCode,
  }) async {
    await initialize();
    await _notificationsPlugin.cancel(idWeeklyExcel);
    if (!enabled) return;

    final isArabic = languageCode != 'en';
    final title =
        isArabic ? 'تقرير إنجاز الأسبوعي 📊' : 'Weekly Excel Report 📊';
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
      icon: 'ic_stat_enjaz',
    );

    await _scheduleChecked(
      id: idWeeklyExcel,
      title: title,
      body: body,
      date: tzDateTime,
      details: const NotificationDetails(android: androidDetails),
      payload: 'weekly_excel',
      repeats: DateTimeComponents.dayOfWeekAndTime,
      exact: false,
    );
  }

  /// Reschedule all active reminders
  Future<void> rescheduleAll(AppDatabase db, {String? languageCode}) async {
    await initialize();
    try {
      await scheduleMonthlyBackupReminder();
    } catch (error) {
      await recordFailure(error, id: 99904);
    }

    final todayStr = _formatDate(DateTime.now());
    final todayTasks = await db.watchTasksForDate(todayStr).first;

    final morningHour =
        int.tryParse(await db.getSetting('morning_summary_hour') ?? '8') ?? 8;
    final morningMinute =
        int.tryParse(await db.getSetting('morning_summary_minute') ?? '0') ?? 0;
    final morningEnabled =
        (await db.getSetting('morning_summary_enabled')) != 'false';

    await scheduleDailySummary(
      enabled: morningEnabled,
      hour: morningHour,
      minute: morningMinute,
      todayItemsCount: todayTasks.length,
      languageCode: languageCode,
    );

    final eveningHour =
        int.tryParse(await db.getSetting('evening_review_hour') ?? '21') ?? 21;
    final eveningMinute =
        int.tryParse(await db.getSetting('evening_review_minute') ?? '0') ?? 0;
    final eveningEnabled =
        (await db.getSetting('evening_review_enabled')) == 'true';

    await scheduleEveningReview(
      enabled: eveningEnabled,
      hour: eveningHour,
      minute: eveningMinute,
      languageCode: languageCode,
    );

    final weeklyHour =
        int.tryParse(await db.getSetting('weekly_excel_hour') ?? '18') ?? 18;
    final weeklyMinute =
        int.tryParse(await db.getSetting('weekly_excel_minute') ?? '0') ?? 0;
    final weeklyEnabled =
        (await db.getSetting('weekly_excel_enabled')) != 'false';

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
