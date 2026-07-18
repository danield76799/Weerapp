import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/battery_optimization_service.dart';
import 'services/weather_notification_service.dart';
import 'services/weather_provider.dart';
import 'services/weather_service.dart';

// Global notifiers voor thema changes
final ValueNotifier<String> themeModeNotifier = ValueNotifier<String>('system');
final ValueNotifier<int> accentColorNotifier = ValueNotifier<int>(0xFF49AFC2);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final weatherService = WeatherService();

  final prefs = await SharedPreferences.getInstance();
  themeModeNotifier.value = prefs.getString('theme_mode') ?? 'system';
  accentColorNotifier.value = prefs.getInt('accent_color') ?? 0xFF49AFC2;

  runApp(WeerApp(weatherService: weatherService));

  // Post-startup init — fire-and-forget, niet blokkeren van eerste frame.
  // Notif init (timezone) en battery-opt prompt zijn niet nodig voor UI.
  // HomeScreen checkThresholds heeft eigen try/catch, dus een gemiste notif
  // bij cold-start is veilig.
  WeatherNotificationService(weatherService: weatherService)
      .initialize()
      .catchError((_) {});
  BatteryOptimizationService.askOnceIfNeeded().catchError((_) {});
}

class WeerApp extends StatelessWidget {
  final WeatherService weatherService;

  const WeerApp({super.key, required this.weatherService});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: accentColorNotifier,
      builder: (context, accentColor, _) {
        return ValueListenableBuilder<String>(
          valueListenable: themeModeNotifier,
          builder: (context, themeMode, _) {
            return MultiProvider(
              providers: [
                Provider<WeatherService>.value(value: weatherService),
                ChangeNotifierProvider(create: (_) => WeatherProvider(weatherService)),
              ],
              child: MaterialApp(
                title: 'Weer',
                debugShowCheckedModeBanner: false,
                theme: _buildTheme(Brightness.light, Color(accentColor)),
                darkTheme: _buildTheme(Brightness.dark, Color(accentColor)),
                themeMode: _themeModeFromString(themeMode),
                home: const _SplashGate(),
              ),
            );
          },
        );
      },
    );
  }

  ThemeMode _themeModeFromString(String mode) {
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  ThemeData _buildTheme(Brightness brightness, Color accentColor) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: accentColor,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: brightness == Brightness.dark
          ? colorScheme.copyWith(
              surface: const Color(0xFF0E1116),
              surfaceContainerHigh: const Color(0xFF1A1F2B),
              surfaceContainer: const Color(0xFF151A24),
              surfaceContainerLow: const Color(0xFF11151D),
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

class _SplashGate extends StatefulWidget {
  const _SplashGate();

  @override
  State<_SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<_SplashGate> {
  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('onboarding_seen') ?? false;
    if (!mounted) return;
    if (seen) {
      // Already seen → show home screen directly
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      // First time → show onboarding
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wb_cloudy, size: 64),
            const SizedBox(height: 16),
            Text(
              'Weer',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}