import 'package:workmanager/workmanager.dart';

import 'services/location_service.dart';
import 'services/weather_notification_service.dart';
import 'services/weather_service.dart';
import 'services/widget_service.dart';

/// Top-level function — MOET buiten een class staan zodat workmanager de
/// Dart callback kan registreren in een headless isolate.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    switch (task) {
      case BackgroundTaskNames.weatherAlerts:
        await _runWeatherAlertsCheck();
        break;
      case Workmanager.iOSBackgroundTask:
        // iOS background fetch — zelfde check
        await _runWeatherAlertsCheck();
        break;
    }
    // Return true zodat het OS weet dat de taak succesvol was.
    return Future.value(true);
  });
}

/// Haal de huidige locatie op en draai de bestaande alert-logica.
/// Dit is exact dezelfde code die home_screen.dart aanroept bij app-open,
/// maar dan op de achtergrond zodat alerts ook binnenkomen zonder de app openen.
Future<void> _runWeatherAlertsCheck() async {
  try {
    final weatherService = WeatherService();
    final notifService = WeatherNotificationService(weatherService: weatherService);

    // 1. Locatie bepalen. In een headless background-isolate kunnen we geen
    //    permissie-dialog tonen, dus probeer eerst een verse GPS-positie
    //    (zonder request — alleen als permissie al gegeven is). Als die faalt,
    //    val terug op de laatst-opgeslagen locatie uit SharedPreferences.
    double lat;
    double lon;
    String name;

    try {
      final loc = await LocationService().getCurrentLocation();
      lat = loc.lat;
      lon = loc.lon;
      name = loc.name;
    } catch (_) {
      final last = await weatherService.getLastLocation();
      if (last != null) {
        lat = last.lat;
        lon = last.lon;
        name = last.name;
      } else {
        // Geen GPS en geen opgeslagen locatie — niets te doen deze tick.
        return;
      }
    }

    // 2. Verse weersdata ophalen (force = true, want achtergrond moet actueel zijn)
    final data = await weatherService.fetchWeather(
      lat: lat,
      lon: lon,
      locationName: name,
      force: true,
    );

    // 3. Update home screen widget zodat die mee ververst met huidige locatie
    await WidgetService.updateWeather(data);

    // 4. Bestaande alert + briefing-logica draaien
    await notifService.checkThresholds(data);
    await notifService.sendMorningBriefingIfDue(data);
  } catch (_) {
    // Achtergrond-taak mag nooit crashen — bij locatie/API-fout gewoon skippen.
    // Volgende tick (over ~15 min) probeert het opnieuw.
  }
}

class BackgroundTaskNames {
  static const String weatherAlerts = 'weather_alerts_background';
}
