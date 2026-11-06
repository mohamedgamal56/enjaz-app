import '../../../core/db/app_database.dart';
import 'notification_service.dart';

class ReminderScheduler {
  final NotificationService _notificationService;
  final AppDatabase _db;

  ReminderScheduler({
    NotificationService? notificationService,
    required AppDatabase db,
  })  : _notificationService = notificationService ?? NotificationService.instance,
        _db = db;

  /// Calculate deterministic notification ID for a reminder
  static int getNotificationId(int reminderId) => (reminderId.abs() % 2000000000);

  /// Schedule a specific reminder
  Future<void> scheduleReminder({
    required Reminder reminder,
    required String title,
    String? dueDate,
    String? dueTime,
    int defaultDateOnlyHour = 9,
    int defaultDateOnlyMinute = 0,
    String? languageCode,
  }) async {
    final notifId = getNotificationId(reminder.id);
    await _notificationService.cancelNotification(notifId);

    if (!reminder.enabled || reminder.deletedAt != null) {
      return;
    }

    DateTime? targetDateTime;
    if (reminder.triggerType == 'absolute') {
      targetDateTime = reminder.absoluteTime;
    } else {
      if (dueDate == null) return;
      final dateParts = dueDate.split('-');
      if (dateParts.length != 3) return;
      final year = int.tryParse(dateParts[0]) ?? 0;
      final month = int.tryParse(dateParts[1]) ?? 0;
      final day = int.tryParse(dateParts[2]) ?? 0;

      int hour = defaultDateOnlyHour;
      int minute = defaultDateOnlyMinute;
      if (dueTime != null && dueTime.contains(':')) {
        final tp = dueTime.split(':');
        hour = int.tryParse(tp[0]) ?? defaultDateOnlyHour;
        minute = int.tryParse(tp[1]) ?? defaultDateOnlyMinute;
      }

      final baseDateTime = DateTime(year, month, day, hour, minute);
      final offset = reminder.offsetMinutes ?? 0;
      targetDateTime = baseDateTime.subtract(Duration(minutes: offset));
    }

    if (targetDateTime == null || targetDateTime.isBefore(DateTime.now())) {
      return;
    }

    final message = (reminder.message != null && reminder.message!.trim().isNotEmpty)
        ? reminder.message!
        : title;

    if (reminder.kind == 'alarm') {
      await _notificationService.scheduleAlarm(
        id: notifId,
        title: title,
        body: message,
        scheduledDateTime: targetDateTime,
        payload: '${reminder.ownerType}:${reminder.ownerId}',
        languageCode: languageCode,
      );
    } else {
      await _notificationService.scheduleNotification(
        id: notifId,
        title: title,
        body: message,
        scheduledDateTime: targetDateTime,
        payload: '${reminder.ownerType}:${reminder.ownerId}',
        languageCode: languageCode,
      );
    }
  }

  /// Cancel a specific reminder
  Future<void> cancelReminder(int reminderId) async {
    final notifId = getNotificationId(reminderId);
    await _notificationService.cancelNotification(notifId);
  }

  /// Cancel all reminders for an owner (e.g. task done, moved to trash)
  Future<void> cancelAllForOwner(String ownerType, int ownerId) async {
    final reminders = await _db.getRemindersForOwner(ownerType, ownerId);
    for (final r in reminders) {
      await cancelReminder(r.id);
    }
  }

  /// Reschedule all reminders for an owner after restore
  Future<void> rescheduleAllForOwner(
    String ownerType,
    int ownerId, {
    required String title,
    String? dueDate,
    String? dueTime,
    String? languageCode,
  }) async {
    final reminders = await _db.getRemindersForOwner(ownerType, ownerId);
    for (final r in reminders) {
      await scheduleReminder(
        reminder: r,
        title: title,
        dueDate: dueDate,
        dueTime: dueTime,
        languageCode: languageCode,
      );
    }
  }

  /// On task marked Done: cancel all its reminders
  Future<void> onTaskDone(int taskId) async {
    await cancelAllForOwner('task', taskId);
  }

  /// On task postponed: reschedule relative to new date
  Future<void> onTaskPostponed(
    Task task,
    String newDueDate, {
    String? languageCode,
  }) async {
    final reminders = await _db.getRemindersForOwner('task', task.id);
    for (final r in reminders) {
      await scheduleReminder(
        reminder: r,
        title: task.title,
        dueDate: newDueDate,
        dueTime: task.dueTime,
        languageCode: languageCode,
      );
    }
  }

  /// Reschedule all active reminders across the app
  Future<void> rescheduleAllActive({String? languageCode}) async {
    final allReminders = await _db.getAllActiveReminders();
    for (final r in allReminders) {
      if (r.ownerType == 'task') {
        final task = await _db.getTaskById(r.ownerId);
        if (task != null && task.status != 'done' && task.deletedAt == null) {
          await scheduleReminder(
            reminder: r,
            title: task.title,
            dueDate: task.dueDate,
            dueTime: task.dueTime,
            languageCode: languageCode,
          );
        }
      } else if (r.ownerType == 'goal') {
        final goal = await _db.getGoalById(r.ownerId);
        if (goal != null && goal.status != 'done' && goal.status != 'abandoned' && goal.deletedAt == null) {
          await scheduleReminder(
            reminder: r,
            title: goal.title,
            dueDate: goal.targetDate,
            dueTime: '09:00',
            languageCode: languageCode,
          );
        }
      } else if (r.ownerType == 'idea') {
        final idea = await _db.getIdeaById(r.ownerId);
        if (idea != null && idea.status != 'converted' && idea.deletedAt == null) {
          await scheduleReminder(
            reminder: r,
            title: idea.title,
            languageCode: languageCode,
          );
        }
      } else if (r.ownerType == 'habit') {
        final habit = await _db.getHabitById(r.ownerId);
        if (habit != null && !habit.archived && habit.deletedAt == null) {
          await scheduleReminder(
            reminder: r,
            title: habit.nameAr,
            languageCode: languageCode,
          );
        }
      }
    }
  }
}
