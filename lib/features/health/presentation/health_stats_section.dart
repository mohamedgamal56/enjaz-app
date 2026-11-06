import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/utils/app_formatter.dart';
import '../../../core/utils/numerals_formatter.dart';
import '../domain/health_service.dart';
import 'health_icon_helper.dart';

class HealthStatsSection extends ConsumerWidget {
  final DateTime referenceDate;

  const HealthStatsSection({
    super.key,
    required this.referenceDate,
  });

  Widget _buildKpiCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: color.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final numeralsFormat = ref.watch(numeralsProvider);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final theme = Theme.of(context);
    const healthService = HealthService();

    return StreamBuilder<List<HealthItem>>(
      stream: db.watchActiveHealthItems(),
      builder: (context, activeSnap) {
        return StreamBuilder<List<HealthItem>>(
          stream: db.watchDoneHealthItems(),
          builder: (context, doneSnap) {
            return StreamBuilder<List<Treatment>>(
              stream: db.watchActiveTreatments(),
              builder: (context, treatSnap) {
                final allItems = [...(activeSnap.data ?? []), ...(doneSnap.data ?? [])];
                final treatments = treatSnap.data ?? [];

                // For checks, let's load all active treatments checks or compute directly
                return FutureBuilder<List<TreatmentCheck>>(
                  future: db.select(db.treatmentChecks).get(),
                  builder: (context, checkSnap) {
                    final allChecks = checkSnap.data ?? [];

                    final metrics = healthService.computeHealthMetrics(
                      items: allItems,
                      treatments: treatments,
                      allChecks: allChecks,
                      today: referenceDate,
                    );

                    final adherenceRounded = metrics.overallTreatmentAdherence.round();
                    final adherenceStr = '${NumeralsFormatter.format(adherenceRounded.toString(), numeralsFormat)}%';

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // KPI Grid
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1.45,
                          children: [
                            _buildKpiCard(
                              context,
                              title: isArabic ? 'فحوصات مطلوبة' : 'Needed Checkups',
                              value: NumeralsFormatter.format(metrics.neededCount.toString(), numeralsFormat),
                              icon: Icons.assignment_late_outlined,
                              color: Colors.orange,
                            ),
                            _buildKpiCard(
                              context,
                              title: isArabic ? 'مواعيد مجدولة' : 'Scheduled Visits',
                              value: NumeralsFormatter.format(metrics.scheduledCount.toString(), numeralsFormat),
                              icon: Icons.event_available_rounded,
                              color: Colors.blue,
                            ),
                            _buildKpiCard(
                              context,
                              title: isArabic ? 'أُنجزت هذا العام' : 'Done This Year',
                              value: NumeralsFormatter.format(metrics.checkupsDoneThisYear.toString(), numeralsFormat),
                              icon: Icons.check_circle_outline_rounded,
                              color: Colors.green,
                            ),
                            _buildKpiCard(
                              context,
                              title: isArabic ? 'الالتزام بالعلاج' : 'Adherence Rate',
                              value: adherenceStr,
                              icon: Icons.medication_rounded,
                              color: Colors.purple,
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Longest Waiting Items Card
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.timer_outlined, size: 20, color: Colors.orange),
                                    const SizedBox(width: 8),
                                    Text(
                                      isArabic ? 'أطول الفحوصات انتظاراً' : 'Longest-waiting Checkups',
                                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const Divider(height: 20),
                                if (metrics.longestWaitingItems.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                                    child: Text(
                                      isArabic ? 'لا توجد فحوصات معلقة في الانتظار' : 'No pending checkups waiting',
                                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                                    ),
                                  )
                                else
                                  ...metrics.longestWaitingItems.map((item) {
                                    final waiting = healthService.calculateWaitingDuration(item.neededSince);
                                    final waitingStr = waiting.format(isArabic, numerals: numeralsFormat);

                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 10.0),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 14,
                                            backgroundColor: HealthIconHelper.getStatusColor(item.status).withValues(alpha: 0.15),
                                            child: Icon(
                                              HealthIconHelper.getKindIcon(item.kind),
                                              size: 14,
                                              color: HealthIconHelper.getStatusColor(item.status),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              item.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              waitingStr,
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.deepOrange),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Upcoming Appointments Card
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.event_note_rounded, size: 20, color: Colors.blue),
                                    const SizedBox(width: 8),
                                    Text(
                                      isArabic ? 'المواعيد الطبية القادمة' : 'Upcoming Medical Appointments',
                                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const Divider(height: 20),
                                if (metrics.upcomingAppointments.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                                    child: Text(
                                      isArabic ? 'لا توجد مواعيد كشوفات مجدولة قريباً' : 'No upcoming appointments scheduled',
                                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                                    ),
                                  )
                                else
                                  ...metrics.upcomingAppointments.map((item) {
                                    final dateStr = item.scheduledAt != null
                                        ? AppFormatter.formatDateTime(
                                            DateTime.fromMillisecondsSinceEpoch(item.scheduledAt!),
                                            locale: Localizations.localeOf(context).toString(),
                                            format: numeralsFormat,
                                          )
                                        : '';

                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 10.0),
                                      child: Row(
                                        children: [
                                          const CircleAvatar(
                                            radius: 14,
                                            backgroundColor: Color(0x1F2196F3),
                                            child: Icon(Icons.medical_services_rounded, size: 14, color: Colors.blue),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item.title,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                                                ),
                                                if (item.placeOrDoctor != null && item.placeOrDoctor!.isNotEmpty)
                                                  Text(
                                                    item.placeOrDoctor!,
                                                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              dateStr,
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
