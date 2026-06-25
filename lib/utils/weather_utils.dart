import 'package:flutter/material.dart';

class WeatherUtils {
  /// UV-index risico categorie + bijbehorende kleur
  static ({String label, Color color, String advice}) uvInfo(double uv) {
    if (uv < 0) {
      return (label: 'Onbekend', color: Colors.grey, advice: '');
    }
    if (uv < 3) {
      return (
        label: 'Laag',
        color: const Color(0xFF4CAF50),
        advice: 'Geen bescherming nodig',
      );
    }
    if (uv < 6) {
      return (
        label: 'Matig',
        color: const Color(0xFFFFC107),
        advice: 'Zonnebrandcrème bij lang verblijf',
      );
    }
    if (uv < 8) {
      return (
        label: 'Hoog',
        color: const Color(0xFFFF9800),
        advice: 'Bescherming noodzakelijk',
      );
    }
    if (uv < 11) {
      return (
        label: 'Zeer hoog',
        color: const Color(0xFFF44336),
        advice: 'Vermijd middagzon, gebruik bescherming',
      );
    }
    return (
      label: 'Extreem',
      color: const Color(0xFF9C27B0),
      advice: 'Blijf binnen tussen 11-15u',
    );
  }

  /// OpenWeather weather code → icoon
  static IconData iconForCode(int code) {
    if (code >= 200 && code < 300) return Icons.thunderstorm;
    if (code >= 300 && code < 400) return Icons.grain;
    if (code >= 500 && code < 600) {
      if (code >= 511) return Icons.umbrella;
      if (code >= 502) return Icons.water_drop;
      return Icons.water_drop;
    }
    if (code >= 600 && code < 700) return Icons.ac_unit;
    if (code >= 700 && code < 800) return Icons.foggy;
    if (code == 800) return Icons.wb_sunny;
    if (code == 801) return Icons.cloud_queue;
    if (code >= 802) return Icons.cloud;
    return Icons.cloud_queue;
  }

  /// OpenWeather weather code → icoonkleur
  static Color colorForCode(int code) {
    if (code >= 200 && code < 300) return const Color(0xFF455A64);
    if (code >= 500 && code < 600) return const Color(0xFF1976D2);
    if (code >= 600 && code < 700) return const Color(0xFF90CAF9);
    if (code >= 700 && code < 800) return const Color(0xFF78909C);
    if (code == 800) return const Color(0xFFFFA726);
    if (code >= 801) return const Color(0xFF78909C);
    return const Color(0xFF90A4AE);
  }

  /// Temperatuur → kleur (blauw voor koud, rood voor warm)
  static Color tempColor(double temp) {
    if (temp <= 0) return const Color(0xFF1976D2);
    if (temp <= 10) return const Color(0xFF42A5F5);
    if (temp <= 20) return const Color(0xFF66BB6A);
    if (temp <= 25) return const Color(0xFFFFA726);
    if (temp <= 30) return const Color(0xFFEF6C00);
    return const Color(0xFFD32F2F);
  }

  /// Wind in m/s → beschrijving
  static String windDescription(double mps) {
    if (mps < 0.3) return 'Windstil';
    if (mps < 1.5) return 'Zwak';
    if (mps < 3.3) return 'Matig';
    if (mps < 5.4) return 'Vrij krachtig';
    if (mps < 7.9) return 'Krachtig';
    if (mps < 10.7) return 'Hard';
    if (mps < 13.8) return 'Stormachtig';
    if (mps < 17.1) return 'Storm';
    return 'Zware storm';
  }
}
