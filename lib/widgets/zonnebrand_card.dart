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
        color: uv.color.withAlpha(60),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: uv.color.withAlpha(40),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: theme.colorScheme.outline.withAlpha(80),
          width: 1.2,
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
                  advies,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(220),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    Text(
                      'UV ${current.uvIndex.toStringAsFixed(1)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Color.lerp(uv.color, Colors.black, 0.6) ?? uv.color, // Maak de kleur donkerder voor WCAG contrast
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

  String _buildAdvice(double uv) {
    if (uv < 3) {
      return 'UV is laag. Je kan veilig naar buiten.';
    }
    if (uv < 6) {
      return 'Matig risico. Smeer je in als je langer dan een uur buiten bent.';
    }
    if (uv < 8) {
      return 'Bescherming noodzakelijk. Smeer je in tussen 11:00 en 15:00.';
    }
    if (uv < 11) {
      return 'Vermijd de middagzon. Smeer je in.';
    }
    return 'Blijf binnen tussen 11:00 en 15:00. UV is extreem.';
  }
}