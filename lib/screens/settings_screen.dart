import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _jasAdvies = true;
  bool _zonnebrandAdvies = true;
  bool _buienVerwachting = true;
  bool _details = true;
  bool _luchtkwaliteit = true;
  bool _autoRefresh = true;
  bool _notificaties = true;
  bool _loading = true;

  // Notificatie types
  bool _notifRain = true;
  bool _notifUV = true;
  bool _notifFrost = true;
  bool _notifHeat = true;

  // Drempelwaarden
  double _uvThreshold = 7;
  double _heatThreshold = 30;
  double _frostThreshold = 0;
  double _rainThreshold = 40; // neerslagkans %

  String _themeMode = 'system';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _jasAdvies = prefs.getBool('show_jas_advies') ?? true;
      _zonnebrandAdvies = prefs.getBool('show_zonnebrand') ?? true;
      _buienVerwachting = prefs.getBool('show_buien') ?? true;
      _details = prefs.getBool('show_details') ?? true;
      _luchtkwaliteit = prefs.getBool('show_air_quality') ?? true;
      _autoRefresh = prefs.getBool('auto_refresh') ?? true;
      _notificaties = prefs.getBool('weather_notifications') ?? true;
      _themeMode = prefs.getString('theme_mode') ?? 'system';

      _notifRain = prefs.getBool('notif_rain') ?? true;
      _notifUV = prefs.getBool('notif_uv') ?? true;
      _notifFrost = prefs.getBool('notif_frost') ?? true;
      _notifHeat = prefs.getBool('notif_heat') ?? true;

      _uvThreshold = prefs.getDouble('notif_uv_threshold') ?? 7;
      _heatThreshold = prefs.getDouble('notif_heat_threshold') ?? 30;
      _frostThreshold = prefs.getDouble('notif_frost_threshold') ?? 0;
      _rainThreshold = prefs.getDouble('notif_rain_threshold') ?? 40;

      _loading = false;
    });
  }

  Future<void> _toggle(String key, dynamic value, {bool isString = false}) async {
    final prefs = await SharedPreferences.getInstance();
    if (isString) {
      await prefs.setString(key, value as String);
    } else if (value is double) {
      await prefs.setDouble(key, value);
    } else {
      await prefs.setBool(key, value as bool);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Instellingen')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Instellingen')),
      body: ListView(
        children: [
          _SectionHeader('Weer kaarten'),
          _SwitchTile(
            icon: Icons.checkroom,
            title: 'Kan ik zonder jas?',
            subtitle: 'Slim advies op basis van temperatuur en regen',
            value: _jasAdvies,
            onChanged: (v) {
              setState(() => _jasAdvies = v);
              _toggle('show_jas_advies', v);
            },
          ),
          _SwitchTile(
            icon: Icons.wb_sunny,
            title: 'Moet ik me insmeren?',
            subtitle: 'UV-index advies met beschermingstips',
            value: _zonnebrandAdvies,
            onChanged: (v) {
              setState(() => _zonnebrandAdvies = v);
              _toggle('show_zonnebrand', v);
            },
          ),
          _SwitchTile(
            icon: Icons.umbrella,
            title: 'Blijft het droog?',
            subtitle: 'Buienverwachting voor de komende uren',
            value: _buienVerwachting,
            onChanged: (v) {
              setState(() => _buienVerwachting = v);
              _toggle('show_buien', v);
            },
          ),
          _SwitchTile(
            icon: Icons.info_outline,
            title: 'Details',
            subtitle: 'Dauwpunt, zicht, windstoten, daglengte, zonuren',
            value: _details,
            onChanged: (v) {
              setState(() => _details = v);
              _toggle('show_details', v);
            },
          ),
          _SwitchTile(
            icon: Icons.air,
            title: 'Luchtkwaliteit & Pollen',
            subtitle: 'PM2.5, PM10, NO₂, O₃ en hooikoorts',
            value: _luchtkwaliteit,
            onChanged: (v) {
              setState(() => _luchtkwaliteit = v);
              _toggle('show_air_quality', v);
            },
          ),
          const Divider(),
          _SectionHeader('Algemeen'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.palette, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 16),
                const Expanded(child: Text('Thema')),
                Flexible(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'system', label: Text('Auto')),
                        ButtonSegment(value: 'light', label: Text('Licht')),
                        ButtonSegment(value: 'dark', label: Text('Donker')),
                      ],
                      selected: {_themeMode},
                      onSelectionChanged: (selection) {
                        setState(() => _themeMode = selection.first);
                        themeModeNotifier.value = selection.first;
                        _toggle('theme_mode', selection.first, isString: true);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          _SwitchTile(
            icon: Icons.refresh,
            title: 'Auto-refresh',
            subtitle: 'Weer elke 10 minuten automatisch bijwerken',
            value: _autoRefresh,
            onChanged: (v) {
              setState(() => _autoRefresh = v);
              _toggle('auto_refresh', v);
            },
          ),
          const Divider(),
          _SectionHeader('Weer notificaties'),
          _SwitchTile(
            icon: Icons.notifications,
            title: 'Notificaties aan',
            subtitle: 'Ontvang meldingen over het weer',
            value: _notificaties,
            onChanged: (v) {
              setState(() => _notificaties = v);
              _toggle('weather_notifications', v);
            },
          ),
          if (_notificaties) ...[
            _SwitchTile(
              icon: Icons.water_drop,
              title: 'Regen melding',
              subtitle: 'Waarschuwing bij verwachte regen',
              value: _notifRain,
              onChanged: (v) {
                setState(() => _notifRain = v);
                _toggle('notif_rain', v);
              },
            ),
            if (_notifRain)
              _SliderTile(
                icon: Icons.percent,
                title: 'Neerslagkans drempel',
                value: _rainThreshold,
                min: 20,
                max: 80,
                divisions: 12,
                unit: '%',
                onChanged: (v) => setState(() => _rainThreshold = v),
                onChangeEnd: (v) => _toggle('notif_rain_threshold', v),
              ),
            _SwitchTile(
              icon: Icons.wb_sunny,
              title: 'UV melding',
              subtitle: 'Waarschuwing bij hoge UV-index',
              value: _notifUV,
              onChanged: (v) {
                setState(() => _notifUV = v);
                _toggle('notif_uv', v);
              },
            ),
            if (_notifUV)
              _SliderTile(
                icon: Icons.wb_sunny,
                title: 'UV drempel',
                value: _uvThreshold,
                min: 3,
                max: 11,
                divisions: 8,
                unit: '',
                onChanged: (v) => setState(() => _uvThreshold = v),
                onChangeEnd: (v) => _toggle('notif_uv_threshold', v),
              ),
            _SwitchTile(
              icon: Icons.ac_unit,
              title: 'Vorst melding',
              subtitle: 'Waarschuwing bij vorst',
              value: _notifFrost,
              onChanged: (v) {
                setState(() => _notifFrost = v);
                _toggle('notif_frost', v);
              },
            ),
            if (_notifFrost)
              _SliderTile(
                icon: Icons.ac_unit,
                title: 'Vorst drempel',
                value: _frostThreshold,
                min: -10,
                max: 5,
                divisions: 15,
                unit: '°C',
                onChanged: (v) => setState(() => _frostThreshold = v),
                onChangeEnd: (v) => _toggle('notif_frost_threshold', v),
              ),
            _SwitchTile(
              icon: Icons.thermostat,
              title: 'Hitte melding',
              subtitle: 'Waarschuwing bij hoge temperatuur',
              value: _notifHeat,
              onChanged: (v) {
                setState(() => _notifHeat = v);
                _toggle('notif_heat', v);
              },
            ),
            if (_notifHeat)
              _SliderTile(
                icon: Icons.thermostat,
                title: 'Hitte drempel',
                value: _heatThreshold,
                min: 22,
                max: 40,
                divisions: 18,
                unit: '°C',
                onChanged: (v) => setState(() => _heatThreshold = v),
                onChangeEnd: (v) => _toggle('notif_heat_threshold', v),
              ),
          ],
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Weerapp v1.0 · Open-Meteo API',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(120),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _SliderTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String unit;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  const _SliderTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.unit,
    required this.onChanged,
    required this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary.withAlpha(180)),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(fontSize: 13)),
              const Spacer(),
              Text(
                '${value.toStringAsFixed(0)}$unit',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ],
      ),
    );
  }
}