import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../today/presentation/today_screen.dart';
import '../../plan/presentation/plan_screen.dart';
import '../../stats/presentation/stats_screen.dart';
import 'more_screen.dart';
import '../../tasks/presentation/quick_add_sheet.dart';
import '../../goals/presentation/add_goal_sheet.dart';
import '../../ideas/presentation/add_idea_sheet.dart';
import '../../notes/presentation/add_note_sheet.dart';
import '../../settings/presentation/settings_screen.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    TodayScreen(),
    PlanScreen(),
    StatsScreen(),
    MoreScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    // Top title changes per tab
    String getTitle() {
      switch (_currentIndex) {
        case 0:
          return l10n.appName;
        case 1:
          return isArabic ? 'التخطيط' : 'Plan';
        case 2:
          return l10n.tabStats;
        case 3:
          return isArabic ? 'المزيد' : 'More';
        default:
          return l10n.appName;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          getTitle(),
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_currentIndex != 3)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: l10n.settings,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.today_outlined),
            selectedIcon: const Icon(Icons.today_rounded),
            label: isArabic ? 'اليوم\nToday' : 'Today',
          ),
          NavigationDestination(
            icon: const Icon(Icons.assignment_outlined),
            selectedIcon: const Icon(Icons.assignment_rounded),
            label: isArabic ? 'التخطيط\nPlan' : 'Plan',
          ),
          NavigationDestination(
            icon: const Icon(Icons.bar_chart_rounded),
            selectedIcon: const Icon(Icons.bar_chart_rounded),
            label: isArabic ? 'الإحصائيات\nStats' : 'Stats',
          ),
          NavigationDestination(
            icon: const Icon(Icons.more_horiz_rounded),
            selectedIcon: const Icon(Icons.more_horiz_rounded),
            label: isArabic ? 'المزيد\nMore' : 'More',
          ),
        ],
      ),
      // Floating button on Today and Plan. Stats and More have no button.
      floatingActionButton: (_currentIndex == 0 || _currentIndex == 1)
          ? FloatingActionButton(
              tooltip: _currentIndex == 0
                  ? l10n.addTask
                  : (ref.watch(planSegmentProvider) == 0
                      ? l10n.addGoal
                      : (ref.watch(planSegmentProvider) == 1 ? l10n.addIdea : (isArabic ? 'إضافة ملاحظة' : 'Add Note'))),
              child: const Icon(Icons.add_rounded),
              onPressed: () {
                if (_currentIndex == 0) {
                  QuickAddSheet.show(context, initialKind: 'task');
                } else if (_currentIndex == 1) {
                  final segment = ref.read(planSegmentProvider);
                  if (segment == 0) {
                    AddGoalSheet.show(context);
                  } else if (segment == 1) {
                    AddIdeaSheet.show(context);
                  } else {
                    AddNoteSheet.show(context);
                  }
                }
              },
            )
          : null,
    );
  }
}
