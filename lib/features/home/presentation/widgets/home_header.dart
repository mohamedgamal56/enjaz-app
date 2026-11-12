import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../assistant/presentation/assistant_sheet.dart';
import '../../../settings/presentation/settings_screen.dart';
import '../../domain/home_settings_provider.dart';

/// HomeHeader (UI.md Section 4.1 & Section 9)
/// 'أهلاً، <name>' and today's date in words in text-secondary.
/// Settings button on the end side; microphone button next to it.
class HomeHeader extends ConsumerWidget {
  final DateTime? referenceDate;

  const HomeHeader({
    super.key,
    this.referenceDate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final homeSettings = ref.watch(homeSettingsProvider);
    final numerals = ref.watch(numeralsProvider);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final locale = isArabic ? 'ar' : 'en';

    final now = referenceDate ?? DateTime.now();
    final weekday = AppFormatter.formatWeekday(now, locale: locale);
    final formattedDate = AppFormatter.formatDate(now, locale: locale, format: numerals);
    final dateString = '$weekday، $formattedDate';

    final userName = homeSettings.userName.trim();
    final greeting = userName.isNotEmpty
        ? (isArabic ? 'أهلاً، $userName' : 'Hello, $userName')
        : (isArabic ? 'أهلاً' : 'Hello');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Greeting & Date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  greeting,
                  style: AppTypography.greeting(context).copyWith(color: colors.text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2.0),
                Text(
                  dateString,
                  style: AppTypography.caption(context, color: colors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Microphone button
          IconButton(
            icon: const Icon(Icons.mic_rounded, size: 24.0),
            tooltip: isArabic ? 'المساعد الصوتي' : 'Voice assistant',
            color: colors.accent,
            onPressed: () => AssistantSheet.show(context),
          ),

          // Settings button
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 24.0),
            tooltip: isArabic ? 'الإعدادات' : 'Settings',
            color: colors.textSecondary,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}
