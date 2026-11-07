import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../rule_based_intent_parser.dart';
import '../voice_input_service.dart';

class VoiceTestItem {
  final int id;
  final String category; // 'amount', 'datetime', 'question', 'dialect'
  final String expectedText;
  String? recognizedText;
  bool? isIntentCorrect;
  bool? isNumberCorrect;
  bool? isDateTimeCorrect;

  VoiceTestItem({
    required this.id,
    required this.category,
    required this.expectedText,
    this.recognizedText,
    this.isIntentCorrect,
    this.isNumberCorrect,
    this.isDateTimeCorrect,
  });
}

/// Dedicated 30-Sentence Speech Recognition Test Wizard (VOICE.md Section 10.3).
class VoiceTestScreen extends StatefulWidget {
  final VoiceInputService? voiceService;

  const VoiceTestScreen({super.key, this.voiceService});

  @override
  State<VoiceTestScreen> createState() => _VoiceTestScreenState();
}

class _VoiceTestScreenState extends State<VoiceTestScreen> {
  late final VoiceInputService _voiceService;
  final RuleBasedIntentParser _parser = RuleBasedIntentParser();
  bool _isAirplaneMode = false;
  int? _activeRecordingIndex;
  String _liveTranscript = '';

  late final List<VoiceTestItem> _testItems;

  @override
  void initState() {
    super.initState();
    _voiceService = widget.voiceService ?? VoiceInputService();
    _initTestItems();

    _voiceService.transcriptStream.listen((text) {
      if (mounted && _activeRecordingIndex != null) {
        setState(() {
          _liveTranscript = text;
        });
      }
    });
  }

  void _initTestItems() {
    _testItems = [
      // 10 commands with amounts
      VoiceTestItem(id: 1, category: 'أوامر بمبالغ', expectedText: 'صرفت 100 جنيه بنزين للموتوسيكل النهارده'),
      VoiceTestItem(id: 2, category: 'أوامر بمبالغ', expectedText: 'سجل شاي وقهوة بـ 25 جنيه'),
      VoiceTestItem(id: 3, category: 'أوامر بمبالغ', expectedText: 'صرفت 350 جنيه سوبر ماركت طلبات البيت'),
      VoiceTestItem(id: 4, category: 'أوامر بمبالغ', expectedText: 'دخل 5000 جنيه من مشروع فريلانس'),
      VoiceTestItem(id: 5, category: 'أوامر بمبالغ', expectedText: 'سجل 75 جنيه غدا كشري وسلطة'),
      VoiceTestItem(id: 6, category: 'أوامر بمبالغ', expectedText: 'دفعت 1500 جنيه إيجار الشقة'),
      VoiceTestItem(id: 7, category: 'أوامر بمبالغ', expectedText: 'صرفت خمسين جنيه كارت شحن'),
      VoiceTestItem(id: 8, category: 'أوامر بمبالغ', expectedText: 'اشتريت دواء من الصيدلية بـ 120 جنيه'),
      VoiceTestItem(id: 9, category: 'أوامر بمبالغ', expectedText: 'ضيف للمشتريات شاشة كمبيوتر بـ 4500 جنيه'),
      VoiceTestItem(id: 10, category: 'أوامر بمبالغ', expectedText: 'سجل 80 جنيه مواصلات ومترو'),

      // 10 commands with dates and times
      VoiceTestItem(id: 11, category: 'أوامر بتواريخ وأوقات', expectedText: 'أنا بكرة عايز أعمل مونتاج الإعلان الساعة 4 العصر'),
      VoiceTestItem(id: 12, category: 'أوامر بتواريخ وأوقات', expectedText: 'سجل مشوار النهارده أروح السنترال الساعة 1'),
      VoiceTestItem(id: 13, category: 'أوامر بتواريخ وأوقات', expectedText: 'فكرني يوم الخميس أكلم دكتور أحمد الساعة 7 بالليل'),
      VoiceTestItem(id: 14, category: 'أوامر بتواريخ وأوقات', expectedText: 'سجل مهمة مراجعة التقارير الشهرية يوم الخميس الساعة 2'),
      VoiceTestItem(id: 15, category: 'أوامر بتواريخ وأوقات', expectedText: 'فكرني بكرة الساعة 6 أصحى مصطفى للمدرسة'),
      VoiceTestItem(id: 16, category: 'أوامر بتواريخ وأوقات', expectedText: 'مشوار يوم التلات أروح البنك الساعة 10 الصبح'),
      VoiceTestItem(id: 17, category: 'أوامر بتواريخ وأوقات', expectedText: 'أجل مهمة مراجعة الحسابات لبكرة عشان مضغوط في الشغل'),
      VoiceTestItem(id: 18, category: 'أوامر بتواريخ وأوقات', expectedText: 'سجل كشف رمد يوم 15 نوفمبر الساعة 5'),
      VoiceTestItem(id: 19, category: 'أوامر بتواريخ وأوقات', expectedText: 'فكرني بعد ساعتين أقفل الغسالة'),
      VoiceTestItem(id: 20, category: 'أوامر بتواريخ وأوقات', expectedText: 'سجل مهمة تسليم المشروع النهائي يوم 20 نوفمبر'),

      // 5 questions
      VoiceTestItem(id: 21, category: 'أسئلة واستفسارات', expectedText: 'ورايا إيه النهارده؟'),
      VoiceTestItem(id: 22, category: 'أسئلة واستفسارات', expectedText: 'صرفت كام الشهر ده؟'),
      VoiceTestItem(id: 23, category: 'أسئلة واستفسارات', expectedText: 'إيه المهام المتأخرة عندي؟'),
      VoiceTestItem(id: 24, category: 'أسئلة واستفسارات', expectedText: 'عملت إيه إمبارح؟'),
      VoiceTestItem(id: 25, category: 'أسئلة واستفسارات', expectedText: 'إيه اللي عليا الشهر ده؟'),

      // 5 Egyptian dialect words
      VoiceTestItem(id: 26, category: 'كلمات عامية مصرية', expectedText: 'شربت كوبايتين قهوة مظبوط النهارده'),
      VoiceTestItem(id: 27, category: 'كلمات عامية مصرية', expectedText: 'صليت العصر في الجامع'),
      VoiceTestItem(id: 28, category: 'كلمات عامية مصرية', expectedText: 'أجل المشوار بتاع التصوير لبعده عشان مفيش فلوس'),
      VoiceTestItem(id: 29, category: 'كلمات عامية مصرية', expectedText: 'ملاحظة الفكرة محتاجة تظبيط شوية'),
      VoiceTestItem(id: 30, category: 'كلمات عامية مصرية', expectedText: 'عايز اشتري هيدفون جديد عشان القديم باظ'),
    ];
  }

  Future<void> _toggleRecord(int index) async {
    if (_activeRecordingIndex == index) {
      // Stop recording
      final finalTranscript = await _voiceService.stopListening();
      final item = _testItems[index];
      item.recognizedText = finalTranscript.isEmpty ? _liveTranscript : finalTranscript;
      _evaluateItem(item);

      setState(() {
        _activeRecordingIndex = null;
        _liveTranscript = '';
      });
    } else {
      // Start recording for this item
      if (_activeRecordingIndex != null) {
        await _voiceService.stopListening();
      }

      setState(() {
        _activeRecordingIndex = index;
        _liveTranscript = '';
      });

      await _voiceService.startListening();
    }
  }

  void _evaluateItem(VoiceTestItem item) {
    final text = item.recognizedText ?? '';
    if (text.isEmpty) {
      item.isIntentCorrect = false;
      item.isNumberCorrect = false;
      item.isDateTimeCorrect = false;
      return;
    }

    final parsed = _parser.parse(text);
    item.isIntentCorrect = parsed.isRecognized;

    // Check numbers
    final hasNumberExpected = item.expectedText.contains(RegExp(r'\d+|خمسين|كوبايتين'));
    if (hasNumberExpected) {
      item.isNumberCorrect = parsed.slots.containsKey('amount') ||
          parsed.slots.containsKey('quantity') ||
          text.contains(RegExp(r'\d+'));
    } else {
      item.isNumberCorrect = true;
    }

    // Check dates/times
    final hasDateExpected = item.expectedText.contains(RegExp(r'النهارده|بكرة|الخميس|التلات|نوفمبر|ساعتين|الشهر|إمبارح'));
    if (hasDateExpected) {
      item.isDateTimeCorrect = parsed.slots.containsKey('date') ||
          parsed.slots.containsKey('time') ||
          parsed.slots.containsKey('period');
    } else {
      item.isDateTimeCorrect = true;
    }
  }

  void _copyMarkdownReport() {
    final modeStr = _isAirplaneMode ? 'وضع الطيران (Airplane Mode)' : 'الوضع العادي (Online/Local Pack)';
    final buffer = StringBuffer();
    buffer.writeln('# تقرير اختبار التعرف الصوتي (VOICE.md Section 10.3) — $modeStr');
    buffer.writeln();
    buffer.writeln('| # | الفئة | الجملة المستهدفة | النص المنطوق الفعلي | صحة الأرقام | صحة التواريخ | صحة النية |');
    buffer.writeln('|---|---|---|---|---|---|---|');

    for (final item in _testItems) {
      final rec = (item.recognizedText ?? '-').replaceAll('|', '/');
      final numOk = item.isNumberCorrect == true ? '✅' : (item.isNumberCorrect == false ? '❌' : '-');
      final dtOk = item.isDateTimeCorrect == true ? '✅' : (item.isDateTimeCorrect == false ? '❌' : '-');
      final intentOk = item.isIntentCorrect == true ? '✅' : (item.isIntentCorrect == false ? '❌' : '-');
      buffer.writeln('| ${item.id} | ${item.category} | ${item.expectedText} | $rec | $numOk | $dtOk | $intentOk |');
    }

    final testedCount = _testItems.where((i) => i.recognizedText != null).length;
    final successCount = _testItems.where((i) => i.isIntentCorrect == true).length;
    buffer.writeln();
    buffer.writeln('**الإجمالي المختبر:** $testedCount / 30');
    buffer.writeln('**النجاح الإجمالي للنية:** $successCount / $testedCount');

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم نسخ جدول التقرير بصيغة Markdown بنجاح!'),
        backgroundColor: Colors.teal,
      ),
    );
  }

  @override
  void dispose() {
    _voiceService.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final testedCount = _testItems.where((i) => i.recognizedText != null).length;
    final successCount = _testItems.where((i) => i.isIntentCorrect == true).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('اختبار التعرف الصوتي (30 جملة)'),
        actions: [
          IconButton(
            tooltip: 'نسخ التقرير (Markdown)',
            icon: const Icon(Icons.copy_all_rounded),
            onPressed: _copyMarkdownReport,
          ),
        ],
      ),
      body: Column(
        children: [
          // Mode switch & stats header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الإنجاز: $testedCount من 30 مختبرة ($successCount ناجحة)',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: 30 > 0 ? testedCount / 30 : 0.0,
                          minHeight: 6,
                          backgroundColor: Colors.grey.shade300,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                FilterChip(
                  label: Text(_isAirplaneMode ? '✈️ وضع الطيران' : '🌐 وضع عادي'),
                  selected: _isAirplaneMode,
                  onSelected: (val) {
                    setState(() {
                      _isAirplaneMode = val;
                    });
                  },
                ),
              ],
            ),
          ),

          // 30 items list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _testItems.length,
              itemBuilder: (context, index) {
                final item = _testItems[index];
                final isRecording = _activeRecordingIndex == index;
                final currentText = isRecording ? _liveTranscript : item.recognizedText;

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isRecording
                          ? Colors.red
                          : (item.isIntentCorrect == true ? Colors.green.shade300 : Colors.transparent),
                      width: isRecording ? 2 : 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Category and item number
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '#${item.id} - ${item.category}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (item.isIntentCorrect != null)
                              Row(
                                children: [
                                  _buildTag('نية', item.isIntentCorrect),
                                  const SizedBox(width: 4),
                                  _buildTag('أرقام', item.isNumberCorrect),
                                  const SizedBox(width: 4),
                                  _buildTag('وقت', item.isDateTimeCorrect),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Expected phrase
                        Text(
                          item.expectedText,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Recognized or Live text
                        if (currentText != null && currentText.isNotEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isRecording ? Colors.red.shade50 : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'المنطوق: $currentText',
                              style: TextStyle(
                                color: isRecording ? Colors.red.shade900 : Colors.black87,
                                fontStyle: isRecording ? FontStyle.italic : FontStyle.normal,
                              ),
                            ),
                          ),

                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isRecording ? Colors.red : theme.colorScheme.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: Icon(isRecording ? Icons.stop_rounded : Icons.mic_rounded),
                            label: Text(isRecording ? 'إيقاف وحفظ' : 'تسجيل صوتي'),
                            onPressed: () => _toggleRecord(index),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String label, bool? ok) {
    if (ok == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: ok ? Colors.green.shade100 : Colors.red.shade100,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$label: ${ok ? '✓' : '✗'}',
        style: TextStyle(
          fontSize: 10,
          color: ok ? Colors.green.shade900 : Colors.red.shade900,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
