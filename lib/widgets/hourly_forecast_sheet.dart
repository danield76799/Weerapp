import 'package:flutter/material.dart';

import '../models/weather.dart';
import '../utils/weather_utils.dart';

/// Toont een horizontale scrollbare lijst met temperatuur per uur voor één dag.
/// Wordt getoond als je op een dag in de 16-daagse forecast tikt.
class HourlyForecastSheet extends StatelessWidget {
  final DateTime date;
  final List<HourlyForecast> hours;

  const HourlyForecastSheet({
    super.key,
    required this.date,
    required this.hours,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dayNames = ['maandag', 'dinsdag', 'woensdag', 'donderdag', 'vrijdag', 'zaterdag', 'zondag'];
    final monthNames = ['jan', 'feb', 'mrt', 'apr', 'mei', 'jun', 'jul', 'aug', 'sep', 'okt', 'nov', 'dec'];
    final title = '${dayNames[date.weekday - 1]} ${date.day} ${monthNames[date.month - 1]}';

    if (hours.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text('Geen uurdata beschikbaar',
              style: theme.textTheme.bodyMedium),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withAlpha(60),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Text(title,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('${hours.length} uur',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurface.withAlpha(150))),
              ],
            ),
          ),
          // Horizontal scroll with hours
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: hours.length,
              itemBuilder: (context, i) {
                final h = hours[i];
                final isDay = h.time.hour >= 6 && h.time.hour < 21;
                final icon = WeatherUtils.iconForWmoCode(h.weatherCode, isDay: isDay);
                final iconColor = WeatherUtils.colorForWmoCode(h.weatherCode);
                final tempColor = WeatherUtils.tempColor(h.temperature);
                final uv = WeatherUtils.uvInfo(h.uvIndex);

                return Container(
                  width: 64,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh.withAlpha(120),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${h.time.hour.toString().padLeft(2, '0')}:00',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withAlpha(180),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Icon(icon, color: iconColor, size: 22),
                      const SizedBox(height: 4),
                      Text(
                        '${h.temperature.toStringAsFixed(0)}°',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: tempColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (h.precipitationProbability > 10)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.water_drop,
                                size: 10,
                                color: theme.colorScheme.onSurface.withAlpha(150)),
                            const SizedBox(width: 2),
                            Text(
                              '${h.precipitationProbability}%',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 10,
                                color: theme.colorScheme.onSurface.withAlpha(150),
                              ),
                            ),
                          ],
                        ),
                      if (h.uvIndex >= 3)
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: uv.color,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            h.uvIndex.toStringAsFixed(0),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}