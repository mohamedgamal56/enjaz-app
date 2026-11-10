import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../domain/notification_service.dart';

class XiaomiPermissionsStatus {
  final bool isXiaomi;
  final bool showWhenLocked;
  final bool backgroundStart;
  final bool allGranted;

  const XiaomiPermissionsStatus({
    required this.isXiaomi,
    required this.showWhenLocked,
    required this.backgroundStart,
    required this.allGranted,
  });
}

class XiaomiPermissionHelper {
  static const _channel = MethodChannel('com.enjaz.app/assistant');

  static Future<bool> isXiaomi() async {
    try {
      return await _channel.invokeMethod<bool>('isXiaomiDevice') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<XiaomiPermissionsStatus> checkXiaomiPermissions() async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('checkXiaomiPermissions');
      if (res != null) {
        return XiaomiPermissionsStatus(
          isXiaomi: res['isXiaomi'] == true,
          showWhenLocked: res['showWhenLocked'] == true,
          backgroundStart: res['backgroundStart'] == true,
          allGranted: res['allGranted'] == true,
        );
      }
    } catch (_) {}
    final xiaomi = await isXiaomi();
    return XiaomiPermissionsStatus(
      isXiaomi: xiaomi,
      showWhenLocked: !xiaomi,
      backgroundStart: !xiaomi,
      allGranted: !xiaomi,
    );
  }

  static Future<void> openXiaomiPermissions() async {
    try {
      await _channel.invokeMethod('openXiaomiOtherPermissions');
    } catch (_) {
      await openAppSettings();
    }
  }

  static Future<void> openExactAlarmSettings() async {
    try {
      await _channel.invokeMethod('exactAlarmSettings');
    } catch (_) {
      await openAppSettings();
    }
  }

  /// Check whether notifications, exact alarms, and (if Xiaomi) lock screen permissions are all granted.
  static Future<bool> areAllRequiredPermissionsGranted() async {
    final notifs = await NotificationService.instance.areNotificationsEnabled();
    if (!notifs) return false;

    final exact = await NotificationService.instance.areExactAlarmsPermitted();
    if (!exact) return false;

    final miui = await checkXiaomiPermissions();
    if (miui.isXiaomi && !miui.allGranted) return false;

    return true;
  }

  /// Strict permission verification:
  /// Verifies all required permissions. If any are missing, presents a guided interactive sheet,
  /// redirects to settings, and automatically re-verifies on host resume.
  /// Returns `true` ONLY if all permissions are granted; otherwise `false`.
  static Future<bool> ensureAllPermissions(BuildContext context) async {
    if (await areAllRequiredPermissionsGranted()) return true;
    if (!context.mounted) return false;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => const _StrictPermissionSheet(),
    );

    return result ?? false;
  }

  /// Build persistent Card for ReminderCheckScreen
  static Widget buildCard(BuildContext context) {
    return const _XiaomiStatusCard();
  }
}

class _StrictPermissionSheet extends StatefulWidget {
  const _StrictPermissionSheet();

  @override
  State<_StrictPermissionSheet> createState() => _StrictPermissionSheetState();
}

class _StrictPermissionSheetState extends State<_StrictPermissionSheet>
    with WidgetsBindingObserver {
  bool _checking = true;
  bool _notifsGranted = false;
  bool _exactGranted = false;
  XiaomiPermissionsStatus _miuiStatus = const XiaomiPermissionsStatus(
    isXiaomi: false,
    showWhenLocked: true,
    backgroundStart: true,
    allGranted: true,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _check();
    }
  }

  Future<void> _check() async {
    if (!mounted) return;
    setState(() => _checking = true);

    final notifs = await NotificationService.instance.areNotificationsEnabled();
    final exact = await NotificationService.instance.areExactAlarmsPermitted();
    final miui = await XiaomiPermissionHelper.checkXiaomiPermissions();

    if (!mounted) return;
    setState(() {
      _notifsGranted = notifs;
      _exactGranted = exact;
      _miuiStatus = miui;
      _checking = false;
    });

    final allDone = notifs && exact && (!miui.isXiaomi || miui.allGranted);
    if (allDone) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    final notifsMissing = !_notifsGranted;
    final exactMissing = !_exactGranted;
    final miuiMissing = _miuiStatus.isXiaomi && !_miuiStatus.allGranted;
    final allDone = !notifsMissing && !exactMissing && !miuiMissing;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: allDone
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.errorContainer.withValues(alpha: 0.4),
              shape: BoxShape.circle,
            ),
            child: Icon(
              allDone ? Icons.check_circle_rounded : Icons.shield_rounded,
              size: 44,
              color: allDone
                  ? theme.colorScheme.primary
                  : theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            isAr
                ? 'إعداد أذونات المنبه وتجاوز شاشة القفل'
                : 'Alarm & Lock Screen Permissions',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            isAr
                ? 'لكي يرن المنبه بدقة وتضيء الشاشة وتظهر أزرار الإيقاف والتأجيل فوق شاشة القفل، يتطلب النظام تفعيل الصلاحيات التالية:'
                : 'To ensure the alarm rings on time, wakes the screen, and shows controls over lock screen, please grant the following:',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),

          // Notifications Item
          _buildPermissionTile(
            context: context,
            title: isAr ? 'إذن إرسال الإشعارات' : 'Notification Permission',
            subtitle: isAr
                ? 'لإظهار الإشعار ورنين الصوت'
                : 'To post notifications and ring audio',
            isGranted: _notifsGranted,
            onFix: () async {
              await NotificationService.instance.requestPermission();
              await _check();
            },
          ),
          const SizedBox(height: 10),

          // Exact Alarms Item
          _buildPermissionTile(
            context: context,
            title: isAr ? 'إذن التوقيت الدقيق (Exact Alarms)' : 'Exact Alarms',
            subtitle: isAr
                ? 'للرنين في نفس الثانية ومقاومة وضع السكون'
                : 'For exact second timing in Doze mode',
            isGranted: _exactGranted,
            onFix: () async {
              await XiaomiPermissionHelper.openExactAlarmSettings();
            },
          ),
          const SizedBox(height: 10),

          // Xiaomi Lock Screen & Pop-up Item (if Xiaomi)
          if (_miuiStatus.isXiaomi) ...[
            _buildPermissionTile(
              context: context,
              title: isAr
                  ? 'أذونات شاومي (شاشة القفل والنوافذ)'
                  : 'Xiaomi Lock Screen & Pop-ups',
              subtitle: isAr
                  ? 'تفعيل: "الظهور على شاشة القفل" و"عرض النوافذ المنبثقة"'
                  : 'Enable: "Show on Lock screen" and "Display pop-up windows"',
              isGranted: _miuiStatus.allGranted,
              onFix: () async {
                await XiaomiPermissionHelper.openXiaomiPermissions();
              },
            ),
            const SizedBox(height: 10),
          ],

          const SizedBox(height: 14),

          // Action Buttons
          if (allDone) ...[
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(true),
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: Text(
                  isAr ? 'تم بنجاح.. تفعيل المنبه' : 'All Set.. Enable Alarm',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: () async {
                  if (miuiMissing) {
                    await XiaomiPermissionHelper.openXiaomiPermissions();
                  } else if (exactMissing) {
                    await XiaomiPermissionHelper.openExactAlarmSettings();
                  } else {
                    await NotificationService.instance.requestPermission();
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.settings_suggest_rounded, size: 22),
                label: Text(
                  isAr ? 'فتح الإعدادات لتفعيل الأذونات' : 'Open Settings to Enable',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(isAr ? 'إلغاء المنبه' : 'Cancel Alarm'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextButton.icon(
                    onPressed: _checking ? null : _check,
                    icon: _checking
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(isAr ? 'تحقق مجدداً' : 'Check Again'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPermissionTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required bool isGranted,
    required VoidCallback onFix,
  }) {
    final theme = Theme.of(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isGranted
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
            : theme.colorScheme.errorContainer.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGranted
              ? theme.colorScheme.primary.withValues(alpha: 0.3)
              : theme.colorScheme.error.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isGranted
                ? Icons.check_circle_rounded
                : Icons.warning_amber_rounded,
            color: isGranted
                ? theme.colorScheme.primary
                : theme.colorScheme.error,
            size: 26,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (!isGranted) ...[
            const SizedBox(width: 8),
            FilledButton.tonal(
              onPressed: onFix,
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                isAr ? 'تفعيل' : 'Fix',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _XiaomiStatusCard extends StatefulWidget {
  const _XiaomiStatusCard();

  @override
  State<_XiaomiStatusCard> createState() => _XiaomiStatusCardState();
}

class _XiaomiStatusCardState extends State<_XiaomiStatusCard>
    with WidgetsBindingObserver {
  XiaomiPermissionsStatus? _status;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final status = await XiaomiPermissionHelper.checkXiaomiPermissions();
    if (mounted) setState(() => _status = status);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final status = _status;
    if (status == null || !status.isXiaomi) return const SizedBox.shrink();

    final allOk = status.allGranted;

    return Card(
      color: allOk
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.25)
          : theme.colorScheme.errorContainer.withValues(alpha: 0.25),
      margin: const EdgeInsets.symmetric(vertical: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: allOk
              ? theme.colorScheme.primary.withValues(alpha: 0.3)
              : theme.colorScheme.error.withValues(alpha: 0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  allOk ? Icons.check_circle_rounded : Icons.lock_clock_rounded,
                  color: allOk
                      ? theme.colorScheme.primary
                      : theme.colorScheme.error,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isAr
                        ? 'أذونات شاومي (شاشة القفل والنوافذ)'
                        : 'Xiaomi Lock Screen & Pop-ups',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isAr
                  ? 'لكي تضيء الشاشة وتظهر أزرار إيقاف المنبه فوق شاشة القفل، يرجى التأكد من تفعيل "العرض على شاشة القفل" و"عرض النوافذ المنبثقة".'
                  : 'To turn screen on and show alarm controls over lock screen, enable "Show on Lock screen" and "Display pop-up windows".',
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildChip(
                  label: isAr ? 'شاشة القفل' : 'Lock screen',
                  ok: status.showWhenLocked,
                  theme: theme,
                ),
                const SizedBox(width: 8),
                _buildChip(
                  label: isAr ? 'النوافذ المنبثقة' : 'Pop-ups',
                  ok: status.backgroundStart,
                  theme: theme,
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  await XiaomiPermissionHelper.openXiaomiPermissions();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: allOk
                      ? theme.colorScheme.primary
                      : theme.colorScheme.error,
                  foregroundColor: allOk
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onError,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.touch_app_rounded, size: 20),
                label: Text(
                  allOk
                      ? (isAr ? 'مفعلة بالكامل ✓ (فتح للمراجعة)' : 'Fully Enabled ✓')
                      : (isAr ? 'تفعيل الإذن الآن' : 'Enable Permission Now'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required bool ok,
    required ThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: ok
            ? theme.colorScheme.primary.withValues(alpha: 0.15)
            : theme.colorScheme.error.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: ok
              ? theme.colorScheme.primary.withValues(alpha: 0.4)
              : theme.colorScheme.error.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ok ? Icons.check : Icons.close,
            size: 14,
            color: ok ? theme.colorScheme.primary : theme.colorScheme.error,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: ok ? theme.colorScheme.primary : theme.colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }
}
