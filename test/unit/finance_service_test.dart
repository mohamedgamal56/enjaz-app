import 'package:flutter_test/flutter_test.dart';
import 'package:enjaz/core/db/app_database.dart';
import 'package:enjaz/features/finance/domain/finance_service.dart';

void main() {
  const service = FinanceService();

  group('Round 5 Acceptance Tests - FinanceService', () {
    test('1. Monthly summary, tea expense, and savings rate match manual count', () {
      final txs = [
        Transaction(
          id: 1,
          kind: 'income',
          amountMinor: 1000000, // 10,000 EGP
          categoryId: 16,
          nature: 'none',
          occurredAt: 1730000000000,
          localDate: '2026-11-01',
          createdAt: 1730000000000,
          updatedAt: 1730000000000,
        ),
        Transaction(
          id: 2,
          kind: 'expense',
          amountMinor: 1000, // 10 EGP (Tea)
          categoryId: 1, // Tea & Coffee
          nature: 'side',
          occurredAt: 1730001000000,
          localDate: '2026-11-01',
          createdAt: 1730001000000,
          updatedAt: 1730001000000,
        ),
        Transaction(
          id: 3,
          kind: 'expense',
          amountMinor: 250000, // 2,500 EGP (Rent)
          categoryId: 6,
          nature: 'essential',
          occurredAt: 1730002000000,
          localDate: '2026-11-02',
          createdAt: 1730002000000,
          updatedAt: 1730002000000,
        ),
      ];

      final totals = service.calculateTotals(txs);
      expect(totals.incomeMinor, 1000000);
      expect(totals.expenseMinor, 251000);
      expect(totals.savedMinor, 749000);
      // Savings rate = 749000 / 1000000 = 0.749 (74.9%)
      expect(totals.savingsRate, closeTo(0.749, 0.001));
    });

    test('2. Essential vs side shares and top categories on a dataset of 100 transactions', () {
      final txs = <Transaction>[];
      int expectedEssential = 0;
      int expectedSide = 0;

      // 60 essential transactions of 1000 minor = 60,000 minor
      for (int i = 0; i < 60; i++) {
        final amount = 1000 + (i * 10);
        expectedEssential += amount;
        txs.add(
          Transaction(
            id: i + 1,
            kind: 'expense',
            amountMinor: amount,
            categoryId: (i % 5) + 3, // essential categories
            nature: 'essential',
            occurredAt: 1730000000000 + i * 1000,
            localDate: '2026-11-03',
            createdAt: 1730000000000,
            updatedAt: 1730000000000,
          ),
        );
      }

      // 40 side transactions
      for (int i = 0; i < 40; i++) {
        final amount = 500 + (i * 20);
        expectedSide += amount;
        txs.add(
          Transaction(
            id: i + 61,
            kind: 'expense',
            amountMinor: amount,
            categoryId: (i % 2) + 1, // side categories (1: tea, 2: dining)
            nature: 'side',
            occurredAt: 1730000000000 + (i + 60) * 1000,
            localDate: '2026-11-04',
            createdAt: 1730000000000,
            updatedAt: 1730000000000,
          ),
        );
      }

      expect(txs.length, 100);

      final share = service.calculateNatureShare(txs);
      expect(share.essentialMinor, expectedEssential);
      expect(share.sideMinor, expectedSide);

      final total = expectedEssential + expectedSide;
      final expectedEssentialPct = (expectedEssential / total) * 100;
      final expectedSidePct = (expectedSide / total) * 100;

      expect(share.essentialPercent, closeTo(expectedEssentialPct, 0.01));
      expect(share.sidePercent, closeTo(expectedSidePct, 0.01));

      // Category spendings
      final catMap = {
        1: const FinanceCategory(id: 1, nameAr: 'شاي وقهوة', kind: 'expense', nature: 'side', color: 0xFF0000, isDefault: true, archived: false, sortOrder: 1, createdAt: 0, updatedAt: 0),
        2: const FinanceCategory(id: 2, nameAr: 'أكل من بره', kind: 'expense', nature: 'side', color: 0xFF0000, isDefault: true, archived: false, sortOrder: 2, createdAt: 0, updatedAt: 0),
        3: const FinanceCategory(id: 3, nameAr: 'بقالة', kind: 'expense', nature: 'essential', color: 0xFF0000, isDefault: true, archived: false, sortOrder: 3, createdAt: 0, updatedAt: 0),
      };

      final topCats = service.getTopCategories(txs, catMap, limit: 3);
      expect(topCats.length, 3);
      expect(topCats.first.amountMinor, greaterThan(topCats.last.amountMinor));
    });

    test('3. Marking wishlist item as bought lowers wishlist total and creates estimate', () {
      final items = [
        const WishlistItem(
          id: 1,
          name: 'شاشة جديدة',
          estimatedPriceMinor: 500000, // 5,000 EGP
          priority: 'high',
          status: 'wanted',
          createdAt: 0,
          updatedAt: 0,
        ),
        const WishlistItem(
          id: 2,
          name: 'ماوس لاسلكي',
          estimatedPriceMinor: 100000, // 1,000 EGP
          priority: 'normal',
          status: 'planned',
          createdAt: 0,
          updatedAt: 0,
        ),
        const WishlistItem(
          id: 3,
          name: 'كتاب',
          estimatedPriceMinor: 20000, // 200 EGP
          priority: 'low',
          status: 'bought', // already bought
          createdAt: 0,
          updatedAt: 0,
        ),
      ];

      // Average monthly savings: 2,000 EGP = 200,000 minor
      final estimate = service.calculateWishlistEstimate(items, 200000);
      expect(estimate.totalWantedPlannedMinor, 600000); // 5000 + 1000 EGP
      // 600,000 / 200,000 = 3.0 months
      expect(estimate.estimatedMonths, closeTo(3.0, 0.01));
    });

    test('4. An obligation becomes late the day after its due date and on-time rate is correct', () {
      final instances = [
        const ObligationInstance(
          id: 1,
          obligationId: 10,
          dueDate: '2026-11-04',
          amountMinor: 50000,
          status: 'pending', // Late on 2026-11-05
          createdAt: 0,
          updatedAt: 0,
        ),
        const ObligationInstance(
          id: 2,
          obligationId: 10,
          dueDate: '2026-11-05',
          amountMinor: 50000,
          status: 'paid',
          paidAt: 1730790000000, // Paid on time
          createdAt: 0,
          updatedAt: 0,
        ),
        const ObligationInstance(
          id: 3,
          obligationId: 10,
          dueDate: '2026-11-10',
          amountMinor: 50000,
          status: 'pending', // Due soon
          createdAt: 0,
          updatedAt: 0,
        ),
      ];

      final metrics = service.calculateObligationsMetrics(instances, '2026-11-05');
      expect(metrics.lateCount, 1);
      expect(metrics.lateAmountMinor, 50000);
      expect(metrics.dueSoonCount, 1);
      // Total due or paid: 1 late + 1 paid = 2. On time: 1. Rate = 50%
      expect(metrics.onTimeRate, 50.0);
    });

    test('5. Small recurring spending detection (>= 10 entries with small average)', () {
      final txs = <Transaction>[];
      // 12 coffee transactions of 2500 minor = 25 EGP
      for (int i = 0; i < 12; i++) {
        txs.add(
          Transaction(
            id: i + 1,
            kind: 'expense',
            amountMinor: 2500,
            categoryId: 1,
            nature: 'side',
            occurredAt: 1730000000000,
            localDate: '2026-11-05',
            createdAt: 0,
            updatedAt: 0,
          ),
        );
      }

      // 3 large expenses of 50,000 minor in another category
      for (int i = 0; i < 3; i++) {
        txs.add(
          Transaction(
            id: i + 20,
            kind: 'expense',
            amountMinor: 50000,
            categoryId: 5,
            nature: 'essential',
            occurredAt: 1730000000000,
            localDate: '2026-11-05',
            createdAt: 0,
            updatedAt: 0,
          ),
        );
      }

      final catMap = {
        1: const FinanceCategory(id: 1, nameAr: 'شاي وقهوة', kind: 'expense', nature: 'side', color: 0, isDefault: true, archived: false, sortOrder: 1, createdAt: 0, updatedAt: 0),
        5: const FinanceCategory(id: 5, nameAr: 'فواتير', kind: 'expense', nature: 'essential', color: 0, isDefault: true, archived: false, sortOrder: 5, createdAt: 0, updatedAt: 0),
      };

      final smallRecurring = service.findSmallRecurringSpending(txs, catMap, minCount: 10, maxAvgMinor: 3000);
      expect(smallRecurring.length, 1);
      expect(smallRecurring.first.categoryId, 1);
      expect(smallRecurring.first.count, 12);
      expect(smallRecurring.first.totalAmountMinor, 30000); // 12 * 2500
      expect(smallRecurring.first.averageAmountMinor, 2500);
    });
  });
}
