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
      'duplicateTask': 'تكرار المهمة',
      'deleteTask': 'حذف المهمة',
      'deleteTaskConfirm': 'هل أنت متأكد من حذف هذه المهمة؟',
      'taskDeleted': 'تم نقل المهمة لسلة المحذوفات',
      'minute': 'دقيقة',
      'hour': 'ساعة',

      'multiLinePasteTitle': 'تحويل الملاحظات لمهام',
      'multiLinePastePrompt': 'تم اكتشاف أسطر متعددة، تحويلها لمهام منفصلة؟',
      'importNotes': 'استيراد ملاحظات',
      'pasteNotesHint': 'الصق ملاحظاتك أو قائمتك هنا (كل سطر هيكون مهمة منفصلة)...',
      'convert': 'تحويل لمهام',
      'tasksCreatedSuccess': 'تم إنشاء المهام بنجاح',

      'historyTitle': 'سجل المهام',
      'searchHint': 'ابحث في المهام، الملاحظات، أو الأسباب...',
      'filterAll': 'الكل',
      'filterKind': 'النوع',
      'filterStatus': 'الحالة',
      'sortNewest': 'الأحدث أولاً',
      'sortOldest': 'الأقدم أولاً',
      'noHistoryFound': 'مفيش نتائج مطابقة للبحث',
      'clearFilters': 'إعادة ضبط الفلاتر',

      'reasonsManager': 'إدارة أسباب التأجيل',
      'addReason': 'إضافة سبب جديد',
      'editReason': 'تعديل السبب',
      'reasonLabelAr': 'نص السبب (عربي)',
      'reasonLabelEn': 'نص السبب (إنجليزي - اختياري)',
      'reasonCategory': 'التصنيف',
      'categoryPostpone': 'تأجيل',
      'categoryWaiting': 'انتظار',
      'categoryStopped': 'توقف',
      'categoryPartial': 'إنجاز جزئي',
      'categoryAny': 'عام / أي حالة',
      'archive': 'أرشفة',
      'archiveReasonConfirm': 'هل تريد أرشفة هذا السبب؟ لن يظهر في القوائم الجديدة ولكن سيبقى في السجلات القديمة.',
      'usageCountLabel': 'مرات الاستخدام',
      'reasonAddedSuccess': 'تمت إضافة السبب بنجاح',
      'reasonUpdatedSuccess': 'تم تعديل السبب بنجاح',
      'reasonArchivedSuccess': 'تمت أرشفة السبب',

      'trash': 'سلة المحذوفات',
      'emptyTrash': 'سلة المحذوفات فارغة',
      'purgeTrash': 'تفريغ السلة نهائياً',
      'purgeTrashConfirm': 'هل أنت متأكد من تفريغ سلة المحذوفات نهائياً؟ لا يمكن التراجع عن هذا الإجراء.',
      'restore': 'استعادة',
      'taskRestored': 'تمت استعادة المهمة',

      'goalTitle': 'عنوان الهدف',
      'goalDescription': 'وصف الهدف وملاحظاته',
      'progressMode': 'طريقة حساب التقدم',
      'modeMilestones': 'مراحل وخطوات',
      'modeNumeric': 'مستهدف رقمي',
      'targetValue': 'المستهدف',
      'currentValue': 'الحالي',
      'unit': 'الوحدة',
      'unitHint': 'مثال: صفحة، جنيه، كم، ساعة',
      'targetDate': 'تاريخ الهدف',
      'category': 'التصنيف',
      'categoryPersonal': 'شخصي',
      'categoryWork': 'عمل',
      'categoryStudy': 'دراسة',
      'categoryHealth': 'صحة',
      'categoryFinance': 'مالية',
      'categoryOther': 'أخرى',
      'milestones': 'المراحل',
      'addMilestone': 'إضافة مرحلة',
      'editMilestone': 'تعديل المرحلة',
      'milestoneTitle': 'اسم المرحلة',
      'milestoneWeight': 'الوزن النسبي',
      'milestoneDone': 'مكتملة',
      'milestonePending': 'قيد الانتظار',
      'logProgress': 'تسجيل تقدم',
      'progressDelta': 'القيمة المضافة (+ أو -)',
      'progressNote': 'ملاحظة (اختياري)',
      'progressHistory': 'سجل التحديثات الرقمية',
      'dueToday': 'موعده اليوم',
      'noTargetDate': 'بدون تاريخ محدد',
      'nextMilestone': 'المرحلة القادمة',
      'allMilestonesDone': 'تمت جميع المراحل!',
      'linkedTasks': 'مهام مرتبطة',
      'addTaskToGoal': 'إضافة مهمة لهذا الهدف',
      'noMilestonesYet': 'لم تتم إضافة أي مراحل بعد',
      'noLinkedTasksYet': 'لا توجد مهام مرتبطة بهذا الهدف',
      'noGoalUpdatesYet': 'لم يتم تسجيل أي تقدم بعد',
      'pauseGoal': 'إيقاف مؤقت للهدف',
      'resumeGoal': 'استئناف الهدف',
      'abandonGoal': 'إلغاء الهدف',
      'markGoalDone': 'إكمال الهدف',
      'deleteGoal': 'حذف الهدف',
      'deleteGoalConfirm': 'هل تريد نقل هذا الهدف لسلة المحذوفات؟',
      'pauseReasonPrompt': 'سبب الإيقاف المؤقت:',
      'abandonReasonPrompt': 'سبب الإلغاء أو التراجع:',
      'reasonRequired': 'يرجى كتابة أو اختيار السبب',
      'allMilestonesDonePrompt': 'مبروك! تم إنجاز كل مراحل الهدف، هل تريد تعيينه كمكتمل؟',
      'goalSavedSuccess': 'تم حفظ الهدف بنجاح',
      'milestoneAdded': 'تمت إضافة المرحلة بنجاح',
      'progressLoggedSuccess': 'تم تسجيل التقدم بنجاح',
      'filterActive': 'نشطة',
      'filterPaused': 'متوقفة',
      'filterDone': 'مكتملة',
      'editGoal': 'تعديل الهدف',

      'editIdea': 'تعديل الفكرة',
      'ideaTitle': 'عنوان الفكرة',
      'ideaDescription': 'تفاصيل وملاحظات الفكرة',
      'ideaSaved': 'تم حفظ الفكرة بنجاح',
      'convertToTask': 'تحويل لمهمة',
      'convertToGoal': 'تحويل لهدف',
      'ideaConvertedToTaskSuccess': 'تم تحويل الفكرة لمهمة بنجاح',
      'ideaConvertedToGoalSuccess': 'تم تحويل الفكرة لهدف بنجاح',
      'archiveIdea': 'أرشفة الفكرة',
      'unarchiveIdea': 'إلغاء الأرشفة',
      'deleteIdea': 'حذف الفكرة',
      'deleteIdeaConfirm': 'هل تريد نقل هذه الفكرة لسلة المحذوفات؟',
      'searchIdeasHint': 'ابحث في الأفكار والوسوم...',
      'tags': 'الوسوم',
      'addTag': 'إضافة وسم',
      'tagHint': 'اكتب الوسم واضغط Enter...',
      'allTags': 'كل الوسوم',
      'noIdeasYet': 'مفيش أفكار مسجلة في هذا القسم',
      'voiceNotes': 'تسجيلات صوتية',
      'addVoiceNote': 'تسجيل صوتي جديد',
      'recordIdea': 'سجّل فكرة',
      'recordVoiceNote': 'بدء التسجيل',
      'stopRecording': 'إيقاف وحفظ',
      'cancelRecording': 'إلغاء',
      'pauseRecording': 'إيقاف مؤقت',
      'resumeRecording': 'استئناف',
      'recordingTime': 'مدة التسجيل',
      'recordingSaved': 'تم حفظ التسجيل الصوتي بنجاح',
      'discardRecordingConfirm': 'التسجيل الحالي أطول من 5 ثوانٍ، هل تريد تجاهله وحذفه؟',
      'voiceNoteLabel': 'عنوان التسجيل (اختياري)',
      'renameVoiceNote': 'تسمية التسجيل',
      'deleteVoiceNote': 'حذف التسجيل',
      'deleteVoiceNoteConfirm': 'هل تريد حذف هذا التسجيل الصوتي؟',
      'voicePermissionTitle': 'صلاحية الميكروفون',
      'voicePermissionDesc': 'يحتاج التطبيق إذن استخدام الميكروفون لتسجيل الملاحظات الصوتية وحفظها محلياً على جهازك دون اتصال بالإنترنت.',
      'grantPermission': 'منح الإذن',
      'openSettings': 'فتح الإعدادات',
      'voiceFileMissing': 'الملف غير موجود',
      'cleanDeletedRecordings': 'تنظيف المحذوفات',
      'voiceStorage': 'مساحة التسجيلات الصوتية',
      'voiceNotesCountLabel': 'عدد التسجيلات',
      'voiceStorageUsedLabel': 'المساحة المستخدمة',
      'stats': 'الإحصائيات',
      'rangeWeek': 'أسبوع',
      'rangeMonth': 'شهر',
      'rangeYear': 'سنة',
      'rangeAllTime': 'كل الأوقات',
      'rangeCustom': 'نطاق مخصص',
      'rangeThisWeek': 'الأسبوع الحالي',
      'rangeLastWeek': 'الأسبوع الماضي',
      'rangeThisMonth': 'الشهر الحالي',
      'rangeLastMonth': 'الشهر الماضي',
      'rangeThisYear': 'السنة الحالية',
      'completionRate': 'نسبة الإنجاز',
      'completedTasksCount': 'المهام المنجزة',
      'postponedTasksCount': 'المهام المؤجلة',
      'partialTasksCount': 'أُنجز جزء منها',
      'waitingStoppedCount': 'منتظرة ومتوقفة',
      'averageDuration': 'متوسط المدة',
      'currentStreak': 'الحماسة الحالية',
      'bestStreak': 'أفضل حماسة',
      'daysUnit': 'أيام',
      'minutesUnit': 'دقيقة',
      'vsPreviousPeriod': 'مقارنة بالفترة السابقة',
      'completionTrend': 'إنجاز المهام عبر الوقت',
      'statusDistribution': 'توزيع حالات المهام',
      'topReasons': 'أبرز أسباب التأجيل والتوقف',
      'productiveWeekday': 'أكثر الأيام إنتاجية',
      'goalsStats': 'أهداف تم التقدم فيها',
      'ideasStats': 'الأفكار والتحويلات',
      'highlights': 'أبرز ما اتنجز',
      'noStatsData': 'مفيش بيانات كافية للفترة دي',
      'noStatsDataSubtitle': 'أنجز بعض المهام وارجع هنا لمتابعة إحصائياتك الصادقة',
      'exportExcel': 'تصدير تقرير الإكسيل',
      'exportExcelSubtitle': 'ملف .xlsx أوفلاين بالكامل متوافق مع Excel و Google Sheets',
      'exportRange': 'اختر الفترة الزمنية للتقرير',
      'generatingReport': 'جاري تجهيز تقرير الإكسيل أوفلاين...',
      'saveReport': 'حفظ في الملفات',
      'shareReport': 'مشاركة التقرير',
      'reportSavedSuccess': 'تم حفظ ملف التقرير بنجاح',
      'reportSharedSuccess': 'تم فتح نافذة المشاركة',
      'googleSheetsTip': 'نصيحة: تطبيق Google Sheets يفتح ملفات .xlsx مباشرة من Drive',
      'sheetSummary': 'الملخص',
      'sheetTasks': 'المهام',
      'sheetHistory': 'السجل',
      'sheetDaily': 'يومي',
      'sheetReasons': 'الأسباب',
      'sheetGoals': 'الأهداف',
      'sheetIdeas': 'الأفكار',
      'remindersAndNotifications': 'التنبيهات والإشعارات',
      'dailySummary': 'الموجز الصباحي',
      'dailySummarySubtitle': 'إشعار صباحي (08:00) بعدد مهام ومشاوير اليوم',
      'eveningReview': 'المراجعة المسائية',
      'eveningReviewSubtitle': 'إشعار مسائي (21:00) لمراجعة إنجازاتك وتحديث الحالات',
      'weeklyExcelReminder': 'تذكير تقرير الإكسيل الأسبوعي',
      'weeklyExcelReminderSubtitle': 'تذكير كل جمعة (18:00) لمراجعة وتصدير تقرير الإنجاز',
      'defaultReminderTime': 'وقت التنبيه الافتراضي',
      'defaultReminderTimeSubtitle': 'للمهام المحددة بتاريخ فقط وبدون وقت',
      'permissionGranted': 'مفعل',
      'permissionDenied': 'غير مفعل - اضغط للطلب',
      'reminderAtDueTime': 'في الموعد المحدد',
      'reminder10MinBefore': 'قبل 10 دقائق',
      'reminder30MinBefore': 'قبل 30 دقيقة',
      'reminder1HourBefore': 'قبل ساعة',
      'reminder1DayBefore': 'قبل يوم واحد',
      'noReminder': 'بدون تنبيه',
      'taskReminder': 'تنبيه المهمة',
      'recurrence': 'التكرار',
      'recurrenceNone': 'بدون تكرار',
      'recurrenceDaily': 'يومياً',
      'recurrenceWeekly': 'أسبوعياً',
      'recurrenceMonthly': 'شهرياً',
      'recurrenceEndDate': 'تاريخ انتهاء التكرار',
      'recurrenceEndsNever': 'مستمر دائماً',
      'repeatOnDays': 'التكرار في أيام',
      'repeatDayOfMonth': 'يوم من الشهر',
      'editRecurringTitle': 'تعديل المهمة المتكررة',
      'editRecurringThisOnly': 'هذه المهمة فقط',
      'editRecurringAllFuture': 'كل المهام القادمة وقاعدة التكرار',
      'deleteRecurringTitle': 'حذف المهمة المتكررة',
      'deleteRecurringThisOnly': 'حذف هذه المهمة فقط',
      'deleteRecurringAllFuture': 'إلغاء التكرار وحذف كل القادمة',
      'recurrenceGenerated': 'مهمة متكررة',
      'backupAndSecurity': 'النسخ الاحتياطي والأمان',
      'fullBackupTitle': 'نسخة احتياطية شاملة (.zip)',
      'fullBackupDescription': 'تصدير كامل بيانات التطبيق والتسجيلات الصوتية في ملف مضغوط واحد مشفر بترميز SHA-256',
      'includeVoiceNotesToggle': 'تضمين التسجيلات الصوتية',
      'includeVoiceNotesSub': 'تضمين جميع الملفات الصوتية المسجلة داخل ملف النسخة',
      'withoutVoiceNotesSub': 'تصدير نسخة خفيفة للبيانات فقط بدون التسجيلات الصوتية',
      'exportBackupButton': 'تصدير النسخة الاحتياطية (.zip)',
      'exportingBackup': 'جاري تجهيز النسخة الاحتياطية...',
      'errorExportingBackup': 'حدث خطأ أثناء تصدير النسخة',
      'restoreBackupTitle': 'استرجاع نسخة احتياطية (.zip)',
      'restoreBackupDescription': 'استعادة بيانات التطبيق من ملف نسخة احتياطية سابق. يتم حفظ نسخة أمان تلقائية قبل الاستبدال.',
      'selectBackupFileButton': 'اختيار ملف نسخة احتياطية (.zip)',
      'inspectingBackup': 'جاري فحص ملف النسخة...',
      'restoringBackup': 'جاري استرجاع البيانات...',
      'restoreBackupSuccess': 'تم استرجاع النسخة الاحتياطية بنجاح!',
      'errorRestoringBackup': 'حدث خطأ أثناء استرجاع النسخة',
      'invalidBackupFile': 'ملف غير صالح',
      'invalidBackupFileDetails': 'الملف المحدد لا يطابق بنية نسخ إنجاز الاحتياطية.',
      'restoreConfirmTitle': 'تأكيد استرجاع البيانات',
      'restoreConfirmMessage': 'سيتم استبدال جميع البيانات الحالية بالبيانات الموجودة في ملف النسخة الاحتياطية. هل أنت متأكد؟',
      'backupDate': 'تاريخ النسخة',
      'safetyCopyNotice': 'ملاحظة أمان: تم أخذ نسخة احتياطية تلقائية من بياناتك الحالية قبل بدء الاسترجاع لحمايتها.',
      'restoreReplaceButton': 'استبدال واسترجاع',
      'csvExportTitle': 'تصدير ملفات CSV',
      'csvExportDescription': 'تصدير الجداول بصيغة CSV القياسية بترميز UTF-8 مع BOM لقراءة الأرقام والنصوص العربية بشكل مثالي',
      'tasksCsvTitle': 'ملف المهام (tasks.csv)',
      'tasksCsvSubtitle': 'يشمل جميع الحقول وتاريخ الإنشاء وعدد التسجيلات الصوتية',
      'exportTasksCsvTooltip': 'تصدير ومشاركة ملف tasks.csv',
      'eventsCsvTitle': 'ملف سجل العمليات (events.csv)',
      'eventsCsvSubtitle': 'سجل التغييرات الكامل للحالات والتأجيلات وأسبابها',
      'exportEventsCsvTooltip': 'تصدير ومشاركة ملف events.csv',
      'exportingCsv': 'جاري تصدير ملف CSV...',
      'errorExportingCsv': 'حدث خطأ أثناء تصدير ملف CSV',
      'unknownDate': 'غير معروف',
      'appLockTitle': 'إنجاز - تطبيق مؤمّن',
      'appLockSubtitle': 'يرجى تأكيد الهوية بواسطة البصمة أو رمز قفل الشاشة لمتابعة استخدام التطبيق',
      'appLockReason': 'يرجى تأكيد هويتك للوصول لتطبيق إنجاز',
      'unlockApp': 'فتح القفل',
      'authenticating': 'جاري التحقق...',
      'authFailedMessage': 'فشل التحقق من الهوية',
      'appLockSettingTitle': 'قفل التطبيق والأمان',
      'appLockSettingSubtitle': 'حماية التطبيق بالبصمة وإخفاء الشاشة في قائمة التطبيقات الحديثة',
      'trashPurgedSuccess': 'تم تفريغ سلة المحذوفات نهائياً',
      'trashPurgedDetails': 'تم حذف العناصر وتنظيف الملفات الصوتية',
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
      'duplicateTask': 'Duplicate task',
      'deleteTask': 'Delete task',
      'deleteTaskConfirm': 'Are you sure you want to delete this task?',
      'taskDeleted': 'Task moved to trash',
      'minute': 'min',
      'hour': 'hr',

      'multiLinePasteTitle': 'Convert notes to tasks',
      'multiLinePastePrompt': 'Found multiple lines, create separate tasks?',
      'importNotes': 'Import notes',
      'pasteNotesHint': 'Paste your notes or list here (each line a task)...',
      'convert': 'Convert to tasks',
      'tasksCreatedSuccess': 'Tasks created successfully',

      'historyTitle': 'Task History',
      'searchHint': 'Search tasks, notes, or reasons...',
      'filterAll': 'All',
      'filterKind': 'Kind',
      'filterStatus': 'Status',
      'sortNewest': 'Newest first',
      'sortOldest': 'Oldest first',
      'noHistoryFound': 'No matching history found',
      'clearFilters': 'Reset filters',

      'reasonsManager': 'Reasons Manager',
      'addReason': 'Add New Reason',
      'editReason': 'Edit Reason',
      'reasonLabelAr': 'Reason label (Arabic)',
      'reasonLabelEn': 'Reason label (English - optional)',
      'reasonCategory': 'Category',
      'categoryPostpone': 'Postpone',
      'categoryWaiting': 'Waiting',
      'categoryStopped': 'Stopped',
      'categoryPartial': 'Partial',
      'categoryAny': 'Any status',
      'archive': 'Archive',
      'archiveReasonConfirm': "Archive this reason? It won't appear in new lists but remains in old records.",
      'usageCountLabel': 'Usage count',
      'reasonAddedSuccess': 'Reason added successfully',
      'reasonUpdatedSuccess': 'Reason updated successfully',
      'reasonArchivedSuccess': 'Reason archived',

      'trash': 'Trash',
      'emptyTrash': 'Trash is empty',
      'purgeTrash': 'Purge trash permanently',
      'purgeTrashConfirm': 'Permanently purge all items in trash? This cannot be undone.',
      'restore': 'Restore',
      'taskRestored': 'Task restored',

      'goalTitle': 'Goal Title',
      'goalDescription': 'Goal Description & Notes',
      'progressMode': 'Progress Tracking Mode',
      'modeMilestones': 'Milestones & Steps',
      'modeNumeric': 'Numeric Target',
      'targetValue': 'Target Value',
      'currentValue': 'Current Value',
      'unit': 'Unit',
      'unitHint': 'e.g. pages, EGP, km, hrs',
      'targetDate': 'Target Date',
      'category': 'Category',
      'categoryPersonal': 'Personal',
      'categoryWork': 'Work',
      'categoryStudy': 'Study',
      'categoryHealth': 'Health',
      'categoryFinance': 'Finance',
      'categoryOther': 'Other',
      'milestones': 'Milestones',
      'addMilestone': 'Add Milestone',
      'editMilestone': 'Edit Milestone',
      'milestoneTitle': 'Milestone Title',
      'milestoneWeight': 'Relative Weight',
      'milestoneDone': 'Done',
      'milestonePending': 'Pending',
      'logProgress': 'Log Progress',
      'progressDelta': 'Value Delta (+ or -)',
      'progressNote': 'Note (optional)',
      'progressHistory': 'Numeric Progress History',
      'dueToday': 'Due today',
      'noTargetDate': 'No target date',
      'nextMilestone': 'Next Milestone',
      'allMilestonesDone': 'All milestones completed!',
      'linkedTasks': 'Linked Tasks',
      'addTaskToGoal': 'Add Task to Goal',
      'noMilestonesYet': 'No milestones added yet',
      'noLinkedTasksYet': 'No linked tasks yet',
      'noGoalUpdatesYet': 'No progress updates recorded yet',
      'pauseGoal': 'Pause Goal',
      'resumeGoal': 'Resume Goal',
      'abandonGoal': 'Abandon Goal',
      'markGoalDone': 'Mark Goal Done',
      'deleteGoal': 'Delete Goal',
      'deleteGoalConfirm': 'Move this goal to trash?',
      'pauseReasonPrompt': 'Reason for pausing:',
      'abandonReasonPrompt': 'Reason for abandoning:',
      'reasonRequired': 'Please specify a reason',
      'allMilestonesDonePrompt': 'Congratulations! All milestones are done. Mark this goal as completed?',
      'goalSavedSuccess': 'Goal saved successfully',
      'milestoneAdded': 'Milestone added successfully',
      'progressLoggedSuccess': 'Progress logged successfully',
      'filterActive': 'Active',
      'filterPaused': 'Paused',
      'filterDone': 'Done',
      'editGoal': 'Edit Goal',

      'editIdea': 'Edit Idea',
      'ideaTitle': 'Idea Title',
      'ideaDescription': 'Idea Details & Notes',
      'ideaSaved': 'Idea saved successfully',
      'convertToTask': 'Convert to Task',
      'convertToGoal': 'Convert to Goal',
      'ideaConvertedToTaskSuccess': 'Idea converted to task successfully',
      'ideaConvertedToGoalSuccess': 'Idea converted to goal successfully',
      'archiveIdea': 'Archive Idea',
      'unarchiveIdea': 'Unarchive Idea',
      'deleteIdea': 'Delete Idea',
      'deleteIdeaConfirm': 'Move this idea to trash?',
      'searchIdeasHint': 'Search ideas and tags...',
      'tags': 'Tags',
      'addTag': 'Add Tag',
      'tagHint': 'Type tag and press Enter...',
      'allTags': 'All Tags',
      'noIdeasYet': 'No ideas in this section yet',
      'voiceNotes': 'Voice Notes',
      'addVoiceNote': 'New Voice Note',
      'recordIdea': 'Record an Idea',
      'recordVoiceNote': 'Start Recording',
      'stopRecording': 'Stop & Save',
      'cancelRecording': 'Cancel',
      'pauseRecording': 'Pause',
      'resumeRecording': 'Resume',
      'recordingTime': 'Recording Duration',
      'recordingSaved': 'Voice note saved successfully',
      'discardRecordingConfirm': 'This recording is over 5 seconds. Are you sure you want to discard it?',
      'voiceNoteLabel': 'Voice note label (optional)',
      'renameVoiceNote': 'Rename Voice Note',
      'deleteVoiceNote': 'Delete Voice Note',
      'deleteVoiceNoteConfirm': 'Delete this voice note?',
      'voicePermissionTitle': 'Microphone Permission',
      'voicePermissionDesc': 'Enjaz needs microphone permission to record voice notes offline directly on your device.',
      'grantPermission': 'Grant Permission',
      'openSettings': 'Open Settings',
      'voiceFileMissing': 'File missing',
      'cleanDeletedRecordings': 'Clean Deleted Recordings',
      'voiceStorage': 'Voice Notes Storage',
      'voiceNotesCountLabel': 'Total Recordings',
      'voiceStorageUsedLabel': 'Storage Used',
      'stats': 'Stats',
      'rangeWeek': 'Week',
      'rangeMonth': 'Month',
      'rangeYear': 'Year',
      'rangeAllTime': 'All Time',
      'rangeCustom': 'Custom Range',
      'rangeThisWeek': 'This Week',
      'rangeLastWeek': 'Last Week',
      'rangeThisMonth': 'This Month',
      'rangeLastMonth': 'Last Month',
      'rangeThisYear': 'This Year',
      'completionRate': 'Completion Rate',
      'completedTasksCount': 'Completed Tasks',
      'postponedTasksCount': 'Postponed Tasks',
      'partialTasksCount': 'Partially Done',
      'waitingStoppedCount': 'Waiting & Stopped',
      'averageDuration': 'Average Duration',
      'currentStreak': 'Current Streak',
      'bestStreak': 'Best Streak',
      'daysUnit': 'days',
      'minutesUnit': 'mins',
      'vsPreviousPeriod': 'vs previous period',
      'completionTrend': 'Completion Trend',
      'statusDistribution': 'Status Distribution',
      'topReasons': 'Top Postponement Reasons',
      'productiveWeekday': 'Most Productive Weekday',
      'goalsStats': 'Goals Progress',
      'ideasStats': 'Ideas & Conversions',
      'highlights': 'Highlights',
      'noStatsData': 'Not enough data for this period',
      'noStatsDataSubtitle': 'Complete some tasks and come back to review your honest stats',
      'exportExcel': 'Export Excel Report',
      'exportExcelSubtitle': 'Fully offline .xlsx file compatible with Excel & Google Sheets',
      'exportRange': 'Select Report Range',
      'generatingReport': 'Preparing Excel report offline...',
      'saveReport': 'Save to Files',
      'shareReport': 'Share Report',
      'reportSavedSuccess': 'Report file saved successfully',
      'reportSharedSuccess': 'Opened share dialog',
      'googleSheetsTip': 'Tip: Google Sheets opens .xlsx files directly from Google Drive',
      'sheetSummary': 'Summary',
      'sheetTasks': 'Tasks',
      'sheetHistory': 'History',
      'sheetDaily': 'Daily',
      'sheetReasons': 'Reasons',
      'sheetGoals': 'Goals',
      'sheetIdeas': 'Ideas',
      'remindersAndNotifications': 'Reminders & Notifications',
      'dailySummary': 'Daily Summary',
      'dailySummarySubtitle': 'Morning notification (08:00) with today\'s task count',
      'eveningReview': 'Evening Review',
      'eveningReviewSubtitle': 'Evening notification (21:00) to review and update your day',
      'weeklyExcelReminder': 'Weekly Excel Reminder',
      'weeklyExcelReminderSubtitle': 'Reminder every Friday (18:00) to export weekly report',
      'defaultReminderTime': 'Default Reminder Time',
      'defaultReminderTimeSubtitle': 'For tasks with date only and no specific time',
      'permissionGranted': 'Enabled',
      'permissionDenied': 'Disabled - Tap to enable',
      'reminderAtDueTime': 'At due time',
      'reminder10MinBefore': '10 minutes before',
      'reminder30MinBefore': '30 minutes before',
      'reminder1HourBefore': '1 hour before',
      'reminder1DayBefore': '1 day before',
      'noReminder': 'No reminder',
      'taskReminder': 'Task Reminder',
      'recurrence': 'Repeat',
      'recurrenceNone': 'Does not repeat',
      'recurrenceDaily': 'Daily',
      'recurrenceWeekly': 'Weekly',
      'recurrenceMonthly': 'Monthly',
      'recurrenceEndDate': 'Repeat end date',
      'recurrenceEndsNever': 'Repeats forever',
      'repeatOnDays': 'Repeat on days',
      'repeatDayOfMonth': 'Day of month',
      'editRecurringTitle': 'Edit Recurring Task',
      'editRecurringThisOnly': 'This one only',
      'editRecurringAllFuture': 'All future instances & rule',
      'deleteRecurringTitle': 'Delete Recurring Task',
      'deleteRecurringThisOnly': 'Delete this one only',
      'deleteRecurringAllFuture': 'Cancel series & delete all future',
      'recurrenceGenerated': 'Recurring',
      'backupAndSecurity': 'Backup & Security',
      'fullBackupTitle': 'Full Backup Archive (.zip)',
      'fullBackupDescription': 'Export all application data and audio recordings into a single zip archive verified with SHA-256',
      'includeVoiceNotesToggle': 'Include Voice Notes',
      'includeVoiceNotesSub': 'Include all recorded audio files in archive',
      'withoutVoiceNotesSub': 'Export lightweight backup of data only without audio',
      'exportBackupButton': 'Export Backup (.zip)',
      'exportingBackup': 'Preparing backup archive...',
      'errorExportingBackup': 'Error exporting backup',
      'restoreBackupTitle': 'Restore Backup (.zip)',
      'restoreBackupDescription': 'Restore application data from a previous backup file. An automatic safety snapshot is saved before replacement.',
      'selectBackupFileButton': 'Select Backup File (.zip)',
      'inspectingBackup': 'Inspecting backup file...',
      'restoringBackup': 'Restoring backup data...',
      'restoreBackupSuccess': 'Backup restored successfully!',
      'errorRestoringBackup': 'Error restoring backup',
      'invalidBackupFile': 'Invalid Backup File',
      'invalidBackupFileDetails': 'The selected file does not match Enjaz backup structure.',
      'restoreConfirmTitle': 'Confirm Data Restore',
      'restoreConfirmMessage': 'All current data will be replaced by the data in this backup file. Are you sure?',
      'backupDate': 'Backup Date',
      'safetyCopyNotice': 'Safety Notice: An automatic safety copy of current data is saved before restoration begins.',
      'restoreReplaceButton': 'Replace & Restore',
      'csvExportTitle': 'Export CSV Files',
      'csvExportDescription': 'Export tables in standard UTF-8 BOM CSV format for perfect Arabic text compatibility',
      'tasksCsvTitle': 'Tasks Table (tasks.csv)',
      'tasksCsvSubtitle': 'Includes all fields, timestamps and voice notes count',
      'exportTasksCsvTooltip': 'Export and share tasks.csv',
      'eventsCsvTitle': 'Events History (events.csv)',
      'eventsCsvSubtitle': 'Full audit trail of status changes, postponements and reasons',
      'exportEventsCsvTooltip': 'Export and share events.csv',
      'exportingCsv': 'Exporting CSV file...',
      'errorExportingCsv': 'Error exporting CSV',
      'unknownDate': 'Unknown',
      'appLockTitle': 'Enjaz - Protected',
      'appLockSubtitle': 'Please authenticate using fingerprint or device screen lock to continue',
      'appLockReason': 'Please authenticate to access Enjaz app',
      'unlockApp': 'Unlock',
      'authenticating': 'Authenticating...',
      'authFailedMessage': 'Authentication failed',
      'appLockSettingTitle': 'App Lock & Security',
      'appLockSettingSubtitle': 'Protect app with biometrics and obscure preview in recent apps',
      'trashPurgedSuccess': 'Trash permanently emptied',
      'trashPurgedDetails': 'Items purged and audio files cleaned',
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
  String get duplicateTask => _get('duplicateTask');
  String get deleteTask => _get('deleteTask');
  String get deleteTaskConfirm => _get('deleteTaskConfirm');
  String get taskDeleted => _get('taskDeleted');
  String get minute => _get('minute');
  String get hour => _get('hour');

  String get multiLinePasteTitle => _get('multiLinePasteTitle');
  String get multiLinePastePrompt => _get('multiLinePastePrompt');
  String get importNotes => _get('importNotes');
  String get pasteNotesHint => _get('pasteNotesHint');
  String get convert => _get('convert');
  String get tasksCreatedSuccess => _get('tasksCreatedSuccess');

  String get historyTitle => _get('historyTitle');
  String get searchHint => _get('searchHint');
  String get filterAll => _get('filterAll');
  String get filterKind => _get('filterKind');
  String get filterStatus => _get('filterStatus');
  String get sortNewest => _get('sortNewest');
  String get sortOldest => _get('sortOldest');
  String get noHistoryFound => _get('noHistoryFound');
  String get clearFilters => _get('clearFilters');

  String get reasonsManager => _get('reasonsManager');
  String get addReason => _get('addReason');
  String get editReason => _get('editReason');
  String get reasonLabelAr => _get('reasonLabelAr');
  String get reasonLabelEn => _get('reasonLabelEn');
  String get reasonCategory => _get('reasonCategory');
  String get categoryPostpone => _get('categoryPostpone');
  String get categoryWaiting => _get('categoryWaiting');
  String get categoryStopped => _get('categoryStopped');
  String get categoryPartial => _get('categoryPartial');
  String get categoryAny => _get('categoryAny');
  String get archive => _get('archive');
  String get archiveReasonConfirm => _get('archiveReasonConfirm');
  String get usageCountLabel => _get('usageCountLabel');
  String get reasonAddedSuccess => _get('reasonAddedSuccess');
  String get reasonUpdatedSuccess => _get('reasonUpdatedSuccess');
  String get reasonArchivedSuccess => _get('reasonArchivedSuccess');

  String get trash => _get('trash');
  String get emptyTrash => _get('emptyTrash');
  String get purgeTrash => _get('purgeTrash');
  String get purgeTrashConfirm => _get('purgeTrashConfirm');
  String get restore => _get('restore');
  String get taskRestored => _get('taskRestored');

  String get goalTitle => _get('goalTitle');
  String get goalDescription => _get('goalDescription');
  String get progressMode => _get('progressMode');
  String get modeMilestones => _get('modeMilestones');
  String get modeNumeric => _get('modeNumeric');
  String get targetValue => _get('targetValue');
  String get currentValue => _get('currentValue');
  String get unit => _get('unit');
  String get unitHint => _get('unitHint');
  String get targetDate => _get('targetDate');
  String get category => _get('category');
  String get categoryPersonal => _get('categoryPersonal');
  String get categoryWork => _get('categoryWork');
  String get categoryStudy => _get('categoryStudy');
  String get categoryHealth => _get('categoryHealth');
  String get categoryFinance => _get('categoryFinance');
  String get categoryOther => _get('categoryOther');
  String get milestones => _get('milestones');
  String get addMilestone => _get('addMilestone');
  String get editMilestone => _get('editMilestone');
  String get milestoneTitle => _get('milestoneTitle');
  String get milestoneWeight => _get('milestoneWeight');
  String get milestoneDone => _get('milestoneDone');
  String get milestonePending => _get('milestonePending');
  String get logProgress => _get('logProgress');
  String get progressDelta => _get('progressDelta');
  String get progressNote => _get('progressNote');
  String get progressHistory => _get('progressHistory');
  String get dueToday => _get('dueToday');
  String get noTargetDate => _get('noTargetDate');
  String get nextMilestone => _get('nextMilestone');
  String get allMilestonesDone => _get('allMilestonesDone');
  String get linkedTasks => _get('linkedTasks');
  String get addTaskToGoal => _get('addTaskToGoal');
  String get noMilestonesYet => _get('noMilestonesYet');
  String get noLinkedTasksYet => _get('noLinkedTasksYet');
  String get noGoalUpdatesYet => _get('noGoalUpdatesYet');
  String get pauseGoal => _get('pauseGoal');
  String get resumeGoal => _get('resumeGoal');
  String get abandonGoal => _get('abandonGoal');
  String get markGoalDone => _get('markGoalDone');
  String get deleteGoal => _get('deleteGoal');
  String get deleteGoalConfirm => _get('deleteGoalConfirm');
  String get pauseReasonPrompt => _get('pauseReasonPrompt');
  String get abandonReasonPrompt => _get('abandonReasonPrompt');
  String get reasonRequired => _get('reasonRequired');
  String get allMilestonesDonePrompt => _get('allMilestonesDonePrompt');
  String get goalSavedSuccess => _get('goalSavedSuccess');
  String get milestoneAdded => _get('milestoneAdded');
  String get progressLoggedSuccess => _get('progressLoggedSuccess');
  String get filterActive => _get('filterActive');
  String get filterPaused => _get('filterPaused');
  String get filterDone => _get('filterDone');
  String get editGoal => _get('editGoal');

  String get editIdea => _get('editIdea');
  String get ideaTitle => _get('ideaTitle');
  String get ideaDescription => _get('ideaDescription');
  String get ideaSaved => _get('ideaSaved');
  String get convertToTask => _get('convertToTask');
  String get convertToGoal => _get('convertToGoal');
  String get ideaConvertedToTaskSuccess => _get('ideaConvertedToTaskSuccess');
  String get ideaConvertedToGoalSuccess => _get('ideaConvertedToGoalSuccess');
  String get archiveIdea => _get('archiveIdea');
  String get unarchiveIdea => _get('unarchiveIdea');
  String get deleteIdea => _get('deleteIdea');
  String get deleteIdeaConfirm => _get('deleteIdeaConfirm');
  String get searchIdeasHint => _get('searchIdeasHint');
  String get tags => _get('tags');
  String get addTag => _get('addTag');
  String get tagHint => _get('tagHint');
  String get allTags => _get('allTags');
  String get noIdeasYet => _get('noIdeasYet');
  String get voiceNotes => _get('voiceNotes');
  String get addVoiceNote => _get('addVoiceNote');
  String get recordIdea => _get('recordIdea');
  String get recordVoiceNote => _get('recordVoiceNote');
  String get stopRecording => _get('stopRecording');
  String get cancelRecording => _get('cancelRecording');
  String get pauseRecording => _get('pauseRecording');
  String get resumeRecording => _get('resumeRecording');
  String get recordingTime => _get('recordingTime');
  String get recordingSaved => _get('recordingSaved');
  String get discardRecordingConfirm => _get('discardRecordingConfirm');
  String get voiceNoteLabel => _get('voiceNoteLabel');
  String get renameVoiceNote => _get('renameVoiceNote');
  String get deleteVoiceNote => _get('deleteVoiceNote');
  String get deleteVoiceNoteConfirm => _get('deleteVoiceNoteConfirm');
  String get voicePermissionTitle => _get('voicePermissionTitle');
  String get voicePermissionDesc => _get('voicePermissionDesc');
  String get grantPermission => _get('grantPermission');
  String get openSettings => _get('openSettings');
  String get voiceFileMissing => _get('voiceFileMissing');
  String get cleanDeletedRecordings => _get('cleanDeletedRecordings');
  String get voiceStorage => _get('voiceStorage');
  String get voiceNotesCountLabel => _get('voiceNotesCountLabel');
  String get voiceStorageUsedLabel => _get('voiceStorageUsedLabel');

  String get stats => _get('stats');
  String get rangeWeek => _get('rangeWeek');
  String get rangeMonth => _get('rangeMonth');
  String get rangeYear => _get('rangeYear');
  String get rangeAllTime => _get('rangeAllTime');
  String get rangeCustom => _get('rangeCustom');
  String get rangeThisWeek => _get('rangeThisWeek');
  String get rangeLastWeek => _get('rangeLastWeek');
  String get rangeThisMonth => _get('rangeThisMonth');
  String get rangeLastMonth => _get('rangeLastMonth');
  String get rangeThisYear => _get('rangeThisYear');
  String get completionRate => _get('completionRate');
  String get completedTasksCount => _get('completedTasksCount');
  String get postponedTasksCount => _get('postponedTasksCount');
  String get partialTasksCount => _get('partialTasksCount');
  String get waitingStoppedCount => _get('waitingStoppedCount');
  String get averageDuration => _get('averageDuration');
  String get currentStreak => _get('currentStreak');
  String get bestStreak => _get('bestStreak');
  String get daysUnit => _get('daysUnit');
  String get minutesUnit => _get('minutesUnit');
  String get vsPreviousPeriod => _get('vsPreviousPeriod');
  String get completionTrend => _get('completionTrend');
  String get statusDistribution => _get('statusDistribution');
  String get topReasons => _get('topReasons');
  String get productiveWeekday => _get('productiveWeekday');
  String get goalsStats => _get('goalsStats');
  String get ideasStats => _get('ideasStats');
  String get highlights => _get('highlights');
  String get noStatsData => _get('noStatsData');
  String get noStatsDataSubtitle => _get('noStatsDataSubtitle');
  String get exportExcel => _get('exportExcel');
  String get exportExcelSubtitle => _get('exportExcelSubtitle');
  String get exportRange => _get('exportRange');
  String get generatingReport => _get('generatingReport');
  String get saveReport => _get('saveReport');
  String get shareReport => _get('shareReport');
  String get reportSavedSuccess => _get('reportSavedSuccess');
  String get reportSharedSuccess => _get('reportSharedSuccess');
  String get googleSheetsTip => _get('googleSheetsTip');
  String get sheetSummary => _get('sheetSummary');
  String get sheetTasks => _get('sheetTasks');
  String get sheetHistory => _get('sheetHistory');
  String get sheetDaily => _get('sheetDaily');
  String get sheetReasons => _get('sheetReasons');
  String get sheetGoals => _get('sheetGoals');
  String get sheetIdeas => _get('sheetIdeas');

  String get remindersAndNotifications => _get('remindersAndNotifications');
  String get dailySummary => _get('dailySummary');
  String get dailySummarySubtitle => _get('dailySummarySubtitle');
  String get eveningReview => _get('eveningReview');
  String get eveningReviewSubtitle => _get('eveningReviewSubtitle');
  String get weeklyExcelReminder => _get('weeklyExcelReminder');
  String get weeklyExcelReminderSubtitle => _get('weeklyExcelReminderSubtitle');
  String get defaultReminderTime => _get('defaultReminderTime');
  String get defaultReminderTimeSubtitle => _get('defaultReminderTimeSubtitle');
  String get permissionGranted => _get('permissionGranted');
  String get permissionDenied => _get('permissionDenied');
  String get reminderAtDueTime => _get('reminderAtDueTime');
  String get reminder10MinBefore => _get('reminder10MinBefore');
  String get reminder30MinBefore => _get('reminder30MinBefore');
  String get reminder1HourBefore => _get('reminder1HourBefore');
  String get reminder1DayBefore => _get('reminder1DayBefore');
  String get noReminder => _get('noReminder');
  String get taskReminder => _get('taskReminder');
  String get recurrence => _get('recurrence');
  String get recurrenceNone => _get('recurrenceNone');
  String get recurrenceDaily => _get('recurrenceDaily');
  String get recurrenceWeekly => _get('recurrenceWeekly');
  String get recurrenceMonthly => _get('recurrenceMonthly');
  String get recurrenceEndDate => _get('recurrenceEndDate');
  String get recurrenceEndsNever => _get('recurrenceEndsNever');
  String get repeatOnDays => _get('repeatOnDays');
  String get repeatDayOfMonth => _get('repeatDayOfMonth');
  String get editRecurringTitle => _get('editRecurringTitle');
  String get editRecurringThisOnly => _get('editRecurringThisOnly');
  String get editRecurringAllFuture => _get('editRecurringAllFuture');
  String get deleteRecurringTitle => _get('deleteRecurringTitle');
  String get deleteRecurringThisOnly => _get('deleteRecurringThisOnly');
  String get deleteRecurringAllFuture => _get('deleteRecurringAllFuture');
  String get recurrenceGenerated => _get('recurrenceGenerated');

  String get backupAndSecurity => _get('backupAndSecurity');
  String get fullBackupTitle => _get('fullBackupTitle');
  String get fullBackupDescription => _get('fullBackupDescription');
  String get includeVoiceNotesToggle => _get('includeVoiceNotesToggle');
  String get includeVoiceNotesSub => _get('includeVoiceNotesSub');
  String get withoutVoiceNotesSub => _get('withoutVoiceNotesSub');
  String get exportBackupButton => _get('exportBackupButton');
  String get exportingBackup => _get('exportingBackup');
  String get errorExportingBackup => _get('errorExportingBackup');
  String get restoreBackupTitle => _get('restoreBackupTitle');
  String get restoreBackupDescription => _get('restoreBackupDescription');
  String get selectBackupFileButton => _get('selectBackupFileButton');
  String get inspectingBackup => _get('inspectingBackup');
  String get restoringBackup => _get('restoringBackup');
  String get restoreBackupSuccess => _get('restoreBackupSuccess');
  String get errorRestoringBackup => _get('errorRestoringBackup');
  String get invalidBackupFile => _get('invalidBackupFile');
  String get invalidBackupFileDetails => _get('invalidBackupFileDetails');
  String get restoreConfirmTitle => _get('restoreConfirmTitle');
  String get restoreConfirmMessage => _get('restoreConfirmMessage');
  String get backupDate => _get('backupDate');
  String get safetyCopyNotice => _get('safetyCopyNotice');
  String get restoreReplaceButton => _get('restoreReplaceButton');
  String get csvExportTitle => _get('csvExportTitle');
  String get csvExportDescription => _get('csvExportDescription');
  String get tasksCsvTitle => _get('tasksCsvTitle');
  String get tasksCsvSubtitle => _get('tasksCsvSubtitle');
  String get exportTasksCsvTooltip => _get('exportTasksCsvTooltip');
  String get eventsCsvTitle => _get('eventsCsvTitle');
  String get eventsCsvSubtitle => _get('eventsCsvSubtitle');
  String get exportEventsCsvTooltip => _get('exportEventsCsvTooltip');
  String get exportingCsv => _get('exportingCsv');
  String get errorExportingCsv => _get('errorExportingCsv');
  String get unknownDate => _get('unknownDate');
  String get appLockTitle => _get('appLockTitle');
  String get appLockSubtitle => _get('appLockSubtitle');
  String get appLockReason => _get('appLockReason');
  String get unlockApp => _get('unlockApp');
  String get authenticating => _get('authenticating');
  String get authFailedMessage => _get('authFailedMessage');
  String get appLockSettingTitle => _get('appLockSettingTitle');
  String get appLockSettingSubtitle => _get('appLockSettingSubtitle');
  String get trashPurgedSuccess => _get('trashPurgedSuccess');
  String get trashPurgedDetails => _get('trashPurgedDetails');

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
