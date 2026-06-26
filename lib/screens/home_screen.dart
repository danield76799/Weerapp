import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/location_service.dart';
import '../services/saved_locations_service.dart';
import '../services/weather_notification_service.dart';
import '../services/weather_provider.dart';
import '../services/weather_service.dart';
import '../widgets/current_weather_card.dart';
import '../widgets/daily_forecast_list.dart';
import '../widgets/jas_advice_card.dart';
import '../widgets/zonnebrand_card.dart';
import '../widgets/buien_card.dart';
import '../widgets/air_quality_card.dart';
import '../widgets/details_card.dart';
import 'location_search_screen.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
      await _loadLocation(loc.lat, loc.lon, loc.name);
    }
    _startAutoRefresh();
  }

  Future<void> _useCurrentLocation() async {
    try {
      final loc = await _locationService.getCurrentLocation();
      if (!mounted) return;
      // Save as a location
      final saved = SavedLocation(lat: loc.lat, lon: loc.lon, name: loc.name);
      await _savedLocations.addLocation(saved);
      final locations = await _savedLocations.getLocations();
      setState(() {
        _locations = locations;
        _loading = false;
      });
      await _loadLocation(loc.lat, loc.lon, loc.name);
      _startAutoRefresh();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Locatie: $e')),
      );
      _openSearch();
    }
  }

  Future<void> _loadLocation(double lat, double lon, String name) async {
    final provider = context.read<WeatherProvider>();
    await provider.loadWeather(lat: lat, lon: lon, locationName: name);
    if (provider.hasData) {
      try {
        final notif = WeatherNotificationService(
          weatherService: context.read<WeatherService>(),
        );
        await notif.checkThresholds(provider.data!);
      } catch (_) {}
    }
  }

  Future<void> _silentRefreshCurrent() async {
    if (_locations.isEmpty || _currentPage >= _locations.length) return;
    final loc = _locations[_currentPage];
    final provider = context.read<WeatherProvider>();
    final service = context.read<WeatherService>();
    await provider.silentRefresh(loc.lat, loc.lon, loc.name);
    if (provider.hasData) {
      try {
        final notif = WeatherNotificationService(weatherService: service);
        await notif.checkThresholds(provider.data!);
      } catch (_) {}
    }
  }

  Future<void> _onPageChanged(int page) async {
    setState(() => _currentPage = page);
    if (page < _locations.length) {
      final loc = _locations[page];
      await _loadLocation(loc.lat, loc.lon, loc.name);
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
      await _loadLocation(newLoc.lat, newLoc.lon, newLoc.name);
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
        title: Text(
          _locations.isNotEmpty ? _locations[_currentPage.clamp(0, _locations.length - 1)].name : 'Weer',
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
                  onRetry: () => _loadLocation(loc.lat, loc.lon, loc.name),
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
                    JasAdviceCard(current: data.current, nextHours: data.nextHours(6)),
                    const SizedBox(height: 12),
                    ZonnebrandCard(current: data.current),
                    const SizedBox(height: 12),
                    BuienCard(nextHours: data.nextHours(12)),
                    const SizedBox(height: 12),
                    DetailsCard(current: data.current, today: data.daily.first),
                    if (data.airQuality != null || data.pollen != null) ...[
                      const SizedBox(height: 12),
                      AirQualityCard(airQuality: data.airQuality, pollen: data.pollen),
                    ],
                    const SizedBox(height: 16),
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