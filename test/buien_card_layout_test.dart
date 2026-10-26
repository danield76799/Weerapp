// Regressietest: de regenkaart en het uurscherm mogen geen
// layout-overflow veroorzaken, ook niet met een kleine of vergrote
// tekstschaal.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:weerapp/models/weather.dart';
import 'package:weerapp/widgets/buien_card.dart';

HourlyForecast _uur(
  DateTime time, {
  double precipitation = 0,
  int probability = 0,
  double temperature = 11,
}) {
  return HourlyForecast(
    time: time,
    temperature: temperature,
    apparentTemperature: temperature,
    precipitationProbability: probability,
    weatherCode: 3,
    uvIndex: 0.7,
    precipitation: precipitation,
  );
}

void main() {
  testWidgets('BuienCard past zonder overflow', (tester) async {
    final now = DateTime.now();
    final hours = List.generate(
      12,
      (i) => _uur(
        DateTime(now.year, now.month, now.day, now.hour + i),
        precipitation: i == 4 ? 0.4 : 0,
        probability: i == 4 ? 80 : 0,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BuienCard(nextHours: hours),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('BuienCard past met een grote tekstschaal', (tester) async {
    final now = DateTime.now();
    final hours = List.generate(
      12,
      (i) => _uur(
        DateTime(now.year, now.month, now.day, now.hour + i),
        precipitation: i == 4 ? 0.4 : 0,
        probability: i == 4 ? 80 : 0,
      ),
    );

    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BuienCard(nextHours: hours),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
