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

  String _themeMode = 'system'; // system, light, dark

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
      _loading = false;
    });
  }

  Future<void> _toggle(String key, dynamic value, {bool isString = false}) async {
    final prefs = await SharedPreferences.getInstance();
    if (isString) {
      await prefs.setString(key, value as String);
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
          // Theme mode selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.palette, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text('Thema'),
                ),
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
          _SwitchTile(
            icon: Icons.notifications,
            title: 'Weer notificaties',
            subtitle: 'Melding bij UV ≥ 7, vorst of hitte',
            value: _notificaties,
            onChanged: (v) {
              setState(() => _notificaties = v);
              _toggle('weather_notifications', v);
            },
          ),
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