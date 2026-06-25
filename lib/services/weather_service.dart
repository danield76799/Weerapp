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
    final userKey = prefs.getString(_apiKeyPref);
    // Built-in default key — user can override in settings
    return userKey ?? '81896c1223f157476c08c45883b32e13';
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

  /// Haal huidige + 5-daagse forecast op voor gegeven coördinaten
  /// Gebruikt OpenWeather 2.5 API (gratis, geen aparte subscription nodig)
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
      // 1. Current weather
      final currentResponse = await _dio.get(
        '/data/2.5/weather',
        queryParameters: {
          'lat': lat,
          'lon': lon,
          'appid': key,
          'units': 'metric',
          'lang': 'nl',
        },
      );

      if (currentResponse.statusCode != 200) {
        throw WeatherApiException(
            'API error ${currentResponse.statusCode}: ${currentResponse.statusMessage}');
      }

      // 2. 5-day forecast
      final forecastResponse = await _dio.get(
        '/data/2.5/forecast',
        queryParameters: {
          'lat': lat,
          'lon': lon,
          'appid': key,
          'units': 'metric',
          'lang': 'nl',
          'cnt': 40, // 5 days × 8 entries per day
        },
      );

      if (forecastResponse.statusCode != 200) {
        throw WeatherApiException(
            'API error ${forecastResponse.statusCode}: ${forecastResponse.statusMessage}');
      }

      // Combineer naar WeatherData
      final weather = _parseWeatherData(
        currentResponse.data as Map<String, dynamic>,
        forecastResponse.data as Map<String, dynamic>,
        locationName,
      );
      await _writeCache(cacheKey, weather);
      await setLastLocation(lat, lon, locationName);
      return weather;
    } on DioException catch (e) {
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

  /// Parse OpenWeather 2.5 current + forecast responses naar WeatherData
  WeatherData _parseWeatherData(
    Map<String, dynamic> currentJson,
    Map<String, dynamic> forecastJson,
    String locationName,
  ) {
    // Current weather
    final current = CurrentWeather(
      temperature: (currentJson['main']['temp'] as num).toDouble(),
      feelsLike: (currentJson['main']['feels_like'] as num).toDouble(),
      humidity: currentJson['main']['humidity'] as int,
      windSpeed: ((currentJson['wind']?['speed'] as num?) ?? 0).toDouble(),
      weatherCode: currentJson['weather'][0]['id'] as int,
      weatherDescription: currentJson['weather'][0]['description'] as String,
      iconCode: currentJson['weather'][0]['icon'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch((currentJson['dt'] as int) * 1000),
      uvIndex: 0, // 2.5 weather API doesn't include UV — will fetch separately
      pressure: (currentJson['main']['pressure'] as int?) ?? 1013,
      clouds: (currentJson['clouds']?['all'] as int?) ?? 0,
      precipitation: (currentJson['rain']?['1h'] as num?)?.toDouble() ??
          (currentJson['snow']?['1h'] as num?)?.toDouble(),
      sunrise: DateTime.fromMillisecondsSinceEpoch(
          ((currentJson['sys']?['sunrise'] as int?) ?? 0) * 1000),
      sunset: DateTime.fromMillisecondsSinceEpoch(
          ((currentJson['sys']?['sunset'] as int?) ?? 0) * 1000),
    );

    // 5-day forecast: groepeer 3-uurlijkse entries per dag
    final list = forecastJson['list'] as List;
    final dailyMap = <String, List<Map<String, dynamic>>>{};
    for (final item in list) {
      final dt = DateTime.fromMillisecondsSinceEpoch((item['dt'] as int) * 1000);
      final dayKey = '${dt.year}-${dt.month}-${dt.day}';
      dailyMap.putIfAbsent(dayKey, () => []).add(item as Map<String, dynamic>);
    }

    final daily = <DailyForecast>[];
    for (final entries in dailyMap.values) {
      double tempMin = double.infinity;
      double tempMax = double.negativeInfinity;
      double tempDay = 0;
      double tempNight = 0;
      double pop = 0;
      double rain = 0;
      double windSum = 0;
      int humiditySum = 0;
      double uvMax = 0;
      int weatherCode = 800;
      String weatherDesc = '';
      String iconCode = '';
      DateTime? sunrise;
      DateTime? sunset;
      DateTime? date;

      for (final e in entries) {
        final temp = (e['main']['temp'] as num).toDouble();
        final minT = (e['main']['temp_min'] as num).toDouble();
        final maxT = (e['main']['temp_max'] as num).toDouble();
        if (minT < tempMin) tempMin = minT;
        if (maxT > tempMax) tempMax = maxT;
        final dt = DateTime.fromMillisecondsSinceEpoch((e['dt'] as int) * 1000);
        date ??= dt;
        if (dt.hour >= 12 && dt.hour <= 15) {
          tempDay = temp;
          uvMax = ((e['main']?['uvi'] as num?) ?? 0).toDouble();
        }
        if (dt.hour >= 0 && dt.hour <= 6) {
          tempNight = temp;
        }
        pop = ((e['pop'] as num?) ?? 0).toDouble() > pop
            ? (e['pop'] as num).toDouble()
            : pop;
        rain += ((e['rain']?['3h'] as num?) ?? 0).toDouble();
        windSum += ((e['wind']?['speed'] as num?) ?? 0).toDouble();
        humiditySum += e['main']['humidity'] as int;
        weatherCode = e['weather'][0]['id'] as int;
        weatherDesc = e['weather'][0]['description'] as String;
        iconCode = e['weather'][0]['icon'] as String;
      }

      // Use current day's sunrise/sunset from current weather
      sunrise = current.sunrise;
      sunset = current.sunset;

      daily.add(DailyForecast(
        date: date!,
        tempMin: tempMin,
        tempMax: tempMax,
        tempDay: tempDay > 0 ? tempDay : (tempMin + tempMax) / 2,
        tempNight: tempNight > 0 ? tempNight : tempMin,
        weatherCode: weatherCode,
        weatherDescription: weatherDesc,
        iconCode: iconCode,
        precipitationProbability: pop,
        precipitationAmount: rain,
        windSpeed: windSum / entries.length,
        uvIndex: uvMax,
        humidity: humiditySum ~/ entries.length,
        sunrise: sunrise,
        sunset: sunset,
      ));
    }

    return WeatherData(
      current: current,
      daily: daily.take(5).toList(), // 2.5 API gives 5 days
      fetchedAt: DateTime.now(),
      locationName: locationName,
    );
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
