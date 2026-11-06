import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;

import '../../../core/db/app_database.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../reminders/domain/reminder_scheduler.dart';
import '../domain/habits_service.dart';
import 'habit_icon_helper.dart';
import 'add_habit_sheet.dart';

class HabitDetailsScreen extends ConsumerStatefulWidget {
  final int habitId;

  const HabitDetailsScreen({
    super.key,
    required this.habitId,
  });

  @override
  ConsumerState<HabitDetailsScreen> createState() => _HabitDetailsScreenState();
}

class _HabitDetailsScreenState extends ConsumerState<HabitDetailsScreen> {
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

  void _prevMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
  }

  Future<void> _showAddPastLogDialog(Habit habit) async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );

    if (pickedDate == null || !mounted) return;
    final logDateStr = HabitsService.formatDate(pickedDate);

    if (habit.type == 'check') {
      final db = ref.read(databaseProvider);
      await db.setHabitCheck(habit.id, logDateStr, true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isArabic ? 'تم تسجيل اليوم بأثر رجعي' : 'Day recorded successfully')),
        );
      }
    } else if (habit.type == 'count') {
      final db = ref.read(databaseProvider);
      await db.logHabitCount(habit.id, logDateStr);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isArabic ? 'تمت إضافة +1 لهذا اليوم' : '+1 added for this day')),
        );
      }
    } else if (habit.type == 'amount') {
      _showAmountDialog(habit, logDateStr);
    }
  }

  void _showAmountDialog(Habit habit, String logDateStr) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isArabic ? 'تسجيل كمية لـ $logDateStr' : 'Enter amount for $logDateStr'),
        content: TextField(
          controller: amountController,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: habit.unit != null ? '${habit.unit}' : (isArabic ? 'الكمية' : 'Amount'),
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
                final db = ref.read(databaseProvider);
                await db.setHabitAmount(habit.id, logDateStr, val);
                if (ctx.mounted) Navigator.of(ctx).pop();
              }
            },
            child: Text(isArabic ? 'حفظ' : 'Save'),
          ),
        ],
      ),
    );
  }

  void _showAddReminderSheet(Habit habit) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    String reminderKind = 'notification'; // notification | alarm
    TimeOfDay selectedTime = const TimeOfDay(hour: 9, minute: 0);
    final messageController = TextEditingController(text: habit.nameAr);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isArabic ? 'إضافة تذكير للعادة' : 'Add Habit Reminder',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                      value: 'notification',
                      icon: const Icon(Icons.notifications_active_outlined),
                      label: Text(isArabic ? 'إشعار عادي' : 'Notification'),
                    ),
                    ButtonSegment(
                      value: 'alarm',
                      icon: const Icon(Icons.alarm_rounded),
                      label: Text(isArabic ? 'منبه صوتي' : 'Alarm'),
                    ),
                  ],
                  selected: {reminderKind},
                  onSelectionChanged: (val) => setSheetState(() => reminderKind = val.first),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.access_time_rounded),
                  title: Text(isArabic ? 'وقت التنبيه اليومي' : 'Daily Reminder Time'),
                  trailing: FilledButton.tonal(
                    onPressed: () async {
                      final picked = await showTimePicker(context: context, initialTime: selectedTime);
                      if (picked != null) setSheetState(() => selectedTime = picked);
                    },
                    child: Text(selectedTime.format(context)),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: messageController,
                  decoration: InputDecoration(
                    labelText: isArabic ? 'نص التذكير' : 'Reminder text',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  onPressed: () async {
                    final db = ref.read(databaseProvider);
                    final now = DateTime.now();
                    var targetTime = DateTime(now.year, now.month, now.day, selectedTime.hour, selectedTime.minute);
                    if (targetTime.isBefore(now)) {
                      targetTime = targetTime.add(const Duration(days: 1));
                    }

                    final reminderId = await db.insertReminder(
                      RemindersCompanion.insert(
                        ownerType: 'habit',
                        ownerId: habit.id,
                        kind: drift.Value(reminderKind),
                        triggerType: const drift.Value('absolute'),
                        absoluteTime: drift.Value(targetTime),
                        message: drift.Value(messageController.text.trim()),
                        enabled: const drift.Value(true),
                        createdAt: now.millisecondsSinceEpoch,
                        updatedAt: now.millisecondsSinceEpoch,
                      ),
                    );

                    final rem = await db.getReminderById(reminderId);
                    if (rem != null) {
                      await ReminderScheduler(db: db).scheduleReminder(
                        reminder: rem,
                        title: habit.nameAr,
                        languageCode: Localizations.localeOf(context).languageCode,
                      );
                    }

                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                  child: Text(isArabic ? 'حفظ التذكير' : 'Save Reminder'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final db = ref.watch(databaseProvider);

    return FutureBuilder<Habit?>(
      future: db.getHabitById(widget.habitId),
      builder: (context, habitSnapshot) {
        final habit = habitSnapshot.data;
        if (habit == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final habitColor = Color(int.parse((habit.color ?? '#1976D2').replaceFirst('#', '0xFF')));

        return Scaffold(
          appBar: AppBar(
            title: Text(isArabic ? habit.nameAr : (habit.nameEn ?? habit.nameAr)),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_rounded),
                onPressed: () async {
                  final items = await db.getHabitItems(habit.id);
                  if (context.mounted) {
                    AddHabitSheet.show(context, habitToEdit: habit, existingItems: items);
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.calendar_today_rounded),
                tooltip: isArabic ? 'تسجيل بأثر رجعي' : 'Back-date log',
                onPressed: () => _showAddPastLogDialog(habit),
              ),
            ],
          ),
          body: StreamBuilder<List<HabitLog>>(
            stream: db.watchHabitLogsForDate(''), // Dummy stream or load range
            builder: (context, _) {
              // Load historical data for this habit
              final startRange = HabitsService.formatDate(DateTime.now().subtract(const Duration(days: 365)));
              final endRange = HabitsService.formatDate(DateTime.now().add(const Duration(days: 1)));

              return FutureBuilder<List<dynamic>>(
                future: Future.wait([
                  db.getHabitLogsForRange(habit.id, startRange, endRange),
                  db.getHabitItemLogsForRange(habit.id, startRange, endRange),
                  db.getHabitItems(habit.id),
                  db.getRemindersForOwner('habit', habit.id),
                ]),
                builder: (context, asyncSnapshot) {
                  if (!asyncSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final logs = asyncSnapshot.data![0] as List<HabitLog>;
                  final itemLogs = asyncSnapshot.data![1] as List<HabitItemLog>;
                  final items = asyncSnapshot.data![2] as List<HabitItem>;
                  final reminders = asyncSnapshot.data![3] as List<Reminder>;

                  // Group logs by date
                  final logsByDate = <String, double>{};
                  for (final l in logs) {
                    logsByDate[l.logDate] = (logsByDate[l.logDate] ?? 0) + l.value;
                  }

                  // Group checklist logs by date
                  final itemLogsByDate = <String, Set<int>>{};
                  for (final il in itemLogs) {
                    itemLogsByDate.putIfAbsent(il.logDate, () => <int>{}).add(il.itemId);
                  }

                  // Build completion map for every day
                  final completionMap = <String, bool>{};
                  final allDates = {...logsByDate.keys, ...itemLogsByDate.keys};
                  for (final d in allDates) {
                    final loggedVal = logsByDate[d] ?? 0.0;
                    final doneItems = itemLogsByDate[d]?.length ?? 0;
                    completionMap[d] = HabitsService.isDayCompleted(
                      type: habit.type,
                      dailyTarget: habit.dailyTarget,
                      totalLoggedValue: loggedVal,
                      totalChecklistItems: items.length,
                      doneChecklistItems: doneItems,
                    );
                  }

                  // Streaks
                  final (currentStreak, bestStreak) = HabitsService.calculateStreaks(
                    scheduleDays: habit.scheduleDays,
                    completionMap: completionMap,
                    today: DateTime.now(),
                  );

                  // Week & Month rates
                  final now = DateTime.now();
                  final weekStart = now.subtract(Duration(days: now.weekday - 1));
                  final monthStart = DateTime(now.year, now.month, 1);
                  final weekRate = HabitsService.calculateCompletionRate(
                    scheduleDays: habit.scheduleDays,
                    completionMap: completionMap,
                    start: weekStart,
                    end: now,
                  );
                  final monthRate = HabitsService.calculateCompletionRate(
                    scheduleDays: habit.scheduleDays,
                    completionMap: completionMap,
                    start: monthStart,
                    end: now,
                  );

                  return ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    children: [
                      // Header Card
                      Card(
                        elevation: 0,
                        color: habitColor.withValues(alpha: 0.12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(color: habitColor.withValues(alpha: 0.3)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 30,
                                backgroundColor: habitColor,
                                child: Icon(HabitIconHelper.getIcon(habit.icon), color: Colors.white, size: 32),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isArabic ? habit.nameAr : (habit.nameEn ?? habit.nameAr),
                                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _describeHabitType(habit, items.length, isArabic),
                                      style: TextStyle(fontSize: 13, color: theme.colorScheme.outline),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // KPI Cards Row (Current Streak & Best Streak)
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricCard(
                              context,
                              title: isArabic ? 'السلسلة الحالية' : 'Current Streak',
                              value: '$currentStreak',
                              unit: isArabic ? 'يوم 🔥' : 'days 🔥',
                              color: Colors.orange,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMetricCard(
                              context,
                              title: isArabic ? 'أطول سلسلة' : 'Best Streak',
                              value: '$bestStreak',
                              unit: isArabic ? 'يوم 🏆' : 'days 🏆',
                              color: Colors.amber.shade800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Week & Month Completion Rate Row
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricCard(
                              context,
                              title: isArabic ? 'إنجاز هذا الأسبوع' : 'This Week',
                              value: '${weekRate.toInt()}%',
                              unit: isArabic ? 'نسبة الالتزام' : 'Completion',
                              color: Colors.teal,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMetricCard(
                              context,
                              title: isArabic ? 'إنجاز هذا الشهر' : 'This Month',
                              value: '${monthRate.toInt()}%',
                              unit: isArabic ? 'نسبة الالتزام' : 'Completion',
                              color: Colors.indigo,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Month Heatmap Calendar Card
                      Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    isArabic ? 'التقويم الشهري والالتزام' : 'Monthly Heatmap',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.chevron_left_rounded),
                                        onPressed: _prevMonth,
                                      ),
                                      Text(
                                        DateFormat('MMMM yyyy', isArabic ? 'ar' : 'en').format(_currentMonth),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.chevron_right_rounded),
                                        onPressed: _nextMonth,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildMonthHeatmapGrid(context, habit, completionMap, habitColor),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Reminders Section
                      Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.alarm_rounded, color: Colors.deepPurple),
                                      const SizedBox(width: 8),
                                      Text(
                                        isArabic ? 'تنبيهات العادة' : 'Habit Reminders',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                    ],
                                  ),
                                  FilledButton.tonalIcon(
                                    icon: const Icon(Icons.add_rounded, size: 16),
                                    label: Text(isArabic ? 'إضافة' : 'Add'),
                                    onPressed: () => _showAddReminderSheet(habit),
                                  ),
                                ],
                              ),
                              if (reminders.isEmpty) ...[
                                const SizedBox(height: 12),
                                Text(
                                  isArabic ? 'لا توجد تنبيهات مخصصة لهذه العادة' : 'No reminders set for this habit',
                                  style: TextStyle(fontSize: 13, color: theme.colorScheme.outline),
                                ),
                              ] else ...[
                                const SizedBox(height: 12),
                                ...reminders.map((rem) {
                                  final timeStr = rem.absoluteTime != null
                                      ? DateFormat('hh:mm a').format(rem.absoluteTime!)
                                      : '09:00 AM';
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(
                                      rem.kind == 'alarm' ? Icons.alarm_rounded : Icons.notifications_active_outlined,
                                      color: Colors.deepPurple,
                                    ),
                                    title: Text(timeStr, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text(rem.kind == 'alarm' ? (isArabic ? 'منبه' : 'Alarm') : (isArabic ? 'إشعار' : 'Notification')),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                                      onPressed: () async {
                                        await ReminderScheduler(db: db).cancelReminder(rem.id);
                                        await db.deleteReminder(rem.id);
                                      },
                                    ),
                                  );
                                }),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Recent Logs List
                      Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    isArabic ? 'سجل التسجيلات الأخير' : 'Recent Logs',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  TextButton.icon(
                                    icon: const Icon(Icons.add_rounded, size: 16),
                                    label: Text(isArabic ? 'تسجيل جديد' : 'Add log'),
                                    onPressed: () => _showAddPastLogDialog(habit),
                                  ),
                                ],
                              ),
                              if (logs.isEmpty) ...[
                                const SizedBox(height: 12),
                                Text(
                                  isArabic ? 'لا توجد تسجيلات مسجلة بعد' : 'No logs recorded yet',
                                  style: TextStyle(fontSize: 13, color: theme.colorScheme.outline),
                                ),
                              ] else ...[
                                const SizedBox(height: 8),
                                ...logs.take(15).map((log) {
                                  final timeStr = DateFormat('hh:mm a').format(DateTime.fromMillisecondsSinceEpoch(log.at));
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(Icons.check_circle_outline_rounded, color: Colors.green),
                                    title: Text('${log.logDate} ($timeStr)'),
                                    subtitle: Text(
                                      habit.type == 'amount'
                                          ? '${log.value} ${habit.unit ?? ''}'
                                          : (isArabic ? 'تم التسجيل (+${log.value.toInt()})' : 'Logged (+${log.value.toInt()})'),
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red),
                                      onPressed: () => db.deleteHabitLog(log.id),
                                    ),
                                  );
                                }),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required String value,
    required String unit,
    required Color color,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  value,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
                ),
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthHeatmapGrid(
    BuildContext context,
    Habit habit,
    Map<String, bool> completionMap,
    Color habitColor,
  ) {
    final year = _currentMonth.year;
    final month = _currentMonth.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstWeekday = DateTime(year, month, 1).weekday; // 1=Mon..7=Sun
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final daysOfWeekAr = ['إث', 'ثل', 'أر', 'خم', 'جم', 'سب', 'أح'];
    final daysOfWeekEn = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

    return Column(
      children: [
        // Weekday header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(7, (i) {
            return SizedBox(
              width: 32,
              child: Text(
                isArabic ? daysOfWeekAr[i] : daysOfWeekEn[i],
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),

        // Days Grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
          ),
          itemCount: (firstWeekday - 1) + daysInMonth,
          itemBuilder: (context, index) {
            if (index < firstWeekday - 1) {
              return const SizedBox();
            }

            final day = index - (firstWeekday - 1) + 1;
            final dateObj = DateTime(year, month, day);
            final dateStr = HabitsService.formatDate(dateObj);
            final isCompleted = completionMap[dateStr] == true;
            final isScheduled = HabitsService.isScheduledForDay(habit.scheduleDays, dateObj);
            final isPastOrToday = !dateObj.isAfter(DateTime.now());

            Color bgColor;
            Color textColor;

            if (isCompleted) {
              bgColor = habitColor;
              textColor = Colors.white;
            } else if (!isScheduled) {
              bgColor = Colors.grey.withValues(alpha: 0.1);
              textColor = Colors.grey.shade400;
            } else if (isPastOrToday) {
              bgColor = Colors.red.withValues(alpha: 0.12);
              textColor = Colors.red.shade700;
            } else {
              bgColor = Colors.transparent;
              textColor = Colors.grey;
            }

            return InkWell(
              onTap: () {
                if (dateObj.isAfter(DateTime.now())) return;
                if (habit.type == 'check') {
                  ref.read(databaseProvider).setHabitCheck(habit.id, dateStr, !isCompleted);
                } else if (habit.type == 'count') {
                  ref.read(databaseProvider).logHabitCount(habit.id, dateStr);
                } else if (habit.type == 'amount') {
                  _showAmountDialog(habit, dateStr);
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isCompleted ? habitColor : Colors.grey.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Text(
                  '$day',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  String _describeHabitType(Habit h, int checklistCount, bool isArabic) {
    switch (h.type) {
      case 'count':
        final targetStr = h.dailyTarget != null
            ? (h.dailyTarget! % 1 == 0 ? h.dailyTarget!.toInt().toString() : h.dailyTarget.toString())
            : '';
        return isArabic
            ? 'عدّاد (${targetStr.isNotEmpty ? 'الهدف: $targetStr ' : ''}${h.unit ?? ''})'
            : 'Counter (${targetStr.isNotEmpty ? 'Target: $targetStr ' : ''}${h.unit ?? ''})';
      case 'check':
        return isArabic ? 'صح أو لسه يومياً' : 'Daily Check';
      case 'amount':
        final targetStr = h.dailyTarget != null
            ? (h.dailyTarget! % 1 == 0 ? h.dailyTarget!.toInt().toString() : h.dailyTarget.toString())
            : '';
        return isArabic
            ? 'كمية (${targetStr.isNotEmpty ? 'الهدف: $targetStr ' : ''}${h.unit ?? ''})'
            : 'Amount (${targetStr.isNotEmpty ? 'Target: $targetStr ' : ''}${h.unit ?? ''})';
      case 'checklist':
        return isArabic ? 'قائمة ($checklistCount عناصر)' : 'Checklist ($checklistCount items)';
      default:
        return h.type;
    }
  }
}
