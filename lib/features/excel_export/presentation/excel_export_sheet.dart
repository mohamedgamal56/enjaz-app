import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/db/app_database.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
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

      // Compute statistics for the summary sheet
      final prevRange = range.getPreviousRange();
      final prevTasks = await db.getTasksForStatsRange(prevRange.start, prevRange.end);
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
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    final isAr = l10n.locale.languageCode == 'ar';
    final range = _resolveSelectedRange();

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
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
                  color: colors.border,
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
                    color: colors.surfaceVariant,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.table_chart_rounded, color: colors.accent, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.exportExcel,
                        style: AppTypography.titleLarge(context).copyWith(
                          fontWeight: FontWeight.bold,
                          color: colors.text,
                        ),
                      ),
                      Text(
                        l10n.exportExcelSubtitle,
                        style: AppTypography.bodySmall(context).copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: colors.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Range Preset Chips
            Text(
              l10n.exportRange,
              style: AppTypography.bodyMedium(context).copyWith(
                fontWeight: FontWeight.w600,
                color: colors.text,
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
                color: colors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 18, color: colors.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      range.getLocalizedLabel(isAr ? 'ar' : 'en'),
                      style: AppTypography.bodyMedium(context).copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.text,
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
                color: colors.accent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.accent.withOpacity(0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline_rounded, color: colors.accent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.googleSheetsTip,
                      style: AppTypography.bodySmall(context).copyWith(
                        color: colors.text,
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
                    CircularProgressIndicator(color: colors.accent),
                    const SizedBox(height: 12),
                    Text(
                      l10n.generatingReport,
                      style: AppTypography.bodyMedium(context).copyWith(
                        color: colors.textMuted,
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
                  color: colors.done.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.done),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: colors.done, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.basename(_generatedFile!.path),
                            style: AppTypography.bodyMedium(context).copyWith(
                              fontWeight: FontWeight.bold,
                              color: colors.text,
                            ),
                          ),
                          Text(
                            '${(_generatedFile!.lengthSync() / 1024).toStringAsFixed(1)} KB • 7 ${l10n.sheetTasks}',
                            style: AppTypography.bodySmall(context).copyWith(
                              color: colors.textMuted,
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
                  backgroundColor: colors.accent,
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
                    style: TextStyle(color: colors.stopped, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),

              // Generate Button
              FilledButton.icon(
                onPressed: _startExport,
                icon: const Icon(Icons.download_rounded),
                label: Text(l10n.exportExcel),
                style: FilledButton.styleFrom(
                  backgroundColor: colors.accent,
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
    final colors = AppColors.of(context);
    final isSelected = _selectedPreset == preset;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _selectedPreset = preset;
          _generatedFile = null;
        });
      },
      selectedColor: colors.accent.withOpacity(0.18),
      backgroundColor: colors.surfaceVariant,
      labelStyle: TextStyle(
        color: isSelected ? colors.accent : colors.text,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        fontSize: 13,
      ),
      side: BorderSide(
        color: isSelected ? colors.accent : colors.border,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}
