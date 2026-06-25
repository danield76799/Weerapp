/// Weer data models voor OpenWeather One Call API 3.0
class CurrentWeather {
  final double temperature;
  final double feelsLike;
  final int humidity;
  final double windSpeed;
  final int weatherCode;
  final String weatherDescription;
  final String iconCode;
  final DateTime timestamp;
  final double uvIndex;
  final int pressure;
  final int clouds;
  final double? precipitation;
  final DateTime sunrise;
  final DateTime sunset;

  CurrentWeather({
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.windSpeed,
    required this.weatherCode,
    required this.weatherDescription,
    required this.iconCode,
    required this.timestamp,
    required this.uvIndex,
    required this.pressure,
    required this.clouds,
    required this.precipitation,
    required this.sunrise,
    required this.sunset,
  });

  factory CurrentWeather.fromJson(Map<String, dynamic> json) {
    return CurrentWeather(
      temperature: (json['temp'] as num).toDouble(),
      feelsLike: (json['feels_like'] as num).toDouble(),
      humidity: json['humidity'] as int,
      windSpeed: (json['wind_speed'] as num).toDouble(),
      weatherCode: json['weather'][0]['id'] as int,
      weatherDescription: json['weather'][0]['description'] as String,
      iconCode: json['weather'][0]['icon'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch((json['dt'] as int) * 1000),
      uvIndex: (json['uvi'] as num).toDouble(),
      pressure: json['pressure'] as int,
      clouds: json['clouds'] as int,
      precipitation: (json['rain']?['1h'] as num?)?.toDouble() ??
          (json['snow']?['1h'] as num?)?.toDouble(),
      sunrise: DateTime.fromMillisecondsSinceEpoch((json['sunrise'] as int) * 1000),
      sunset: DateTime.fromMillisecondsSinceEpoch((json['sunset'] as int) * 1000),
    );
  }

  Map<String, dynamic> toJson() => {
        'temp': temperature,
        'feels_like': feelsLike,
        'humidity': humidity,
        'wind_speed': windSpeed,
        'weather': [
          {
            'id': weatherCode,
            'description': weatherDescription,
            'icon': iconCode,
          }
        ],
        'dt': timestamp.millisecondsSinceEpoch ~/ 1000,
        'uvi': uvIndex,
        'pressure': pressure,
        'clouds': clouds,
        'rain': precipitation != null ? {'1h': precipitation} : null,
        'sunrise': sunrise.millisecondsSinceEpoch ~/ 1000,
        'sunset': sunset.millisecondsSinceEpoch ~/ 1000,
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
  final String iconCode;
  final double precipitationProbability;
  final double precipitationAmount;
  final double windSpeed;
  final double uvIndex;
  final int humidity;
  final DateTime sunrise;
  final DateTime sunset;

  DailyForecast({
    required this.date,
    required this.tempMin,
    required this.tempMax,
    required this.tempDay,
    required this.tempNight,
    required this.weatherCode,
    required this.weatherDescription,
    required this.iconCode,
    required this.precipitationProbability,
    required this.precipitationAmount,
    required this.windSpeed,
    required this.uvIndex,
    required this.humidity,
    required this.sunrise,
    required this.sunset,
  });

  factory DailyForecast.fromJson(Map<String, dynamic> json) {
    return DailyForecast(
      date: DateTime.fromMillisecondsSinceEpoch((json['dt'] as int) * 1000),
      tempMin: (json['temp']['min'] as num).toDouble(),
      tempMax: (json['temp']['max'] as num).toDouble(),
      tempDay: (json['temp']['day'] as num).toDouble(),
      tempNight: (json['temp']['night'] as num).toDouble(),
      weatherCode: json['weather'][0]['id'] as int,
      weatherDescription: json['weather'][0]['description'] as String,
      iconCode: json['weather'][0]['icon'] as String,
      precipitationProbability: ((json['pop'] as num?) ?? 0).toDouble(),
      precipitationAmount: ((json['rain'] as num?) ?? 0).toDouble() +
          ((json['snow'] as num?) ?? 0).toDouble(),
      windSpeed: (json['wind_speed'] as num).toDouble(),
      uvIndex: (json['uvi'] as num).toDouble(),
      humidity: json['humidity'] as int,
      sunrise: DateTime.fromMillisecondsSinceEpoch((json['sunrise'] as int) * 1000),
      sunset: DateTime.fromMillisecondsSinceEpoch((json['sunset'] as int) * 1000),
    );
  }

  Map<String, dynamic> toJson() => {
        'dt': date.millisecondsSinceEpoch ~/ 1000,
        'temp': {
          'min': tempMin,
          'max': tempMax,
          'day': tempDay,
          'night': tempNight,
        },
        'weather': [
          {
            'id': weatherCode,
            'description': weatherDescription,
            'icon': iconCode,
          }
        ],
        'pop': precipitationProbability,
        'rain': precipitationAmount,
        'wind_speed': windSpeed,
        'uvi': uvIndex,
        'humidity': humidity,
        'sunrise': sunrise.millisecondsSinceEpoch ~/ 1000,
        'sunset': sunset.millisecondsSinceEpoch ~/ 1000,
      };
}

class HourlyForecast {
  final DateTime time;
  final double temperature;
  final int precipitationProbability;
  final int weatherCode;
  final double uvIndex;

  HourlyForecast({
    required this.time,
    required this.temperature,
    required this.precipitationProbability,
    required this.weatherCode,
    required this.uvIndex,
  });
}

class WeatherData {
  final CurrentWeather current;
  final List<DailyForecast> daily;
  final List<HourlyForecast> hourly;
  final DateTime fetchedAt;
  final String locationName;

  WeatherData({
    required this.current,
    required this.daily,
    required this.hourly,
    required this.fetchedAt,
    required this.locationName,
  });

  /// Get hourly forecasts for a specific date
  List<HourlyForecast> hourlyForDay(DateTime date) {
    return hourly.where((h) =>
      h.time.year == date.year &&
      h.time.month == date.month &&
      h.time.day == date.day
    ).toList();
  }

  factory WeatherData.fromJson(Map<String, dynamic> json, String locationName) {
    final hourly = <HourlyForecast>[];
    if (json['hourly'] != null) {
      for (final h in (json['hourly'] as List)) {
        final m = h as Map<String, dynamic>;
        hourly.add(HourlyForecast(
          time: DateTime.parse(m['time'] as String),
          temperature: (m['temperature'] as num).toDouble(),
          precipitationProbability: (m['precipitation_probability'] as num).toInt(),
          weatherCode: (m['weather_code'] as num).toInt(),
          uvIndex: (m['uv_index'] as num).toDouble(),
        ));
      }
    }
    return WeatherData(
      current: CurrentWeather.fromJson(json['current']),
      daily: (json['daily'] as List)
          .take(16)
          .map((d) => DailyForecast.fromJson(d as Map<String, dynamic>))
          .toList(),
      hourly: hourly,
      fetchedAt: DateTime.now(),
      locationName: locationName,
    );
  }

  Map<String, dynamic> toJson() => {
        'current': current.toJson(),
        'daily': daily.map((d) => d.toJson()).toList(),
        'hourly': hourly.map((h) => {
          'time': h.time.toIso8601String(),
          'temperature': h.temperature,
          'precipitation_probability': h.precipitationProbability,
          'weather_code': h.weatherCode,
          'uv_index': h.uvIndex,
        }).toList(),
        'fetchedAt': fetchedAt.toIso8601String(),
        'locationName': locationName,
      };
}
