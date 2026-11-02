import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/db/app_database.dart';
import '../../voice_notes/domain/voice_note_service.dart';
import 'reasons_manager_screen.dart';
import 'trash_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final currentLocale = ref.watch(localeProvider);
    final currentThemeMode = ref.watch(themeModeProvider);
    final currentNumerals = ref.watch(numeralsProvider);

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
                    '${l10n.version}: 1.0.0 (Phase 0)',
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
