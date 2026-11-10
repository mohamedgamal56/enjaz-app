import 'dart:io';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/db/app_database.dart';
import 'voice_note_service.dart';

class UnsavedRecordingRecoveryService {
  UnsavedRecordingRecoveryService._();

  /// Scans application storage for audio files not recorded in the database
  static Future<List<File>> findUnsavedRecordings(AppDatabase db) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final voiceDir = Directory(p.join(appDir.path, 'voice'));
      if (!await voiceDir.exists()) return [];

      final allVns = await (db.select(db.voiceNotes)).get();
      final knownNames = allVns.map((v) => p.basename(v.fileName)).toSet();

      final unsaved = <File>[];
      final now = DateTime.now();

      await for (final entity in voiceDir.list(followLinks: false)) {
        if (entity is File &&
            (entity.path.endsWith('.m4a') || entity.path.endsWith('.aac'))) {
          final fileName = p.basename(entity.path);
          if (!knownNames.contains(fileName)) {
            final length = await entity.length();
            final lastModified = await entity.lastModified();
            // Must have audio content (> 100 bytes) and not be an active recording (< 10 seconds old)
            if (length > 100 && now.difference(lastModified) > const Duration(seconds: 10)) {
              unsaved.add(entity);
            }
          }
        }
      }

      return unsaved;
    } catch (_) {
      return [];
    }
  }

  /// Recovers an unsaved audio file by registering it in the voice_notes table
  static Future<void> recoverRecording(
    AppDatabase db,
    File file, {
    String? title,
    bool isArabic = true,
  }) async {
    final now = DateTime.now();
    final relativePath = 'voice/${p.basename(file.path)}';
    final length = await file.length();
    final defaultTitle = title ??
        VoiceNoteService.generateVoiceOnlyTitle(date: now, isArabic: isArabic);

    await db.into(db.voiceNotes).insert(
      VoiceNotesCompanion.insert(
        fileName: relativePath,
        durationMs: 0,
        sizeBytes: length,
        createdAt: now.millisecondsSinceEpoch,
        updatedAt: now.millisecondsSinceEpoch,
        parentType: 'general',
        parentId: 0,
        title: Value(defaultTitle),
      ),
    );
  }

  /// Discards and deletes an unsaved audio file
  static Future<void> discardRecording(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  /// Check for unsaved recordings on startup and prompt the user (Spec 14.3)
  static Future<void> checkAndPrompt(BuildContext context, AppDatabase db) async {
    final unsavedFiles = await findUnsavedRecordings(db);
    if (unsavedFiles.isEmpty || !context.mounted) return;

    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    for (final file in unsavedFiles) {
      if (!context.mounted) break;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.mic_external_on_rounded, size: 36, color: Colors.orange),
          title: Text(
            isArabic ? 'تسجيل صوتي غير محفوظ' : 'Unsaved Recording Recovered',
          ),
          content: Text(
            isArabic
                ? 'تم العثور على تسجيل صوتي تم إيقافه فجأة قبل الحفظ (${VoiceNoteService.formatFileSize(file.lengthSync())}). هل تريد الاحتفاظ به كملاحظة صوتية أم حذفه؟'
                : 'An unsaved recording from a previous session was found (${VoiceNoteService.formatFileSize(file.lengthSync())}). Would you like to keep or discard it?',
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await discardRecording(file);
              },
              child: Text(isArabic ? 'حذف وتجاهل' : 'Discard'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.save_rounded, size: 18),
              onPressed: () async {
                Navigator.of(ctx).pop();
                await recoverRecording(db, file, isArabic: isArabic);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isArabic
                            ? 'تم حفظ التسجيل الصوتي بنجاح'
                            : 'Recording recovered and saved successfully',
                      ),
                    ),
                  );
                }
              },
              label: Text(isArabic ? 'حفظ التسجيل' : 'Keep Recording'),
            ),
          ],
        ),
      );
    }
  }
}
