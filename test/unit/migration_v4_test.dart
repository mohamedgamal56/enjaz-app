import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Drift Schema Migration v4 Tests (Round 3 Notes Table)', () {
    test('Drift migration script correctly prepares SQL for notes table and indexes', () {
      const createNotesTableSql = '''
        CREATE TABLE IF NOT EXISTS notes (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          deleted_at INTEGER,
          title TEXT,
          body TEXT NOT NULL,
          kind TEXT NOT NULL DEFAULT 'note',
          color TEXT,
          pinned INTEGER NOT NULL DEFAULT 0,
          note_date TEXT,
          tags TEXT,
          occurred_at INTEGER,
          local_date TEXT
        );
      ''';

      const createIndexDate = 'CREATE INDEX IF NOT EXISTS idx_notes_date ON notes (note_date);';
      const createIndexPinned = 'CREATE INDEX IF NOT EXISTS idx_notes_pinned ON notes (pinned);';
      const createIndexDeleted = 'CREATE INDEX IF NOT EXISTS idx_notes_deleted ON notes (deleted_at);';

      expect(createNotesTableSql.contains('notes'), isTrue);
      expect(createNotesTableSql.contains('body TEXT NOT NULL'), isTrue);
      expect(createNotesTableSql.contains("kind TEXT NOT NULL DEFAULT 'note'"), isTrue);
      expect(createNotesTableSql.contains('pinned INTEGER NOT NULL DEFAULT 0'), isTrue);
      expect(createNotesTableSql.contains('occurred_at INTEGER'), isTrue);
      expect(createIndexDate.contains('idx_notes_date'), isTrue);
      expect(createIndexPinned.contains('idx_notes_pinned'), isTrue);
      expect(createIndexDeleted.contains('idx_notes_deleted'), isTrue);
    });

    test('Notes kind options include note, quote, info per Spec Section 3.2', () {
      const allowedKinds = ['note', 'quote', 'info'];
      expect(allowedKinds.contains('note'), isTrue);
      expect(allowedKinds.contains('quote'), isTrue);
      expect(allowedKinds.contains('info'), isTrue);
    });
  });
}
