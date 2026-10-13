import 'package:flutter/material.dart';

import '../models/weather.dart';
import '../theme/nimbus_palette.dart';
import '../utils/weather_utils.dart';
import '../screens/hourly_detail_screen.dart';

/// Nederlandse dagnamen en maandnamen voor het formatteren van datums
/// zonder Intl-locale-initialisatie (initializeDateFormatting('nl') is niet
/// aangeroepen in deze app en DateFormat('...', 'nl') crasht daarop met een
/// LocaleDataException).
const _weekdagen = ['maandag', 'dinsdag', 'woensdag', 'donderdag', 'vrijdag', 'zaterdag', 'zondag'];
const _maanden = ['jan', 'feb', 'mrt', 'apr', 'mei', 'jun', 'jul', 'aug', 'sep', 'okt', 'nov', 'dec'];

/// "EEE d MMM"-stijl dag-label, bv. "vr 10 okt".
String _nlDagLabel(DateTime d) {
  // DateTime.weekday: ma=1 … zo=7
  final dag = _weekdagen[d.weekday - 1];
  final maand = _maanden[d.month - 1];
  return '${dag.substring(0, 3)} ${d.day} $maand';
}

/// Nimbus-stijl hero-kaart: locatie, omschrijving, groot icoon + temperatuur,
/// detail-chips (voelt als, luchtvochtigheid, wind) en een droog/neerslag-
/// regel onderin. Matched de referentie-screenshot 1-op-1.
class NimbusHeroCard extends StatelessWidget {
  final WeatherData data;
  final bool isDay;
  final VoidCallback? onRename;
  final VoidCallback? onRemove;

  const NimbusHeroCard({
    super.key,
    required this.data,
    required this.isDay,
    this.onRename,
    this.onRemove,
  });

  /// Of de komende ~3 uur droog blijft (geen neerslag > 0).
  bool _droogVolgende3Uur() {
    final now = DateTime.now();
    final next3 = data.hourly.where((h) {
      return h.time.isAfter(now) &&
          h.time.isBefore(now.add(const Duration(hours: 3)));
    });
    return next3.every((h) => (h.precipitation ?? 0) <= 0);
  }

  @override
  Widget build(BuildContext context) {
    final current = data.current;
    final icon = WeatherUtils.iconForWmoCode(current.weatherCode, isDay: isDay);
    final iconColor = isDay
        ? const Color(0xFFFFD54F) // zachter geel voor dag-iconen op blauw
        : Colors.white;
    final onRename = this.onRename;
    final onRemove = this.onRemove;

    // Detailchips volgens de screenshot: voelt als, luchtvochtigheid, wind.
    final chips = [
      (
        icon: Icons.thermostat_rounded,
        label: 'Voelt als',
        value: '${current.feelsLike.toStringAsFixed(0)}°',
      ),
      (
        icon: Icons.water_drop_outlined,
        label: 'Luchtvochtigheid',
        value: '${current.humidity}%',
      ),
      (
        icon: Icons.air_rounded,
        label: 'Wind',
        value: '${current.windSpeed.toStringAsFixed(0)} km/u',
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [NimbusPalette.heroTop, NimbusPalette.heroBottom],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Locatie + omschrijving; tap = hernoemen, long-press = verwijderen.
          GestureDetector(
            onTap: onRename,
            onLongPress: onRemove,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    _shortName(data.locationName),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: NimbusPalette.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.edit_outlined,
                  size: 14,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            current.weatherDescription,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              color: NimbusPalette.textSecondary,
            ),
          ),
          const SizedBox(height: 12),

          // Groot icoon + temperatuur
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 64, color: iconColor),
              const SizedBox(width: 12),
              Text(
                '${current.temperature.toStringAsFixed(0)}°',
                style: const TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w400,
                  color: NimbusPalette.textPrimary,
                  letterSpacing: -1.5,
                  height: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Detail chips in Wrap zodat ze netjes teruglopen
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: chips.map((chip) => _Chip(
              icon: chip.icon,
              label: '${chip.label} · ${chip.value}',
            )).toList(),
          ),
          const SizedBox(height: 16),

          // Droog/neerslag-regel met klein icoon
          Row(
            children: [
              Icon(
                _droogVolgende3Uur()
                    ? Icons.umbrella_outlined
                    : Icons.water_drop,
                size: 20,
                color: NimbusPalette.textPrimary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _droogVolgende3Uur()
                      ? 'Droog de komende 3 uur'
                      : 'Neerslag binnenskomend',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    color: NimbusPalette.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Kort locatienaam in: "Bardolino, Provincia di Verona" → "Bardolino".
  String _shortName(String name) {
    final comma = name.indexOf(',');
    if (comma > 0) return name.substring(0, comma).trim();
    return name;
  }
}

/// Pill-vormige chip met icoon en label·waarde tekst.
class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Chip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: NimbusPalette.textPrimary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: NimbusPalette.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontaal scrolbare rij per-uur kaartjes in Nimbus-stijl.
///
/// Elke kaart toont tijd, icoon, temperatuur en neerslagkans. Tikken opent de
/// bestaande [HourlyForecastSheet] voor die dag.
class NimbusHourlyRow extends StatelessWidget {
  final WeatherData data;
  final bool isDay;

  const NimbusHourlyRow({
    super.key,
    required this.data,
    required this.isDay,
  });

  @override
  Widget build(BuildContext context) {
    final hours = data.nextHours(12);
    if (hours.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Per uur',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: NimbusPalette.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 128,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: hours.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final h = hours[index];
              final isNow = index == 0;
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HourlyDetailScreen(
                        data: data,
                        date: h.time,
                      ),
                    ),
                  );
                },
                child: Container(
                  width: 76,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: NimbusPalette.card,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      Text(
                        isNow
                            ? 'Nu'
                            : '${h.time.hour.toString().padLeft(2, '0')}:${h.time.minute.toString().padLeft(2, '0')}',
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: NimbusPalette.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        WeatherUtils.iconForWmoCode(h.weatherCode, isDay: h.isDay),
                        size: 30,
                        color: Colors.white,
                      ),
                      const Spacer(),
                      Text(
                        '${h.temperature.toStringAsFixed(0)}°',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: NimbusPalette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.water_drop,
                              size: 12,
                              color: h.precipitationProbability > 0
                                  ? NimbusPalette.accent
                                  : NimbusPalette.textMuted,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${h.precipitationProbability}%',
                              style: TextStyle(
                                fontSize: 12,
                                color: h.precipitationProbability > 0
                                    ? NimbusPalette.accent
                                    : NimbusPalette.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Komende-dagen sectie: uitleg + kaart per dag.
class NimbusDailySection extends StatelessWidget {
  final WeatherData data;

  const NimbusDailySection({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final days = data.daily.take(7).toList();
    if (days.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Komende dagen',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: NimbusPalette.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Zekerheid = hoe betrouwbaar de verwachting is. Hoe verder '
          'vooruit, hoe onzekerder.',
          style: TextStyle(
            fontSize: 13,
            color: NimbusPalette.textSecondary,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 12),
        ...days.map((day) => _DayCard(day: day)),
      ],
    );
  }
}

/// Eén dagkaart: dag-label, icoon, neerslagkans, min/max en pijl.
class _DayCard extends StatelessWidget {
  final DailyForecast day;

  const _DayCard({required this.day});

  String get _label {
    final now = DateTime.now();
    final isToday = day.date.year == now.year &&
        day.date.month == now.month &&
        day.date.day == now.day;
    if (isToday) return 'Vandaag';
    final tomorrow = now.add(const Duration(days: 1));
    if (day.date.year == tomorrow.year &&
        day.date.month == tomorrow.month &&
        day.date.day == tomorrow.day) {
      return 'Morgen';
    }
    return _nlDagLabel(day.date);
  }

  /// Zekerheids-label: hoe betrouwbaar is de verwachting? Hoe verder vooruit,
  /// hoe lager de zekerheid (en hoge neerslagkans verhoogt de onzekerheid).
  String get _zekerheid {
    final now = DateTime.now();
    final dagenVooruit = day.date.difference(DateTime(now.year, now.month, now.day)).inDays;
    if (dagenVooruit <= 1) return 'hoog';
    if (dagenVooruit <= 3) return 'matig';
    return 'laag';
  }

  Color get _zekerheidKleur {
    switch (_zekerheid) {
      case 'hoog':
        return const Color(0xFF66BB6A);
      case 'matig':
        return const Color(0xFFFFC107);
      default:
        return const Color(0xFFEF5350);
    }
  }

  @override
  Widget build(BuildContext context) {
    final icon = WeatherUtils.iconForWmoCode(day.weatherCode, isDay: true);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: NimbusPalette.card,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          // Linkerkolom: dag-label + zekerheid met stip
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _label,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: NimbusPalette.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _zekerheidKleur,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Zekerheid: ${_zekerheid.toLowerCase()}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: NimbusPalette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Icoon + neerslagkans
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 26, color: Colors.white),
              const SizedBox(width: 8),
              Icon(
                Icons.water_drop,
                size: 14,
                color: day.precipitationProbability > 0
                    ? NimbusPalette.accent
                    : NimbusPalette.textMuted,
              ),
              const SizedBox(width: 3),
              Text(
                '${day.precipitationProbability.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: day.precipitationProbability > 0
                      ? NimbusPalette.accent
                      : NimbusPalette.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          // Min/max + pijl
          Text(
            '${day.tempMax.toStringAsFixed(0)}°',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: NimbusPalette.textPrimary,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '${day.tempMin.toStringAsFixed(0)}°',
            style: const TextStyle(
              fontSize: 16,
              color: NimbusPalette.textMuted,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.chevron_right,
            size: 20,
            color: NimbusPalette.textMuted,
          ),
        ],
      ),
    );
  }
}