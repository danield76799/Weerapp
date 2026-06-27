import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SavedLocation {
  final double lat;
  final double lon;
  final String name;
  final int sortOrder;
  final bool isCurrentLocation;

  SavedLocation({
    required this.lat,
    required this.lon,
    required this.name,
    this.sortOrder = 0,
    this.isCurrentLocation = false,
  });

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lon': lon,
        'name': name,
        'sortOrder': sortOrder,
        'isCurrentLocation': isCurrentLocation,
      };

  factory SavedLocation.fromJson(Map<String, dynamic> json) {
    return SavedLocation(
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      name: json['name'] as String,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      isCurrentLocation: (json['isCurrentLocation'] as bool?) ?? false,
    );
  }
}

class SavedLocationsService {
  static const _key = 'saved_locations';

  Future<List<SavedLocation>> getLocations() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      final locations = list
          .map((e) => SavedLocation.fromJson(e as Map<String, dynamic>))
          .toList();
      locations.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return locations;
    } catch (_) {
      return [];
    }
  }

  Future<void> addLocation(SavedLocation loc) async {
    final locations = await getLocations();
    // If this is a current location, unmark any previous current location
    if (loc.isCurrentLocation) {
      for (var i = 0; i < locations.length; i++) {
        if (locations[i].isCurrentLocation) {
          locations[i] = SavedLocation(
            lat: locations[i].lat,
            lon: locations[i].lon,
            name: locations[i].name,
            sortOrder: locations[i].sortOrder,
            isCurrentLocation: false,
          );
        }
      }
    }
    // Avoid duplicates
    final exists = locations.any((l) =>
        (l.lat - loc.lat).abs() < 0.01 && (l.lon - loc.lon).abs() < 0.01);
    if (!exists) {
      locations.add(loc);
    } else {
      // Update existing with isCurrentLocation flag
      final idx = locations.indexWhere((l) =>
          (l.lat - loc.lat).abs() < 0.01 && (l.lon - loc.lon).abs() < 0.01);
      if (idx >= 0) {
        locations[idx] = SavedLocation(
          lat: locations[idx].lat,
          lon: locations[idx].lon,
          name: loc.name.isNotEmpty ? loc.name : locations[idx].name,
          sortOrder: locations[idx].sortOrder,
          isCurrentLocation: loc.isCurrentLocation,
        );
      }
    }
    await _save(locations);
  }

  Future<void> removeLocation(double lat, double lon) async {
    final locations = await getLocations();
    locations.removeWhere(
        (l) => (l.lat - lat).abs() < 0.01 && (l.lon - lon).abs() < 0.01);
    // Re-index sortOrder
    for (var i = 0; i < locations.length; i++) {
      locations[i] = SavedLocation(
        lat: locations[i].lat,
        lon: locations[i].lon,
        name: locations[i].name,
        sortOrder: i,
      );
    }
    await _save(locations);
  }

  Future<void> _save(List<SavedLocation> locations) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(locations.map((l) => l.toJson()).toList()),
    );
  }
}