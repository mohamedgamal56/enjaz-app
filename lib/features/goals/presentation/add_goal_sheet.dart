import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;

import '../../../core/db/app_database.dart';
import '../../../core/l10n/app_localizations.dart';

class AddGoalSheet extends ConsumerStatefulWidget {
  final Goal? existingGoal;

  const AddGoalSheet({
    super.key,
    this.existingGoal,
  });

  static Future<Goal?> show(
    BuildContext context, {
    Goal? existingGoal,
  }) {
    return showModalBottomSheet<Goal?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => AddGoalSheet(existingGoal: existingGoal),
    );
  }

  @override
  ConsumerState<AddGoalSheet> createState() => _AddGoalSheetState();
}

class _AddGoalSheetState extends ConsumerState<AddGoalSheet> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _targetValueController = TextEditingController();
  final _unitController = TextEditingController();
  final _milestoneInputController = TextEditingController();

  final _titleFocusNode = FocusNode();

  String _progressMode = 'milestones'; // milestones | numeric
  String _category = 'personal'; // personal | work | study | health | finance | other
  String? _targetDate; // YYYY-MM-DD
  final List<String> _initialMilestones = [];

  bool get isEdit => widget.existingGoal != null;

  @override
  void initState() {
    super.initState();
    if (widget.existingGoal != null) {
      final g = widget.existingGoal!;
      _titleController.text = g.title;
      _descController.text = g.description ?? '';
      _progressMode = g.progressMode;
      _category = g.category ?? 'personal';
      _targetDate = g.targetDate;
      if (g.targetValue != null) {
        _targetValueController.text = g.targetValue!.toStringAsFixed(
            g.targetValue!.truncateToDouble() == g.targetValue! ? 0 : 1);
      }
      _unitController.text = g.unit ?? '';
    } else {
      // Default target date: 3 months from now
      final defaultDate = DateTime.now().add(const Duration(days: 90));
      _targetDate =
          '${defaultDate.year.toString().padLeft(4, '0')}-${defaultDate.month.toString().padLeft(2, '0')}-${defaultDate.day.toString().padLeft(2, '0')}';
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _titleFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _targetValueController.dispose();
    _unitController.dispose();
    _milestoneInputController.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  Future<void> _pickTargetDate() async {
    final now = DateTime.now();
    final initial = _targetDate != null ? DateTime.tryParse(_targetDate!) ?? now : now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (picked != null) {
      setState(() {
        _targetDate =
            '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  void _addInitialMilestone() {
    final text = _milestoneInputController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _initialMilestones.add(text);
        _milestoneInputController.clear();
      });
    }
  }

  Future<void> _saveGoal() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final db = ref.read(databaseProvider);
    final now = DateTime.now().millisecondsSinceEpoch;
    final double? targetVal = double.tryParse(_targetValueController.text.trim());

    if (isEdit) {
      final updated = widget.existingGoal!.toCompanion(true).copyWith(
        title: drift.Value(title),
        description: _descController.text.trim().isNotEmpty
            ? drift.Value(_descController.text.trim())
            : const drift.Value(null),
        category: drift.Value(_category),
        progressMode: drift.Value(_progressMode),
        targetDate: _targetDate != null ? drift.Value(_targetDate) : const drift.Value(null),
        targetValue: targetVal != null ? drift.Value(targetVal) : const drift.Value(null),
        unit: _unitController.text.trim().isNotEmpty
            ? drift.Value(_unitController.text.trim())
            : const drift.Value(null),
        updatedAt: drift.Value(now),
      );
      await db.updateGoalData(updated);
      if (!mounted) return;
      Navigator.of(context).pop();
    } else {
      final companion = GoalsCompanion.insert(
        title: title,
        description: _descController.text.trim().isNotEmpty
            ? drift.Value(_descController.text.trim())
            : const drift.Value.absent(),
        category: drift.Value(_category),
        progressMode: drift.Value(_progressMode),
        targetDate: _targetDate != null ? drift.Value(_targetDate) : const drift.Value.absent(),
        targetValue: targetVal != null ? drift.Value(targetVal) : const drift.Value.absent(),
        unit: _unitController.text.trim().isNotEmpty
            ? drift.Value(_unitController.text.trim())
            : const drift.Value.absent(),
        currentValue: const drift.Value(0.0),
        status: const drift.Value('active'),
        createdAt: now,
        updatedAt: now,
      );

      final newGoalId = await db.insertNewGoal(companion);

      // Insert initial milestones if any
      if (_progressMode == 'milestones' && _initialMilestones.isNotEmpty) {
        for (int i = 0; i < _initialMilestones.length; i++) {
          await db.insertNewMilestone(
            MilestonesCompanion.insert(
              goalId: newGoalId,
              title: _initialMilestones[i],
              sortOrder: drift.Value(i),
              weight: const drift.Value(1),
              status: const drift.Value('pending'),
              createdAt: now,
              updatedAt: now,
            ),
          );
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final categories = [
      {'key': 'personal', 'label': l10n.categoryPersonal, 'icon': Icons.person_outline},
      {'key': 'work', 'label': l10n.categoryWork, 'icon': Icons.business_center_outlined},
      {'key': 'study', 'label': l10n.categoryStudy, 'icon': Icons.school_outlined},
      {'key': 'health', 'label': l10n.categoryHealth, 'icon': Icons.favorite_outline},
      {'key': 'finance', 'label': l10n.categoryFinance, 'icon': Icons.account_balance_wallet_outlined},
      {'key': 'other', 'label': l10n.categoryOther, 'icon': Icons.star_outline},
    ];

    return Padding(
      padding: EdgeInsets.only(
        bottom: bottomInset,
        left: 20,
        right: 20,
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
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Sheet title
            Row(
              children: [
                Icon(Icons.flag_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  isEdit ? l10n.editGoal : l10n.addGoal,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Goal Title input
            TextField(
              controller: _titleController,
              focusNode: _titleFocusNode,
              decoration: InputDecoration(
                hintText: l10n.goalTitle,
                prefixIcon: const Icon(Icons.title_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
              ),
            ),
            const SizedBox(height: 12),

            // Goal Description input
            TextField(
              controller: _descController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: l10n.goalDescription,
                prefixIcon: const Icon(Icons.notes_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
              ),
            ),
            const SizedBox(height: 16),

            // Category choice chips
            Text(
              l10n.category,
              style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: categories.map((cat) {
                  final isSelected = _category == cat['key'];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      avatar: Icon(cat['icon'] as IconData, size: 16),
                      label: Text(cat['label'] as String),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _category = cat['key'] as String);
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Progress Mode selector
            Text(
              l10n.progressMode,
              style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: [
                ButtonSegment<String>(
                  value: 'milestones',
                  label: Text(l10n.modeMilestones),
                  icon: const Icon(Icons.checklist_rounded),
                ),
                ButtonSegment<String>(
                  value: 'numeric',
                  label: Text(l10n.modeNumeric),
                  icon: const Icon(Icons.numbers_rounded),
                ),
              ],
              selected: {_progressMode},
              onSelectionChanged: (val) {
                setState(() => _progressMode = val.first);
              },
            ),
            const SizedBox(height: 16),

            // Target Date picker
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.calendar_today_rounded, color: theme.colorScheme.primary),
              title: Text(l10n.targetDate),
              subtitle: Text(
                _targetDate ?? l10n.noTargetDate,
                style: TextStyle(
                  color: _targetDate != null ? theme.colorScheme.primary : theme.colorScheme.outline,
                  fontWeight: FontWeight.bold,
                ),
              ),
              trailing: OutlinedButton(
                onPressed: _pickTargetDate,
                child: Text(l10n.datePick),
              ),
            ),
            const Divider(),

            // Mode-specific configuration
            if (_progressMode == 'numeric') ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _targetValueController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: l10n.targetValue,
                        hintText: '5000',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _unitController,
                      decoration: InputDecoration(
                        labelText: l10n.unit,
                        hintText: l10n.unitHint,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Milestones mode: Initial milestones (if creating new)
              if (!isEdit) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.milestones,
                  style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _milestoneInputController,
                        onSubmitted: (_) => _addInitialMilestone(),
                        decoration: InputDecoration(
                          hintText: l10n.milestoneTitle,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.add_rounded),
                      onPressed: _addInitialMilestone,
                    ),
                  ],
                ),
                if (_initialMilestones.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _initialMilestones.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final m = entry.value;
                      return Chip(
                        label: Text(m),
                        deleteIcon: const Icon(Icons.close_rounded, size: 16),
                        onDeleted: () {
                          setState(() => _initialMilestones.removeAt(idx));
                        },
                      );
                    }).toList(),
                  ),
                ],
              ],
            ],

            const SizedBox(height: 24),

            // Save button
            FilledButton.icon(
              icon: const Icon(Icons.check_rounded),
              label: Text(isEdit ? l10n.save : l10n.save),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _saveGoal,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
