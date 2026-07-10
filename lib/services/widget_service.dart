import 'package:home_widget/home_widget.dart';

import '../models/weather.dart';

class WidgetService {
  static const _appGroupId = 'com.danield.weerapp';
  static const _prefKey = 'HomeWidgetPreferences';

  /// Update de home screen widget met actuele weergegevens
  static Future<void> updateWeather(WeatherData data) async {
    try {
      final current = data.current;
      final locationName = _shortName(data.locationName);

      // Map WMO code to Dutch description
      final condition = _wmoToDutch(current.weatherCode);

      final temp = '${current.temperature.toStringAsFixed(0)}°';
      final feels = 'Voelt als ${current.feelsLike.toStringAsFixed(0)}°';

      // Rain info from next hours
      String rainInfo = '';
      final nextHours = data.nextHours(12);
      HourlyForecast? firstRain;
      for (final h in nextHours) {
        if ((h.precipitation ?? 0) > 0.2 || h.precipitationProbability > 30) {
          firstRain = h;
          break;
        }
      }
      if (firstRain != null) {
        final hour = firstRain.time.hour;
        rainInfo = '🌧 ${hour.toString().padLeft(2, '0')}:00 ${firstRain.precipitationProbability}%';
      } else {
        rainInfo = '☀️ Droog';
      }

      // UV
      final uvVal = current.uvIndex;
      String uvInfo;
      if (uvVal < 3) {
        uvInfo = 'UV $uvVal';
      } else if (uvVal < 6) {
        uvInfo = 'UV $uvVal ⚠️';
      } else {
        uvInfo = 'UV $uvVal 🔴';
      }

      // Wind
      final windInfo = '💨 ${current.windSpeed.toStringAsFixed(1)} m/s';

      // Updated time
      final now = DateTime.now();
      final updated = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      final date = '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}';

      // Set app group for sharing data with widget (Android shared preferences suite name)
      await HomeWidget.setAppGroupId(_prefKey);

      // Save to SharedPreferences for the Kotlin widget provider
      await HomeWidget.saveWidgetData('location', locationName);
      await HomeWidget.saveWidgetData('temp', temp);
      await HomeWidget.saveWidgetData('condition', condition);
      await HomeWidget.saveWidgetData('feels', feels);
      await HomeWidget.saveWidgetData('rain', rainInfo);
      await HomeWidget.saveWidgetData('uv', uvInfo);
      await HomeWidget.saveWidgetData('wind', windInfo);
      await HomeWidget.saveWidgetData('updated', updated);
      await HomeWidget.saveWidgetData('date', date);

      // Trigger widget update
      await HomeWidget.updateWidget(
        iOSName: null,
        androidName: 'WeatherWidgetProvider',
      );
    } catch (e) {
      // Silent fail — widget is non-critical
    }
  }

  static String _shortName(String name) {
    final comma = name.indexOf(',');
    if (comma > 0) return name.substring(0, comma).trim();
    return name;
  }

  static String _wmoToDutch(int code) {
    switch (code) {
      case 0:
        return '☀️ Onbewolkt';
      case 1:
        return '🌤 Hoofdzakelijk onbewolkt';
      case 2:
        return '⛅ Deels bewolkt';
      case 3:
        return '☁️ Bewolkt';
      case 45:
      case 48:
        return '🌫 Mist';
      case 51:
      case 53:
      case 55:
        return '🌦 Motregen';
      case 56:
      case 57:
        return '🌦 Motregen (ijs)';
      case 61:
      case 63:
      case 65:
        return '🌧 Regen';
      case 66:
      case 67:
        return '🌧 Ijsregen';
      case 71:
      case 73:
      case 75:
        return '❄️ Sneeuw';
      case 77:
        return '🌨 Sneeuwkorrels';
      case 80:
      case 81:
      case 82:
        return '🌧 Regenbuien';
      case 85:
      case 86:
        return '🌨 Sneeuwbuien';
      case 95:
        return '⛈️ Onweer';
      case 96:
      case 99:
        return '⛈️ Onweer met hagel';
      default:
        return 'Weer';
    }
  }
}