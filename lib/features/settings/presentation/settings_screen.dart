import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/db/app_database.dart';
import '../../voice_notes/domain/voice_note_service.dart';
import '../../excel_export/presentation/excel_export_sheet.dart';
import '../../reminders/presentation/reminders_settings_card.dart';
import 'reasons_manager_screen.dart';
import 'trash_screen.dart';
import '../../security/domain/app_lock_provider.dart';
import '../../backup/presentation/backup_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final currentLocale = ref.watch(localeProvider);
    final currentThemeMode = ref.watch(themeModeProvider);
    final currentNumerals = ref.watch(numeralsProvider);
    final appLockState = ref.watch(appLockProvider);
    final isArabic = (currentLocale?.languageCode ?? Localizations.localeOf(context).languageCode) == 'ar';

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        children: [
          // Section: Language
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.language_rounded, color: theme.colorScheme.primary),
                      const SizedBox(width: 12),
                      Text(
                        l10n.language,
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  RadioListTile<String>(
                    title: Text(l10n.languageArabic),
                    subtitle: const Text('Arabic (RTL)'),
                    value: 'ar',
                    groupValue: currentLocale?.languageCode ??
                        Localizations.localeOf(context).languageCode,
                    onChanged: (val) {
                      ref.read(localeProvider.notifier).setLocale(const Locale('ar'));
                    },
                  ),
                  RadioListTile<String>(
                    title: Text(l10n.languageEnglish),
                    subtitle: const Text('English (LTR)'),
                    value: 'en',
                    groupValue: currentLocale?.languageCode ??
                        Localizations.localeOf(context).languageCode,
                    onChanged: (val) {
                      ref.read(localeProvider.notifier).setLocale(const Locale('en'));
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Section: Theme
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.palette_outlined, color: theme.colorScheme.primary),
                      const SizedBox(width: 12),
                      Text(
                        l10n.theme,
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  RadioListTile<ThemeMode>(
                    title: Text(l10n.themeSystem),
                    value: ThemeMode.system,
                    groupValue: currentThemeMode,
                    onChanged: (val) {
                      if (val != null) {
                        ref.read(themeModeProvider.notifier).setThemeMode(val);
                      }
                    },
                  ),
                  RadioListTile<ThemeMode>(
                    title: Text(l10n.themeLight),
                    value: ThemeMode.light,
                    groupValue: currentThemeMode,
                    onChanged: (val) {
                      if (val != null) {
                        ref.read(themeModeProvider.notifier).setThemeMode(val);
                      }
                    },
                  ),
                  RadioListTile<ThemeMode>(
                    title: Text(l10n.themeDark),
                    value: ThemeMode.dark,
                    groupValue: currentThemeMode,
                    onChanged: (val) {
                      if (val != null) {
                        ref.read(themeModeProvider.notifier).setThemeMode(val);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Section: Numerals
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.tag_rounded, color: theme.colorScheme.primary),
                      const SizedBox(width: 12),
                      Text(
                        l10n.numerals,
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  RadioListTile<NumeralsFormat>(
                    title: Text(l10n.numeralsWestern),
                    value: NumeralsFormat.western,
                    groupValue: currentNumerals,
                    onChanged: (val) {
                      if (val != null) {
                        ref.read(numeralsProvider.notifier).setFormat(val);
                      }
                    },
                  ),
                  RadioListTile<NumeralsFormat>(
                    title: Text(l10n.numeralsArabic),
                    value: NumeralsFormat.arabicIndic,
                    groupValue: currentNumerals,
                    onChanged: (val) {
                      if (val != null) {
                        ref.read(numeralsProvider.notifier).setFormat(val);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Section: Management (Reasons & Trash)
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.schedule_rounded, color: theme.colorScheme.primary),
                  title: Text(l10n.reasonsManager),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ReasonsManagerScreen()),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error),
                  title: Text(l10n.trash),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const TrashScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Section: Voice Notes Storage (Spec 14.6)
          FutureBuilder<(int, int)>(
            future: ref.read(databaseProvider).getVoiceStorageStats(),
            builder: (context, snapshot) {
              final count = snapshot.data?.$1 ?? 0;
              final bytes = snapshot.data?.$2 ?? 0;
              final sizeFormatted = VoiceNoteService.formatFileSize(bytes);

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.mic_rounded, color: theme.colorScheme.primary),
                          const SizedBox(width: 12),
                          Text(
                            l10n.voiceStorage,
                            style: theme.textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${l10n.voiceNotesCountLabel}: $count'),
                          Text(
                            '${l10n.voiceStorageUsedLabel}: $sizeFormatted',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Section: Reminders & Notifications (Spec 8)
          const RemindersSettingsCard(),
          const SizedBox(height: 16),

          // Section: Excel Report Export (Spec 15.2)
          Card(
            child: ListTile(
              leading: Icon(Icons.table_chart_rounded, color: theme.colorScheme.primary),
              title: Text(l10n.exportExcel),
              subtitle: Text(l10n.exportExcelSubtitle),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
              onTap: () {
                ExcelExportSheet.show(context);
              },
            ),
          ),
          const SizedBox(height: 16),

          // Section: App Lock & Security (Phase 7)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.security_rounded, color: theme.colorScheme.primary),
                      const SizedBox(width: 12),
                      Text(
                        l10n.appLockSettingTitle,
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (!appLockState.hasDeviceSecurity) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: theme.colorScheme.error),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isArabic
                                  ? 'لم يتم تعيين قفل للشاشة على جهازك (PIN أو بصمة). يرجى تعيين قفل شاشة من إعدادات الهاتف لتفعيل الحماية.'
                                  : 'No screen lock (PIN, pattern or biometrics) is set on this phone. Please enable it in system settings first.',
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.appLockTitle),
                    subtitle: Text(
                      isArabic
                          ? 'قفل التطبيق ببصمة الهاتف أو رمز PIN أو النمط'
                          : l10n.appLockSettingSubtitle,
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
                    ),
                    value: appLockState.isEnabled,
                    onChanged: (val) async {
                      final notifier = ref.read(appLockProvider.notifier);
                      final success = await notifier.setLockEnabled(
                        val,
                        localizedReason: l10n.appLockReason,
                      );
                      if (!success && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.authFailedMessage)),
                        );
                      }
                    },
                  ),
                  if (appLockState.isEnabled) ...[
                    const Divider(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        isArabic ? 'مهلة القفل في الخلفية' : 'Background lock timeout',
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: Text(
                        isArabic
                            ? _formatTimeoutLabelAr(appLockState.timeoutSeconds)
                            : _formatTimeoutLabelEn(appLockState.timeoutSeconds),
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.primary),
                      ),
                      trailing: DropdownButton<int>(
                        value: appLockState.timeoutSeconds,
                        underline: const SizedBox(),
                        items: [
                          DropdownMenuItem(value: 0, child: Text(isArabic ? 'فوراً' : 'Immediately')),
                          DropdownMenuItem(value: 30, child: Text(isArabic ? '30 ثانية' : '30 seconds')),
                          DropdownMenuItem(value: 60, child: Text(isArabic ? 'دقيقة واحدة' : '1 minute')),
                          DropdownMenuItem(value: 300, child: Text(isArabic ? '5 دقائق' : '5 minutes')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            ref.read(appLockProvider.notifier).setTimeoutSeconds(val);
                          }
                        },
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        isArabic
                            ? 'إخفاء تفاصيل التنبيهات على شاشة القفل'
                            : 'Hide notification details on lock screen',
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: Text(
                        isArabic
                            ? 'حماية خصوصية نصوص المهام والملاحظات عند قفل الشاشة'
                            : 'Protects privacy of task & note text on phone lock screen',
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
                      ),
                      value: appLockState.hideNotificationDetails,
                      onChanged: (val) {
                        ref.read(appLockProvider.notifier).setHideNotificationDetails(val);
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Section: Backup & Restore (Phase 7)
          Card(
            child: ListTile(
              leading: Icon(Icons.backup_outlined, color: theme.colorScheme.primary),
              title: Text(l10n.backupAndSecurity),
              subtitle: Text(l10n.fullBackupDescription),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const BackupScreen()),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Section: About
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: theme.colorScheme.primary),
                      const SizedBox(width: 12),
                      Text(
                        l10n.about,
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.aboutDescription,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${l10n.version}: 1.0.0 (Phase 7 - Final)',
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatTimeoutLabelAr(int seconds) {
  switch (seconds) {
    case 0:
      return 'القفل فور الخروج من التطبيق';
    case 30:
      return 'القفل بعد 30 ثانية في الخلفية';
    case 60:
      return 'القفل بعد دقيقة واحدة في الخلفية';
    case 300:
      return 'القفل بعد 5 دقائق في الخلفية';
    default:
      return '$seconds ثانية';
  }
}

String _formatTimeoutLabelEn(int seconds) {
  switch (seconds) {
    case 0:
      return 'Lock immediately on exit';
    case 30:
      return 'Lock after 30 seconds';
    case 60:
      return 'Lock after 1 minute';
    case 300:
      return 'Lock after 5 minutes';
    default:
      return '$seconds seconds';
  }
}
