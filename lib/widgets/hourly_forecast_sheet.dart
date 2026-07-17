import 'package:flutter/material.dart';

import '../models/weather.dart';
import '../utils/weather_utils.dart';

class HourlyForecastSheet extends StatefulWidget {
  final DateTime date;
  final List<HourlyForecast> hours;

  const HourlyForecastSheet({
    super.key,
    required this.date,
    required this.hours,
  });

  @override
  State<HourlyForecastSheet> createState() => _HourlyForecastSheetState();
}

class _HourlyForecastSheetState extends State<HourlyForecastSheet> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Auto-scroll to current hour if today
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentHour();
    });
  }

  void _scrollToCurrentHour() {
    final now = DateTime.now();
    final isToday = widget.date.year == now.year &&
        widget.date.month == now.month &&
        widget.date.day == now.day;

    if (!isToday || widget.hours.isEmpty) return;

    // Find the index of the first hour >= now
    int targetIndex = 0;
    for (var i = 0; i < widget.hours.length; i++) {
      if (widget.hours[i].time.hour >= now.hour) {
        targetIndex = i;
        break;
      }
      targetIndex = i;
    }

    // Each item is ~80px wide (72 + 8 margin)
    const itemWidth = 88.0;
    final offset = (targetIndex * itemWidth) - 60.0; // slight left padding
    _scrollController.animateTo(
      offset.clamp(0.0, double.infinity),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dayNames = ['maandag', 'dinsdag', 'woensdag', 'donderdag', 'vrijdag', 'zaterdag', 'zondag'];
    final monthNames = ['jan', 'feb', 'mrt', 'apr', 'mei', 'jun', 'jul', 'aug', 'sep', 'okt', 'nov', 'dec'];
    final title = '${dayNames[widget.date.weekday - 1]} ${widget.date.day} ${monthNames[widget.date.month - 1]}';

    if (widget.hours.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text('Geen uurdata beschikbaar', style: theme.textTheme.bodyMedium),
        ),
      );
    }

    final now = DateTime.now();
    final isToday = widget.date.year == now.year &&
        widget.date.month == now.month &&
        widget.date.day == now.day;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withAlpha(60),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Text(title,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                if (isToday)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withAlpha(40),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'NU',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                Text('${widget.hours.length} uur',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurface.withAlpha(200))),
              ],
            ),
          ),
          SizedBox(
            height: 220,
            child: ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              itemCount: widget.hours.length,
              itemBuilder: (context, i) {
                final h = widget.hours[i];
                // Fix: use actual isDay from API data instead of fixed 6-21h range
                final icon = WeatherUtils.iconForWmoCode(h.weatherCode, isDay: h.isDay);
                final iconColor = WeatherUtils.colorForWmoCode(h.weatherCode);
                final tempColor = WeatherUtils.tempColor(h.temperature);

                // Highlight current hour if today
                final isCurrentHour = isToday && h.time.hour == now.hour;

                return Container(
                  width: 80,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  decoration: BoxDecoration(
                    color: isCurrentHour
                        ? theme.colorScheme.primary.withAlpha(40)
                        : theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                    border: isCurrentHour
                        ? Border.all(color: theme.colorScheme.primary.withAlpha(120), width: 1.5)
                        : null,
                  ),
                  child: Column(
                    children: [
                      // Tijd / NU
                      SizedBox(
                        height: 18,
                        child: Center(
                          child: Text(
                            isCurrentHour ? 'NU' : '${h.time.hour.toString().padLeft(2, '0')}:00',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isCurrentHour ? FontWeight.w700 : FontWeight.w500,
                              color: isCurrentHour
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface.withAlpha(180),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Weer icoon
                      SizedBox(
                        height: 26,
                        child: Center(child: Icon(icon, color: iconColor, size: 26)),
                      ),
                      const SizedBox(height: 4),
                      // Temperatuur
                      SizedBox(
                        height: 22,
                        child: Center(
                          child: Text(
                            '${h.temperature.toStringAsFixed(0)}°',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: tempColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      // Gevoelstemperatuur (vast slot — leeg indien geen verschil)
                      SizedBox(
                        height: 14,
                        child: Center(
                          child: (h.apparentTemperature - h.temperature).abs() >= 1
                              ? Text(
                                  '${h.apparentTemperature.toStringAsFixed(0)}°',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: theme.colorScheme.onSurface.withAlpha(180),
                                  ),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Windrichting pijl (vast slot)
                      SizedBox(
                        height: 16,
                        child: Center(
                          child: Transform.rotate(
                            angle: h.windDirection.toDouble() * 3.1415926535 / 180,
                            child: Icon(
                              Icons.arrow_upward,
                              size: 16,
                              color: theme.colorScheme.onSurface.withAlpha(180),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Neerslagkans (vast slot — leeg indien < 10%)
                      SizedBox(
                        height: 16,
                        child: Center(
                          child: h.precipitationProbability > 10
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.water_drop,
                                        size: 11, color: theme.colorScheme.onSurface.withAlpha(200)),
                                    const SizedBox(width: 2),
                                    Text(
                                      '${h.precipitationProbability}%',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: theme.colorScheme.onSurface.withAlpha(200),
                                      ),
                                    ),
                                  ],
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // UV-index (vast slot — leeg indien < 3)
                      SizedBox(
                        height: 20,
                        child: Center(
                          child: h.uvIndex >= 3
                              ? Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: WeatherUtils.uvInfo(h.uvIndex).color,
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    h.uvIndex.toStringAsFixed(0),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}