import 'package:flutter/material.dart';

class HabitIconHelper {
  HabitIconHelper._();

  static const Map<String, IconData> icons = {
    'local_cafe_rounded': Icons.local_cafe_rounded,
    'coffee': Icons.local_cafe_rounded,
    'mosque_rounded': Icons.mosque_rounded,
    'mosque': Icons.mosque_rounded,
    'menu_book_rounded': Icons.menu_book_rounded,
    'book': Icons.menu_book_rounded,
    'auto_awesome_rounded': Icons.auto_awesome_rounded,
    'adhkar': Icons.auto_awesome_rounded,
    'water_drop_rounded': Icons.water_drop_rounded,
    'water': Icons.water_drop_rounded,
    'fitness_center_rounded': Icons.fitness_center_rounded,
    'fitness': Icons.fitness_center_rounded,
    'directions_run_rounded': Icons.directions_run_rounded,
    'sports_gymnastics_rounded': Icons.sports_gymnastics_rounded,
    'self_improvement_rounded': Icons.self_improvement_rounded,
    'bedtime_rounded': Icons.bedtime_rounded,
    'alarm_rounded': Icons.alarm_rounded,
    'eco_rounded': Icons.eco_rounded,
    'favorite_rounded': Icons.favorite_rounded,
    'check_circle_rounded': Icons.check_circle_rounded,
    'star_rounded': Icons.star_rounded,
    'work_rounded': Icons.work_rounded,
    'school_rounded': Icons.school_rounded,
  };

  static IconData getIcon(String? iconKey) {
    if (iconKey == null) return Icons.check_circle_outline_rounded;
    return icons[iconKey] ?? Icons.check_circle_outline_rounded;
  }
}
