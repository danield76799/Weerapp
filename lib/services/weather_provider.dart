import 'package:flutter/foundation.dart';

import '../models/weather.dart';
import '../services/weather_service.dart';

enum WeatherStatus { idle, loading, loaded, error }

class WeatherProvider extends ChangeNotifier {
  final WeatherService _service;

  WeatherData? _data;
  WeatherStatus _status = WeatherStatus.idle;
  String? _errorMessage;
  bool _isFromCache = false;
  DateTime? _lastRefresh;
  bool _disposed = false;

  // Memory cache: key = "lat,lon" -> WeatherData
  // LRU cache with max 5 entries to prevent unbounded memory growth
  static const int _maxCacheSize = 5;
  final Map<String, WeatherData> _memoryCache = {};

  WeatherProvider(this._service);

  WeatherData? get data => _data;
  WeatherStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isFromCache => _isFromCache;
  bool get hasData => _data != null;
  DateTime? get lastRefresh => _lastRefresh;

  /// Haal gecachte data op voor een specifieke locatie (uit memory)
  WeatherData? getCachedData(String key) => _memoryCache[key];

  Future<void> loadWeather({
    required double lat,
    required double lon,
    required String locationName,
    bool force = false,
  }) async {
    final key = '${lat.toStringAsFixed(2)},${lon.toStringAsFixed(2)}';

    // 1. Memory cache? → toon direct, refresh op achtergrond als nodig
    if (!force && _memoryCache.containsKey(key)) {
      final cached = _memoryCache[key]!;
      final age = DateTime.now().difference(cached.fetchedAt);
      _data = cached;
      _currentLocationKey = key;
      _status = WeatherStatus.loaded;
      _isFromCache = age > const Duration(minutes: 10);
      _lastRefresh = cached.fetchedAt;
      notifyListeners();

      // Als cache jonger dan 10 min is, niet opnieuw ophalen
      if (!_isFromCache) return;

      // Cache is oud — refresh op achtergrond (zonder loading state)
      _refreshFromMemory(key, lat, lon, locationName);
      return;
    }

    // 2. Geen memory cache — laad met loading state
    _status = WeatherStatus.loading;
    _errorMessage = null;
    _isFromCache = false;
    notifyListeners();

    try {
      final data = await _service.fetchWeather(
        lat: lat,
        lon: lon,
        locationName: locationName,
        force: force,
      );
      _data = data;
      _addToCache(key, data);
      _currentLocationKey = key;
      _isFromCache = DateTime.now().difference(data.fetchedAt) > const Duration(minutes: 5);
      _status = WeatherStatus.loaded;
      _lastRefresh = DateTime.now();
    } catch (e) {
      _errorMessage = e.toString();
      _status = WeatherStatus.error;
    }
    notifyListeners();
  }

  String? _currentLocationKey;

  /// Refresh op achtergrond terwijl oude data getoond wordt
  Future<void> _refreshFromMemory(
    String key,
    double lat,
    double lon,
    String locationName,
  ) async {
    try {
      final data = await _service.fetchWeather(
        lat: lat,
        lon: lon,
        locationName: locationName,
        force: true,
      );
      _addToCache(key, data);
      if (_currentLocationKey == key) {
        _data = data;
        _lastRefresh = DateTime.now();
        _isFromCache = false;
        notifyListeners();
      }
    } catch (_) {
      // Silent fail — oude data blijft getoond
    }
  }

  /// Silent refresh — no loading state, just update data in background
  Future<void> silentRefresh(double lat, double lon, String name) async {
    final key = '${lat.toStringAsFixed(2)},${lon.toStringAsFixed(2)}';
    try {
      final data = await _service.fetchWeather(
        lat: lat,
        lon: lon,
        locationName: name,
        force: true,
      );
      _data = data;
      _addToCache(key, data);
      _currentLocationKey = key;
      _lastRefresh = DateTime.now();
      _isFromCache = false;
      notifyListeners();
    } catch (e) {
      // Silent fail — keep old data
      debugPrint('Silent refresh failed: $e');
    }
  }

  Future<void> refresh(double lat, double lon, String name) async {
    await loadWeather(lat: lat, lon: lon, locationName: name, force: true);
  }

  /// Add to cache with LRU eviction
  void _addToCache(String key, WeatherData data) {
    if (_memoryCache.length >= _maxCacheSize && !_memoryCache.containsKey(key)) {
      _memoryCache.remove(_memoryCache.keys.first);
    }
    _memoryCache[key] = data;
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _memoryCache.clear();
    super.dispose();
  }
}