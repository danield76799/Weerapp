import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/saved_locations_service.dart';

/// Eenvoudige neerslagkaart met OpenStreetMap en regen overlay
/// Gebruikt de Buienradar radar kaart als transparante overlay
class RainRadarScreen extends StatelessWidget {
  final SavedLocation location;

  const RainRadarScreen({super.key, required this.location});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final center = LatLng(location.lat, location.lon);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Neerslagkaart'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showInfo(context),
            tooltip: 'Info',
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: center,
              initialZoom: 7,
              minZoom: 5,
              maxZoom: 12,
            ),
            children: [
              // Base map — dark style
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.danield.weerapp',
              ),
              // Rain overlay — Buienradar actuele radar
              TileLayer(
                urlTemplate:
                    'https://cdn.buienradar.nl/maps/radar/radar.1/radarnl_{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                tileProvider: NetworkTileProvider(),
                userAgentPackageName: 'com.danield.weerapp',
              ),
              // Location marker
              MarkerLayer(
                markers: [
                  Marker(
                    point: center,
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(100),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      width: 16,
                      height: 16,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Legend
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withAlpha(230),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Neerslagintensiteit',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _legendItem('Licht', const Color(0xFF81D4FA)),
                      _legendItem('Matig', const Color(0xFF29B6F6)),
                      _legendItem('Zwaar', const Color(0xFF0288D1)),
                      _legendItem('Zeer zwaar', const Color(0xFF01579B)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  void _showInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Neerslagkaart'),
        content: const Text(
          'Deze kaart toont de actuele neerslag van Buienradar.\n\n'
          'De blauwe kleuren geven regen aan:\n'
          '• Lichtblauw = lichte regen\n'
          '• Donkerblauw = zware regen\n\n'
          'De marker toont je huidige locatie.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Sluiten'),
          ),
        ],
      ),
    );
  }
}