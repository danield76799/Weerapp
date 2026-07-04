import 'package:flutter/material.dart';

import '../models/weather.dart';
import '../utils/sky_gradient.dart';
import '../utils/string_extensions.dart';
import '../utils/weather_utils.dart';


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
    final uv = WeatherUtils.uvInfo(current.uvIndex);
    final icon = WeatherUtils.iconForWmoCode(current.weatherCode);
    final iconColor = WeatherUtils.colorForWmoCode(current.weatherCode);

    final skyColors = SkyGradient.getColors(DateTime.now(), current.weatherCode);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: skyColors,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(30),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(60), // Slightly stronger overlay for contrast
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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${current.temperature.toStringAsFixed(0)}°C',
                        style: const TextStyle(
                          fontSize: 84,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1,
                          letterSpacing: -2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        current.weatherDescription.capitalize(),
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      Text(
                        'Voelt als ${current.feelsLike.toStringAsFixed(0)}°C',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: Icon(icon, size: 100, color: iconColor),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white38, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.wb_sunny, color: Colors.amber, size: 22),
                      const SizedBox(width: 8),
                      const Text('UV-index', style: TextStyle(color: Colors.white)),
                      const Spacer(),
                      Text(
                        current.uvIndex.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          uv.label.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (uv.advice.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      uv.advice,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white38, width: 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _SunTimeItem(
                    icon: Icons.wb_sunny,
                    iconColor: const Color(0xFFFFB74D),
                    label: 'Op',
                    time: sunrise ?? current.sunrise,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: _DayProgressBar(
                        sunrise: sunrise ?? current.sunrise,
                        sunset: sunset ?? current.sunset,
                        now: DateTime.now(),
                      ),
                    ),
                  ),
                  _SunTimeItem(
                    icon: Icons.nights_stay_outlined,
                    iconColor: const Color(0xFF7E57C2),
                    label: 'Onder',
                    time: sunset ?? current.sunset,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _DetailChip(
                  icon: Icons.air,
                  label: WeatherUtils.windDescription(current.windSpeed),
                  value: '${current.windSpeed.toStringAsFixed(1)} m/s',
                  color: const Color(0xFF42A5F5),
                ),
                const SizedBox(width: 8),
                _DetailChip(
                  icon: Icons.water_drop_outlined,
                  label: 'Luchtvochtigheid',
                  value: '${current.humidity}%',
                  color: const Color(0xFF26C6DA),
                ),
                const SizedBox(width: 8),
                _DetailChip(
                  icon: Icons.cloud_outlined,
                  label: 'Bewolking',
                  value: '${current.clouds}%',
                  color: const Color(0xFF90A4AE),
                ),
              ],
            ),
            if (current.precipitation != null && current.precipitation! > 0) ...[
              const SizedBox(height: 8),
              _DetailChip(
                icon: Icons.umbrella,
                label: 'Neerslag laatste uur',
                value: '${current.precipitation!.toStringAsFixed(1)} mm',
                color: const Color(0xFF1976D2),
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
  final Color color;
  const _DetailChip({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withAlpha(30),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(60), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 11, color: Colors.white.withAlpha(200)),
                    maxLines: 1,
                    overflow: TextOverflow.fade, // Subtieler dan ellipsis voor korte chips
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
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
        Text(
          timeStr,
          style: const TextStyle(fontSize: 10, color: Colors.white),
        ),
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
    final total = sunset.difference(sunrise).inSeconds;
    final passed = now.difference(sunrise).inSeconds;
    final fraction = total > 0 ? (passed / total).clamp(0.0, 1.0) : 0.0;

    return Container(
      height: 6,
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(3),
      ),
      child: FractionallyAlignedIndicator(
        alignment: Alignment(-1.0 + fraction * 2, 0.0),
        child: Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class FractionallyAlignedIndicator extends StatelessWidget {
  final Alignment alignment;
  final Widget child;
  const FractionallyAlignedIndicator({
    super.key,
    required this.alignment,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomMultiChildLayout(
          delegate: _IndicatorDelegate(
            alignment: alignment,
            size: constraints.biggest,
          ),
          children: [
            LayoutId(
              id: 'dot',
              child: child,
            ),
          ],
        );
      },
    );
  }
}

class _IndicatorDelegate extends MultiChildLayoutDelegate {
  final Alignment alignment;
  final Size size;

  _IndicatorDelegate({required this.alignment, required this.size});

  @override
  void performLayout(Size size) {
    final dot = layoutChild('dot', const BoxConstraints());
    positionChild(dot, Offset(
      (size.width - dot.width).abs() / 2 + alignment.x * (size.width - dot.width) / 2,
      (size.height - dot.height) / 2,
    ));
  }

  @override
  bool shouldRelayout(covariant _IndicatorDelegate old) =>
      old.alignment != alignment || old.size != size;
}
