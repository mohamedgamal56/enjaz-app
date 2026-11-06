import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../../core/db/app_database.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../stats/domain/stats_service.dart';
import '../domain/excel_export_service.dart';

class ExcelExportSheet extends ConsumerStatefulWidget {
  final StatsRangeType initialRangeType;
  final DateTime? initialReferenceDate;

  const ExcelExportSheet({
    super.key,
    this.initialRangeType = StatsRangeType.week,
    this.initialReferenceDate,
  });

  static Future<void> show(
    BuildContext context, {
    StatsRangeType initialRangeType = StatsRangeType.week,
    DateTime? initialReferenceDate,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ExcelExportSheet(
        initialRangeType: initialRangeType,
        initialReferenceDate: initialReferenceDate,
      ),
    );
  }

  @override
  ConsumerState<ExcelExportSheet> createState() => _ExcelExportSheetState();
}

enum ExportPreset {
  thisWeek,
  lastWeek,
  thisMonth,
  lastMonth,
  thisYear,
  allTime,
  custom,
}

class _ExcelExportSheetState extends ConsumerState<ExcelExportSheet> {
  late ExportPreset _selectedPreset;
  DateTime? _customStart;
  DateTime? _customEnd;

  bool _isGenerating = false;
  File? _generatedFile;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    switch (widget.initialRangeType) {
      case StatsRangeType.week:
        _selectedPreset = ExportPreset.thisWeek;
        break;
      case StatsRangeType.month:
        _selectedPreset = ExportPreset.thisMonth;
        break;
      case StatsRangeType.year:
        _selectedPreset = ExportPreset.thisYear;
        break;
      case StatsRangeType.allTime:
        _selectedPreset = ExportPreset.allTime;
        break;
      case StatsRangeType.custom:
        _selectedPreset = ExportPreset.custom;
        break;
    }
  }

  StatsDateRange _resolveSelectedRange() {
    final now = widget.initialReferenceDate ?? DateTime.now();

    switch (_selectedPreset) {
      case ExportPreset.thisWeek:
        return StatsService.resolveRange(
          type: StatsRangeType.week,
          referenceDate: now,
        );
      case ExportPreset.lastWeek:
        final currentWeek = StatsService.resolveRange(
          type: StatsRangeType.week,
          referenceDate: now,
        );
        return currentWeek.getPreviousRange();
      case ExportPreset.thisMonth:
        return StatsService.resolveRange(
          type: StatsRangeType.month,
          referenceDate: now,
        );
      case ExportPreset.lastMonth:
        final currentMonth = StatsService.resolveRange(
          type: StatsRangeType.month,
          referenceDate: now,
        );
        return currentMonth.getPreviousRange();
      case ExportPreset.thisYear:
        return StatsService.resolveRange(
          type: StatsRangeType.year,
          referenceDate: now,
        );
      case ExportPreset.allTime:
        return StatsService.resolveRange(
          type: StatsRangeType.allTime,
          referenceDate: now,
        );
      case ExportPreset.custom:
        return StatsService.resolveRange(
          type: StatsRangeType.custom,
          referenceDate: now,
          customStart: _customStart ?? now.subtract(const Duration(days: 30)),
          customEnd: _customEnd ?? now,
        );
    }
  }

  Future<void> _startExport() async {
    setState(() {
      _isGenerating = true;
      _errorMessage = null;
      _generatedFile = null;
    });

    try {
      final range = _resolveSelectedRange();
      final db = ref.read(databaseProvider);

      // Fetch all required data from Drift
      final tasks = await db.getTasksForStatsRange(range.start, range.end);
      final events = await db.getEventsForRange(range.start, range.end);
      final allDoneEvents = await db.getAllDoneEvents();
      final goals = await db.getAllGoalsList();
      final milestones = await db.getAllMilestonesList();
      final goalUpdates = await db.getGoalUpdatesForRange(range.start, range.end);
      final ideas = await db.getAllIdeasList();
      final voiceNotes = await db.getAllVoiceNotesList();

      final rangeStartStr = "${range.start.year}-${range.start.month.toString().padLeft(2, '0')}-${range.start.day.toString().padLeft(2, '0')}";
      final rangeEndStr = "${range.end.year}-${range.end.month.toString().padLeft(2, '0')}-${range.end.day.toString().padLeft(2, '0')}";
      final transactions = await db.getTransactionsForRange(rangeStartStr, rangeEndStr);
      final categories = await db.getAllFinanceCategories();
      final obligations = await db.getAllObligations();
      final instances = await db.getObligationInstancesForRange(rangeStartStr, rangeEndStr);
      final wishlist = await db.getAllWishlistItems();

      // Compute statistics for the summary sheet
      final prevRange = range.getPreviousRange();
      final prevEvents = await db.getEventsForRange(prevRange.start, prevRange.end);
      final prevDoneCount = prevEvents.where((e) => e.toStatus == 'done').map((e) => e.taskId).toSet().length;

      const statsService = StatsService();
      final statsResult = statsService.computeStats(
        range: range,
        tasks: tasks,
        rangeEvents: events,
        allDoneEvents: allDoneEvents,
        previousPeriodCompletedCount: prevDoneCount,
        goals: goals,
        milestones: milestones,
        goalUpdates: goalUpdates,
        ideas: ideas,
      );

      final l10n = AppLocalizations.of(context);
      const exportService = ExcelExportService();

      final file = await exportService.generateReport(
        range: range,
        stats: statsResult,
        tasks: tasks,
        events: events,
        goals: goals,
        milestones: milestones,
        goalUpdates: goalUpdates,
        ideas: ideas,
        voiceNotes: voiceNotes,
        transactions: transactions,
        financeCategories: categories,
        obligations: obligations,
        obligationInstances: instances,
        wishlistItems: wishlist,
        languageCode: l10n.locale.languageCode,
      );

      if (mounted) {
        setState(() {
          _isGenerating = false;
          _generatedFile = file;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _shareFile() async {
    if (_generatedFile == null) return;
    final l10n = AppLocalizations.of(context);
    final box = context.findRenderObject() as RenderBox?;

    await Share.shareXFiles(
      [XFile(_generatedFile!.path)],
      text: '${l10n.appName} - ${l10n.exportExcel}',
      sharePositionOrigin: box != null ? box.localToGlobal(Offset.zero) & box.size : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final isAr = l10n.locale.languageCode == 'ar';
    final range = _resolveSelectedRange();
    final primaryColor = theme.colorScheme.primary;
    final surfaceColor = theme.colorScheme.surface;
    final surfaceVariant = theme.colorScheme.surfaceContainerHighest;
    final textColor = theme.colorScheme.onSurface;
    final textMuted = theme.colorScheme.onSurfaceVariant;
    final borderColor = theme.colorScheme.outlineVariant;
    final doneColor = AppColors.getStatusColor('done', isDark);

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: surfaceVariant,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.table_chart_rounded, color: primaryColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.exportExcel,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      Text(
                        l10n.exportExcelSubtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Range Preset Chips
            Text(
              l10n.exportRange,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(height: 10),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildPresetChip(ExportPreset.thisWeek, l10n.rangeThisWeek),
                _buildPresetChip(ExportPreset.lastWeek, l10n.rangeLastWeek),
                _buildPresetChip(ExportPreset.thisMonth, l10n.rangeThisMonth),
                _buildPresetChip(ExportPreset.lastMonth, l10n.rangeLastMonth),
                _buildPresetChip(ExportPreset.thisYear, l10n.rangeThisYear),
                _buildPresetChip(ExportPreset.allTime, l10n.rangeAllTime),
                _buildPresetChip(ExportPreset.custom, l10n.rangeCustom),
              ],
            ),
            const SizedBox(height: 16),

            // Selected Range Summary Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 18, color: primaryColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      range.getLocalizedLabel(isAr ? 'ar' : 'en'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Tip Box (Google Sheets direct open)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primaryColor.withOpacity(0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline_rounded, color: primaryColor, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.googleSheetsTip,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: textColor,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Generation progress or action buttons
            if (_isGenerating)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    CircularProgressIndicator(color: primaryColor),
                    const SizedBox(height: 12),
                    Text(
                      l10n.generatingReport,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: textMuted,
                      ),
                    ),
                  ],
                ),
              )
            else if (_generatedFile != null) ...[
              // Generated file info card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: doneColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: doneColor),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: doneColor, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.basename(_generatedFile!.path),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          Text(
                            '${(_generatedFile!.lengthSync() / 1024).toStringAsFixed(1)} KB • 8 ${isAr ? 'أوراق عمل' : 'worksheets'}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Action buttons: Share
              FilledButton.icon(
                onPressed: _shareFile,
                icon: const Icon(Icons.share_rounded),
                label: Text(l10n.shareReport),
                style: FilledButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ] else ...[
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),

              // Generate Button
              FilledButton.icon(
                onPressed: _startExport,
                icon: const Icon(Icons.download_rounded),
                label: Text(l10n.exportExcel),
                style: FilledButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip(ExportPreset preset, String label) {
    final theme = Theme.of(context);
    final isSelected = _selectedPreset == preset;
    final primaryColor = theme.colorScheme.primary;
    final surfaceVariant = theme.colorScheme.surfaceContainerHighest;
    final textColor = theme.colorScheme.onSurface;
    final borderColor = theme.colorScheme.outlineVariant;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _selectedPreset = preset;
          _generatedFile = null;
        });
      },
      selectedColor: primaryColor.withOpacity(0.18),
      backgroundColor: surfaceVariant,
      labelStyle: TextStyle(
        color: isSelected ? primaryColor : textColor,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        fontSize: 13,
      ),
      side: BorderSide(
        color: isSelected ? primaryColor : borderColor,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}
