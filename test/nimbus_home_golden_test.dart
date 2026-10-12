import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:weerapp/models/weather.dart';
import 'package:weerapp/screens/nimbus_home_screen.dart';
import 'package:weerapp/services/weather_provider.dart';
import 'package:weerapp/services/weather_service.dart';

/// Solide-kleur PNG zodat de test zonder netwerk rendert.
Future<Uint8List> _solidPng(Color color, {int size = 64}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
    ui.Paint()..color = color,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(size, size);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('rendert het Nimbus homescreen met voorbeelddata naar PNG',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(564, 1268);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // SharedPreferences in-memory, mét een opgeslagen locatie zodat de
    // bootstrap niet op GPS zit te wachten. saved_locations is een JSON-string
    // (SavedLocationsService doet jsonDecode op getString).
    SharedPreferences.setMockInitialValues({
      'onboarding_seen': true,
      'saved_locations': jsonEncode([
        {'lat': 43.65, 'lon': -79.38, 'name': 'Toronto, CA', 'sortOrder': 0, 'isCurrentLocation': false},
      ]),
    });

    // Provider met fake-weather: verzin getallen, geen netwerk.
    final service = WeatherService();
    final provider = WeatherProvider(service);

    // We injecteren fake data door loadWeather te mocken via de memory-cache:
    // simpler is direct een WeatherData te construeren.
    // WeatherProvider heeft geen setter; we gebruiken de interne cache via
    // loadWeather — maar die doet netwerk. Daarom bouwen we het scherm met een
    // gepatchte provider-subclass.
    final fakeData = WeatherData(
      current: CurrentWeather(
        temperature: 13,
        feelsLike: 12,
        humidity: 97,
        windSpeed: 8,
        weatherCode: 2,
        weatherDescription: 'Helder met af en toe bewolking',
        timestamp: DateTime.now(),
        uvIndex: 2,
        pressure: 1015,
        clouds: 40,
        precipitation: 0,
        sunrise: DateTime.now().subtract(const Duration(hours: 6)),
        sunset: DateTime.now().add(const Duration(hours: 6)),
      ),
      daily: [
        DailyForecast(
          date: DateTime.now(),
          tempMin: 13,
          tempMax: 22,
          tempDay: 18,
          tempNight: 9,
          weatherCode: 1,
          weatherDescription: 'Helder',
          precipitationProbability: 20,
          precipitationAmount: 0,
          windSpeed: 8,
          uvIndex: 3,
          humidity: 70,
          sunrise: DateTime.now().subtract(const Duration(hours: 6)),
          sunset: DateTime.now().add(const Duration(hours: 6)),
        ),
        DailyForecast(
          date: DateTime.now().add(const Duration(days: 1)),
          tempMin: 14,
          tempMax: 24,
          tempDay: 19,
          tempNight: 10,
          weatherCode: 61,
          weatherDescription: 'Lichte regen',
          precipitationProbability: 85,
          precipitationAmount: 4,
          windSpeed: 12,
          uvIndex: 2,
          humidity: 80,
          sunrise: DateTime.now().subtract(const Duration(hours: 6)),
          sunset: DateTime.now().add(const Duration(hours: 6)),
        ),
      ],
      hourly: List.generate(
        12,
        (i) => HourlyForecast(
          time: DateTime.now().add(Duration(hours: i + 1)),
          temperature: 21 + (i % 3),
          apparentTemperature: 20,
          precipitationProbability: i % 2 == 0 ? 10 : 5,
          weatherCode: 2,
          uvIndex: 2,
          precipitation: 0,
          windDirection: 180,
          isDay: i < 6,
        ),
      ),
      fetchedAt: DateTime.now(),
      locationName: 'Toronto, CA',
      lat: 43.65,
      lon: -79.38,
    );

    // Inject via reflection-achtige hack: WeatherProvider.data is read-only,
    // dus we testen het scherm met de echte provider en zetten de data via
    // silentRefresh-mock. Praktischer: test het scherm niet met echte netwerk
    // maar met de fake-provider subclass hieronder.
    final fakeProvider = _FakeWeatherProvider(service, fakeData);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<WeatherService>.value(value: service),
          ChangeNotifierProvider<WeatherProvider>.value(value: fakeProvider),
        ],
        child: const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: NimbusHomeScreen(),
        ),
      ),
    );

    // Bootstrap is async (prefs + provider): pump de frames handmatig in
    // plaats van pumpAndSettle — de loading-spinner pusht continue frames.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    await expectLater(
      find.byType(NimbusHomeScreen),
      matchesGoldenFile('goldens/nimbus_home.png'),
    );
  });
}

/// Provider die het netwerk omzeilt: loadWeather/silentRefresh vullen _data
/// met de meegegeven fake-WeatherData.
class _FakeWeatherProvider extends WeatherProvider {
  final WeatherData fakeData;
  _FakeWeatherProvider(super.service, this.fakeData);

  bool _loaded = false;

  @override
  Future<void> loadWeather({
    required double lat,
    required double lon,
    required String locationName,
    bool force = false,
  }) async {
    if (_loaded) return;
    _loaded = true;
    // Gebruik de interne gelijkwaardige flow: set data via de publieke API.
    // WeatherProvider heeft geen publieke setter; we misbruiken het feit dat
    // fake data toch al in fakeData zit en renderen dat direct. Voor de
    // golden-test is alleen de render relevant.
  }

  @override
  // ignore: unnecessary_overrides
  WeatherData? get data => fakeData;

  @override
  bool get hasData => true;

  @override
  WeatherStatus get status => WeatherStatus.loaded;

  @override
  DateTime? get lastRefresh => DateTime.now();
}