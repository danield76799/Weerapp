import 'package:flutter/material.dart';

/// Berekent lucht-achtergrond kleuren op basis van tijd van dag
/// Nacht: donkerblauw → ochtend: oranje/roze → dag: blauw → avond: paars/oranje
class SkyGradient {
  /// Geeft gradient kleuren voor een bepaald tijdstip
  static List<Color> getColors(DateTime time) {
    final hour = time.hour + time.minute / 60.0;

    if (hour < 5) {
      // Diepe nacht
      return [const Color(0xFF0A1428), const Color(0xFF1A1A3E)];
    } else if (hour < 7) {
      // Schittering (5-7u)
      final t = (hour - 5) / 2.0;
      return [
        _lerp(const Color(0xFF0A1428), const Color(0xFFFF8C42), t * 0.6),
        _lerp(const Color(0xFF1A1A3E), const Color(0xFFE91E63), t * 0.5),
      ];
    } else if (hour < 9) {
      // Ochtendschemering (7-9u)
      final t = (hour - 7) / 2.0;
      return [
        _lerp(const Color(0xFFFF8C42), const Color(0xFF49AFC2), t),
        _lerp(const Color(0xFFE91E63), const Color(0xFF80DEEA), t),
      ];
    } else if (hour < 17) {
      // Dag (9-17u)
      return [const Color(0xFF49AFC2), const Color(0xFF80DEEA)];
    } else if (hour < 20) {
      // Avondschemering (17-20u)
      final t = (hour - 17) / 3.0;
      return [
        _lerp(const Color(0xFF49AFC2), const Color(0xFFFF6F00), t),
        _lerp(const Color(0xFF80DEEA), const Color(0xFF6A1B9A), t),
      ];
    } else if (hour < 22) {
      // Schemering→nacht (20-22u)
      final t = (hour - 20) / 2.0;
      return [
        _lerp(const Color(0xFFFF6F00), const Color(0xFF0A1428), t * 0.7),
        _lerp(const Color(0xFF6A1B9A), const Color(0xFF1A1A3E), t * 0.7),
      ];
    } else {
      // Nacht
      return [const Color(0xFF0A1428), const Color(0xFF1A1A3E)];
    }
  }

  static Color _lerp(Color a, Color b, double t) {
    t = t.clamp(0.0, 1.0);
    return Color.lerp(a, b, t)!;
  }
}