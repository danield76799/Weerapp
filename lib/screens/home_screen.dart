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
      _silentRefreshCurrent();
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
    if (provider.hasData) {
      // Update home screen widget
      WidgetService.updateWeather(provider.data!);
      if (isCurrentLocation) {
        try {
          final notif = WeatherNotificationService(
            weatherService: context.read<WeatherService>(),
          );
          await notif.checkThresholds(provider.data!);
          await notif.sendMorningBriefingIfDue(provider.data!);
        } catch (_) {}
      }
    }
  }

  Future<void> _silentRefreshCurrent() async {
    if (_locations.isEmpty || _currentPage >= _locations.length) return;
    final loc = _locations[_currentPage];
    final provider = context.read<WeatherProvider>();
    final service = context.read<WeatherService>();
    await provider.silentRefresh(loc.lat, loc.lon, loc.name);
    if (provider.hasData) {
      WidgetService.updateWeather(provider.data!);
      if (loc.isCurrentLocation) {
        try {
          final notif = WeatherNotificationService(weatherService: service);
          await notif.checkThresholds(provider.data!);
        } catch (_) {}
      }
    }
  }

  Future<void> _onPageChanged(int page) async {
    setState(() => _currentPage = page);
    if (page < _locations.length) {
      final loc = _locations[page];
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
            style: TextButton.styleFrom(foregroundColor: Colors.red),
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
      appBar: AppBar(
        title: GestureDetector(
          onTap: _renameLocation,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  _locations.isNotEmpty
                      ? _shortName(_locations[_currentPage.clamp(0, _locations.length - 1)].name)
                      : 'Weer',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.edit_outlined, size: 14, color: Theme.of(context).colorScheme.onSurface.withAlpha(120)),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_location_alt),
            onPressed: _openSearch,
            tooltip: 'Locatie toevoegen',
          ),
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _useCurrentLocation,
            tooltip: 'Mijn locatie',
          ),
          IconButton(
            icon: const Icon(Icons.radar),
            onPressed: () {
              if (_locations.isNotEmpty && _currentPage < _locations.length) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RainRadarScreen(
                      location: _locations[_currentPage],
                    ),
                  ),
                );
              }
            },
            tooltip: 'Neerslagkaart',
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: _openSettings,
            tooltip: 'Instellingen',
          ),
          if (_locations.length > 1)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _removeCurrentLocation,
              tooltip: 'Locatie verwijderen',
            ),
        ],
      ),
      body: Consumer<WeatherProvider>(
        builder: (context, provider, _) {
          if (_locations.isEmpty) {
            return _ErrorState(
              message: 'Geen locaties. Tik op + om er toe te voegen.',
              onRetry: _openSearch,
            );
          }

          return PageView.builder(
            controller: _pageController ??= PageController(),
            itemCount: _locations.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              final loc = _locations[index];
              // Only show weather for current page
              if (_locations.indexOf(loc) != _currentPage) {
                return const SizedBox.shrink();
              }

              if (provider.status == WeatherStatus.loading && !provider.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (provider.status == WeatherStatus.error && !provider.hasData) {
                return _ErrorState(
                  message: provider.errorMessage ?? 'Onbekende fout',
                  onRetry: () => _loadLocation(loc.lat, loc.lon, loc.name, isCurrentLocation: loc.isCurrentLocation),
                );
              }
              if (!provider.hasData) {
                return const Center(child: Text('Geen data'));
              }

              final data = provider.data!;
              return RefreshIndicator(
                onRefresh: () => provider.refresh(loc.lat, loc.lon, loc.name),
                child: ListView(
                  padding: const EdgeInsets.all(16),
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
                        child: Text(
                          'Bijgewerkt om ${provider.lastRefresh!.hour.toString().padLeft(2, '0')}:${provider.lastRefresh!.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onSurface.withAlpha(120),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    const SizedBox(height: 12),
                    if (_showJas)
                      JasAdviceCard(current: data.current, nextHours: data.nextHours(6)),
                    if (_showJas) const SizedBox(height: 12),
                    if (_showZonnebrand)
                      ZonnebrandCard(current: data.current),
                    if (_showZonnebrand) const SizedBox(height: 12),
                    if (_showBuien)
                      BuienCard(nextHours: data.nextHours(12)),
                    if (_showBuien) const SizedBox(height: 12),
                    if (_showDetails)
                      DetailsCard(current: data.current, today: data.daily.first),
                    if (_showDetails) const SizedBox(height: 12),
                    if (_showAirQuality && (data.airQuality != null || data.pollen != null))
                      AirQualityCard(airQuality: data.airQuality, pollen: data.pollen),
                    if (_showAirQuality && (data.airQuality != null || data.pollen != null))
                      const SizedBox(height: 16),
                    if (data.pastDaily.length >= 2) ...[
                      WeatherHistoryCard(pastDaily: data.pastDaily, daily: data.daily),
                      const SizedBox(height: 16),
                    ],
                    if (data.pastDaily.length >= 7) ...[
                      WeatherComparisonCard(pastDaily: data.pastDaily, daily: data.daily),
                      const SizedBox(height: 16),
                    ],
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        '16-daagse verwachting',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 8),
                    DailyForecastList(days: data.daily, hourly: data.hourly, locationName: data.locationName),
                    const SizedBox(height: 24),
                  ],
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: _locations.length > 1
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_locations.length, (i) {
                    final isActive = i == _currentPage;
                    return GestureDetector(
                      onTap: () {
                        _pageController?.animateToPage(
                          i,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isActive ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isActive
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurface.withAlpha(60),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            )
          : null,
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 64,
                color: Theme.of(context).colorScheme.onSurface.withAlpha(100)),
            const SizedBox(height: 16),
            Text('Weer ophalen mislukt', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Opnieuw proberen'),
            ),
          ],
        ),
      ),
    );
  }
}