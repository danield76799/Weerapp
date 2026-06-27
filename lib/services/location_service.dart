import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class LocationResult {
  final double lat;
  final double lon;
  final String name;

  LocationResult({required this.lat, required this.lon, required this.name});
}

class LocationService {
  /// Vraag locatie permissie + huidige GPS
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

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.low,
      timeLimit: const Duration(seconds: 30),
    ).catchError((e) {
      // Probeer last known position als fallback
      return Geolocator.getLastKnownPosition().then((last) {
        if (last != null) return last;
        throw LocationException('GPS-timeout: kan locatie niet bepalen. Controleer of GPS aan staat.');
      });
    });

    final name = await _reverseGeocode(pos.latitude, pos.longitude);
    return LocationResult(
      lat: pos.latitude,
      lon: pos.longitude,
      name: name,
    );
  }

  /// Zoek een adres / stad op
  Future<LocationResult?> searchLocation(String query) async {
    try {
      final results = await locationFromAddress(query);
      if (results.isEmpty) return null;
      final pos = results.first;
      final name = await _reverseGeocode(pos.latitude, pos.longitude);
      return LocationResult(lat: pos.latitude, lon: pos.longitude, name: name);
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
