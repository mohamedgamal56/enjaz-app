import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/db/app_database.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/enjaz_appearance.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/widgets/widgets.dart';
import '../../assistant/presentation/assistant_sheet.dart';
import '../../finance/presentation/finance_screen.dart';
import '../../habits/presentation/habits_screen.dart';
import '../../health/presentation/health_screen.dart';
import '../../plan/presentation/plan_screen.dart';
import '../../tasks/presentation/task_details_screen.dart';
import '../../today/presentation/today_screen.dart';
import '../domain/home_summary_data.dart';
import 'widgets/home_finance_card.dart';
import 'widgets/home_goals_ideas_card.dart';
import 'widgets/home_habits_card.dart';
import 'widgets/home_health_card.dart';
import 'widgets/home_today_card.dart';

final _agendaTasks = StreamProvider.autoDispose.family<List<Task>, String>(
  (ref, day) => ref.watch(databaseProvider).watchTasksForDate(day),
);

/// All presets reuse the same section cards and existing destination screens.
class HomeAppearanceLayout extends ConsumerStatefulWidget {
  const HomeAppearanceLayout({
    super.key,
    required this.appearance,
    required this.data,
    required this.cardIds,
    this.preview = false,
  });

  final EnjazAppearance appearance;
  final HomeSummaryData data;
  final List<String> cardIds;
  final bool preview;

  @override
  ConsumerState<HomeAppearanceLayout> createState() =>
      _HomeAppearanceLayoutState();
}

class _HomeAppearanceLayoutState extends ConsumerState<HomeAppearanceLayout> {
  late DateTime _day;
  String? _section;
  String _query = '';

  EnjazAppearance get look => widget.appearance;
  HomeSummaryData get data => widget.data;
  List<String> get ids => widget.cardIds;
  bool get ar => Localizations.localeOf(context).languageCode == 'ar';
  AppColors get colors => AppColors.of(context);
  TextTheme get type => Theme.of(context).textTheme;
  bool get hasToday => ids.contains('today');
  List<String> get otherIds => ids.where((id) => id != 'today').toList();

  @override
  void initState() {
    super.initState();
    _day = widget.preview
        ? DateTime(2026, 11, 12)
        : DateUtils.dateOnly(DateTime.now());
  }

  String tr(String arabic, String english) => ar ? arabic : english;
  String number(int value) =>
      AppFormatter.formatNumber(value, format: ref.watch(numeralsProvider));
  String digits(String value) => AppFormatter.formatStringDigits(value,
      format: ref.watch(numeralsProvider));

  String title(String id) => switch (id) {
        'today' => tr('مهام اليوم', 'Today’s tasks'),
        'habits' => tr('العادات', 'Habits'),
        'finance' => tr('المصاريف', 'Spending'),
        'health' => tr('الصحة', 'Health'),
        _ => tr('الأهداف والأفكار', 'Goals & ideas'),
      };

  IconData icon(String id) => switch (id) {
        'today' => Icons.event_available_outlined,
        'habits' => Icons.repeat_rounded,
        'finance' => Icons.account_balance_wallet_outlined,
        'health' => Icons.favorite_border_rounded,
        _ => Icons.track_changes_rounded,
      };

  String metric(String id) => switch (id) {
        'today' =>
          '${number(data.todayCompletedCount)} / ${number(data.todayTotalCount)}',
        'habits' =>
          '${number(data.habitsCompletedCount)} / ${number(data.habitsTotalScheduledCount)}',
        'finance' => MoneyFormatter.formatWithCurrency(
            data.todaySpendingMinor,
            masked: ref.watch(financeMaskedProvider),
            format: ref.watch(numeralsProvider),
            currency: tr('ج.م', 'EGP'),
          ),
        'health' =>
          data.nearestHealthTitle == null ? '—' : tr('موعد قادم', 'Upcoming'),
        _ => number(data.activeGoalsCount),
      };

  void _open(String id, {DateTime? date}) {
    if (widget.preview) return;
    final destination = switch (id) {
      'today' => TodayScreen(initialDate: date),
      'habits' => const HabitsScreen(),
      'finance' => const FinanceScreen(),
      'health' => const HealthScreen(),
      _ => const PlanScreen(),
    };
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => destination));
  }

  void _speak() {
    if (!widget.preview) AssistantSheet.show(context);
  }

  Widget _card(String id) {
    final card = switch (id) {
      'today' => HomeTodayCard(data: data),
      'habits' => HomeHabitsCard(data: data),
      'finance' => HomeFinanceCard(data: data),
      'health' => HomeHealthCard(data: data),
      _ => HomeGoalsIdeasCard(data: data),
    };
    return IgnorePointer(ignoring: widget.preview, child: card);
  }

  Widget _stack(List<Widget> children, {double gap = 12}) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(height: gap),
            children[i],
          ],
        ],
      );

  Widget _grid(List<String> cards, {bool wideToday = true, double gap = 12}) {
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 328 &&
          MediaQuery.textScalerOf(context).scale(14) <= 18.3;
      final rows = <Widget>[];
      for (var i = 0; i < cards.length; i++) {
        final id = cards[i];
        if (!wide ||
            (wideToday && id == 'today') ||
            i == cards.length - 1 ||
            (wideToday && cards[i + 1] == 'today')) {
          rows.add(_card(id));
        } else {
          rows.add(Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _card(id)),
              SizedBox(width: gap),
              Expanded(child: _card(cards[++i])),
            ],
          ));
        }
      }
      return _stack(rows, gap: gap);
    });
  }

  Widget _shortcut(String id, {bool showMetric = true}) => AppCard(
        onTap: widget.preview ? null : () => _open(id),
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon(id), color: colors.accent, size: 21),
            const SizedBox(height: 6),
            Text(title(id),
                textAlign: TextAlign.center, style: type.labelMedium),
            if (showMetric)
              Text(metric(id),
                  textAlign: TextAlign.center, style: type.bodyMedium),
          ],
        ),
      );

  Widget _shortcuts(List<String> cards, {bool showMetric = true}) {
    if (cards.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final columns = (constraints.maxWidth / (84 * math.max(1, scale)))
          .floor()
          .clamp(1, 4);
      final width = (constraints.maxWidth - 8 * (columns - 1)) / columns;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final id in cards)
            SizedBox(
                width: width, child: _shortcut(id, showMetric: showMetric)),
        ],
      );
    });
  }

  Widget _progressHero({bool emphasis = false, bool compact = false}) =>
      AppCard(
        onTap: widget.preview ? null : () => _open('today'),
        child: Row(
          children: [
            SizedBox(
              width: compact ? 58 : 78,
              height: compact ? 58 : 78,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                      child: CircularProgressIndicator(
                    value: data.todayProgress.clamp(0.0, 1.0),
                    color: colors.accent,
                    backgroundColor: colors.border,
                    strokeWidth: emphasis ? 7 : 4,
                    strokeCap: StrokeCap.round,
                    semanticsLabel: title('today'),
                  )),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: FittedBox(
                        child: Text(
                      '${number((data.todayProgress * 100).round())}%',
                      style: type.titleMedium,
                    )),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title('today'), style: type.titleMedium),
                Text(metric('today'),
                    style: type.bodyMedium?.copyWith(color: colors.accent)),
                if (data.nextTaskTitle != null) ...[
                  const SizedBox(height: 5),
                  Text(data.nextTaskTitle!,
                      style: type.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  if (data.nextTaskTime != null)
                    Text(digits(data.nextTaskTime!), style: type.bodySmall),
                ],
              ],
            )),
          ],
        ),
      );

  Widget _voiceButton() => FilledButton.tonalIcon(
        onPressed: widget.preview ? () {} : _speak,
        icon: const Icon(Icons.mic_rounded),
        label: Text(tr('اتكلم مع إنجاز', 'Talk to Enjaz')),
      );

  Widget _voiceOrbit() => Column(
        children: [
          if (otherIds.isNotEmpty)
            _shortcuts(otherIds.take(2).toList(), showMetric: false),
          const SizedBox(height: 8),
          SizedBox(
            height: 166,
            child: Stack(
              alignment: Alignment.center,
              children: [
                ExcludeSemantics(
                    child: CustomPaint(
                  size: const Size(162, 162),
                  painter: _OrbitPainter(colors.accent),
                )),
                SizedBox.square(
                  dimension: 108,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      shape: const CircleBorder(),
                      backgroundColor: colors.accent,
                      foregroundColor:
                          colors.isDark ? colors.background : Colors.white,
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: widget.preview ? () {} : _speak,
                    child: Icon(Icons.mic_rounded,
                        size: 40,
                        semanticLabel: tr('اتكلم مع إنجاز', 'Talk to Enjaz')),
                  ),
                ),
              ],
            ),
          ),
          Text(tr('اتكلم مع إنجاز', 'Talk to Enjaz'), style: type.titleMedium),
          if (otherIds.length > 2) ...[
            const SizedBox(height: 12),
            _shortcuts(otherIds.skip(2).toList(), showMetric: false),
          ],
        ],
      );

  Widget _week() {
    final first = _day.subtract(Duration(days: (_day.weekday + 1) % 7));
    return Wrap(
      spacing: 5,
      runSpacing: 4,
      children: List.generate(7, (i) {
        final day = DateTime(first.year, first.month, first.day + i);
        final label = DateFormat('EEE', ar ? 'ar' : 'en').format(day);
        return ChoiceChip(
          label: Text('$label ${number(day.day)}'),
          showCheckmark: false,
          selected: DateUtils.isSameDay(day, _day),
          onSelected: (_) => setState(() => _day = day),
        );
      }),
    );
  }

  Widget _agenda(
      {bool ruled = false, bool week = false, bool skyline = false}) {
    final day = week ? _day : DateUtils.dateOnly(DateTime.now());
    final date = DateFormat('yyyy-MM-dd').format(day);
    final asyncTasks = widget.preview ? null : ref.watch(_agendaTasks(date));
    final tasks = asyncTasks?.valueOrNull;
    final rows = widget.preview
        ? <({int? id, String title, String? time, bool done})>[
            (
              id: null,
              title: tr('مراجعة البريد', 'Review email'),
              time: '09:00',
              done: true
            ),
            (
              id: null,
              title: tr('تجهيز العرض', 'Prepare slides'),
              time: '11:00',
              done: true
            ),
            (
              id: null,
              title: tr('مقابلة عمل', 'Job interview'),
              time: '14:00',
              done: false
            ),
            (
              id: null,
              title: tr('مراجعة الأهداف', 'Review goals'),
              time: '17:00',
              done: false
            ),
          ]
        : [
            for (final task in tasks ?? <Task>[])
              (
                id: task.id,
                title: task.title,
                time: task.dueTime,
                done: task.status == 'done'
              ),
          ];
    if (!ruled)
      rows.sort((a, b) => (a.time ?? '99:99').compareTo(b.time ?? '99:99'));
    final nextIndex = rows.indexWhere((row) => !row.done);
    return _stack([
      if (skyline)
        SizedBox(
          height: 78,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(look.radius),
            child: CustomPaint(
                painter: _SkylinePainter(colors.accent, colors.surface)),
          ),
        ),
      if (week) _week(),
      Row(children: [
        Expanded(
            child: Text(
          ruled ? title('today') : tr('جدول اليوم', 'Daily schedule'),
          style: type.titleMedium,
        )),
        TextButton(
          onPressed: widget.preview ? null : () => _open('today', date: day),
          child: Text(tr('عرض المهام', 'View tasks')),
        ),
      ]),
      if (asyncTasks?.isLoading == true && tasks == null)
        const LinearProgressIndicator()
      else if (asyncTasks?.hasError == true && tasks == null)
        Text(tr('تعذّر تحميل المهام', 'Could not load tasks'))
      else if (rows.isEmpty)
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(tr(
              'لا توجد مهام في هذا اليوم', 'No tasks scheduled for this day')),
        ),
      for (var i = 0; i < math.min(rows.length, 5); i++)
        _agendaRow(rows[i],
            ruled: ruled, highlighted: !ruled && i == nextIndex),
    ], gap: ruled ? 4 : 8);
  }

  Widget _agendaRow(
    ({int? id, String title, String? time, bool done}) row, {
    required bool ruled,
    required bool highlighted,
  }) =>
      DecoratedBox(
        decoration: BoxDecoration(
          color: highlighted ? colors.accent.withValues(alpha: .11) : null,
          border: ruled
              ? Border(bottom: BorderSide(color: colors.border))
              : BorderDirectional(
                  start: BorderSide(
                      color: highlighted ? colors.accent : colors.border,
                      width: 2),
                ),
        ),
        child: ListTile(
          minTileHeight: 52,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          leading: Icon(
            row.done
                ? Icons.check_circle_rounded
                : ruled
                    ? Icons.check_box_outline_blank_rounded
                    : Icons.radio_button_unchecked,
            color:
                row.done || highlighted ? colors.accent : colors.textSecondary,
            size: 19,
          ),
          title: Text(row.title, maxLines: 2, overflow: TextOverflow.ellipsis),
          trailing: row.time == null
              ? null
              : Text(digits(row.time!), style: type.bodySmall),
          onTap: widget.preview || row.id == null
              ? null
              : () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => TaskDetailsScreen(taskId: row.id!)),
                  ),
        ),
      );

  Widget _ledger() => _stack([
        if (hasToday) _agenda(ruled: true),
        for (final id in otherIds)
          Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                leading: Icon(icon(id), color: colors.accent),
                title: Text(title(id)),
                subtitle: Text(metric(id),
                    style:
                        type.bodyMedium?.copyWith(color: colors.textSecondary)),
                trailing: const Icon(Icons.chevron_right),
                onTap: widget.preview ? null : () => _open(id),
              ),
              Divider(color: colors.border, height: 1),
            ],
          ),
      ]);

  Widget _axis() {
    final current = ids.contains(_section) ? _section! : ids.first;
    return _stack([
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final id in ids)
            ChoiceChip(
              avatar: Icon(icon(id), size: 16),
              label: Text(title(id)),
              selected: current == id,
              onSelected: (_) => setState(() => _section = id),
            ),
        ],
      ),
      _card(current),
      if (current == 'today') _agenda(ruled: true),
      if (ids.length > 1) _shortcuts(ids.where((id) => id != current).toList()),
    ]);
  }

  Widget _searchGrid({required bool withShortcuts}) {
    final query = _query.toLowerCase().trim();
    final filtered =
        ids.where((id) => title(id).toLowerCase().contains(query)).toList();
    return _stack([
      TextField(
        key: ValueKey(look),
        onChanged: (value) => setState(() => _query = value),
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search),
          labelText: tr('ابحث في أقسام الرئيسية', 'Find a home section'),
        ),
      ),
      if (filtered.isEmpty)
        Text(tr('لا توجد أقسام مطابقة', 'No matching sections')),
      if (withShortcuts && filtered.isNotEmpty)
        _shortcuts(filtered, showMetric: false),
      _grid(filtered, wideToday: !withShortcuts, gap: 8),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (ids.isEmpty) return const SizedBox.shrink();
    return switch (look) {
      EnjazAppearance.original => _grid(ids),
      EnjazAppearance.signature => _stack([
          if (hasToday) _progressHero(emphasis: true),
          _shortcuts(otherIds),
          if (hasToday && data.nextTaskTitle != null) _agenda(ruled: true),
        ]),
      EnjazAppearance.classic => _ledger(),
      EnjazAppearance.rail => _stack([
          if (hasToday) _agenda(week: true),
          _shortcuts(otherIds),
        ]),
      EnjazAppearance.nile => _stack([
          if (hasToday) _agenda(week: true, skyline: true),
          _grid(otherIds),
        ]),
      EnjazAppearance.glass => _stack([
          if (hasToday) _card('today'),
          _grid(otherIds, gap: 10),
        ]),
      EnjazAppearance.studio => _stack([
          _voiceButton(),
          if (hasToday) _progressHero(emphasis: true),
          for (final id in otherIds) _card(id),
        ], gap: 16),
      EnjazAppearance.voice => _stack([
          _voiceOrbit(),
          if (hasToday) _card('today'),
        ]),
      EnjazAppearance.aurora => _stack([
          if (hasToday) _progressHero(),
          _grid(otherIds, gap: 16),
          _voiceButton(),
        ], gap: 16),
      EnjazAppearance.pulse => _stack([
          if (hasToday) _progressHero(compact: true, emphasis: true),
          _grid(otherIds, gap: 8),
        ], gap: 8),
      EnjazAppearance.neonAgenda => _stack([
          _shortcuts(otherIds),
          if (hasToday) _agenda(),
        ]),
      EnjazAppearance.brief => _stack([
          _shortcuts(ids),
          if (hasToday) _agenda(ruled: true),
          _grid(otherIds, gap: 8),
        ], gap: 8),
      EnjazAppearance.control => _searchGrid(withShortcuts: false),
      EnjazAppearance.axis => _axis(),
      EnjazAppearance.matrix => _searchGrid(withShortcuts: true),
    };
  }
}

class _OrbitPainter extends CustomPainter {
  const _OrbitPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final (factor, start, sweep, alpha, stroke) in [
      (.97, -.5, 5.4, .22, 1.0),
      (.83, -1.6, 2.0, .85, 3.0),
      (.83, 1.5, 1.8, .52, 3.0),
      (.72, 0.0, 6.29, .17, 1.0),
    ]) {
      paint
        ..color = color.withValues(alpha: alpha)
        ..strokeWidth = stroke;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius * factor),
          start, sweep, false, paint);
    }
  }

  @override
  bool shouldRepaint(_OrbitPainter oldDelegate) => oldDelegate.color != color;
}

class _SkylinePainter extends CustomPainter {
  const _SkylinePainter(this.accent, this.surface);
  final Color accent;
  final Color surface;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final sky = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.alphaBlend(accent.withValues(alpha: .17), surface),
          surface
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, sky);
    final ink = Paint()..color = accent.withValues(alpha: .42);
    final skyline = Path()..moveTo(0, h * .72);
    for (final (x, y) in [
      (.11, .72),
      (.22, .34),
      (.33, .72),
      (.44, .48),
      (.53, .72),
      (.64, .72),
      (.67, .29),
      (.68, .12),
      (.69, .29),
      (.72, .72),
      (.77, .72),
      (.82, .52),
      (.88, .72),
      (1.0, .72),
    ]) {
      skyline.lineTo(w * x, h * y);
    }
    skyline
      ..lineTo(w, h * .75)
      ..lineTo(0, h * .75)
      ..close();
    canvas.drawPath(skyline, ink);
    final ripple = Paint()
      ..color = accent.withValues(alpha: .24)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(w * .12, h * .83), Offset(w * .88, h * .83), ripple);
    canvas.drawLine(Offset(w * .35, h * .91), Offset(w * .73, h * .91), ripple);
  }

  @override
  bool shouldRepaint(_SkylinePainter oldDelegate) =>
      oldDelegate.accent != accent || oldDelegate.surface != surface;
}
