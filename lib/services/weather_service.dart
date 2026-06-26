import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/weather.dart';

/// Open-Meteo API — gratis, geen API key, 16-daagse forecast met UV-index.
///
/// Docs: https://open-meteo.com/en/docs
/// Forecast API: https://api.open-meteo.com/v1/forecast
/// Air Quality API: https://air-quality-api.open-meteo.com/v1/air-quality
///
class WeatherService {
  static const _cacheKeyPrefix = 'weather_cache_';
  static const _lastLocationKey = 'last_location';
  static const _cacheMaxAge = Duration(hours: 1);

  static const _forecastBaseUrl = 'https://api.open-meteo.com';
  static const _airQualityUrl =
      'https://air-quality-api.open-meteo.com/v1/air-quality';

  final Dio _dio;

  WeatherService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: _forecastBaseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
            ));

  // API key methods — kept for compatibility but not used with Open-Meteo
  Future<bool> setApiKey(String key) async => true;
  Future<String?> getApiKey() async => 'open-meteo';
  Future<bool> hasApiKey() async => true;

  Future<void> setLastLocation(double lat, double lon, String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _lastLocationKey,
      jsonEncode({'lat': lat, 'lon': lon, 'name': name}),
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

  /// Haal huidige + 16-daagse forecast op via Open-Meteo
  Future<WeatherData> fetchWeather({
    required double lat,
    required double lon,
    required String locationName,
    bool force = false,
  }) async {
    final cacheKey =
        '$_cacheKeyPrefix${lat.toStringAsFixed(2)}_${lon.toStringAsFixed(2)}';

    if (!force) {
      final cached = await _readCache(cacheKey);
      if (cached != null) return cached;
    }

    try {
      final response = await _dio.get(
        '/v1/forecast',
        queryParameters: {
          'latitude': lat,
          'longitude': lon,
          'current': [
            'temperature_2m',
            'apparent_temperature',
            'relative_humidity_2m',
            'precipitation',
            'weather_code',
            'wind_speed_10m',
            'pressure_msl',
            'cloud_cover',
            'uv_index',
            'dew_point_2m',
            'visibility',
            'wind_gusts_10m',
            'sunshine_duration',
          ].join(','),
          'hourly': [
            'temperature_2m',
            'precipitation_probability',
            'weather_code',
            'uv_index',
            'cloud_cover',
          ].join(','),
          'daily': [
            'weather_code',
            'temperature_2m_max',
            'temperature_2m_min',
            'apparent_temperature_max',
            'apparent_temperature_min',
            'sunrise',
            'sunset',
            'uv_index_max',
            'precipitation_sum',
            'precipitation_probability_max',
            'wind_speed_10m_max',
            'wind_gusts_10m_max',
            'relative_humidity_2m_max',
            'cloud_cover_max',
            'sunshine_duration',
          ].join(','),
          'timezone': 'auto',
          'forecast_days': 16,
          'wind_speed_unit': 'ms',
          'temperature_unit': 'celsius',
          'precipitation_unit': 'mm',
        },
      );

      if (response.statusCode != 200) {
        throw WeatherApiException('API error ${response.statusCode}');
      }

      final data = response.data as Map<String, dynamic>;

      // Best-effort air quality + pollen fetch (separate API).
      final airQuality = await _fetchAirQuality(lat, lon);

      final weather = _parseOpenMeteo(
        data,
        locationName,
        airQuality: airQuality.$1,
        pollen: airQuality.$2,
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

  /// Fetch current air quality + pollen from the Open-Meteo Air Quality API.
  ///
  /// Returns `(null, null)` if the request fails — weather data should still be
  /// returned to the caller in that case.
  Future<(AirQuality?, PollenInfo?)> _fetchAirQuality(
    double lat,
    double lon,
  ) async {
    try {
      final response = await _dio.get(
        _airQualityUrl,
        queryParameters: {
          'latitude': lat,
          'longitude': lon,
          'current': [
            'pm2_5',
            'pm10',
            'nitrogen_dioxide',
            'ozone',
            'european_aqi',
            'birch_pollen',
            'alder_pollen',
            'grass_pollen',
            'mugwort_pollen',
            'ragweed_pollen',
          ].join(','),
          'timezone': 'auto',
        },
      );

      if (response.statusCode != 200) {
        return (null, null);
      }

      final body = response.data as Map<String, dynamic>;
      final current = body['current'] as Map<String, dynamic>?;
      if (current == null) return (null, null);

      final timeStr = current['time'] as String?;
      final ts = timeStr != null ? DateTime.parse(timeStr) : DateTime.now();

      AirQuality? air;
      PollenInfo? pollen;

      try {
        air = AirQuality(
          pm25: (current['pm2_5'] as num?)?.toInt() ?? 0,
          pm10: (current['pm10'] as num?)?.toInt() ?? 0,
          no2: (current['nitrogen_dioxide'] as num?)?.toInt() ?? 0,
          o3: (current['ozone'] as num?)?.toInt() ?? 0,
          europeanAqi: (current['european_aqi'] as num?)?.toInt(),
          timestamp: ts,
        );
      } catch (_) {
        air = null;
      }

      try {
        pollen = PollenInfo(
          grass: (current['grass_pollen'] as num?)?.toInt() ?? 0,
          birch: (current['birch_pollen'] as num?)?.toInt() ?? 0,
          alder: (current['alder_pollen'] as num?)?.toInt() ?? 0,
          mugwort: (current['mugwort_pollen'] as num?)?.toInt() ?? 0,
          ragweed: (current['ragweed_pollen'] as num?)?.toInt() ?? 0,
          timestamp: ts,
        );
      } catch (_) {
        pollen = null;
      }

      return (air, pollen);
    } catch (_) {
      // Non-fatal: air quality is supplementary.
      return (null, null);
    }
  }

  /// Parse Open-Meteo response naar WeatherData
  WeatherData _parseOpenMeteo(
    Map<String, dynamic> json,
    String locationName, {
    AirQuality? airQuality,
    PollenInfo? pollen,
  }) {
    final currentJson = json['current'] as Map<String, dynamic>;
    final dailyJson = json['daily'] as Map<String, dynamic>;
    final hourlyJson = json['hourly'] as Map<String, dynamic>?;

    // Current weather
    final current = CurrentWeather(
      temperature: (currentJson['temperature_2m'] as num?)?.toDouble() ?? 0,
      feelsLike: (currentJson['apparent_temperature'] as num?)?.toDouble() ?? 0,
      humidity: (currentJson['relative_humidity_2m'] as num?)?.toInt() ?? 0,
      windSpeed: (currentJson['wind_speed_10m'] as num?)?.toDouble() ?? 0,
      windGusts: (currentJson['wind_gusts_10m'] as num?)?.toDouble(),
      weatherCode: _wmoCode((currentJson['weather_code'] as num?) ?? 0),
      weatherDescription: _wmoDescription((currentJson['weather_code'] as num?) ?? 0),
      timestamp: DateTime.parse(currentJson['time'] as String),
      uvIndex: (currentJson['uv_index'] as num?)?.toDouble() ?? 0,
      pressure: (currentJson['pressure_msl'] as num?)?.toInt() ?? 1013,
      clouds: (currentJson['cloud_cover'] as num?)?.toInt() ?? 0,
      precipitation: (currentJson['precipitation'] as num?)?.toDouble(),
      sunrise: DateTime.parse((dailyJson['sunrise'] as List).first as String),
      sunset: DateTime.parse((dailyJson['sunset'] as List).first as String),
      dewPoint: (currentJson['dew_point_2m'] as num?)?.toDouble(),
      visibility: (currentJson['visibility'] as num?)?.toInt(),
      sunshineDuration: (currentJson['sunshine_duration'] as num?)?.toDouble(),
    );

    // Daily forecast — 16 days
    final dates = dailyJson['time'] as List;
    final tMax = dailyJson['temperature_2m_max'] as List;
    final tMin = dailyJson['temperature_2m_min'] as List;
    final appMax = dailyJson['apparent_temperature_max'] as List;
    final appMin = dailyJson['apparent_temperature_min'] as List;
    final weatherCodes = dailyJson['weather_code'] as List;
    final uvMax = dailyJson['uv_index_max'] as List;
    final precipSum = dailyJson['precipitation_sum'] as List;
    final precipProb = dailyJson['precipitation_probability_max'] as List;
    final windMax = dailyJson['wind_speed_10m_max'] as List;
    final humidityMax = dailyJson['relative_humidity_2m_max'] as List;
    final gustsMax = dailyJson['wind_gusts_10m_max'] as List?;
    final cloudCoverDaily = dailyJson['cloud_cover_max'] as List?;
    final sunDurDaily = dailyJson['sunshine_duration'] as List?;
    final sunrises = dailyJson['sunrise'] as List;
    final sunsets = dailyJson['sunset'] as List;

    final daily = <DailyForecast>[];
    for (var i = 0; i < dates.length && i < 16; i++) {
      final date = DateTime.parse(dates[i] as String);
      final wmoCode = (weatherCodes[i] as num?)?.toInt() ?? 0;
      daily.add(DailyForecast(
        date: date,
        tempMin: (tMin[i] as num?)?.toDouble() ?? 0,
        tempMax: (tMax[i] as num?)?.toDouble() ?? 0,
        tempDay: (tMax[i] as num?)?.toDouble() ?? 0,
        tempNight: (tMin[i] as num?)?.toDouble() ?? 0,
        weatherCode: _wmoCode(wmoCode),
        weatherDescription: _wmoDescription(wmoCode),
        precipitationProbability:
            ((precipProb[i] as num?) ?? 0).toDouble() / 100,
        precipitationAmount: ((precipSum[i] as num?) ?? 0).toDouble(),
        windSpeed: (windMax[i] as num?)?.toDouble() ?? 0,
        windGustsMax: (gustsMax?[i] as num?)?.toDouble(),
        uvIndex: (uvMax[i] as num?)?.toDouble() ?? 0,
        cloudCover: (cloudCoverDaily?[i] as num?)?.toInt() ?? 0,
        humidity: (humidityMax[i] as num?)?.toInt() ?? 0,
        sunrise: DateTime.parse(sunrises[i] as String),
        sunset: DateTime.parse(sunsets[i] as String),
        sunshineDuration: (sunDurDaily?[i] as num?)?.toDouble(),
      ));
    }

    // Hourly forecast — parse all hours
    final hourly = <HourlyForecast>[];
    if (hourlyJson != null) {
      final hTimes = hourlyJson['time'] as List;
      final hTemp = hourlyJson['temperature_2m'] as List;
      final hPop = hourlyJson['precipitation_probability'] as List?;
      final hWeather = hourlyJson['weather_code'] as List;
      final hUv = hourlyJson['uv_index'] as List;
      final hCloud = hourlyJson['cloud_cover'] as List?;
      for (var i = 0; i < hTimes.length; i++) {
        final apiUv = ((hUv[i] as num?) ?? 0).toDouble();
        final cloudCover = ((hCloud?[i] as num?) ?? 0).toInt();
        // Clouds reduce UV: 0% clouds = full UV, 100% clouds = ~50% UV
        final cloudFactor = 1.0 - (cloudCover / 200.0);
        final correctedUv = apiUv * cloudFactor;
        hourly.add(HourlyForecast(
          time: DateTime.parse(hTimes[i] as String),
          temperature: (hTemp[i] as num?)?.toDouble() ?? 0,
          precipitationProbability: ((hPop?[i] as num?) ?? 0).toInt(),
          weatherCode: (hWeather[i] as num?)?.toInt() ?? 0,
          uvIndex: correctedUv,
        ));
      }
    }

    // Update daily UV with the max hourly UV for each day
    // This ensures daily UV matches what's shown in the hourly forecast
    for (final day in daily) {
      final dayHours = hourly.where((h) =>
          h.time.year == day.date.year &&
          h.time.month == day.date.month &&
          h.time.day == day.date.day);
      if (dayHours.isNotEmpty) {
        final maxHourlyUv = dayHours
            .map((h) => h.uvIndex)
            .reduce((a, b) => a > b ? a : b);
        day.uvIndexFromHourly = maxHourlyUv;
      }
    }

    return WeatherData(
      current: current,
      daily: daily,
      hourly: hourly,
      airQuality: airQuality,
      pollen: pollen,
      fetchedAt: DateTime.now(),
      locationName: locationName,
    );
  }

  /// WMO weather code → simplified code (compatible with our icon system)
  int _wmoCode(num code) {
    return code.toInt();
  }

  /// WMO weather code → Dutch description
  String _wmoDescription(num code) {
    const map = {
      0: 'onbewolkt',
      1: 'voornamelijk onbewolkt',
      2: 'deels bewolkt',
      3: 'bewolkt',
      45: 'mist',
      48: 'mist met rijp',
      51: 'lichte motregen',
      53: 'motregen',
      55: 'zware motregen',
      56: 'lichte motregen (vriezend)',
      57: 'motregen (vriezend)',
      61: 'lichte regen',
      63: 'regen',
      65: 'zware regen',
      66: 'lichte regen (vriezend)',
      67: 'regen (vriezend)',
      71: 'lichte sneeuw',
      73: 'sneeuw',
      75: 'zware sneeuw',
      77: 'sneeuwkorrels',
      80: 'lichte regenbuien',
      81: 'regenbuien',
      82: 'zware regenbuien',
      85: 'lichte sneeuwbuien',
      86: 'zware sneeuwbuien',
      95: 'onweer',
      96: 'onweer met lichte hagel',
      99: 'onweer met zware hagel',
    };
    return map[code.toInt()] ?? 'onbekend';
  }

  /// WMO weather code → icon string (day variant)
  String _wmoIcon(num code) {
    const map = {
      0: '01d',
      1: '02d',
      2: '03d',
      3: '04d',
      45: '50d',
      48: '50d',
      51: '09d',
      53: '09d',
      55: '09d',
      56: '09d',
      57: '09d',
      61: '10d',
      63: '10d',
      65: '10d',
      66: '10d',
      67: '10d',
      71: '13d',
      73: '13d',
      75: '13d',
      77: '13d',
      80: '09d',
      81: '09d',
      82: '09d',
      85: '13d',
      86: '13d',
      95: '11d',
      96: '11d',
      99: '11d',
    };
    return map[code.toInt()] ?? '01d';
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