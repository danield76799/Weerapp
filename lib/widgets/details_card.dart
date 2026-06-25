import 'package:flutter/material.dart';

import '../models/weather.dart';
import '../utils/weather_utils.dart';

/// Extra details: dauwpunt, zicht, windstoten, daglengte, zonuren
class DetailsCard extends StatelessWidget {
  final CurrentWeather current;
  final DailyForecast today;

  const DetailsCard({
    super.key,
    required this.current,
    required this.today,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = <_DetailItem>[];

    // Windstoten
    if (current.windGusts != null) {
      items.add(_DetailItem(
        icon: Icons.air,
        label: 'Windstoten',
        value: '${current.windGusts!.toStringAsFixed(1)} m/s',
        color: const Color(0xFF42A5F5),
      ));
    }

    // Dauwpunt
    if (current.dewPoint != null) {
      items.add(_DetailItem(
        icon: Icons.water_drop_outlined,
        label: 'Dauwpunt',
        value: '${current.dewPoint!.toStringAsFixed(0)}°C',
        color: const Color(0xFF26C6DA),
      ));
    }

    // Zicht
    if (current.visibility != null) {
      final km = (current.visibility! / 1000).toStringAsFixed(0);
      items.add(_DetailItem(
        icon: Icons.visibility_outlined,
        label: 'Zicht',
        value: '$km km',
        color: const Color(0xFF78909C),
      ));
    }

    // Luchtdruk
    items.add(_DetailItem(
      icon: Icons.speed,
      label: 'Luchtdruk',
      value: '${current.pressure} hPa',
      color: const Color(0xFF8D6E63),
    ));

    // Daglengte
    final dayLen = today.dayLengthHours;
    final hours = dayLen.floor();
    final minutes = ((dayLen - hours) * 60).round();
    items.add(_DetailItem(
      icon: Icons.access_time,
      label: 'Daglengte',
      value: '${hours}u ${minutes}m',
      color: const Color(0xFFFFA726),
    ));

    // Zonuren
    if (today.sunshineHours != null) {
      items.add(_DetailItem(
        icon: Icons.wb_sunny_outlined,
        label: 'Zonuren',
        value: '${today.sunshineHours!.toStringAsFixed(1)}u',
        color: const Color(0xFFFFD54F),
      ));
    }

    // Zonsopgang / -onder
    items.add(_DetailItem(
      icon: Icons.wb_sunny,
      label: 'Zonsopgang',
      value: '${current.sunrise.hour.toString().padLeft(2, '0')}:${current.sunrise.minute.toString().padLeft(2, '0')}',
      color: const Color(0xFFFFB74D),
    ));
    items.add(_DetailItem(
      icon: Icons.nights_stay_outlined,
      label: 'Zonsondergang',
      value: '${current.sunset.hour.toString().padLeft(2, '0')}:${current.sunset.minute.toString().padLeft(2, '0')}',
      color: const Color(0xFF7E57C2),
    ));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh.withAlpha(120),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Details',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2.8,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: items.length,
            itemBuilder: (context, i) => _buildTile(context, items[i]),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(BuildContext context, _DetailItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: item.color.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(item.icon, size: 20, color: item.color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(item.label,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
                    )),
                Text(item.value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailItem {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  _DetailItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
}