import 'package:flutter/material.dart';

import '../models/weather.dart';
import '../utils/weather_utils.dart';

/// "Moet ik me insmeren?" — UV advies met humor
class ZonnebrandCard extends StatelessWidget {
  final CurrentWeather current;
  final List<HourlyForecast>? nextHours;

  const ZonnebrandCard({
    super.key,
    required this.current,
    this.nextHours,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Kijk niet alleen naar de huidige UV, maar naar de verwachte piek van
    // vandaag. Anders staat er 's ochtends "Nee" terwijl het om 13:00 alsnog
    // hoog wordt.
    final todayUv = _peakUvToday();
    final uv = WeatherUtils.uvInfo(todayUv);
    final advice = _buildAdvice(todayUv);

    // Hint als de piek later op de dag valt dan nu.
    final peakHour = _peakUvHour();
    final now = DateTime.now();
    final String? timingHint;
    if (peakHour != null &&
        (peakHour.difference(now).inMinutes > 60) &&
        todayUv >= 3) {
      final h = peakHour.hour.toString().padLeft(2, '0');
      timingHint = 'Piek rond $h:00 uur';
    } else {
      timingHint = null;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: uv.color.withAlpha(80),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.wb_sunny, size: 32, color: uv.color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Moet ik me insmeren?',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  advice,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(220),
                    fontSize: 13,
                  ),
                ),
                if (timingHint != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.schedule, size: 12, color: Colors.orange),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          timingHint,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.orange.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 6),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    Text(
                      'UV ${todayUv.toStringAsFixed(1)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Color.lerp(uv.color, Colors.black, 0.6) ?? uv.color,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: uv.color,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        uv.label.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Hoogste UV-index verwacht voor de rest van vandaag (uurlijkse data).
  double _peakUvToday() {
    final now = DateTime.now();
    var peak = current.uvIndex;
    final hours = nextHours;
    if (hours != null) {
      for (final h in hours) {
        // Alleen uren van vandaag die nog komen (of nu) meetellen.
        if (h.time.year == now.year &&
            h.time.month == now.month &&
            h.time.day == now.day &&
            !h.time.isBefore(now.subtract(const Duration(minutes: 30)))) {
          if (h.uvIndex > peak) peak = h.uvIndex;
        }
      }
    }
    return peak;
  }

  /// Tijdstip van de UV-piek vandaag (voor de "piek rond HH:00" hint).
  DateTime? _peakUvHour() {
    final now = DateTime.now();
    final hours = nextHours;
    if (hours == null || hours.isEmpty) return null;
    var peak = current.uvIndex;
    DateTime? peakTime = now;
    for (final h in hours) {
      if (h.time.year == now.year &&
          h.time.month == now.month &&
          h.time.day == now.day &&
          !h.time.isBefore(now.subtract(const Duration(minutes: 30)))) {
        if (h.uvIndex > peak) {
          peak = h.uvIndex;
          peakTime = h.time;
        }
      }
    }
    return peakTime;
  }

  String _buildAdvice(double uv) {
    String advice;
    if (uv < 3) {
      advice = 'Nee — UV is laag. Je kan veilig naar buiten zonder bescherming.';
    } else if (uv < 6) {
      advice = 'Ja, bij lang verblijf buiten. Smeer je in als je langer dan een uur buiten bent.';
    } else if (uv < 8) {
      advice = 'Ja! Bescherming noodzakelijk. Smeer je in tussen 11:00 en 15:00.';
    } else if (uv < 11) {
      advice = 'Absoluut! Vermijd de middagzon. Smeer je in (en je kale kruin).';
    } else {
      advice = 'Ja! Blijf binnen tussen 11:00 en 15:00. UV is extreem.';
    }
    return advice + ' Herhaal elke 2 uur, ook na zweten of zwemmen.';
  }
}