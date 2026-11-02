import 'package:flutter/widgets.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('ar'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('ar'),
    Locale('en'),
  ];

  static final Map<String, Map<String, String>> _localizedValues = {
    'ar': {
      'appName': 'إنجاز',
      'tabToday': 'اليوم',
      'tabGoals': 'الأهداف',
      'tabIdeas': 'الأفكار',
      'tabStats': 'الإحصائيات',
      'history': 'السجل',
      'settings': 'الإعدادات',
      'language': 'اللغة',
      'languageArabic': 'العربية',
      'languageEnglish': 'English',
      'theme': 'المظهر',
      'themeLight': 'فاتح',
      'themeDark': 'داكن',
      'themeSystem': 'حسب النظام',
      'numerals': 'الأرقام',
      'numeralsWestern': 'إنجليزية (123)',
      'numeralsArabic': 'مشرقية (١٢٣)',
      'emptyTodayTitle': 'مفيش حاجة مخططة النهارده',
      'emptyTodaySubtitle': 'ابدأ يومك بإضافة أول مهمة أو مشوار',
      'addTask': 'أضف مهمة',
      'noDateInbox': 'بدون تاريخ',
      'goalsActive': 'نشطة',
      'goalsPaused': 'متوقفة',
      'goalsDone': 'مكتملة',
      'emptyGoalsTitle': 'مفيش أهداف مسجلة حالياً',
      'addGoal': 'أضف هدف',
      'ideasNew': 'جديدة',
      'ideasExploring': 'بتتدرس',
      'ideasConverted': 'اتحولت',
      'ideasArchived': 'مؤرشفة',
      'emptyIdeasTitle': 'مفيش أفكار مسجلة',
      'addIdea': 'أضف فكرة',
      'statsWeek': 'أسبوع',
      'statsMonth': 'شهر',
      'statsYear': 'سنة',
      'emptyStatsTitle': 'مفيش بيانات كافية للفترة دي',
      'version': 'الإصدار',
      'loading': 'جارٍ التحميل...',
      'about': 'عن إنجاز',
      'aboutDescription': 'تطبيقك الشخصي لإدارة المهام والأهداف الحياتية أوفلاين بالكامل وبدون أي تعقيد.',
    },
    'en': {
      'appName': 'Enjaz',
      'tabToday': 'Today',
      'tabGoals': 'Goals',
      'tabIdeas': 'Ideas',
      'tabStats': 'Stats',
      'history': 'History',
      'settings': 'Settings',
      'language': 'Language',
      'languageArabic': 'Arabic',
      'languageEnglish': 'English',
      'theme': 'Theme',
      'themeLight': 'Light',
      'themeDark': 'Dark',
      'themeSystem': 'System default',
      'numerals': 'Numerals',
      'numeralsWestern': 'Western (123)',
      'numeralsArabic': 'Arabic-Indic (١٢٣)',
      'emptyTodayTitle': 'Nothing planned today',
      'emptyTodaySubtitle': 'Start your day by adding your first task or errand',
      'addTask': 'Add task',
      'noDateInbox': 'No date',
      'goalsActive': 'Active',
      'goalsPaused': 'Paused',
      'goalsDone': 'Done',
      'emptyGoalsTitle': 'No goals recorded yet',
      'addGoal': 'Add goal',
      'ideasNew': 'New',
      'ideasExploring': 'Exploring',
      'ideasConverted': 'Converted',
      'ideasArchived': 'Archived',
      'emptyIdeasTitle': 'No ideas recorded',
      'addIdea': 'Add idea',
      'statsWeek': 'Week',
      'statsMonth': 'Month',
      'statsYear': 'Year',
      'emptyStatsTitle': 'Not enough data for this period',
      'version': 'Version',
      'loading': 'Loading...',
      'about': 'About Enjaz',
      'aboutDescription': 'Your personal, fully offline task and goal tracker designed for honesty and progress.',
    },
  };

  String _t(String key) {
    final lang = locale.languageCode;
    return _localizedValues[lang]?[key] ??
        _localizedValues['en']?[key] ??
        key;
  }

  String get appName => _t('appName');
  String get tabToday => _t('tabToday');
  String get tabGoals => _t('tabGoals');
  String get tabIdeas => _t('tabIdeas');
  String get tabStats => _t('tabStats');
  String get history => _t('history');
  String get settings => _t('settings');
  String get language => _t('language');
  String get languageArabic => _t('languageArabic');
  String get languageEnglish => _t('languageEnglish');
  String get theme => _t('theme');
  String get themeLight => _t('themeLight');
  String get themeDark => _t('themeDark');
  String get themeSystem => _t('themeSystem');
  String get numerals => _t('numerals');
  String get numeralsWestern => _t('numeralsWestern');
  String get numeralsArabic => _t('numeralsArabic');
  String get emptyTodayTitle => _t('emptyTodayTitle');
  String get emptyTodaySubtitle => _t('emptyTodaySubtitle');
  String get addTask => _t('addTask');
  String get noDateInbox => _t('noDateInbox');
  String get goalsActive => _t('goalsActive');
  String get goalsPaused => _t('goalsPaused');
  String get goalsDone => _t('goalsDone');
  String get emptyGoalsTitle => _t('emptyGoalsTitle');
  String get addGoal => _t('addGoal');
  String get ideasNew => _t('ideasNew');
  String get ideasExploring => _t('ideasExploring');
  String get ideasConverted => _t('ideasConverted');
  String get ideasArchived => _t('ideasArchived');
  String get emptyIdeasTitle => _t('emptyIdeasTitle');
  String get addIdea => _t('addIdea');
  String get statsWeek => _t('statsWeek');
  String get statsMonth => _t('statsMonth');
  String get statsYear => _t('statsYear');
  String get emptyStatsTitle => _t('emptyStatsTitle');
  String get version => _t('version');
  String get loading => _t('loading');
  String get about => _t('about');
  String get aboutDescription => _t('aboutDescription');
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['ar', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
