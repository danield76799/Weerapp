import 'package:flutter/material.dart';

import '../models/weather.dart';

/// Toont temperatuur trend van afgelopen 7 dagen als lijngrafiek
class WeatherHistoryCard extends StatelessWidget {
  final List<DailyForecast> pastDaily;
  final List<DailyForecast> daily;

  const WeatherHistoryCard({
    super.key,
    required this.pastDaily,
    required this.daily,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Combine past + today for the chart
    final chartData = <_DayData>[];
    final allDays = [...pastDaily];
    if (daily.isNotEmpty) allDays.add(daily.first);

    if (allDays.length < 2) {
      return const SizedBox.shrink();
    }

    double minTemp = double.infinity;
    double maxTemp = double.negativeInfinity;

    for (final d in allDays) {
      chartData.add(_DayData(
        date: d.date,
        tempMax: d.tempMax,
        tempMin: d.tempMin,
      ));
      if (d.tempMin < minTemp) minTemp = d.tempMin;
      if (d.tempMax > maxTemp) maxTemp = d.tempMax;
    }

    // Add padding to range
    final range = (maxTemp - minTemp).clamp(1.0, double.infinity);
    minTemp -= range * 0.15;
    maxTemp += range * 0.15;

    final dayNames = ['ma', 'di', 'wo', 'do', 'vr', 'za', 'zo'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh.withAlpha(120),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.show_chart, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Temperatuur afgelopen ${allDays.length} dagen',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: CustomPaint(
              size: Size.infinite,
              painter: _TempChartPainter(
                data: chartData,
                minTemp: minTemp,
                maxTemp: maxTemp,
                maxColor: const Color(0xFFE53935),
                minColor: const Color(0xFF1E88E5),
                dayNames: dayNames,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendDot('Max', const Color(0xFFE53935)),
              const SizedBox(width: 16),
              _legendDot('Min', const Color(0xFF1E88E5)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendDot(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    );
  }
}

class _DayData {
  final DateTime date;
  final double tempMax;
  final double tempMin;
  _DayData({required this.date, required this.tempMax, required this.tempMin});
}

class _TempChartPainter extends CustomPainter {
  final List<_DayData> data;
  final double minTemp;
  final double maxTemp;
  final Color maxColor;
  final Color minColor;
  final List<String> dayNames;

  _TempChartPainter({
    required this.data,
    required this.minTemp,
    required this.maxTemp,
    required this.maxColor,
    required this.minColor,
    required this.dayNames,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final w = size.width;
    final h = size.height;

    // Reserve space for Y-axis labels on the left
    final leftPad = 28.0;
    final topPad = 8.0;
    final bottomPad = 18.0;
    final chartW = w - leftPad;
    final chartH = h - topPad - bottomPad;
    final stepX = chartW / (data.length - 1);

    double tempToY(double temp) {
      final ratio = (temp - minTemp) / (maxTemp - minTemp);
      return topPad + chartH * (1 - ratio.clamp(0.0, 1.0));
    }

    // Y-axis scale: generate nice round temperature values
    final axisStyle = TextStyle(
      fontSize: 9,
      color: Colors.black54,
      fontWeight: FontWeight.w500,
    );
    final gridPaint = Paint()
      ..color = Colors.black.withAlpha(12)
      ..strokeWidth = 0.5;

    // Calculate nice step for Y-axis labels (aim for ~4 labels)
    final range = maxTemp - minTemp;
    final rawStep = range / 4;
    final niceSteps = [1, 2, 3, 5, 10];
    double niceStep = niceSteps
        .firstWhere((s) => s >= rawStep, orElse: () => (rawStep * 10).ceil())
        .toDouble();
    final startVal = (minTemp / niceStep).ceil() * niceStep;
    final endVal = maxTemp;

    for (var v = startVal; v <= endVal + 0.01; v += niceStep) {
      final y = tempToY(v);
      final tp = TextPainter(
        text: TextSpan(text: '${v.toStringAsFixed(v % 1 == 0 ? 0 : 1)}°', style: axisStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, y - tp.height / 2));
      canvas.drawLine(Offset(leftPad, y), Offset(w, y), gridPaint);
    }

    // Max temp line + min temp line paths
    final maxPath = Path();
    final minPath = Path();

    for (var i = 0; i < data.length; i++) {
      final x = leftPad + i * stepX;
      final maxY = tempToY(data[i].tempMax);
      final minY = tempToY(data[i].tempMin);
      if (i == 0) {
        maxPath.moveTo(x, maxY);
        minPath.moveTo(x, minY);
      } else {
        maxPath.lineTo(x, maxY);
        minPath.lineTo(x, minY);
      }
    }

    // Fill between max and min
    final fillPath = Path();
    for (var i = 0; i < data.length; i++) {
      final x = leftPad + i * stepX;
      final y = tempToY(data[i].tempMax);
      if (i == 0) {
        fillPath.moveTo(x, y);
      } else {
        fillPath.lineTo(x, y);
      }
    }
    for (var i = data.length - 1; i >= 0; i--) {
      final x = leftPad + i * stepX;
      final y = tempToY(data[i].tempMin);
      fillPath.lineTo(x, y);
    }
    fillPath.close();

    final fillPaint = Paint()
      ..color = maxColor.withAlpha(25)
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    // Max temp line
    final maxPaint = Paint()
      ..color = maxColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(maxPath, maxPaint);

    // Min temp line
    final minPaint = Paint()
      ..color = minColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(minPath, minPaint);

    // Dots + day labels
    final dotPaint = Paint()..color = maxColor;
    final dotPaintMin = Paint()..color = minColor;
    final dayLabelStyle = TextStyle(
      fontSize: 9,
      color: Colors.black54,
      fontWeight: FontWeight.w500,
    );

    for (var i = 0; i < data.length; i++) {
      final x = leftPad + i * stepX;
      final maxY = tempToY(data[i].tempMax);
      final minY = tempToY(data[i].tempMin);

      // Dots
      canvas.drawCircle(Offset(x, maxY), 3, dotPaint);
      canvas.drawCircle(Offset(x, minY), 3, dotPaintMin);

      // Day name below x-axis
      final dayName = dayNames[data[i].date.weekday - 1];
      TextPainter(
        text: TextSpan(text: dayName, style: dayLabelStyle),
        textDirection: TextDirection.ltr,
      )
        ..layout()
        ..paint(canvas, Offset(x - 6, h - bottomPad + 3));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}