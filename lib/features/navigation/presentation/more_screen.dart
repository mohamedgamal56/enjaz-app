import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../history/presentation/history_screen.dart';
import '../../settings/presentation/trash_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../backup/presentation/backup_screen.dart';
import '../../habits/presentation/habits_screen.dart';
import '../../finance/presentation/finance_screen.dart';
import '../../health/presentation/health_screen.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      children: [
        // App header banner
        Card(
          elevation: 0,
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: theme.colorScheme.primary,
                  child: const Icon(Icons.check_rounded, color: Colors.white, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.appName,
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isArabic
                            ? 'إدارة المهام والأهداف والملاحظات أوفلاين'
                            : 'Tasks, Goals & Notes fully offline',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 1. Finance (Roadmap v2.0 Round 5)
        _buildMenuCard(
          context,
          icon: Icons.account_balance_wallet_rounded,
          iconColor: Colors.green,
          title: isArabic ? 'المال والمصروفات' : 'Finance',
          subtitle: isArabic ? 'المصروفات، الدخل، الأقساط، والمشتريات وتحليل الادخار' : 'Expenses, income, obligations, wishlist & savings',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FinanceScreen()),
            );
          },
        ),
        const SizedBox(height: 10),

        // 2. Habits (Roadmap v2.0 Round 4)
        _buildMenuCard(
          context,
          icon: Icons.repeat_rounded,
          iconColor: Colors.teal,
          title: isArabic ? 'العادات اليومية' : 'Habits',
          subtitle: isArabic ? 'متابعة العادات، الصلوات، القراءة، والروتين اليومي' : 'Track daily habits, prayers, reading & routine',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HabitsScreen()),
            );
          },
        ),
        const SizedBox(height: 10),

        // 3. Health (Roadmap v2.0 Round 6)
        _buildMenuCard(
          context,
          icon: Icons.favorite_rounded,
          iconColor: Colors.redAccent,
          title: isArabic ? 'الصحة والعلاج' : 'Health & Treatments',
          subtitle: isArabic ? 'الفحوصات، التحاليل، مواعيد الكشوفات، ومتابعة الأدوية' : 'Checkups, lab tests, appointments & medication tracking',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HealthScreen()),
            );
          },
        ),
        const SizedBox(height: 10),

        // 2. History
        _buildMenuCard(
          context,
          icon: Icons.history_rounded,
          iconColor: Colors.blue,
          title: isArabic ? 'السجل الزمني للمهام' : l10n.history,
          subtitle: isArabic ? 'استعراض تاريخ إنجاز وتعديل المهام السابقة' : 'Log of completed and modified tasks',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HistoryScreen()),
            );
          },
        ),
        const SizedBox(height: 10),

        // 2. Trash
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
        const SizedBox(height: 10),

        // 3. Backup & Security
        _buildMenuCard(
          context,
          icon: Icons.shield_outlined,
          iconColor: Colors.teal,
          title: isArabic ? 'النسخ الاحتياطي والأمان' : l10n.backupAndSecurity,
          subtitle: isArabic ? 'تصدير نسخة مشفرة AES-256 واستيراد البيانات' : 'Encrypted backups and data import',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BackupScreen()),
            );
          },
        ),
        const SizedBox(height: 10),

        // 4. Settings
        _buildMenuCard(
          context,
          icon: Icons.settings_outlined,
          iconColor: Colors.purple,
          title: isArabic ? 'الإعدادات العامة' : l10n.settings,
          subtitle: isArabic ? 'التنبيهات، المظهر، قفل التطبيق، والأرقام' : 'Reminders, Theme, App Lock & Numerals',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
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
    final theme = Theme.of(context);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: iconColor.withValues(alpha: 0.12),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: theme.colorScheme.outline)),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
        onTap: onTap,
      ),
    );
  }
}
