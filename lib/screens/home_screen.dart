import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/location_service.dart';
import '../services/weather_notification_service.dart';
import '../services/weather_provider.dart';
import '../services/weather_service.dart';
import '../widgets/current_weather_card.dart';
import '../widgets/daily_forecast_list.dart';
import 'api_key_screen.dart';
import 'location_search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _locationService = LocationService();
  bool _checkingKey = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final service = context.read<WeatherService>();
    final hasKey = await service.hasApiKey();
    if (!mounted) return;
    setState(() => _checkingKey = false);
    if (!hasKey) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ApiKeyScreen()),
      );
      return;
    }
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
    if (_checkingKey) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

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
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '5-daagse verwachting',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                const SizedBox(height: 8),
                DailyForecastList(days: data.daily),
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
