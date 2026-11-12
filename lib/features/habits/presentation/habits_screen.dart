import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/habits_service.dart';
import 'habit_icon_helper.dart';
import 'habit_details_screen.dart';
import 'add_habit_sheet.dart';
import 'suggested_habits_sheet.dart';

class HabitsScreen extends ConsumerWidget {
  const HabitsScreen({super.key});

  void _confirmDelete(BuildContext context, WidgetRef ref, Habit habit) async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isArabic ? 'حذف العادة' : 'Delete Habit'),
        content: Text(
          isArabic
              ? 'هل أنت متأكد من نقل عادة "${habit.nameAr}" وسجلاتها إلى سلة المحذوفات؟'
              : 'Move habit "${habit.nameEn ?? habit.nameAr}" to trash?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(isArabic ? 'حذف' : 'Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(databaseProvider).softDeleteHabit(habit.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isArabic ? 'تم نقل العادة إلى سلة المحذوفات' : 'Habit moved to trash',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final db = ref.watch(databaseProvider);
    final todayStr = HabitsService.formatDate(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Text(isArabic ? 'العادات اليومية' : 'Habits'),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome_rounded, color: Colors.amber),
            tooltip: isArabic ? 'العادات المقترحة' : 'Suggested Habits',
            onPressed: () => SuggestedHabitsSheet.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: isArabic ? 'إنشاء عادة جديدة' : 'New Habit',
            onPressed: () => AddHabitSheet.show(context),
          ),
        ],
      ),
      body: StreamBuilder<List<Habit>>(
        stream: db.watchActiveHabits(),
        builder: (context, habitSnapshot) {
          if (habitSnapshot.connectionState == ConnectionState.waiting && !habitSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final habits = habitSnapshot.data ?? [];

          if (habits.isEmpty) {
            return Center(
              child: EmptyState(
                icon: Icons.repeat_rounded,
                title: isArabic ? 'ابدأ في بناء عاداتك اليومية' : 'Start Building Daily Habits',
                subtitle: isArabic
                    ? 'تابع الصلوات، القراءة، شرب الماء، الرياضة والقهوة بلمسة واحدة يومياً'
                    : 'Track prayers, reading, water, fitness, coffee and more offline',
                actionLabel: isArabic ? 'إضافة من العادات المقترحة' : 'Add from Suggested Habits',
                onAction: () => SuggestedHabitsSheet.show(context),
              ),
            );
          }

          return StreamBuilder<List<HabitLog>>(
            stream: db.watchHabitLogsForDate(todayStr),
            builder: (context, logsSnapshot) {
              final logs = logsSnapshot.data ?? [];
              final logsByHabit = <int, double>{};
              for (final l in logs) {
                logsByHabit[l.habitId] = (logsByHabit[l.habitId] ?? 0.0) + l.value;
              }

              return StreamBuilder<List<HabitItemLog>>(
                stream: db.watchHabitItemLogsForDate(todayStr),
                builder: (context, itemLogsSnapshot) {
                  final itemLogs = itemLogsSnapshot.data ?? [];
                  final itemLogsByHabit = <int, Set<int>>{};
                  for (final il in itemLogs) {
                    itemLogsByHabit.putIfAbsent(il.habitId, () => <int>{}).add(il.itemId);
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: habits.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final habit = habits[index];
                      final habitColor = Color(int.parse((habit.color ?? '#1976D2').replaceFirst('#', '0xFF')));
                      final totalLogged = logsByHabit[habit.id] ?? 0.0;
                      final doneItemIds = itemLogsByHabit[habit.id] ?? <int>{};

                      return AppCard(
                        padding: const EdgeInsets.all(16),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => HabitDetailsScreen(habitId: habit.id),
                            ),
                          );
                        },
                        child: Row(
                          children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: habitColor.withValues(alpha: 0.15),
                                  child: Icon(
                                    HabitIconHelper.getIcon(habit.icon),
                                    color: habitColor,
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isArabic ? habit.nameAr : (habit.nameEn ?? habit.nameAr),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      const SizedBox(height: 4),
                                      FutureBuilder<List<HabitItem>>(
                                        future: habit.type == 'checklist' ? db.getHabitItems(habit.id) : Future.value([]),
                                        builder: (context, itemsSnap) {
                                          final items = itemsSnap.data ?? [];
                                          final progress = HabitsService.calculateProgress(
                                            type: habit.type,
                                            dailyTarget: habit.dailyTarget,
                                            unit: habit.unit,
                                            totalLoggedValue: totalLogged,
                                            totalChecklistItems: items.length,
                                            doneChecklistItems: doneItemIds.length,
                                          );

                                          return Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: progress.isCompleted
                                                      ? Colors.green.withValues(alpha: 0.15)
                                                      : theme.colorScheme.surfaceContainerHighest,
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  isArabic
                                                      ? (progress.isCompleted ? 'مكتملة اليوم' : 'اليوم: ${progress.displayProgress}')
                                                      : (progress.isCompleted ? 'Completed Today' : 'Today: ${progress.displayProgress}'),
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: progress.isCompleted ? Colors.green.shade800 : theme.colorScheme.outline,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert_rounded),
                                  onSelected: (val) async {
                                    if (val == 'edit') {
                                      final items = await db.getHabitItems(habit.id);
                                      if (context.mounted) {
                                        AddHabitSheet.show(context, habitToEdit: habit, existingItems: items);
                                      }
                                    } else if (val == 'archive') {
                                      await db.archiveHabit(habit.id, true);
                                    } else if (val == 'delete') {
                                      _confirmDelete(context, ref, habit);
                                    }
                                  },
                                  itemBuilder: (ctx) => [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          const Icon(Icons.edit_outlined, size: 18),
                                          const SizedBox(width: 8),
                                          Text(isArabic ? 'تعديل' : 'Edit'),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'archive',
                                      child: Row(
                                        children: [
                                          const Icon(Icons.archive_outlined, size: 18),
                                          const SizedBox(width: 8),
                                          Text(isArabic ? 'أرشفة' : 'Archive'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuDivider(),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                                          const SizedBox(width: 8),
                                          Text(isArabic ? 'حذف' : 'Delete', style: const TextStyle(color: Colors.red)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                    },
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_rounded),
        label: Text(isArabic ? 'إضافة عادة' : 'Add Habit'),
        onPressed: () => AddHabitSheet.show(context),
      ),
    );
  }
}
