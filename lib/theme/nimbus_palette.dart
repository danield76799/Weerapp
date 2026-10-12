import 'package:flutter/material.dart';

/// Kleurpalet van het Nimbus-stijl homescreen, afgeleid van het referentie-
/// screenshot (donker marine-blauw met een felblauwe hero-kaart).
///
/// Donkere kaarten op een bijna-zwart achtergrondvlak; de hero-kaart is een
/// verzadigde blauwe gradient; accentkleur voor chips/ticks is ijsblauw.
abstract class NimbusPalette {
  /// Schermachtergrond (bijna zwart, lichte blauwe zweem).
  static const Color background = Color(0xFF0B0E14);

  /// Achtergrond van de per-uur kaartjes en dagkaarten.
  static const Color card = Color(0xFF1E2230);

  /// Iets lichtere variant voor de geselecteerde/morgen-kaart.
  static const Color cardHighlight = Color(0xFF252A3A);

  /// Gradient voor de hero-kaart (van midden-blauw naar dieper blauw).
  static const Color heroTop = Color(0xFF2E5BFF);
  static const Color heroBottom = Color(0xFF1E3A8A);

  /// IJsblauw accent voor percentage-labels en de Radar-knop.
  static const Color accent = Color(0xFF8FA6FF);

  /// Zachte witte tekst op kaarten.
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFB8BDC9);
  static const Color textMuted = Color(0xFF838A99);
}