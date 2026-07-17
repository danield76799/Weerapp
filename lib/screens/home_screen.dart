import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/location_service.dart';
import '../services/saved_locations_service.dart';
import '../services/weather_notification_service.dart';
import '../services/weather_provider.dart';
import '../services/weather_service.dart';
import '../services/widget_service.dart';
import '../widgets/current_weather_card.dart';
import '../widgets/daily_forecast_list.dart';
import '../widgets/jas_advice_card.dart';
import '../widgets/zonnebrand_card.dart';
import '../widgets/buien_card.dart';
import '../widgets/air_quality_card.dart';
import '../widgets/details_card.dart';
import '../widgets/weather_history_card.dart';
import '../widgets/weather_comparison_card.dart';
import 'location_search_screen.dart';
import 'rain_radar_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _locationService = LocationService();
  final _savedLocations = SavedLocationsService();
  Timer? _autoRefreshTimer;
  static const _refreshInterval = Duration(minutes: 10);

  WeatherNotificationService? _notifService;

  List<SavedLocation> _locations = [];
  int _currentPage = 0;
  PageController? _pageController;
  bool _loading = true;

  // Settings
  bool _showJas = true;
  bool _showZonnebrand = true;
  bool _showBuien = true;
  bool _showDetails = true;
  bool _showAirQuality = true;
  bool _autoRefresh = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    WidgetsBinding.instance.addObserver(this);
    _loadSettings();
    _bootstrap();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _showJas = prefs.getBool('show_jas_advies') ?? true;
      _showZonnebrand = prefs.getBool('show_zonnebrand') ?? true;
      _showBuien = prefs.getBool('show_buien') ?? true;
      _showDetails = prefs.getBool('show_details') ?? true;
      _showAirQuality = prefs.getBool('show_air_quality') ?? true;
      _autoRefresh = prefs.getBool('auto_refresh') ?? true;
    });
    // Restart timer if auto-refresh setting changed
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
    // Reload settings when returning
    _loadSettings();
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

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(_refreshInterval, (_) => _silentRefreshCurrent());
  }

  Future<void> _bootstrap() async {
    // Load saved locations
    final locations = await _savedLocations.getLocations();
    if (!mounted) return;

    if (locations.isEmpty) {
      // No saved locations — try GPS
      _useCurrentLocation();
      return;
    }

    setState(() {
      _locations = locations;
      _loading = false;
    });

    // Load weather for first location
    if (locations.isNotEmpty) {
      final loc = locations.first;
      await _loadLocation(loc.lat, loc.lon, loc.name, isCurrentLocation: loc.isCurrentLocation);
    }
    _startAutoRefresh();
  }

  Future<void> _useCurrentLocation() async {
    try {
      final loc = await _locationService.getCurrentLocation();
      if (!mounted) return;
      // Save as a location
      final saved = SavedLocation(lat: loc.lat, lon: loc.lon, name: loc.name, isCurrentLocation: true);
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
          content: Text(e is LocationException ? e.message : 'Locatie opgevraagd...'),
          duration: const Duration(seconds: 4),
        ),
      );
      _openSearch();
    }
  }

  Future<void> _loadLocation(double lat, double lon, String name, {bool isCurrentLocation = false}) async {
    final provider = context.read<WeatherProvider>();
    await provider.loadWeather(lat: lat, lon: lon, locationName: name);
    // Update widget from current location, not from selected manual location
    if (provider.hasData && isCurrentLocation) {
      WidgetService.updateWeather(provider.data!);
    }
    if (provider.hasData && isCurrentLocation) {
      try {
        _notifService ??= WeatherNotificationService(
          weatherService: context.read<WeatherService>(),
        );
        await _notifService!.checkThresholds(provider.data!);
        await _notifService!.sendMorningBriefingIfDue(provider.data!);
      } catch (_) {}
    }
  }

  Future<void> _silentRefreshCurrent() async {
    if (_locations.isEmpty || _currentPage >= _locations.length) return;
    final loc = _locations[_currentPage];
    final provider = context.read<WeatherProvider>();
    final service = context.read<WeatherService>();

    double lat = loc.lat;
    double lon = loc.lon;
    String name = loc.name;

    // Als isCurrentLocation, haal verse GPS-coördinaten op
    // Maar doe dit maximaal elke 30 minuten — de 10-min timer draait wel,
    // maar GPS is te zwaar voor elke tick. De weather data wordt wel ververst.
    if (loc.isCurrentLocation) {
      final lastGpsKey = 'last_gps_refresh_${loc.lat}_${loc.lon}';
      try {
        final prefs = await SharedPreferences.getInstance();
        final lastGps = prefs.getInt(lastGpsKey) ?? 0;
        final now = DateTime.now().millisecondsSinceEpoch;
        final gpsInterval = const Duration(minutes: 30).inMilliseconds;
        if (now - lastGps > gpsInterval) {
          final gps = await _locationService.getCurrentLocation();
          lat = gps.lat;
          lon = gps.lon;
          name = gps.name;
          await prefs.setInt(lastGpsKey, now);
          // Update opgeslagen locatie met nieuwe GPS-positie
          final updated = SavedLocation(
            lat: lat, lon: lon, name: name,
            sortOrder: loc.sortOrder, isCurrentLocation: true,
          );
          await _savedLocations.addLocation(updated);
          final locations = await _savedLocations.getLocations();
          if (mounted) setState(() => _locations = locations);
        }
      } catch (_) {
        // GPS faalt — gebruik oude coördinaten
      }
    }

    await provider.silentRefresh(lat, lon, name);
    if (provider.hasData && loc.isCurrentLocation) {
      WidgetService.updateWeather(provider.data!);
      // Update naam als API andere naam retourneert dan GPS
      if (loc.isCurrentLocation) {
        final weatherName = provider.data!.locationName;
        if (weatherName.isNotEmpty && weatherName != name) {
          final updated = SavedLocation(
            lat: lat, lon: lon, name: weatherName,
            sortOrder: loc.sortOrder, isCurrentLocation: true,
          );
          await _savedLocations.addLocation(updated);
          final locations = await _savedLocations.getLocations();
          if (mounted) setState(() => _locations = locations);
        }
        try {
          _notifService ??= WeatherNotificationService(weatherService: service);
          await _notifService!.checkThresholds(provider.data!);
        } catch (_) {}
      }
    }
  }

  Future<void> _onPageChanged(int page) async {
    setState(() => _currentPage = page);
    if (page < _locations.length) {
      final loc = _locations[page];
      // Gebruik memory cache voor snelle switch — geen GPS bij swipen
      await _loadLocation(loc.lat, loc.lon, loc.name, isCurrentLocation: loc.isCurrentLocation);
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
      // Save location
      await _savedLocations.addLocation(SavedLocation(lat: lat, lon: lon, name: name));
      final locations = await _savedLocations.getLocations();
      if (!mounted) return;
      setState(() => _locations = locations);
      // Navigate to the new location (last page)
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

  /// Kort locatienaam in: "Bardolino, Provincia di Verona" → "Bardolino"
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuleren')),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Opslaan'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (newName != null && newName.isNotEmpty && newName != loc.name) {
      // Remove old, add with new name
      await _savedLocations.removeLocation(loc.lat, loc.lon);
      await _savedLocations.addLocation(SavedLocation(lat: loc.lat, lon: loc.lon, name: newName, isCurrentLocation: loc.isCurrentLocation));
      final locations = await _savedLocations.getLocations();
      if (!mounted) return;
      setState(() => _locations = locations);
      // Reload weather with new name
      await _loadLocation(loc.lat, loc.lon, newName, isCurrentLocation: loc.isCurrentLocation);
    }
  }

  Future<void> _removeCurrentLocation() async {
    if (_locations.isEmpty || _currentPage >= _locations.length) return;
    final loc = _locations[_currentPage];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${loc.name} verwijderen?'),
        content: Text('Deze locatie wordt verwijderd uit je opgeslagen plaatsen.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuleren')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
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
      _currentPage = _currentPage.clamp(0, locations.isEmpty ? 0 : locations.length - 1);
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
      await _loadLocation(newLoc.lat, newLoc.lon, newLoc.name, isCurrentLocation: newLoc.isCurrentLocation);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        body: const Center(child: CircularProgressIndicator()),
        appBar: AppBar(title: const Text('Weer')),
      );
    }

    return Scaffold(
      body: _HomeBody(
        locations: _locations,
        currentPage: _currentPage,
        onRename: _renameLocation,
        onAdd: _openSearch,
        onMyLocation: _useCurrentLocation,
        onRadar: () {
          if (_locations.isNotEmpty && _currentPage < _locations.length) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RainRadarScreen(location: _locations[_currentPage]),
              ),
            );
          }
        },
        onSettings: _openSettings,
        onRemove: _locations.length > 1 ? _removeCurrentLocation : null,
        child: Consumer<WeatherProvider>(
          builder: (context, provider, _) {
            if (_locations.isEmpty) {
              return _ErrorState(
                message: 'Geen locaties. Tik op + om er toe te voegen.',
                onRetry: _openSearch,
              );
            }

            // No weather data yet — show loading or retry
            if (!provider.hasData) {
              if (provider.status == WeatherStatus.error) {
                return _ErrorState(
                  message: provider.errorMessage ?? 'Onbekende fout',
                  onRetry: () {
                    final loc = _locations[_currentPage.clamp(0, _locations.length - 1)];
                    _loadLocation(loc.lat, loc.lon, loc.name, isCurrentLocation: loc.isCurrentLocation);
                  },
                );
              }
              // Laadstatus met duidelijke tekst i.p.v. naakte spinner (voorkomt
              // een ogenschijnlijk wit scherm bij trage/afwezige data).
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        'Weer wordt geladen…',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Status: ${provider.status.name}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
                            ),
                      ),
                      if (provider.errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            provider.errorMessage!,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }

            final data = provider.data!;
            final loc = _locations[_currentPage.clamp(0, _locations.length - 1)];
            return PageView.builder(
              controller: _pageController,
              itemCount: _locations.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                // Only build the active page; others stay lightweight.
                if (index != _currentPage) {
                  return const SizedBox.shrink();
                }
                return RefreshIndicator(
                  onRefresh: () => provider.refresh(loc.lat, loc.lon, loc.name),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      CurrentWeatherCard(
                        current: data.current,
                        locationName: data.locationName,
                        sunrise: data.daily.isNotEmpty ? data.daily.first.sunrise : null,
                        sunset: data.daily.isNotEmpty ? data.daily.first.sunset : null,
                      ),
                      if (provider.lastRefresh != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6, bottom: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.update, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                'Bijgewerkt om ${provider.lastRefresh!.hour.toString().padLeft(2, '0')}:${provider.lastRefresh!.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).colorScheme.onSurface.withAlpha(120),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_showJas) JasAdviceCard(current: data.current, nextHours: data.hourly),
                      if (_showZonnebrand) ZonnebrandCard(current: data.current, nextHours: data.hourly),
                      if (_showBuien) BuienCard(nextHours: data.hourly),
                      if (_showDetails && data.daily.isNotEmpty) DetailsCard(current: data.current, today: data.daily.first),
                      if (_showAirQuality && data.airQuality != null) AirQualityCard(airQuality: data.airQuality!, pollen: data.pollen),
                      WeatherHistoryCard(pastDaily: data.pastDaily, daily: data.daily),
                      const SizedBox(height: 8),
                      DailyForecastList(
                        days: data.daily,
                        hourly: data.hourly,
                        locationName: data.locationName,
                      ),
                      if (data.pastDaily.isNotEmpty)
                        WeatherComparisonCard(
                          pastDaily: data.pastDaily,
                          daily: data.daily,
                        ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// Home body with ambient weather-based background gradient and a custom
/// header (location name + actions + page dots).
class _HomeBody extends StatelessWidget {
  final List<SavedLocation> locations;
  final int currentPage;
  final VoidCallback onRename;
  final VoidCallback onAdd;
  final VoidCallback onMyLocation;
  final VoidCallback onRadar;
  final VoidCallback onSettings;
  final VoidCallback? onRemove;
  final Widget child;

  const _HomeBody({
    required this.locations,
    required this.currentPage,
    required this.onRename,
    required this.onAdd,
    required this.onMyLocation,
    required this.onRadar,
    required this.onSettings,
    required this.onRemove,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = locations.isNotEmpty
        ? locations[currentPage.clamp(0, locations.length - 1)]
        : null;
    // Ambient gradient based on time of day → gives the whole screen depth.
    final bg = _ambientGradient();

    return Stack(
      children: [
        // Ambient background
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: bg,
              ),
            ),
          ),
        ),
        // Subtle radial glow top-right for premium feel
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.9, -0.9),
                radius: 1.2,
                colors: [
                  theme.colorScheme.primary.withAlpha(40),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Column(
            children: [
              // Custom header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: onRename,
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 20,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                loc != null ? _shortName(loc.name) : 'Weer',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.5,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.edit_outlined,
                              size: 14,
                              color: theme.colorScheme.onSurface.withAlpha(120),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_location_alt),
                      onPressed: onAdd,
                      tooltip: 'Locatie toevoegen',
                    ),
                    IconButton(
                      icon: const Icon(Icons.my_location),
                      onPressed: onMyLocation,
                      tooltip: 'Mijn locatie',
                    ),
                    IconButton(
                      icon: const Icon(Icons.radar),
                      onPressed: onRadar,
                      tooltip: 'Neerslagkaart',
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings_outlined),
                      onPressed: onSettings,
                      tooltip: 'Instellingen',
                    ),
                    if (onRemove != null)
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: onRemove,
                        tooltip: 'Locatie verwijderen',
                      ),
                  ],
                ),
              ),
              // Page dots indicator
              if (locations.length > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: locations.asMap().entries.map((e) {
                      final active = e.key == currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: active ? 18 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: active
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface.withAlpha(80),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              // Content
              Expanded(child: child),
            ],
          ),
        ),
      ],
    );
  }

  List<Color> _ambientGradient() {
    final now = DateTime.now();
    final hour = now.hour;
    final dark = WidgetsBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.dark;
    if (dark) {
      // Deep space-gray ambience, slightly cooler at night
      if (hour >= 19 || hour < 6) {
        return [const Color(0xFF0B1020), const Color(0xFF0E1116)];
      }
      return [const Color(0xFF101826), const Color(0xFF0E1116)];
    }
    // Light mode: soft sky tint
    if (hour >= 19 || hour < 6) {
      return [const Color(0xFF2A2F45), const Color(0xFFF5F8FB)];
    }
    return [const Color(0xFFDCEBF7), const Color(0xFFF5F8FB)];
  }

  String _shortName(String name) {
    return name.length > 22 ? '${name.substring(0, 20)}…' : name;
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _ErrorState({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 64, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Opnieuw proberen'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
