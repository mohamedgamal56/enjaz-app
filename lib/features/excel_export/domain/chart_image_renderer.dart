import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../stats/domain/stats_service.dart';

class ChartImageRenderer {
  const ChartImageRenderer();

  static const Color _bgColor = Color(0xFFFFFFFF);
  static const Color _cardBorder = Color(0xFFE2E8F0);
  static const Color _textDark = Color(0xFF1E293B);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _primary = Color(0xFF0D9488); // Teal
  static const Color _accent = Color(0xFF14B8A6);

  static const Map<String, Color> _statusColors = {
    'done': Color(0xFF10B981),      // Emerald
    'todo': Color(0xFF94A3B8),      // Slate
    'in_progress': Color(0xFF3B82F6), // Blue
    'partial': Color(0xFFF97316),   // Orange
    'postponed': Color(0xFFF59E0B), // Amber
    'waiting': Color(0xFF8B5CF6),   // Purple
    'stopped': Color(0xFFEF4444),   // Red
  };

  /// 1. Render Timeline Bar Chart of completed tasks over time (2x PNG, 600x320)
  Future<Uint8List> renderTimelineChart({
    required List<MapEntry<String, int>> entries,
    required bool isAr,
    int width = 600,
    int height = 320,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));

    _drawBackgroundCard(canvas, width.toDouble(), height.toDouble());

    // Title
    _drawText(
      canvas,
      isAr ? 'إنجاز المهام عبر الأيام' : 'Completed Tasks Timeline',
      const Offset(24, 20),
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: _textDark,
      isRtl: isAr,
      maxWidth: width - 48.0,
    );

    final plotLeft = 60.0;
    final plotRight = width - 30.0;
    final plotTop = 70.0;
    final plotBottom = height - 50.0;
    final plotWidth = plotRight - plotLeft;
    final plotHeight = plotBottom - plotTop;

    if (entries.isEmpty || entries.every((e) => e.value == 0)) {
      _drawEmptyState(canvas, width, height, isAr ? 'لا توجد مهام منجزة في هذه الفترة' : 'No completed tasks in this period');
      final picture = recorder.endRecording();
      final img = await picture.toImage(width, height);
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      return byteData!.buffer.asUint8List();
    }

    final maxVal = entries.map((e) => e.value).fold<int>(0, math.max);
    final ceiling = maxVal < 5 ? 5 : ((maxVal / 5).ceil() * 5);

    // Draw horizontal grid lines & Y labels
    final gridPaint = Paint()
      ..color = _cardBorder
      ..strokeWidth = 1.0;

    for (int i = 0; i <= 4; i++) {
      final y = plotBottom - (i / 4.0) * plotHeight;
      final val = (ceiling * (i / 4.0)).round();
      canvas.drawLine(Offset(plotLeft, y), Offset(plotRight, y), gridPaint);

      _drawText(
        canvas,
        '$val',
        Offset(20, y - 8),
        fontSize: 11,
        color: _textMuted,
        isRtl: false,
      );
    }

    // Draw Bars
    // Take at most 14 entries to fit nicely
    final visibleEntries = entries.length > 14
        ? entries.sublist(entries.length - 14)
        : entries;

    final barSlotWidth = plotWidth / visibleEntries.length;
    final barWidth = math.min(24.0, barSlotWidth * 0.6);

    final barPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, plotTop),
        Offset(0, plotBottom),
        [_accent, _primary],
      );

    for (int i = 0; i < visibleEntries.length; i++) {
      final entry = visibleEntries[i];
      final val = entry.value;
      final barH = ceiling == 0 ? 0.0 : (val / ceiling) * plotHeight;
      final cx = plotLeft + i * barSlotWidth + barSlotWidth / 2;
      final x = cx - barWidth / 2;
      final y = plotBottom - barH;

      if (val > 0) {
        final rrect = RRect.fromRectAndCorners(
          Rect.fromLTWH(x, y, barWidth, barH),
          topLeft: const Radius.circular(5),
          topRight: const Radius.circular(5),
        );
        canvas.drawRRect(rrect, barPaint);

        // Value on top of bar
        _drawText(
          canvas,
          '$val',
          Offset(cx - 10, y - 18),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: _primary,
        );
      }

      // X Label (short date)
      final label = entry.key.length >= 5 ? entry.key.substring(5) : entry.key; // e.g. "11-06"
      _drawText(
        canvas,
        label,
        Offset(cx - 16, plotBottom + 8),
        fontSize: 10,
        color: _textMuted,
      );
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(width, height);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// 2. Render Status Distribution Donut Chart (2x PNG, 600x320)
  Future<Uint8List> renderStatusDonutChart({
    required Map<String, int> statusDist,
    required bool isAr,
    int width = 600,
    int height = 320,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));

    _drawBackgroundCard(canvas, width.toDouble(), height.toDouble());

    // Title
    _drawText(
      canvas,
      isAr ? 'توزيع حالات المهام' : 'Status Distribution',
      const Offset(24, 20),
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: _textDark,
      isRtl: isAr,
    );

    final total = statusDist.values.fold<int>(0, (sum, count) => sum + count);
    if (total == 0) {
      _drawEmptyState(canvas, width, height, isAr ? 'لا توجد مهام مسجلة' : 'No tasks recorded');
      final picture = recorder.endRecording();
      final img = await picture.toImage(width, height);
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      return byteData!.buffer.asUint8List();
    }

    // Donut setup
    final donutCenter = Offset(width * 0.32, height * 0.55);
    final outerRadius = 80.0;
    final innerRadius = 48.0;

    double startAngle = -math.pi / 2;

    statusDist.forEach((st, count) {
      if (count <= 0) return;
      final sweepAngle = (count / total) * 2 * math.pi;
      final color = _statusColors[st] ?? _textMuted;

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = outerRadius - innerRadius
        ..strokeCap = StrokeCap.butt;

      final midRadius = (outerRadius + innerRadius) / 2;
      canvas.drawArc(
        Rect.fromCircle(center: donutCenter, radius: midRadius),
        startAngle,
        sweepAngle - 0.04, // slight gap
        false,
        paint,
      );

      startAngle += sweepAngle;
    });

    // Center text
    _drawText(
      canvas,
      '$total',
      Offset(donutCenter.dx - 18, donutCenter.dy - 16),
      fontSize: 22,
      fontWeight: FontWeight.bold,
      color: _textDark,
    );
    _drawText(
      canvas,
      isAr ? 'مهمة' : 'tasks',
      Offset(donutCenter.dx - 14, donutCenter.dy + 8),
      fontSize: 11,
      color: _textMuted,
    );

    // Legend on the right
    final legendLeft = width * 0.60;
    double legendY = 65.0;

    final labels = isAr
        ? {
            'done': 'مكتملة',
            'todo': 'قيد الانتظار',
            'in_progress': 'قيد التنفيذ',
            'partial': 'إنجاز جزئي',
            'postponed': 'مؤجلة',
            'waiting': 'معلقة',
            'stopped': 'متوقفة',
          }
        : {
            'done': 'Completed',
            'todo': 'Todo',
            'in_progress': 'In Progress',
            'partial': 'Partial',
            'postponed': 'Postponed',
            'waiting': 'Waiting',
            'stopped': 'Stopped',
          };

    statusDist.forEach((st, count) {
      if (count <= 0) return;
      final color = _statusColors[st] ?? _textMuted;
      final pct = ((count / total) * 100).round();
      final label = labels[st] ?? st;

      // Color bullet
      canvas.drawCircle(Offset(legendLeft, legendY + 7), 5, Paint()..color = color);

      // Label & count
      _drawText(
        canvas,
        '$label: $count ($pct%)',
        Offset(legendLeft + 14, legendY),
        fontSize: 12,
        color: _textDark,
        fontWeight: FontWeight.w600,
      );

      legendY += 28.0;
    });

    final picture = recorder.endRecording();
    final img = await picture.toImage(width, height);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// 3. Render Top Postponement Reasons Bar Chart (2x PNG, 600x320)
  Future<Uint8List> renderReasonsChart({
    required List<ReasonCount> topReasons,
    required bool isAr,
    int width = 600,
    int height = 320,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));

    _drawBackgroundCard(canvas, width.toDouble(), height.toDouble());

    // Title
    _drawText(
      canvas,
      isAr ? 'أهم أسباب التأجيل والتوقف' : 'Top Postponement Reasons',
      const Offset(24, 20),
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: _textDark,
      isRtl: isAr,
    );

    if (topReasons.isEmpty || topReasons.every((r) => r.count == 0)) {
      _drawEmptyState(canvas, width, height, isAr ? 'لا توجد أسباب تأجيل مسجلة' : 'No recorded postponement reasons');
      final picture = recorder.endRecording();
      final img = await picture.toImage(width, height);
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      return byteData!.buffer.asUint8List();
    }

    final maxVal = topReasons.map((r) => r.count).fold<int>(0, math.max);
    final displayReasons = topReasons.take(5).toList();

    double startY = 70.0;
    final rowHeight = 44.0;
    final maxBarWidth = width - 260.0;

    final barPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        Offset(maxBarWidth, 0),
        [const Color(0xFFF59E0B), const Color(0xFFD97706)],
      );

    for (final r in displayReasons) {
      final barW = maxVal > 0 ? (r.count / maxVal) * maxBarWidth : 0.0;

      // Reason name
      _drawText(
        canvas,
        r.reason,
        Offset(24, startY),
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: _textDark,
        maxWidth: 160,
      );

      // Bar
      final barRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(180, startY + 2, math.max(12.0, barW), 14),
        const Radius.circular(7),
      );
      canvas.drawRRect(barRect, barPaint);

      // Count badge
      _drawText(
        canvas,
        '${r.count}×',
        Offset(180 + math.max(12.0, barW) + 10, startY),
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: const Color(0xFFB45309),
      );

      startY += rowHeight;
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(width, height);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// 4. Render Weekday Productivity Bar Chart (2x PNG, 600x320)
  Future<Uint8List> renderWeekdayProductivityChart({
    required List<int> weekdayCounts, // 7 items for Saturday..Friday
    required bool isAr,
    int width = 600,
    int height = 320,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));

    _drawBackgroundCard(canvas, width.toDouble(), height.toDouble());

    // Title
    _drawText(
      canvas,
      isAr ? 'أكثر أيام الأسبوع إنتاجية' : 'Productivity by Weekday',
      const Offset(24, 20),
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: _textDark,
      isRtl: isAr,
    );

    final maxVal = weekdayCounts.fold<int>(0, math.max);
    if (maxVal == 0) {
      _drawEmptyState(canvas, width, height, isAr ? 'لا توجد بيانات إنتاجية كافية' : 'No productivity data yet');
      final picture = recorder.endRecording();
      final img = await picture.toImage(width, height);
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      return byteData!.buffer.asUint8List();
    }

    final dayLabels = isAr
        ? ['السبت', 'الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة']
        : ['Sat', 'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri'];

    final plotLeft = 50.0;
    final plotRight = width - 30.0;
    final plotTop = 75.0;
    final plotBottom = height - 50.0;
    final plotWidth = plotRight - plotLeft;
    final plotHeight = plotBottom - plotTop;

    final ceiling = maxVal < 5 ? 5 : ((maxVal / 5).ceil() * 5);
    final barSlotWidth = plotWidth / 7;
    final barWidth = 32.0;

    for (int i = 0; i < 7; i++) {
      final count = i < weekdayCounts.length ? weekdayCounts[i] : 0;
      final isPeak = count == maxVal && count > 0;
      final barH = ceiling == 0 ? 0.0 : (count / ceiling) * plotHeight;
      final cx = plotLeft + i * barSlotWidth + barSlotWidth / 2;
      final x = cx - barWidth / 2;
      final y = plotBottom - barH;

      final barColor = isPeak ? _primary : _primary.withOpacity(0.35);

      if (count > 0) {
        final rrect = RRect.fromRectAndCorners(
          Rect.fromLTWH(x, y, barWidth, barH),
          topLeft: const Radius.circular(6),
          topRight: const Radius.circular(6),
        );
        canvas.drawRRect(rrect, Paint()..color = barColor);

        // Count above bar
        _drawText(
          canvas,
          '$count',
          Offset(cx - (count > 9 ? 10 : 5), y - 18),
          fontSize: 11,
          fontWeight: isPeak ? FontWeight.bold : FontWeight.normal,
          color: isPeak ? _primary : _textMuted,
        );

        if (isPeak) {
          // Peak Star badge
          _drawText(
            canvas,
            '★',
            Offset(cx - 6, y - 32),
            fontSize: 12,
            color: const Color(0xFFF59E0B),
          );
        }
      }

      // Day label
      _drawText(
        canvas,
        dayLabels[i],
        Offset(cx - 18, plotBottom + 8),
        fontSize: 11,
        fontWeight: isPeak ? FontWeight.bold : FontWeight.normal,
        color: isPeak ? _primary : _textMuted,
      );
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(width, height);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  // --- Helper Drawers ---

  void _drawBackgroundCard(Canvas canvas, double w, double h) {
    // Fill white
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = _bgColor);

    // Border
    final borderPaint = Paint()
      ..color = _cardBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(1, 1, w - 2, h - 2), const Radius.circular(12)),
      borderPaint,
    );
  }

  void _drawEmptyState(Canvas canvas, int width, int height, String message) {
    _drawText(
      canvas,
      message,
      Offset(width / 2 - 120, height / 2 - 10),
      fontSize: 13,
      color: _textMuted,
      maxWidth: 240,
    );
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset, {
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.normal,
    Color color = Colors.black,
    bool isRtl = false,
    double? maxWidth,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          fontFamily: 'Cairo',
        ),
      ),
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      maxLines: 1,
    );
    tp.layout(maxWidth: maxWidth ?? double.infinity);
    tp.paint(canvas, offset);
  }
}
