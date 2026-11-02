import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../today/presentation/today_screen.dart';
import '../../goals/presentation/goals_screen.dart';
import '../../ideas/presentation/ideas_screen.dart';
import '../../stats/presentation/stats_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../tasks/presentation/quick_add_sheet.dart';
import '../../history/presentation/history_screen.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    TodayScreen(),
    GoalsScreen(),
    IdeasScreen(),
    StatsScreen(),
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
          return l10n.tabGoals;
        case 2:
          return l10n.tabIdeas;
        case 3:
          return l10n.tabStats;
        default:
          return l10n.appName;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          getTitle(),
          style: theme.textTheme.titleLarge,
        ),
        actions: [
          if (_currentIndex == 0) ...[
            IconButton(
              icon: const Icon(Icons.history_rounded),
              tooltip: l10n.history,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HistoryScreen()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: l10n.settings,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
          ] else ...[
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
            icon: const Icon(Icons.flag_outlined),
            selectedIcon: const Icon(Icons.flag_rounded),
            label: isArabic ? 'الأهداف\nGoals' : 'Goals',
          ),
          NavigationDestination(
            icon: const Icon(Icons.lightbulb_outline_rounded),
            selectedIcon: const Icon(Icons.lightbulb_rounded),
            label: isArabic ? 'الأفكار\nIdeas' : 'Ideas',
          ),
          NavigationDestination(
            icon: const Icon(Icons.bar_chart_rounded),
            selectedIcon: const Icon(Icons.bar_chart_rounded),
            label: isArabic ? 'الإحصائيات\nStats' : 'Stats',
          ),
        ],
      ),
      // Floating button on Today, Goals and Ideas. Stats has no button.
      floatingActionButton: _currentIndex != 3
          ? FloatingActionButton(
              tooltip: l10n.addTask,
              child: const Icon(Icons.add_rounded),
              onPressed: () {
                final kind = _currentIndex == 1
                    ? 'goal'
                    : _currentIndex == 2
                        ? 'idea'
                        : 'task';
                QuickAddSheet.show(context, initialKind: kind);
              },
            )
          : null,
    );
  }
}
