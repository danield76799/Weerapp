import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;
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
  static const _morningBriefingChannelId = 'morning_briefing';
  static const _morningBriefingNotifId = 1001;

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

  /// Plan de dagelijkse ochtendbriefing in
  Future<void> scheduleMorningBriefing(TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('morning_briefing', true);
    await prefs.setInt('briefing_hour', time.hour);
    await prefs.setInt('briefing_minute', time.minute);

    // Plan daily recurring notificatie
    await _plugin.zonedSchedule(
      id: _morningBriefingNotifId,
      title: '🌤 Ochtendbriefing',
      body: 'Weeroverzicht voor vandaag — tik om te bekijken',
      scheduledDate: _nextInstanceOf(time),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _morningBriefingChannelId,
          'Ochtendbriefing',
          channelDescription: 'Dagelijkse weerbriefing op instelbare tijd',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          category: AndroidNotificationCategory.reminder,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: false,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Annuleer de ochtendbriefing
  Future<void> cancelMorningBriefing() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('morning_briefing', false);
    await _plugin.cancel(id: _morningBriefingNotifId);
  }

  /// Stuur de ochtendbriefing direct (geprobeerd bij app-open)
  Future<void> sendMorningBriefingIfDue(WeatherData data) async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('morning_briefing') ?? false;
    if (!enabled) return;

    final today = DateTime.now();
    final todayKey = 'briefing_sent_${today.year}${today.month}${today.day}';
    final alreadySent = prefs.getBool(todayKey) ?? false;
    if (alreadySent) return;

    final bh = prefs.getInt('briefing_hour') ?? 7;
    final bm = prefs.getInt('briefing_minute') ?? 0;
    final nowMinutes = today.hour * 60 + today.minute;
    final briefingMinutes = bh * 60 + bm;

    // Stuur alleen in het uur ná de ingestelde tijd
    if (nowMinutes < briefingMinutes || nowMinutes > briefingMinutes + 60) return;

    final current = data.current;
    final day = data.daily.isNotEmpty ? data.daily.first : null;
    if (day == null) return;

    final lines = <String>[];
    lines.add('🌡 ${current.temperature.toStringAsFixed(0)}°C nu, max ${day.tempMax.toStringAsFixed(0)}°');
    lines.add('☁️ ${current.weatherDescription}');

    // Regen verwachting
    final nextHours = data.nextHours(12);
    bool rainToday = false;
    for (final h in nextHours) {
      if (h.precipitationProbability > 30) {
        rainToday = true;
        break;
      }
    }
    if (rainToday) {
      lines.add('🌧 Regen verwacht vandaag');
    } else {
      lines.add('☀️ Vandaag droog');
    }

    // UV
    if (current.uvIndex >= 6) {
      lines.add('🔆 UV ${current.uvIndex.toStringAsFixed(0)} (${_uvLabel(current.uvIndex)}) — smeer in!');
    } else if (current.uvIndex >= 3) {
      lines.add('🔆 UV ${current.uvIndex.toStringAsFixed(0)} (${_uvLabel(current.uvIndex)})');
    }

    // Wind
    if (current.windSpeed > 7) {
      lines.add('💨 Harde wind: ${current.windSpeed.toStringAsFixed(1)} m/s');
    }

    const androidDetails = AndroidNotificationDetails(
      _morningBriefingChannelId,
      'Ochtendbriefing',
      channelDescription: 'Dagelijkse weerbriefing op instelbare tijd',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      category: AndroidNotificationCategory.reminder,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: true,
    );

    await _plugin.show(
      id: _morningBriefingNotifId,
      title: '🌤 Ochtendbriefing — ${day.tempMax.toStringAsFixed(0)}° / ${day.tempMin.toStringAsFixed(0)}°',
      body: lines.join('\n'),
      notificationDetails: const NotificationDetails(android: androidDetails, iOS: iosDetails),
    );

    await prefs.setBool(todayKey, true);
  }

  tz.TZDateTime _nextInstanceOf(TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}