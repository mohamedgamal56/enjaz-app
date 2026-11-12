import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

enum QuickAddOption {
  task,
  errand,
  expense,
  habit,
  note,
  idea,
  voiceNote,
}

/// QuickAddMenu (UI.md Section 3, 5 & Section 9)
/// Bottom sheet menu triggered by the '+' center button, offering direct entry points
/// for Task, Errand, Expense, Habit, Note, Idea, and Voice Note.
class QuickAddMenu extends StatelessWidget {
  final ValueChanged<QuickAddOption> onSelect;

  const QuickAddMenu({
    super.key,
    required this.onSelect,
  });

  static Future<QuickAddOption?> show(BuildContext context) {
    return showModalBottomSheet<QuickAddOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => QuickAddMenu(
        onSelect: (opt) {
          Navigator.of(ctx).pop(opt);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    final options = [
      _OptionItem(
        option: QuickAddOption.task,
        label: 'مهمة',
        icon: Icons.check_circle_outline_rounded,
        color: colors.accent,
      ),
      _OptionItem(
        option: QuickAddOption.errand,
        label: 'مشوار',
        icon: Icons.directions_walk_rounded,
        color: Colors.blueAccent,
      ),
      _OptionItem(
        option: QuickAddOption.expense,
        label: 'مصروف',
        icon: Icons.payments_outlined,
        color: Colors.teal,
      ),
      _OptionItem(
        option: QuickAddOption.habit,
        label: 'عادة',
        icon: Icons.repeat_rounded,
        color: Colors.indigoAccent,
      ),
      _OptionItem(
        option: QuickAddOption.note,
        label: 'ملاحظة',
        icon: Icons.edit_note_rounded,
        color: Colors.orangeAccent,
      ),
      _OptionItem(
        option: QuickAddOption.idea,
        label: 'فكرة',
        icon: Icons.lightbulb_outline_rounded,
        color: Colors.amber,
      ),
      _OptionItem(
        option: QuickAddOption.voiceNote,
        label: 'تسجيل صوتي',
        icon: Icons.mic_none_rounded,
        color: Colors.deepOrangeAccent,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
        border: Border(
          top: BorderSide(
            color: colors.border,
            width: 1.0,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Grab handle
              Center(
                child: Container(
                  width: 36.0,
                  height: 4.0,
                  margin: const EdgeInsets.only(bottom: 16.0),
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(999.0),
                  ),
                ),
              ),

              Text(
                'إضافة سريعة',
                style: AppTypography.cardTitle(context),
              ),
              const SizedBox(height: 16.0),

              // Options grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: options.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 12.0,
                  crossAxisSpacing: 12.0,
                  childAspectRatio: 0.85,
                ),
                itemBuilder: (context, index) {
                  final item = options[index];
                  return InkWell(
                    onTap: () => onSelect(item.option),
                    borderRadius: BorderRadius.circular(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 48.0,
                          height: 48.0,
                          decoration: BoxDecoration(
                            color: colors.surfaceVariant,
                            borderRadius: BorderRadius.circular(14.0),
                            border: Border.all(
                              color: colors.border,
                              width: 1.0,
                            ),
                          ),
                          child: Icon(
                            item.icon,
                            color: colors.text,
                            size: 24.0,
                          ),
                        ),
                        const SizedBox(height: 6.0),
                        Text(
                          item.label,
                          style: AppTypography.caption(context).copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionItem {
  final QuickAddOption option;
  final String label;
  final IconData icon;
  final Color color;

  const _OptionItem({
    required this.option,
    required this.label,
    required this.icon,
    required this.color,
  });
}
