import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../today/presentation/today_screen.dart';

/// HomeOverdueStrip (UI.md Section 4.2 & Section 9)
/// Warning strip shown only when overdue tasks exist.
class HomeOverdueStrip extends ConsumerWidget {
  final int overdueCount;

  const HomeOverdueStrip({
    super.key,
    required this.overdueCount,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (overdueCount <= 0) return const SizedBox.shrink();

    final colors = AppColors.of(context);
    final numerals = ref.watch(numeralsProvider);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final countFormatted = AppFormatter.formatNumber(overdueCount, format: numerals);

    final text = isArabic
        ? (overdueCount == 1 ? 'مهمة واحدة متأخرة' : '$countFormatted مهام متأخرة')
        : (overdueCount == 1 ? '1 overdue task' : '$countFormatted overdue tasks');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: AppCard(
        color: colors.warningText.withValues(alpha: 0.12),
        borderColor: colors.warningBorder,
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const TodayScreen()),
          );
        },
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 20.0,
              color: colors.warningText,
            ),
            const SizedBox(width: 10.0),
            Expanded(
              child: Text(
                text,
                style: AppTypography.body(context, color: colors.warningText).copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              isArabic ? 'عرض' : 'View',
              style: AppTypography.caption(context, color: colors.warningText).copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4.0),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 12.0,
              color: colors.warningText,
            ),
          ],
        ),
      ),
    );
  }
}
