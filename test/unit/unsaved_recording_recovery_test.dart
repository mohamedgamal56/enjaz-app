import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:enjaz/core/db/app_database.dart';
import 'package:enjaz/features/voice_notes/domain/unsaved_recording_recovery_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late Directory tempDir;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    tempDir = await Directory.systemTemp.createTemp('enjaz_recovery_test_');
  });

  tearDown(() async {
    await db.close();
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  group('Unsaved Recording Recovery Service Tests (Spec 14.3)', () {
    test('Recovers orphaned recording into voice_notes database table', () async {
      final voiceFile = File(p.join(tempDir.path, 'voice_crashed_12345.m4a'));
      await voiceFile.writeAsBytes(List.filled(5000, 42));

      expect(await voiceFile.exists(), isTrue);

      // Recover it
      await UnsavedRecordingRecoveryService.recoverRecording(
        db,
        voiceFile,
        title: 'تسجيل مسترجع',
        isArabic: true,
      );

      final voiceNotes = await db.getAllVoiceNotesList();
      expect(voiceNotes.length, equals(1));
      expect(voiceNotes.first.title, equals('تسجيل مسترجع'));
      expect(voiceNotes.first.fileName, contains('voice_crashed_12345.m4a'));
      expect(voiceNotes.first.sizeBytes, equals(5000));
    });

    test('Discards and physically deletes orphaned recording', () async {
      final voiceFile = File(p.join(tempDir.path, 'voice_discard_999.m4a'));
      await voiceFile.writeAsBytes(List.filled(2000, 1));

      expect(await voiceFile.exists(), isTrue);

      await UnsavedRecordingRecoveryService.discardRecording(voiceFile);

      expect(await voiceFile.exists(), isFalse);
    });
  });
}
