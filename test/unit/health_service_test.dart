import 'package:flutter_test/flutter_test.dart';
import 'package:enjaz/features/health/domain/health_service.dart';
import 'package:enjaz/core/db/app_database.dart';

void main() {
  const service = HealthService();

  group('HealthService - calculateWaitingDuration', () {
    test('calculates waiting duration in days and months accurately', () {
      final today = DateTime(2026, 11, 6);

      // Same day
      final duration0 = service.calculateWaitingDuration('2026-11-06', today);
      expect(duration0.totalDays, 0);
      expect(duration0.months, 0);

      // 10 days ago
      final duration10 = service.calculateWaitingDuration('2026-10-27', today);
      expect(duration10.totalDays, 10);
      expect(duration10.months, 0);
      expect(duration10.format(true), 'محتاج من 10 يوم');

      // 90 days ago (~3 months)
      final duration90 = service.calculateWaitingDuration('2026-08-08', today);
      expect(duration90.totalDays, 90);
      expect(duration90.months, 3);
      expect(duration90.format(true), 'محتاج من 3 شهر');
      expect(duration90.format(false), 'needed for 3 mo');
    });
  });

  group('HealthService - calculateTreatmentAdherence', () {
    test('computes adherence percentage based on active days and checks', () {
      final today = DateTime(2026, 11, 10);
      const startDate = '2026-11-01';
      const endDate = '2026-11-10'; // 10 days total

      // 8 days taken out of 10 days
      final checks = [
        const TreatmentCheck(id: 1, treatmentId: 1, checkDate: '2026-11-01', taken: true, createdAt: 0, updatedAt: 0),
        const TreatmentCheck(id: 2, treatmentId: 1, checkDate: '2026-11-02', taken: true, createdAt: 0, updatedAt: 0),
        const TreatmentCheck(id: 3, treatmentId: 1, checkDate: '2026-11-03', taken: true, createdAt: 0, updatedAt: 0),
        const TreatmentCheck(id: 4, treatmentId: 1, checkDate: '2026-11-04', taken: true, createdAt: 0, updatedAt: 0),
        const TreatmentCheck(id: 5, treatmentId: 1, checkDate: '2026-11-05', taken: true, createdAt: 0, updatedAt: 0),
        const TreatmentCheck(id: 6, treatmentId: 1, checkDate: '2026-11-06', taken: true, createdAt: 0, updatedAt: 0),
        const TreatmentCheck(id: 7, treatmentId: 1, checkDate: '2026-11-07', taken: true, createdAt: 0, updatedAt: 0),
        const TreatmentCheck(id: 8, treatmentId: 1, checkDate: '2026-11-08', taken: true, createdAt: 0, updatedAt: 0),
      ];

      final metrics = service.calculateTreatmentAdherence(
        startDate: startDate,
        endDate: endDate,
        checks: checks,
        today: today,
      );

      expect(metrics.totalDays, 10);
      expect(metrics.takenDays, 8);
      expect(metrics.adherencePercent, 80.0);
      expect(metrics.formatPercent(), '80%');
    });

    test('returns 0 when no checks recorded', () {
      final today = DateTime(2026, 11, 5);
      final metrics = service.calculateTreatmentAdherence(
        startDate: '2026-11-01',
        endDate: '2026-11-05',
        checks: [],
        today: today,
      );
      expect(metrics.totalDays, 5);
      expect(metrics.takenDays, 0);
      expect(metrics.adherencePercent, 0.0);
    });
  });

  group('HealthService - getNextRecurringDate', () {
    test('adds months correctly across calendar years', () {
      final doneDate = DateTime(2026, 8, 15);

      // 6 months later
      final next6 = service.getNextRecurringDate(doneDate, 6);
      expect(next6.year, 2027);
      expect(next6.month, 2);
      expect(next6.day, 15);

      // 12 months later
      final next12 = service.getNextRecurringDate(doneDate, 12);
      expect(next12.year, 2027);
      expect(next12.month, 8);
      expect(next12.day, 15);
    });
  });

  group('HealthService - computeHealthMetrics', () {
    test('aggregates counts, upcoming appointments, and longest waiting items', () {
      final now = DateTime(2026, 11, 6, 12, 0);
      final nowMs = now.millisecondsSinceEpoch;

      final items = [
        HealthItem(
          id: 1,
          title: 'تحليل دم شامل',
          kind: 'test',
          status: 'needed',
          neededSince: '2026-08-01', // longest waiting
          dueBy: null,
          scheduledAt: null,
          placeOrDoctor: null,
          doneAt: null,
          resultNote: null,
          followUpNeeded: false,
          postponeCount: 0,
          postponedReason: null,
          repeatEveryMonths: null,
          costMinor: null,
          occurredAt: 0,
          localDate: '2026-08-01',
          createdAt: 0,
          updatedAt: 0,
        ),
        HealthItem(
          id: 2,
          title: 'كشف أسنان دوري',
          kind: 'dental',
          status: 'scheduled',
          neededSince: '2026-10-01',
          dueBy: null,
          scheduledAt: nowMs + (1000 * 60 * 60 * 24 * 2), // in 2 days
          placeOrDoctor: 'د. سامي',
          doneAt: null,
          resultNote: null,
          followUpNeeded: false,
          postponeCount: 0,
          postponedReason: null,
          repeatEveryMonths: 6,
          costMinor: null,
          occurredAt: 0,
          localDate: '2026-10-01',
          createdAt: 0,
          updatedAt: 0,
        ),
        HealthItem(
          id: 3,
          title: 'فحص عيون سنوي',
          kind: 'checkup',
          status: 'done',
          neededSince: '2026-01-01',
          dueBy: null,
          scheduledAt: null,
          placeOrDoctor: 'مركز النور',
          doneAt: DateTime(2026, 5, 10).millisecondsSinceEpoch,
          resultNote: 'النظر 6/6',
          followUpNeeded: false,
          postponeCount: 0,
          postponedReason: null,
          repeatEveryMonths: 12,
          costMinor: 30000,
          occurredAt: 0,
          localDate: '2026-01-01',
          createdAt: 0,
          updatedAt: 0,
        ),
      ];

      final treatments = [
        const Treatment(
          id: 1,
          healthItemId: null,
          name: 'فيتامين د',
          instructionsNote: 'قرص أسبوعياً',
          startDate: '2026-11-01',
          endDate: '2026-11-05',
          purchased: true,
          purchasedAt: null,
          purchaseCostMinor: 15000,
          adherence: 'following',
          stoppedReason: null,
          note: null,
          occurredAt: 0,
          localDate: '2026-11-01',
          createdAt: 0,
          updatedAt: 0,
        ),
      ];

      final checks = [
        const TreatmentCheck(id: 1, treatmentId: 1, checkDate: '2026-11-01', taken: true, createdAt: 0, updatedAt: 0),
        const TreatmentCheck(id: 2, treatmentId: 1, checkDate: '2026-11-02', taken: true, createdAt: 0, updatedAt: 0),
        const TreatmentCheck(id: 3, treatmentId: 1, checkDate: '2026-11-03', taken: true, createdAt: 0, updatedAt: 0),
        const TreatmentCheck(id: 4, treatmentId: 1, checkDate: '2026-11-04', taken: true, createdAt: 0, updatedAt: 0),
        const TreatmentCheck(id: 5, treatmentId: 1, checkDate: '2026-11-05', taken: true, createdAt: 0, updatedAt: 0),
      ]; // 5 out of 5 = 100%

      final metrics = service.computeHealthMetrics(
        items: items,
        treatments: treatments,
        allChecks: checks,
        today: now,
      );

      expect(metrics.neededCount, 1);
      expect(metrics.scheduledCount, 1);
      expect(metrics.doneCount, 1);
      expect(metrics.checkupsDoneThisYear, 1);
      expect(metrics.longestWaitingItems.first.title, 'تحليل دم شامل');
      expect(metrics.upcomingAppointments.first.title, 'كشف أسنان دوري');
      expect(metrics.overallTreatmentAdherence, 100.0);
    });
  });
}
