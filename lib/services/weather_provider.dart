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

  WeatherProvider(this._service);

  WeatherData? get data => _data;
  WeatherStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isFromCache => _isFromCache;
  bool get hasData => _data != null;

  Future<void> loadWeather({
    required double lat,
    required double lon,
    required String locationName,
    bool force = false,
  }) async {
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
      _status = WeatherStatus.loaded;
      // Bepaal of data uit cache komt
      _isFromCache = DateTime.now().difference(data.fetchedAt) > const Duration(minutes: 5);
    } catch (e) {
      _errorMessage = e.toString();
      _status = WeatherStatus.error;
    }
    notifyListeners();
  }

  Future<void> refresh(double lat, double lon, String name) async {
    await loadWeather(lat: lat, lon: lon, locationName: name, force: true);
  }
}
