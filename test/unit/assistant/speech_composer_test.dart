import 'package:flutter_test/flutter_test.dart';
import 'package:enjaz/features/assistant/speech_composer.dart';

void main() {
  group('SpeechComposer Unit Tests (VOICE.md Step 4 & Section 6)', () {
    const composer = SpeechComposer();

    test('composeAgenda formats single date with tasks and 5-item limit', () {
      final speech = composer.composeAgenda(
        targetDateWords: 'يوم الخميس 12 نوفمبر 2026',
        taskTitles: [
          'تسليم الفيديوهات',
          'مراجعة الحسابات',
          'كتابة المقال',
          'شراء مستلزمات',
          'جلسة جيم',
          'قراءة كتاب',
          'شرب قهوة',
        ],
        overdueCount: 2,
        obligationsCount: 1,
        healthCount: 1,
        pendingHabits: ['القراءة', 'الرياضة'],
      );

      expect(speech, contains('وراك في يوم الخميس 12 نوفمبر 2026: 7 مهام'));
      expect(speech, contains('وكمان مهمتين'));
      expect(speech, contains('ومعاك مهمتين متأخرة'));
      expect(speech, contains('والتزام مستحق'));
      expect(speech, contains('وكشف'));
      expect(speech, contains('وعادات لسه مكملتهاش: القراءة، الرياضة'));
    });

    test('composeAgenda handles empty state cleanly', () {
      final speech = composer.composeAgenda(
        targetDateWords: 'النهارده',
        taskTitles: const [],
      );

      expect(speech, equals('في النهارده معندكش مهام مجدولة ولا التزامات، يومك رايق!'));
    });

    test('composeRecap formats done, postponed with reason, spending, and habits', () {
      final speech = composer.composeRecap(
        periodWords: 'إمبارح',
        doneTasksCount: 5,
        postponedCount: 2,
        topPostponeReason: 'مضغوط في الشغل',
        habitAdherencePct: 0.80,
        totalSpending: 250,
        notesCount: 2,
        ideasCount: 1,
      );

      expect(speech, contains('ملخص إمبارح: أنجزت 5 مهام'));
      expect(speech, contains('وأجلت مهمتين (أكتر سبب: مضغوط في الشغل)'));
      expect(speech, contains('ونسبة التزام العادات 80%'));
      expect(speech, contains('وإجمالي المصاريف 250 جنيه'));
      expect(speech, contains('وسجلت ملاحظتين وفكرة'));
    });

    test('composeSpending formats overall spending with top categories and essential vs side', () {
      final speech = composer.composeSpending(
        periodWords: 'الشهر ده',
        totalAmount: 1500,
        topCategories: const [
          (name: 'طعام ومطاعم', amount: 800),
          (name: 'مواصلات وبنزين', amount: 400),
        ],
        essentialPct: 0.70,
        sidePct: 0.30,
        comparisonText: 'أقل 10% من الشهر السابق',
      );

      expect(speech, contains('إجمالي مصاريفك في الشهر ده هو 1500 جنيه'));
      expect(speech, contains('وأكتر حاجة صرفت عليها: طعام ومطاعم (800 جنيه)'));
      expect(speech, contains('الأساسي 70% والجانبي 30%'));
      expect(speech, contains('(أقل 10% من الشهر السابق)'));
    });

    test('composeSpending formats specific category query', () {
      final speech = composer.composeSpending(
        periodWords: 'الشهر ده',
        totalAmount: 350,
        categoryName: 'أكل بره',
      );

      expect(speech, equals('صرفت على أكل بره في الشهر ده 350 جنيه'));
    });

    test('composeHabitStatus formats coffee habit with cups count and streak', () {
      final speech = composer.composeHabitStatus(
        habitName: 'القهوة',
        habitKey: 'coffee',
        todayCount: 2,
        currentStreak: 12,
      );

      expect(speech, contains('شربت النهارده فنجانين'));
      expect(speech, contains('ومستمر فيها بقالك 12 يوم'));
    });

    test('composeHabitStatus formats check habit when completed', () {
      final speech = composer.composeHabitStatus(
        habitName: 'صلاة الفجر',
        habitKey: 'prayer',
        todayCount: 1,
        currentStreak: 5,
        isCompletedToday: true,
      );

      expect(speech, contains('أنجزت عادة صلاة الفجر النهارده، عاش!'));
      expect(speech, contains('ومستمر فيها بقالك 5 أيام'));
    });

    test('composePending formats overdue tasks list', () {
      final speech = composer.composePending(
        filterType: 'overdue',
        tasks: const [
          (title: 'مراجعة الميزانية', reason: 'مفيش وقت'),
          (title: 'تسليم التقرير', reason: null),
        ],
      );

      expect(speech, contains('عندك مهمتين المتأخرة: مراجعة الميزانية (مفيش وقت)، تسليم التقرير'));
    });

    test('composePending handles empty overdue state', () {
      final speech = composer.composePending(
        filterType: 'overdue',
        tasks: const [],
      );

      expect(speech, equals('معندكش مهام المتأخرة حالياً، عاش!'));
    });

    test('composeObligations formats late and upcoming obligations', () {
      final speech = composer.composeObligations(
        lateObligations: const [
          (name: 'فاتورة الكهرباء', amount: 200, dueDate: '2026-11-01'),
        ],
        upcomingObligations: const [
          (name: 'قسط اللابتوب', amount: 1000, dueDate: '2026-11-20'),
          (name: 'اشتراك النت', amount: 300, dueDate: '2026-11-25'),
        ],
        totalDueAmount: 1500,
      );

      expect(speech, contains('إجمالي الالتزامات المستحقة: 1500 جنيه'));
      expect(speech, contains('ومعاك التزام متأخرة: فاتورة الكهرباء (200 جنيه)'));
      expect(speech, contains('والتزامين قادمة هذا الشهر'));
    });

    test('composeHealthPending formats checkups list with waiting duration', () {
      final speech = composer.composeHealthPending(
        items: const [
          (title: 'كشف أسنان', status: 'مطلوب', waitingDays: 45, waitingMonths: 1),
          (title: 'تحليل سكر', status: 'مؤجل', waitingDays: 10, waitingMonths: 0),
        ],
      );

      expect(speech, contains('عندك كشفين في قائمة الانتظار الطبية:'));
      expect(speech, contains('كشف أسنان (بقاله شهر)'));
      expect(speech, contains('تحليل سكر (بقاله 10 أيام)'));
    });

    test('composeWishlist formats wishlist totals', () {
      final speech = composer.composeWishlist(
        itemCount: 3,
        totalEstimatedPrice: 4500,
      );

      expect(speech, contains('عندك 3 حاجات في قائمة المشتريات بإجمالي تقديري 4500 جنيه'));
    });
  });
}
