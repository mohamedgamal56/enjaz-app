import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../domain/habits_service.dart';
import 'habit_icon_helper.dart';
import 'habit_details_screen.dart';

class HabitsStrip extends ConsumerWidget {
  final DateTime selectedDate;

  const HabitsStrip({
    super.key,
    required this.selectedDate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final dateStr = HabitsService.formatDate(selectedDate);

    return StreamBuilder<List<Habit>>(
      stream: db.watchActiveHabits(),
      builder: (context, habitSnapshot) {
        final habits = habitSnapshot.data ?? [];
        if (habits.isEmpty) return const SizedBox();

        // Filter habits scheduled for this day
        final scheduledHabits = habits.where((h) => HabitsService.isScheduledForDay(h.scheduleDays, selectedDate)).toList();
        if (scheduledHabits.isEmpty) return const SizedBox();

        return StreamBuilder<List<HabitLog>>(
          stream: db.watchHabitLogsForDate(dateStr),
          builder: (context, logsSnapshot) {
            final logs = logsSnapshot.data ?? [];
            final logsByHabit = <int, double>{};
            for (final l in logs) {
              logsByHabit[l.habitId] = (logsByHabit[l.habitId] ?? 0.0) + l.value;
            }

            return StreamBuilder<List<HabitItemLog>>(
              stream: db.watchHabitItemLogsForDate(dateStr),
              builder: (context, itemLogsSnapshot) {
                final itemLogs = itemLogsSnapshot.data ?? [];
                final itemLogsByHabit = <int, Set<int>>{};
                for (final il in itemLogs) {
                  itemLogsByHabit.putIfAbsent(il.habitId, () => <int>{}).add(il.itemId);
                }

                return Container(
                  height: 105,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: scheduledHabits.length,
                    itemBuilder: (context, index) {
                      final habit = scheduledHabits[index];
                      final loggedVal = logsByHabit[habit.id] ?? 0.0;
                      final doneItemIds = itemLogsByHabit[habit.id] ?? <int>{};

                      return _HabitStripCard(
                        habit: habit,
                        dateStr: dateStr,
                        totalLogged: loggedVal,
                        doneItemIds: doneItemIds,
                        isArabic: isArabic,
                        onOpenDetails: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => HabitDetailsScreen(habitId: habit.id),
                            ),
                          );
                        },
                      );
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _HabitStripCard extends ConsumerWidget {
  final Habit habit;
  final String dateStr;
  final double totalLogged;
  final Set<int> doneItemIds;
  final bool isArabic;
  final VoidCallback onOpenDetails;

  const _HabitStripCard({
    required this.habit,
    required this.dateStr,
    required this.totalLogged,
    required this.doneItemIds,
    required this.isArabic,
    required this.onOpenDetails,
  });

  void _showChecklistDialog(BuildContext context, WidgetRef ref, List<HabitItem> items) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final db = ref.read(databaseProvider);
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(HabitIconHelper.getIcon(habit.icon), color: Color(int.parse((habit.color ?? '#1976D2').replaceFirst('#', '0xFF')))),
                    const SizedBox(width: 8),
                    Text(
                      isArabic ? habit.nameAr : (habit.nameEn ?? habit.nameAr),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...items.map((item) {
                  final isDone = doneItemIds.contains(item.id);
                  return CheckboxListTile(
                    value: isDone,
                    title: Text(item.name),
                    onChanged: (val) async {
                      await db.toggleHabitItem(habit.id, item.id, dateStr, val ?? false);
                      setSheetState(() {
                        if (val == true) {
                          doneItemIds.add(item.id);
                        } else {
                          doneItemIds.remove(item.id);
                        }
                      });
                    },
                  );
                }),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAmountDialog(BuildContext context, WidgetRef ref) {
    final amountController = TextEditingController(
      text: totalLogged > 0 ? (totalLogged % 1 == 0 ? totalLogged.toInt().toString() : totalLogged.toString()) : '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isArabic ? 'تسجيل كمية (${habit.nameAr})' : 'Log Amount (${habit.nameEn ?? habit.nameAr})'),
        content: TextField(
          controller: amountController,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: habit.unit ?? (isArabic ? 'الكمية' : 'Amount'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final val = double.tryParse(amountController.text.trim());
              if (val != null) {
                await ref.read(databaseProvider).setHabitAmount(habit.id, dateStr, val);
                if (ctx.mounted) Navigator.of(ctx).pop();
              }
            },
            child: Text(isArabic ? 'حفظ' : 'Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final color = Color(int.parse((habit.color ?? '#1976D2').replaceFirst('#', '0xFF')));

    return FutureBuilder<List<HabitItem>>(
      future: habit.type == 'checklist' ? ref.read(databaseProvider).getHabitItems(habit.id) : Future.value([]),
      builder: (context, itemsSnapshot) {
        final items = itemsSnapshot.data ?? [];
        final totalItems = items.length;
        final doneCount = doneItemIds.length;

        final isDone = HabitsService.isDayCompleted(
          type: habit.type,
          dailyTarget: habit.dailyTarget,
          totalLoggedValue: totalLogged,
          totalChecklistItems: totalItems,
          doneChecklistItems: doneCount,
        );

        final progress = HabitsService.calculateProgress(
          type: habit.type,
          dailyTarget: habit.dailyTarget,
          unit: habit.unit,
          totalLoggedValue: totalLogged,
          totalChecklistItems: totalItems,
          doneChecklistItems: doneCount,
        );

        return Card(
          elevation: isDone ? 2 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isDone ? color : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              width: isDone ? 1.5 : 0.8,
            ),
          ),
          margin: const EdgeInsets.only(right: 10, top: 4, bottom: 4),
          child: InkWell(
            onTap: onOpenDetails,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 155,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top Row: Icon & Name
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: isDone ? color : color.withValues(alpha: 0.15),
                        child: Icon(
                          HabitIconHelper.getIcon(habit.icon),
                          size: 16,
                          color: isDone ? Colors.white : color,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isArabic ? habit.nameAr : (habit.nameEn ?? habit.nameAr),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),

                  // Middle: Progress / Status text
                  Text(
                    progress.displayProgress,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDone ? color : theme.colorScheme.outline,
                    ),
                  ),

                  // Bottom Action Button
                  SizedBox(
                    height: 28,
                    child: _buildActionButton(context, ref, isDone, items),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButton(BuildContext context, WidgetRef ref, bool isDone, List<HabitItem> items) {
    final db = ref.read(databaseProvider);
    final color = Color(int.parse((habit.color ?? '#1976D2').replaceFirst('#', '0xFF')));

    switch (habit.type) {
      case 'count':
        return Row(
          children: [
            Expanded(
              child: FilledButton.tonal(
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  backgroundColor: isDone ? color.withValues(alpha: 0.2) : null,
                ),
                onPressed: () => db.logHabitCount(habit.id, dateStr),
                child: const Text('+1', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
            if (totalLogged > 0) ...[
              const SizedBox(width: 4),
              InkWell(
                onTap: () => db.decrementHabitCount(habit.id, dateStr),
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.remove_rounded, size: 16, color: Colors.grey),
                ),
              ),
            ],
          ],
        );

      case 'check':
        return FilledButton.tonalIcon(
          style: FilledButton.styleFrom(
            padding: EdgeInsets.zero,
            backgroundColor: isDone ? color : null,
            foregroundColor: isDone ? Colors.white : null,
          ),
          icon: Icon(isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, size: 15),
          label: Text(
            isDone ? (isArabic ? 'تمت' : 'Done') : (isArabic ? 'تسجيل' : 'Check'),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
          onPressed: () => db.setHabitCheck(habit.id, dateStr, !isDone),
        );

      case 'amount':
        return FilledButton.tonal(
          style: FilledButton.styleFrom(
            padding: EdgeInsets.zero,
            backgroundColor: isDone ? color.withValues(alpha: 0.2) : null,
          ),
          onPressed: () => _showAmountDialog(context, ref),
          child: Text(
            totalLogged > 0 ? '$totalLogged' : (isArabic ? 'إدخال' : 'Enter'),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        );

      case 'checklist':
        return FilledButton.tonalIcon(
          style: FilledButton.styleFrom(
            padding: EdgeInsets.zero,
            backgroundColor: isDone ? color.withValues(alpha: 0.2) : null,
          ),
          icon: const Icon(Icons.list_alt_rounded, size: 14),
          label: Text(
            '${doneItemIds.length}/${items.length}',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
          onPressed: () => _showChecklistDialog(context, ref, items),
        );

      default:
        return const SizedBox();
    }
  }
}
