import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/money_formatter.dart';
import 'health_event_history_sheet.dart';

class HealthHistoryTab extends ConsumerWidget {
  const HealthHistoryTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final numeralsFormat = ref.watch(numeralsProvider);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final theme = Theme.of(context);

    return StreamBuilder<List<HealthItem>>(
      stream: db.watchDoneHealthItems(),
      builder: (context, snapshot) {
        final items = snapshot.data ?? [];

        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.history_rounded,
                  size: 64,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(height: 12),
                Text(
                  isArabic ? 'سجل الفحوصات المنجزة فارغ حالياً' : 'No completed checkups yet',
                  style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.outline),
                ),
                const SizedBox(height: 8),
                Text(
                  isArabic ? 'الفحوصات والكشوفات التي تكتمل ستظهر هنا' : 'Completed checkups and tests will appear here',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final doneDateStr = item.doneAt != null
                ? AppFormatter.formatDate(
                    DateTime.fromMillisecondsSinceEpoch(item.doneAt!),
                    locale: Localizations.localeOf(context).toString(),
                    format: numeralsFormat,
                  )
                : '';

            return Card(
              margin: const EdgeInsets.only(bottom: 12.0),
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.green.withValues(alpha: 0.15),
                          child: const Icon(Icons.check_circle_rounded, size: 20, color: Colors.green),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              if (item.placeOrDoctor != null && item.placeOrDoctor!.isNotEmpty)
                                Text(
                                  item.placeOrDoctor!,
                                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                                ),
                            ],
                          ),
                        ),
                        // Date badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            doneDateStr,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                        ),
                      ],
                    ),

                    // Result note
                    if (item.resultNote != null && item.resultNote!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.description_outlined, size: 16, color: Colors.teal),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.resultNote!,
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Badges row (follow-up, cost, recurring)
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (item.followUpNeeded)
                          Chip(
                            label: Text(
                              isArabic ? 'مطلوب متابعة' : 'Follow-up needed',
                              style: const TextStyle(fontSize: 11),
                            ),
                            backgroundColor: Colors.amber.withValues(alpha: 0.15),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        if (item.costMinor != null && item.costMinor! > 0)
                          Chip(
                            label: Text(
                              MoneyFormatter.formatWithCurrency(
                                item.costMinor!,
                                currency: isArabic ? 'ج.م' : 'EGP',
                                format: numeralsFormat,
                              ),
                              style: const TextStyle(fontSize: 11),
                            ),
                            backgroundColor: Colors.blue.withValues(alpha: 0.1),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        if (item.repeatEveryMonths != null)
                          Chip(
                            label: Text(
                              isArabic ? 'يتكرر كل ${item.repeatEveryMonths} شهور' : 'Repeats every ${item.repeatEveryMonths} mo',
                              style: const TextStyle(fontSize: 11),
                            ),
                            backgroundColor: Colors.purple.withValues(alpha: 0.1),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                      ],
                    ),

                    const Divider(height: 18),
                    // Actions
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              builder: (_) => HealthEventHistorySheet(item: item),
                            );
                          },
                          icon: const Icon(Icons.history_rounded, size: 16),
                          label: Text(isArabic ? 'سجل الإجراءات' : 'View History', style: const TextStyle(fontSize: 12)),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error, size: 20),
                          tooltip: isArabic ? 'حذف' : 'Delete',
                          onPressed: () {
                            db.softDeleteHealthItem(item.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(isArabic ? 'تم نقل الفحص إلى السلة' : 'Moved to trash')),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
