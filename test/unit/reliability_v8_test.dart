import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:enjaz/core/db/app_database.dart';
import 'package:enjaz/features/backup/domain/backup_service.dart';
import 'package:enjaz/features/assistant/answer_service.dart';
import 'package:enjaz/features/assistant/rule_based_intent_parser.dart';

Archive backup(Map<String, dynamic> data, {bool corrupt = false}) {
  final bytes = utf8.encode(jsonEncode(data));
  final archive = Archive()..addFile(ArchiveFile('data.json', bytes.length, bytes));
  final manifest = utf8.encode(jsonEncode({
    'schema_version': data['schema_version'], 'app_version': '1.2.0',
    'created_at': '2026-11-08', 'includes_voice': false, 'counts': {},
    'checksums': {'data.json': corrupt ? 'invalid' : sha256.convert(bytes).toString()},
  }));
  archive.addFile(ArchiveFile('manifest.json', manifest.length, manifest));
  return archive;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('complete current backup validates and preserves unrecognized phrases', () async {
    await db.into(db.unrecognizedPhrases).insert(UnrecognizedPhrasesCompanion.insert(phrase: 'test', at: 1, createdAt: 1, updatedAt: 1));
    final data = await db.exportAllData();
    expect(() => BackupService.validateArchive(backup(data)), returnsNormally);
    await db.importAllData(data);
    expect((await db.select(db.unrecognizedPhrases).get()).single.phrase, 'test');
  });

  test('rejects incomplete backup before it can wipe other tables', () {
    expect(() => BackupService.validateArchive(backup({'schema_version': 8, 'tasks': []})), throwsFormatException);
  });

  test('checksum mismatch and future schema are rejected', () async {
    final data = await db.exportAllData();
    expect(() => BackupService.validateArchive(backup(data, corrupt: true)), throwsFormatException);
    data['schema_version'] = 999;
    expect(() => BackupService.validateArchive(backup(data)), throwsFormatException);
  });

  test('invalid import rolls back previous rows', () async {
    await db.insertNewTask(TasksCompanion.insert(title: 'keep me', createdAt: 1, updatedAt: 1));
    final data = await db.exportAllData();
    data['tasks'] = [{'id': 'invalid'}];
    await expectLater(db.importAllData(data), throwsA(anything));
    expect((await db.select(db.tasks).get()).single.title, 'keep me');
  });

  test('recap includes postponed events but excludes deleted events', () async {
    final now = DateTime(2026, 11, 8, 12);
    final ms = now.millisecondsSinceEpoch;
    final id = await db.insertNewTask(TasksCompanion.insert(title: 'task', createdAt: ms, updatedAt: ms));
    await db.insertTaskEvent(TaskEventsCompanion.insert(taskId: id, at: ms, fromStatus: 'todo', toStatus: 'postponed', progress: 0, reasonText: const Value('مشغول'), createdAt: ms, updatedAt: ms));
    await db.insertTaskEvent(TaskEventsCompanion.insert(taskId: id, at: ms, fromStatus: 'todo', toStatus: 'done', progress: 100, deletedAt: Value(ms), createdAt: ms, updatedAt: ms));
    final intent = RuleBasedIntentParser(nowProvider: () => now).parse('عملت إيه النهارده؟');
    final answer = await AnswerService(db: db, nowProvider: () => now).buildAnswer(intent);
    expect(answer.speechText, contains('أجلت مهمة'));
    expect(answer.speechText, contains('مشغول'));
    expect(answer.nonSensitiveSpeechText, isNotNull);
    expect(answer.nonSensitiveSpeechText, isNot(contains('جنيه')));
  });

  test('real v7 upgrade preserves tasks and backfills reminders once', () async {
    final dir = await Directory.systemTemp.createTemp('enjaz_migration_');
    final file = File('${dir.path}/db.sqlite');
    var old = AppDatabase(NativeDatabase(file));
    try {
      await old.insertNewTask(TasksCompanion.insert(title: 'existing', dueDate: const Value('2026-11-09'), reminderOffsetMinutes: const Value(10), createdAt: 1, updatedAt: 1));
      await old.customStatement('DROP TABLE unrecognized_phrases');
      await old.customStatement('PRAGMA user_version = 7');
      await old.close();
      old = AppDatabase(NativeDatabase(file));
      expect((await old.select(old.tasks).get()).single.title, 'existing');
      expect((await old.select(old.reminders).get()).single.offsetMinutes, 10);
      expect(await old.select(old.unrecognizedPhrases).get(), isEmpty);
      await old.close();
      old = AppDatabase(NativeDatabase(file));
      expect(await old.select(old.reminders).get(), hasLength(1));
    } finally {
      await old.close();
      await dir.delete(recursive: true);
    }
  });
}
