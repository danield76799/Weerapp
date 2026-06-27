import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

import '../models/weather.dart';
import 'weather_service.dart';

/// Service voor weer-gerelateerde notificaties
class WeatherNotificationService {
  static const _lastNotifPref = 'last_weather_notif';

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  final WeatherService weatherService;

  WeatherNotificationService({required this.weatherService});

  Future<void> initialize() async {
    if (kIsWeb) return;
    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {}

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();
  }

  /// Controleer weer op drempelwaarden en stuur notificatie
  Future<void> checkThresholds(WeatherData data) async {
    final prefs = await SharedPreferences.getInstance();
    final notificationsEnabled = prefs.getBool('weather_notifications') ?? true;
    if (!notificationsEnabled) return;

    final current = data.current;
    final today = data.daily.isNotEmpty ? data.daily.first : null;
    if (today == null) return;

    // Lees drempelwaarden uit instellingen
    final notifRain = prefs.getBool('notif_rain') ?? true;
    final notifUV = prefs.getBool('notif_uv') ?? true;
    final notifFrost = prefs.getBool('notif_frost') ?? true;
    final notifHeat = prefs.getBool('notif_heat') ?? true;

    final uvThreshold = prefs.getDouble('notif_uv_threshold') ?? 7;
    final heatThreshold = prefs.getDouble('notif_heat_threshold') ?? 30;
    final frostThreshold = prefs.getDouble('notif_frost_threshold') ?? 0;
    final rainThreshold = prefs.getDouble('notif_rain_threshold') ?? 40;

    // Check for rain in next 4 hours
    bool rainSoon = false;
    int rainMinutes = 0;
    final nextHours = data.nextHours(4);
    for (var i = 0; i < nextHours.length && i < 4; i++) {
      final h = nextHours[i];
      final precip = h.precipitation ?? 0;
      final precipProb = h.precipitationProbability;
      if (precip > 0.2 || precipProb > rainThreshold) {
        rainSoon = true;
        rainMinutes = i * 60;
        break;
      }
    }

    final lastNotifKey =
        '${_lastNotifPref}_${today.date.toIso8601String().substring(0, 10)}';
    final alreadyNotified = prefs.getStringList(lastNotifKey) ?? [];

    final reasons = <String>[];

    if (notifRain && rainSoon && !alreadyNotified.contains('rain')) {
      reasons.add('rain');
    }
    if (notifUV && (current.uvIndex >= uvThreshold || (today.tempMax >= heatThreshold)) && !alreadyNotified.contains('uv')) {
      reasons.add('uv');
    }
    if (notifFrost && current.temperature <= frostThreshold && !alreadyNotified.contains('freeze')) {
      reasons.add('freeze');
    }
    if (notifHeat && current.temperature >= heatThreshold && !alreadyNotified.contains('heat')) {
      reasons.add('heat');
    }

    if (reasons.isNotEmpty) {
      await _showNotification(current, today, reasons, rainMinutes);
      await prefs.setStringList(lastNotifKey, [...alreadyNotified, ...reasons]);
    }
  }

  Future<void> _showNotification(
    CurrentWeather current,
    DailyForecast today,
    List<String> reasons,
    int rainMinutes,
  ) async {
    final lines = <String>[];

    if (reasons.contains('rain')) {
      if (rainMinutes == 0) {
        lines.add('🌧 Het begint te regenen!');
      } else {
        lines.add('🌧 Regen verwacht binnen ${(rainMinutes / 60).ceil()} uur');
      }
    }
    if (reasons.contains('uv') || reasons.contains('heat')) {
      lines.add('☀️ UV-index ${current.uvIndex.toStringAsFixed(1)} (${_uvLabel(current.uvIndex)})');
    }
    if (reasons.contains('freeze') || reasons.contains('heat')) {
      lines.add('🌡 ${current.temperature.toStringAsFixed(0)}°C');
    }

    const androidDetails = AndroidNotificationDetails(
      'weather_alerts',
      'Weer waarschuwingen',
      channelDescription: 'Meldingen bij regen, UV, vorst of hitte',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: 'Weer alert: ${today.tempMax.toStringAsFixed(0)}° / ${today.tempMin.toStringAsFixed(0)}°',
      body: lines.join('\n'),
      notificationDetails: const NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }

  String _uvLabel(double uv) {
    if (uv < 3) return 'laag';
    if (uv < 6) return 'matig';
    if (uv < 8) return 'hoog';
    if (uv < 11) return 'zeer hoog';
    return 'extreem';
  }
}