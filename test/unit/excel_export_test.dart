import 'dart:io';
import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:enjaz/core/db/app_database.dart';
import 'package:enjaz/features/excel_export/domain/excel_export_service.dart';
import 'package:enjaz/features/stats/domain/stats_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late DateTime now;
  late StatsDateRange weekRange;
  late StatsDateRange monthRange;
  late StatsDateRange yearRange;
  late StatsDateRange allTimeRange;

  late List<Task> sampleTasks;
  late List<TaskEvent> sampleEvents;
  late List<Goal> sampleGoals;
  late List<Milestone> sampleMilestones;
  late List<GoalUpdate> sampleGoalUpdates;
  late List<Idea> sampleIdeas;
  late List<VoiceNote> sampleVoiceNotes;

  setUpAll(() async {
    await initializeDateFormatting('ar', null);
    await initializeDateFormatting('en', null);

    tempDir = Directory.systemTemp.createTempSync('enjaz_excel_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return tempDir.path;
      },
    );
    now = DateTime(2026, 11, 6, 12, 0); // Friday

    weekRange = StatsService.resolveRange(type: StatsRangeType.week, referenceDate: now);
    monthRange = StatsService.resolveRange(type: StatsRangeType.month, referenceDate: now);
    yearRange = StatsService.resolveRange(type: StatsRangeType.year, referenceDate: now);
    allTimeRange = StatsService.resolveRange(type: StatsRangeType.allTime, referenceDate: now);

    final nowMs = now.millisecondsSinceEpoch;
    final yesterdayMs = now.subtract(const Duration(days: 1)).millisecondsSinceEpoch;
    final todayStr = '2026-11-06';
    final yesterdayStr = '2026-11-05';

    // 1. Completed task
    final taskCompleted = Task(
      id: 1,
      title: 'مهمة منجزة في الموعد',
      kind: 'task',
      priority: 'high',
      dueDate: yesterdayStr,
      dueTime: '10:00',
      status: 'done',
      progress: 100,
      postponeCount: 0,
      createdAt: yesterdayMs - 3600000,
      updatedAt: yesterdayMs,
      startedAt: yesterdayMs - 1800000,
      finishedAt: yesterdayMs,
      outcomeNote: 'تم التنفيذ بنجاح واكتمال المطلوب',
    );

    // 2. Postponed task
    final taskPostponed = Task(
      id: 2,
      title: 'مشوار مؤجل لظرف طارئ',
      kind: 'errand',
      priority: 'normal',
      dueDate: todayStr,
      status: 'postponed',
      progress: 0,
      postponeCount: 1,
      reasonText: 'ازدحام مروري',
      createdAt: nowMs - 7200000,
      updatedAt: nowMs,
    );

    // 3. Partial task
    final taskPartial = Task(
      id: 3,
      title: 'مراجعة التقرير الفصلي',
      kind: 'task',
      priority: 'normal',
      dueDate: todayStr,
      status: 'partial',
      progress: 50,
      postponeCount: 0,
      reasonText: 'انشغال باجتماع',
      createdAt: nowMs - 5000000,
      updatedAt: nowMs,
    );

    // 4. Undated inbox task
    final taskUndated = Task(
      id: 4,
      title: 'فكرة مهمة في صندوق الوارد بدون تاريخ',
      kind: 'task',
      priority: 'low',
      dueDate: null,
      status: 'todo',
      progress: 0,
      postponeCount: 0,
      createdAt: nowMs - 1000000,
      updatedAt: nowMs - 1000000,
    );

    sampleTasks = [taskCompleted, taskPostponed, taskPartial, taskUndated];

    sampleEvents = [
      TaskEvent(
        id: 1,
        taskId: 1,
        fromStatus: 'in_progress',
        toStatus: 'done',
        progress: 100,
        at: yesterdayMs,
        note: 'تم إنجاز المهمة كاملة',
        createdAt: yesterdayMs,
        updatedAt: yesterdayMs,
      ),
      TaskEvent(
        id: 2,
        taskId: 2,
        fromStatus: 'todo',
        toStatus: 'postponed',
        progress: 0,
        reasonText: 'ازدحام مروري',
        at: nowMs - 3600000,
        createdAt: nowMs - 3600000,
        updatedAt: nowMs - 3600000,
      ),
      TaskEvent(
        id: 3,
        taskId: 3,
        fromStatus: 'in_progress',
        toStatus: 'partial',
        progress: 50,
        reasonText: 'انشغال باجتماع',
        at: nowMs - 1800000,
        createdAt: nowMs - 1800000,
        updatedAt: nowMs - 1800000,
      ),
    ];

    sampleGoals = [
      Goal(
        id: 1,
        title: 'قراءة 10 كتب مفيدة',
        status: 'active',
        progressMode: 'numeric',
        targetValue: 10.0,
        currentValue: 3.0,
        unit: 'كتاب',
        createdAt: nowMs - 10000000,
        updatedAt: nowMs,
      ),
    ];

    sampleMilestones = [
      Milestone(
        id: 1,
        goalId: 1,
        title: 'إنهاء الكتاب الأول',
        status: 'done',
        sortOrder: 1,
        weight: 1,
        createdAt: nowMs - 10000000,
        updatedAt: yesterdayMs,
      ),
    ];

    sampleGoalUpdates = [
      GoalUpdate(
        id: 1,
        goalId: 1,
        valueDelta: 1.0,
        at: yesterdayMs,
        createdAt: yesterdayMs,
        updatedAt: yesterdayMs,
      ),
    ];

    sampleIdeas = [
      Idea(
        id: 1,
        title: 'تطوير أداة مساعدة ذكية',
        status: 'active',
        createdAt: nowMs - 8000000,
        updatedAt: nowMs,
      ),
    ];

    sampleVoiceNotes = [
      VoiceNote(
        id: 1,
        parentType: 'task',
        parentId: 1,
        fileName: 'note1.m4a',
        durationMs: 45000,
        sizeBytes: 120000,
        recordedAt: yesterdayMs,
        createdAt: yesterdayMs,
        updatedAt: yesterdayMs,
      ),
    ];
  });

  tearDownAll(() {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('Excel Export Service - Round 2 Acceptance Tests', () {
    const statsService = StatsService();
    const exportService = ExcelExportService();

    for (final testRange in [
      ('Week', () => weekRange),
      ('Month', () => monthRange),
      ('Year', () => yearRange),
      ('AllTime', () => allTimeRange),
    ]) {
      test('1. Exported report is not empty for range: ${testRange.$1}', () async {
        final range = testRange.$2();
        final stats = statsService.computeStats(
          range: range,
          tasks: sampleTasks,
          rangeEvents: sampleEvents,
          allDoneEvents: sampleEvents.where((e) => e.toStatus == 'done').toList(),
          previousPeriodCompletedCount: 0,
          goals: sampleGoals,
          milestones: sampleMilestones,
          goalUpdates: sampleGoalUpdates,
          ideas: sampleIdeas,
          now: now,
        );

        final file = await exportService.generateReport(
          range: range,
          stats: stats,
          tasks: sampleTasks,
          events: sampleEvents,
          goals: sampleGoals,
          milestones: sampleMilestones,
          goalUpdates: sampleGoalUpdates,
          ideas: sampleIdeas,
          voiceNotes: sampleVoiceNotes,
          languageCode: 'ar',
          outputDirectory: tempDir,
        );

        expect(file.existsSync(), isTrue);
        expect(file.lengthSync(), greaterThan(1000)); // Non-empty file

        // Read bytes as ZIP
        final bytes = file.readAsBytesSync();
        final archive = ZipDecoder().decodeBytes(bytes);

        // Verify OpenXML DrawingML injection exists
        final drawingXml = archive.findFile('xl/drawings/drawing1.xml');
        expect(drawingXml, isNotNull, reason: 'drawing1.xml should be present in xlsx archive');

        final drawingRels = archive.findFile('xl/drawings/_rels/drawing1.xml.rels');
        expect(drawingRels, isNotNull, reason: 'drawing1.xml.rels should be present');

        // Verify 4 embedded chart images
        for (int i = 1; i <= 4; i++) {
          final imgFile = archive.findFile('xl/media/image$i.png');
          expect(imgFile, isNotNull, reason: 'Embedded chart image $i should exist in xl/media/');
          expect((imgFile!.content as List<int>).length, greaterThan(100));
        }

        // Verify with Excel parser
        final excel = Excel.decodeBytes(bytes);

        // 2. Dashboard sheet comes first and is named 'لوحة المتابعة'
        final defaultSheet = excel.getDefaultSheet();
        expect(defaultSheet, equals('لوحة المتابعة'));

        // Verify all 8 sheets are present
        expect(excel.tables.containsKey('لوحة المتابعة'), isTrue);
        expect(excel.tables.containsKey('الملخص'), isTrue);
        expect(excel.tables.containsKey('المهام'), isTrue);
        expect(excel.tables.containsKey('السجل'), isTrue);
        expect(excel.tables.containsKey('يومي'), isTrue);
        expect(excel.tables.containsKey('الأسباب'), isTrue);
        expect(excel.tables.containsKey('الأهداف'), isTrue);
        expect(excel.tables.containsKey('الأفكار'), isTrue);

        // Verify RTL flag is set for Arabic
        expect(excel['لوحة المتابعة'].isRTL, isTrue);

        // Verify Tasks sheet has rows for our tasks
        final tasksSheet = excel['المهام'];
        expect(tasksSheet.rows.length, greaterThanOrEqualTo(2)); // Header + at least one task row

        // Verify KPI numbers match Stats calculations
        expect(stats.completedCount, equals(1));
        expect(stats.postponedCount, equals(1));
        expect(stats.partialCount, equals(1));
      });
    }

    test('2. Empty range displays clean "No data" note without crashing', () async {
      final emptyRange = StatsDateRange(
        type: StatsRangeType.week,
        start: DateTime(2025, 1, 1),
        end: DateTime(2025, 1, 7),
      );

      final emptyStats = statsService.computeStats(
        range: emptyRange,
        tasks: [],
        rangeEvents: [],
        allDoneEvents: [],
        previousPeriodCompletedCount: 0,
        now: now,
      );

      final file = await exportService.generateReport(
        range: emptyRange,
        stats: emptyStats,
        tasks: [],
        events: [],
        goals: [],
        milestones: [],
        goalUpdates: [],
        ideas: [],
        voiceNotes: [],
        languageCode: 'ar',
        outputDirectory: tempDir,
      );

      expect(file.existsSync(), isTrue);
      final excel = Excel.decodeBytes(file.readAsBytesSync());
      final summarySheet = excel['الملخص'];
      expect(summarySheet.rows.length, greaterThanOrEqualTo(2));
      // First row header, second row empty note
      final noteCell = summarySheet.rows[1][1]?.value.toString();
      expect(noteCell, contains('لا توجد بيانات'));
    });

    test('6. Acceptance test: Excel report contains the finance sheets', () async {
      final range = StatsDateRange(
        type: StatsRangeType.month,
        start: DateTime(2026, 11, 1),
        end: DateTime(2026, 11, 30),
      );
      final stats = statsService.computeStats(
        range: range,
        tasks: [],
        rangeEvents: [],
        allDoneEvents: [],
        previousPeriodCompletedCount: 0,
        now: DateTime(2026, 11, 15),
      );

      final file = await exportService.generateReport(
        range: range,
        stats: stats,
        tasks: [],
        events: [],
        goals: [],
        milestones: [],
        goalUpdates: [],
        ideas: [],
        voiceNotes: [],
        transactions: [
          Transaction(
            id: 1,
            kind: 'expense',
            amountMinor: 2500,
            categoryId: 1,
            nature: 'side',
            occurredAt: 1730000000000,
            localDate: '2026-11-05',
            createdAt: 1730000000000,
            updatedAt: 1730000000000,
          ),
        ],
        financeCategories: [
          const FinanceCategory(
            id: 1,
            nameAr: 'شاي وقهوة',
            nameEn: 'Tea & Coffee',
            kind: 'expense',
            nature: 'side',
            color: 0xFF795548,
            isDefault: true,
            archived: false,
            sortOrder: 1,
            createdAt: 0,
            updatedAt: 0,
          ),
        ],
        obligations: [
          const Obligation(
            id: 1,
            name: 'إيجار',
            kind: 'installment',
            amountMinor: 250000,
            frequency: 'monthly',
            startDate: '2026-11-01',
            createdAt: 0,
            updatedAt: 0,
          ),
        ],
        obligationInstances: [
          const ObligationInstance(
            id: 1,
            obligationId: 1,
            dueDate: '2026-11-05',
            amountMinor: 250000,
            status: 'paid',
            createdAt: 0,
            updatedAt: 0,
          ),
        ],
        wishlistItems: [
          const WishlistItem(
            id: 1,
            name: 'سماعات',
            estimatedPriceMinor: 150000,
            priority: 'normal',
            status: 'wanted',
            createdAt: 0,
            updatedAt: 0,
          ),
        ],
        languageCode: 'ar',
        outputDirectory: tempDir,
      );

      expect(file.existsSync(), isTrue);
      final excel = Excel.decodeBytes(file.readAsBytesSync());
      expect(excel.tables.keys, contains('المعاملات'));
      expect(excel.tables.keys, contains('الالتزامات'));
      expect(excel.tables.keys, contains('المشتريات'));
      expect(excel.tables.keys, contains('ملخص المال'));
    });

    test('7. Acceptance test: Round 7 extended Excel report includes Habits, Notes, and Health sheets', () async {
      final range = StatsDateRange(
        type: StatsRangeType.month,
        start: DateTime(2026, 11, 1),
        end: DateTime(2026, 11, 30),
      );
      final stats = statsService.computeStats(
        range: range,
        tasks: [],
        rangeEvents: [],
        allDoneEvents: [],
        previousPeriodCompletedCount: 0,
        now: DateTime(2026, 11, 15),
      );

      final file = await exportService.generateReport(
        range: range,
        stats: stats,
        tasks: [],
        events: [],
        goals: [],
        milestones: [],
        goalUpdates: [],
        ideas: [],
        voiceNotes: [],
        habits: [
          const Habit(
            id: 1,
            nameAr: 'شرب الماء',
            nameEn: 'Drink Water',
            type: 'count',
            unit: 'كوب',
            dailyTarget: 8.0,
            scheduleDays: 127,
            sortOrder: 1,
            archived: false,
            createdAt: 0,
            updatedAt: 0,
          ),
        ],
        habitLogs: [
          const HabitLog(
            id: 1,
            habitId: 1,
            logDate: '2026-11-05',
            value: 2.0,
            at: 1730000000000,
            createdAt: 0,
            updatedAt: 0,
          ),
        ],
        notes: [
          const Note(
            id: 1,
            body: 'ملاحظة تجريبية لاختبار الإكسيل',
            kind: 'note',
            pinned: false,
            createdAt: 0,
            updatedAt: 0,
          ),
        ],
        healthItems: [
          const HealthItem(
            id: 1,
            title: 'فحص دوري شامل',
            kind: 'checkup',
            status: 'done',
            neededSince: '2026-11-01',
            occurredAt: 1730000000000,
            localDate: '2026-11-05',
            followUpNeeded: false,
            postponeCount: 0,
            createdAt: 0,
            updatedAt: 0,
          ),
        ],
        treatments: [
          const Treatment(
            id: 1,
            name: 'فيتامين د',
            adherence: 'following',
            startDate: '2026-11-01',
            purchased: true,
            occurredAt: 1730000000000,
            localDate: '2026-11-01',
            createdAt: 0,
            updatedAt: 0,
          ),
        ],
        languageCode: 'ar',
        outputDirectory: tempDir,
      );

      expect(file.existsSync(), isTrue);
      final excel = Excel.decodeBytes(file.readAsBytesSync());
      expect(excel.tables.keys, contains('العادات'));
      expect(excel.tables.keys, contains('الملاحظات'));
      expect(excel.tables.keys, contains('الصحة'));
    });

    test('8. Acceptance test Batch 3: Excel numbers equal dashboard/Stats across week, month, year, and all time', () async {
      for (final rangeType in [
        StatsRangeType.week,
        StatsRangeType.month,
        StatsRangeType.year,
        StatsRangeType.allTime,
      ]) {
        final range = StatsService.resolveRange(type: rangeType, referenceDate: now);
        final stats = statsService.computeStats(
          range: range,
          tasks: sampleTasks,
          rangeEvents: sampleEvents,
          allDoneEvents: sampleEvents.where((e) => e.toStatus == 'done').toList(),
          previousPeriodCompletedCount: 0,
          goals: sampleGoals,
          milestones: sampleMilestones,
          goalUpdates: sampleGoalUpdates,
          ideas: sampleIdeas,
          now: now,
        );

        final file = await exportService.generateReport(
          range: range,
          stats: stats,
          tasks: sampleTasks,
          events: sampleEvents,
          goals: sampleGoals,
          milestones: sampleMilestones,
          goalUpdates: sampleGoalUpdates,
          ideas: sampleIdeas,
          voiceNotes: sampleVoiceNotes,
          languageCode: 'ar',
          outputDirectory: tempDir,
        );

        expect(file.existsSync(), isTrue);
        final bytes = file.readAsBytesSync();
        final excel = Excel.decodeBytes(bytes);

        // 1. All sheets must have isRTL == true for Arabic
        for (final table in excel.tables.values) {
          expect(table.isRTL, isTrue, reason: 'Sheet ${table.sheetName} should be RTL for Arabic');
        }

        // 2. Dashboard Sheet (لوحة المتابعة) KPI row numbers must match StatsResult exactly
        final dashboardSheet = excel['لوحة المتابعة'];
        final headerIndex = dashboardSheet.rows.indexWhere(
          (row) => row.isNotEmpty && row[0]?.value.toString() == 'المهام المنجزة',
        );
        expect(headerIndex, isNot(-1), reason: 'Dashboard sheet should contain KPI header row');
        final kpiRow = dashboardSheet.rows[headerIndex + 1];

        // Completed count
        final cellCompleted = kpiRow[0]?.value.toString();
        expect(int.tryParse(cellCompleted ?? ''), equals(stats.completedCount));

        // Completion rate
        final cellRate = kpiRow[1]?.value.toString();
        expect(cellRate, equals('${stats.completionRate.round()}%'));

        // Postponed count
        final cellPostponed = kpiRow[2]?.value.toString();
        expect(int.tryParse(cellPostponed ?? ''), equals(stats.postponedCount));

        // Partial count
        final cellPartial = kpiRow[3]?.value.toString();
        expect(int.tryParse(cellPartial ?? ''), equals(stats.partialCount));

        // Best streak
        final cellStreak = kpiRow[5]?.value.toString();
        expect(int.tryParse(cellStreak ?? ''), equals(stats.bestStreak));

        // 3. Summary Sheet (الملخص) metrics must match StatsResult
        final summarySheet = excel['الملخص'];
        final completedSummaryRow = summarySheet.rows.firstWhere(
          (r) => r.isNotEmpty && r[0]?.value.toString() == 'المهام المنجزة',
        );
        expect(completedSummaryRow[1]?.value.toString(), equals(stats.completedCount.toString()));

        final scheduledSummaryRow = summarySheet.rows.firstWhere(
          (r) => r.isNotEmpty && r[0]?.value.toString() == 'المهام المجدولة',
        );
        expect(scheduledSummaryRow[1]?.value.toString(), equals(stats.scheduledCount.toString()));

        final postponedSummaryRow = summarySheet.rows.firstWhere(
          (r) => r.isNotEmpty && r[0]?.value.toString() == 'المهام المؤجلة',
        );
        expect(postponedSummaryRow[1]?.value.toString(), equals(stats.postponedCount.toString()));
      }
    });
  });
}
