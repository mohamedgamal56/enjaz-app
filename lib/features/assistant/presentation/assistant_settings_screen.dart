import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../l10n/app_localizations.dart';
import '../tts_service.dart';
import 'voice_test_screen.dart';
import 'unrecognized_screen.dart';

class AssistantSettingsScreen extends StatefulWidget {
  const AssistantSettingsScreen({super.key});
  @override
  State<AssistantSettingsScreen> createState() =>
      _AssistantSettingsScreenState();
}

class _AssistantSettingsScreenState extends State<AssistantSettingsScreen> {
  SharedPreferences? _prefs;
  final _tts = TtsService();
  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted) setState(() => _prefs = p);
    });
  }

  @override
  void dispose() {
    _tts.dispose();
    super.dispose();
  }

  Widget toggle(String key, String title, bool defaultValue) => SwitchListTile(
    title: Text(title),
    value: _prefs?.getBool(key) ?? defaultValue,
    onChanged: _prefs == null
        ? null
        : (v) async {
            await _prefs!.setBool(key, v);
            if (mounted) setState(() {});
          },
  );
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      appBar: AppBar(title: Text(l10n?.assistantTitle ?? (isAr ? 'المساعد الصوتي' : 'Voice Assistant'))),
      body: ListView(
        children: [
          ListTile(
            title: Text(l10n?.assistantUnrecognizedTitle ?? (isAr ? 'الجمل غير المفهومة' : 'Unrecognized Phrases')),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UnrecognizedScreen())),
          ),
          toggle('assistant_spoken', l10n?.assistantSpeakResponses ?? (isAr ? 'قراءة الردود بصوت عربي' : 'Read responses aloud'), true),
          toggle(
            'assistant_sensitive',
            l10n?.assistantSpeakSensitive ?? (isAr ? 'قراءة الردود المالية والصحية صوتيًا' : 'Read financial & health responses aloud'),
            false,
          ),
          toggle('assistant_confirm', l10n?.assistantConfirmByVoice ?? (isAr ? 'تأكيد الأوامر بالصوت' : 'Confirm commands by voice'), true),
          toggle('assistant_log', l10n?.assistantLogUnrecognized ?? (isAr ? 'حفظ الجمل غير المفهومة على الجهاز' : 'Save unrecognized phrases on device'), true),
          ListTile(title: Text(l10n?.assistantSpeechRate ?? (isAr ? 'سرعة القراءة' : 'Speech rate'))),
          Slider(
            value: _prefs?.getDouble('assistant_rate') ?? 0.5,
            min: 0.2,
            max: 0.8,
            onChanged: _prefs == null
                ? null
                : (v) async {
                    await _prefs!.setDouble('assistant_rate', v);
                    if (mounted) setState(() {});
                  },
          ),
          ListTile(title: Text(l10n?.assistantConfirmWindow ?? (isAr ? 'مدة التأكيد بالصوت بالثواني' : 'Confirmation window (seconds)'))),
          Slider(
            value: (_prefs?.getInt('assistant_window') ?? 5).toDouble(),
            min: 3,
            max: 10,
            divisions: 7,
            label: '${_prefs?.getInt('assistant_window') ?? 5}',
            onChanged: _prefs == null
                ? null
                : (v) async {
                    await _prefs!.setInt('assistant_window', v.round());
                    if (mounted) setState(() {});
                  },
          ),
          ListTile(
            title: Text(l10n?.assistantTestVoice ?? (isAr ? 'اختبار الصوت العربي' : 'Test Arabic Voice')),
            onTap: () async {
              final sampleText = l10n?.assistantTestVoiceSample ?? (isAr ? 'أهلًا بك في إنجاز. يمكنك تسجيل مهامك بصوتك.' : 'Welcome to Enjaz. You can record tasks with your voice.');
              final ok = await _tts.speak(sampleText);
              if (!ok && context.mounted) {
                final missingText = l10n?.assistantTestVoiceMissingTts ?? (isAr ? 'ثبّت صوتًا عربيًا محليًا من إعدادات تحويل النص إلى كلام في الهاتف.' : 'Install a local Arabic voice from TTS settings.');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(missingText)),
                );
              }
            },
          ),
          ListTile(title: Text(l10n?.assistantStopSpeaking ?? (isAr ? 'إيقاف القراءة' : 'Stop Speaking')), onTap: _tts.stop),
          ListTile(title: Text(l10n?.assistantDeviceSpeechSettings ?? (isAr ? 'إعدادات التعرف على الصوت في الهاتف' : 'Speech recognition settings')), onTap: () async {
            try { await const MethodChannel('com.enjaz.app/assistant').invokeMethod('speechSettings'); } catch (_) {}
          }),
          ListTile(
            title: Text(l10n?.assistantTestMic ?? (isAr ? 'اختبار الميكروفون' : 'Microphone Test')),
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const VoiceTestScreen())),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              l10n?.assistantSettingsHelpNote ?? (isAr
                  ? 'أمر واحد في كل جملة. الحذف وتغيير الإعدادات بالصوت غير متاحين. فهم النص محلي؛ تحويل الصوت إلى نص يعتمد على خدمة أندرويد وقد يستخدم الإنترنت. الكتابة تعمل دائمًا.'
                  : 'One command per sentence. Delete and settings changes are not available by voice. Text understanding is offline; speech-to-text uses Android service. Typing always works.'),
            ),
          ),
        ],
      ),
    );
  }
}
