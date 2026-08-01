extension StringExtensions on String {
  /// Maakt de eerste letter van een string een hoofdletter
  String capitalize() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }
}
