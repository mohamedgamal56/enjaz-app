import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/db/app_database.dart';
import '../../../core/l10n/app_localizations.dart';
import '../domain/notification_service.dart';
import 'notification_permission_sheet.dart';
import 'reminder_check_screen.dart';

class RemindersSettingsCard extends ConsumerStatefulWidget {
  const RemindersSettingsCard({super.key});

  @override
  ConsumerState<RemindersSettingsCard> createState() => _RemindersSettingsCardState();
}

class _RemindersSettingsCardState extends ConsumerState<RemindersSettingsCard> {
  bool _dailySummaryEnabled = true;
  TimeOfDay _dailySummaryTime = const TimeOfDay(hour: 8, minute: 0);

  bool _eveningReviewEnabled = false;
  TimeOfDay _eveningReviewTime = const TimeOfDay(hour: 21, minute: 0);

  bool _weeklyExcelEnabled = true;
  TimeOfDay _weeklyExcelTime = const TimeOfDay(hour: 18, minute: 0);

  TimeOfDay _defaultReminderTime = const TimeOfDay(hour: 9, minute: 0);
  int _snoozeMinutes = 10;
  int _autoStopMinutes = 5;
  String _defaultReminderKind = 'alarm'; // 'alarm' | 'notification'

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _dailySummaryEnabled = prefs.getBool('pref_daily_summary_enabled') ?? true;
      _dailySummaryTime = TimeOfDay(
        hour: prefs.getInt('pref_daily_summary_hour') ?? 8,
        minute: prefs.getInt('pref_daily_summary_minute') ?? 0,
      );

      _eveningReviewEnabled = prefs.getBool('pref_evening_review_enabled') ?? false;
      _eveningReviewTime = TimeOfDay(
        hour: prefs.getInt('pref_evening_review_hour') ?? 21,
        minute: prefs.getInt('pref_evening_review_minute') ?? 0,
      );

      _weeklyExcelEnabled = prefs.getBool('pref_weekly_excel_enabled') ?? true;
      _weeklyExcelTime = TimeOfDay(
        hour: prefs.getInt('pref_weekly_excel_hour') ?? 18,
        minute: prefs.getInt('pref_weekly_excel_minute') ?? 0,
      );

      _defaultReminderTime = TimeOfDay(
        hour: prefs.getInt('pref_default_date_only_hour') ?? 9,
        minute: prefs.getInt('pref_default_date_only_minute') ?? 0,
      );

      _snoozeMinutes = prefs.getInt('pref_snooze_duration') ?? 10;
      _autoStopMinutes = prefs.getInt('pref_alarm_autostop_duration') ?? 5;
      _defaultReminderKind = prefs.getString('pref_default_reminder_kind') ?? 'alarm';

      _isLoading = false;
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pref_daily_summary_enabled', _dailySummaryEnabled);
    await prefs.setInt('pref_daily_summary_hour', _dailySummaryTime.hour);
    await prefs.setInt('pref_daily_summary_minute', _dailySummaryTime.minute);

    await prefs.setBool('pref_evening_review_enabled', _eveningReviewEnabled);
    await prefs.setInt('pref_evening_review_hour', _eveningReviewTime.hour);
    await prefs.setInt('pref_evening_review_minute', _eveningReviewTime.minute);

    await prefs.setBool('pref_weekly_excel_enabled', _weeklyExcelEnabled);
    await prefs.setInt('pref_weekly_excel_hour', _weeklyExcelTime.hour);
    await prefs.setInt('pref_weekly_excel_minute', _weeklyExcelTime.minute);

    await prefs.setInt('pref_default_date_only_hour', _defaultReminderTime.hour);
    await prefs.setInt('pref_default_date_only_minute', _defaultReminderTime.minute);

    await prefs.setInt('pref_snooze_duration', _snoozeMinutes);
    await prefs.setInt('pref_alarm_autostop_duration', _autoStopMinutes);
    await prefs.setString('pref_default_reminder_kind', _defaultReminderKind);

    // Also sync to app database settings table
    final db = ref.read(databaseProvider);
    await db.setSetting('reminder_snooze_duration', _snoozeMinutes.toString());
    await db.setSetting('alarm_autostop_duration', _autoStopMinutes.toString());
    await db.setSetting('default_reminder_kind', _defaultReminderKind);

    final service = NotificationService();
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final lang = isAr ? 'ar' : 'en';

    await service.scheduleDailySummary(
      enabled: _dailySummaryEnabled,
      hour: _dailySummaryTime.hour,
      minute: _dailySummaryTime.minute,
      languageCode: lang,
    );

    await service.scheduleEveningReview(
      enabled: _eveningReviewEnabled,
      hour: _eveningReviewTime.hour,
      minute: _eveningReviewTime.minute,
      languageCode: lang,
    );

    await service.scheduleWeeklyExcelReminder(
      enabled: _weeklyExcelEnabled,
      hour: _weeklyExcelTime.hour,
      minute: _weeklyExcelTime.minute,
      languageCode: lang,
    );
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notifications_active_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  l10n.remindersAndNotifications,
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Health Check Link (Spec Section 5)
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ReminderCheckScreen()),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.health_and_safety_outlined, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isArabic ? 'فحص التنبيهات والمنبه' : 'Reminder Health Check',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          Text(
                            isArabic
                                ? 'فحص الأذونات وشاومي واختبار المنبه 10 ثواني'
                                : 'Check permissions, Xiaomi setup & test alarm',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Daily Summary
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.dailySummary),
              subtitle: Text(l10n.dailySummarySubtitle),
              value: _dailySummaryEnabled,
              onChanged: (val) async {
                if (val) {
                  await NotificationPermissionSheet.show(context);
                }
                setState(() => _dailySummaryEnabled = val);
                await _savePreferences();
              },
              secondary: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
                onPressed: _dailySummaryEnabled
                    ? () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _dailySummaryTime,
                        );
                        if (picked != null) {
                          setState(() => _dailySummaryTime = picked);
                          await _savePreferences();
                        }
                      }
                    : null,
                child: Text(_formatTimeOfDay(_dailySummaryTime)),
              ),
            ),
            const Divider(height: 16),

            // Evening Review
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.eveningReview),
              subtitle: Text(l10n.eveningReviewSubtitle),
              value: _eveningReviewEnabled,
              onChanged: (val) async {
                if (val) {
                  await NotificationPermissionSheet.show(context);
                }
                setState(() => _eveningReviewEnabled = val);
                await _savePreferences();
              },
              secondary: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
                onPressed: _eveningReviewEnabled
                    ? () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _eveningReviewTime,
                        );
                        if (picked != null) {
                          setState(() => _eveningReviewTime = picked);
                          await _savePreferences();
                        }
                      }
                    : null,
                child: Text(_formatTimeOfDay(_eveningReviewTime)),
              ),
            ),
            const Divider(height: 16),

            // Weekly Excel Reminder
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.weeklyExcelReminder),
              subtitle: Text(l10n.weeklyExcelReminderSubtitle),
              value: _weeklyExcelEnabled,
              onChanged: (val) async {
                if (val) {
                  await NotificationPermissionSheet.show(context);
                }
                setState(() => _weeklyExcelEnabled = val);
                await _savePreferences();
              },
              secondary: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
                onPressed: _weeklyExcelEnabled
                    ? () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _weeklyExcelTime,
                        );
                        if (picked != null) {
                          setState(() => _weeklyExcelTime = picked);
                          await _savePreferences();
                        }
                      }
                    : null,
                child: Text(_formatTimeOfDay(_weeklyExcelTime)),
              ),
            ),
            const Divider(height: 16),

            // Default date-only reminder time
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.defaultReminderTime),
              subtitle: Text(l10n.defaultReminderTimeSubtitle),
              trailing: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
                onPressed: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _defaultReminderTime,
                  );
                  if (picked != null) {
                    setState(() => _defaultReminderTime = picked);
                    await _savePreferences();
                  }
                },
                child: Text(_formatTimeOfDay(_defaultReminderTime)),
              ),
            ),
            const Divider(height: 16),

            // Snooze Duration (Spec 1.6)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(isArabic ? 'مدة تأجيل المنبه (Snooze)' : 'Alarm Snooze Duration'),
              subtitle: Text(isArabic ? 'المدة الافتراضية عند الضغط على تأجيل' : 'Default minutes on Snooze'),
              trailing: DropdownButton<int>(
                value: _snoozeMinutes,
                underline: const SizedBox(),
                items: [5, 10, 15, 30].map((m) {
                  return DropdownMenuItem(
                    value: m,
                    child: Text(isArabic ? '$m دقائق' : '$m min'),
                  );
                }).toList(),
                onChanged: (val) async {
                  if (val != null) {
                    setState(() => _snoozeMinutes = val);
                    await _savePreferences();
                  }
                },
              ),
            ),
            const Divider(height: 16),

            // Alarm Auto-stop Duration (Spec 1.6)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(isArabic ? 'مدة توقف المنبه تلقائياً' : 'Alarm Auto-Stop Timeout'),
              subtitle: Text(isArabic ? 'إيقاف رنين المنبه بعد N دقائق' : 'Stops ringing automatically after N min'),
              trailing: DropdownButton<int>(
                value: _autoStopMinutes,
                underline: const SizedBox(),
                items: [1, 3, 5, 10, 15, 30].map((m) {
                  return DropdownMenuItem(
                    value: m,
                    child: Text(isArabic ? '$m دقائق' : '$m min'),
                  );
                }).toList(),
                onChanged: (val) async {
                  if (val != null) {
                    setState(() => _autoStopMinutes = val);
                    await _savePreferences();
                  }
                },
              ),
            ),
            const Divider(height: 16),

            // Default Reminder Type (Spec 1.3)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(isArabic ? 'نوع التنبيه الافتراضي للمهام المحددة بوقت' : 'Default Reminder Type for Timed Tasks'),
              subtitle: Text(
                _defaultReminderKind == 'alarm'
                    ? (isArabic ? 'منبه (رنين مستمر حتى التفاعل)' : 'Alarm (continuous ring until action)')
                    : (isArabic ? 'إشعار عادي' : 'Standard Notification'),
              ),
              trailing: DropdownButton<String>(
                value: _defaultReminderKind,
                underline: const SizedBox(),
                items: [
                  DropdownMenuItem(
                    value: 'alarm',
                    child: Text(isArabic ? 'منبه (Alarm)' : 'Alarm'),
                  ),
                  DropdownMenuItem(
                    value: 'notification',
                    child: Text(isArabic ? 'إشعار (Notification)' : 'Notification'),
                  ),
                ],
                onChanged: (val) async {
                  if (val != null) {
                    setState(() => _defaultReminderKind = val);
                    await _savePreferences();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
