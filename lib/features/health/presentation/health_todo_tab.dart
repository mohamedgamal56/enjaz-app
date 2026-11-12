import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;

import '../../../core/db/app_database.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/widgets/widgets.dart';
import '../../reminders/domain/reminder_scheduler.dart';
import '../domain/health_service.dart';
import 'health_icon_helper.dart';
import 'health_event_history_sheet.dart';
import 'add_edit_health_item_sheet.dart';

class HealthTodoTab extends ConsumerWidget {
  const HealthTodoTab({super.key});

  Future<void> _scheduleAppointment(BuildContext context, WidgetRef ref, HealthItem item) async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final initialDate = item.scheduledAt != null
        ? DateTime.fromMillisecondsSinceEpoch(item.scheduledAt!)
        : DateTime.now().add(const Duration(days: 1));

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime(2046),
    );
    if (pickedDate == null || !context.mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );
    if (pickedTime == null || !context.mounted) return;

    final scheduledDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    final db = ref.read(databaseProvider);
    await db.scheduleHealthItem(
      item.id,
      scheduledAt: scheduledDateTime,
      placeOrDoctor: item.placeOrDoctor,
    );

    // Schedule appointment reminders (the day before and at the time)
    final reminderScheduler = ReminderScheduler(db: db);
    // At the time
    final remId1 = await db.insertReminder(
      ownerType: 'health_item',
      ownerId: item.id,
      kind: 'alarm',
      triggerType: 'absolute',
      absoluteTime: scheduledDateTime,
      message: isArabic ? 'موعد فحص: ${item.title}' : 'Appointment: ${item.title}',
    );
    final rem1 = await db.getReminderById(remId1);
    if (rem1 != null) {
      await reminderScheduler.scheduleReminder(
        reminder: rem1,
        title: item.title,
        languageCode: isArabic ? 'ar' : 'en',
      );
    }

    // 1 day before
    final dayBefore = scheduledDateTime.subtract(const Duration(days: 1));
    if (dayBefore.isAfter(DateTime.now())) {
      final remId2 = await db.insertReminder(
        ownerType: 'health_item',
        ownerId: item.id,
        kind: 'notification',
        triggerType: 'absolute',
        absoluteTime: dayBefore,
        message: isArabic ? 'تذكير بموعد فحص غداً: ${item.title}' : 'Appointment tomorrow: ${item.title}',
      );
      final rem2 = await db.getReminderById(remId2);
      if (rem2 != null) {
        await reminderScheduler.scheduleReminder(
          reminder: rem2,
          title: item.title,
          languageCode: isArabic ? 'ar' : 'en',
        );
      }
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isArabic
              ? 'تم تحديد الموعد وجدولة التذكيرات بنجاح'
              : 'Appointment & reminders scheduled successfully',
        ),
      ),
    );
  }

  Future<void> _postponeItem(BuildContext context, WidgetRef ref, HealthItem item) async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isArabic ? 'تأجيل الفحص / الكشف' : 'Postpone Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isArabic
                  ? 'برجاء كتابة سبب التأجيل للمتابعة:'
                  : 'Please enter a postponement reason:',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: isArabic ? 'مثال: انشغال في العمل، تأجيل الطبيب...' : 'e.g. Busy with work, doctor rescheduled...',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(isArabic ? 'تأكيد التأجيل' : 'Confirm'),
          ),
        ],
      ),
    );

    if (confirmed == true && reasonController.text.trim().isNotEmpty) {
      final db = ref.read(databaseProvider);
      await db.postponeHealthItem(
        item.id,
        reason: reasonController.text.trim(),
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isArabic ? 'تم تأجيل الفحص' : 'Item postponed')),
      );
    }
  }

  Future<void> _completeItem(BuildContext context, WidgetRef ref, HealthItem item) async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final resultController = TextEditingController();
    final costController = TextEditingController(
      text: item.costMinor != null ? (item.costMinor! / 100).toStringAsFixed(0) : '',
    );
    bool followUp = false;
    bool createExpense = true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text(isArabic ? 'تسجيل إنجاز الفحص' : 'Mark as Done'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: resultController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: isArabic ? 'ملاحظة النتيجة (اختياري)' : 'Result Note (optional)',
                      hintText: isArabic ? 'مثال: التحاليل سليمة، مطلوب إعادة الفحص بعد 6 شهور...' : 'e.g. Normal results...',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: costController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: isArabic ? 'التكلفة الفعلية (ج.م)' : 'Actual Cost (EGP)',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.attach_money_rounded),
                    ),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(isArabic ? 'مطلوب متابعة لاحقة' : 'Follow-up needed'),
                    value: followUp,
                    onChanged: (val) => setDialogState(() => followUp = val ?? false),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(isArabic ? 'تسجيل مصروف في قسم المال' : 'Record finance expense'),
                    value: createExpense,
                    onChanged: (val) => setDialogState(() => createExpense = val ?? false),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(isArabic ? 'إلغاء' : 'Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(isArabic ? 'تم الإنجاز' : 'Mark Done'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed == true) {
      final db = ref.read(databaseProvider);
      final costMinor = MoneyFormatter.parseToMinor(costController.text.trim());
      final now = DateTime.now();

      await db.completeHealthItem(
        item.id,
        doneDate: now,
        resultNote: resultController.text.trim().isNotEmpty ? resultController.text.trim() : null,
        followUpNeeded: followUp,
        costMinor: costMinor > 0 ? costMinor : null,
      );

      // Cancel reminders
      final reminderScheduler = ReminderScheduler(db: db);
      await reminderScheduler.cancelAllForOwner('health_item', item.id);

      // Optional: create finance transaction
      if (createExpense && costMinor > 0) {
        final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        // find health category
        final cats = await db.getAllFinanceCategories();
        final healthCat = cats.firstWhere(
          (c) => c.nameAr.contains('صحة') || (c.nameEn?.toLowerCase().contains('health') ?? false),
          orElse: () => cats.first,
        );

        await db.insertTransaction(
          TransactionsCompanion.insert(
            kind: 'expense',
            amountMinor: costMinor,
            categoryId: healthCat.id,
            nature: const drift.Value('essential'),
            occurredAt: now.millisecondsSinceEpoch,
            localDate: dateStr,
            note: drift.Value('فحص طبي: ${item.title}'),
            paymentMethod: const drift.Value('cash'),
            createdAt: now.millisecondsSinceEpoch,
            updatedAt: now.millisecondsSinceEpoch,
          ),
        );
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? 'تم تسجيل إنجاز الفحص بنجاح'
                : 'Checkup marked as done',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final numeralsFormat = ref.watch(numeralsProvider);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final theme = Theme.of(context);
    const healthService = HealthService();

    return StreamBuilder<List<HealthItem>>(
      stream: db.watchActiveHealthItems(),
      builder: (context, snapshot) {
        final items = snapshot.data ?? [];

        if (items.isEmpty) {
          return Center(
            child: EmptyState(
              icon: Icons.health_and_safety_outlined,
              title: isArabic ? 'لا توجد فحوصات أو كشوفات مطلوبة حالياً' : 'No pending checkups or tests',
              subtitle: isArabic ? 'اضغط على زر + بالأسفل لإضافة فحص أو كشف' : 'Tap + button below to add an item',
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final waiting = healthService.calculateWaitingDuration(item.neededSince);
            final waitingStr = waiting.format(isArabic, numerals: numeralsFormat);
            final isNeglected = waiting.totalDays >= 30;

            String? scheduledStr;
            if (item.scheduledAt != null) {
              scheduledStr = AppFormatter.formatDateTime(
                DateTime.fromMillisecondsSinceEpoch(item.scheduledAt!),
                locale: Localizations.localeOf(context).toString(),
                format: numeralsFormat,
              );
            }

            return AppCard(
              margin: const EdgeInsets.only(bottom: 12.0),
              padding: const EdgeInsets.all(14.0),
              borderColor: isNeglected ? Colors.orange.withValues(alpha: 0.5) : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    // Header row
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: HealthIconHelper.getStatusColor(item.status).withValues(alpha: 0.15),
                          child: Icon(
                            HealthIconHelper.getKindIcon(item.kind),
                            size: 18,
                            color: HealthIconHelper.getStatusColor(item.status),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (item.placeOrDoctor != null && item.placeOrDoctor!.isNotEmpty)
                                Text(
                                  item.placeOrDoctor!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.outline,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Waiting pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isNeglected
                                ? Colors.orange.withValues(alpha: 0.15)
                                : theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isNeglected ? Colors.orange : theme.colorScheme.outlineVariant,
                            ),
                          ),
                          child: Text(
                            waitingStr,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isNeglected ? FontWeight.bold : FontWeight.normal,
                              color: isNeglected ? Colors.deepOrange : theme.colorScheme.outline,
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
                                builder: (_) => AddEditHealthItemSheet(itemToEdit: item),
                              );
                            } else if (val == 'history') {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                builder: (_) => HealthEventHistorySheet(item: item),
                              );
                            } else if (val == 'delete') {
                              db.softDeleteHealthItem(item.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(isArabic ? 'تم نقل الفحص إلى السلة' : 'Moved to trash')),
                              );
                            }
                          },
                          itemBuilder: (ctx) => [
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
                              value: 'history',
                              child: Row(
                                children: [
                                  const Icon(Icons.history_rounded, size: 18),
                                  const SizedBox(width: 8),
                                  Text(isArabic ? 'سجل الإجراءات' : 'History'),
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

                    // Scheduled or postponed info
                    if (item.status == 'scheduled' && scheduledStr != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.event_available_rounded, size: 16, color: Colors.blue),
                            const SizedBox(width: 6),
                            Text(
                              '${isArabic ? 'الموعد:' : 'Appointment:'} $scheduledStr',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (item.status == 'postponed') ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.history_toggle_off_rounded, size: 16, color: Colors.amber),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${isArabic ? 'مؤجل (${item.postponeCount} مرات):' : 'Postponed (${item.postponeCount}x):'} ${item.postponedReason ?? ''}',
                                style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),
                    // Action Buttons Row
                    Row(
                      children: [
                        // Schedule button
                        OutlinedButton.icon(
                          onPressed: () => _scheduleAppointment(context, ref, item),
                          icon: const Icon(Icons.calendar_month_rounded, size: 16),
                          label: Text(isArabic ? 'جدولة موعد' : 'Schedule', style: const TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Postpone button
                        OutlinedButton.icon(
                          onPressed: () => _postponeItem(context, ref, item),
                          icon: const Icon(Icons.update_rounded, size: 16),
                          label: Text(isArabic ? 'تأجيل' : 'Postpone', style: const TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const Spacer(),
                        // Done button
                        FilledButton.icon(
                          onPressed: () => _completeItem(context, ref, item),
                          icon: const Icon(Icons.check_circle_rounded, size: 16),
                          label: Text(isArabic ? 'تم الإنجاز' : 'Done', style: const TextStyle(fontSize: 12)),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
          },
        );
      },
    );
  }
}
