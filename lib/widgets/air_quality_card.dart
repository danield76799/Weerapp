import 'package:flutter/material.dart';

import '../models/weather.dart';

/// Luchtkwaliteit + pollen info
class AirQualityCard extends StatelessWidget {
  final AirQuality? airQuality;
  final PollenInfo? pollen;

  const AirQualityCard({
    super.key,
    required this.airQuality,
    required this.pollen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (airQuality == null && pollen == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh.withAlpha(120),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(30),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: theme.colorScheme.outline.withAlpha(80),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (airQuality != null) ...[
            Row(
              children: [
                Icon(Icons.air, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Luchtkwaliteit',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                _aqiBadge(context, airQuality!),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _pollutantChip('PM2.5', '${airQuality!.pm25}', 'µg/m³'),
                _pollutantChip('PM10', '${airQuality!.pm10}', 'µg/m³'),
                _pollutantChip('NO₂', '${airQuality!.no2}', 'µg/m³'),
                _pollutantChip('O₃', '${airQuality!.o3}', 'µg/m³'),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              airQuality!.advice,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(220),
                fontSize: 13,
              ),
            ),
          ],
          if (airQuality != null && pollen != null) const SizedBox(height: 16),
          if (pollen != null) ...[
            Row(
              children: [
                Icon(Icons.grass, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Pollen / Hooikoorts',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _pollenChip(theme, 'Gras', pollen!.grassLabel(), pollen!.grass, const Color(0xFF8BC34A)),
                _pollenChip(theme, 'Berk', pollen!.birchLabel(), pollen!.birch, const Color(0xFFFFA726)),
                _pollenChip(theme, 'Els', pollen!.alderLabel(), pollen!.alder, const Color(0xFF42A5F5)),
                _pollenChip(theme, 'Bijvoet', pollen!.mugwortLabel(), pollen!.mugwort, const Color(0xFFAB47BC)),
                _pollenChip(theme, 'Ambrosia', pollen!.ragweedLabel(), pollen!.ragweed, const Color(0xFFEF5350)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _aqiBadge(BuildContext context, AirQuality aq) {
    final color = _aqiColor(aq.europeanAqi ?? aq.pm25);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '${aq.label} (${aq.europeanAqi ?? aq.pm25})',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Color _aqiColor(int aqi) {
    if (aqi <= 20) return const Color(0xFF4CAF50);
    if (aqi <= 40) return const Color(0xFFFFC107);
    if (aqi <= 60) return const Color(0xFFFF9800);
    if (aqi <= 80) return const Color(0xFFF44336);
    return const Color(0xFF9C27B0);
  }

  Widget _pollutantChip(String name, String value, String unit) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(width: 4),
          Text('$value $unit', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _pollenChip(ThemeData theme, String name, String label, int value, Color color) {
    if (value == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(name, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface)),
            const SizedBox(width: 4),
            Text('geen', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(60),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(120), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(width: 4),
          Text('$value/m³', style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
