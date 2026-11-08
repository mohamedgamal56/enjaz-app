import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../domain/notification_service.dart';

class ReminderCheckScreen extends ConsumerStatefulWidget {
  const ReminderCheckScreen({super.key});

  @override
  ConsumerState<ReminderCheckScreen> createState() => _ReminderCheckScreenState();
}

class _ReminderCheckScreenState extends ConsumerState<ReminderCheckScreen> {
  bool _notificationGranted = false;
  bool _exactAlarmGranted = false;
  bool _batteryOptimizationIgnored = false;
  bool _checking = true;

  int? _testCountdown;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    setState(() => _checking = true);
    final notif = await Permission.notification.isGranted;
    final exact = await NotificationService.instance.areExactAlarmsPermitted();
    final battery = await Permission.ignoreBatteryOptimizations.isGranted;

    if (mounted) {
      setState(() {
        _notificationGranted = notif;
        _exactAlarmGranted = exact;
        _batteryOptimizationIgnored = battery;
        _checking = false;
      });
    }
  }

  void _triggerAlarmTest(bool isArabic) async {
    await NotificationService.instance.testAlarmIn10Seconds(isArabic: isArabic);
    setState(() => _testCountdown = 10);
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_testCountdown! <= 1) {
          _testCountdown = null;
          timer.cancel();
        } else {
          _testCountdown = _testCountdown! - 1;
        }
      });
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? 'تمت جدولة المنبه! سيصدر صوتاً واهتزازاً بعد 10 ثوانٍ ⏰'
                : 'Alarm scheduled! Will sound in 10 seconds ⏰',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      appBar: AppBar(
        title: Text(isArabic ? 'فحص التنبيهات والمنبه' : 'Reminder Health Check'),
      ),
      body: _checking
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _checkPermissions,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Test Alarm Card (Primary Action)
                  Card(
                    color: theme.colorScheme.primaryContainer,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.alarm_on_rounded,
                                color: theme.colorScheme.primary,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  isArabic
                                      ? 'اختبار صوت المنبه والاهتزاز'
                                      : 'Test Alarm Sound & Vibration',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isArabic
                                ? 'اضغط لتشغيل منبه تجريبي بعد 10 ثوانٍ للتأكد من وصول الصوت والاهتزاز وشاشة التفاعل حتى لو الشاشة مقفلة.'
                                : 'Trigger a test alarm in 10 seconds to verify sound, vibration and action buttons even with screen locked.',
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _testCountdown != null
                                ? null
                                : () => _triggerAlarmTest(isArabic),
                            icon: const Icon(Icons.timer_outlined),
                            label: Text(
                              _testCountdown != null
                                  ? (isArabic
                                      ? 'المنبه سيعمل خلال $_testCountdown ثواني...'
                                      : 'Ringing in $_testCountdown s...')
                                  : (isArabic
                                      ? 'اختبار المنبه بعد 10 ثواني'
                                      : 'Test Alarm in 10 Seconds'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Section Title: System Permissions
                  Text(
                    isArabic ? 'حالة أذونات النظام' : 'System Permissions Status',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 1. Notification Permission
                  _buildStatusTile(
                    theme: theme,
                    title: isArabic ? 'إذن الإشعارات' : 'Notification Permission',
                    subtitle: isArabic
                        ? (_notificationGranted ? 'مفعّل ومسموح به' : 'معطل - يلزم التفعيل لإظهار التنبيهات')
                        : (_notificationGranted ? 'Allowed' : 'Disabled - needed for alerts'),
                    isGranted: _notificationGranted,
                    onAction: () async {
                      await Permission.notification.request();
                      await _checkPermissions();
                    },
                    actionLabel: isArabic ? 'تفعيل' : 'Allow',
                  ),

                  // 2. Exact Alarm Permission
                  _buildStatusTile(
                    theme: theme,
                    title: isArabic ? 'إذن المنبه في الوقت الدقيق' : 'Exact Alarm Permission',
                    subtitle: isArabic
                        ? (_exactAlarmGranted ? 'مفعّل ومسموح به' : 'معطل - قد تتأخر التنبيهات')
                        : (_exactAlarmGranted ? 'Allowed' : 'Disabled - alerts may be delayed'),
                    isGranted: _exactAlarmGranted,
                    onAction: () => openAppSettings(),
                    actionLabel: isArabic ? 'إعدادات' : 'Settings',
                  ),

                  // 3. Battery Optimization
                  _buildStatusTile(
                    theme: theme,
                    title: isArabic ? 'تجاهل توفير البطارية' : 'Ignore Battery Optimization',
                    subtitle: isArabic
                        ? (_batteryOptimizationIgnored ? 'بدون قيود (ممتاز)' : 'مقيد - قد يقوم النظام بإيقاف التنبيهات في الخلفية')
                        : (_batteryOptimizationIgnored ? 'No restrictions (Best)' : 'Restricted by system'),
                    isGranted: _batteryOptimizationIgnored,
                    onAction: () async {
                      await Permission.ignoreBatteryOptimizations.request();
                      await _checkPermissions();
                    },
                    actionLabel: isArabic ? 'استثناء' : 'Whitelist',
                  ),

                  const SizedBox(height: 24),

                  // Section: Xiaomi / Redmi Guidance Card (Spec Section 5)
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: theme.colorScheme.outlineVariant),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.phone_android_rounded, color: Colors.orange),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  isArabic
                                      ? 'إرشادات خاصة لهواتف شاومي وريدمي (Xiaomi / MIUI / HyperOS)'
                                      : 'Xiaomi / Redmi / MIUI Guidance',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            isArabic
                                ? 'لضمان رنين المنبه وعدم كتمه من قبل نظام MIUI/HyperOS على موبايلك (Redmi 12)، تأكد من تفعيل الآتي في إعدادات التطبيق:\n\n'
                                  '1. التشغيل التلقائي (Autostart): فعّل خيار التشغيل التلقائي للتطبيق.\n'
                                  '2. توفير البطارية (Battery Saver): اختر "لا توجد قيود" (No restrictions).\n'
                                  '3. شاشة القفل: السماح بعرض الإشعارات على شاشة القفل.\n'
                                  '4. الإشعارات المنبثقة (Pop-up): السماح بالإشعارات العائمة والمنبثقة.'
                                : 'To ensure alarms ring reliably on Xiaomi/MIUI devices:\n'
                                  '1. Autostart: Turn on autostart for Enjaz.\n'
                                  '2. Battery saver: Select "No restrictions".\n'
                                  '3. Lock screen: Allow showing notifications on lock screen.\n'
                                  '4. Pop-up notifications: Allow floating and banner pop-ups.',
                            style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () => openAppSettings(),
                            icon: const Icon(Icons.settings_outlined),
                            label: Text(
                              isArabic
                                  ? 'فتح إعدادات تطبيق إنجاز في النظام'
                                  : 'Open App System Settings',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusTile({
    required ThemeData theme,
    required String title,
    required String subtitle,
    required bool isGranted,
    required VoidCallback onAction,
    required String actionLabel,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(
          isGranted ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
          color: isGranted ? Colors.green : Colors.amber.shade800,
          size: 28,
        ),
        title: Text(title, style: theme.textTheme.titleSmall),
        subtitle: Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: isGranted ? Colors.green.shade700 : theme.colorScheme.error,
          ),
        ),
        trailing: isGranted
            ? null
            : TextButton(
                onPressed: onAction,
                child: Text(actionLabel),
              ),
      ),
    );
  }
}
