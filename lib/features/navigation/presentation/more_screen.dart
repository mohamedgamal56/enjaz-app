import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../assistant/presentation/assistant_settings_screen.dart';
import '../../assistant/presentation/assistant_sheet.dart';
import '../../backup/presentation/backup_screen.dart';
import '../../excel_export/presentation/excel_export_sheet.dart';
import '../../finance/presentation/finance_screen.dart';
import '../../habits/presentation/habits_screen.dart';
import '../../health/presentation/health_screen.dart';
import '../../history/presentation/history_screen.dart';
import '../../home/domain/home_settings_provider.dart';
import '../../plan/presentation/plan_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../settings/presentation/trash_screen.dart';
import '../../today/presentation/today_screen.dart';

/// MoreScreen (UI.md Section 5 & Section 9)
/// Clean utility screen containing settings, backups, Excel export, history, trash.
/// Modules whose Home card is hidden appear dynamically here so they are never lost.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final homeSettings = ref.watch(homeSettingsProvider);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      children: [
        // Voice Assistant quick row
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
          leading: const Icon(Icons.mic_rounded),
          title: Text(l10n.assistantRecordByVoice),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
          onTap: () => AssistantSheet.show(context),
        ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
          leading: const Icon(Icons.settings_voice_rounded),
          title: Text(l10n.assistantSettingsAndHelp),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AssistantSettingsScreen()),
          ),
        ),
        const Divider(height: 16),

        // Dynamic modules: shown here ONLY if their card is hidden on Home (UI.md Section 5)
        if (!homeSettings.isCardVisible('today')) ...[
          _buildMenuCard(
            context,
            icon: Icons.today_rounded,
            iconColor: Colors.blueAccent,
            title: isArabic ? 'المهام (النهاردة)' : 'Tasks (Today)',
            subtitle: isArabic ? 'عرض وإدارة مهام اليوم وقوائم المهام' : 'View and manage today tasks',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TodayScreen()),
            ),
          ),
          const SizedBox(height: 10),
        ],

        if (!homeSettings.isCardVisible('habits')) ...[
          _buildMenuCard(
            context,
            icon: Icons.repeat_rounded,
            iconColor: Colors.teal,
            title: isArabic ? 'العادات اليومية' : 'Habits',
            subtitle: isArabic ? 'متابعة العادات والروتين اليومي' : 'Track daily habits and routine',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HabitsScreen()),
            ),
          ),
          const SizedBox(height: 10),
        ],

        if (!homeSettings.isCardVisible('finance')) ...[
          _buildMenuCard(
            context,
            icon: Icons.account_balance_wallet_rounded,
            iconColor: Colors.green,
            title: isArabic ? 'المال والمصروفات' : 'Finance',
            subtitle: isArabic ? 'المصروفات، الدخل، والميزانية' : 'Expenses, income, and budgets',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FinanceScreen()),
            ),
          ),
          const SizedBox(height: 10),
        ],

        if (!homeSettings.isCardVisible('health')) ...[
          _buildMenuCard(
            context,
            icon: Icons.favorite_rounded,
            iconColor: Colors.redAccent,
            title: isArabic ? 'الصحة والعلاج' : 'Health & Treatments',
            subtitle: isArabic ? 'المواعيد الطبية ومتابعة العلاج' : 'Medical appointments and health tracking',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HealthScreen()),
            ),
          ),
          const SizedBox(height: 10),
        ],

        if (!homeSettings.isCardVisible('goals_ideas')) ...[
          _buildMenuCard(
            context,
            icon: Icons.track_changes_rounded,
            iconColor: Colors.amber,
            title: isArabic ? 'الأهداف والأفكار' : 'Goals & Ideas',
            subtitle: isArabic ? 'إدارة الأهداف، الأفكار، والملاحظات' : 'Manage goals, ideas, and notes',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PlanScreen()),
            ),
          ),
          const SizedBox(height: 10),
        ],

        // 1. Settings (الإعدادات)
        _buildMenuCard(
          context,
          icon: Icons.settings_outlined,
          iconColor: Colors.purple,
          title: isArabic ? 'الإعدادات' : l10n.settings,
          subtitle: isArabic ? 'الملف الشخصي، الرئيسية، التنبيهات، والمظهر' : 'Profile, Home, Reminders & Theme',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          },
        ),
        const SizedBox(height: 10),

        // 2. Backup & Security (النسخ الاحتياطي والأمان)
        _buildMenuCard(
          context,
          icon: Icons.shield_outlined,
          iconColor: Colors.teal,
          title: isArabic ? 'النسخ الاحتياطي والأمان' : l10n.backupAndSecurity,
          subtitle: isArabic ? 'تصدير نسخة مشفرة واستيراد البيانات' : 'Encrypted backups and data import',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BackupScreen()),
            );
          },
        ),
        const SizedBox(height: 10),

        // 3. Excel Export (تقرير إكسيل)
        _buildMenuCard(
          context,
          icon: Icons.table_chart_rounded,
          iconColor: Colors.teal.shade700,
          title: isArabic ? 'تقرير إكسيل' : 'Excel Report',
          subtitle: isArabic ? 'تصدير تقرير شامل لكافة الأقسام والمهام' : 'Export detailed spreadsheet report',
          onTap: () => ExcelExportSheet.show(context),
        ),
        const SizedBox(height: 10),

        // 4. History (السجل)
        _buildMenuCard(
          context,
          icon: Icons.history_rounded,
          iconColor: Colors.blue,
          title: isArabic ? 'السجل' : l10n.history,
          subtitle: isArabic ? 'استعراض تاريخ إنجاز وتعديل المهام' : 'Log of completed and modified tasks',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HistoryScreen()),
            );
          },
        ),
        const SizedBox(height: 10),

        // 5. Trash (سلة المحذوفات)
        _buildMenuCard(
          context,
          icon: Icons.delete_outline_rounded,
          iconColor: Colors.deepOrange,
          title: isArabic ? 'سلة المحذوفات' : l10n.trash,
          subtitle: isArabic ? 'استرجاع العناصر المحذوفة أو حذفها نهائياً' : 'Restore or permanently delete items',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TrashScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: iconColor.withValues(alpha: 0.12),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.of(context).textSecondary)),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
        onTap: onTap,
      ),
    );
  }
}
