import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../excel_export/presentation/excel_export_sheet.dart';
import '../../stats/domain/stats_service.dart';
import '../domain/timeline_models.dart';
import 'timeline_day_view.dart';
import 'timeline_month_view.dart';
import 'timeline_week_view.dart';
import 'timeline_year_view.dart';

class TimelineCalendarScreen extends ConsumerStatefulWidget {
  final DateTime? initialDate;

  const TimelineCalendarScreen({super.key, this.initialDate});

  @override
  ConsumerState<TimelineCalendarScreen> createState() => _TimelineCalendarScreenState();
}

class _TimelineCalendarScreenState extends ConsumerState<TimelineCalendarScreen> {
  int _selectedView = 0; // 0: Day, 1: Week, 2: Month, 3: Year
  late DateTime _referenceDate;

  @override
  void initState() {
    super.initState();
    final now = widget.initialDate ?? DateTime.now();
    // Clamp to 2026..2046 range
    if (now.isBefore(TimelineConstants.minDate)) {
      _referenceDate = TimelineConstants.minDate;
    } else if (now.isAfter(TimelineConstants.maxDate)) {
      _referenceDate = TimelineConstants.maxDate;
    } else {
      _referenceDate = now;
    }
  }

  void _jumpToToday() {
    setState(() {
      final now = DateTime.now();
      if (now.isBefore(TimelineConstants.minDate)) {
        _referenceDate = TimelineConstants.minDate;
      } else if (now.isAfter(TimelineConstants.maxDate)) {
        _referenceDate = TimelineConstants.maxDate;
      } else {
        _referenceDate = now;
      }
      _selectedView = 0; // Jump to Day view
    });
  }

  void _navigateRange(int direction) {
    setState(() {
      DateTime target;
      switch (_selectedView) {
        case 0: // Day
          target = _referenceDate.add(Duration(days: direction));
          break;
        case 1: // Week
          target = _referenceDate.add(Duration(days: 7 * direction));
          break;
        case 2: // Month
          target = DateTime(_referenceDate.year, _referenceDate.month + direction, _referenceDate.day.clamp(1, 28));
          break;
        case 3: // Year
          target = DateTime(_referenceDate.year + direction, _referenceDate.month, _referenceDate.day.clamp(1, 28));
          break;
        default:
          target = _referenceDate;
      }

      if (target.isBefore(TimelineConstants.minDate)) {
        _referenceDate = TimelineConstants.minDate;
      } else if (target.isAfter(TimelineConstants.maxDate)) {
        _referenceDate = TimelineConstants.maxDate;
      } else {
        _referenceDate = target;
      }
    });
  }

  bool _canNavigate(int direction) {
    if (direction < 0) {
      return _referenceDate.isAfter(TimelineConstants.minDate);
    } else {
      return _referenceDate.isBefore(TimelineConstants.maxDate);
    }
  }

  String _getDateHeaderLabel(bool isAr, NumeralsFormat numerals) {
    switch (_selectedView) {
      case 0: // Day
        final dayName = isAr
            ? DateFormat('EEEE، d MMMM yyyy', 'ar').format(_referenceDate)
            : DateFormat('EEEE, d MMMM yyyy', 'en').format(_referenceDate);
        return AppFormatter.formatStringDigits(dayName, format: numerals);
      case 1: // Week
        final satOffset = (_referenceDate.weekday % 7 + 1) % 7;
        final start = _referenceDate.subtract(Duration(days: satOffset));
        final end = start.add(const Duration(days: 6));
        final sStr = DateFormat('d MMM', isAr ? 'ar' : 'en').format(start);
        final eStr = DateFormat('d MMM yyyy', isAr ? 'ar' : 'en').format(end);
        return AppFormatter.formatStringDigits('$sStr - $eStr', format: numerals);
      case 2: // Month
        final mStr = DateFormat('MMMM yyyy', isAr ? 'ar' : 'en').format(_referenceDate);
        return AppFormatter.formatStringDigits(mStr, format: numerals);
      case 3: // Year
        return AppFormatter.formatStringDigits('${_referenceDate.year}', format: numerals);
      default:
        return '';
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _referenceDate,
      firstDate: TimelineConstants.minDate,
      lastDate: TimelineConstants.maxDate,
    );
    if (picked != null) {
      setState(() => _referenceDate = picked);
    }
  }

  void _exportPeriod() {
    StatsRangeType rangeType;
    switch (_selectedView) {
      case 0:
        rangeType = StatsRangeType.custom;
        break;
      case 1:
        rangeType = StatsRangeType.week;
        break;
      case 2:
        rangeType = StatsRangeType.month;
        break;
      case 3:
        rangeType = StatsRangeType.year;
        break;
      default:
        rangeType = StatsRangeType.month;
    }

    ExcelExportSheet.show(
      context,
      initialRangeType: rangeType,
      initialReferenceDate: _referenceDate,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final numerals = ref.watch(numeralsProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          isAr ? 'التقويم والسجل الزمني' : 'Calendar & Timeline',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        actions: [
          // Jump to Today button
          TextButton.icon(
            onPressed: _jumpToToday,
            icon: const Icon(Icons.today_rounded, size: 18),
            label: Text(
              isAr ? 'اليوم' : 'Today',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          // Export this period button
          IconButton(
            icon: const Icon(Icons.table_chart_rounded),
            tooltip: isAr ? 'تصدير هذه الفترة' : 'Export this period',
            onPressed: _exportPeriod,
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. View Switcher Segments (Day, Week, Month, Year)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                segments: [
                  ButtonSegment<int>(
                    value: 0,
                    label: Text(isAr ? 'اليوم' : 'Day'),
                    icon: const Icon(Icons.view_day_outlined, size: 16),
                  ),
                  ButtonSegment<int>(
                    value: 1,
                    label: Text(isAr ? 'الأسبوع' : 'Week'),
                    icon: const Icon(Icons.view_week_outlined, size: 16),
                  ),
                  ButtonSegment<int>(
                    value: 2,
                    label: Text(isAr ? 'الشهر' : 'Month'),
                    icon: const Icon(Icons.calendar_view_month_rounded, size: 16),
                  ),
                  ButtonSegment<int>(
                    value: 3,
                    label: Text(isAr ? 'السنة' : 'Year'),
                    icon: const Icon(Icons.calendar_today_rounded, size: 16),
                  ),
                ],
                selected: {_selectedView},
                onSelectionChanged: (val) {
                  setState(() => _selectedView = val.first);
                },
              ),
            ),
          ),

          // 2. Date Navigation Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: _canNavigate(isAr ? 1 : -1) ? () => _navigateRange(isAr ? 1 : -1) : null,
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _pickDate,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _getDateHeaderLabel(isAr, numerals),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_drop_down_rounded, size: 20, color: colors.textMuted),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: _canNavigate(isAr ? -1 : 1) ? () => _navigateRange(isAr ? -1 : 1) : null,
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // 3. View Body
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _buildCurrentView(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentView() {
    switch (_selectedView) {
      case 0:
        return TimelineDayView(
          key: ValueKey('day_${_referenceDate.year}_${_referenceDate.month}_${_referenceDate.day}'),
          date: _referenceDate,
          onDayChanged: () => setState(() {}),
        );
      case 1:
        return TimelineWeekView(
          key: ValueKey('week_${_referenceDate.year}_${_referenceDate.month}_${_referenceDate.day}'),
          referenceDate: _referenceDate,
          onSelectDay: (day) {
            setState(() {
              _referenceDate = day;
              _selectedView = 0; // Open day view
            });
          },
        );
      case 2:
        return TimelineMonthView(
          key: ValueKey('month_${_referenceDate.year}_${_referenceDate.month}'),
          referenceDate: _referenceDate,
          onSelectDay: (day) {
            setState(() {
              _referenceDate = day;
              _selectedView = 0; // Open day view
            });
          },
          onMonthChanged: (newMonth) {
            setState(() => _referenceDate = newMonth);
          },
        );
      case 3:
        return TimelineYearView(
          key: ValueKey('year_${_referenceDate.year}'),
          year: _referenceDate.year,
          onSelectMonth: (monthNum) {
            setState(() {
              _referenceDate = DateTime(_referenceDate.year, monthNum, 1);
              _selectedView = 2; // Open month view
            });
          },
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
