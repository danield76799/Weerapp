import 'package:flutter/material.dart';

import '../models/weather.dart';

/// Buienverwachting met regendiagram — toont neerslag per uur voor de
/// komende 12 uur. Helder en leesbaar op een smalle telefoon.
class BuienCard extends StatelessWidget {
  final List<HourlyForecast> nextHours;

  const BuienCard({super.key, required this.nextHours});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Komende 12 uur (start bij het huidige uur, geen 30-min offset-rommel).
    final now = DateTime.now();
    final startOfHour = DateTime(now.year, now.month, now.day, now.hour);
    final next12h = nextHours
        .where((h) => !h.time.isBefore(startOfHour))
        .take(12)
        .toList();

    if (next12h.isEmpty) {
      return const SizedBox.shrink();
    }

    // Eerste regen-uur bepalen + zwaarste bui
    HourlyForecast? firstRain;
    double maxPrecip = 0;
    bool anyRain = false;
    for (final h in next12h) {
      final precip = h.precipitation ?? 0;
      final prob = h.precipitationProbability.toDouble();
      if (precip > 0.05 || prob > 20) {
        anyRain = true;
        firstRain ??= h;
        if (precip > maxPrecip) maxPrecip = precip;
      }
    }

    String advies;
    IconData icon;
    Color color;

    if (!anyRain) {
      advies = 'Het blijft droog de komende 12 uur. ☀️';
      icon = Icons.wb_sunny_outlined;
      color = const Color(0xFF4CAF50);
    } else if (firstRain!.time.hour == now.hour) {
      advies = 'Het regent nu! 🌧';
      icon = Icons.umbrella;
      color = const Color(0xFF1976D2);
    } else {
      final rain = firstRain; // non-null: anyRain is true en firstRain is gezet
      final diffMinutes = rain.time.difference(now).inMinutes;
      final hoursUntilRain = diffMinutes ~/ 60;
      final minutesUntilRain = diffMinutes % 60;
      if (hoursUntilRain > 0) {
        advies = minutesUntilRain > 0
            ? 'Regen over $hoursUntilRain u $minutesUntilRain min.'
            : 'Regen over $hoursUntilRain uur.';
      } else {
        advies = 'Regen over $minutesUntilRain min.';
      }
      icon = Icons.umbrella;
      color = const Color(0xFFFF9800);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withAlpha(150),
            color.withAlpha(60),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(160), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status-regel
          Row(
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  advies,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // 12 bars, één per uur
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < next12h.length; i++)
                  _HourBar(
                    hour: next12h[i],
                    maxPrecip: maxPrecip,
                    color: color,
                    isFirstRain: next12h[i].time == firstRain?.time,
                    showHourLabel: i % 2 == 0, // 00, 02, 04, ...
                    theme: theme,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Legenda
          Row(
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
        ],
      ),
    );
  }
}

class _HourBar extends StatelessWidget {
  final HourlyForecast hour;
  final double maxPrecip;
  final Color color;
  final bool isFirstRain;
  final bool showHourLabel;
  final ThemeData theme;

  const _HourBar({
    required this.hour,
    required this.maxPrecip,
    required this.color,
    required this.isFirstRain,
    required this.showHourLabel,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final precip = hour.precipitation ?? 0;
    final prob = hour.precipitationProbability.toDouble();
    final isRain = precip > 0.05 || prob > 20;

    final barHeight = maxPrecip > 0
        ? ((precip / maxPrecip) * 86).clamp(3.0, 86.0)
        : 3.0;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1.5),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // mm-label boven de bar (alleen bij regen, leesbaar formaat)
            if (isRain && precip >= 0.3)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  precip.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isFirstRain ? FontWeight.w700 : FontWeight.w400,
                    color: isFirstRain
                        ? color
                        : theme.colorScheme.onSurface.withAlpha(160),
                  ),
                ),
              )
            else
              const SizedBox(height: 14),
            // De bar
            Container(
              width: double.infinity,
              height: barHeight,
              decoration: BoxDecoration(
                color: isRain ? null : theme.colorScheme.surfaceContainerHighest,
                gradient: isRain
                    ? LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          color.withAlpha(220),
                          color.withAlpha(110),
                        ],
                      )
                    : null,
                borderRadius: BorderRadius.circular(4),
                border: isFirstRain ? Border.all(color: color, width: 1.5) : null,
              ),
            ),
            const SizedBox(height: 4),
            // Uur-label (elke 2e)
            SizedBox(
              height: 16,
              child: showHourLabel
                  ? Text(
                      hour.time.hour.toString().padLeft(2, '0'),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isFirstRain ? FontWeight.w700 : FontWeight.w400,
                        color: isFirstRain
                            ? color
                            : theme.colorScheme.onSurface.withAlpha(120),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
