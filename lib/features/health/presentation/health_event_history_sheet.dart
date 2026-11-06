import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/utils/date_formatter.dart';
import 'health_icon_helper.dart';

class HealthEventHistorySheet extends ConsumerWidget {
  final HealthItem item;

  const HealthEventHistorySheet({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final numeralsFormat = ref.watch(numeralsProvider);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: HealthIconHelper.getStatusColor(item.status).withValues(alpha: 0.15),
                      child: Icon(
                        HealthIconHelper.getKindIcon(item.kind),
                        color: HealthIconHelper.getStatusColor(item.status),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            isArabic ? 'سجل الإجراءات وتغيير الحالات' : 'Status change audit history',
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Events stream
              Expanded(
                child: StreamBuilder<List<HealthEvent>>(
                  stream: db.watchHealthEventsForItem(item.id),
                  builder: (context, snapshot) {
                    final events = snapshot.data ?? [];

                    if (events.isEmpty) {
                      return Center(
                        child: Text(
                          isArabic ? 'لا توجد سجلات مسجلة بعد' : 'No history events recorded yet',
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
                        ),
                      );
                    }

                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16.0),
                      itemCount: events.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final event = events[index];
                        final dateStr = AppFormatter.formatDateTime(
                          DateTime.fromMillisecondsSinceEpoch(event.at),
                          locale: Localizations.localeOf(context).toString(),
                          format: numeralsFormat,
                        );

                        return Container(
                          padding: const EdgeInsets.all(12.0),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: HealthIconHelper.getStatusColor(event.toStatus).withValues(alpha: 0.2),
                                child: Icon(
                                  Icons.history_rounded,
                                  size: 16,
                                  color: HealthIconHelper.getStatusColor(event.toStatus),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          '${HealthIconHelper.getStatusLabel(event.fromStatus, isArabic)} ➔ ${HealthIconHelper.getStatusLabel(event.toStatus, isArabic)}',
                                          style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                                        ),
                                        const Spacer(),
                                        Text(
                                          dateStr,
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: theme.colorScheme.outline,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (event.note != null && event.note!.trim().isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        event.note!,
                                        style: theme.textTheme.bodySmall,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
