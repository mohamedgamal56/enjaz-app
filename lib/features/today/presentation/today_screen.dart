import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../tasks/presentation/quick_add_sheet.dart';
import '../../tasks/presentation/widgets/task_card.dart';
import '../../tasks/domain/task_selection_provider.dart';
import '../../tasks/presentation/widgets/bulk_selection_bar.dart';
import '../../recurrence/domain/recurrence_service.dart';
import '../../reminders/domain/notification_service.dart';
import '../../reminders/domain/reminder_scheduler.dart';

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  late DateTime _selectedDate;
  bool _isWaitingCollapsed = true;
  bool _isDoneCollapsed = true;
  List<int> _currentVisibleTaskIds = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final db = ref.read(databaseProvider);
      await db.purgeTrashOlderThan30Days();
      await RecurrenceService.generateAllUpcomingInstances(db);
      if (mounted) {
        await NotificationService().rescheduleAll(
          db,
          languageCode: Localizations.localeOf(context).languageCode,
        );
        await ReminderScheduler(db: db).rescheduleAllActive(
          languageCode: Localizations.localeOf(context).languageCode,
        );
      }
    });
  }

  String _formatDateString(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  void _previousDay() {
    setState(() {
      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
    });
  }

  void _nextDay() {
    setState(() {
      _selectedDate = _selectedDate.add(const Duration(days: 1));
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: _selectedDate.subtract(const Duration(days: 365)),
      lastDate: _selectedDate.add(const Duration(days: 3650)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  void _openInboxSheet() {
    final db = ref.read(databaseProvider);
    final l10n = AppLocalizations.of(context);
    final numeralsFormat = ref.read(numeralsProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          builder: (_, scrollController) {
            return StreamBuilder<List<Task>>(
              stream: db.watchUndatedTasks(),
              builder: (context, snapshot) {
                final tasks = snapshot.data ?? [];

                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.outlineVariant,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l10n.noDateInbox,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              AppFormatter.formatNumber(tasks.length, format: numeralsFormat),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(),
                      Expanded(
                        child: tasks.isEmpty
                          ? Center(
                              child: Text(
                                l10n.noDateInbox,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              itemCount: tasks.length,
                              itemBuilder: (_, i) {
                                final t = tasks[i];
                                return Column(
                                  children: [
                                    TaskCard(task: t),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton.icon(
                                        icon: const Icon(Icons.today_rounded, size: 16),
                                        label: Text(l10n.moveToToday),
                                        onPressed: () async {
                                          final now = DateTime.now();
                                          final todayStr = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
                                          await db.moveTaskToDate(t.id, todayStr);
                                        },
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
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
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final numeralsFormat = ref.watch(numeralsProvider);

    final now = DateTime.now();
    final todayOnly = DateTime(now.year, now.month, now.day);
    final isToday = _selectedDate.isAtSameMomentAs(todayOnly);

    final selectedDateStr = _formatDateString(_selectedDate);
    final todayStr = _formatDateString(todayOnly);

    final weekday = AppFormatter.formatWeekday(
      _selectedDate,
      locale: Localizations.localeOf(context).toString(),
    );
    final fullDate = AppFormatter.formatDate(
      _selectedDate,
      locale: Localizations.localeOf(context).toString(),
      format: numeralsFormat,
    );

    final db = ref.watch(databaseProvider);
    final selectionState = ref.watch(taskSelectionProvider);

    return PopScope(
      canPop: !selectionState.isSelecting,
      onPopInvoked: (didPop) {
        if (!didPop && selectionState.isSelecting) {
          ref.read(taskSelectionProvider.notifier).clear();
        }
      },
      child: Scaffold(
        appBar: selectionState.isSelecting
            ? BulkSelectionBar(currentVisibleTaskIds: _currentVisibleTaskIds)
            : null,
        body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Date Switcher Header
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded),
                        tooltip: l10n.previousDay,
                        onPressed: _previousDay,
                      ),
                      InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          child: Column(
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    weekday,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (isToday) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primaryContainer,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        l10n.tabToday,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.onPrimaryContainer,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                fullDate,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.outline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded),
                        tooltip: l10n.nextDay,
                        onPressed: _nextDay,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Progress & Inbox row
              StreamBuilder<List<Task>>(
                stream: db.watchTasksForDate(selectedDateStr),
                builder: (context, taskSnapshot) {
                  final dailyTasks = taskSnapshot.data ?? [];
                  final totalTasks = dailyTasks.length;
                  final doneCount =
                      dailyTasks.where((t) => t.status == 'done').length;

                  return StreamBuilder<int>(
                    stream: db.watchUndatedTasksCount(),
                    builder: (context, countSnapshot) {
                      final undatedCount = countSnapshot.data ?? 0;

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ActionChip(
                            avatar: const Icon(Icons.inbox_outlined, size: 16),
                            label: Text(
                              '${l10n.noDateInbox} (${AppFormatter.formatNumber(undatedCount, format: numeralsFormat)})',
                            ),
                            onPressed: _openInboxSheet,
                          ),
                          Chip(
                            avatar: Icon(
                              Icons.check_circle_rounded,
                              size: 16,
                              color: AppColors.getStatusColor('done', isDark),
                            ),
                            label: Text(
                              isArabic
                                  ? '${AppFormatter.formatNumber(doneCount, format: numeralsFormat)} من ${AppFormatter.formatNumber(totalTasks, format: numeralsFormat)} تمت'
                                  : '${AppFormatter.formatNumber(doneCount, format: numeralsFormat)} of ${AppFormatter.formatNumber(totalTasks, format: numeralsFormat)} done',
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 8),

              // Task Sections List
              Expanded(
                child: StreamBuilder<List<Task>>(
                  stream: db.watchTasksForDate(selectedDateStr),
                  builder: (context, dayTasksSnapshot) {
                    final allDayTasks = dayTasksSnapshot.data ?? [];
                    _currentVisibleTaskIds = allDayTasks.map((t) => t.id).toList();

                    return StreamBuilder<List<Task>>(
                      stream: db.watchOverdueTasks(todayStr),
                      builder: (context, overdueSnapshot) {
                        final overdueTasks = overdueSnapshot.data ?? [];

                        return StreamBuilder<List<Task>>(
                          stream: db.watchPostponedDueTasks(selectedDateStr),
                          builder: (context, postponedDueSnapshot) {
                            final postponedDueTasks =
                                postponedDueSnapshot.data ?? [];

                            // Categorize tasks for selected day
                            final regularTasks = allDayTasks
                                .where((t) =>
                                    t.kind != 'errand' &&
                                    t.status != 'done' &&
                                    t.status != 'postponed' &&
                                    t.status != 'waiting')
                                .toList();

                            final errandTasks = allDayTasks
                                .where((t) =>
                                    t.kind == 'errand' &&
                                    t.status != 'done' &&
                                    t.status != 'postponed' &&
                                    t.status != 'waiting')
                                .toList();

                            final waitingAndPostponed = allDayTasks
                                .where((t) =>
                                    t.status == 'waiting' ||
                                    (t.status == 'postponed' &&
                                        !postponedDueTasks
                                            .any((p) => p.id == t.id)))
                                .toList();

                            final doneTasks = allDayTasks
                                .where((t) => t.status == 'done')
                                .toList();

                            final bool hasAnyItems = allDayTasks.isNotEmpty ||
                                (isToday && overdueTasks.isNotEmpty) ||
                                postponedDueTasks.isNotEmpty;

                            // Empty State
                            if (!hasAnyItems) {
                              return Center(
                                child: SingleChildScrollView(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme
                                              .surfaceContainerHighest,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.task_alt_rounded,
                                          size: 48,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        l10n.emptyTodayTitle,
                                        style: theme.textTheme.titleMedium,
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        l10n.emptyTodaySubtitle,
                                        style: theme.textTheme.bodySmall,
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 20),
                                      FilledButton.icon(
                                        icon: const Icon(Icons.add_rounded),
                                        label: Text(l10n.addTask),
                                        style: FilledButton.styleFrom(
                                          minimumSize: const Size(160, 48),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                        ),
                                        onPressed: () {
                                          QuickAddSheet.show(
                                            context,
                                            initialDate: selectedDateStr,
                                            initialKind: 'task',
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            // Render Sections in order (hide empty ones)
                            return ListView(
                              children: [
                                // 1. Overdue Section (Shown on today only)
                                if (isToday && overdueTasks.isNotEmpty) ...[
                                  _buildSectionHeader(
                                    context,
                                    title: l10n.sectionOverdue,
                                    count: overdueTasks.length,
                                    color: Colors.redAccent,
                                  ),
                                  ...overdueTasks.map((t) => Column(
                                        children: [
                                          TaskCard(task: t),
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: TextButton.icon(
                                              icon: const Icon(
                                                  Icons.redo_rounded,
                                                  size: 16),
                                              label: Text(l10n.moveToToday),
                                              onPressed: () async {
                                                await db.moveTaskToDate(
                                                    t.id, todayStr);
                                              },
                                            ),
                                          ),
                                        ],
                                      )),
                                  const SizedBox(height: 12),
                                ],

                                // 2. Today's Tasks
                                if (regularTasks.isNotEmpty) ...[
                                  _buildSectionHeader(
                                    context,
                                    title: l10n.sectionTasks,
                                    count: regularTasks.length,
                                  ),
                                  ...regularTasks
                                      .map((t) => TaskCard(task: t)),
                                  const SizedBox(height: 12),
                                ],

                                // 3. Today's Errands
                                if (errandTasks.isNotEmpty) ...[
                                  _buildSectionHeader(
                                    context,
                                    title: l10n.sectionErrands,
                                    count: errandTasks.length,
                                    icon: Icons.directions_walk_rounded,
                                  ),
                                  ...errandTasks
                                      .map((t) => TaskCard(task: t)),
                                  const SizedBox(height: 12),
                                ],

                                // 4. Postponed & Due Now
                                if (postponedDueTasks.isNotEmpty) ...[
                                  _buildSectionHeader(
                                    context,
                                    title: l10n.sectionPostponedDue,
                                    count: postponedDueTasks.length,
                                    color: AppColors.getStatusColor(
                                        'postponed', isDark),
                                    icon: Icons.schedule_rounded,
                                  ),
                                  ...postponedDueTasks
                                      .map((t) => TaskCard(task: t)),
                                  const SizedBox(height: 12),
                                ],

                                // 5. Waiting & Postponed (collapsed)
                                if (waitingAndPostponed.isNotEmpty) ...[
                                  ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(
                                      _isWaitingCollapsed
                                          ? Icons.expand_more_rounded
                                          : Icons.expand_less_rounded,
                                    ),
                                    title: Text(
                                      '${l10n.sectionWaitingAndPostponed} (${AppFormatter.formatNumber(waitingAndPostponed.length, format: numeralsFormat)})',
                                      style: theme.textTheme.titleSmall,
                                    ),
                                    onTap: () {
                                      setState(() {
                                        _isWaitingCollapsed =
                                            !_isWaitingCollapsed;
                                      });
                                    },
                                  ),
                                  if (!_isWaitingCollapsed)
                                    ...waitingAndPostponed
                                        .map((t) => TaskCard(task: t)),
                                  const SizedBox(height: 8),
                                ],

                                // 6. Done Today (collapsed)
                                if (doneTasks.isNotEmpty) ...[
                                  ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(
                                      _isDoneCollapsed
                                          ? Icons.expand_more_rounded
                                          : Icons.expand_less_rounded,
                                    ),
                                    title: Text(
                                      '${l10n.sectionDoneToday} (${AppFormatter.formatNumber(doneTasks.length, format: numeralsFormat)})',
                                      style: theme.textTheme.titleSmall,
                                    ),
                                    onTap: () {
                                      setState(() {
                                        _isDoneCollapsed = !_isDoneCollapsed;
                                      });
                                    },
                                  ),
                                  if (!_isDoneCollapsed)
                                    ...doneTasks
                                        .map((t) => TaskCard(task: t)),
                                  const SizedBox(height: 8),
                                ],

                                const SizedBox(height: 64),
                              ],
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required int count,
    Color? color,
    IconData? icon,
  }) {
    final theme = Theme.of(context);
    final numeralsFormat = ref.watch(numeralsProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: color ?? theme.colorScheme.primary),
            const SizedBox(width: 6),
          ],
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: (color ?? theme.colorScheme.primary).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              AppFormatter.formatNumber(count, format: numeralsFormat),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color ?? theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
