import 'package:flutter/material.dart';

import '../models/weather.dart';
import '../utils/weather_utils.dart';

/// "Moet ik me insmeren?" — UV advies met humor
class ZonnebrandCard extends StatelessWidget {
  final CurrentWeather current;

  const ZonnebrandCard({super.key, required this.current});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final uv = WeatherUtils.uvInfo(current.uvIndex);
    final advies = _buildAdvice(current.uvIndex);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: uv.color.withAlpha(40),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: uv.color.withAlpha(120), width: 1.5),
      ),
      child: Row(
        children: [
          Icon(Icons.wb_sunny, size: 36, color: uv.color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Moet ik me insmeren?',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  advies,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(200),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      'UV ${current.uvIndex.toStringAsFixed(1)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: uv.color,
                      ),
                    ),
                    const SizedBox(width: 8),
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

  String _buildAdvice(double uv) {
    if (uv < 3) return 'Nee — UV is laag. Je kan veilig naar buiten zonder bescherming.';
    if (uv < 6) return 'Ja, bij lang verblijf buiten. Smeer je in als je langer dan een uur buiten bent.';
    if (uv < 8) return 'Ja! Bescherming noodzakelijk. Smeer je in tussen 11:00 en 15:00.';
    if (uv < 11) return 'Absoluut! Vermijd de middagzon. Smeer je in (en je kale kruin).';
    return 'Ja! Blijf binnen tussen 11:00 en 15:00. UV is extreem.';
  }
}