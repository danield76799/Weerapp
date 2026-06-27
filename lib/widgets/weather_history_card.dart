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
            height: 120,
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
    final stepX = w / (data.length - 1);
    final padding = h * 0.15;
    final chartH = h - padding * 2;

    double tempToY(double temp) {
      final ratio = (temp - minTemp) / (maxTemp - minTemp);
      return padding + chartH * (1 - ratio.clamp(0.0, 1.0));
    }

    // Grid lines
    final gridPaint = Paint()
      ..color = Colors.white.withAlpha(15)
      ..strokeWidth = 0.5;
    for (var i = 0; i <= 3; i++) {
      final y = padding + (chartH / 3) * i;
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }

    // Max temp line (filled area)
    final maxPath = Path();
    final minPath = Path();

    for (var i = 0; i < data.length; i++) {
      final x = i * stepX;
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
      final x = i * stepX;
      final y = tempToY(data[i].tempMax);
      if (i == 0) {
        fillPath.moveTo(x, y);
      } else {
        fillPath.lineTo(x, y);
      }
    }
    for (var i = data.length - 1; i >= 0; i--) {
      final x = i * stepX;
      final y = tempToY(data[i].tempMin);
      fillPath.lineTo(x, y);
    }
    fillPath.close();

    final fillPaint = Paint()
      ..color = maxColor.withAlpha(30)
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

    // Dots + labels
    final dotPaint = Paint()..color = maxColor;
    final dotPaintMin = Paint()..color = minColor;
    final labelStyle = TextStyle(
      fontSize: 9,
      color: Colors.white.withAlpha(120),
    );
    final tempStyle = TextStyle(
      fontSize: 8,
      color: Colors.white.withAlpha(100),
    );

    for (var i = 0; i < data.length; i++) {
      final x = i * stepX;
      final maxY = tempToY(data[i].tempMax);
      final minY = tempToY(data[i].tempMin);

      // Dots
      canvas.drawCircle(Offset(x, maxY), 3, dotPaint);
      canvas.drawCircle(Offset(x, minY), 3, dotPaintMin);

      // Day name
      final dayName = dayNames[data[i].date.weekday - 1];
      TextPainter(
        text: TextSpan(text: dayName, style: labelStyle),
        textDirection: TextDirection.ltr,
      )
        ..layout()
        ..paint(canvas, Offset(x - 6, h - padding + 4));

      // Temp labels (only first and last to avoid clutter)
      if (i == 0 || i == data.length - 1) {
        TextPainter(
          text: TextSpan(text: '${data[i].tempMax.toStringAsFixed(0)}°', style: tempStyle),
          textDirection: TextDirection.ltr,
        )
          ..layout()
          ..paint(canvas, Offset(x - 8, maxY - 14));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}