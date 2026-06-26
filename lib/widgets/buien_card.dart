import 'package:flutter/material.dart';

import '../models/weather.dart';

/// Buienverwachting — regen de komende uren met "wanneer regent het?" highlight
class BuienCard extends StatelessWidget {
  final List<HourlyForecast> nextHours;

  const BuienCard({super.key, required this.nextHours});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Find first rain hour
    HourlyForecast? firstRain;
    int firstRainIndex = -1;
    for (var i = 0; i < nextHours.length; i++) {
      final h = nextHours[i];
      if ((h.precipitation ?? 0) > 0.1 || h.precipitationProbability > 30) {
        firstRain = h;
        firstRainIndex = i;
        break;
      }
    }

    final raining = firstRain != null;

    String advies;
    IconData icon;
    Color color;

    if (!raining) {
      advies = 'Het blijft droog de komende ${nextHours.length} uur.';
      icon = Icons.umbrella_outlined;
      color = const Color(0xFF4CAF50);
    } else if (firstRainIndex == 0) {
      advies = 'Het regent nu! Neem een paraplu mee.';
      icon = Icons.umbrella;
      color = const Color(0xFF1976D2);
    } else {
      final hoursUntilRain = firstRain!.time.hour;
      advies = 'Regen verwacht rond ${hoursUntilRain.toString().padLeft(2, '0')}:00 uur.';
      icon = Icons.umbrella;
      color = const Color(0xFFFF9800);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(40),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(120), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 28, color: color),
              const SizedBox(width: 10),
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
          if (raining) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: nextHours.length,
                itemBuilder: (context, i) {
                  final h = nextHours[i];
                  final intensity = (h.precipitation ?? 0);
                  final isRain = intensity > 0.1 || h.precipitationProbability > 30;
                  final isFirstRain = i == firstRainIndex;

                  return Container(
                    width: 48,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: isRain
                          ? (isFirstRain
                              ? color.withAlpha(200)
                              : color.withAlpha(80 + (intensity * 400).toInt().clamp(0, 120)))
                          : theme.colorScheme.surfaceContainerHigh.withAlpha(100),
                      borderRadius: BorderRadius.circular(8),
                      border: isFirstRain ? Border.all(color: color, width: 2) : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isRain && isFirstRain
                              ? '🌧'
                              : '${h.time.hour.toString().padLeft(2, '0')}u',
                          style: TextStyle(
                            fontSize: isRain && isFirstRain ? 14 : 10,
                            fontWeight: isFirstRain ? FontWeight.w700 : FontWeight.w400,
                            color: isRain
                                ? (isFirstRain ? Colors.white : color)
                                : theme.colorScheme.onSurface.withAlpha(120),
                          ),
                        ),
                        Text(
                          isRain ? '${h.precipitationProbability}%' : '—',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isRain ? FontWeight.w600 : FontWeight.w400,
                            color: isRain
                                ? (isFirstRain ? Colors.white : color)
                                : theme.colorScheme.onSurface.withAlpha(120),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}