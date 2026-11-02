import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables.dart';
import 'seed_reasons.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  Tasks,
  TaskEvents,
  Reasons,
  Goals,
  Milestones,
  GoalUpdates,
  Ideas,
  Tags,
  IdeaTags,
  Recurrences,
  Settings,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();

          // Seed default reasons
          final now = DateTime.now().millisecondsSinceEpoch;
          for (final r in initialSeedReasons) {
            await into(reasons).insert(
              ReasonsCompanion.insert(
                labelAr: r.labelAr,
                labelEn: Value(r.labelEn),
                category: r.category,
                createdAt: now,
                updatedAt: now,
                isDefault: const Value(true),
                usageCount: const Value(0),
                archived: const Value(false),
              ),
            );
          }
        },
        onUpgrade: (Migrator m, int from, int to) async {
          // Versioned migrations go here
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'enjaz.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});
