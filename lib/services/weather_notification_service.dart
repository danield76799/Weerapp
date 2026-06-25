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
    final today = data.daily.first;
    final current = data.current;

    final lastNotifKey =
        '${_lastNotifPref}_${today.date.toIso8601String().substring(0, 10)}';
    final alreadyNotified = prefs.getStringList(lastNotifKey) ?? [];

    final reasons = <String>[];

    if (current.uvIndex >= 7 && !alreadyNotified.contains('uv')) {
      reasons.add('uv');
    }
    if (current.temperature <= 0 && !alreadyNotified.contains('freeze')) {
      reasons.add('freeze');
    }
    if (current.temperature >= 30 && !alreadyNotified.contains('heat')) {
      reasons.add('heat');
    }
    if (today.tempMin <= -2 && !alreadyNotified.contains('frost')) {
      reasons.add('frost');
    }
    if (today.tempMax >= 33 && !alreadyNotified.contains('hot')) {
      reasons.add('hot');
    }

    if (reasons.isNotEmpty) {
      await _showThresholdNotification(current, today, reasons);
      await prefs.setStringList(lastNotifKey, [...alreadyNotified, ...reasons]);
    }
  }

  Future<void> _showThresholdNotification(
    CurrentWeather current,
    DailyForecast today,
    List<String> reasons,
  ) async {
    final lines = <String>[];
    if (reasons.contains('uv') || reasons.contains('hot')) {
      lines.add(
          '☀️ UV-index is ${current.uvIndex.toStringAsFixed(1)} (${_uvLabel(current.uvIndex)})');
    }
    if (reasons.contains('freeze') || reasons.contains('frost')) {
      lines.add(
          '🥶 Vorst: ${current.temperature.toStringAsFixed(0)}°C (min vandaag ${today.tempMin.toStringAsFixed(0)}°C)');
    }
    if (reasons.contains('heat')) {
      lines.add('🔥 Hitte: ${current.temperature.toStringAsFixed(0)}°C');
    }

    const androidDetails = AndroidNotificationDetails(
      'weather_alerts',
      'Weer waarschuwingen',
      channelDescription: 'Meldingen bij extreme weersomstandigheden',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true, presentBadge: true, presentSound: true,
    );
    await _plugin.show(
      id: 9001,
      title:
          'Weer alert: ${today.tempMax.toStringAsFixed(0)}°C / ${today.tempMin.toStringAsFixed(0)}°C',
      body: lines.join('\n'),
      notificationDetails: const NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      ),
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
