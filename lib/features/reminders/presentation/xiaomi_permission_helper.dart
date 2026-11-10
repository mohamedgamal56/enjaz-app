import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class XiaomiPermissionHelper {
  static const _channel = MethodChannel('com.enjaz.app/assistant');
  static const _prefKey = 'xiaomi_onboarding_shown';

  static Future<bool> isXiaomi() async {
    try {
      return await _channel.invokeMethod<bool>('isXiaomiDevice') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openXiaomiPermissions() async {
    try {
      await _channel.invokeMethod('openXiaomiOtherPermissions');
    } catch (_) {}
  }

  /// Show onboarding bottom sheet if on Xiaomi and hasn't been shown yet
  static Future<void> checkAndPrompt(BuildContext context) async {
    try {
      final xiaomi = await isXiaomi();
      if (!xiaomi) return;

      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_prefKey) == true) return;
      if (!context.mounted) return;

      final isAr = Localizations.localeOf(context).languageCode == 'ar';

      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_clock_rounded,
                  size: 44,
                  color: Theme.of(ctx).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isAr
                    ? 'تنبيه مهم لمستخدمي هواتف شاومي'
                    : 'Important for Xiaomi Users',
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                isAr
                    ? 'لكي تضيء الشاشة وتظهر أزرار إيقاف المنبه فوق شاشة القفل، يرجى تفعيل إذن "العرض على شاشة القفل" و"النوافذ المنبثقة".'
                    : 'To turn screen on and show alarm buttons over lock screen, please enable "Show on Lock screen" and "Display pop-up windows".',
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                      height: 1.5,
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        prefs.setBool(_prefKey, true);
                        Navigator.of(ctx).pop();
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(isAr ? 'لاحقاً' : 'Later'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: () async {
                        await prefs.setBool(_prefKey, true);
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        await openXiaomiPermissions();
                      },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.touch_app_rounded, size: 20),
                      label: Text(isAr ? 'تفعيل الإذن الآن' : 'Enable Now'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    } catch (_) {}
  }

  /// Build persistent Card for ReminderCheckScreen
  static Widget buildCard(BuildContext context) {
    final theme = Theme.of(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Card(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
      margin: const EdgeInsets.symmetric(vertical: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lock_clock_rounded,
                    color: theme.colorScheme.primary, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isAr
                        ? 'تنبيه مهم لمستخدمي هواتف شاومي'
                        : 'Important for Xiaomi Users',
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
                  ? 'لكي تضيء الشاشة وتظهر أزرار إيقاف المنبه فوق شاشة القفل، يرجى تفعيل إذن "العرض على شاشة القفل" و"النوافذ المنبثقة".'
                  : 'To turn screen on and show alarm buttons over lock screen, please enable "Show on Lock screen" and "Display pop-up windows".',
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: openXiaomiPermissions,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.touch_app_rounded, size: 20),
                label: Text(isAr ? 'تفعيل الإذن الآن' : 'Enable Permission Now'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
