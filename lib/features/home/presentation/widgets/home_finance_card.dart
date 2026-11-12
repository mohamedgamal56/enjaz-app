import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/card_header.dart';
import '../../../finance/domain/finance_masked_provider.dart';
import '../../../finance/domain/money_formatter.dart';
import '../../../finance/presentation/finance_screen.dart';
import '../../domain/home_summary_data.dart';

/// HomeFinanceCard (UI.md Section 4.2 & Section 9)
/// Displays today's spending and remaining monthly budget (or month total).
/// Masked via financeMaskedProvider.
class HomeFinanceCard extends ConsumerWidget {
  final HomeSummaryData data;

  const HomeFinanceCard({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final numerals = ref.watch(numeralsProvider);
    final isMasked = ref.watch(financeMaskedProvider);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final currency = isArabic ? 'ج.م' : 'EGP';

    void openFinanceScreen() {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const FinanceScreen()),
      );
    }

    final todaySpendingStr = MoneyFormatter.formatWithCurrency(
      data.todaySpendingMinor,
      currency: currency,
      masked: isMasked,
      format: numerals,
      showDecimals: false,
    );

    final remainingBudgetStr = MoneyFormatter.formatWithCurrency(
      data.remainingMonthlyBudgetMinor,
      currency: currency,
      masked: isMasked,
      format: numerals,
      showDecimals: false,
    );

    final monthSpendingStr = MoneyFormatter.formatWithCurrency(
      data.monthSpendingMinor,
      currency: currency,
      masked: isMasked,
      format: numerals,
      showDecimals: false,
    );

    return AppCard(
      onTap: openFinanceScreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          CardHeader(
            title: isArabic ? 'المال' : 'Finance',
            leading: Icon(Icons.account_balance_wallet_rounded, size: 18.0, color: colors.accent),
            trailing: InkWell(
              borderRadius: BorderRadius.circular(12.0),
              onTap: () => ref.read(financeMaskedProvider.notifier).toggle(),
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Icon(
                  isMasked ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  size: 16.0,
                  color: colors.textSecondary,
                ),
              ),
            ),
          ),

          // Spending today in large type
          Text(
            todaySpendingStr,
            style: AppTypography.keyValue(context, color: colors.text),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2.0),
          Text(
            isArabic ? 'مصروف اليوم' : 'Today spending',
            style: AppTypography.caption(context, color: colors.textSecondary).copyWith(
              fontSize: 11.0,
            ),
          ),
          const SizedBox(height: 8.0),

          // Monthly budget or month spending
          Text(
            data.hasMonthlyBudget
                ? (isArabic ? 'متبقي الميزانية: $remainingBudgetStr' : 'Budget left: $remainingBudgetStr')
                : (isArabic ? 'مصروف الشهر ده: $monthSpendingStr' : 'Month spent: $monthSpendingStr'),
            style: AppTypography.caption(context, color: colors.textSecondary).copyWith(
              fontSize: 11.0,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
