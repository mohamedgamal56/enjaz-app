import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('المساعد الصوتي')),
    body: ListView(
      children: [
        ListTile(title: const Text('عرض الجمل غير المفهومة'), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UnrecognizedScreen()))),
        toggle('assistant_spoken', 'قراءة الردود بصوت عربي', true),
        toggle(
          'assistant_sensitive',
          'قراءة الردود المالية والصحية صوتيًا',
          false,
        ),
        toggle('assistant_confirm', 'تأكيد الأوامر بالصوت', true),
        toggle('assistant_log', 'حفظ الجمل غير المفهومة على الجهاز', true),
        const ListTile(title: Text('سرعة القراءة')),
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
        const ListTile(title: Text('مدة التأكيد بالصوت بالثواني')),
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
          title: const Text('اختبار الصوت العربي'),
          onTap: () async {
            final ok = await _tts.speak(
              'أهلًا بك في إنجاز. يمكنك تسجيل مهامك بصوتك.',
            );
            if (!ok && context.mounted)
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'ثبّت صوتًا عربيًا محليًا من إعدادات تحويل النص إلى كلام في الهاتف.',
                  ),
                ),
              );
          },
        ),
        ListTile(title: const Text('إيقاف القراءة'), onTap: _tts.stop),
        ListTile(title: const Text('إعدادات التعرف على الصوت في الهاتف'), onTap: () async {
          try { await const MethodChannel('com.enjaz.app/assistant').invokeMethod('speechSettings'); } catch (_) {}
        }),
        ListTile(
          title: const Text('اختبار الميكروفون'),
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const VoiceTestScreen())),
        ),
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'أمر واحد في كل جملة. الحذف وتغيير الإعدادات بالصوت غير متاحين. فهم النص محلي؛ تحويل الصوت إلى نص يعتمد على خدمة أندرويد وقد يستخدم الإنترنت. الكتابة تعمل دائمًا.\n\nأمثلة:\nسجل بكرة أكلم العميل الساعة 5\nصرفت خمسين جنيه بنزين\nشربت كوبايتين قهوة\nورايا إيه النهارده؟\nعملت إيه الأسبوع اللي فات؟\nضيف للمشتريات سماعة\nمحتاج كشف أسنان\nملاحظة أراجع الفكرة\nسجل فكرة صوتية',
          ),
        ),
      ],
    ),
  );
}
