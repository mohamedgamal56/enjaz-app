import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/widgets.dart';
import '../../tasks/domain/task_selection_provider.dart';
import '../../tasks/presentation/widgets/bulk_selection_bar.dart';
import '../../tasks/presentation/widgets/task_card.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _searchController = TextEditingController();
  String? _selectedKind; // null = all, 'task', 'errand'
  final Set<String> _selectedStatuses = {};
  bool _oldestFirst = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleStatus(String status) {
    setState(() {
      if (_selectedStatuses.contains(status)) {
        _selectedStatuses.remove(status);
      } else {
        _selectedStatuses.add(status);
      }
    });
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _selectedKind = null;
      _selectedStatuses.clear();
      _oldestFirst = false;
    });
  }

  String _formatGroupHeader(
    DateTime dt,
    BuildContext context,
    AppLocalizations l10n,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final target = DateTime(dt.year, dt.month, dt.day);
    final numeralsFormat = ref.watch(numeralsProvider);

    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    if (target == today) {
      return isArabic ? 'اليوم' : l10n.dateToday;
    } else if (target == yesterday) {
      return isArabic ? 'أمس' : 'Yesterday';
    } else {
      return AppFormatter.formatDate(
        target,
        locale: Localizations.localeOf(context).toString(),
        format: numeralsFormat,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final db = ref.watch(databaseProvider);
    final selectionState = ref.watch(taskSelectionProvider);

    final statusFilters = [
      'done',
      'in_progress',
      'partial',
      'postponed',
      'waiting',
      'stopped',
      'todo',
    ];

    return PopScope(
      canPop: !selectionState.isSelecting,
      onPopInvoked: (didPop) {
        if (!didPop && selectionState.isSelecting) {
          ref.read(taskSelectionProvider.notifier).clear();
        }
      },
      child: StreamBuilder<List<Task>>(
        stream: db.watchHistoryTasks(
          query: _searchController.text,
          statusFilter:
              _selectedStatuses.isNotEmpty ? _selectedStatuses.toList() : null,
          kindFilter: _selectedKind,
          oldestFirst: _oldestFirst,
        ),
        builder: (context, snapshot) {
          final tasks = snapshot.data ?? [];
          final visibleTaskIds = tasks.map((t) => t.id).toList();

          return Scaffold(
            appBar: selectionState.isSelecting
                ? BulkSelectionBar(currentVisibleTaskIds: visibleTaskIds)
                : AppBar(
                    title: Text(l10n.historyTitle),
                    actions: [
                      if (_selectedStatuses.isNotEmpty ||
                          _selectedKind != null ||
                          _searchController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.filter_alt_off_rounded),
                          tooltip: l10n.clearFilters,
                          onPressed: _clearFilters,
                        ),
                    ],
                  ),
            body: Column(
              children: [
                // Search Input
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: l10n.searchHint,
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                });
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),

                // Filters Row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      // Sort Toggle
                      ActionChip(
                        avatar: Icon(
                          _oldestFirst
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded,
                          size: 16,
                        ),
                        label: Text(
                          _oldestFirst ? l10n.sortOldest : l10n.sortNewest,
                        ),
                        onPressed: () {
                          setState(() {
                            _oldestFirst = !_oldestFirst;
                          });
                        },
                      ),
                      const SizedBox(width: 8),

                      // Kind Filter: Tasks
                      FilterChip(
                        label: Text(l10n.task),
                        selected: _selectedKind == 'task',
                        onSelected: (selected) {
                          setState(() {
                            _selectedKind = selected ? 'task' : null;
                          });
                        },
                      ),
                      const SizedBox(width: 8),

                      // Kind Filter: Errands
                      FilterChip(
                        label: Text(l10n.errand),
                        selected: _selectedKind == 'errand',
                        onSelected: (selected) {
                          setState(() {
                            _selectedKind = selected ? 'errand' : null;
                          });
                        },
                      ),
                      const SizedBox(width: 8),

                      // Status Filters
                      ...statusFilters.map((st) {
                        final isSel = _selectedStatuses.contains(st);
                        final color = AppColors.getStatusColor(st, isDark);
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: FilterChip(
                            avatar: Icon(
                              AppColors.getStatusIcon(st),
                              size: 16,
                              color: isSel ? Colors.white : color,
                            ),
                            label: Text(l10n.getStatusLabel(st)),
                            selected: isSel,
                            selectedColor: color.withOpacity(0.85),
                            checkmarkColor: Colors.white,
                            onSelected: (_) => _toggleStatus(st),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const Divider(height: 12),

                // Stream of History Tasks
                Expanded(
                  child: Builder(
                    builder: (context) {
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          tasks.isEmpty) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (tasks.isEmpty) {
                        return Center(
                          child: EmptyState(
                            icon: Icons.manage_search_rounded,
                            title: l10n.noHistoryFound,
                          ),
                        );
                      }

                      // Group tasks by day (from dueDate or createdAt)
                      final Map<String, List<Task>> grouped = {};
                      for (final t in tasks) {
                        final dt = t.dueDate != null
                            ? DateTime.parse(t.dueDate!)
                            : DateTime.fromMillisecondsSinceEpoch(t.createdAt);
                        final dayKey =
                            '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
                        grouped.putIfAbsent(dayKey, () => []).add(t);
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        itemCount: grouped.length,
                        itemBuilder: (context, idx) {
                          final dayKey = grouped.keys.elementAt(idx);
                          final dayTasks = grouped[dayKey]!;
                          final dt = DateTime.parse(dayKey);
                          final headerText = _formatGroupHeader(dt, context, l10n);

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 8,
                                ),
                                child: Text(
                                  headerText,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                              ...dayTasks.map((t) => TaskCard(task: t)),
                              const SizedBox(height: 8),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
