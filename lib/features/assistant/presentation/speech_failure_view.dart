import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../l10n/app_localizations.dart';

String speechFailureText(BuildContext context, String code) {
  final s = lookupAppLocalizations(Localizations.localeOf(context));
  final message = switch (code) {
    'microphone_denied' || 'error_permission' => s.speechDenied,
    'microphone_permanent' => s.speechPermanent,
    'speech_unavailable' => s.speechUnavailable,
    'arabic_missing' => s.speechArabicMissing,
    'error_network' || 'error_network_timeout' => s.speechNetwork,
    _ => s.speechFailed,
  };
  return '$message ($code)';
}

class SpeechSettingsButton extends StatelessWidget {
  final String code;
  const SpeechSettingsButton({super.key, required this.code});
  @override
  Widget build(BuildContext context) => TextButton(
        child: Text(lookupAppLocalizations(Localizations.localeOf(context))
            .speechSettings),
        onPressed: () async {
          if (code.startsWith('microphone') || code == 'error_permission') {
            await openAppSettings();
          } else {
            try {
              final opened =
                  await const MethodChannel('com.enjaz.app/assistant')
                      .invokeMethod<bool>('speechSettings');
              if (opened != true) await openAppSettings();
            } catch (_) {
              await openAppSettings();
            }
          }
        },
      );
}
