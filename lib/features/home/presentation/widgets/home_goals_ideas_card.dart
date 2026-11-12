import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/card_header.dart';
import '../../../plan/presentation/plan_screen.dart';
import '../../domain/home_summary_data.dart';

/// HomeGoalsIdeasCard (UI.md Section 4.2 & Section 9)
/// Displays counts of active goals, ideas, and notes.
/// Tapping navigates to PlanScreen.
class HomeGoalsIdeasCard extends ConsumerWidget {
  final HomeSummaryData data;

  const HomeGoalsIdeasCard({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final numerals = ref.watch(numeralsProvider);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    void openPlanScreen() {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PlanScreen()),
      );
    }

    final goalsStr = AppFormatter.formatNumber(data.activeGoalsCount, format: numerals);
    final ideasStr = AppFormatter.formatNumber(data.ideasCount, format: numerals);
    final notesStr = AppFormatter.formatNumber(data.notesCount, format: numerals);

    final goalsText = isArabic
        ? (data.activeGoalsCount == 1 ? 'هدف واحد نشط' : '$goalsStr أهداف نشطة')
        : (data.activeGoalsCount == 1 ? '1 active goal' : '$goalsStr active goals');

    final subText = isArabic
        ? '$ideasStr أفكار · $notesStr ملاحظات'
        : '$ideasStr ideas · $notesStr notes';

    return AppCard(
      onTap: openPlanScreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          CardHeader(
            title: isArabic ? 'الأهداف والأفكار' : 'Goals & Ideas',
            leading: Icon(Icons.track_changes_rounded, size: 18.0, color: colors.accent),
          ),

          Text(
            goalsText,
            style: AppTypography.body(context, color: colors.text).copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2.0),
          Text(
            subText,
            style: AppTypography.caption(context, color: colors.textSecondary).copyWith(
              fontSize: 11.0,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
