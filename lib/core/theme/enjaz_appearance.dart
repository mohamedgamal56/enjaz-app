import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stable names are stored on-device. The existing design stays the default.
enum EnjazAppearance {
  original('إنجاز الحالي', 'Current Enjaz', 'ترتيب إنجاز المعتاد',
      'The familiar Enjaz layout', Icons.home_outlined, 16),
  signature('هوية إنجاز', 'Enjaz Signature', 'تقدّم اليوم واختصارات الأقسام',
      'Daily progress and section shortcuts', Icons.dashboard_outlined, 22),
  classic('المفكرة الكلاسيكية', 'Classic Planner', 'مهام في سطور مثل المفكرة',
      'A ruled list of your day', Icons.menu_book_outlined, 6),
  rail('خط اليوم', 'Day Rail', 'أيام الأسبوع وجدول زمني واضح',
      'Week selector and a clean timeline', Icons.timeline, 14),
  nile('على النيل', 'Nile Agenda', 'جدول زمني مع أفق القاهرة',
      'A timeline with a Cairo skyline', Icons.landscape_outlined, 20),
  glass('زجاج إنجاز', 'Enjaz Glass', 'بطاقات متدرجة بحواف تركواز',
      'Teal-edged glass panels', Icons.layers_outlined, 24),
  studio('استوديو إنجاز', 'Enjaz Studio', 'تقدّم وإضافة سريعة في أول الشاشة',
      'Progress and quick capture up front', Icons.auto_awesome_outlined, 18),
  voice('دائرة الصوت', 'Voice Orbit', 'الميكروفون في قلب الشاشة',
      'The microphone at the center', Icons.mic_none, 28),
  aurora('وهج إنجاز', 'Enjaz Glow', 'بطاقات مرتبة مع وهج خفيف',
      'A dashboard with a soft teal glow', Icons.blur_on, 26),
  pulse('نبض اليوم', 'Daily Pulse', 'حلقة إنجاز وبطاقات ملخص',
      'A progress ring with summary cards', Icons.donut_large, 16),
  neonAgenda('جدول مضيء', 'Luminous Schedule', 'اختصارات الأقسام فوق مواعيدك',
      'Section shortcuts over the agenda', Icons.event_note_outlined, 16),
  brief('ملخص اليوم', 'Daily Brief', 'مهام وأرقام في لوحة مختصرة',
      'A compact view of tasks and numbers', Icons.view_quilt_outlined, 10),
  control(
      'مركز المتابعة',
      'Control Center',
      'بحث في المهام والأقسام وكروت مفصّلة',
      'Find sections in a detailed grid',
      Icons.grid_view,
      12),
  axis('محور الحياة', 'Life Hub', 'تبويبات تركز على قسم في كل مرة',
      'Focus on one section at a time', Icons.view_day_outlined, 18),
  matrix('شبكة إنجاز', 'Enjaz Matrix', 'بحث واختصارات سريعة مع كروت مضيئة',
      'Search and shortcuts with teal-edged cards', Icons.widgets_outlined, 14);

  const EnjazAppearance(this.ar, this.en, this.arDescription,
      this.enDescription, this.icon, this.radius);

  final String ar;
  final String en;
  final String arDescription;
  final String enDescription;
  final IconData icon;
  final double radius;

  String title(bool arabic) => arabic ? ar : en;
  String description(bool arabic) => arabic ? arDescription : enDescription;

  bool get hasGlow =>
      this == glass || this == aurora || this == matrix || this == neonAgenda;
}

final enjazAppearanceProvider =
    StateNotifierProvider<EnjazAppearanceNotifier, EnjazAppearance>((ref) {
  return EnjazAppearanceNotifier();
});

class EnjazAppearanceNotifier extends StateNotifier<EnjazAppearance> {
  EnjazAppearanceNotifier() : super(EnjazAppearance.original) {
    _ready = _restore();
  }

  static const _key = 'enjaz_appearance';
  late final Future<SharedPreferences> _ready;

  Future<SharedPreferences> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (mounted) {
      state = EnjazAppearance.values.firstWhere(
        (appearance) => appearance.name == saved,
        orElse: () => EnjazAppearance.original,
      );
    }
    return prefs;
  }

  Future<void> select(EnjazAppearance appearance) async {
    final prefs = await _ready;
    if (!await prefs.setString(_key, appearance.name)) {
      throw StateError('Could not save appearance');
    }
    if (mounted) state = appearance;
  }
}

@immutable
class EnjazAppearanceTheme extends ThemeExtension<EnjazAppearanceTheme> {
  const EnjazAppearanceTheme(this.appearance);
  final EnjazAppearance appearance;

  static EnjazAppearance of(BuildContext context) =>
      Theme.of(context).extension<EnjazAppearanceTheme>()?.appearance ??
      EnjazAppearance.original;

  static ThemeData apply(ThemeData theme, EnjazAppearance appearance) {
    if (appearance == EnjazAppearance.original) return theme;
    return theme.copyWith(
      extensions: [
        ...theme.extensions.values,
        EnjazAppearanceTheme(appearance)
      ],
      cardTheme: theme.cardTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(appearance.radius),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
    );
  }

  @override
  EnjazAppearanceTheme copyWith({EnjazAppearance? appearance}) =>
      EnjazAppearanceTheme(appearance ?? this.appearance);

  @override
  EnjazAppearanceTheme lerp(EnjazAppearanceTheme? other, double t) =>
      other != null && t >= .5 ? other : this;
}
