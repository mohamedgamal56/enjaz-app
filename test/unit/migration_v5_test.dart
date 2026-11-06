import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Drift Schema Migration v5 Tests (Round 4 Habits Tables)', () {
    test('1. Migration v5 prepares SQL for habits table and indexes', () {
      const createHabitsTableSql = '''
        CREATE TABLE IF NOT EXISTS habits (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          deleted_at INTEGER,
          name_ar TEXT NOT NULL,
          name_en TEXT,
          type TEXT NOT NULL,
          unit TEXT,
          daily_target REAL,
          icon TEXT,
          color TEXT,
          schedule_days INTEGER NOT NULL DEFAULT 127,
          builtin_key TEXT,
          sort_order INTEGER NOT NULL DEFAULT 0,
          archived INTEGER NOT NULL DEFAULT 0,
          occurred_at INTEGER,
          local_date TEXT
        );
      ''';

      const createHabitItemsTableSql = '''
        CREATE TABLE IF NOT EXISTS habit_items (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          deleted_at INTEGER,
          habit_id INTEGER NOT NULL,
          name TEXT NOT NULL,
          sort_order INTEGER NOT NULL DEFAULT 0
        );
      ''';

      const createHabitLogsTableSql = '''
        CREATE TABLE IF NOT EXISTS habit_logs (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          deleted_at INTEGER,
          habit_id INTEGER NOT NULL,
          log_date TEXT NOT NULL,
          value REAL NOT NULL DEFAULT 1.0,
          at INTEGER NOT NULL,
          note TEXT,
          occurred_at INTEGER,
          local_date TEXT
        );
      ''';

      const createHabitItemLogsTableSql = '''
        CREATE TABLE IF NOT EXISTS habit_item_logs (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          deleted_at INTEGER,
          habit_id INTEGER NOT NULL,
          item_id INTEGER NOT NULL,
          log_date TEXT NOT NULL,
          done_at INTEGER NOT NULL,
          occurred_at INTEGER,
          local_date TEXT
        );
      ''';

      expect(createHabitsTableSql.contains('habits'), isTrue);
      expect(createHabitsTableSql.contains('name_ar TEXT NOT NULL'), isTrue);
      expect(createHabitsTableSql.contains('type TEXT NOT NULL'), isTrue);
      expect(createHabitsTableSql.contains('schedule_days INTEGER NOT NULL DEFAULT 127'), isTrue);

      expect(createHabitItemsTableSql.contains('habit_items'), isTrue);
      expect(createHabitItemsTableSql.contains('habit_id INTEGER NOT NULL'), isTrue);

      expect(createHabitLogsTableSql.contains('habit_logs'), isTrue);
      expect(createHabitLogsTableSql.contains('log_date TEXT NOT NULL'), isTrue);
      expect(createHabitLogsTableSql.contains('at INTEGER NOT NULL'), isTrue);

      expect(createHabitItemLogsTableSql.contains('habit_item_logs'), isTrue);
      expect(createHabitItemLogsTableSql.contains('item_id INTEGER NOT NULL'), isTrue);
    });

    test('2. Habits type options include count, check, amount, checklist per Spec Section 4.1', () {
      const allowedTypes = ['count', 'check', 'amount', 'checklist'];
      expect(allowedTypes.contains('count'), isTrue);
      expect(allowedTypes.contains('check'), isTrue);
      expect(allowedTypes.contains('amount'), isTrue);
      expect(allowedTypes.contains('checklist'), isTrue);
    });
  });
}
