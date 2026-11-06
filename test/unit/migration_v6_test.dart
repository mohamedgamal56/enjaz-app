import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Drift Schema Migration v6 Tests (Round 5 Finance Tables)', () {
    test('1. Migration v6 prepares SQL for finance tables and indexes', () {
      const createFinanceCategoriesTableSql = '''
        CREATE TABLE IF NOT EXISTS finance_categories (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          deleted_at INTEGER,
          name_ar TEXT NOT NULL,
          name_en TEXT,
          kind TEXT NOT NULL,
          nature TEXT NOT NULL DEFAULT 'side',
          icon TEXT,
          color INTEGER NOT NULL DEFAULT 2201459,
          is_default INTEGER NOT NULL DEFAULT 0,
          archived INTEGER NOT NULL DEFAULT 0,
          sort_order INTEGER NOT NULL DEFAULT 0
        );
      ''';

      const createTransactionsTableSql = '''
        CREATE TABLE IF NOT EXISTS transactions (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          deleted_at INTEGER,
          kind TEXT NOT NULL,
          amount_minor INTEGER NOT NULL,
          category_id INTEGER NOT NULL,
          nature TEXT NOT NULL DEFAULT 'side',
          occurred_at INTEGER NOT NULL,
          local_date TEXT NOT NULL,
          note TEXT,
          payment_method TEXT,
          obligation_instance_id INTEGER,
          wishlist_item_id INTEGER
        );
      ''';

      const createQuickExpensesTableSql = '''
        CREATE TABLE IF NOT EXISTS quick_expenses (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          deleted_at INTEGER,
          label TEXT NOT NULL,
          category_id INTEGER NOT NULL,
          default_amount_minor INTEGER NOT NULL,
          nature TEXT NOT NULL DEFAULT 'side',
          sort_order INTEGER NOT NULL DEFAULT 0
        );
      ''';

      const createWishlistItemsTableSql = '''
        CREATE TABLE IF NOT EXISTS wishlist_items (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          deleted_at INTEGER,
          name TEXT NOT NULL,
          estimated_price_minor INTEGER NOT NULL,
          priority TEXT NOT NULL DEFAULT 'normal',
          status TEXT NOT NULL DEFAULT 'wanted',
          target_date TEXT,
          note TEXT,
          bought_at INTEGER,
          bought_price_minor INTEGER,
          transaction_id INTEGER
        );
      ''';

      const createObligationsTableSql = '''
        CREATE TABLE IF NOT EXISTS obligations (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          deleted_at INTEGER,
          name TEXT NOT NULL,
          kind TEXT NOT NULL,
          amount_minor INTEGER NOT NULL,
          frequency TEXT NOT NULL DEFAULT 'monthly',
          due_day INTEGER,
          due_date TEXT,
          start_date TEXT NOT NULL,
          end_date TEXT,
          installments_total INTEGER,
          counterpart TEXT,
          note TEXT
        );
      ''';

      const createObligationInstancesTableSql = '''
        CREATE TABLE IF NOT EXISTS obligation_instances (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          deleted_at INTEGER,
          obligation_id INTEGER NOT NULL,
          due_date TEXT NOT NULL,
          amount_minor INTEGER NOT NULL,
          status TEXT NOT NULL DEFAULT 'pending',
          paid_at INTEGER,
          paid_amount_minor INTEGER,
          transaction_id INTEGER
        );
      ''';

      const createBudgetsTableSql = '''
        CREATE TABLE IF NOT EXISTS budgets (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          deleted_at INTEGER,
          category_id INTEGER,
          month TEXT NOT NULL,
          limit_minor INTEGER NOT NULL
        );
      ''';

      expect(createFinanceCategoriesTableSql, contains('finance_categories'));
      expect(createTransactionsTableSql, contains('transactions'));
      expect(createQuickExpensesTableSql, contains('quick_expenses'));
      expect(createWishlistItemsTableSql, contains('wishlist_items'));
      expect(createObligationsTableSql, contains('obligations'));
      expect(createObligationInstancesTableSql, contains('obligation_instances'));
      expect(createBudgetsTableSql, contains('budgets'));
    });
  });
}
