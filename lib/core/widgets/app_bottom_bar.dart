import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// AppBottomBarItem definition for AppBottomBar
class AppBottomBarItem {
  final IconData icon;
  final IconData? activeIcon;
  final String label;

  const AppBottomBarItem({
    required this.icon,
    this.activeIcon,
    required this.label,
  });
}

/// AppBottomBar (UI.md Section 3, 5 & Section 9)
/// 4-tab bottom navigation bar featuring a centered '+' action button.
/// Follows calm and minimal design with 1px top border and no shadows.
class AppBottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onAddPressed;
  final List<AppBottomBarItem>? customItems;

  const AppBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
    required this.onAddPressed,
    this.customItems,
  });

  static const List<AppBottomBarItem> defaultItems = [
    AppBottomBarItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'الرئيسية',
    ),
    AppBottomBarItem(
      icon: Icons.event_note_outlined,
      activeIcon: Icons.event_note_rounded,
      label: 'التخطيط',
    ),
    AppBottomBarItem(
      icon: Icons.bar_chart_outlined,
      activeIcon: Icons.bar_chart_rounded,
      label: 'الإحصائيات',
    ),
    AppBottomBarItem(
      icon: Icons.more_horiz_rounded,
      activeIcon: Icons.more_horiz_rounded,
      label: 'المزيد',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final items = customItems ?? defaultItems;

    // Items are split into 2 left and 2 right around the center button
    final firstHalf = items.sublist(0, items.length ~/ 2);
    final secondHalf = items.sublist(items.length ~/ 2);

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(
            color: colors.border,
            width: 1.0,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64.0,
          child: Row(
            children: [
              // Left tabs (الرئيسية, التخطيط)
              for (int i = 0; i < firstHalf.length; i++)
                Expanded(
                  child: _buildTab(
                    context,
                    item: firstHalf[i],
                    index: i,
                    isSelected: currentIndex == i,
                  ),
                ),

              // Center '+' Add Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: SizedBox(
                  width: 48.0,
                  height: 48.0,
                  child: Material(
                    color: colors.accent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onAddPressed,
                      child: const Center(
                        child: Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                          size: 28.0,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Right tabs (الإحصائيات, المزيد)
              for (int i = 0; i < secondHalf.length; i++)
                Expanded(
                  child: _buildTab(
                    context,
                    item: secondHalf[i],
                    index: firstHalf.length + i,
                    isSelected: currentIndex == (firstHalf.length + i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTab(
    BuildContext context, {
    required AppBottomBarItem item,
    required int index,
    required bool isSelected,
  }) {
    final colors = AppColors.of(context);
    final iconColor = isSelected ? colors.accent : colors.textSecondary;
    final iconData = (isSelected && item.activeIcon != null) ? item.activeIcon! : item.icon;

    return InkWell(
      onTap: () => onTabSelected(index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            iconData,
            size: 22.0,
            color: iconColor,
          ),
          const SizedBox(height: 3.0),
          Text(
            item.label,
            style: AppTypography.caption(
              context,
              color: iconColor,
            ).copyWith(
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              fontSize: 12.0, // Minimum 12px per UI.md Section 3
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
