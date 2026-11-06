import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;

import '../../../core/db/app_database.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/money_formatter.dart';
import '../../reminders/domain/reminder_scheduler.dart';
import '../domain/finance_service.dart';

class ObligationsTab extends ConsumerStatefulWidget {
  const ObligationsTab({super.key});

  @override
  ConsumerState<ObligationsTab> createState() => _ObligationsTabState();
}

class _ObligationsTabState extends ConsumerState<ObligationsTab> {
  static const _service = FinanceService();

  void _showAddEditObligationSheet([Obligation? existing]) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final amountCtrl = TextEditingController(
      text: existing != null ? MoneyFormatter.formatAmount(existing.amountMinor, showDecimals: false) : '',
    );
    final counterpartCtrl = TextEditingController(text: existing?.counterpart ?? '');
    final noteCtrl = TextEditingController(text: existing?.note ?? '');
    final installmentsCtrl = TextEditingController(
      text: existing?.installmentsTotal != null ? existing!.installmentsTotal.toString() : '',
    );

    String kind = existing?.kind ?? 'installment';
    String frequency = existing?.frequency ?? 'monthly';
    int dueDay = existing?.dueDay ?? DateTime.now().day;
    DateTime startDate = existing != null ? DateTime.tryParse(existing.startDate) ?? DateTime.now() : DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            left: 20,
            right: 20,
            top: 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  existing == null
                      ? (isArabic ? 'إضافة التزام أو قسط جديد' : 'Add Obligation')
                      : (isArabic ? 'تعديل الالتزام' : 'Edit Obligation'),
                  style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: isArabic ? 'اسم الالتزام (مثال: إيجار، قسط شقة، نت)' : 'Name',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: isArabic ? 'المبلغ (ج.م)' : 'Amount (EGP)',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: kind,
                  decoration: InputDecoration(
                    labelText: isArabic ? 'النوع' : 'Kind',
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(value: 'installment', child: Text(isArabic ? 'قسط' : 'Installment')),
                    DropdownMenuItem(value: 'bill', child: Text(isArabic ? 'فاتورة' : 'Bill')),
                    DropdownMenuItem(value: 'debt', child: Text(isArabic ? 'دين' : 'Debt')),
                    DropdownMenuItem(value: 'subscription', child: Text(isArabic ? 'اشتراك' : 'Subscription')),
                    DropdownMenuItem(value: 'other', child: Text(isArabic ? 'أخرى' : 'Other')),
                  ],
                  onChanged: (val) {
                    if (val != null) setSheetState(() => kind = val);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: frequency,
                  decoration: InputDecoration(
                    labelText: isArabic ? 'التكرار' : 'Frequency',
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(value: 'monthly', child: Text(isArabic ? 'شهرياً' : 'Monthly')),
                    DropdownMenuItem(value: 'weekly', child: Text(isArabic ? 'أسبوعياً' : 'Weekly')),
                    DropdownMenuItem(value: 'once', child: Text(isArabic ? 'مرة واحدة' : 'Once')),
                    DropdownMenuItem(value: 'yearly', child: Text(isArabic ? 'سنوياً' : 'Yearly')),
                  ],
                  onChanged: (val) {
                    if (val != null) setSheetState(() => frequency = val);
                  },
                ),
                const SizedBox(height: 12),
                if (frequency == 'monthly')
                  Row(
                    children: [
                      Text(isArabic ? 'يوم الاستحقاق من كل شهر:' : 'Due day of month:'),
                      const SizedBox(width: 16),
                      DropdownButton<int>(
                        value: dueDay.clamp(1, 31),
                        items: List.generate(31, (i) => i + 1).map((d) {
                          return DropdownMenuItem(value: d, child: Text('$d'));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setSheetState(() => dueDay = val);
                        },
                      ),
                    ],
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: counterpartCtrl,
                  decoration: InputDecoration(
                    labelText: isArabic ? 'الجهة أو الشخص المستحق (اختياري)' : 'Counterpart / Creditor',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: installmentsCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: isArabic ? 'إجمالي عدد الأقساط (اختياري)' : 'Total Installments (optional)',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  decoration: InputDecoration(
                    labelText: isArabic ? 'ملاحظات' : 'Notes',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    final amountMinor = MoneyFormatter.parseToMinor(amountCtrl.text);
                    if (name.isEmpty || amountMinor <= 0) return;

                    final db = ref.read(databaseProvider);
                    final now = DateTime.now();
                    final startDateStr = "${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}";
                    final totalInst = int.tryParse(installmentsCtrl.text.trim());

                    if (existing != null) {
                      await db.updateObligation(
                        ObligationsCompanion(
                          id: drift.Value(existing.id),
                          name: drift.Value(name),
                          kind: drift.Value(kind),
                          amountMinor: drift.Value(amountMinor),
                          frequency: drift.Value(frequency),
                          dueDay: drift.Value(frequency == 'monthly' ? dueDay : null),
                          counterpart: drift.Value(counterpartCtrl.text.trim().isEmpty ? null : counterpartCtrl.text.trim()),
                          installmentsTotal: drift.Value(totalInst),
                          note: drift.Value(noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim()),
                          updatedAt: drift.Value(now.millisecondsSinceEpoch),
                        ),
                      );
                    } else {
                      final obId = await db.insertObligation(
                        ObligationsCompanion.insert(
                          name: name,
                          kind: kind,
                          amountMinor: amountMinor,
                          frequency: drift.Value(frequency),
                          dueDay: drift.Value(frequency == 'monthly' ? dueDay : null),
                          startDate: startDateStr,
                          counterpart: drift.Value(counterpartCtrl.text.trim().isEmpty ? null : counterpartCtrl.text.trim()),
                          installmentsTotal: drift.Value(totalInst),
                          note: drift.Value(noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim()),
                          createdAt: now.millisecondsSinceEpoch,
                          updatedAt: now.millisecondsSinceEpoch,
                        ),
                      );

                      // Generate instances for next 3 months
                      final instanceDates = _service.generateInstancesDates(
                        frequency: frequency,
                        startDate: startDateStr,
                        dueDay: dueDay,
                        amountMinor: amountMinor,
                        installmentsTotal: totalInst,
                        fromDate: now,
                        monthsAhead: 3,
                      );

                      for (final inst in instanceDates) {
                        await db.into(db.obligationInstances).insert(
                              ObligationInstancesCompanion.insert(
                                obligationId: obId,
                                dueDate: inst.dueDate,
                                amountMinor: inst.amountMinor,
                                status: const drift.Value('pending'),
                                createdAt: now.millisecondsSinceEpoch,
                                updatedAt: now.millisecondsSinceEpoch,
                              ),
                            );
                      }
                    }

                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                  child: Text(isArabic ? 'حفظ' : 'Save'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _markInstancePaid(BuildContext context, ObligationInstance instance, Obligation ob) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final amountCtrl = TextEditingController(
      text: MoneyFormatter.formatAmount(instance.amountMinor, showDecimals: false),
    );
    bool recordAsExpense = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isArabic ? 'سداد الالتزام' : 'Pay Obligation'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${ob.name}: ${MoneyFormatter.formatWithCurrency(instance.amountMinor, currency: isArabic ? 'ج.م' : 'EGP')}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: isArabic ? 'المبلغ المدفوع (ج.م)' : 'Paid Amount (EGP)',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: recordAsExpense,
                title: Text(
                  isArabic ? 'تسجيل العملية كمصروف في المعاملات' : 'Record as an expense transaction',
                  style: const TextStyle(fontSize: 13),
                ),
                onChanged: (val) => setDialogState(() => recordAsExpense = val ?? true),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(isArabic ? 'إلغاء' : 'Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final paidMinor = MoneyFormatter.parseToMinor(amountCtrl.text);
                final db = ref.read(databaseProvider);
                final now = DateTime.now();
                final localDate = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

                int? txId;
                if (recordAsExpense) {
                  txId = await db.insertTransaction(
                    TransactionsCompanion.insert(
                      kind: 'expense',
                      amountMinor: paidMinor,
                      categoryId: 14, // أقساط والتزامات
                      nature: const drift.Value('essential'),
                      occurredAt: now.millisecondsSinceEpoch,
                      localDate: localDate,
                      note: drift.Value('سداد: ${ob.name}'),
                      obligationInstanceId: drift.Value(instance.id),
                      createdAt: now.millisecondsSinceEpoch,
                      updatedAt: now.millisecondsSinceEpoch,
                    ),
                  );
                }

                await db.markObligationInstancePaid(instance.id, paidMinor, txId);
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: Text(isArabic ? 'تأكيد السداد' : 'Confirm Payment'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddReminderSheet(BuildContext context, Obligation ob) async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    int offsetDays = 1;
    String reminderKind = 'alarm';

    showModalBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isArabic ? 'ضبط تذكير للالتزام: ${ob.name}' : 'Set Reminder: ${ob.name}',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(isArabic ? 'التنبيه قبل موعد الاستحقاق بـ:' : 'Remind before:'),
                  DropdownButton<int>(
                    value: offsetDays,
                    items: [
                      DropdownMenuItem(value: 0, child: Text(isArabic ? 'في نفس اليوم' : 'Same day')),
                      DropdownMenuItem(value: 1, child: Text(isArabic ? 'قبلها بيوم' : '1 day before')),
                      DropdownMenuItem(value: 2, child: Text(isArabic ? 'قبلها بيومين' : '2 days before')),
                      DropdownMenuItem(value: 3, child: Text(isArabic ? 'قبلها بـ 3 أيام' : '3 days before')),
                    ],
                    onChanged: (val) {
                      if (val != null) setSheetState(() => offsetDays = val);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'alarm',
                    icon: const Icon(Icons.alarm_rounded),
                    label: Text(isArabic ? 'منبه رنان' : 'Alarm'),
                  ),
                  ButtonSegment(
                    value: 'notification',
                    icon: const Icon(Icons.notifications_active_rounded),
                    label: Text(isArabic ? 'إشعار عادي' : 'Notification'),
                  ),
                ],
                selected: {reminderKind},
                onSelectionChanged: (set) => setSheetState(() => reminderKind = set.first),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () async {
                  final db = ref.read(databaseProvider);
                  final now = DateTime.now();
                  final reminderId = await db.insertReminder(
                    ownerType: 'obligation',
                    ownerId: ob.id,
                    kind: reminderKind,
                    triggerType: 'offset',
                    offsetMinutes: offsetDays * 24 * 60,
                    message: isArabic ? 'استحقاق: ${ob.name}' : 'Due: ${ob.name}',
                    enabled: true,
                  );

                  final rem = await db.getReminderById(reminderId);
                  if (rem != null && ctx.mounted) {
                    await ReminderScheduler(db: db).scheduleReminder(
                      reminder: rem,
                      title: ob.name,
                      dueDate: ob.dueDate ?? ob.startDate,
                      dueTime: '09:00',
                      languageCode: Localizations.localeOf(context).languageCode,
                    );
                  }
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
                child: Text(isArabic ? 'تفعيل التذكير' : 'Set Reminder'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final numeralsFormat = ref.watch(numeralsProvider);
    final isMasked = ref.watch(financeMaskedProvider);
    final db = ref.watch(databaseProvider);

    final now = DateTime.now();
    final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final soonLimit = now.add(const Duration(days: 7));
    final soonLimitStr = "${soonLimit.year}-${soonLimit.month.toString().padLeft(2, '0')}-${soonLimit.day.toString().padLeft(2, '0')}";

    return StreamBuilder<List<Obligation>>(
      stream: db.watchObligations(),
      builder: (context, obSnap) {
        final obligations = obSnap.data ?? [];
        final obMap = {for (final o in obligations) o.id: o};

        return StreamBuilder<List<ObligationInstance>>(
          stream: db.watchObligationInstancesForMonth("${now.year}-${now.month.toString().padLeft(2, '0')}"),
          builder: (context, instSnap) {
            final allInstances = instSnap.data ?? [];

            final lateInstances = <ObligationInstance>[];
            final dueSoonInstances = <ObligationInstance>[];
            final upcomingInstances = <ObligationInstance>[];
            final paidInstances = <ObligationInstance>[];

            for (final inst in allInstances) {
              if (inst.status == 'paid') {
                paidInstances.add(inst);
              } else if (inst.status == 'skipped') {
                continue;
              } else if (inst.dueDate.compareTo(todayStr) < 0) {
                lateInstances.add(inst);
              } else if (inst.dueDate.compareTo(soonLimitStr) <= 0) {
                dueSoonInstances.add(inst);
              } else {
                upcomingInstances.add(inst);
              }
            }

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isArabic ? 'الالتزامات والأقساط' : 'Obligations',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => _showAddEditObligationSheet(),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: Text(isArabic ? 'إضافة التزام' : 'Add Obligation'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 1. Late section (متأخرة)
                if (lateInstances.isNotEmpty) ...[
                  _buildSectionHeader(
                    context,
                    title: isArabic ? 'متأخرة السداد ⚠️' : 'Late Dues ⚠️',
                    color: Colors.red,
                    count: lateInstances.length,
                  ),
                  ...lateInstances.map((i) => _buildInstanceCard(context, i, obMap[i.obligationId], Colors.red)),
                  const SizedBox(height: 12),
                ],

                // 2. Due soon section (قريبة)
                if (dueSoonInstances.isNotEmpty) ...[
                  _buildSectionHeader(
                    context,
                    title: isArabic ? 'مستحقة قريباً (خلال 7 أيام)' : 'Due Soon (Next 7 days)',
                    color: Colors.orange,
                    count: dueSoonInstances.length,
                  ),
                  ...dueSoonInstances.map((i) => _buildInstanceCard(context, i, obMap[i.obligationId], Colors.orange)),
                  const SizedBox(height: 12),
                ],

                // 3. Upcoming section (قادمة)
                if (upcomingInstances.isNotEmpty) ...[
                  _buildSectionHeader(
                    context,
                    title: isArabic ? 'قادمة' : 'Upcoming',
                    color: Colors.blue,
                    count: upcomingInstances.length,
                  ),
                  ...upcomingInstances.map((i) => _buildInstanceCard(context, i, obMap[i.obligationId], Colors.blue)),
                  const SizedBox(height: 12),
                ],

                // 4. Paid section (مدفوعة)
                if (paidInstances.isNotEmpty) ...[
                  _buildSectionHeader(
                    context,
                    title: isArabic ? 'تم سدادها بنجاح ✅' : 'Paid ✅',
                    color: Colors.green,
                    count: paidInstances.length,
                  ),
                  ...paidInstances.map((i) => _buildInstanceCard(context, i, obMap[i.obligationId], Colors.green)),
                  const SizedBox(height: 12),
                ],

                if (allInstances.isEmpty && obligations.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40.0),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.account_balance_outlined, size: 60, color: theme.colorScheme.outlineVariant),
                          const SizedBox(height: 12),
                          Text(
                            isArabic ? 'لا توجد التزامات مسجلة حالياً' : 'No obligations recorded',
                            style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.outline),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 80),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSectionHeader(BuildContext context, {required String title, required Color color, required int count}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 8),
          Text(
            '$title ($count)',
            style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildInstanceCard(BuildContext context, ObligationInstance inst, Obligation? ob, Color statusColor) {
    if (ob == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final numeralsFormat = ref.watch(numeralsProvider);
    final isMasked = ref.watch(financeMaskedProvider);
    final isPaid = inst.status == 'paid';

    final amountFormatted = MoneyFormatter.formatWithCurrency(
      inst.amountMinor,
      currency: isArabic ? 'ج.م' : 'EGP',
      masked: isMasked,
      format: numeralsFormat,
    );

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    ob.name,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  amountFormatted,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  '${isArabic ? 'موعد الاستحقاق:' : 'Due:'} ${inst.dueDate}',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                ),
                if (ob.counterpart != null && ob.counterpart!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text('• ${ob.counterpart}', style: theme.textTheme.bodySmall),
                ],
                const Spacer(),
                if (!isPaid) ...[
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      backgroundColor: Colors.green,
                    ),
                    onPressed: () => _markInstancePaid(context, inst, ob),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: Text(isArabic ? 'تم الدفع' : 'Paid'),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.alarm_add_rounded, size: 20),
                    tooltip: isArabic ? 'تذكير' : 'Reminder',
                    onPressed: () => _showAddReminderSheet(context, ob),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
