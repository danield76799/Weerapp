// Basis smoke test voor Weerapp
import 'package:flutter_test/flutter_test.dart';

import 'package:weerapp/services/weather_service.dart';

void main() {
  test('WeatherService can be instantiated', () {
    final service = WeatherService();
    expect(service, isNotNull);
  });
}
