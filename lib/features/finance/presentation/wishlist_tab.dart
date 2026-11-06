import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;

import '../../../core/db/app_database.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/money_formatter.dart';
import '../domain/finance_service.dart';

class WishlistTab extends ConsumerStatefulWidget {
  const WishlistTab({super.key});

  @override
  ConsumerState<WishlistTab> createState() => _WishlistTabState();
}

class _WishlistTabState extends ConsumerState<WishlistTab> {
  static const _service = FinanceService();

  void _showAddEditWishlistSheet([WishlistItem? existing]) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final priceCtrl = TextEditingController(
      text: existing != null ? MoneyFormatter.formatAmount(existing.estimatedPriceMinor, showDecimals: false) : '',
    );
    final noteCtrl = TextEditingController(text: existing?.note ?? '');
    String priority = existing?.priority ?? 'normal';
    String status = existing?.status ?? 'wanted';

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                existing == null
                    ? (isArabic ? 'إضافة إلى قائمة المشتريات' : 'Add to Wishlist')
                    : (isArabic ? 'تعديل عنصر المشتريات' : 'Edit Wishlist Item'),
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'اسم السلعة أو الغرض' : 'Item Name',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: isArabic ? 'السعر التقديري (ج.م)' : 'Estimated Price',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(isArabic ? 'الأولوية:' : 'Priority:'),
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(value: 'low', label: Text(isArabic ? 'منخفضة' : 'Low')),
                      ButtonSegment(value: 'normal', label: Text(isArabic ? 'عادية' : 'Normal')),
                      ButtonSegment(value: 'high', label: Text(isArabic ? 'عالية' : 'High')),
                    ],
                    selected: {priority},
                    onSelectionChanged: (set) => setSheetState(() => priority = set.first),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(isArabic ? 'الحالة:' : 'Status:'),
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(value: 'wanted', label: Text(isArabic ? 'مرغوبة' : 'Wanted')),
                      ButtonSegment(value: 'planned', label: Text(isArabic ? 'مخططة' : 'Planned')),
                    ],
                    selected: {status},
                    onSelectionChanged: (set) => setSheetState(() => status = set.first),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'ملاحظات ورابط السلعة' : 'Notes & Link',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  final priceMinor = MoneyFormatter.parseToMinor(priceCtrl.text);
                  if (name.isEmpty || priceMinor <= 0) return;

                  final db = ref.read(databaseProvider);
                  final now = DateTime.now().millisecondsSinceEpoch;

                  if (existing != null) {
                    await db.updateWishlistItem(
                      WishlistItemsCompanion(
                        id: drift.Value(existing.id),
                        name: drift.Value(name),
                        estimatedPriceMinor: drift.Value(priceMinor),
                        priority: drift.Value(priority),
                        status: drift.Value(status),
                        note: drift.Value(noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim()),
                        updatedAt: drift.Value(now),
                      ),
                    );
                  } else {
                    await db.insertWishlistItem(
                      WishlistItemsCompanion.insert(
                        name: name,
                        estimatedPriceMinor: priceMinor,
                        priority: drift.Value(priority),
                        status: drift.Value(status),
                        note: drift.Value(noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim()),
                        createdAt: now,
                        updatedAt: now,
                      ),
                    );
                  }
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
                child: Text(isArabic ? 'حفظ' : 'Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _markAsBought(BuildContext context, WishlistItem item) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final priceCtrl = TextEditingController(
      text: MoneyFormatter.formatAmount(item.estimatedPriceMinor, showDecimals: false),
    );
    int selectedCatId = 15; // default to أخرى or shopping

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isArabic ? 'مبروك الشراء! 🎉' : 'Purchase Confirmed! 🎉'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isArabic
                  ? 'سيتم تسجيل العملية كمصروف وتحديث حالة السلعة إلى "تم الشراء".'
                  : 'This will record an expense and mark the item as bought.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: isArabic ? 'السعر الفعلي المدفوع (ج.م)' : 'Actual Paid Price',
                border: const OutlineInputBorder(),
              ),
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
              final paidMinor = MoneyFormatter.parseToMinor(priceCtrl.text);
              final db = ref.read(databaseProvider);
              final now = DateTime.now();
              final localDate = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

              // 1. Create transaction
              final txId = await db.insertTransaction(
                TransactionsCompanion.insert(
                  kind: 'expense',
                  amountMinor: paidMinor,
                  categoryId: selectedCatId,
                  nature: const drift.Value('side'),
                  occurredAt: now.millisecondsSinceEpoch,
                  localDate: localDate,
                  note: drift.Value('شراء من قائمة المشتريات: ${item.name}'),
                  wishlistItemId: drift.Value(item.id),
                  createdAt: now.millisecondsSinceEpoch,
                  updatedAt: now.millisecondsSinceEpoch,
                ),
              );

              // 2. Mark wishlist item bought
              await db.markWishlistItemBought(item.id, paidMinor, txId);

              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: Text(isArabic ? 'تأكيد وحفظ كمصروف' : 'Confirm & Save Expense'),
          ),
        ],
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

    // Calculate 3-month average savings
    final now = DateTime.now();
    final threeMonthsAgo = DateTime(now.year, now.month - 3, 1);
    final threeMonthsAgoStr = "${threeMonthsAgo.year}-${threeMonthsAgo.month.toString().padLeft(2, '0')}-01";
    final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    return FutureBuilder<List<Transaction>>(
      future: db.getTransactionsForRange(threeMonthsAgoStr, todayStr),
      builder: (context, txSnap) {
        final txs = txSnap.data ?? [];
        final totals = _service.calculateTotals(txs);
        final avgMonthlySavings = totals.savedMinor > 0 ? (totals.savedMinor ~/ 3) : 0;

        return StreamBuilder<List<WishlistItem>>(
          stream: db.watchWishlistItems(),
          builder: (context, snapshot) {
            final items = snapshot.data ?? [];
            final estimate = _service.calculateWishlistEstimate(items, avgMonthlySavings);

            final totalFormatted = MoneyFormatter.formatWithCurrency(
              estimate.totalWantedPlannedMinor,
              currency: isArabic ? 'ج.م' : 'EGP',
              masked: isMasked,
              format: numeralsFormat,
            );

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              children: [
                // Header Summary Card
                Card(
                  elevation: 0,
                  color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: theme.colorScheme.secondary,
                              child: const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isArabic ? 'إجمالي المشتريات المخططة' : 'Total Planned Wishlist',
                                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    totalFormatted,
                                    style: theme.textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (estimate.estimatedMonths != null && estimate.estimatedMonths! > 0) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.timer_outlined, size: 16, color: theme.colorScheme.secondary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    isArabic
                                        ? '≈ ${estimate.estimatedMonths!.toStringAsFixed(1)} شهور من متوسط ادخارك (آخر 3 شهور)'
                                        : '≈ ${estimate.estimatedMonths!.toStringAsFixed(1)} months of your avg savings',
                                    style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isArabic ? 'قائمة الأمنيات والمشتريات' : 'Wishlist Items',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => _showAddEditWishlistSheet(),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: Text(isArabic ? 'إضافة سلعة' : 'Add Item'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40.0),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.card_giftcard_rounded, size: 60, color: theme.colorScheme.outlineVariant),
                          const SizedBox(height: 12),
                          Text(
                            isArabic ? 'قائمة المشتريات فارغة حالياً' : 'Wishlist is empty',
                            style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.outline),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...items.map((item) {
                    final isBought = item.status == 'bought';
                    final itemPriceFormatted = MoneyFormatter.formatWithCurrency(
                      isBought && item.boughtPriceMinor != null ? item.boughtPriceMinor! : item.estimatedPriceMinor,
                      currency: isArabic ? 'ج.م' : 'EGP',
                      masked: isMasked,
                      format: numeralsFormat,
                    );

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isBought
                              ? Colors.green.withValues(alpha: 0.3)
                              : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.name,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      decoration: isBought ? TextDecoration.lineThrough : null,
                                    ),
                                  ),
                                ),
                                Text(
                                  itemPriceFormatted,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: isBought ? Colors.green : theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (isBought
                                            ? Colors.green
                                            : item.priority == 'high'
                                                ? Colors.red
                                                : Colors.blue)
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isBought
                                        ? (isArabic ? 'تم الشراء' : 'Bought')
                                        : item.priority == 'high'
                                            ? (isArabic ? 'أولوية عالية' : 'High Priority')
                                            : (isArabic ? 'أولوية عادية' : 'Normal Priority'),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isBought
                                          ? Colors.green
                                          : item.priority == 'high'
                                              ? Colors.red
                                              : Colors.blue,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                if (!isBought) ...[
                                  FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      backgroundColor: Colors.green,
                                    ),
                                    onPressed: () => _markAsBought(context, item),
                                    icon: const Icon(Icons.check_rounded, size: 16),
                                    label: Text(isArabic ? 'اشتريتها' : 'I bought it'),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 20),
                                  onPressed: () => _showAddEditWishlistSheet(item),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red),
                                  onPressed: () async {
                                    await db.softDeleteWishlistItem(item.id);
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 80),
              ],
            );
          },
        );
      },
    );
  }
}
