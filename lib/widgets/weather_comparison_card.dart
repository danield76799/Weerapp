import 'package:flutter/material.dart';

import '../models/weather.dart';

/// Vergelijkt deze week met vorige week op basis van historische data.
/// Toont of het warmer/kouder/natter/droger is dan de week ervoor.
class WeatherComparisonCard extends StatelessWidget {
  final List<DailyForecast> pastDaily;
  final List<DailyForecast> daily;

  const WeatherComparisonCard({
    super.key,
    required this.pastDaily,
    required this.daily,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // We need at least 7 past days + some forecast to compare
    if (pastDaily.length < 7 || daily.isEmpty) {
      return const SizedBox.shrink();
    }

    // This week: last 7 days from pastDaily (including today if in pastDaily)
    // If today is in daily (not pastDaily), include it
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    // Build "this week": the most recent 7 days we have data for
    final thisWeek = <DailyForecast>[];
    // pastDaily already contains days before today
    thisWeek.addAll(pastDaily);
    // Add today from daily if available
    if (daily.isNotEmpty) {
      thisWeek.add(daily.first);
    }
    // Take last 7
    if (thisWeek.length > 7) {
      thisWeek.removeRange(0, thisWeek.length - 7);
    }

    // Previous week: the 7 days before this week
    final prevWeekEnd = thisWeek.isNotEmpty ? thisWeek.first.date : todayDate;
    final prevWeek = <DailyForecast>[];
    for (final d in pastDaily) {
      if (d.date.isBefore(prevWeekEnd)) {
        prevWeek.add(d);
      }
    }
    // Take last 7 of those
    if (prevWeek.length > 7) {
      prevWeek.removeRange(0, prevWeek.length - 7);
    }

    if (thisWeek.length < 3 || prevWeek.length < 3) {
      return const SizedBox.shrink();
    }

    // Calculate averages
    final thisWeekAvgMax = thisWeek.map((d) => d.tempMax).reduce((a, b) => a + b) / thisWeek.length;
    final prevWeekAvgMax = prevWeek.map((d) => d.tempMax).reduce((a, b) => a + b) / prevWeek.length;

    final thisWeekRain = thisWeek.map((d) => d.precipitationAmount).reduce((a, b) => a + b);
    final prevWeekRain = prevWeek.map((d) => d.precipitationAmount).reduce((a, b) => a + b);

    final thisWeekSunHours = thisWeek
        .map((d) => d.sunshineHours ?? 0)
        .reduce((a, b) => a + b);
    final prevWeekSunHours = prevWeek
        .map((d) => d.sunshineHours ?? 0)
        .reduce((a, b) => a + b);

    final tempDiff = thisWeekAvgMax - prevWeekAvgMax;
    final rainDiff = thisWeekRain - prevWeekRain;
    final sunDiff = thisWeekSunHours - prevWeekSunHours;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.compare_arrows, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Weekvergelijking',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Deze week vs vorige week',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(150),
            ),
          ),
          const SizedBox(height: 14),
          // Temperatuur
          _ComparisonRow(
            icon: Icons.thermostat,
            iconColor: tempDiff > 0 ? const Color(0xFFEF5350) : const Color(0xFF42A5F5),
            label: 'Gem. max temperatuur',
            thisValue: '${thisWeekAvgMax.toStringAsFixed(0)}°',
            prevValue: '${prevWeekAvgMax.toStringAsFixed(0)}°',
            diff: tempDiff,
            diffUnit: '°',
            higherIsWarmer: true,
          ),
          const SizedBox(height: 10),
          // Neerslag
          _ComparisonRow(
            icon: Icons.water_drop,
            iconColor: const Color(0xFF42A5F5),
            label: 'Totale neerslag',
            thisValue: '${thisWeekRain.toStringAsFixed(1)} mm',
            prevValue: '${prevWeekRain.toStringAsFixed(1)} mm',
            diff: rainDiff,
            diffUnit: ' mm',
            higherIsWarmer: false,
          ),
          const SizedBox(height: 10),
          // Zonuren
          _ComparisonRow(
            icon: Icons.wb_sunny,
            iconColor: const Color(0xFFFFA726),
            label: 'Zonuren',
            thisValue: '${thisWeekSunHours.toStringAsFixed(0)}u',
            prevValue: '${prevWeekSunHours.toStringAsFixed(0)}u',
            diff: sunDiff,
            diffUnit: 'u',
            higherIsWarmer: true,
          ),
        ],
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String thisValue;
  final String prevValue;
  final double diff;
  final String diffUnit;
  final bool higherIsWarmer;

  const _ComparisonRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.thisValue,
    required this.prevValue,
    required this.diff,
    required this.diffUnit,
    required this.higherIsWarmer,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final absDiff = diff.abs();
    final isUp = diff > 0.01;
    final isDown = diff < -0.01;
    final isSame = !isUp && !isDown;

    String diffText;
    Color diffColor;
    IconData diffIcon;

    if (isSame) {
      diffText = 'gelijk';
      diffColor = theme.colorScheme.onSurface.withAlpha(150);
      diffIcon = Icons.remove;
    } else {
      diffText = '${isUp ? '+' : '-'}${absDiff.toStringAsFixed(absDiff < 1 ? 1 : 0)}$diffUnit';
      if (higherIsWarmer) {
        diffColor = isUp ? const Color(0xFFEF5350) : const Color(0xFF42A5F5);
      } else {
        // For rain: more rain = blue, less rain = orange (drier)
        diffColor = isUp ? const Color(0xFF42A5F5) : const Color(0xFFFFA726);
      }
      diffIcon = isUp ? Icons.arrow_upward : Icons.arrow_downward;
    }

    return Row(
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(180),
              )),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    thisValue,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '(vorige: $prevValue)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(120),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: diffColor.withAlpha(45),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: diffColor.withAlpha(80), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(diffIcon, size: 14, color: diffColor),
              const SizedBox(width: 4),
              Text(
                diffText,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: diffColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}