import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/weather.dart';

/// Service die OpenWeather One Call API 3.0 aanroept.
/// Gratis tier: 1000 calls/dag. Maximaal 14 dagen forecast.
///
/// API key wordt opgeslagen in SharedPreferences; bij eerste gebruik
/// toont de app een setup-scherm waar de gebruiker zijn/haar eigen
/// gratis key kan invoeren.
class WeatherService {
  static const _apiKeyPref = 'openweather_api_key';
  static const _cacheKeyPrefix = 'weather_cache_';
  static const _lastLocationKey = 'last_location';
  static const _cacheMaxAge = Duration(hours: 1);

  final Dio _dio;

  WeatherService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: 'https://api.openweathermap.org',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
              headers: {'User-Agent': 'Weerapp/1.0'},
            ));

  /// Sla API key op en test 'm
  Future<bool> setApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyPref, key.trim());
    return true;
  }

  Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiKeyPref);
  }

  Future<bool> hasApiKey() async {
    final key = await getApiKey();
    return key != null && key.isNotEmpty;
  }

  /// Bewaar laatst gebruikte locatie voor offline default
  Future<void> setLastLocation(double lat, double lon, String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _lastLocationKey,
      jsonEncode({
        'lat': lat,
        'lon': lon,
        'name': name,
      }),
    );
  }

  Future<({double lat, double lon, String name})?> getLastLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastLocationKey);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return (
        lat: (json['lat'] as num).toDouble(),
        lon: (json['lon'] as num).toDouble(),
        name: json['name'] as String,
      );
    } catch (_) {
      return null;
    }
  }

  /// Haal huidige + 14-daagse forecast op voor gegeven coördinaten
  Future<WeatherData> fetchWeather({
    required double lat,
    required double lon,
    required String locationName,
    bool force = false,
  }) async {
    final key = await getApiKey();
    if (key == null || key.isEmpty) {
      throw WeatherApiException('Geen API key ingesteld');
    }

    final cacheKey = '$_cacheKeyPrefix${lat.toStringAsFixed(2)}_${lon.toStringAsFixed(2)}';

    if (!force) {
      final cached = await _readCache(cacheKey);
      if (cached != null) return cached;
    }

    try {
      final response = await _dio.get(
        '/data/3.0/onecall',
        queryParameters: {
          'lat': lat,
          'lon': lon,
          'appid': key,
          'units': 'metric',
          'lang': 'nl',
          'exclude': 'minutely,hourly,alerts',
        },
      );

      if (response.statusCode != 200) {
        throw WeatherApiException(
            'API error ${response.statusCode}: ${response.statusMessage}');
      }

      final weather = WeatherData.fromJson(
        response.data as Map<String, dynamic>,
        locationName,
      );
      await _writeCache(cacheKey, weather);
      await setLastLocation(lat, lon, locationName);
      return weather;
    } on DioException catch (e) {
      // Probeer cache als fallback bij netwerkfout
      final cached = await _readCache(cacheKey, ignoreAge: true);
      if (cached != null) return cached;
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.error is SocketException) {
        throw WeatherApiException('Geen internetverbinding');
      }
      throw WeatherApiException('Netwerkfout: ${e.message}');
    } catch (e) {
      final cached = await _readCache(cacheKey, ignoreAge: true);
      if (cached != null) return cached;
      rethrow;
    }
  }

  Future<WeatherData?> _readCache(String key, {bool ignoreAge = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final fetchedAt = DateTime.parse(json['fetchedAt'] as String);
      if (!ignoreAge &&
          DateTime.now().difference(fetchedAt) > _cacheMaxAge) {
        return null;
      }
      return WeatherData.fromJson(json, json['locationName'] as String);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(String key, WeatherData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(data.toJson()));
  }
}

class WeatherApiException implements Exception {
  final String message;
  WeatherApiException(this.message);

  @override
  String toString() => message;
}
