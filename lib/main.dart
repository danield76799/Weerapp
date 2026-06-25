import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'services/weather_notification_service.dart';
import 'services/weather_provider.dart';
import 'services/weather_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final weatherService = WeatherService();
  await WeatherNotificationService(weatherService: weatherService).initialize();

  runApp(WeerApp(weatherService: weatherService));
}

class WeerApp extends StatelessWidget {
  final WeatherService weatherService;
  const WeerApp({super.key, required this.weatherService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<WeatherService>.value(value: weatherService),
        ChangeNotifierProvider(create: (_) => WeatherProvider(weatherService)),
      ],
      child: MaterialApp(
        title: 'Weer',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(Brightness.light),
        darkTheme: _buildTheme(Brightness.dark),
        home: const HomeScreen(),
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF49AFC2),
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: brightness == Brightness.dark
          ? colorScheme.copyWith(
              surface: Colors.black,
              surfaceContainerHigh: const Color(0xFF111111),
            )
          : colorScheme,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
      ),
    );
  }
}
