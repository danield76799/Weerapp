import 'package:flutter/material.dart';

import '../models/weather.dart';
import '../utils/sky_gradient.dart';
import '../utils/weather_utils.dart';

/// Toont huidig weer: grote temp, icoon, UV-badge, details (voelt, wind, etc.)
class CurrentWeatherCard extends StatelessWidget {
  final CurrentWeather current;
  final String locationName;
  final DateTime? sunrise;
  final DateTime? sunset;

  const CurrentWeatherCard({
    super.key,
    required this.current,
    required this.locationName,
    this.sunrise,
    this.sunset,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final uv = WeatherUtils.uvInfo(current.uvIndex);
    final icon = WeatherUtils.iconForWmoCode(current.weatherCode);
    final iconColor = WeatherUtils.colorForWmoCode(current.weatherCode);

    // Dynamische lucht gradient op basis van actuele tijd
    final skyColors = SkyGradient.getColors(DateTime.now());

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: skyColors,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, size: 18, color: Colors.white),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    locationName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
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
                            style: const TextStyle(
                              fontSize: 72,
                              fontWeight: FontWeight.w200,
                              color: Colors.white,
                              height: 1,
                              shadows: [
                                Shadow(
                                  color: Colors.black38,
                                  blurRadius: 4,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text('°C',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black38,
                                      blurRadius: 3,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                )),
                          ),
                        ],
                      ),
                      Text(
                        current.weatherDescription,
                        style: const TextStyle(
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.black38,
                              blurRadius: 3,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'Voelt als ${current.feelsLike.toStringAsFixed(0)}°C',
                        style: const TextStyle(
                          color: Colors.white70,
                          shadows: [
                            Shadow(
                              color: Colors.black38,
                              blurRadius: 2,
                              offset: Offset(0, 1),
                            ),
                          ],
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
                          ?.copyWith(color: Colors.white)),
                  const Spacer(),
                  Text(
                    current.uvIndex.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Colors.amber,
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
                style: const TextStyle(
                  color: Colors.white70,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          // Zonsopgang / zonsondergang klok
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh.withAlpha(100),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _SunTimeItem(
                  icon: Icons.wb_sunny,
                  iconColor: const Color(0xFFFFB74D),
                  label: 'Op',
                  time: current.sunrise,
                ),
                // Day progress bar
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _DayProgressBar(
                      sunrise: current.sunrise,
                      sunset: current.sunset,
                      now: DateTime.now(),
                    ),
                  ),
                ),
                _SunTimeItem(
                  icon: Icons.nights_stay_outlined,
                  iconColor: const Color(0xFF7E57C2),
                  label: 'Onder',
                  time: current.sunset,
                ),
              ],
            ),
          ),
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

class _SunTimeItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final DateTime time;

  const _SunTimeItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(
          fontSize: 10,
          color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
        )),
        Text(timeStr, style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        )),
      ],
    );
  }
}

class _DayProgressBar extends StatelessWidget {
  final DateTime sunrise;
  final DateTime sunset;
  final DateTime now;

  const _DayProgressBar({
    required this.sunrise,
    required this.sunset,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    final totalDuration = sunset.difference(sunrise).inMilliseconds;
    final elapsed = now.difference(sunrise).inMilliseconds;
    final progress = (elapsed / totalDuration).clamp(0.0, 1.0);
    final isDay = now.isAfter(sunrise) && now.isBefore(sunset);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final sunX = (progress * width).clamp(0.0, width);

        return SizedBox(
          height: 24,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 10,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              if (isDay)
                Positioned(
                  left: 0,
                  top: 10,
                  child: Container(
                    width: sunX,
                    height: 4,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [
                        Color(0xFFFFB74D),
                        Color(0xFFFFA726),
                      ]),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              if (isDay)
                Positioned(
                  left: sunX - 6,
                  top: 4,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFA726),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFA726).withAlpha(100),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
