import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/enjaz_appearance.dart';
import '../../../core/widgets/app_bottom_bar.dart';
import '../../home/domain/home_settings_provider.dart';
import '../../home/domain/home_summary_data.dart';
import '../../home/presentation/home_appearance_layout.dart';
import '../../home/presentation/widgets/home_header.dart';

class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(enjazAppearanceProvider);
    final ar = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      appBar: AppBar(title: Text(ar ? 'شكل إنجاز' : 'Enjaz appearance')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: EnjazAppearance.values.length,
        separatorBuilder: (_, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final appearance = EnjazAppearance.values[index];
          final selected = appearance == current;
          return ListTile(
            key: ValueKey('appearance-${appearance.name}'),
            leading: Icon(appearance.icon,
                color: Theme.of(context).colorScheme.primary),
            title: Text(appearance.title(ar)),
            subtitle: Text(appearance.description(ar)),
            trailing: Icon(selected ? Icons.check_circle : Icons.chevron_right),
            selected: selected,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => AppearancePreviewScreen(appearance: appearance),
              ),
            ),
          );
        },
      ),
    );
  }
}

class AppearancePreviewScreen extends ConsumerStatefulWidget {
  const AppearancePreviewScreen({super.key, required this.appearance});
  final EnjazAppearance appearance;

  @override
  ConsumerState<AppearancePreviewScreen> createState() =>
      _AppearancePreviewScreenState();
}

class _AppearancePreviewScreenState
    extends ConsumerState<AppearancePreviewScreen> {
  static const sample = HomeSummaryData(
    todayCompletedCount: 2,
    todayTotalCount: 5,
    todayProgress: .4,
    habitsCompletedCount: 3,
    habitsTotalScheduledCount: 4,
    habitsStreak: 6,
    hasHabits: true,
    todaySpendingMinor: 12000,
    monthSpendingMinor: 145000,
    hasMonthlyBudget: true,
    remainingMonthlyBudgetMinor: 55000,
    postponedHealthCount: 1,
    activeGoalsCount: 3,
    ideasCount: 2,
    notesCount: 4,
    nextTaskTime: '14:00',
  );

  bool _saving = false;

  Future<void> _apply(bool ar) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(enjazAppearanceProvider.notifier)
          .select(widget.appearance);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ar
            ? 'تعذّر حفظ الشكل. حاول مرة أخرى.'
            : 'Could not save the appearance. Try again.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    final selected = ref.watch(enjazAppearanceProvider) == widget.appearance;
    final theme = EnjazAppearanceTheme.apply(
      AppTheme.dark(ar ? 'ar' : 'en'),
      widget.appearance,
    );
    final data = HomeSummaryData(
      todayCompletedCount: sample.todayCompletedCount,
      todayTotalCount: sample.todayTotalCount,
      todayProgress: sample.todayProgress,
      nextTaskTitle: ar ? 'مقابلة عمل' : 'Job interview',
      nextTaskTime: sample.nextTaskTime,
      habitsCompletedCount: sample.habitsCompletedCount,
      habitsTotalScheduledCount: sample.habitsTotalScheduledCount,
      habitsStreak: sample.habitsStreak,
      hasHabits: sample.hasHabits,
      todaySpendingMinor: sample.todaySpendingMinor,
      monthSpendingMinor: sample.monthSpendingMinor,
      hasMonthlyBudget: sample.hasMonthlyBudget,
      remainingMonthlyBudgetMinor: sample.remainingMonthlyBudgetMinor,
      nearestHealthTitle: ar ? 'موعد متابعة' : 'Follow-up',
      nearestHealthDay: ar ? 'غدًا' : 'Tomorrow',
      postponedHealthCount: sample.postponedHealthCount,
      activeGoalsCount: sample.activeGoalsCount,
      ideasCount: sample.ideasCount,
      notesCount: sample.notesCount,
    );
    return Theme(
      data: theme,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.appearance.title(ar)),
          actions: [
            TextButton(
              key: const ValueKey('apply-enjaz-appearance'),
              onPressed: _saving || selected ? null : () => _apply(ar),
              child: Text(selected
                  ? (ar ? 'مفعّل' : 'Active')
                  : (ar ? 'اختيار' : 'Apply')),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                  ar ? 'معاينة ببيانات تجريبية' : 'Preview with sample data',
                  style: theme.textTheme.bodySmall),
            ),
            IgnorePointer(
                child: HomeHeader(
              referenceDate: DateTime(2026, 11, 12),
              previewName: ar ? 'محمد' : 'Mohamed',
            )),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: HomeAppearanceLayout(
                appearance: widget.appearance,
                data: data,
                cardIds: HomeSettingsNotifier.defaultOrder,
                preview: true,
              ),
            ),
          ],
        ),
        bottomNavigationBar: ExcludeSemantics(
          child: IgnorePointer(
              child: AppBottomBar(
            currentIndex: 0,
            onTabSelected: (_) {},
            onAddPressed: () {},
          )),
        ),
      ),
    );
  }
}
