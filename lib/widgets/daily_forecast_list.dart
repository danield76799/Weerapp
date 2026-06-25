import 'package:flutter/material.dart';

import '../models/weather.dart';
import '../utils/weather_utils.dart';

class DailyForecastList extends StatelessWidget {
  final List<DailyForecast> days;

  const DailyForecastList({super.key, required this.days});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: days.asMap().entries.map((entry) {
        final i = entry.key;
        final day = entry.value;
        return _DailyTile(day: day, isToday: i == 0);
      }).toList(),
    );
  }
}

class _DailyTile extends StatelessWidget {
  final DailyForecast day;
  final bool isToday;
  const _DailyTile({required this.day, required this.isToday});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Use simple Dutch day names without locale initialization
    final dayNames = ['maandag', 'dinsdag', 'woensdag', 'donderdag', 'vrijdag', 'zaterdag', 'zondag'];
    final dayName = isToday ? 'Vandaag' : dayNames[day.date.weekday - 1];
    final dateStr = '${day.date.day} ${_monthName(day.date.month)}';
    final icon = WeatherUtils.iconForCode(day.weatherCode);
    final iconColor = WeatherUtils.colorForCode(day.weatherCode);
    final uv = WeatherUtils.uvInfo(day.uvIndex);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh.withAlpha(isToday ? 200 : 120),
        borderRadius: BorderRadius.circular(14),
        border: isToday
            ? Border.all(color: theme.colorScheme.primary.withAlpha(120), width: 1.5)
            : null,
      ),
      child: Row(
        children: [
          // Datum
          SizedBox(
            width: 88,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dayName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                    color: isToday ? theme.colorScheme.primary : null,
                  ),
                ),
                Text(
                  dateStr,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(150),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Icoon
          Icon(icon, color: iconColor, size: 32),
          const SizedBox(width: 8),
          // Neerslagkans
          SizedBox(
            width: 50,
            child: day.precipitationProbability > 0.1
                ? Row(
                    children: [
                      Icon(Icons.water_drop, size: 14, color: theme.colorScheme.onSurface.withAlpha(150)),
                      const SizedBox(width: 2),
                      Text(
                        '${(day.precipitationProbability * 100).toInt()}%',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
          // UV mini-badge
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: uv.color,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              day.uvIndex.toStringAsFixed(0),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Spacer(),
          // Min temp
          Text(
            '${day.tempMin.toStringAsFixed(0)}°',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(150),
            ),
          ),
          const SizedBox(width: 8),
          // Temperatuur range balk
          SizedBox(
            width: 60,
            child: _TempRangeBar(min: day.tempMin, max: day.tempMax),
          ),
          const SizedBox(width: 8),
          // Max temp
          Text(
            '${day.tempMax.toStringAsFixed(0)}°',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: WeatherUtils.tempColor(day.tempMax),
            ),
          ),
        ],
      ),
    );
  }

  static String _monthName(int month) {
    const names = [
      'jan', 'feb', 'mrt', 'apr', 'mei', 'jun',
      'jul', 'aug', 'sep', 'okt', 'nov', 'dec'
    ];
    return names[month - 1];
  }
}

class _TempRangeBar extends StatelessWidget {
  final double min;
  final double max;
  const _TempRangeBar({required this.min, required this.max});

  @override
  Widget build(BuildContext context) {
    // Clip waarden voor de gradient bar (typische range -10 .. +35)
    const minScale = -10.0;
    const maxScale = 35.0;
    final minPct = ((min - minScale) / (maxScale - minScale)).clamp(0.0, 1.0);
    final maxPct = ((max - minScale) / (maxScale - minScale)).clamp(0.0, 1.0);
    final width = 60.0;
    final barHeight = 4.0;
    final activeWidth = (maxPct - minPct) * width;

    return SizedBox(
      width: width,
      height: 14,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          // Track
          Positioned(
            left: 0,
            right: 0,
            top: (14 - barHeight) / 2,
            child: Container(
              height: barHeight,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Active range
          Positioned(
            left: minPct * width,
            top: (14 - barHeight) / 2,
            child: Container(
              width: activeWidth.clamp(2.0, width),
              height: barHeight,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF42A5F5),
                    Color(0xFFFFA726),
                    Color(0xFFEF6C00),
                  ],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
