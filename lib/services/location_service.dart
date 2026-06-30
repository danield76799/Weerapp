import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class LocationResult {
  final double lat;
  final double lon;
  final String name;
  final LocationSource source;

  LocationResult({
    required this.lat,
    required this.lon,
    required this.name,
    this.source = LocationSource.gps,
  });
}

enum LocationSource { gps, network, cached, manual }

class LocationService {
  /// Haalt locatie op met multi-strategy fallback:
  /// 1. Network (WiFi/cell) — snelst, werkt binnen
  /// 2. GPS — accuraatst, duurt langer
  /// 3. Last known — als alles faalt
  /// 4. Error — geen enkele bron beschikbaar
  Future<LocationResult> getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationException('Locatie staat uit in je telefooninstellingen');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw LocationException('Locatie permissie geweigerd');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw LocationException(
          'Locatie permissie permanent geweigerd. Ga naar instellingen om dit aan te passen');
    }

    // STRATEGIE 1: Network (WiFi + cell towers) — snel, binnen
    Position? pos = await _tryNetworkLocation();
    if (pos != null) {
      final name = await _reverseGeocode(pos.latitude, pos.longitude);
      return LocationResult(
        lat: pos.latitude,
        lon: pos.longitude,
        name: name,
        source: LocationSource.network,
      );
    }

    // STRATEGIE 2: GPS — accuraat, traag
    pos = await _tryGpsLocation();
    if (pos != null) {
      final name = await _reverseGeocode(pos.latitude, pos.longitude);
      return LocationResult(
        lat: pos.latitude,
        lon: pos.longitude,
        name: name,
        source: LocationSource.gps,
      );
    }

    // STRATEGIE 3: Last known position (cached)
    pos = await Geolocator.getLastKnownPosition();
    if (pos != null) {
      final name = await _reverseGeocode(pos.latitude, pos.longitude);
      return LocationResult(
        lat: pos.latitude,
        lon: pos.longitude,
        name: name,
        source: LocationSource.cached,
      );
    }

    // Nikets werkte
    throw LocationException(
        'Kan locatie niet bepalen.\\nControleer of WiFi/GPS aan staat en probeer opnieuw.');
  }

  /// Probeer netwerk locatie (WiFi + cell towers) — werkt binnenshuis
  Future<Position?> _tryNetworkLocation() async {
    try {
      // low = network provider (WiFi + cell towers), geen GPS
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 5),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  /// Probeer GPS — accuraat maar traag, werkt slecht binnen
  Future<Position?> _tryGpsLocation() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  /// Zoek een adres / stad op
  Future<LocationResult?> searchLocation(String query) async {
    try {
      final results = await locationFromAddress(query);
      if (results.isEmpty) return null;
      final pos = results.first;
      final name = await _reverseGeocode(pos.latitude, pos.longitude);
      return LocationResult(
        lat: pos.latitude,
        lon: pos.longitude,
        name: name,
        source: LocationSource.manual,
      );
    } catch (_) {
      return null;
    }
  }

  Future<String> _reverseGeocode(double lat, double lon) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lon);
      if (placemarks.isEmpty) return 'Onbekend';
      final p = placemarks.first;
      final parts = <String>[
        if ((p.locality ?? '').isNotEmpty) p.locality!,
        if ((p.subAdministrativeArea ?? '').isNotEmpty &&
            p.subAdministrativeArea != p.locality)
          p.subAdministrativeArea!,
      ];
      if (parts.isEmpty) {
        return p.name ?? 'Locatie';
      }
      return parts.join(', ');
    } catch (_) {
      return 'Lat ${lat.toStringAsFixed(2)}, Lon ${lon.toStringAsFixed(2)}';
    }
  }
}

class LocationException implements Exception {
  final String message;
  LocationException(this.message);

  @override
  String toString() => message;
}
