import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/location_service.dart';
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
  Timer? _autoRefreshTimer;
  static const _refreshInterval = Duration(minutes: 10);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh when app comes back to foreground
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(_refreshInterval, (_) => _refresh());
  }

  Future<void> _bootstrap() async {
    final service = context.read<WeatherService>();
    // Open-Meteo doesn't need an API key — skip setup screen
    final last = await service.getLastLocation();
    if (last != null) {
      _load(last.lat, last.lon, last.name);
    } else {
      _useCurrentLocation();
    }
  }

  Future<void> _useCurrentLocation() async {
    try {
      final loc = await _locationService.getCurrentLocation();
      if (!mounted) return;
      _load(loc.lat, loc.lon, loc.name);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Locatie: $e')),
      );
      // Zoek alsnog handmatig
      _openSearch();
    }
  }

  Future<void> _load(double lat, double lon, String name) async {
    final provider = context.read<WeatherProvider>();
    await provider.loadWeather(lat: lat, lon: lon, locationName: name);
    if (provider.hasData) {
      // Check notificaties na laden
      try {
        final notif = WeatherNotificationService(
          weatherService: context.read<WeatherService>(),
        );
        await notif.checkThresholds(provider.data!);
      } catch (_) {}
    }
  }

  Future<void> _openSearch() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const LocationSearchScreen()),
    );
    if (result != null) {
      _load(result['lat'] as double, result['lon'] as double, result['name'] as String);
    }
  }

  Future<void> _refresh() async {
    final provider = context.read<WeatherProvider>();
    final service = context.read<WeatherService>();
    final last = await service.getLastLocation();
    if (last == null) return;
    await provider.refresh(last.lat, last.lon, last.name);
    if (provider.hasData) {
      final notif = WeatherNotificationService(weatherService: service);
      await notif.checkThresholds(provider.data!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _openSearch,
            tooltip: 'Zoek locatie',
          ),
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _useCurrentLocation,
            tooltip: 'Mijn locatie',
          ),
        ],
      ),
      body: Consumer<WeatherProvider>(
        builder: (context, provider, _) {
          if (provider.status == WeatherStatus.loading && !provider.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.status == WeatherStatus.error && !provider.hasData) {
            return _ErrorState(
              message: provider.errorMessage ?? 'Onbekende fout',
              onRetry: _useCurrentLocation,
            );
          }
          if (!provider.hasData) {
            return const Center(child: Text('Geen data'));
          }

          final data = provider.data!;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (provider.isFromCache)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.cloud_off,
                            size: 16,
                            color: Theme.of(context).colorScheme.onTertiaryContainer),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Offline data van ${data.fetchedAt.hour}:${data.fetchedAt.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onTertiaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                CurrentWeatherCard(
                  current: data.current,
                  locationName: data.locationName,
                ),
                const SizedBox(height: 12),
                JasAdviceCard(
                  current: data.current,
                  nextHours: data.nextHours(6),
                ),
                const SizedBox(height: 12),
                ZonnebrandCard(current: data.current),
                const SizedBox(height: 12),
                BuienCard(nextHours: data.nextHours(12)),
                const SizedBox(height: 12),
                DetailsCard(
                  current: data.current,
                  today: data.daily.first,
                ),
                if (data.airQuality != null || data.pollen != null) ...[
                  const SizedBox(height: 12),
                  AirQualityCard(
                    airQuality: data.airQuality,
                    pollen: data.pollen,
                  ),
                ],
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '16-daagse verwachting',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                const SizedBox(height: 8),
                DailyForecastList(
                  days: data.daily,
                  hourly: data.hourly,
                  locationName: data.locationName,
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
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
