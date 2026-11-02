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
