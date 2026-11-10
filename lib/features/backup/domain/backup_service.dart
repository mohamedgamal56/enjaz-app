import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/db/app_database.dart';
import '../../reminders/domain/notification_service.dart';
import '../../reminders/domain/reminder_scheduler.dart';
import 'backup_models.dart';
import 'backup_encryption_service.dart';

class BackupService {
  BackupService._();

  static const String appVersion = '1.2.0';

  static void validateArchive(Archive archive, {int maxSchemaVersion = 8}) {
    final data = archive.findFile('data.json');
    if (data == null)
      throw const FormatException('بيانات النسخة الاحتياطية ناقصة');
    final decoded = jsonDecode(utf8.decode(data.content as List<int>));
    if (decoded is! Map<String, dynamic> ||
        decoded['tasks'] is! List ||
        decoded['schema_version'] is! int ||
        decoded['schema_version'] < 1 ||
        decoded['schema_version'] > maxSchemaVersion) {
      throw const FormatException('نسخة احتياطية غير صالحة أو من إصدار أحدث');
    }
    final version = decoded['schema_version'] as int;
    final requiredTables = <String>[
      'tasks', 'task_events', 'reasons', 'goals', 'milestones', 'goal_updates',
      'ideas', 'tags', 'idea_tags', 'recurrences', 'settings',
      if (version >= 2) 'voice_notes',
      if (version >= 3) 'reminders',
      if (version >= 4) 'notes',
      if (version >= 5) ...['habits', 'habit_items', 'habit_logs', 'habit_item_logs'],
      if (version >= 6) ...['finance_categories', 'transactions', 'quick_expenses', 'wishlist_items', 'obligations', 'obligation_instances', 'budgets'],
      if (version >= 7) ...['health_items', 'health_events', 'treatments', 'treatment_checks'],
      if (version >= 8) 'unrecognized_phrases',
    ];
    for (final key in requiredTables) {
      if (decoded[key] is! List || (decoded[key] as List).any((row) => row is! Map<String, dynamic>)) {
        throw FormatException('جدول ناقص أو غير صالح: $key');
      }
    }
    final manifestFile = archive.findFile('manifest.json');
    if (manifestFile != null) {
      final manifest = BackupManifest.fromJson(
        jsonDecode(utf8.decode(manifestFile.content as List<int>)),
      );
      if (manifest.schemaVersion != version || !manifest.checksums.containsKey('data.json'))
        throw const FormatException('إصدار النسخة أحدث من التطبيق');
      for (final entry in manifest.checksums.entries) {
        final file = archive.findFile(entry.key);
        if (file == null ||
            sha256.convert(file.content as List<int>).toString() !=
                entry.value) {
          throw const FormatException('ملف النسخة الاحتياطية تالف');
        }
      }
    }
  }

  /// Export full backup archive (.zip)
  static Future<File> exportFullBackup({
    required AppDatabase db,
    required bool includeVoice,
    String? password,
  }) async {
    final archive = Archive();
    final checksums = <String, String>{};

    // 1. Export DB tables to data.json
    final dataMap = await db.exportAllData();
    final jsonString = jsonEncode(dataMap);
    final jsonBytes = utf8.encode(jsonString);
    final dataSha256 = sha256.convert(jsonBytes).toString();
    checksums['data.json'] = dataSha256;

    archive.addFile(ArchiveFile('data.json', jsonBytes.length, jsonBytes));

    // 2. Export Voice Notes if requested
    int voiceCount = 0;
    if (includeVoice) {
      final voiceNotes = await db.getAllVoiceNotesList();
      final appDir = await getApplicationDocumentsDirectory();

      for (final vn in voiceNotes) {
        final filePath = p.join(appDir.path, vn.fileName);
        final file = File(filePath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final fileHash = sha256.convert(bytes).toString();
          final archivePath = 'voice/${p.basename(vn.fileName)}';
          checksums[archivePath] = fileHash;

          archive.addFile(ArchiveFile(archivePath, bytes.length, bytes));
          voiceCount++;
        }
      }
    }

    // 3. Build manifest.json
    final counts = <String, int>{
      'tasks': (dataMap['tasks'] as List?)?.length ?? 0,
      'task_events': (dataMap['task_events'] as List?)?.length ?? 0,
      'reasons': (dataMap['reasons'] as List?)?.length ?? 0,
      'goals': (dataMap['goals'] as List?)?.length ?? 0,
      'milestones': (dataMap['milestones'] as List?)?.length ?? 0,
      'goal_updates': (dataMap['goal_updates'] as List?)?.length ?? 0,
      'ideas': (dataMap['ideas'] as List?)?.length ?? 0,
      'tags': (dataMap['tags'] as List?)?.length ?? 0,
      'idea_tags': (dataMap['idea_tags'] as List?)?.length ?? 0,
      'recurrences': (dataMap['recurrences'] as List?)?.length ?? 0,
      'voice_notes': voiceCount,
      'notes': (dataMap['notes'] as List?)?.length ?? 0,
      'habits': (dataMap['habits'] as List?)?.length ?? 0,
      'transactions': (dataMap['transactions'] as List?)?.length ?? 0,
      'finance':
          ((dataMap['transactions'] as List?)?.length ?? 0) +
          ((dataMap['wishlist_items'] as List?)?.length ?? 0) +
          ((dataMap['obligations'] as List?)?.length ?? 0),
      'health_items': (dataMap['health_items'] as List?)?.length ?? 0,
      'treatments': (dataMap['treatments'] as List?)?.length ?? 0,
      'health':
          ((dataMap['health_items'] as List?)?.length ?? 0) +
          ((dataMap['treatments'] as List?)?.length ?? 0),
    };

    final manifest = BackupManifest(
      schemaVersion: db.schemaVersion,
      appVersion: appVersion,
      createdAt: DateTime.now().toIso8601String(),
      includesVoice: includeVoice,
      counts: counts,
      checksums: checksums,
    );

    final manifestBytes = utf8.encode(jsonEncode(manifest.toJson()));
    archive.addFile(
      ArchiveFile('manifest.json', manifestBytes.length, manifestBytes),
    );

    // 4. Encode zip & apply optional encryption
    final zipEncoder = ZipEncoder();
    final encodedZip = zipEncoder.encode(archive) ?? <int>[];

    List<int> finalBytes = encodedZip;
    final isEncrypted = password != null && password.trim().isNotEmpty;
    if (isEncrypted) {
      finalBytes = await BackupEncryptionService.instance.encrypt(
        plaintextBytes: encodedZip,
        password: password.trim(),
      );
    }

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final ext = isEncrypted ? 'enjaz' : 'zip';
    final backupFileName = 'Enjaz_Backup_$timestamp.$ext';
    final backupFile = File(p.join(tempDir.path, backupFileName));
    await backupFile.writeAsBytes(finalBytes);

    return backupFile;
  }

  /// Inspect a picked backup file (.zip or encrypted .enjaz) and return preview information
  static Future<BackupPreview> inspectBackupFile(
    File file, {
    String? password,
  }) async {
    try {
      if (!await file.exists()) {
        return BackupPreview.invalid('الملف المحدد غير موجود.');
      }

      final bytes = await file.readAsBytes();
      final isEncrypted = BackupEncryptionService.instance.isEncryptedBackup(
        bytes,
      );

      if (isEncrypted && (password == null || password.trim().isEmpty)) {
        return BackupPreview.encryptedNeedPassword(fileSizeBytes: bytes.length);
      }

      final List<int> zipBytes;
      if (isEncrypted) {
        zipBytes = await BackupEncryptionService.instance.decrypt(
          encryptedBytes: bytes,
          password: password!.trim(),
        );
      } else {
        zipBytes = bytes;
      }

      final archive = ZipDecoder().decodeBytes(zipBytes);
      validateArchive(archive);

      ArchiveFile? manifestFile;
      ArchiveFile? dataFile;

      for (final f in archive) {
        if (f.name == 'manifest.json') manifestFile = f;
        if (f.name == 'data.json') dataFile = f;
      }

      if (dataFile == null) {
        return BackupPreview.invalid(
          'الملف المضغوط لا يحتوي على بيانات التطبيق (data.json).',
        );
      }

      final dataString = utf8.decode(dataFile.content as List<int>);
      final dataMap = jsonDecode(dataString) as Map<String, dynamic>;

      BackupManifest? manifest;
      if (manifestFile != null) {
        try {
          final manifestString = utf8.decode(manifestFile.content as List<int>);
          final manifestMap =
              jsonDecode(manifestString) as Map<String, dynamic>;
          manifest = BackupManifest.fromJson(manifestMap);
        } catch (_) {}
      }

      final tasksCount =
          (dataMap['tasks'] as List?)?.length ?? manifest?.counts['tasks'] ?? 0;
      final goalsCount =
          (dataMap['goals'] as List?)?.length ?? manifest?.counts['goals'] ?? 0;
      final ideasCount =
          (dataMap['ideas'] as List?)?.length ?? manifest?.counts['ideas'] ?? 0;
      final notesCount =
          (dataMap['notes'] as List?)?.length ?? manifest?.counts['notes'] ?? 0;
      final habitsCount =
          (dataMap['habits'] as List?)?.length ??
          manifest?.counts['habits'] ??
          0;
      final financeCount =
          ((dataMap['transactions'] as List?)?.length ?? 0) +
                  ((dataMap['wishlist_items'] as List?)?.length ?? 0) +
                  ((dataMap['obligations'] as List?)?.length ?? 0) !=
              0
          ? ((dataMap['transactions'] as List?)?.length ?? 0) +
                ((dataMap['wishlist_items'] as List?)?.length ?? 0) +
                ((dataMap['obligations'] as List?)?.length ?? 0)
          : (manifest?.counts['finance'] ?? 0);
      final healthCount =
          ((dataMap['health_items'] as List?)?.length ?? 0) +
                  ((dataMap['treatments'] as List?)?.length ?? 0) !=
              0
          ? ((dataMap['health_items'] as List?)?.length ?? 0) +
                ((dataMap['treatments'] as List?)?.length ?? 0)
          : (manifest?.counts['health'] ?? 0);
      final voiceNotesCount =
          (dataMap['voice_notes'] as List?)?.length ??
          manifest?.counts['voice_notes'] ??
          0;

      DateTime? createdAt;
      if (manifest?.createdAt != null) {
        createdAt = DateTime.tryParse(manifest!.createdAt);
      } else if (dataMap['exported_at'] != null) {
        createdAt = DateTime.tryParse(dataMap['exported_at'].toString());
      }

      return BackupPreview(
        isValid: true,
        isEncrypted: isEncrypted,
        schemaVersion:
            manifest?.schemaVersion ?? (dataMap['schema_version'] as int? ?? 1),
        createdAt: createdAt,
        includesVoice: manifest?.includesVoice ?? false,
        tasksCount: tasksCount,
        goalsCount: goalsCount,
        ideasCount: ideasCount,
        notesCount: notesCount,
        habitsCount: habitsCount,
        financeCount: financeCount,
        healthCount: healthCount,
        voiceNotesCount: voiceNotesCount,
        fileSizeBytes: bytes.length,
      );
    } on BackupEncryptionException catch (e) {
      return BackupPreview.invalid(e.message);
    } catch (e) {
      return BackupPreview.invalid('تعذر قراءة ملف النسخة الاحتياطية: $e');
    }
  }

  /// Restore backup archive: creates safety snapshot first, then replaces database and extracts audio files
  static Future<bool> restoreBackup({
    required AppDatabase db,
    required File zipFile,
    String? password,
    bool createSafetySnapshot = true,
  }) async {
    final rawBytes = await zipFile.readAsBytes();
    final isEncrypted = BackupEncryptionService.instance.isEncryptedBackup(
      rawBytes,
    );

    final List<int> zipBytes;
    if (isEncrypted) {
      if (password == null || password.trim().isEmpty) {
        throw const BackupEncryptionException(
          'يرجى إدخال كلمة المرور لفك تشفير النسخة الاحتياطية.',
        );
      }
      zipBytes = await BackupEncryptionService.instance.decrypt(
        encryptedBytes: rawBytes,
        password: password.trim(),
      );
    } else {
      zipBytes = rawBytes;
    }

    final validatedArchive = ZipDecoder().decodeBytes(zipBytes);
    validateArchive(validatedArchive, maxSchemaVersion: db.schemaVersion);
    // 1. Create safety snapshot before restoration
    if (createSafetySnapshot) {
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final backupsDir = Directory(p.join(appDir.path, 'backups'));
        if (!await backupsDir.exists()) {
          await backupsDir.create(recursive: true);
        }
        final safetyFile = await exportFullBackup(db: db, includeVoice: true);
        final safetyTarget = p.join(
          backupsDir.path,
          'safety_pre_restore_${DateTime.now().millisecondsSinceEpoch}.zip',
        );
        await safetyFile.copy(safetyTarget);
      } catch (e) {
        throw StateError('تعذر حفظ نسخة الأمان. لم يتم استبدال البيانات.');
      }
    }

    final archive = ZipDecoder().decodeBytes(zipBytes);

    ArchiveFile? dataFile;
    final voiceFiles = <ArchiveFile>[];

    for (final file in archive) {
      if (file.name == 'data.json') {
        dataFile = file;
      } else if (file.name.startsWith('voice/') && !file.name.endsWith('/')) {
        voiceFiles.add(file);
      }
    }

    if (dataFile == null) {
      throw Exception('الملف لا يحتوي على data.json');
    }

    // 2. Decode and import database data
    final dataString = utf8.decode(dataFile.content as List<int>);
    final dataMap = jsonDecode(dataString) as Map<String, dynamic>;
    // Write restored audio under unique names first. Existing recordings remain
    // intact if a write or the database transaction fails.
    final stagedFiles = <File>[];
    final restoredNames = <String, String>{};
    final restoreId = DateTime.now().microsecondsSinceEpoch;
    try {
    if (voiceFiles.isNotEmpty) {
      final appDir = await getApplicationDocumentsDirectory();
      final voiceDir = Directory(p.join(appDir.path, 'voice'));
      if (!await voiceDir.exists()) {
        await voiceDir.create(recursive: true);
      }

      for (final vf in voiceFiles) {
        final fileName = p.basename(vf.name);
        final newName = 'restore_${restoreId}_${stagedFiles.length}_$fileName';
        final targetPath = p.join(voiceDir.path, newName);
        final targetFile = File(targetPath);
        stagedFiles.add(targetFile);
        await targetFile.writeAsBytes(vf.content as List<int>, flush: true);
        restoredNames[fileName] = 'voice/$newName';
      }
    }
    for (final row in (dataMap['voice_notes'] as List? ?? [])) {
      final original = row['fileName'] as String?;
      final restored = original == null ? null : restoredNames[p.basename(original)];
      if (restored != null) row['fileName'] = restored;
    }
    await db.importAllData(dataMap);
    } catch (_) {
      for (final file in stagedFiles) {
        try { if (await file.exists()) await file.delete(); } catch (_) {}
      }
      rethrow;
    }

    // 4. Reschedule reminders
    await NotificationService().cancelAll();
    await NotificationService().rescheduleAll(db);
    await ReminderScheduler(db: db).rescheduleAllActive();

    return true;
  }

  /// Export tasks.csv with UTF-8 BOM and all fields including voice_note_count
  static Future<File> exportTasksCsv(AppDatabase db) async {
    final tasksList = await (db.select(
      db.tasks,
    )..where((t) => t.deletedAt.isNull())).get();
    final voiceCounts = await db.getTaskVoiceNotesCounts();

    final buffer = StringBuffer();
    // UTF-8 BOM
    buffer.write('\uFEFF');

    // Headers
    buffer.writeln(
      'id,title,kind,status,priority,dueDate,dueTime,postponedUntil,postponeCount,progress,reasonId,reasonText,goalId,milestoneId,notes,outcomeNote,locationText,reminderOffsetMinutes,recurrenceId,voiceNoteCount,createdAt,updatedAt,deletedAt',
    );

    for (final t in tasksList) {
      final vCount = voiceCounts[t.id] ?? 0;
      final row = [
        t.id,
        _escapeCsv(t.title),
        _escapeCsv(t.kind),
        _escapeCsv(t.status),
        _escapeCsv(t.priority),
        _escapeCsv(t.dueDate ?? ''),
        _escapeCsv(t.dueTime ?? ''),
        _escapeCsv(t.postponedUntil ?? ''),
        t.postponeCount,
        t.progress,
        t.reasonId ?? '',
        _escapeCsv(t.reasonText ?? ''),
        t.goalId ?? '',
        t.milestoneId ?? '',
        _escapeCsv(t.notes ?? ''),
        _escapeCsv(t.outcomeNote ?? ''),
        _escapeCsv(t.locationText ?? ''),
        t.reminderOffsetMinutes ?? '',
        t.recurrenceId ?? '',
        vCount,
        t.createdAt,
        t.updatedAt,
        t.deletedAt ?? '',
      ];
      buffer.writeln(row.join(','));
    }

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final file = File(p.join(tempDir.path, 'tasks_export_$timestamp.csv'));
    await file.writeAsString(buffer.toString(), encoding: utf8);
    return file;
  }

  /// Export events.csv with UTF-8 BOM and all fields
  static Future<File> exportEventsCsv(AppDatabase db) async {
    final eventsList = await (db.select(
      db.taskEvents,
    )..where((e) => e.deletedAt.isNull())).get();

    final buffer = StringBuffer();
    // UTF-8 BOM
    buffer.write('\uFEFF');

    // Headers
    buffer.writeln(
      'id,taskId,at,fromStatus,toStatus,progress,reasonId,reasonText,note,createdAt,updatedAt,deletedAt',
    );

    for (final e in eventsList) {
      final row = [
        e.id,
        e.taskId,
        e.at,
        _escapeCsv(e.fromStatus),
        _escapeCsv(e.toStatus),
        e.progress,
        e.reasonId ?? '',
        _escapeCsv(e.reasonText ?? ''),
        _escapeCsv(e.note ?? ''),
        e.createdAt,
        e.updatedAt,
        e.deletedAt ?? '',
      ];
      buffer.writeln(row.join(','));
    }

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final file = File(p.join(tempDir.path, 'events_export_$timestamp.csv'));
    await file.writeAsString(buffer.toString(), encoding: utf8);
    return file;
  }

  static String _escapeCsv(String val) {
    if (val.isEmpty) return '';
    if (val.contains(',') ||
        val.contains('"') ||
        val.contains('\n') ||
        val.contains('\r')) {
      return '"${val.replaceAll('"', '""')}"';
    }
    return val;
  }
}
