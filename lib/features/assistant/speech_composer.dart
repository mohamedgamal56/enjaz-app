import 'plural_ar.dart';

/// Helper to compose Arabic speech & text answers for the voice assistant (VOICE.md Sections 3.4 & 6).
///
/// Implements Arabic grammar rules, PluralAr counting, explicit dates/periods,
/// and limits responses to at most 5 items before appending "وكمان N".
class SpeechComposer {
  const SpeechComposer();

  /// Composes the agenda answer for a day or range (Section 6: agenda)
  String composeAgenda({
    required String targetDateWords,
    required List<String> taskTitles,
    int overdueCount = 0,
    int obligationsCount = 0,
    int healthCount = 0,
    List<String> pendingHabits = const [],
  }) {
    if (taskTitles.isEmpty && overdueCount == 0 && obligationsCount == 0 && healthCount == 0 && pendingHabits.isEmpty) {
      return 'في $targetDateWords معندكش مهام مجدولة ولا التزامات، يومك رايق!';
    }

    final buffer = StringBuffer('وراك في $targetDateWords: ');
    if (taskTitles.isNotEmpty) {
      buffer.write(PluralAr.formatTasks(taskTitles.length));
      final displayed = taskTitles.take(5).toList();
      buffer.write(' (${displayed.join('، ')}');
      if (taskTitles.length > 5) {
        buffer.write('، وكمان ${PluralAr.formatTasks(taskTitles.length - 5)}');
      }
      buffer.write(')');
    } else {
      buffer.write('لا توجد مهام جديدة');
    }

    if (overdueCount > 0) {
      buffer.write('، ومعاك ${PluralAr.formatTasks(overdueCount)} متأخرة');
    }
    if (obligationsCount > 0) {
      buffer.write('، و${PluralAr.formatObligations(obligationsCount)} مستحقة');
    }
    if (healthCount > 0) {
      buffer.write('، و${PluralAr.formatCheckups(healthCount)}');
    }
    if (pendingHabits.isNotEmpty) {
      buffer.write('، وعادات لسه مكملتهاش: ${pendingHabits.take(3).join('، ')}');
    }

    return buffer.toString();
  }

  /// Composes the recap answer for a period (Section 6: recap)
  String composeRecap({
    required String periodWords,
    required int doneTasksCount,
    int postponedCount = 0,
    String? topPostponeReason,
    double? habitAdherencePct,
    num totalSpending = 0,
    int notesCount = 0,
    int ideasCount = 0,
  }) {
    final buffer = StringBuffer('ملخص $periodWords: ');
    buffer.write('أنجزت ${PluralAr.formatTasks(doneTasksCount)}');

    if (postponedCount > 0) {
      buffer.write('، وأجلت ${PluralAr.formatTasks(postponedCount)}');
      if (topPostponeReason != null && topPostponeReason.isNotEmpty) {
        buffer.write(' (أكتر سبب: $topPostponeReason)');
      }
    }

    if (habitAdherencePct != null && habitAdherencePct > 0) {
      final pct = (habitAdherencePct * 100).round();
      buffer.write('، ونسبة التزام العادات $pct%');
    }

    if (totalSpending > 0) {
      buffer.write('، وإجمالي المصاريف ${PluralAr.formatPounds(totalSpending)}');
    }

    if (notesCount > 0 || ideasCount > 0) {
      final extra = <String>[];
      if (notesCount > 0) extra.add(PluralAr.formatNotes(notesCount));
      if (ideasCount > 0) extra.add(PluralAr.formatIdeas(ideasCount));
      buffer.write('، وسجلت ${extra.join(' و')}');
    }

    return buffer.toString();
  }

  /// Composes spending answer (Section 6: spending)
  String composeSpending({
    required String periodWords,
    required num totalAmount,
    String? categoryName,
    List<({String name, num amount})> topCategories = const [],
    double? essentialPct,
    double? sidePct,
    String? comparisonText,
  }) {
    final buffer = StringBuffer();
    if (categoryName != null && categoryName.isNotEmpty) {
      buffer.write('صرفت على $categoryName في $periodWords ${PluralAr.formatPounds(totalAmount)}');
    } else {
      buffer.write('إجمالي مصاريفك في $periodWords هو ${PluralAr.formatPounds(totalAmount)}');
    }

    if (topCategories.isNotEmpty && categoryName == null) {
      final top = topCategories.first;
      buffer.write('، وأكتر حاجة صرفت عليها: ${top.name} (${PluralAr.formatPounds(top.amount)})');
    }

    if (essentialPct != null && sidePct != null && totalAmount > 0) {
      final ess = (essentialPct * 100).round();
      final side = (sidePct * 100).round();
      buffer.write('، الأساسي $ess% والجانبي $side%');
    }

    if (comparisonText != null && comparisonText.isNotEmpty) {
      buffer.write(' ($comparisonText)');
    }

    return buffer.toString();
  }

  /// Composes habit status answer (Section 6: habit_status)
  String composeHabitStatus({
    required String habitName,
    required num todayCount,
    String habitKey = '',
    int currentStreak = 0,
    bool isCompletedToday = false,
  }) {
    final buffer = StringBuffer();

    if (habitKey == 'coffee') {
      if (todayCount == 0) {
        buffer.write('ماشربتش ولا فنجان قهوة النهارده');
      } else {
        buffer.write('شربت النهارده ${PluralAr.formatCups(todayCount.toInt())}');
      }
    } else if (habitKey == 'water') {
      if (todayCount == 0) {
        buffer.write('ماشربتش مياه كفاية النهارده لسه');
      } else {
        buffer.write('شربت النهارده $todayCount لتر مياه');
      }
    } else {
      if (isCompletedToday || todayCount > 0) {
        buffer.write('أنجزت عادة $habitName النهارده، عاش!');
      } else {
        buffer.write('لسه مكملتش عادة $habitName النهارده');
      }
    }

    if (currentStreak > 0) {
      buffer.write('، ومستمر فيها بقالك ${PluralAr.formatDays(currentStreak)}');
    }

    return buffer.toString();
  }

  /// Composes pending tasks answer (Section 6: pending)
  String composePending({
    required String filterType, // 'overdue', 'postponed', 'waiting', 'all'
    required List<({String title, String? reason})> tasks,
  }) {
    String label = 'المتأخرة';
    if (filterType == 'postponed') label = 'المؤجلة';
    if (filterType == 'waiting') label = 'المعلقة (مستني)';
    if (filterType == 'all') label = 'المعلقة والمؤجلة';

    if (tasks.isEmpty) {
      return 'معندكش مهام $label حالياً، عاش!';
    }

    final buffer = StringBuffer('عندك ${PluralAr.formatTasks(tasks.length)} $label: ');
    final displayed = tasks.take(5).map((t) {
      if (t.reason != null && t.reason!.isNotEmpty) {
        return '${t.title} (${t.reason})';
      }
      return t.title;
    }).toList();

    buffer.write(displayed.join('، '));
    if (tasks.length > 5) {
      buffer.write('، وكمان ${PluralAr.formatTasks(tasks.length - 5)}');
    }

    return buffer.toString();
  }

  /// Composes obligations answer (Section 6: obligations)
  String composeObligations({
    required List<({String name, num amount, String dueDate})> lateObligations,
    required List<({String name, num amount, String dueDate})> upcomingObligations,
    required num totalDueAmount,
  }) {
    if (lateObligations.isEmpty && upcomingObligations.isEmpty) {
      return 'معندكش أي التزامات مالية مستحقة أو متأخرة حالياً، ممتاز!';
    }

    final buffer = StringBuffer('إجمالي الالتزامات المستحقة: ${PluralAr.formatPounds(totalDueAmount)}');
    if (lateObligations.isNotEmpty) {
      buffer.write('، ومعاك ${PluralAr.formatObligations(lateObligations.length)} متأخرة: ');
      buffer.write(lateObligations.take(5).map((o) => '${o.name} (${PluralAr.formatPounds(o.amount)})').join('، '));
      if (lateObligations.length > 5) {
        buffer.write('، وكمان ${PluralAr.formatObligations(lateObligations.length - 5)}');
      }
    }

    if (upcomingObligations.isNotEmpty) {
      buffer.write('، و${PluralAr.formatObligations(upcomingObligations.length)} قادمة هذا الشهر');
    }

    return buffer.toString();
  }

  /// Composes health pending answer (Section 6: health_pending)
  String composeHealthPending({
    required List<({String title, String status, int waitingDays, int waitingMonths})> items,
  }) {
    if (items.isEmpty) {
      return 'معندكش أي كشوفات أو تحاليل مؤجلة، صحتك بالدنيا!';
    }

    final buffer = StringBuffer('عندك ${PluralAr.formatCheckups(items.length)} في قائمة الانتظار الطبية: ');
    final displayed = items.take(5).map((i) {
      final duration = i.waitingMonths > 0 ? PluralAr.formatMonths(i.waitingMonths) : PluralAr.formatDays(i.waitingDays);
      return '${i.title} (بقاله $duration)';
    }).toList();

    buffer.write(displayed.join('، '));
    if (items.length > 5) {
      buffer.write('، وكمان ${PluralAr.formatCheckups(items.length - 5)}');
    }

    return buffer.toString();
  }

  /// Composes wishlist answer (Section 6: wishlist)
  String composeWishlist({
    required int itemCount,
    required num totalEstimatedPrice,
  }) {
    if (itemCount == 0) {
      return 'قائمة أمنيات المشتريات فاضية حالياً.';
    }

    final buffer = StringBuffer('عندك ${PluralAr.formatItems(itemCount, singular: 'حاجة', dual: 'حاجتين', plural: 'حاجات')} في قائمة المشتريات');
    if (totalEstimatedPrice > 0) {
      buffer.write(' بإجمالي تقديري ${PluralAr.formatPounds(totalEstimatedPrice)}');
    }

    return buffer.toString();
  }
}
