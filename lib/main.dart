import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/l10n/app_localizations.dart';
import 'l10n/app_localizations.dart' as gen_l10n;
import 'core/l10n/l10n.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/navigation/presentation/main_shell.dart';
import 'features/reminders/presentation/alarm_overlay.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: EnjazApp(),
    ),
  );
}

class EnjazApp extends ConsumerWidget {
  const EnjazApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customLocale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);

    // Default locale if none selected: Arabic as primary per spec
    final activeLocale = customLocale ?? const Locale('ar');

    return MaterialApp(
      title: 'إنجاز - Enjaz',
      debugShowCheckedModeBanner: false,
      locale: activeLocale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        gen_l10n.AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light(activeLocale.languageCode),
      darkTheme: AppTheme.dark(activeLocale.languageCode),
      themeMode: themeMode,
      builder: (context, child) =>
          AlarmOverlay(child: child ?? const SizedBox.shrink()),
      home: const MainShell(),
    );
  }
}
