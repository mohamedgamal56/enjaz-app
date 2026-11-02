import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../domain/task_status_service.dart';

class StatusSheet extends ConsumerStatefulWidget {
  final Task task;
  final String? initialStatus;

  const StatusSheet({
    super.key,
    required this.task,
    this.initialStatus,
  });

  static Future<int?> show(
    BuildContext context, {
    required Task task,
    String? initialStatus,
  }) {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatusSheet(
        task: task,
        initialStatus: initialStatus,
      ),
    );
  }

  @override
  ConsumerState<StatusSheet> createState() => _StatusSheetState();
}

class _StatusSheetState extends ConsumerState<StatusSheet> {
  late String _selectedStatus;
  int? _selectedReasonId;
  String? _selectedReasonText;
  bool _isCustomReason = false;
  final _customReasonController = TextEditingController();
  final _outcomeNoteController = TextEditingController();

  double _progressValue = 50.0;
  String? _postponedUntil;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.initialStatus ?? widget.task.status;
    _progressValue = widget.task.progress > 0 && widget.task.progress < 100
        ? widget.task.progress.toDouble()
        : 50.0;

    // Default postponed date is tomorrow
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    _postponedUntil =
        '${tomorrow.year.toString().padLeft(4, '0')}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _customReasonController.dispose();
    _outcomeNoteController.dispose();
    super.dispose();
  }

  String _getReasonCategoryForStatus(String status) {
    switch (status) {
      case 'postponed':
        return 'postpone';
      case 'waiting':
        return 'waiting';
      case 'stopped':
        return 'stopped';
      case 'partial':
        return 'partial';
      default:
        return 'any';
    }
  }

  bool _isValid() {
    final validationError = TaskStatusService.validateTransition(
      targetStatus: _selectedStatus,
      progress: _progressValue.round(),
      reasonId: _selectedReasonId,
      reasonText: _isCustomReason
          ? _customReasonController.text.trim()
          : _selectedReasonText,
    );
    return validationError == null;
  }

  Future<void> _pickPostponeDate() async {
    final now = DateTime.now();
    final initialDate = _postponedUntil != null
        ? DateTime.tryParse(_postponedUntil!) ?? now.add(const Duration(days: 1))
        : now.add(const Duration(days: 1));

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        _postponedUntil =
            '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  void _confirm() async {
    final db = ref.read(databaseProvider);
    final reasonText = _isCustomReason
        ? _customReasonController.text.trim()
        : _selectedReasonText;

    final outcomeNote = _selectedStatus == 'done' &&
            _outcomeNoteController.text.trim().isNotEmpty
        ? _outcomeNoteController.text.trim()
        : null;

    final eventId = await db.updateTaskStatus(
      task: widget.task,
      newStatus: _selectedStatus,
      progress: _selectedStatus == 'partial'
          ? _progressValue.round()
          : (_selectedStatus == 'done' ? 100 : null),
      reasonId: _isCustomReason ? null : _selectedReasonId,
      reasonText: reasonText,
      postponedUntil:
          _selectedStatus == 'postponed' ? _postponedUntil : null,
      outcomeNote: outcomeNote,
    );

    if (!mounted) return;
    Navigator.of(context).pop(eventId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final numeralsFormat = ref.watch(numeralsProvider);

    final statuses = [
      'todo',
      'in_progress',
      'partial',
      'done',
      'postponed',
      'waiting',
      'stopped',
    ];

    final isReasonRequired = [
      'partial',
      'postponed',
      'waiting',
      'stopped',
    ].contains(_selectedStatus);

    final reasonCategory = _getReasonCategoryForStatus(_selectedStatus);
    final db = ref.watch(databaseProvider);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Sheet Title & Current Task Title
            Text(
              l10n.changeStatusTitle,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              widget.task.title,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),

            // 7 Statuses Grid
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: statuses.map((statusKey) {
                final isSelected = _selectedStatus == statusKey;
                final color = AppColors.getStatusColor(statusKey, isDark);
                final icon = AppColors.getStatusIcon(statusKey);
                final label = l10n.getStatusLabel(statusKey);

                return ChoiceChip(
                  avatar: Icon(
                    icon,
                    size: 18,
                    color: isSelected ? Colors.white : color,
                  ),
                  label: Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : null,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: color,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedStatus = statusKey;
                      });
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Progress Slider for 'partial'
            if (_selectedStatus == 'partial') ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l10n.progressLabel,
                            style: theme.textTheme.titleSmall,
                          ),
                          Text(
                            '%${AppFormatter.formatNumber(_progressValue.round(), format: numeralsFormat)}',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: AppColors.getStatusColor('partial', isDark),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: _progressValue,
                        min: 1,
                        max: 99,
                        divisions: 98,
                        label: '${_progressValue.round()}%',
                        onChanged: (val) {
                          setState(() {
                            _progressValue = val;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Postpone Date Picker for 'postponed'
            if (_selectedStatus == 'postponed') ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.postponeUntilLabel,
                        style: theme.textTheme.titleSmall,
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.event_rounded, size: 18),
                        label: Text(
                          _postponedUntil != null
                              ? AppFormatter.formatDate(
                                  DateTime.parse(_postponedUntil!),
                                  locale: Localizations.localeOf(context).toString(),
                                  format: numeralsFormat,
                                )
                              : l10n.datePick,
                        ),
                        onPressed: _pickPostponeDate,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Reason Section for (partial, postponed, waiting, stopped)
            if (isReasonRequired) ...[
              Text(
                '${l10n.selectReason} *',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),

              StreamBuilder<List<Reason>>(
                stream: db.watchReasons(category: reasonCategory),
                builder: (context, snapshot) {
                  final reasonsList = snapshot.data ?? [];

                  return Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      ...reasonsList.map((reason) {
                        final isSelected = !_isCustomReason &&
                            _selectedReasonId == reason.id;
                        final label = isArabic
                            ? reason.labelAr
                            : (reason.labelEn ?? reason.labelAr);

                        return ChoiceChip(
                          label: Text(label),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _isCustomReason = false;
                              _selectedReasonId = selected ? reason.id : null;
                              _selectedReasonText = selected ? label : null;
                            });
                          },
                        );
                      }),
                      // 'Other reason' chip
                      ChoiceChip(
                        avatar: const Icon(Icons.edit_outlined, size: 14),
                        label: Text(l10n.reasonOther),
                        selected: _isCustomReason,
                        onSelected: (selected) {
                          setState(() {
                            _isCustomReason = selected;
                            if (selected) {
                              _selectedReasonId = null;
                            }
                          });
                        },
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),

              // Custom reason text field
              if (_isCustomReason) ...[
                TextField(
                  controller: _customReasonController,
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: l10n.specifyReasonHint,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],

            // Done Outcome Note (Optional)
            if (_selectedStatus == 'done') ...[
              TextField(
                controller: _outcomeNoteController,
                decoration: InputDecoration(
                  labelText: l10n.outcomeNoteLabel,
                  hintText: l10n.outcomeNoteHint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.celebration_outlined),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Action Buttons (Confirm & Cancel)
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: Text(l10n.cancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _isValid() ? _confirm : null,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: Text(l10n.confirm),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
