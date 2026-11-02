import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
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

  String _formatGroupHeader(DateTime dt, BuildContext context, AppLocalizations l10n) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(dt.year, dt.month, dt.day);
    final numeralsFormat = ref.watch(numeralsProvider);

    if (target.isAtSameMomentAs(today)) {
      return l10n.tabToday;
    }
    final yesterday = today.subtract(const Duration(days: 1));
    if (target.isAtSameMomentAs(yesterday)) {
      final isAr = Localizations.localeOf(context).languageCode == 'ar';
      return isAr ? 'الأمس' : 'Yesterday';
    }

    return AppFormatter.formatDate(
      dt,
      locale: Localizations.localeOf(context).toString(),
      format: numeralsFormat,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final db = ref.watch(databaseProvider);

    final statusOptions = [
      'done',
      'in_progress',
      'partial',
      'postponed',
      'waiting',
      'stopped',
      'todo',
    ];

    return Scaffold(
      appBar: AppBar(
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

                // Kind Filter: All / Task / Errand
                ChoiceChip(
                  label: Text(l10n.filterAll),
                  selected: _selectedKind == null,
                  onSelected: (_) {
                    setState(() {
                      _selectedKind = null;
                    });
                  },
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  avatar: const Icon(Icons.check_circle_outline, size: 14),
                  label: Text(l10n.task),
                  selected: _selectedKind == 'task',
                  onSelected: (sel) {
                    setState(() {
                      _selectedKind = sel ? 'task' : null;
                    });
                  },
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  avatar: const Icon(Icons.location_on_outlined, size: 14),
                  label: Text(l10n.errand),
                  selected: _selectedKind == 'errand',
                  onSelected: (sel) {
                    setState(() {
                      _selectedKind = sel ? 'errand' : null;
                    });
                  },
                ),
                const SizedBox(width: 8),

                // Status Chips
                ...statusOptions.map((st) {
                  final isSelected = _selectedStatuses.contains(st);
                  final color = AppColors.getStatusColor(st, isDark);
                  final label = l10n.getStatusLabel(st);

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: FilterChip(
                      label: Text(label),
                      selected: isSelected,
                      selectedColor: color.withValues(alpha: 0.2),
                      checkmarkColor: color,
                      labelStyle: TextStyle(
                        color: isSelected ? color : null,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
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
            child: StreamBuilder<List<Task>>(
              stream: db.watchHistoryTasks(
                query: _searchController.text,
                statusFilter: _selectedStatuses.isNotEmpty
                    ? _selectedStatuses.toList()
                    : null,
                kindFilter: _selectedKind,
                oldestFirst: _oldestFirst,
              ),
              builder: (context, snapshot) {
                final tasks = snapshot.data ?? [];

                if (snapshot.connectionState == ConnectionState.waiting &&
                    tasks.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (tasks.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.manage_search_rounded,
                          size: 64,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l10n.noHistoryFound,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
  }
}
