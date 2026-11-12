import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/card_header.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../health/presentation/health_screen.dart';
import '../../domain/home_settings_provider.dart';
import '../../domain/home_summary_data.dart';

/// HomeHealthCard (UI.md Section 4.2, 4.4 & Section 9)
/// Displays the nearest health item/appointment and postponed count.
/// Respects hideHealthDetails setting.
class HomeHealthCard extends ConsumerWidget {
  final HomeSummaryData data;

  const HomeHealthCard({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final numerals = ref.watch(numeralsProvider);
    final homeSettings = ref.watch(homeSettingsProvider);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    void openHealthScreen() {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const HealthScreen()),
      );
    }

    final postponedStr = AppFormatter.formatNumber(data.postponedHealthCount, format: numerals);

    String? displayTitle;
    if (data.nearestHealthTitle != null) {
      if (homeSettings.hideHealthDetails) {
        displayTitle = isArabic ? 'موعد قادم' : 'Upcoming appointment';
      } else {
        displayTitle = data.nearestHealthTitle;
      }
    }

    return AppCard(
      onTap: openHealthScreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          CardHeader(
            title: isArabic ? 'الصحة' : 'Health',
            leading: Icon(Icons.favorite_rounded, size: 18.0, color: colors.accent),
          ),

          if (displayTitle != null) ...[
            Text(
              displayTitle,
              style: AppTypography.body(context, color: colors.text).copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (data.nearestHealthDay != null) ...[
              const SizedBox(height: 2.0),
              Text(
                data.nearestHealthDay!,
                style: AppTypography.caption(context, color: colors.textSecondary).copyWith(
                  fontSize: 11.0,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ] else ...[
            Text(
              isArabic ? 'مفيش مواعيد قريبة' : 'No upcoming appointments',
              style: AppTypography.caption(context, color: colors.textSecondary),
            ),
          ],

          if (data.postponedHealthCount > 0) ...[
            const SizedBox(height: 8.0),
            StatusChip(
              label: isArabic ? '$postponedStr مؤجل' : '$postponedStr postponed',
              color: colors.warning,
              backgroundColor: colors.warningContainer,
            ),
          ],
        ],
      ),
    );
  }
}
