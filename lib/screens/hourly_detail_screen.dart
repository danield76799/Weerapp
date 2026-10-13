import 'package:flutter/material.dart';

import '../models/weather.dart';
import '../theme/nimbus_palette.dart';
import '../utils/weather_utils.dart';

/// Nimbus-stijl uurlijkse prognose: gedetailleerde verticale lijst per uur.
///
/// Toont per uur:
///  - tijd + weericoon + temperatuur
///  - Nederlandse weersbeschrijving
///  - 3 chips: neerslagkans %, neerslaghoeveelheid mm, wind km/u
///
/// Bovenin: zonsopkomst / zonsondergang en een korte disclaimer.
class HourlyDetailScreen extends StatefulWidget {
  final WeatherData data;
  final DateTime date;

  const HourlyDetailScreen({
    super.key,
    required this.data,
    required this.date,
  });

  @override
  State<HourlyDetailScreen> createState() => _HourlyDetailScreenState();
}

class _HourlyDetailScreenState extends State<HourlyDetailScreen> {
  final _scrollController = ScrollController();
  final _itemKeys = <GlobalKey>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrentHour());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrentHour() {
    final hours = widget.data.hourlyForDay(widget.date);
    final now = DateTime.now();
    final isToday = widget.date.year == now.year &&
        widget.date.month == now.month &&
        widget.date.day == now.day;

    if (!isToday || hours.isEmpty) return;

    int targetIndex = 0;
    for (var i = 0; i < hours.length; i++) {
      if (hours[i].time.hour >= now.hour) {
        targetIndex = i;
        break;
      }
    }

    final ctx = _itemKeys[targetIndex].currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        alignment: 0.15,
      );
    } else {
      // Fallback: schat ~88 px per kaart.
      final offset = (targetIndex * 88.0).clamp(
          0.0, _scrollController.position.maxScrollExtent);
      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  String _dayLabel(DateTime d) {
    final days = [
      'maandag',
      'dinsdag',
      'woensdag',
      'donderdag',
      'vrijdag',
      'zaterdag',
      'zondag',
    ];
    final months = [
      'jan',
      'feb',
      'mrt',
      'apr',
      'mei',
      'jun',
      'jul',
      'aug',
      'sep',
      'okt',
      'nov',
      'dec',
    ];
    final now = DateTime.now();
    final isToday = d.year == now.year && d.month == now.month && d.day == now.day;
    final base = isToday
        ? 'Vandaag'
        : '${days[d.weekday - 1]} ${d.day} ${months[d.month - 1]}';
    return base;
  }

  String _formatTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Open-Meteo levert wind in m/s (unit=ms); Nimbus toont km/u.
  int _msToKmh(double ms) => (ms * 3.6).round();

  String _formatSun(DateTime? t) {
    if (t == null) return '--:--';
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final hours = widget.data.hourlyForDay(widget.date);
    final theme = Theme.of(context);

    // Reserveer zoveel keys als we nodig hebben voor auto-scroll.
    _itemKeys.clear();
    for (var i = 0; i < hours.length; i++) {
      _itemKeys.add(GlobalKey());
    }

    return Scaffold(
      backgroundColor: NimbusPalette.background,
      appBar: AppBar(
        title: Text('Uurlijkse prognose'),
        centerTitle: true,
        backgroundColor: NimbusPalette.background,
        foregroundColor: NimbusPalette.textPrimary,
      ),
      body: SafeArea(
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // Header met daglabel, zonsopkomst/-ondergang en disclaimer.
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _dayLabel(widget.date),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: NimbusPalette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _SunTile(
                          icon: Icons.wb_sunny_outlined,
                          label: 'Zonsopkomst',
                          value: _formatSun(widget.data.current.sunrise),
                        ),
                        const SizedBox(width: 12),
                        _SunTile(
                          icon: Icons.bedtime_outlined,
                          label: 'Zonsondergang',
                          value: _formatSun(widget.data.current.sunset),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Indicatie op basis van hoe ver vooruit de verwachting is: hoe verder, hoe minder zeker.',
                      style: TextStyle(
                        fontSize: 12,
                        color: NimbusPalette.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Uurlijkse prognose',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: NimbusPalette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            // Lijst met uurkaarten.
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList.separated(
                itemCount: hours.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final h = hours[i];
                  final now = DateTime.now();
                  final isToday = widget.date.year == now.year &&
                      widget.date.month == now.month &&
                      widget.date.day == now.day;
                  final isCurrent =
                      isToday && h.time.hour == now.hour;

                  final icon = WeatherUtils.iconForWmoCode(
                    h.weatherCode,
                    isDay: h.isDay,
                  );
                  final iconColor =
                      WeatherUtils.colorForWmoCode(h.weatherCode);
                  final description =
                      WeatherUtils.descriptionForWmoCode(h.weatherCode);
                  final rain = h.precipitation ?? 0;

                  return Container(
                    key: _itemKeys[i],
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? NimbusPalette.card.withAlpha(240)
                          : NimbusPalette.card,
                      borderRadius: BorderRadius.circular(16),
                      border: isCurrent
                          ? Border.all(
                              color: theme.colorScheme.primary.withAlpha(120),
                              width: 1.5,
                            )
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Rij 1: tijd, icoon, temperatuur
                        Row(
                          children: [
                            SizedBox(
                              width: 48,
                              child: Text(
                                _formatTime(h.time),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: NimbusPalette.textPrimary,
                                ),
                              ),
                            ),
                            Icon(icon, color: iconColor, size: 28),
                            const SizedBox(width: 12),
                            Text(
                              '${h.temperature.toStringAsFixed(0)}°',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: NimbusPalette.textPrimary,
                              ),
                            ),
                            if (isCurrent) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary
                                      .withAlpha(40),
                                  borderRadius: BorderRadius.circular(6),
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
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Beschrijving
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 14,
                            color: NimbusPalette.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        // 3 chips
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _DetailChip(
                              icon: Icons.water_drop_outlined,
                              value: '${h.precipitationProbability}%',
                              alpha: h.precipitationProbability > 0
                                  ? 255
                                  : 130,
                            ),
                            _DetailChip(
                              icon: Icons.grain,
                              value: '${rain.toStringAsFixed(1)} mm',
                              alpha: rain > 0 ? 255 : 130,
                            ),
                            _DetailChip(
                              icon: Icons.air_rounded,
                              value: '${_msToKmh(h.windSpeed)} km/u',
                              alpha: 200,
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

class _SunTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SunTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: NimbusPalette.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 20,
                color: const Color(0xFFFFD54F)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: NimbusPalette.textSecondary,
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: NimbusPalette.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final int alpha;

  const _DetailChip({
    required this.icon,
    required this.value,
    required this.alpha,
  });

  @override
  Widget build(BuildContext context) {
    final fg = NimbusPalette.textPrimary.withAlpha(alpha.clamp(100, 255));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: NimbusPalette.background.withAlpha(180),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
