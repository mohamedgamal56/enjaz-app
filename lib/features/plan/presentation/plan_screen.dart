import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../goals/presentation/goals_screen.dart';
import '../../ideas/presentation/ideas_screen.dart';
import '../../notes/presentation/notes_tab.dart';
import '../../notes/presentation/add_note_sheet.dart';

final planSegmentProvider = StateProvider<int>((ref) => 0); // 0: Goals, 1: Ideas, 2: Notes

class PlanScreen extends ConsumerWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSegment = ref.watch(planSegmentProvider);
    final theme = Theme.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Column(
      children: [
        // Top Header with Segmented Control & "Note of the day" quick action
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Expanded(
                child: SegmentedButton<int>(
                  segments: [
                    ButtonSegment<int>(
                      value: 0,
                      label: Text(isArabic ? 'الأهداف' : 'Goals'),
                      icon: const Icon(Icons.flag_rounded, size: 16),
                    ),
                    ButtonSegment<int>(
                      value: 1,
                      label: Text(isArabic ? 'الأفكار' : 'Ideas'),
                      icon: const Icon(Icons.lightbulb_rounded, size: 16),
                    ),
                    ButtonSegment<int>(
                      value: 2,
                      label: Text(isArabic ? 'الملاحظات' : 'Notes'),
                      icon: const Icon(Icons.note_alt_rounded, size: 16),
                    ),
                  ],
                  selected: {currentSegment},
                  onSelectionChanged: (newSelection) {
                    ref.read(planSegmentProvider.notifier).state = newSelection.first;
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Quick "Note of the day" action (Spec Section 3.2)
              IconButton.filledTonal(
                icon: const Icon(Icons.edit_note_rounded),
                tooltip: isArabic ? 'ملاحظة اليوم' : 'Note of the day',
                onPressed: () => AddNoteSheet.show(context),
              ),
            ],
          ),
        ),

        // Body based on selected segment
        Expanded(
          child: IndexedStack(
            index: currentSegment,
            children: const [
              GoalsScreen(),
              IdeasScreen(),
              NotesTab(),
            ],
          ),
        ),
      ],
    );
  }
}
