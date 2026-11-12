import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/widgets/widgets.dart';
import 'add_goal_sheet.dart';
import 'widgets/goal_card.dart';

class GoalsScreen extends ConsumerStatefulWidget {
  const GoalsScreen({super.key});

  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen> {
  int _selectedSegment = 0;

  String get _selectedStatus {
    switch (_selectedSegment) {
      case 0:
        return 'active';
      case 1:
        return 'paused';
      case 2:
        return 'done';
      default:
        return 'active';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final db = ref.watch(databaseProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Segmented control: نشطة / متوقفة / مكتملة
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: SegmentedButton<int>(
                segments: [
                  ButtonSegment<int>(
                    value: 0,
                    label: Text(l10n.goalsActive),
                    icon: const Icon(Icons.play_circle_outline, size: 18),
                  ),
                  ButtonSegment<int>(
                    value: 1,
                    label: Text(l10n.goalsPaused),
                    icon: const Icon(Icons.pause_circle_outline, size: 18),
                  ),
                  ButtonSegment<int>(
                    value: 2,
                    label: Text(l10n.goalsDone),
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                  ),
                ],
                selected: {_selectedSegment},
                onSelectionChanged: (Set<int> newSelection) {
                  setState(() {
                    _selectedSegment = newSelection.first;
                  });
                },
              ),
            ),
            const SizedBox(height: 8),

            // Goals Stream List
            Expanded(
              child: StreamBuilder<List<Goal>>(
                stream: db.watchGoals(status: _selectedStatus),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final goals = snapshot.data ?? [];

                  if (goals.isEmpty) {
                    return Center(
                      child: EmptyState(
                        icon: Icons.flag_outlined,
                        title: l10n.emptyGoalsTitle,
                        subtitle: isArabic
                            ? 'لا توجد أهداف في هذا القسم بعد'
                            : 'No goals in this section yet',
                        actionLabel: l10n.addGoal,
                        onAction: () => AddGoalSheet.show(context),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80, top: 4),
                    itemCount: goals.length,
                    itemBuilder: (context, index) {
                      return GoalCard(goal: goals[index]);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
