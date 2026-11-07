import 'package:flutter/material.dart';

import '../../action_plan.dart';

/// Interactive confirmation card displaying the interpreted action with fields in plain words,
/// chips for details/missing info, and three action buttons: تأكيد / Confirm, تعديل / Edit, إلغاء / Cancel (VOICE.md Section 2.4).
class ConfirmationCard extends StatelessWidget {
  final ActionPlan plan;
  final VoidCallback onConfirm;
  final VoidCallback onEdit;
  final VoidCallback onCancel;
  final ValueChanged<String>? onDateChipSelected;
  final ValueChanged<String>? onReasonSelected;
  final ValueChanged<CandidateTask>? onCandidateSelected;

  const ConfirmationCard({
    super.key,
    required this.plan,
    required this.onConfirm,
    required this.onEdit,
    required this.onCancel,
    this.onDateChipSelected,
    this.onReasonSelected,
    this.onCandidateSelected,
  });

  IconData _getActionIcon() {
    switch (plan.actionType) {
      case 'task':
        return Icons.task_alt_rounded;
      case 'errand':
        return Icons.directions_walk_rounded;
      case 'reminder':
        return Icons.alarm_rounded;
      case 'status_update':
        return Icons.update_rounded;
      case 'expense':
        return Icons.shopping_bag_outlined;
      case 'income':
        return Icons.payments_rounded;
      case 'habit':
        return Icons.repeat_rounded;
      case 'note':
        return Icons.edit_note_rounded;
      case 'idea':
        return Icons.lightbulb_outline_rounded;
      case 'wishlist':
        return Icons.card_giftcard_rounded;
      case 'health':
        return Icons.medical_services_outlined;
      case 'blocked':
        return Icons.block_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  Color _getActionColor(ColorScheme colorScheme) {
    switch (plan.actionType) {
      case 'task':
      case 'errand':
      case 'reminder':
        return Colors.blue;
      case 'status_update':
        return Colors.teal;
      case 'expense':
        return Colors.orange;
      case 'income':
        return Colors.green;
      case 'habit':
        return Colors.purple;
      case 'note':
        return Colors.amber.shade800;
      case 'idea':
        return Colors.indigo;
      case 'wishlist':
        return Colors.pink;
      case 'health':
        return Colors.red;
      case 'blocked':
        return colorScheme.error;
      default:
        return colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final actionColor = _getActionColor(colorScheme);

    if (plan.isBlocked) {
      return Card(
        color: colorScheme.errorContainer.withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.error.withValues(alpha: 0.5)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.shield_outlined, color: colorScheme.error, size: 28),
                  const SizedBox(width: 10),
                  Text(
                    'إجراء محظور بالصوت',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.error,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                plan.descriptionInWords,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onCancel,
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('إغلاق'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: actionColor.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Header with icon and action badge
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: actionColor.withValues(alpha: 0.15),
                  radius: 20,
                  child: Icon(_getActionIcon(), color: actionColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.actionTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'يرجى التأكيد للمتابعة',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 2. Main description in words (VOICE.md Section 2.4)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: actionColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: actionColor.withValues(alpha: 0.2)),
              ),
              child: Text(
                plan.descriptionInWords,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // 3. Ambiguous task candidates selection (if applicable)
            if (plan.isAmbiguous && plan.candidateTasks.isNotEmpty) ...[
              Text(
                'تم العثور على أكثر من مهمة مطابقة، اختر إحداها:',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...plan.candidateTasks.map((cand) {
                final isSelected = plan.slots['taskId'] == cand.id;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => onCandidateSelected?.call(cand),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? actionColor.withValues(alpha: 0.15) : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? actionColor : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                            size: 18,
                            color: isSelected ? actionColor : colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              cand.title,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (cand.dueDate != null)
                            Text(
                              cand.dueDate!,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 10),
            ],

            // 4. Missing date chips (VOICE.md Section 2.6)
            if (plan.hasMissingDate) ...[
              Text(
                'تاريخ المهمة:',
                style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('بدون تاريخ'),
                    selected: plan.selectedDateChip == 'none',
                    onSelected: (val) => onDateChipSelected?.call('none'),
                  ),
                  ChoiceChip(
                    label: const Text('اليوم'),
                    selected: plan.selectedDateChip == 'today',
                    onSelected: (val) => onDateChipSelected?.call('today'),
                  ),
                  ChoiceChip(
                    label: const Text('بكرة'),
                    selected: plan.selectedDateChip == 'tomorrow',
                    onSelected: (val) => onDateChipSelected?.call('tomorrow'),
                  ),
                  ChoiceChip(
                    label: const Text('اختر تاريخ'),
                    selected: plan.selectedDateChip == 'custom',
                    onSelected: (val) => onDateChipSelected?.call('custom'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],

            // 5. Missing reason chips (VOICE.md Section 2.6)
            if (plan.hasMissingReason) ...[
              Text(
                'السبب مطلوب، اختر سبباً:',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.error,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: plan.reasonChips.map((r) {
                  final isSelected = plan.slots['reason'] == r;
                  return ChoiceChip(
                    label: Text(r),
                    selected: isSelected,
                    onSelected: (val) => onReasonSelected?.call(r),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
            ],

            // 6. Action buttons (VOICE.md Section 2.4: تأكيد / Confirm, تعديل / Edit, إلغاء / Cancel)
            const SizedBox(height: 8),
            Row(
              children: [
                // تأكيد
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: actionColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: onConfirm,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text(
                      'تأكيد',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // تعديل
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('تعديل'),
                  ),
                ),
                const SizedBox(width: 8),

                // إلغاء
                IconButton(
                  tooltip: 'إلغاء',
                  style: IconButton.styleFrom(
                    foregroundColor: colorScheme.error,
                  ),
                  onPressed: onCancel,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
