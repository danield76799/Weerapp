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
    final base = ColorScheme.fromSeed(
      seedColor: accentColor,
      brightness: brightness,
    );
    final colorScheme = brightness == Brightness.dark
        ? base.copyWith(
            surface: const Color(0xFF0E1116),
            surfaceContainerHigh: const Color(0xFF1E2228),
            surfaceContainer: const Color(0xFF161A20),
            surfaceContainerLow: const Color(0xFF12161B),
            surfaceContainerHighest: const Color(0xFF282C34),
            onSurface: const Color(0xFFE8EDF2),
            shadow: Colors.black,
          )
        : base.copyWith(
            surface: const Color(0xFFF5F8FB),
            surfaceContainerHigh: const Color(0xFFEAF1F6),
            surfaceContainer: const Color(0xFFF0F5F9),
            surfaceContainerLow: const Color(0xFFFAFCFD),
            surfaceContainerHighest: const Color(0xFFE1EAF1),
            onSurface: const Color(0xFF1A1D23),
          );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
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