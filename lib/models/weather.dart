/// Weer data models voor Open-Meteo API

class CurrentWeather {
  final double temperature;
  final double feelsLike;
  final int humidity;
  final double windSpeed;
  final double? windGusts;
  final int weatherCode;
  final String weatherDescription;
  final DateTime timestamp;
  final double uvIndex;
  final int pressure;
  final int clouds;
  final double? precipitation;
  final DateTime sunrise;
  final DateTime sunset;
  final double? dewPoint;
  final int? visibility;
  final double? sunshineDuration;

  CurrentWeather({
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.windSpeed,
    this.windGusts,
    required this.weatherCode,
    required this.weatherDescription,
    required this.timestamp,
    required this.uvIndex,
    required this.pressure,
    required this.clouds,
    this.precipitation,
    required this.sunrise,
    required this.sunset,
    this.dewPoint,
    this.visibility,
    this.sunshineDuration,
  });

  double get dayLengthHours => sunset.difference(sunrise).inMinutes / 60.0;
  double? get sunshineHours => sunshineDuration != null ? sunshineDuration! / 3600.0 : null;

  factory CurrentWeather.fromJson(Map<String, dynamic> json) {
    return CurrentWeather(
      temperature: (json['temperature'] as num).toDouble(),
      feelsLike: (json['feels_like'] as num).toDouble(),
      humidity: (json['humidity'] as int?) ?? 0,
      windSpeed: (json['wind_speed'] as num).toDouble(),
      windGusts: (json['wind_gusts'] as num?)?.toDouble(),
      weatherCode: (json['weather_code'] as num?)?.toInt() ?? 0,
      weatherDescription: (json['weather_description'] as String?) ?? '',
      timestamp: json['timestamp'] is String ? DateTime.parse(json['timestamp']) : DateTime.now(),
      uvIndex: (json['uv_index'] as num?)?.toDouble() ?? 0,
      pressure: (json['pressure'] as int?) ?? 1013,
      clouds: (json['clouds'] as int?) ?? 0,
      precipitation: (json['precipitation'] as num?)?.toDouble(),
      sunrise: json['sunrise'] is String ? DateTime.parse(json['sunrise']) : DateTime.now(),
      sunset: json['sunset'] is String ? DateTime.parse(json['sunset']) : DateTime.now(),
      dewPoint: (json['dew_point'] as num?)?.toDouble(),
      visibility: (json['visibility'] as num?)?.toInt(),
      sunshineDuration: (json['sunshine_duration'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'temperature': temperature,
        'feels_like': feelsLike,
        'humidity': humidity,
        'wind_speed': windSpeed,
        'wind_gusts': windGusts,
        'weather_code': weatherCode,
        'weather_description': weatherDescription,
        'timestamp': timestamp.toIso8601String(),
        'uv_index': uvIndex,
        'pressure': pressure,
        'clouds': clouds,
        'precipitation': precipitation,
        'sunrise': sunrise.toIso8601String(),
        'sunset': sunset.toIso8601String(),
        'dew_point': dewPoint,
        'visibility': visibility,
        'sunshine_duration': sunshineDuration,
      };
}

class DailyForecast {
  final DateTime date;
  final double tempMin;
  final double tempMax;
  final double tempDay;
  final double tempNight;
  final int weatherCode;
  final String weatherDescription;
  final double precipitationProbability;
  final double precipitationAmount;
  final double windSpeed;
  final double? windGustsMax;
  double _uvIndexMax; // raw theoretical max from API, updated from hourly
  final int cloudCover; // daily average cloud cover %
  final int humidity;
  final DateTime sunrise;
  final DateTime sunset;
  final double? sunshineDuration;

  DailyForecast({
    required this.date,
    required this.tempMin,
    required this.tempMax,
    required this.tempDay,
    required this.tempNight,
    required this.weatherCode,
    required this.weatherDescription,
    required this.precipitationProbability,
    required this.precipitationAmount,
    required this.windSpeed,
    this.windGustsMax,
    required double uvIndex,
    this.cloudCover = 0,
    required this.humidity,
    required this.sunrise,
    required this.sunset,
    this.sunshineDuration,
  }) : _uvIndexMax = uvIndex;

  /// UV index — calculated from hourly data if available, otherwise raw API max
  double get uvIndex => _uvIndexMax;

  /// Set the UV based on hourly max (called after parsing hourly data)
  set uvIndexFromHourly(double value) {
    _uvIndexMax = value;
  }

  /// Raw theoretical UV max
  double get uvIndexMax => _uvIndexMax;

  double get dayLengthHours => sunset.difference(sunrise).inMinutes / 60.0;
  double? get sunshineHours => sunshineDuration != null ? sunshineDuration! / 3600.0 : null;

  factory DailyForecast.fromJson(Map<String, dynamic> json) {
    return DailyForecast(
      date: json['date'] is String ? DateTime.parse(json['date']) : DateTime.now(),
      tempMin: (json['temp_min'] as num?)?.toDouble() ?? 0,
      tempMax: (json['temp_max'] as num?)?.toDouble() ?? 0,
      tempDay: (json['temp_day'] as num?)?.toDouble() ?? 0,
      tempNight: (json['temp_night'] as num?)?.toDouble() ?? 0,
      weatherCode: (json['weather_code'] as num?)?.toInt() ?? 0,
      weatherDescription: (json['weather_description'] as String?) ?? '',
      precipitationProbability: (json['precipitation_probability'] as num?)?.toDouble() ?? 0,
      precipitationAmount: (json['precipitation_amount'] as num?)?.toDouble() ?? 0,
      windSpeed: (json['wind_speed'] as num?)?.toDouble() ?? 0,
      windGustsMax: (json['wind_gusts_max'] as num?)?.toDouble(),
      uvIndex: (json['uv_index'] as num?)?.toDouble() ?? 0,
      cloudCover: (json['cloud_cover'] as num?)?.toInt() ?? 0,
      humidity: (json['humidity'] as int?) ?? 0,
      sunrise: json['sunrise'] is String ? DateTime.parse(json['sunrise']) : DateTime.now(),
      sunset: json['sunset'] is String ? DateTime.parse(json['sunset']) : DateTime.now(),
      sunshineDuration: (json['sunshine_duration'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'temp_min': tempMin,
        'temp_max': tempMax,
        'temp_day': tempDay,
        'temp_night': tempNight,
        'weather_code': weatherCode,
        'weather_description': weatherDescription,
        'precipitation_probability': precipitationProbability,
        'precipitation_amount': precipitationAmount,
        'wind_speed': windSpeed,
        'wind_gusts_max': windGustsMax,
        'uv_index': uvIndexMax,
        'cloud_cover': cloudCover,
        'humidity': humidity,
        'sunrise': sunrise.toIso8601String(),
        'sunset': sunset.toIso8601String(),
        'sunshine_duration': sunshineDuration,
      };
}

class HourlyForecast {
  final DateTime time;
  final double temperature;
  final double apparentTemperature;
  final int precipitationProbability;
  final int weatherCode;
  final double uvIndex;
  final double? precipitation;
  final int windDirection;
  final bool isDay;

  HourlyForecast({
    required this.time,
    required this.temperature,
    required this.apparentTemperature,
    required this.precipitationProbability,
    required this.weatherCode,
    required this.uvIndex,
    this.precipitation,
    this.windDirection = 0,
    this.isDay = true,
  });
}

class AirQuality {
  final int pm10;
  final int pm25;
  final int no2;
  final int o3;
  final int? europeanAqi;
  final DateTime timestamp;

  AirQuality({
    required this.pm10,
    required this.pm25,
    required this.no2,
    required this.o3,
    this.europeanAqi,
    required this.timestamp,
  });

  String get label {
    final aqi = europeanAqi ?? pm25;
    if (aqi <= 20) return 'Goed';
    if (aqi <= 40) return 'Matig';
    if (aqi <= 60) return 'Ongezond';
    if (aqi <= 80) return 'Zeer ongezond';
    return 'Gevaarlijk';
  }

  String get advice {
    final aqi = europeanAqi ?? pm25;
    if (aqi <= 20) return 'Geen bezorgdheid';
    if (aqi <= 40) return 'Geen bezorgdheid voor de meesten';
    if (aqi <= 60) return 'Gevoelige groepen kunnen klachten krijgen';
    if (aqi <= 80) return 'Iedereen kan klachten krijgen';
    return 'Vermijd buitenactiviteiten';
  }

  factory AirQuality.fromJson(Map<String, dynamic> json) {
    return AirQuality(
      pm10: (json['pm10'] as num?)?.toInt() ?? 0,
      pm25: (json['pm25'] as num?)?.toInt() ?? 0,
      no2: (json['no2'] as num?)?.toInt() ?? 0,
      o3: (json['o3'] as num?)?.toInt() ?? 0,
      europeanAqi: (json['european_aqi'] as num?)?.toInt(),
      timestamp: json['timestamp'] is String
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'pm10': pm10,
        'pm25': pm25,
        'no2': no2,
        'o3': o3,
        'european_aqi': europeanAqi,
        'timestamp': timestamp.toIso8601String(),
      };
}

class PollenInfo {
  final int grass;
  final int birch;
  final int alder;
  final int mugwort;
  final int ragweed;
  final DateTime timestamp;

  PollenInfo({
    required this.grass,
    required this.birch,
    required this.alder,
    required this.mugwort,
    required this.ragweed,
    required this.timestamp,
  });

  String grassLabel() => _pollenLabel(grass);
  String birchLabel() => _pollenLabel(birch);
  String alderLabel() => _pollenLabel(alder);
  String mugwortLabel() => _pollenLabel(mugwort);
  String ragweedLabel() => _pollenLabel(ragweed);

  String _pollenLabel(int value) {
    if (value == 0) return 'geen';
    if (value <= 2) return 'laag';
    if (value <= 5) return 'matig';
    if (value <= 10) return 'hoog';
    return 'zeer hoog';
  }

  factory PollenInfo.fromJson(Map<String, dynamic> json) {
    return PollenInfo(
      grass: (json['grass'] as num?)?.toInt() ?? 0,
      birch: (json['birch'] as num?)?.toInt() ?? 0,
      alder: (json['alder'] as num?)?.toInt() ?? 0,
      mugwort: (json['mugwort'] as num?)?.toInt() ?? 0,
      ragweed: (json['ragweed'] as num?)?.toInt() ?? 0,
      timestamp: json['timestamp'] is String
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'grass': grass,
        'birch': birch,
        'alder': alder,
        'mugwort': mugwort,
        'ragweed': ragweed,
        'timestamp': timestamp.toIso8601String(),
      };
}

class WeatherData {
  final CurrentWeather current;
  final List<DailyForecast> daily;
  final List<DailyForecast> pastDaily;
  final List<HourlyForecast> hourly;
  final AirQuality? airQuality;
  final PollenInfo? pollen;
  final DateTime fetchedAt;
  final String locationName;
  final double lat;
  final double lon;

  WeatherData({
    required this.current,
    required this.daily,
    this.pastDaily = const [],
    required this.hourly,
    this.airQuality,
    this.pollen,
    required this.fetchedAt,
    required this.locationName,
    required this.lat,
    required this.lon,
  });
  /// Get hourly forecasts for a specific date, starting from current hour if today
  List<HourlyForecast> hourlyForDay(DateTime date) {
    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    return hourly.where((h) {
      // Match the date
      if (h.time.year != date.year || h.time.month != date.month || h.time.day != date.day) {
        return false;
      }
      // If today, only show hours from now onwards
      if (isToday && h.time.isBefore(now.subtract(const Duration(minutes: 30)))) {
        return false;
      }
      return true;
    }).toList();
  }

  List<HourlyForecast> nextHours(int count) {
    final now = DateTime.now();
    return hourly
        .where((h) => h.time.isAfter(now.subtract(const Duration(hours: 1))))
        .take(count)
        .toList();
  }

  factory WeatherData.fromJson(Map<String, dynamic> json, String locationName) {
    final hourly = <HourlyForecast>[];
    if (json['hourly'] != null) {
      for (final h in (json['hourly'] as List)) {
        final m = h as Map<String, dynamic>;
        hourly.add(HourlyForecast(
          time: DateTime.parse(m['time'] as String),
          temperature: (m['temperature'] as num).toDouble(),
          apparentTemperature: (m['apparent_temperature'] as num?)?.toDouble() ?? (m['temperature'] as num).toDouble(),
          precipitationProbability: (m['precipitation_probability'] as num).toInt(),
          weatherCode: (m['weather_code'] as num).toInt(),
          uvIndex: (m['uv_index'] as num).toDouble(),
          precipitation: (m['precipitation'] as num?)?.toDouble(),
          windDirection: (m['wind_direction'] as num?)?.toInt() ?? 0,
          isDay: (m['is_day'] as num?)?.toInt() == 1,
        ));
      }
    }
    return WeatherData(
      current: CurrentWeather.fromJson(json['current']),
      daily: (json['daily'] as List)
          .take(16)
          .map((d) => DailyForecast.fromJson(d as Map<String, dynamic>))
          .toList(),
      pastDaily: (json['past_daily'] as List?)
          ?.map((d) => DailyForecast.fromJson(d as Map<String, dynamic>))
          .toList() ?? [],
      hourly: hourly,
      airQuality: json['air_quality'] != null
          ? AirQuality.fromJson(json['air_quality'])
          : null,
      pollen: json['pollen'] != null
          ? PollenInfo.fromJson(json['pollen'])
          : null,
      fetchedAt: json['fetchedAt'] != null
          ? DateTime.parse(json['fetchedAt'] as String)
          : DateTime.now(),
      locationName: locationName,
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lon: (json['lon'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'cache_version': 7,
        'current': current.toJson(),
        'daily': daily.map((d) => d.toJson()).toList(),
        'past_daily': pastDaily.map((d) => d.toJson()).toList(),
        'hourly': hourly.map((h) => {
          'time': h.time.toIso8601String(),
          'temperature': h.temperature,
          'apparent_temperature': h.apparentTemperature,
          'precipitation_probability': h.precipitationProbability,
          'weather_code': h.weatherCode,
          'uv_index': h.uvIndex,
          'precipitation': h.precipitation,
          'wind_direction': h.windDirection,
          'is_day': h.isDay ? 1 : 0,
        }).toList(),
        'air_quality': airQuality?.toJson(),
        'pollen': pollen?.toJson(),
        'fetchedAt': fetchedAt.toIso8601String(),
        'locationName': locationName,
        'lat': lat,
        'lon': lon,
      };
}