import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;

import '../../../core/db/app_database.dart';
import '../domain/habits_service.dart';
import 'habit_icon_helper.dart';

class SuggestedHabitsSheet extends ConsumerWidget {
  const SuggestedHabitsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SuggestedHabitsSheet(),
    );
  }

  Future<void> _addTemplate(BuildContext context, WidgetRef ref, SuggestedHabitTemplate template) async {
    final db = ref.read(databaseProvider);
    final now = DateTime.now().millisecondsSinceEpoch;
    final todayStr = HabitsService.formatDate(DateTime.now());
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final habitId = await db.insertHabit(
      HabitsCompanion.insert(
        nameAr: template.nameAr,
        nameEn: drift.Value(template.nameEn),
        type: template.type,
        unit: drift.Value(template.unit),
        dailyTarget: drift.Value(template.dailyTarget),
        icon: drift.Value(template.icon),
        color: drift.Value(template.colorHex),
        scheduleDays: const drift.Value(127),
        builtinKey: drift.Value(template.builtinKey),
        occurredAt: drift.Value(now),
        localDate: drift.Value(todayStr),
        createdAt: now,
        updatedAt: now,
      ),
    );

    if (template.checklistItems.isNotEmpty) {
      for (int i = 0; i < template.checklistItems.length; i++) {
        await db.insertHabitItem(
          HabitItemsCompanion.insert(
            habitId: habitId,
            name: template.checklistItems[i],
            sortOrder: drift.Value(i),
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
    }

    if (context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? 'تمت إضافة عادة "${template.nameAr}" بنجاح'
                : 'Habit "${template.nameEn}" added successfully',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: Colors.amber),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isArabic ? 'العادات المقترحة الجاهزة' : 'Suggested Habits',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isArabic
                ? 'أضف أي عادة مقترحة بلمسة واحدة، ويمكنك تعديلها بالكامل لاحقاً'
                : 'Add any suggested habit in one tap, fully customizable later',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: HabitsService.suggestedHabits.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final template = HabitsService.suggestedHabits[index];
                final color = Color(int.parse(template.colorHex.replaceFirst('#', '0xFF')));

                return Card(
                  elevation: 0,
                  color: color.withValues(alpha: 0.08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: color.withValues(alpha: 0.3)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: CircleAvatar(
                      backgroundColor: color,
                      child: Icon(HabitIconHelper.getIcon(template.icon), color: Colors.white, size: 22),
                    ),
                    title: Text(
                      isArabic ? template.nameAr : template.nameEn,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      _formatTemplateSubtitle(template, isArabic),
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
                    ),
                    trailing: FilledButton.tonal(
                      onPressed: () => _addTemplate(context, ref, template),
                      child: Text(isArabic ? 'إضافة' : 'Add'),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  String _formatTemplateSubtitle(SuggestedHabitTemplate t, bool isArabic) {
    if (t.type == 'checklist') {
      return isArabic ? 'قائمة (${t.checklistItems.length} بنود)' : 'Checklist (${t.checklistItems.length} items)';
    } else if (t.type == 'check') {
      return isArabic ? 'صح أو لسه يومياً' : 'Daily check';
    } else if (t.dailyTarget != null && t.unit != null) {
      final targetStr = t.dailyTarget! % 1 == 0 ? t.dailyTarget!.toInt().toString() : t.dailyTarget.toString();
      return isArabic ? 'الهدف: $targetStr ${t.unit}' : 'Target: $targetStr ${t.unit}';
    } else {
      return t.type;
    }
  }
}
