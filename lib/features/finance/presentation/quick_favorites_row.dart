import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;

import '../../../core/db/app_database.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/money_formatter.dart';

class QuickFavoritesRow extends ConsumerWidget {
  const QuickFavoritesRow({super.key});

  void _recordQuickExpense(
    BuildContext context,
    WidgetRef ref,
    QuickExpense fav,
    Map<int, FinanceCategory> catMap,
  ) async {
    final db = ref.read(databaseProvider);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final numeralsFormat = ref.read(numeralsProvider);
    final now = DateTime.now();
    final localDate = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    final cat = catMap[fav.categoryId];
    final nature = fav.nature.isNotEmpty ? fav.nature : (cat?.nature ?? 'side');

    final txId = await db.insertTransaction(
      TransactionsCompanion.insert(
        kind: 'expense',
        amountMinor: fav.defaultAmountMinor,
        categoryId: fav.categoryId,
        nature: drift.Value(nature),
        occurredAt: now.millisecondsSinceEpoch,
        localDate: localDate,
        paymentMethod: const drift.Value('cash'),
        createdAt: now.millisecondsSinceEpoch,
        updatedAt: now.millisecondsSinceEpoch,
      ),
    );

    if (!context.mounted) return;

    final amountStr = MoneyFormatter.formatWithCurrency(
      fav.defaultAmountMinor,
      currency: isArabic ? 'ج.م' : 'EGP',
      format: numeralsFormat,
    );

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isArabic ? 'تم تسجيل ${fav.label}: $amountStr' : 'Recorded ${fav.label}: $amountStr',
        ),
        action: SnackBarAction(
          label: isArabic ? 'تراجع' : 'Undo',
          onPressed: () async {
            await db.softDeleteTransaction(txId);
          },
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showAddEditFavoriteDialog(BuildContext context, WidgetRef ref, [QuickExpense? existing]) {
    final db = ref.read(databaseProvider);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final labelCtrl = TextEditingController(text: existing?.label ?? '');
    final amountCtrl = TextEditingController(
      text: existing != null ? (existing.defaultAmountMinor / 100).toString() : '',
    );
    int? selectedCatId = existing?.categoryId;
    String selectedNature = existing?.nature ?? 'side';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
            existing == null
                ? (isArabic ? 'إضافة مصروف مفضل سريع' : 'Add Quick Favorite')
                : (isArabic ? 'تعديل المصروف المفضل' : 'Edit Quick Favorite'),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: labelCtrl,
                  decoration: InputDecoration(
                    labelText: isArabic ? 'الاسم (مثال: شاي، قهوة، بنزين)' : 'Label',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: isArabic ? 'المبلغ الافتراضي (ج.م)' : 'Default Amount',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<FinanceCategory>>(
                  future: db.getAllFinanceCategories(kind: 'expense'),
                  builder: (context, snapshot) {
                    final cats = snapshot.data ?? [];
                    if (selectedCatId == null && cats.isNotEmpty) {
                      selectedCatId = cats.first.id;
                    }
                    return DropdownButtonFormField<int>(
                      value: selectedCatId,
                      decoration: InputDecoration(
                        labelText: isArabic ? 'التصنيف' : 'Category',
                        border: const OutlineInputBorder(),
                      ),
                      items: cats.map((c) {
                        return DropdownMenuItem<int>(
                          value: c.id,
                          child: Text(isArabic ? c.nameAr : (c.nameEn ?? c.nameAr)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedCatId = val);
                        }
                      },
                    );
                  },
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(value: 'essential', label: Text(isArabic ? 'ضروري' : 'Essential')),
                    ButtonSegment(value: 'side', label: Text(isArabic ? 'كمالي' : 'Side')),
                  ],
                  selected: {selectedNature},
                  onSelectionChanged: (set) {
                    setDialogState(() => selectedNature = set.first);
                  },
                ),
              ],
            ),
          ),
          actions: [
            if (existing != null)
              TextButton(
                onPressed: () async {
                  await db.deleteQuickExpense(existing.id);
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
                child: Text(isArabic ? 'حذف' : 'Delete', style: const TextStyle(color: Colors.red)),
              ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(isArabic ? 'إلغاء' : 'Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final label = labelCtrl.text.trim();
                final amountMinor = MoneyFormatter.parseToMinor(amountCtrl.text);
                if (label.isEmpty || amountMinor <= 0 || selectedCatId == null) return;

                final now = DateTime.now().millisecondsSinceEpoch;
                if (existing != null) {
                  await db.updateQuickExpense(
                    QuickExpensesCompanion(
                      id: drift.Value(existing.id),
                      label: drift.Value(label),
                      categoryId: drift.Value(selectedCatId!),
                      defaultAmountMinor: drift.Value(amountMinor),
                      nature: drift.Value(selectedNature),
                      updatedAt: drift.Value(now),
                    ),
                  );
                } else {
                  await db.insertQuickExpense(
                    QuickExpensesCompanion.insert(
                      label: label,
                      categoryId: selectedCatId!,
                      defaultAmountMinor: amountMinor,
                      nature: drift.Value(selectedNature),
                      sortOrder: const drift.Value(99),
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
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final numeralsFormat = ref.watch(numeralsProvider);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final theme = Theme.of(context);

    return StreamBuilder<List<FinanceCategory>>(
      stream: db.watchActiveFinanceCategories(kind: 'expense'),
      builder: (context, catSnap) {
        final catMap = <int, FinanceCategory>{
          for (final c in (catSnap.data ?? <FinanceCategory>[])) c.id: c
        };

        return StreamBuilder<List<QuickExpense>>(
          stream: db.watchQuickExpenses(),
          builder: (context, snapshot) {
            final favorites = snapshot.data ?? [];

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  ...favorites.map((fav) {
                    final amountFormatted = MoneyFormatter.formatWithCurrency(
                      fav.defaultAmountMinor,
                      currency: isArabic ? 'ج.م' : 'EGP',
                      format: numeralsFormat,
                      showDecimals: false,
                    );

                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ActionChip(
                        elevation: 1,
                        avatar: CircleAvatar(
                          radius: 12,
                          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                          child: Icon(
                            Icons.bolt_rounded,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        label: Text(
                          '${fav.label} • $amountFormatted',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        onPressed: () => _recordQuickExpense(context, ref, fav, catMap),
                        tooltip: isArabic ? 'نقرة للتسجيل الفوري، ضغط مطول للتعديل' : 'Tap to record, long press to edit',
                      ),
                    );
                  }),
                  IconButton.filledTonal(
                    iconSize: 18,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.add_rounded),
                    tooltip: isArabic ? 'إضافة مفضلة سريعة' : 'Add favorite',
                    onPressed: () => _showAddEditFavoriteDialog(context, ref),
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
