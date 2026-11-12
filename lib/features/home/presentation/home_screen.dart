import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/enjaz_appearance.dart';
import '../../../core/widgets/empty_state.dart';
import '../domain/home_settings_provider.dart';
import '../domain/home_summary_service.dart';
import 'home_appearance_layout.dart';
import 'widgets/home_header.dart';
import 'widgets/home_overdue_strip.dart';

/// HomeScreen (UI.md Section 4 & Section 9)
/// Aggregated responsive home dashboard for Enjaz.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final summaryAsync = ref.watch(homeSummaryProvider);
    final homeSettings = ref.watch(homeSettingsProvider);
    final appearance = ref.watch(enjazAppearanceProvider);
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
                title: isArabic
                    ? 'حدث خطأ أثناء تحميل البيانات'
                    : 'Error loading summary',
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
                      child: HomeAppearanceLayout(
                        key: ValueKey(appearance),
                        appearance: appearance,
                        cardIds: visibleCardIds,
                        data: data,
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
}
