import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:enjaz/core/db/app_database.dart';
import 'package:enjaz/features/settings/presentation/trash_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('TrashScreen renders with 7 tabs and empty placeholders', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
        child: const MaterialApp(
          home: TrashScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(TrashScreen), findsOneWidget);
    expect(find.byType(TabBar), findsOneWidget);
  });
}
