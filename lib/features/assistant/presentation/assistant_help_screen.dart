import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';

/// Screen displaying the complete guide of commands and questions supported by the Voice Assistant (VOICE.md Sections 2.8, 5 & 6).
class AssistantHelpScreen extends StatelessWidget {
  const AssistantHelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(isArabic ? 'دليل أوامر المساعد' : 'Assistant Commands Guide'),
          bottom: TabBar(
            tabs: [
              Tab(
                icon: const Icon(Icons.add_task_rounded),
                text: isArabic ? 'أوامر التسجيل' : 'Commands',
              ),
              Tab(
                icon: const Icon(Icons.help_outline_rounded),
                text: isArabic ? 'الأسئلة والاستفسارات' : 'Questions',
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            // Safe limits info banner (VOICE.md Section 2.8)
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.privacy_tip_outlined, color: colorScheme.primary, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isArabic
                          ? 'المساعد ينفذ أمرًا واحدًا في كل جملة، ويعمل محليًا على هاتفك لحماية خصوصيتك. حمايةً لملفاتك لا يقوم المساعد بحذف أي بيانات إطلاقًا.'
                          : 'The assistant processes one command per sentence and runs 100% on-device. For data protection, it cannot delete any items.',
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
                    ),
                  ),
                ],
              ),
            ),

            // Tab Views
            Expanded(
              child: TabBarView(
                children: [
                  _CommandsTabView(isArabic: isArabic),
                  _QuestionsTabView(isArabic: isArabic),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommandsTabView extends StatelessWidget {
  final bool isArabic;
  const _CommandsTabView({required this.isArabic});

  @override
  Widget build(BuildContext context) {
    final sections = [
      _HelpCategory(
        icon: Icons.task_alt_rounded,
        color: Colors.blue,
        title: isArabic ? 'المهام (Tasks)' : 'Tasks',
        examples: isArabic
            ? [
                'سجّل بكرة أكلم العميل الساعة 5',
                'أنا عايز بكرة أعمل مونتاج الإعلان',
                'يوم الخميس هقابل الدكتور',
                'ضيف مهمة أراجع الفاتورة',
              ]
            : [
                'Register tomorrow call client at 5 PM',
                'Add task review invoice on Thursday',
              ],
      ),
      _HelpCategory(
        icon: Icons.directions_walk_rounded,
        color: Colors.indigo,
        title: isArabic ? 'المشاوير (Errands)' : 'Errands',
        examples: isArabic
            ? [
                'سجّل مشوار بكرة أجيب البنزين',
                'مشوار النهارده البنك الساعة 12',
                'مشوار أشتري طلبات من كارفور',
              ]
            : [
                'Record errand tomorrow get groceries',
                'Errand today bank at 12',
              ],
      ),
      _HelpCategory(
        icon: Icons.alarm_rounded,
        color: Colors.amber.shade900,
        title: isArabic ? 'التنبيهات والتذكيرات (Reminders)' : 'Reminders',
        examples: isArabic
            ? [
                'فكرني بكرة الساعة 9 أكلم أحمد',
                'نبهني بعد يومين أدفع الفاتورة',
                'فكرني الجمعة العصر أزور أهلي',
              ]
            : [
                'Remind me tomorrow at 9 AM to call Ahmed',
                'Alert me in 2 days to pay the bill',
              ],
      ),
      _HelpCategory(
        icon: Icons.update_rounded,
        color: Colors.teal,
        title: isArabic ? 'تحديث الحالة والإنجاز (Status Updates)' : 'Status Updates',
        examples: isArabic
            ? [
                'خلصت مهمة التقرير',
                'ابتديت المونتاج',
                'أجّل مهمة التقرير لبكرة لأن مفيش فلوس',
                'مستنية رد الدكتور مهمة العميل',
                'وقفت مهمة الإعلان بسبب الميزانية',
                'عملت نص مهمة التصميم لأني تعبت',
              ]
            : [
                'Finished report task',
                'Started editing video',
                'Postponed report to tomorrow because no budget',
              ],
      ),
      _HelpCategory(
        icon: Icons.shopping_bag_outlined,
        color: Colors.orange,
        title: isArabic ? 'تسجيل المصاريف (Expenses)' : 'Expenses',
        examples: isArabic
            ? [
                'سجّل شاي بعشرة جنيه',
                'صرفت 50 على أكل بره',
                'دفعت 300 فاتورة النت امبارح',
                'بنزين 200 جنيه',
              ]
            : [
                'Log 50 on restaurant food',
                'Paid 300 internet bill yesterday',
              ],
      ),
      _HelpCategory(
        icon: Icons.payments_rounded,
        color: Colors.green,
        title: isArabic ? 'تسجيل الدخل (Income)' : 'Income',
        examples: isArabic
            ? [
                'دخل 5000 من عميل',
                'قبضت مرتب 8000',
              ]
            : [
                'Income 5000 from client',
                'Received salary 8000',
              ],
      ),
      _HelpCategory(
        icon: Icons.repeat_rounded,
        color: Colors.purple,
        title: isArabic ? 'العادات اليومية (Habits)' : 'Habits',
        examples: isArabic
            ? [
                'شربت قهوة',
                'كوبايتين قهوة',
                'صليت الفجر',
                'قريت 5 صفحات قرآن',
                'عملت أذكار الصباح',
              ]
            : [
                'Drank coffee',
                'Read 5 pages Quran',
                'Did morning prayers',
              ],
      ),
      _HelpCategory(
        icon: Icons.edit_note_rounded,
        color: Colors.brown,
        title: isArabic ? 'الملاحظات والأفكار (Notes & Ideas)' : 'Notes & Ideas',
        examples: isArabic
            ? [
                'ملاحظة اللي بيذاكر بيتعلم الصبر',
                'سجّل حكمة...',
                'فكرة تطبيق للمشاوير',
                'سجّل فكرة منصة تعليمية',
                'سجّل ملاحظة صوتية',
              ]
            : [
                'Note patience is key',
                'Idea for errands app',
                'Record voice note',
              ],
      ),
      _HelpCategory(
        icon: Icons.card_giftcard_rounded,
        color: Colors.pink,
        title: isArabic ? 'المشتريات والصحة (Wishlist & Health)' : 'Wishlist & Health',
        examples: isArabic
            ? [
                'ضيف للمشتريات سماعة بألف وخمسمية',
                'عايز اشتري كاميرا',
                'فكرني أروح كشف الأسنان الخميس',
                'محتاج أعمل تحليل سكر',
              ]
            : [
                'Add headphones 1500 to wishlist',
                'Remind me to visit dentist on Thursday',
              ],
      ),
    ];

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: sections.length,
      itemBuilder: (context, index) => _CategoryCard(category: sections[index]),
    );
  }
}

class _QuestionsTabView extends StatelessWidget {
  final bool isArabic;
  const _QuestionsTabView({required this.isArabic});

  @override
  Widget build(BuildContext context) {
    final sections = [
      _HelpCategory(
        icon: Icons.calendar_today_rounded,
        color: Colors.blue,
        title: isArabic ? 'الأجندة والجدول (Agenda)' : 'Agenda',
        examples: isArabic
            ? [
                'ايه ورايا النهارده؟',
                'ايه ورايا بعد يومين؟',
                'ايه عندي يوم الخميس؟',
                'ايه ورايا الاسبوع ده؟',
              ]
            : [
                'What is on my schedule today?',
                'What do I have on Thursday?',
                'What is my agenda for this week?',
              ],
      ),
      _HelpCategory(
        icon: Icons.analytics_outlined,
        color: Colors.teal,
        title: isArabic ? 'ملخص الإنجاز (Recap)' : 'Recap',
        examples: isArabic
            ? [
                'عملت ايه امبارح؟',
                'عملت ايه الاسبوع اللي فات؟',
                'ايه اللي حصل يوم 12/9؟',
                'ملخص الشهر ده',
              ]
            : [
                'What did I accomplish yesterday?',
                'What did I do last week?',
                'Monthly recap',
              ],
      ),
      _HelpCategory(
        icon: Icons.account_balance_wallet_outlined,
        color: Colors.orange,
        title: isArabic ? 'استفسارات المصاريف (Spending)' : 'Spending',
        examples: isArabic
            ? [
                'صرفت كام على أكل بره الشهر ده؟',
                'اكتر حاجة بصرف عليها؟',
                'مصروف النهارده كام؟',
              ]
            : [
                'How much did I spend on food this month?',
                'What is my top expense category?',
                'How much did I spend today?',
              ],
      ),
      _HelpCategory(
        icon: Icons.repeat_rounded,
        color: Colors.purple,
        title: isArabic ? 'متابعة العادات (Habits Status)' : 'Habits Status',
        examples: isArabic
            ? [
                'شربت كام قهوة النهارده؟',
                'صليت ايه النهارده؟',
                'التزامي بالقرآن الاسبوع ده؟',
              ]
            : [
                'How many coffees did I drink today?',
                'What prayers did I complete today?',
              ],
      ),
      _HelpCategory(
        icon: Icons.hourglass_top_rounded,
        color: Colors.deepOrange,
        title: isArabic ? 'المتأخر والمعلق (Pending Items)' : 'Pending Items',
        examples: isArabic
            ? [
                'ايه المتأخر عندي؟',
                'ايه المؤجل؟',
                'ايه اللي مستني؟',
              ]
            : [
                'What tasks are overdue?',
                'What is postponed?',
                'What is waiting?',
              ],
      ),
      _HelpCategory(
        icon: Icons.receipt_long_rounded,
        color: Colors.green,
        title: isArabic ? 'الالتزامات والأقساط (Obligations)' : 'Obligations',
        examples: isArabic
            ? [
                'ايه عليا الشهر ده؟',
                'ايه الالتزامات المتأخرة؟',
              ]
            : [
                'What obligations are due this month?',
                'What obligations are overdue?',
              ],
      ),
      _HelpCategory(
        icon: Icons.medical_services_outlined,
        color: Colors.red,
        title: isArabic ? 'المواعيد الطبية (Health Pending)' : 'Health Appointments',
        examples: isArabic
            ? [
                'ايه الكشوفات المؤجلة؟',
                'عندي مواعيد دكتور امتى؟',
              ]
            : [
                'What medical appointments are pending?',
              ],
      ),
      _HelpCategory(
        icon: Icons.shopping_cart_outlined,
        color: Colors.pink,
        title: isArabic ? 'قائمة المشتريات (Wishlist Totals)' : 'Wishlist Totals',
        examples: isArabic
            ? [
                'اجمالي المشتريات اللي عايزها كام؟',
              ]
            : [
                'What is the total cost of my wishlist?',
              ],
      ),
    ];

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: sections.length,
      itemBuilder: (context, index) => _CategoryCard(category: sections[index]),
    );
  }
}

class _HelpCategory {
  final IconData icon;
  final Color color;
  final String title;
  final List<String> examples;

  const _HelpCategory({
    required this.icon,
    required this.color,
    required this.title,
    required this.examples,
  });
}

class _CategoryCard extends StatelessWidget {
  final _HelpCategory category;
  const _CategoryCard({required this.category});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: category.color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(category.icon, color: category.color, size: 22),
        ),
        title: Text(
          category.title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: category.examples.map((example) {
          return InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              Clipboard.setData(ClipboardData(text: example));
              final l10n = AppLocalizations.of(context);
              final isAr = Localizations.localeOf(context).languageCode == 'ar';
              final prefix = l10n?.assistantCopiedExample ?? (isAr ? 'تم نسخ:' : 'Copied:');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$prefix "$example"'),
                  duration: const Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
              child: Row(
                children: [
                  Icon(Icons.format_quote_rounded, size: 16, color: category.color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      example,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.copy_rounded,
                    size: 16,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
