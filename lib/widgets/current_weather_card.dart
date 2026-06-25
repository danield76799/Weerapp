import 'package:flutter/material.dart';

import '../models/weather.dart';
import '../utils/weather_utils.dart';

/// Toont huidig weer: grote temp, icoon, UV-badge, details (voelt, wind, etc.)
class CurrentWeatherCard extends StatelessWidget {
  final CurrentWeather current;
  final String locationName;

  const CurrentWeatherCard({
    super.key,
    required this.current,
    required this.locationName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final uv = WeatherUtils.uvInfo(current.uvIndex);
    final icon = WeatherUtils.iconForCode(current.weatherCode);
    final iconColor = WeatherUtils.colorForCode(current.weatherCode);
    final tempColor = WeatherUtils.tempColor(current.temperature);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, size: 18, color: theme.colorScheme.onSurface),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  locationName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 72, color: iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          current.temperature.toStringAsFixed(0),
                          style: theme.textTheme.displayLarge?.copyWith(
                            fontSize: 72,
                            fontWeight: FontWeight.w200,
                            color: tempColor,
                            height: 1,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text('°C',
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: theme.colorScheme.onSurface.withAlpha(180),
                              )),
                        ),
                      ],
                    ),
                    Text(
                      current.weatherDescription,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(200),
                      ),
                    ),
                    Text(
                      'Voelt als ${current.feelsLike.toStringAsFixed(0)}°C',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(150),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // UV badge — prominent
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: uv.color.withAlpha(40),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: uv.color.withAlpha(180), width: 1.5),
            ),
            child: Row(
              children: [
                Icon(Icons.wb_sunny, color: uv.color, size: 22),
                const SizedBox(width: 8),
                Text('UV-index',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurface)),
                const Spacer(),
                Text(
                  current.uvIndex.toStringAsFixed(1),
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: uv.color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 6),
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
          ),
          if (uv.advice.isNotEmpty) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                uv.advice,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(150),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          // Details grid
          Row(
            children: [
              _DetailChip(
                icon: Icons.air,
                label: WeatherUtils.windDescription(current.windSpeed),
                value: '${current.windSpeed.toStringAsFixed(1)} m/s',
              ),
              const SizedBox(width: 8),
              _DetailChip(
                icon: Icons.water_drop_outlined,
                label: 'Luchtvochtigheid',
                value: '${current.humidity}%',
              ),
              const SizedBox(width: 8),
              _DetailChip(
                icon: Icons.cloud_outlined,
                label: 'Bewolking',
                value: '${current.clouds}%',
              ),
            ],
          ),
          if (current.precipitation != null && current.precipitation! > 0) ...[
            const SizedBox(height: 8),
            _DetailChip(
              icon: Icons.umbrella,
              label: 'Neerslag laatste uur',
              value: '${current.precipitation!.toStringAsFixed(1)} mm',
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailChip({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withAlpha(180),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: theme.colorScheme.onSurface.withAlpha(180)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(180),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
