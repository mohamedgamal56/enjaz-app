import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../domain/home_settings_provider.dart';
import '../domain/home_summary_data.dart';
import '../domain/home_summary_service.dart';
import 'widgets/home_finance_card.dart';
import 'widgets/home_goals_ideas_card.dart';
import 'widgets/home_habits_card.dart';
import 'widgets/home_header.dart';
import 'widgets/home_health_card.dart';
import 'widgets/home_overdue_strip.dart';
import 'widgets/home_today_card.dart';

/// HomeScreen (UI.md Section 4 & Section 9)
/// Aggregated responsive home dashboard for Enjaz.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final summaryAsync = ref.watch(homeSummaryProvider);
    final homeSettings = ref.watch(homeSettingsProvider);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: summaryAsync.when(
          loading: () => Center(
            child: CircularProgressIndicator(color: colors.accent),
          ),
          error: (error, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: EmptyState(
                icon: Icons.error_outline_rounded,
                title: isArabic ? 'حدث خطأ أثناء تحميل البيانات' : 'Error loading summary',
                subtitle: error.toString(),
                actionLabel: isArabic ? 'إعادة المحاولة' : 'Retry',
                onAction: () => ref.refresh(homeSummaryProvider),
              ),
            ),
          ),
          data: (data) => RefreshIndicator(
            color: colors.accent,
            onRefresh: () async {
              ref.invalidate(homeSummaryProvider);
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 360.0;
                final visibleCardIds = homeSettings.cardOrder
                    .where((id) => homeSettings.isCardVisible(id))
                    .toList();

                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 24.0),
                  children: [
                    // 1. Header
                    const HomeHeader(),

                    // 2. Overdue Strip
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: HomeOverdueStrip(overdueCount: data.overdueCount),
                    ),

                    // 3. Dynamic responsive cards
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: _buildCardGrid(
                        context,
                        cardIds: visibleCardIds,
                        data: data,
                        isNarrow: isNarrow,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardWidget(
    BuildContext context, {
    required String cardId,
    required HomeSummaryData data,
  }) {
    switch (cardId) {
      case 'today':
        return HomeTodayCard(data: data);
      case 'habits':
        return HomeHabitsCard(data: data);
      case 'finance':
        return HomeFinanceCard(data: data);
      case 'health':
        return HomeHealthCard(data: data);
      case 'goals_ideas':
        return HomeGoalsIdeasCard(data: data);
      default:
        return const SizedBox.shrink();
    }
  }

  /// Implements UI.md Section 4.3 Layout Rules:
  /// - Below 360 px of width, half-width cards become full width.
  /// - Half-width cards pair up in the order the owner set.
  /// - An odd one out becomes full width.
  Widget _buildCardGrid(
    BuildContext context, {
    required List<String> cardIds,
    required HomeSummaryData data,
    required bool isNarrow,
  }) {
    if (cardIds.isEmpty) return const SizedBox.shrink();

    final List<Widget> rows = [];
    int i = 0;

    while (i < cardIds.length) {
      final currentId = cardIds[i];
      final isCurrentFullWidth = (currentId == 'today') || isNarrow;

      if (isCurrentFullWidth) {
        // Full-width card
        rows.add(_buildCardWidget(context, cardId: currentId, data: data));
        i++;
      } else {
        // Half-width card: check if it can pair with next card
        final hasNext = (i + 1 < cardIds.length);
        final nextId = hasNext ? cardIds[i + 1] : null;
        final isNextHalfWidth = hasNext && (nextId != 'today');

        if (isNextHalfWidth) {
          // Pair two half-width cards side by side
          rows.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildCardWidget(context, cardId: currentId, data: data),
                ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: _buildCardWidget(context, cardId: nextId!, data: data),
                ),
              ],
            ),
          );
          i += 2;
        } else {
          // Odd half-width card: expands to full width
          rows.add(_buildCardWidget(context, cardId: currentId, data: data));
          i++;
        }
      }

      if (i < cardIds.length) {
        rows.add(const SizedBox(height: 12.0));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: rows,
    );
  }
}
