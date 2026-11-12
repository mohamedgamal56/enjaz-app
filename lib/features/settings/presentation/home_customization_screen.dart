import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../home/domain/home_settings_provider.dart';

/// HomeCustomizationScreen (UI.md Section 7 & Section 9)
/// Allows user to reorder cards, toggle visibility, and configure health privacy.
class HomeCustomizationScreen extends ConsumerWidget {
  const HomeCustomizationScreen({super.key});

  static String getCardTitle(String id, bool isArabic) {
    switch (id) {
      case 'today':
        return isArabic ? 'النهاردة (المهام)' : 'Today (Tasks)';
      case 'habits':
        return isArabic ? 'العادات اليومية' : 'Habits';
      case 'finance':
        return isArabic ? 'المال والمصروفات' : 'Finance';
      case 'health':
        return isArabic ? 'الصحة والعلاج' : 'Health';
      case 'goals_ideas':
        return isArabic ? 'الأهداف والأفكار' : 'Goals & Ideas';
      default:
        return id;
    }
  }

  static IconData getCardIcon(String id) {
    switch (id) {
      case 'today':
        return Icons.today_rounded;
      case 'habits':
        return Icons.repeat_rounded;
      case 'finance':
        return Icons.account_balance_wallet_rounded;
      case 'health':
        return Icons.favorite_rounded;
      case 'goals_ideas':
        return Icons.track_changes_rounded;
      default:
        return Icons.dashboard_rounded;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final homeSettings = ref.watch(homeSettingsProvider);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final order = List<String>.from(homeSettings.cardOrder);

    return Scaffold(
      appBar: AppBar(
        title: Text(isArabic ? 'تخصيص الرئيسية' : 'Home Customization'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        children: [
          // Section: Privacy
          Card(
            child: SwitchListTile(
              secondary: Icon(Icons.privacy_tip_outlined, color: colors.accent),
              title: Text(
                isArabic ? 'إخفاء تفاصيل الصحة في الرئيسية' : 'Hide health details on Home',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              subtitle: Text(
                isArabic
                    ? 'عرض "موعد قادم" فقط لحماية الخصوصية'
                    : 'Show only "Upcoming appointment" without title',
                style: TextStyle(fontSize: 12, color: colors.textSecondary),
              ),
              value: homeSettings.hideHealthDetails,
              onChanged: (val) {
                ref.read(homeSettingsProvider.notifier).setHideHealthDetails(val);
              },
            ),
          ),
          const SizedBox(height: 16.0),

          // Section: Cards ordering and visibility
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
            child: Text(
              isArabic
                  ? 'ترتيب وإظهار البطاقات (اسحب لإعادة الترتيب)'
                  : 'Cards order & visibility (drag to reorder)',
              style: AppTypography.caption(context, color: colors.textSecondary).copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8.0),

          Card(
            child: ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: order.length,
              onReorder: (oldIndex, newIndex) {
                if (newIndex > oldIndex) newIndex -= 1;
                final item = order.removeAt(oldIndex);
                order.insert(newIndex, item);
                ref.read(homeSettingsProvider.notifier).setCardOrder(order);
              },
              itemBuilder: (context, index) {
                final cardId = order[index];
                final isVisible = homeSettings.isCardVisible(cardId);

                return ListTile(
                  key: ValueKey(cardId),
                  leading: ReorderableDragStartListener(
                    index: index,
                    child: Icon(Icons.drag_indicator_rounded, color: colors.textSecondary),
                  ),
                  title: Row(
                    children: [
                      Icon(getCardIcon(cardId), size: 18, color: colors.accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          getCardTitle(cardId, isArabic),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isVisible ? colors.text : colors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  trailing: Switch(
                    value: isVisible,
                    onChanged: (val) {
                      ref.read(homeSettingsProvider.notifier).setCardVisibility(cardId, val);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
