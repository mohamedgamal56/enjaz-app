import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/widgets/widgets.dart';
import 'add_transaction_sheet.dart';
import 'finance_icon_helper.dart';
import 'quick_favorites_row.dart';

class TransactionsTab extends ConsumerStatefulWidget {
  final String currentYearMonth; // "YYYY-MM"

  const TransactionsTab({super.key, required this.currentYearMonth});

  @override
  ConsumerState<TransactionsTab> createState() => _TransactionsTabState();
}

class _TransactionsTabState extends ConsumerState<TransactionsTab> {
  String _filterKind = 'all'; // all | expense | income
  String _filterNature = 'all'; // all | essential | side

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final numeralsFormat = ref.watch(numeralsProvider);
    final isMasked = ref.watch(financeMaskedProvider);
    final db = ref.watch(databaseProvider);

    return StreamBuilder<List<FinanceCategory>>(
      stream: db.watchActiveFinanceCategories(),
      builder: (context, catSnap) {
        final catMap = {for (final c in (catSnap.data ?? [])) c.id: c};

        return StreamBuilder<List<Transaction>>(
          stream: db.watchTransactionsForMonth(widget.currentYearMonth),
          builder: (context, snapshot) {
            final allTxs = snapshot.data ?? [];

            // Apply filters
            final filteredTxs = allTxs.where((tx) {
              if (_filterKind != 'all' && tx.kind != _filterKind) return false;
              if (_filterNature != 'all' && tx.nature != _filterNature) return false;
              return true;
            }).toList();

            // Group by localDate
            final grouped = <String, List<Transaction>>{};
            for (final tx in filteredTxs) {
              grouped.putIfAbsent(tx.localDate, () => []).add(tx);
            }
            final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

            return CustomScrollView(
              slivers: [
                // Quick Favorites row
                const SliverToBoxAdapter(child: QuickFavoritesRow()),

                // Filter row
                SliverToBoxAdapter(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                    child: Row(
                      children: [
                        FilterChip(
                          selected: _filterKind == 'all' && _filterNature == 'all',
                          label: Text(isArabic ? 'الكل' : 'All'),
                          onSelected: (_) {
                            setState(() {
                              _filterKind = 'all';
                              _filterNature = 'all';
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          selected: _filterKind == 'expense',
                          avatar: const Icon(Icons.arrow_downward_rounded, size: 14, color: Colors.red),
                          label: Text(isArabic ? 'مصروفات' : 'Expenses'),
                          onSelected: (val) {
                            setState(() => _filterKind = val ? 'expense' : 'all');
                          },
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          selected: _filterKind == 'income',
                          avatar: const Icon(Icons.arrow_upward_rounded, size: 14, color: Colors.green),
                          label: Text(isArabic ? 'دخل' : 'Income'),
                          onSelected: (val) {
                            setState(() => _filterKind = val ? 'income' : 'all');
                          },
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          selected: _filterNature == 'essential',
                          label: Text(isArabic ? 'ضروري' : 'Essential'),
                          onSelected: (val) {
                            setState(() => _filterNature = val ? 'essential' : 'all');
                          },
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          selected: _filterNature == 'side',
                          label: Text(isArabic ? 'كمالي' : 'Side'),
                          onSelected: (val) {
                            setState(() => _filterNature = val ? 'side' : 'all');
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                if (filteredTxs.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: isArabic ? 'لا توجد معاملات في هذا الشهر' : 'No transactions this month',
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, dateIndex) {
                          final dateStr = sortedDates[dateIndex];
                          final dayTxs = grouped[dateStr] ?? [];

                          DateTime? dt;
                          try {
                            dt = DateTime.parse(dateStr);
                          } catch (_) {}

                          final headerDateStr = dt != null
                              ? AppFormatter.formatDate(
                                  dt,
                                  locale: Localizations.localeOf(context).languageCode,
                                  format: numeralsFormat,
                                )
                              : dateStr;

                          int dayTotalExpense = 0;
                          for (final tx in dayTxs) {
                            if (tx.kind == 'expense') dayTotalExpense += tx.amountMinor;
                          }

                          final dayTotalFormatted = MoneyFormatter.formatWithCurrency(
                            dayTotalExpense,
                            currency: isArabic ? 'ج.م' : 'EGP',
                            masked: isMasked,
                            format: numeralsFormat,
                          );

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 12.0, bottom: 6.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      headerDateStr,
                                      style: theme.textTheme.labelLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                    if (dayTotalExpense > 0)
                                      Text(
                                        dayTotalFormatted,
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.outline,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              ...dayTxs.map((tx) {
                                final isExpense = tx.kind == 'expense';
                                final cat = catMap[tx.categoryId];
                                final catName = isArabic ? (cat?.nameAr ?? 'أخرى') : (cat?.nameEn ?? cat?.nameAr ?? 'Other');
                                final catColor = cat != null ? Color(cat.color) : Colors.grey;
                                final catIcon = FinanceIconHelper.getIcon(cat?.icon);

                                final amountFormatted = MoneyFormatter.formatWithCurrency(
                                  tx.amountMinor,
                                  currency: isArabic ? 'ج.م' : 'EGP',
                                  masked: isMasked,
                                  format: numeralsFormat,
                                );

                                return Dismissible(
                                  key: ValueKey('tx_${tx.id}'),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    alignment: Alignment.centerLeft,
                                    padding: const EdgeInsets.only(left: 20),
                                    color: Colors.red,
                                    child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                                  ),
                                  onDismissed: (_) async {
                                    await db.softDeleteTransaction(tx.id);
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).clearSnackBars();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(isArabic ? 'تم حذف المعاملة' : 'Transaction deleted'),
                                        action: SnackBarAction(
                                          label: isArabic ? 'تراجع' : 'Undo',
                                          onPressed: () => db.restoreTransaction(tx.id),
                                        ),
                                      ),
                                    );
                                  },
                                  child: AppCard(
                                    margin: const EdgeInsets.symmetric(vertical: 4.0),
                                    padding: EdgeInsets.zero,
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 2.0),
                                      onTap: () {
                                        showModalBottomSheet(
                                          context: context,
                                          isScrollControlled: true,
                                          builder: (_) => AddTransactionSheet(existingTransaction: tx),
                                        );
                                      },
                                      leading: CircleAvatar(
                                        backgroundColor: catColor.withValues(alpha: 0.15),
                                        child: Icon(catIcon, color: catColor, size: 20),
                                      ),
                                      title: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              catName,
                                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Text(
                                            isExpense ? '-$amountFormatted' : '+$amountFormatted',
                                            style: theme.textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: isExpense ? Colors.red : Colors.green,
                                            ),
                                          ),
                                        ],
                                      ),
                                      subtitle: Row(
                                        children: [
                                          if (isExpense) ...[
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: (tx.nature == 'essential' ? Colors.blue : Colors.orange).withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                tx.nature == 'essential' ? (isArabic ? 'ضروري' : 'Essential') : (isArabic ? 'كمالي' : 'Side'),
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: tx.nature == 'essential' ? Colors.blue : Colors.orange,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                          ],
                                          if (tx.note != null && tx.note!.isNotEmpty)
                                            Expanded(
                                              child: Text(
                                                tx.note!,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          );
                        },
                        childCount: sortedDates.length,
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            );
          },
        );
      },
    );
  }
}
