import 'package:flutter/material.dart';

extension StringExtensions on String {
  /// Maakt de eerste letter van een string een hoofdletter
  String capitalize() {
    if (this.isEmpty) return this;
    return this[0].toUpperCase() + this.substring(1);
  }
}
