import 'package:flutter/material.dart';

import '../models/weather.dart';
import '../utils/weather_utils.dart';
import 'hourly_forecast_sheet.dart';

class DailyForecastList extends StatelessWidget {
  final List<DailyForecast> days;
  final List<HourlyForecast> hourly;
  final String locationName;

  const DailyForecastList({
    super.key,
    required this.days,
    required this.hourly,
    required this.locationName,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: days.asMap().entries.map((entry) {
        final i = entry.key;
        final day = entry.value;
        return _DailyTile(
          day: day,
          isToday: i == 0,
          onTap: () => _showHourly(context, day.date),
        );
      }).toList(),
    );
  }

  void _showHourly(BuildContext context, DateTime date) {
    final dayHours = hourly
        .where((h) =>
            h.time.year == date.year &&
            h.time.month == date.month &&
            h.time.day == date.day)
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: HourlyForecastSheet(
          date: date,
          hours: dayHours,
        ),
      ),
    );
  }
}

class _DailyTile extends StatelessWidget {
  final DailyForecast day;
  final bool isToday;
  final VoidCallback? onTap;

  const _DailyTile({
    required this.day,
    required this.isToday,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dayNames = ['maandag', 'dinsdag', 'woensdag', 'donderdag', 'vrijdag', 'zaterdag', 'zondag'];
    final dayName = isToday ? 'Vandaag' : dayNames[day.date.weekday - 1];
    final dateStr = '${day.date.day} ${_monthName(day.date.month)}';
    final icon = WeatherUtils.iconForWmoCode(day.weatherCode);
    final iconColor = WeatherUtils.colorForWmoCode(day.weatherCode);
    final uv = WeatherUtils.uvInfo(day.uvIndex);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 5),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
            border: isToday
                ? Border.all(color: theme.colorScheme.primary.withAlpha(130), width: 1.5)
                : Border.all(color: theme.colorScheme.onSurface.withAlpha(60), width: 1),
            boxShadow: isToday
                ? [
                    BoxShadow(
                      color: theme.colorScheme.primary.withAlpha(40),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 72,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dayName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                          fontSize: 15,
                          color: isToday ? theme.colorScheme.primary : null,
                        )),
                    const SizedBox(height: 2),
                    Text(dateStr,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withAlpha(200),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withAlpha(28),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 44,
                child: day.precipitationProbability > 0.1
                    ? FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(children: [
                          Icon(Icons.water_drop,
                              size: 14,
                              color: theme.colorScheme.onSurface.withAlpha(200)),
                          const SizedBox(width: 2),
                          Text('${(day.precipitationProbability * 100).toInt()}%',
                              style: theme.textTheme.bodySmall),
                        ]),
                      )
                    : const SizedBox.shrink(),
              ),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(color: uv.color, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(day.uvIndex.toStringAsFixed(0),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    )),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text('${day.tempMin.toStringAsFixed(0)}°',
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(200),
                    )),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _TempRangeBar(min: day.tempMin, max: day.tempMax),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text('${day.tempMax.toStringAsFixed(0)}°',
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: WeatherUtils.tempColor(day.tempMax),
                    )),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _monthName(int month) {
    const names = ['jan', 'feb', 'mrt', 'apr', 'mei', 'jun', 'jul', 'aug', 'sep', 'okt', 'nov', 'dec'];
    return names[month - 1];
  }
}

class _TempRangeBar extends StatelessWidget {
  final double min;
  final double max;
  const _TempRangeBar({required this.min, required this.max});

  @override
  Widget build(BuildContext context) {
    const minScale = -10.0;
    const maxScale = 35.0;
    final minPct = ((min - minScale) / (maxScale - minScale)).clamp(0.0, 1.0);
    final maxPct = ((max - minScale) / (maxScale - minScale)).clamp(0.0, 1.0);
    const width = 60.0;
    const barHeight = 4.0;
    final activeWidth = (maxPct - minPct) * width;

    return SizedBox(
      width: width,
      height: 14,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
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
          Positioned(
            left: minPct * width,
            top: (14 - barHeight) / 2,
            child: Container(
              width: activeWidth.clamp(2.0, width),
              height: barHeight,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [
                  Color(0xFF42A5F5),
                  Color(0xFFFFA726),
                  Color(0xFFEF6C00),
                ]),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}