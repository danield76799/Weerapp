import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/weather.dart';
import '../services/location_service.dart';
import '../services/saved_locations_service.dart';
import '../services/widget_service.dart';
import '../services/weather_provider.dart';
import '../theme/nimbus_palette.dart';
import '../widgets/nimbus_cards.dart';
import 'location_search_screen.dart';
import 'rain_radar_screen.dart';
import 'settings_screen.dart';

/// Nimbus-stijl homescreen: donker marine-thema met een hero-kaart, per-uur
/// rij en komende-dagen lijst, conform het referentie-screenshot.
///
/// Locatiebeheer (GPS, zoeken, hernoemen, verwijderen, auto-refresh, widget-
/// en notificatie-services) is 1-op-1 overgenomen van de klassieke
/// [HomeScreen]; alleen de presentatie wijkt af.
class NimbusHomeScreen extends StatefulWidget {
  const NimbusHomeScreen({super.key});

  @override
  State<NimbusHomeScreen> createState() => _NimbusHomeScreenState();
}

class _NimbusHomeScreenState extends State<NimbusHomeScreen>
    with WidgetsBindingObserver {
  final _locationService = LocationService();
  final _savedLocations = SavedLocationsService();
  Timer? _autoRefreshTimer;
  static const _refreshInterval = Duration(minutes: 10);

  List<SavedLocation> _locations = [];
  int _currentPage = 0;
  PageController? _pageController;
  bool _loading = true;

  bool _autoRefresh = true;
  bool _isDay = true;

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(_refreshInterval, (_) => _silentRefreshCurrent());
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    WidgetsBinding.instance.addObserver(this);
    _loadSettings();
    _bootstrap();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _pageController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startAutoRefresh();
      _silentRefreshCurrent();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _autoRefreshTimer?.cancel();
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _autoRefresh = prefs.getBool('auto_refresh') ?? true;
    });
    if (_autoRefresh) {
      _startAutoRefresh();
    } else {
      _autoRefreshTimer?.cancel();
    }
  }

  Future<void> _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    _loadSettings();
  }

  Future<void> _bootstrap() async {
    final locations = await _savedLocations.getLocations();
    if (!mounted) return;

    if (locations.isEmpty) {
      await _useCurrentLocation();
      return;
    }

    setState(() {
      _locations = locations;
      _loading = false;
    });

    final loc = locations.first;
    await _loadLocation(loc.lat, loc.lon, loc.name,
        isCurrentLocation: loc.isCurrentLocation);
    _startAutoRefresh();
  }

  Future<void> _useCurrentLocation() async {
    try {
      final loc = await _locationService.getCurrentLocation();
      if (!mounted) return;
      final saved = SavedLocation(
          lat: loc.lat, lon: loc.lon, name: loc.name, isCurrentLocation: true);
      await _savedLocations.addLocation(saved);
      final locations = await _savedLocations.getLocations();
      setState(() {
        _locations = locations;
        _loading = false;
      });
      await _loadLocation(loc.lat, loc.lon, loc.name, isCurrentLocation: true);
      _startAutoRefresh();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              e is LocationException ? e.message : 'Locatie opgevraagd...'),
          duration: const Duration(seconds: 4),
        ),
      );
      _openSearch();
    }
  }

  Future<void> _loadLocation(double lat, double lon, String name,
      {bool isCurrentLocation = false}) async {
    final provider = context.read<WeatherProvider>();
    await provider.loadWeather(lat: lat, lon: lon, locationName: name);
    if (provider.hasData && isCurrentLocation) {
      WidgetService.updateWeather(provider.data!);
    }
    if (mounted) setState(() => _isDay = _calculateIsDay(provider.data));
  }

  bool _calculateIsDay(WeatherData? data) {
    if (data == null) return true;
    final now = DateTime.now();
    return now.isAfter(data.current.sunrise) &&
        now.isBefore(data.current.sunset);
  }

  Future<void> _silentRefreshCurrent() async {
    if (_locations.isEmpty || _currentPage >= _locations.length) return;
    final loc = _locations[_currentPage];
    final provider = context.read<WeatherProvider>();
    await provider.silentRefresh(loc.lat, loc.lon, loc.name);
    if (mounted) setState(() => _isDay = _calculateIsDay(provider.data));
  }

  Future<void> _onPageChanged(int page) async {
    setState(() => _currentPage = page);
    if (page < _locations.length) {
      final loc = _locations[page];
      await _loadLocation(loc.lat, loc.lon, loc.name,
          isCurrentLocation: loc.isCurrentLocation);
    }
  }

  Future<void> _openSearch() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const LocationSearchScreen()),
    );
    if (result != null) {
      final lat = result['lat'] as double;
      final lon = result['lon'] as double;
      final name = result['name'] as String;
      await _savedLocations
          .addLocation(SavedLocation(lat: lat, lon: lon, name: name));
      final locations = await _savedLocations.getLocations();
      if (!mounted) return;
      setState(() => _locations = locations);
      final newIndex = locations.length - 1;
      if (_pageController != null) {
        _pageController!.animateToPage(
          newIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        await _loadLocation(lat, lon, name);
      }
    }
  }

  /// Kort locatienaam in: "Bardolino, Provincia di Verona" → "Bardolino".
  String _shortName(String name) {
    final comma = name.indexOf(',');
    if (comma > 0) return name.substring(0, comma).trim();
    return name;
  }

  Future<void> _renameLocation() async {
    if (_locations.isEmpty || _currentPage >= _locations.length) return;
    final loc = _locations[_currentPage];
    final controller = TextEditingController(text: loc.name);

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Locatie hernoemen'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Naam',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuleren')),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Opslaan'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (newName != null && newName.isNotEmpty && newName != loc.name) {
      await _savedLocations.removeLocation(loc.lat, loc.lon);
      await _savedLocations.addLocation(SavedLocation(
          lat: loc.lat,
          lon: loc.lon,
          name: newName,
          isCurrentLocation: loc.isCurrentLocation));
      final locations = await _savedLocations.getLocations();
      if (!mounted) return;
      setState(() => _locations = locations);
      await _loadLocation(loc.lat, loc.lon, newName,
          isCurrentLocation: loc.isCurrentLocation);
    }
  }

  Future<void> _removeCurrentLocation() async {
    if (_locations.isEmpty || _currentPage >= _locations.length) return;
    final loc = _locations[_currentPage];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${loc.name} verwijderen?'),
        content:
            Text('Deze locatie wordt verwijderd uit je opgeslagen plaatsen.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuleren')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Verwijderen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _savedLocations.removeLocation(loc.lat, loc.lon);
    final locations = await _savedLocations.getLocations();
    if (!mounted) return;

    setState(() {
      _locations = locations;
      _currentPage = _currentPage.clamp(
          0, locations.isEmpty ? 0 : locations.length - 1);
    });

    if (_pageController != null && locations.isNotEmpty) {
      _pageController!.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    }

    if (locations.isNotEmpty) {
      final newLoc = locations[_currentPage];
      await _loadLocation(newLoc.lat, newLoc.lon, newLoc.name,
          isCurrentLocation: newLoc.isCurrentLocation);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: NimbusPalette.background,
        body: Center(
          child: CircularProgressIndicator(color: NimbusPalette.accent),
        ),
      );
    }

    return Scaffold(
      backgroundColor: NimbusPalette.background,
      appBar: AppBar(
        backgroundColor: NimbusPalette.background,
        elevation: 0,
        title: GestureDetector(
          onTap: _renameLocation,
          child: Consumer<WeatherProvider>(
            builder: (context, provider, _) {
              return Text(
                provider.hasData
                    ? _shortName(provider.data!.locationName)
                    : 'Weer',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: NimbusPalette.textPrimary,
                  letterSpacing: -0.3,
                ),
              );
            },
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _useCurrentLocation,
            tooltip: 'Mijn locatie',
          ),
          IconButton(
            icon: const Icon(Icons.add_location_alt_outlined),
            onPressed: _openSearch,
            tooltip: 'Locatie toevoegen',
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _openSearch,
            tooltip: 'Zoeken',
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {},
            tooltip: 'Delen',
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: _openSettings,
            tooltip: 'Instellingen',
          ),
        ],
      ),
      body: Consumer<WeatherProvider>(
        builder: (context, provider, _) {
          if (_locations.isEmpty) {
            return _NimbusErrorState(
              message: 'Geen locaties. Tik op + om er toe te voegen.',
              onRetry: _openSearch,
            );
          }

          if (!provider.hasData) {
            if (provider.status == WeatherStatus.error) {
              return _NimbusErrorState(
                message: provider.errorMessage ?? 'Onbekende fout',
                onRetry: () {
                  final loc =
                      _locations[_currentPage.clamp(0, _locations.length - 1)];
                  _loadLocation(loc.lat, loc.lon, loc.name,
                      isCurrentLocation: loc.isCurrentLocation);
                },
              );
            }
            return const Center(
              child: CircularProgressIndicator(color: NimbusPalette.accent),
            );
          }

          return PageView.builder(
            controller: _pageController,
            itemCount: _locations.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              final loc = _locations[index];
              if (index != _currentPage) {
                return const SizedBox.shrink();
              }

              final data = provider.data!;
              return RefreshIndicator(
                color: NimbusPalette.accent,
                backgroundColor: NimbusPalette.card,
                onRefresh: () => provider.refresh(loc.lat, loc.lon, loc.name),
                child: ListView(
                  padding: EdgeInsets.only(
                    top: 8,
                    bottom: MediaQuery.viewPaddingOf(context).bottom + 96,
                    left: 16,
                    right: 16,
                  ),
                  children: [
                    NimbusHeroCard(
                      data: data,
                      isDay: _isDay,
                      onRename: _renameLocation,
                      onRemove: _removeCurrentLocation,
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        provider.lastRefresh != null
                            ? 'Bijgewerkt om ${provider.lastRefresh!.hour.toString().padLeft(2, '0')}:${provider.lastRefresh!.minute.toString().padLeft(2, '0')}'
                            : '',
                        style: const TextStyle(
                          fontSize: 12,
                          color: NimbusPalette.textMuted,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    NimbusHourlyRow(data: data, isDay: _isDay),
                    const SizedBox(height: 24),
                    NimbusDailySection(data: data),
                  ],
                ),
              );
            },
          );
        },
      ),
      // Radar-knop rechtsonder
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_locations.isNotEmpty && _currentPage < _locations.length) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    RainRadarScreen(location: _locations[_currentPage]),
              ),
            );
          }
        },
        backgroundColor: NimbusPalette.cardHighlight,
        foregroundColor: NimbusPalette.textPrimary,
        icon: const Icon(Icons.radar),
        label: const Text('Radar'),
      ),
    );
  }
}

/// Fout/lege staat in Nimbus-stijl.
class _NimbusErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _NimbusErrorState({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                size: 64, color: NimbusPalette.textMuted),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 15, color: NimbusPalette.textSecondary),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Opnieuw proberen'),
                style: FilledButton.styleFrom(
                  backgroundColor: NimbusPalette.cardHighlight,
                  foregroundColor: NimbusPalette.textPrimary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}