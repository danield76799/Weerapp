import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to request battery optimization exclusion.
/// Android kills background processes for battery savings — this asks
/// the user to whitelist the app so GPS refreshes and widget updates work.
class BatteryOptimizationService {
  static const _channel = MethodChannel('com.danield.weerapp/battery');
  static const _askedKey = 'battery_optimization_asked';

  /// Check if the app is already ignoring battery optimizations.
  static Future<bool> isIgnoring() async {
    try {
      final result = await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Show the system dialog to request battery optimization exclusion.
  /// Returns true if the dialog was shown successfully.
  static Future<bool> requestIgnore() async {
    try {
      final result = await _channel.invokeMethod<bool>('requestIgnoreBatteryOptimizations');
      return result ?? false;
    } catch (_) {
      // Fallback: open battery settings directly
      return openSettings();
    }
  }

  /// Open the battery optimization settings screen.
  static Future<bool> openSettings() async {
    try {
      final result = await _channel.invokeMethod<bool>('openBatterySettings');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Ask the user to disable battery optimization once.
  /// Only shows the prompt once; skips if already whitelisted.
  static Future<void> askOnceIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyAsked = prefs.getBool(_askedKey) ?? false;
    if (alreadyAsked) return;

    final isIgnoring = await isIgnoring();
    if (isIgnoring) return;

    await requestIgnore();

    // Mark as asked so we don't prompt again
    await prefs.setBool(_askedKey, true);
  }
}