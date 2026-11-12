import 'package:enjaz/core/theme/enjaz_appearance.dart';
import 'package:enjaz/features/settings/presentation/appearance_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget harness(Widget child, {String language = 'ar'}) => ProviderScope(
      child: MaterialApp(
        locale: Locale(language),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: child,
      ),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('all fourteen new appearances have unique persisted IDs', () async {
    final choices = EnjazAppearance.values
        .where((v) => v != EnjazAppearance.original)
        .toList();
    expect(choices, hasLength(14));
    expect(choices.map((v) => v.name).toSet(), hasLength(14));

    final first = ProviderContainer();
    await first
        .read(enjazAppearanceProvider.notifier)
        .select(EnjazAppearance.nile);
    expect(first.read(enjazAppearanceProvider), EnjazAppearance.nile);
    first.dispose();

    final restored = ProviderContainer();
    restored.read(enjazAppearanceProvider);
    await Future<void>.delayed(Duration.zero);
    expect(restored.read(enjazAppearanceProvider), EnjazAppearance.nile);
    restored.dispose();
  });

  for (final look in EnjazAppearance.values) {
    testWidgets('${look.name} previews in RTL on a narrow phone',
        (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester
          .pumpWidget(harness(AppearancePreviewScreen(appearance: look)));
      await tester.pumpAndSettle();
      expect(find.text(look.ar), findsOneWidget);
      expect(find.text('معاينة ببيانات تجريبية'), findsOneWidget);
      expect(find.text('أهلاً، محمد'), findsOneWidget);
      final scroller = find.byType(ListView).first;
      for (var i = 0; i < 3; i++) {
        await tester.drag(scroller, const Offset(0, -450));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('preview is reversible and applying changes the saved appearance',
      (tester) async {
    await tester.pumpWidget(harness(const AppearanceScreen(), language: 'en'));
    await tester.pumpAndSettle();
    final choice = find.byKey(const ValueKey('appearance-classic'));
    await tester.tap(choice);
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('enjaz_appearance'), isNull);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(prefs.getString('enjaz_appearance'), isNull);
    await tester.tap(choice);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('apply-enjaz-appearance')));
    await tester.pumpAndSettle();
    expect(prefs.getString('enjaz_appearance'), 'classic');
    expect(find.byType(AppearanceScreen), findsOneWidget);
  });
}
