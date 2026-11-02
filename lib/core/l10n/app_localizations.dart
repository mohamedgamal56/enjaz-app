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

      'task': 'مهمة',
      'errand': 'مشوار',
      'goal': 'هدف',
      'idea': 'فكرة',
      'quickAddTitle': 'إضافة سريعة',
      'taskTitleHint': 'عنوان المهمة أو المشوار...',
      'notesHint': 'ملاحظات وتفاصيل إضافية...',
      'dateToday': 'اليوم',
      'dateTomorrow': 'بكرة',
      'datePick': 'اختر تاريخ',
      'dateNoDate': 'بدون تاريخ',
      'timeOptional': 'الوقت (اختياري)',
      'locationHint': 'المكان أو العنوان...',
      'priorityLabel': 'الأولوية',
      'priorityLow': 'منخفضة',
      'priorityNormal': 'عادية',
      'priorityHigh': 'عالية',
      'save': 'حفظ',
      'saveAndAddAnother': 'حفظ وإضافة آخر',
      'taskAddedSuccess': 'تمت إضافة المهمة بنجاح',

      'statusTodo': 'لسه',
      'statusInProgress': 'جارية',
      'statusPartial': 'اتعمل جزء منها',
      'statusDone': 'تمت',
      'statusPostponed': 'مؤجلة',
      'statusWaiting': 'منتظرة',
      'statusStopped': 'متوقفة',

      'changeStatusTitle': 'تغيير الحالة',
      'selectReason': 'اختر السبب',
      'reasonOther': 'سبب آخر',
      'specifyReasonHint': 'اكتب السبب هنا...',
      'progressLabel': 'نسبة الإنجاز',
      'postponeUntilLabel': 'تأجيل حتى تاريخ',
      'confirm': 'تأكيد',
      'cancel': 'إلغاء',
      'undo': 'تراجع',
      'addNote': 'إضافة ملاحظة',
      'taskCompleted': 'تم إنجاز المهمة! 🎉',
      'statusUpdated': 'تم تحديث الحالة بنجاح',

      'sectionOverdue': 'متأخرة',
      'sectionTasks': 'مهام اليوم',
      'sectionErrands': 'مشاوير اليوم',
      'sectionPostponedDue': 'مؤجلة وحان موعدها',
      'sectionWaitingAndPostponed': 'منتظرة ومؤجلة',
      'sectionDoneToday': 'تمت اليوم',
      'moveToToday': 'نقل لليوم',

      'taskDetailsTitle': 'تفاصيل المهمة',
      'timeline': 'الخط الزمني',
      'created': 'تم الإنشاء',
      'started': 'بدأت في',
      'finished': 'انتهت في',
      'duration': 'المدة المستغرقة',
      'outcomeNoteLabel': 'إزاي خلصت؟',
      'outcomeNoteHint': 'سجل كلمة أو ملاحظة عن النتيجة...',
      'historyLog': 'سجل النشاط والتغييرات',
      'deleteTask': 'حذف المهمة',
      'deleteTaskConfirm': 'هل أنت متأكد من حذف هذه المهمة؟',
      'taskDeleted': 'تم نقل المهمة لسلة المحذوفات',
      'minute': 'دقيقة',
      'hour': 'ساعة',
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
      'aboutDescription': 'Your personal offline productivity and life-tracking companion.',

      'task': 'Task',
      'errand': 'Errand',
      'goal': 'Goal',
      'idea': 'Idea',
      'quickAddTitle': 'Quick Add',
      'taskTitleHint': 'Task or errand title...',
      'notesHint': 'Notes & additional details...',
      'dateToday': 'Today',
      'dateTomorrow': 'Tomorrow',
      'datePick': 'Pick date',
      'dateNoDate': 'No date',
      'timeOptional': 'Time (optional)',
      'locationHint': 'Location / address...',
      'priorityLabel': 'Priority',
      'priorityLow': 'Low',
      'priorityNormal': 'Normal',
      'priorityHigh': 'High',
      'save': 'Save',
      'saveAndAddAnother': 'Save & add another',
      'taskAddedSuccess': 'Task added successfully',

      'statusTodo': 'To do',
      'statusInProgress': 'In progress',
      'statusPartial': 'Partially done',
      'statusDone': 'Done',
      'statusPostponed': 'Postponed',
      'statusWaiting': 'Waiting',
      'statusStopped': 'Stopped',

      'changeStatusTitle': 'Change Status',
      'selectReason': 'Select Reason',
      'reasonOther': 'Other reason',
      'specifyReasonHint': 'Type reason here...',
      'progressLabel': 'Progress',
      'postponeUntilLabel': 'Postpone until',
      'confirm': 'Confirm',
      'cancel': 'Cancel',
      'undo': 'Undo',
      'addNote': 'Add note',
      'taskCompleted': 'Task completed! 🎉',
      'statusUpdated': 'Status updated successfully',

      'sectionOverdue': 'Overdue',
      'sectionTasks': "Today's Tasks",
      'sectionErrands': "Today's Errands",
      'sectionPostponedDue': 'Postponed & Due Now',
      'sectionWaitingAndPostponed': 'Waiting & Postponed',
      'sectionDoneToday': 'Done Today',
      'moveToToday': 'Move to today',

      'taskDetailsTitle': 'Task Details',
      'timeline': 'Timeline',
      'created': 'Created',
      'started': 'Started',
      'finished': 'Finished',
      'duration': 'Duration',
      'outcomeNoteLabel': 'How did it end?',
      'outcomeNoteHint': 'Write a note about the outcome...',
      'historyLog': 'Activity & History Log',
      'deleteTask': 'Delete task',
      'deleteTaskConfirm': 'Are you sure you want to delete this task?',
      'taskDeleted': 'Task moved to trash',
      'minute': 'min',
      'hour': 'hr',
    },
  };

  String _get(String key) {
    final lang = locale.languageCode;
    return _localizedValues[lang]?[key] ?? _localizedValues['ar']?[key] ?? key;
  }

  String get appName => _get('appName');
  String get tabToday => _get('tabToday');
  String get tabGoals => _get('tabGoals');
  String get tabIdeas => _get('tabIdeas');
  String get tabStats => _get('tabStats');
  String get history => _get('history');
  String get settings => _get('settings');
  String get language => _get('language');
  String get languageArabic => _get('languageArabic');
  String get languageEnglish => _get('languageEnglish');
  String get theme => _get('theme');
  String get themeLight => _get('themeLight');
  String get themeDark => _get('themeDark');
  String get themeSystem => _get('themeSystem');
  String get numerals => _get('numerals');
  String get numeralsWestern => _get('numeralsWestern');
  String get numeralsArabic => _get('numeralsArabic');
  String get emptyTodayTitle => _get('emptyTodayTitle');
  String get emptyTodaySubtitle => _get('emptyTodaySubtitle');
  String get addTask => _get('addTask');
  String get noDateInbox => _get('noDateInbox');
  String get goalsActive => _get('goalsActive');
  String get goalsPaused => _get('goalsPaused');
  String get goalsDone => _get('goalsDone');
  String get emptyGoalsTitle => _get('emptyGoalsTitle');
  String get addGoal => _get('addGoal');
  String get ideasNew => _get('ideasNew');
  String get ideasExploring => _get('ideasExploring');
  String get ideasConverted => _get('ideasConverted');
  String get ideasArchived => _get('ideasArchived');
  String get emptyIdeasTitle => _get('emptyIdeasTitle');
  String get addIdea => _get('addIdea');
  String get statsWeek => _get('statsWeek');
  String get statsMonth => _get('statsMonth');
  String get statsYear => _get('statsYear');
  String get emptyStatsTitle => _get('emptyStatsTitle');
  String get version => _get('version');
  String get loading => _get('loading');
  String get about => _get('about');
  String get aboutDescription => _get('aboutDescription');

  String get task => _get('task');
  String get errand => _get('errand');
  String get goal => _get('goal');
  String get idea => _get('idea');
  String get quickAddTitle => _get('quickAddTitle');
  String get taskTitleHint => _get('taskTitleHint');
  String get notesHint => _get('notesHint');
  String get dateToday => _get('dateToday');
  String get dateTomorrow => _get('dateTomorrow');
  String get datePick => _get('datePick');
  String get dateNoDate => _get('dateNoDate');
  String get timeOptional => _get('timeOptional');
  String get locationHint => _get('locationHint');
  String get priorityLabel => _get('priorityLabel');
  String get priorityLow => _get('priorityLow');
  String get priorityNormal => _get('priorityNormal');
  String get priorityHigh => _get('priorityHigh');
  String get save => _get('save');
  String get saveAndAddAnother => _get('saveAndAddAnother');
  String get taskAddedSuccess => _get('taskAddedSuccess');

  String get statusTodo => _get('statusTodo');
  String get statusInProgress => _get('statusInProgress');
  String get statusPartial => _get('statusPartial');
  String get statusDone => _get('statusDone');
  String get statusPostponed => _get('statusPostponed');
  String get statusWaiting => _get('statusWaiting');
  String get statusStopped => _get('statusStopped');

  String get changeStatusTitle => _get('changeStatusTitle');
  String get selectReason => _get('selectReason');
  String get reasonOther => _get('reasonOther');
  String get specifyReasonHint => _get('specifyReasonHint');
  String get progressLabel => _get('progressLabel');
  String get postponeUntilLabel => _get('postponeUntilLabel');
  String get confirm => _get('confirm');
  String get cancel => _get('cancel');
  String get undo => _get('undo');
  String get addNote => _get('addNote');
  String get taskCompleted => _get('taskCompleted');
  String get statusUpdated => _get('statusUpdated');

  String get sectionOverdue => _get('sectionOverdue');
  String get sectionTasks => _get('sectionTasks');
  String get sectionErrands => _get('sectionErrands');
  String get sectionPostponedDue => _get('sectionPostponedDue');
  String get sectionWaitingAndPostponed => _get('sectionWaitingAndPostponed');
  String get sectionDoneToday => _get('sectionDoneToday');
  String get moveToToday => _get('moveToToday');

  String get taskDetailsTitle => _get('taskDetailsTitle');
  String get timeline => _get('timeline');
  String get created => _get('created');
  String get started => _get('started');
  String get finished => _get('finished');
  String get duration => _get('duration');
  String get outcomeNoteLabel => _get('outcomeNoteLabel');
  String get outcomeNoteHint => _get('outcomeNoteHint');
  String get historyLog => _get('historyLog');
  String get deleteTask => _get('deleteTask');
  String get deleteTaskConfirm => _get('deleteTaskConfirm');
  String get taskDeleted => _get('taskDeleted');
  String get minute => _get('minute');
  String get hour => _get('hour');

  String getStatusLabel(String status) {
    switch (status) {
      case 'in_progress':
        return statusInProgress;
      case 'partial':
        return statusPartial;
      case 'done':
        return statusDone;
      case 'postponed':
        return statusPostponed;
      case 'waiting':
        return statusWaiting;
      case 'stopped':
        return statusStopped;
      case 'todo':
      default:
        return statusTodo;
    }
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['ar', 'en'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
