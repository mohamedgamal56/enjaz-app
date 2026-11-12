import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/finance_service.dart';
import 'add_transaction_sheet.dart';
import 'finance_analysis_tab.dart';
import 'obligations_tab.dart';
import 'transactions_tab.dart';
import 'wishlist_tab.dart';

class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key});

  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late DateTime _selectedMonth;
  static const _service = FinanceService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _navigateMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + delta, 1);
    });
  }

  String get _currentYearMonth =>
      "${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}";

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final numeralsFormat = ref.watch(numeralsProvider);
    final isMasked = ref.watch(financeMaskedProvider);
    final db = ref.watch(databaseProvider);

    final monthLabel = AppFormatter.formatDate(
      _selectedMonth,
      locale: Localizations.localeOf(context).languageCode,
      format: numeralsFormat,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(isArabic ? 'المال والميزانية' : 'Finance'),
        actions: [
          // Eye Masking Icon Button
          IconButton(
            icon: Icon(
              isMasked ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            ),
            tooltip: isArabic
                ? (isMasked ? 'إظهار المبالغ' : 'إخفاء المبالغ')
                : (isMasked ? 'Show Amounts' : 'Hide Amounts'),
            onPressed: () {
              ref.read(financeMaskedProvider.notifier).toggle();
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(108),
          child: Column(
            children: [
              // Month Navigation Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      onPressed: () => _navigateMonth(-1),
                    ),
                    Text(
                      monthLabel,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      onPressed: () => _navigateMonth(1),
                    ),
                  ],
                ),
              ),

              // Segmented TabBar
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.center,
                tabs: [
                  Tab(text: isArabic ? 'المعاملات' : 'Transactions'),
                  Tab(text: isArabic ? 'المشتريات' : 'Wishlist'),
                  Tab(text: isArabic ? 'الالتزامات' : 'Obligations'),
                  Tab(text: isArabic ? 'التحليل' : 'Analysis'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // Month Summary Strip Card
          StreamBuilder<List<Transaction>>(
            stream: db.watchTransactionsForMonth(_currentYearMonth),
            builder: (context, snapshot) {
              final txs = snapshot.data ?? [];
              final totals = _service.calculateTotals(txs);

              final incomeFormatted = MoneyFormatter.formatWithCurrency(
                totals.incomeMinor,
                currency: isArabic ? 'ج.م' : 'EGP',
                masked: isMasked,
                format: numeralsFormat,
                showDecimals: false,
              );

              final expenseFormatted = MoneyFormatter.formatWithCurrency(
                totals.expenseMinor,
                currency: isArabic ? 'ج.م' : 'EGP',
                masked: isMasked,
                format: numeralsFormat,
                showDecimals: false,
              );

              final savedFormatted = MoneyFormatter.formatWithCurrency(
                totals.savedMinor,
                currency: isArabic ? 'ج.م' : 'EGP',
                masked: isMasked,
                format: numeralsFormat,
                showDecimals: false,
              );

              return AppCard(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _summaryPill(
                      context,
                      label: isArabic ? 'دخل' : 'Income',
                      value: incomeFormatted,
                      color: Colors.green,
                    ),
                    _summaryPill(
                      context,
                      label: isArabic ? 'مصروف' : 'Expenses',
                      value: expenseFormatted,
                      color: Colors.red,
                    ),
                    _summaryPill(
                      context,
                      label: isArabic ? 'المتبقي' : 'Saved',
                      value: savedFormatted,
                      color: totals.savedMinor >= 0 ? Colors.teal : Colors.orange,
                    ),
                  ],
                ),
              );
            },
          ),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                TransactionsTab(currentYearMonth: _currentYearMonth),
                const WishlistTab(),
                const ObligationsTab(),
                FinanceAnalysisTab(currentYearMonth: _currentYearMonth),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) => AddTransactionSheet(
              initialDate: "${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}-01",
            ),
          );
        },
        icon: const Icon(Icons.add_rounded),
        label: Text(isArabic ? 'إضافة معاملة' : 'Add Transaction'),
      ),
    );
  }

  Widget _summaryPill(BuildContext context, {required String label, required String value, required Color color}) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: theme.textTheme.bodySmall?.copyWith(fontSize: 11, color: theme.colorScheme.outline)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
      ],
    );
  }
}
