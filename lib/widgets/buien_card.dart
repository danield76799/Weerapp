import 'package:flutter/material.dart';

import '../models/weather.dart';

/// Buienverwachting met regendiagram — toont hoeveel mm regen per uur
class BuienCard extends StatelessWidget {
  final List<HourlyForecast> nextHours;

  const BuienCard({super.key, required this.nextHours});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Filter to the next 24 hours only
    final now = DateTime.now();
    final next24h = nextHours
        .where((h) => !h.time.isBefore(now.subtract(const Duration(minutes: 30))))
        .take(24)
        .toList();

    if (next24h.isEmpty) {
      return const SizedBox.shrink();
    }

    // Find first rain hour
    HourlyForecast? firstRain;
    int firstRainIndex = -1;
    double maxPrecip = 0;
    final rainHours = <HourlyForecast>[];
    bool anyRain = false;

    for (var i = 0; i < next24h.length; i++) {
      final h = next24h[i];
      final precip = h.precipitation ?? 0;
      final precipProb = h.precipitationProbability.toDouble();
      if (precip > 0.05 || precipProb > 20) {
        anyRain = true;
        rainHours.add(h);
        if (precip > maxPrecip) maxPrecip = precip;
        if (firstRainIndex == -1) {
          firstRain = h;
          firstRainIndex = i;
        }
      }
    }

    String advies;
    IconData icon;
    Color color;

    if (next24h.isEmpty) {
      advies = 'Geen gegevens beschikbaar.';
      icon = Icons.cloud_off;
      color = const Color(0xFF9E9E9E);
    } else if (!anyRain) {
      advies = 'Het blijft droog de komende ${next24h.length} uur.';
      icon = Icons.umbrella_outlined;
      color = const Color(0xFF4CAF50);
    } else if (firstRainIndex == 0) {
      advies = 'Het regent nu! 🌧';
      icon = Icons.umbrella;
      color = const Color(0xFF1976D2);
    } else {
      final now = DateTime.now();
      final diffMinutes = firstRain!.time.difference(now).inMinutes;
      final hoursUntilRain = diffMinutes ~/ 60;
      final minutesUntilRain = diffMinutes % 60;
      if (hoursUntilRain > 0) {
        advies = 'Regen verwacht over ${hoursUntilRain}u${minutesUntilRain > 0 ? ' ${minutesUntilRain}min' : ''}.';
      } else {
        advies = 'Regen verwacht over ${minutesUntilRain} min.';
      }
      icon = Icons.umbrella;
      color = const Color(0xFFFF9800);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(40),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: color.withAlpha(120), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 24, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  advies,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Bar chart
          SizedBox(
            height: 110,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final barAreaHeight = constraints.maxHeight - 34; // reserve 12 + 2 + 4 + 16
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: next24h.map((h) {
                final precip = h.precipitation ?? 0;
                final prob = h.precipitationProbability.toDouble();
                final isRain = precip > 0.05 || prob > 20;
                final isFirst = h.time == firstRain?.time;

                final barHeight = maxPrecip > 0
                    ? ((precip / maxPrecip) * barAreaHeight).clamp(2.0, barAreaHeight)
                    : 2.0;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                // mm label at top if rain
                        if (isRain && precip >= 0.5)
                          SizedBox(
                            height: 12,
                            child: Text(
                              '${precip.toStringAsFixed(1)}',
                              style: TextStyle(
                                fontSize: 7,
                                fontWeight: isFirst ? FontWeight.w700 : FontWeight.w400,
                                color: isFirst ? color : theme.colorScheme.onSurface.withAlpha(150),
                              ),
                            ),
                          )
                        else
                          const SizedBox(height: 12),
                        const SizedBox(height: 2),
                        // Bar
                        Container(
                          width: double.infinity,
                          height: barHeight,
                          decoration: BoxDecoration(
                            color: isRain
                                ? color.withAlpha(120 + ((precip / (maxPrecip > 0 ? maxPrecip : 1)) * 100).toInt().clamp(0, 100))
                                : theme.colorScheme.surfaceContainerHigh.withAlpha(80),
                            borderRadius: BorderRadius.circular(3),
                            border: isFirst
                                ? Border.all(color: Colors.white, width: 1)
                                : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Hour label
                        SizedBox(
                          height: 16,
                          child: Text(
                            '${h.time.hour.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: isFirst ? FontWeight.w700 : FontWeight.w400,
                              color: isFirst ? color : theme.colorScheme.onSurface.withAlpha(120),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
              },
            ),
          ),
          // Legend
          if (anyRain)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.circle, size: 6, color: color.withAlpha(120)),
                  const SizedBox(width: 4),
                  Text(
                    'Regenintensiteit in mm per uur',
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.onSurface.withAlpha(120),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}