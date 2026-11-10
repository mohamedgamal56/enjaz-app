import 'package:flutter/material.dart';
import '../../answer_service.dart';

/// Interactive answer card widget for question intents (VOICE.md Section 6).
class AnswerCard extends StatelessWidget {
  final AnswerCardData data;
  final VoidCallback? onNavigate;
  final VoidCallback? onClose;

  const AnswerCard({
    super.key,
    required this.data,
    this.onNavigate,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primaryColor = colorScheme.primary;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header: Icon + Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    data.icon,
                    color: primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    data.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (onClose != null)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: onClose,
                    tooltip: isArabic ? 'إغلاق' : 'Close',
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Speech Text Box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
              ),
              child: Text(
                data.speechText,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Metric Chips
            if (data.metricChips.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: data.metricChips.map((chip) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: Text(
                      chip,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
            ],

            // Detail Items (up to 5 items)
            if (data.detailItems.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: data.detailItems.take(5).map((item) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.circle, size: 6, color: primaryColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item,
                              style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 18),
            ],

            // Action Buttons
            Row(
              children: [
                if (data.navTarget != null && onNavigate != null)
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: onNavigate,
                      icon: const Icon(Icons.arrow_outward_rounded, size: 18),
                      label: Text(data.navLabel ?? (isArabic ? 'عرض التفاصيل' : 'View Details')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                if (data.navTarget != null && onNavigate != null && onClose != null)
                  const SizedBox(width: 10),
                if (onClose != null)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onClose,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(isArabic ? 'إغلاق' : 'Close'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
