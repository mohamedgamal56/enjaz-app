import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/utils/date_formatter.dart';
import '../../reminders/domain/reminder_scheduler.dart';
import '../domain/health_service.dart';
import 'health_icon_helper.dart';
import 'add_edit_treatment_sheet.dart';

class TreatmentsTab extends ConsumerWidget {
  const TreatmentsTab({super.key});

  String _getTodayDateStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _setDoseReminder(BuildContext context, WidgetRef ref, Treatment tr) async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (pickedTime == null || !context.mounted) return;

    final db = ref.read(databaseProvider);
    final now = DateTime.now();
    final scheduledDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    // If time is before now, schedule for tomorrow
    final targetDateTime = scheduledDateTime.isBefore(now)
        ? scheduledDateTime.add(const Duration(days: 1))
        : scheduledDateTime;

    final remId = await db.insertReminder(
      ownerType: 'treatment',
      ownerId: tr.id,
      kind: 'notification',
      triggerType: 'absolute',
      absoluteTime: targetDateTime,
      message: isArabic ? 'موعد جرعة علاج: ${tr.name}' : 'Medication time: ${tr.name}',
    );

    final rem = await db.getReminderById(remId);
    if (rem != null) {
      final scheduler = ReminderScheduler(db: db);
      await scheduler.scheduleReminder(
        reminder: rem,
        title: tr.name,
        languageCode: isArabic ? 'ar' : 'en',
      );
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isArabic
              ? 'تم ضبط تذكير بموعد الجرعة بنجاح'
              : 'Dose reminder set successfully',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final numeralsFormat = ref.watch(numeralsProvider);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final theme = Theme.of(context);
    const healthService = HealthService();
    final todayStr = _getTodayDateStr();

    return StreamBuilder<List<Treatment>>(
      stream: db.watchActiveTreatments(),
      builder: (context, snapshot) {
        final treatments = snapshot.data ?? [];

        if (treatments.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.medication_liquid_rounded,
                  size: 64,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(height: 12),
                Text(
                  isArabic ? 'لا توجد علاجات أو أدوية مسجلة حالياً' : 'No treatments or medications tracked',
                  style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.outline),
                ),
                const SizedBox(height: 8),
                Text(
                  isArabic ? 'اضغط على زر + بالأسفل لإضافة كورس علاجي' : 'Tap + button below to add medication',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          itemCount: treatments.length,
          itemBuilder: (context, index) {
            final tr = treatments[index];

            return StreamBuilder<List<TreatmentCheck>>(
              stream: db.watchTreatmentChecks(tr.id),
              builder: (context, checkSnap) {
                final checks = checkSnap.data ?? [];
                final isCheckedToday = checks.any((c) => c.checkDate == todayStr && c.taken);

                final metrics = healthService.calculateTreatmentAdherence(
                  startDate: tr.startDate,
                  endDate: tr.endDate,
                  checks: checks,
                );

                final adherenceLabel = HealthIconHelper.getAdherenceLabel(tr.adherence, isArabic);
                final adherenceColor = HealthIconHelper.getAdherenceColor(tr.adherence);

                return Card(
                  margin: const EdgeInsets.only(bottom: 12.0),
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header row
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.purple.withValues(alpha: 0.15),
                              child: const Icon(Icons.medication_rounded, size: 20, color: Colors.purple),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tr.name,
                                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  if (tr.instructionsNote != null && tr.instructionsNote!.isNotEmpty)
                                    Text(
                                      tr.instructionsNote!,
                                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                                    ),
                                ],
                              ),
                            ),
                            // Adherence status chip
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: adherenceColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                adherenceLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: adherenceColor,
                                ),
                              ),
                            ),
                            // Popup menu
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert_rounded),
                              onSelected: (val) {
                                if (val == 'edit') {
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    builder: (_) => AddEditTreatmentSheet(treatmentToEdit: tr),
                                  );
                                } else if (val == 'reminder') {
                                  _setDoseReminder(context, ref, tr);
                                } else if (val == 'delete') {
                                  db.softDeleteTreatment(tr.id);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(isArabic ? 'تم نقل العلاج إلى السلة' : 'Moved to trash')),
                                  );
                                }
                              },
                              itemBuilder: (ctx) => [
                                PopupMenuItem(
                                  value: 'reminder',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.alarm_add_rounded, size: 18),
                                      const SizedBox(width: 8),
                                      Text(isArabic ? 'تذكير بالجرعة' : 'Dose Reminder'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.edit_rounded, size: 18),
                                      const SizedBox(width: 8),
                                      Text(isArabic ? 'تعديل' : 'Edit'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline_rounded, size: 18, color: theme.colorScheme.error),
                                      const SizedBox(width: 8),
                                      Text(isArabic ? 'حذف' : 'Delete', style: TextStyle(color: theme.colorScheme.error)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        // Purchased pill & duration
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: tr.purchased
                                    ? Colors.teal.withValues(alpha: 0.12)
                                    : Colors.orange.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    tr.purchased ? Icons.shopping_bag_outlined : Icons.remove_shopping_cart_outlined,
                                    size: 14,
                                    color: tr.purchased ? Colors.teal : Colors.orange,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    tr.purchased
                                        ? (isArabic ? 'تم الشراء' : 'Purchased')
                                        : (isArabic ? 'لم يُشترَ بعد' : 'Not bought'),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: tr.purchased ? Colors.teal : Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!tr.purchased) ...[
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => db.markTreatmentPurchased(tr.id),
                                child: Text(
                                  isArabic ? 'تحديد كـ "تم الشراء"' : 'Mark bought',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: theme.colorScheme.primary,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                            const Spacer(),
                            Text(
                              '${tr.startDate}${tr.endDate != null ? ' ➔ ${tr.endDate}' : ''}',
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                            ),
                          ],
                        ),

                        // Adherence Progress Bar & Daily Tick
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    isArabic ? 'نسبة الالتزام بالعلاج:' : 'Adherence:',
                                    style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    metrics.formatPercent(numerals: numeralsFormat),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: metrics.adherencePercent >= 80 ? Colors.green : Colors.orange,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    isArabic
                                        ? '${metrics.takenDays} من ${metrics.totalDays} يوم'
                                        : '${metrics.takenDays} of ${metrics.totalDays} days',
                                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: metrics.totalDays > 0 ? (metrics.adherencePercent / 100.0) : 0.0,
                                  minHeight: 8,
                                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                  color: metrics.adherencePercent >= 80 ? Colors.green : Colors.teal,
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Daily tick button ("مشيت عليه النهارده")
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.tonalIcon(
                                  onPressed: () {
                                    db.toggleTreatmentCheck(
                                      treatmentId: tr.id,
                                      checkDate: todayStr,
                                      taken: !isCheckedToday,
                                    );
                                  },
                                  icon: Icon(
                                    isCheckedToday ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                    color: isCheckedToday ? Colors.green : null,
                                  ),
                                  label: Text(
                                    isCheckedToday
                                        ? (isArabic ? 'مشيت عليه النهارده ✓' : 'Followed today ✓')
                                        : (isArabic ? 'مشيت عليه النهارده' : 'Followed today'),
                                    style: TextStyle(
                                      fontWeight: isCheckedToday ? FontWeight.bold : FontWeight.normal,
                                      color: isCheckedToday ? Colors.green.shade800 : null,
                                    ),
                                  ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: isCheckedToday
                                        ? Colors.green.withValues(alpha: 0.15)
                                        : null,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
