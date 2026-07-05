import 'package:flutter/material.dart';

import '../models/weather.dart';
import '../utils/weather_utils.dart';

/// "Kan ik zonder jas?" — slim advies op basis van temperatuur, gevoel en regen
class JasAdviceCard extends StatelessWidget {
  final CurrentWeather current;
  final List<HourlyForecast> nextHours;

  const JasAdviceCard({
    super.key,
    required this.current,
    required this.nextHours,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final advies = _buildAdvice();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: advies.color.withAlpha(60),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: advies.color.withAlpha(40),
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
          Icon(advies.icon, size: 32, color: advies.color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  advies.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: advies.color,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  advies.body,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(220),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  ({String title, String body, IconData icon, Color color}) _buildAdvice() {
    final temp = current.feelsLike;
    final rain = nextHours.any((h) => h.precipitation != null && h.precipitation! > 0.1);

    if (temp >= 27) {
      return (
        title: 'Kan ik zonder jas? Ja!',
        body: 'Het voelt als ${temp.toStringAsFixed(0)}° en het blijft ${rain ? 'niet' : 'droog'}. Je jas kan thuisblijven.',
        icon: Icons.wb_sunny,
        color: const Color(0xFFE65100),
      );
    }
    if (temp >= 20) {
      return (
        title: 'Kan ik zonder jas? Ja',
        body: 'Het voelt als ${temp.toStringAsFixed(0)}° en het blijft ${rain ? 'niet helemaal' : 'droog'}. Je jas kan thuisblijven.',
        icon: Icons.wb_sunny_outlined,
        color: const Color(0xFF2E7D32),
      );
    }
    if (temp >= 12) {
      return (
        title: 'Een trui is genoeg',
        body: 'Het voelt als ${temp.toStringAsFixed(0)}°. Geen jas nodig, maar een trui is prettig.',
        icon: Icons.checkroom,
        color: const Color(0xFF558B2F),
      );
    }
    if (temp >= 0) {
      return (
        title: 'Jas aan!',
        body: 'Het voelt als ${temp.toStringAsFixed(0)}°. Een jas is nodig — het is koud buiten.',
        icon: Icons.checkroom_outlined,
        color: const Color(0xFF1565C0),
      );
    }
    return (
        title: 'Blijf binnen!',
        body: 'Het voelt als ${temp.toStringAsFixed(0)}°. Het vriest — warm aankleden of binnen blijven.',
        icon: Icons.severe_cold,
        color: const Color(0xFF0D47A1),
    );
  }
}