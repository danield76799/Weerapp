import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/saved_locations_service.dart';

/// Geanimeerde neerslagkaart — 2u terug + 5u vooruit via Open-Meteo raster
class RainRadarScreen extends StatefulWidget {
  final SavedLocation location;
  const RainRadarScreen({super.key, required this.location});

  @override
  State<RainRadarScreen> createState() => _RainRadarScreenState();
}

class _RainRadarScreenState extends State<RainRadarScreen> {
  static DateTime? _lastFetch;
  static List<_PrecipFrame>? _cachedFrames;
  static const Duration _cacheDuration = Duration(minutes: 5);

  final MapController _mapController = MapController();
  List<_PrecipFrame> _frames = [];
  int _currentFrame = 0;
  bool _playing = true;
  Timer? _timer;
  bool _loading = true;
  String? _error;

  static const _gridSize = 3; // 3x3 = 9 points
  static const _gridSpacing = 0.5; // ~55km
  static const _pastHours = 1;
  static const _futureHours = 3;
  static const _totalHours = _pastHours + _futureHours;
  static const _animDuration = Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    _fetchPrecipGrid();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _fetchPrecipGrid() async {
    // Use cached data if recent
    final now = DateTime.now();
    if (_lastFetch != null &&
        _cachedFrames != null &&
        now.difference(_lastFetch!) < _cacheDuration) {
      setState(() {
        _frames = _cachedFrames!;
        _currentFrame = _pastHours;
        _loading = false;
      });
      _startAnimation();
      return;
    }
    try {
      final dio = Dio();
      final centerLat = widget.location.lat;
      final centerLon = widget.location.lon;

      // Build grid coords as comma-separated for batch API call
      final lats = <String>[];
      final lons = <String>[];
      final half = (_gridSize - 1) / 2;
      for (var row = 0; row < _gridSize; row++) {
        for (var col = 0; col < _gridSize; col++) {
          lats.add((centerLat + (half - row) * _gridSpacing).toStringAsFixed(3));
          lons.add((centerLon + (col - half) * _gridSpacing).toStringAsFixed(3));
        }
      }

      // Single batch call: comma-separated lat/lon
      final response = await dio.get<String>(
        'https://api.open-meteo.com/v1/forecast',
        queryParameters: {
          'latitude': lats.join(','),
          'longitude': lons.join(','),
          'hourly': 'precipitation,precipitation_probability',
          'past_days': 2,
          'forecast_days': 2,
          'timezone': 'UTC',
        },
        options: Options(responseType: ResponseType.plain, receiveTimeout: const Duration(seconds: 15)),
      );

      final body = response.data!;
      final decoded = jsonDecode(body);

      // API returns a list when multiple coords, single object for one
      List<dynamic> resultsList;
      if (decoded is List) {
        resultsList = decoded;
      } else {
        resultsList = [decoded];
      }

      // Parse each location's data
      final gridData = <_GridPointData>[];
      for (var i = 0; i < resultsList.length && i < _gridSize * _gridSize; i++) {
        final loc = resultsList[i] as Map<String, dynamic>;
        final lat = (loc['latitude'] as num).toDouble();
        final lon = (loc['longitude'] as num).toDouble();
        final hourly = loc['hourly'] as Map<String, dynamic>;
        final times = hourly['time'] as List;
        final precip = hourly['precipitation'] as List;
        final prob = hourly['precipitation_probability'] as List?;

        // Find "now" index
        final now = DateTime.now().toUtc();
        int startIdx = 0;
        int closestDiff = 999999;
        for (var j = 0; j < times.length; j++) {
          final t = DateTime.parse(times[j] as String);
          final diff = (t.difference(now).inMinutes).abs();
          if (diff < closestDiff) {
            closestDiff = diff;
            startIdx = j;
          }
        }

        // Extract values: startIdx-pastHours to startIdx+futureHours
        final values = <double>[];
        for (var j = startIdx - _pastHours; j <= startIdx + _futureHours; j++) {
          if (j >= 0 && j < precip.length) {
            final p = (precip[j] as num?)?.toDouble() ?? 0;
            final pr = (prob?[j] as num?)?.toDouble() ?? 0;
            values.add(p > 0 ? p : 0);
          } else {
            values.add(0);
          }
        }
        gridData.add(_GridPointData(lat: lat, lon: lon, precipitation: values));
      }

      // Build frames
      final now = DateTime.now().toUtc();
      final frames = <_PrecipFrame>[];
      for (var h = 0; h <= _totalHours; h++) {
        final frameTime = now.subtract(Duration(hours: _pastHours)).add(Duration(hours: h));
        final framePoints = gridData.map((gd) {
          final precip = gd.precipitation.length > h ? gd.precipitation[h] : 0.0;
          return _PrecipPoint(lat: gd.lat, lon: gd.lon, precipitation: precip);
        }).toList();
        frames.add(_PrecipFrame(time: frameTime, points: framePoints));
      }
      // Cache the result
      _lastFetch = now;
      _cachedFrames = frames;

      setState(() {
        _frames = frames;
        _currentFrame = _pastHours;
        _loading = false;
      });
      _startAnimation();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _startAnimation() {
    _timer?.cancel();
    _timer = Timer.periodic(_animDuration, (_) {
      if (!mounted) return;
      setState(() => _currentFrame = (_currentFrame + 1) % _frames.length);
    });
  }

  void _pauseAnimation() {
    _timer?.cancel();
    _timer = null;
    setState(() => _playing = false);
  }

  void _resumeAnimation() {
    setState(() => _playing = true);
    _startAnimation();
  }

  void _jumpToFrame(int index) {
    _timer?.cancel();
    _timer = null;
    setState(() {
      _currentFrame = index;
      _playing = false;
    });
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now().toUtc();
    final diff = dt.difference(now);
    if (diff.inMinutes.abs() < 10) return 'nu';
    if (diff.isNegative) {
      return '${diff.inHours.abs()}u ${diff.inMinutes.abs() % 60}min geleden';
    } else {
      return 'over ${diff.inHours}u ${diff.inMinutes % 60}min';
    }
  }

  String _formatClock(DateTime dt) {
    final local = dt.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  Color _precipColor(double mm) {
    if (mm <= 0) return Colors.transparent;
    if (mm < 0.3) return const Color(0xFF81D4FA).withAlpha(160);
    if (mm < 1.0) return const Color(0xFF29B6F6).withAlpha(180);
    if (mm < 2.5) return const Color(0xFF0288D1).withAlpha(200);
    return const Color(0xFF01579B).withAlpha(220);
  }

  double _precipRadius(double mm) {
    if (mm <= 0) return 0;
    if (mm < 0.3) return 14;
    if (mm < 1.0) return 18;
    if (mm < 2.5) return 22;
    return 28;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final center = LatLng(widget.location.lat, widget.location.lon);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Neerslagkaart')),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Radar laden...'),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Neerslagkaart')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off, size: 48, color: theme.colorScheme.onSurface.withAlpha(120)),
                const SizedBox(height: 16),
                Text('Radar niet beschikbaar', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withAlpha(150)), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: () {
                  setState(() => _loading = true);
                  _fetchPrecipGrid();
                }, child: const Text('Opnieuw proberen')),
              ],
            ),
          ),
        ),
      );
    }

    final frame = _frames[_currentFrame];
    final isFuture = _currentFrame > _pastHours;
    final isNow = _currentFrame == _pastHours;

    final precipMarkers = <Marker>[];
    for (final p in frame.points) {
      if (p.precipitation > 0.05) {
        final color = _precipColor(p.precipitation);
        final radius = _precipRadius(p.precipitation);
        precipMarkers.add(Marker(
          point: LatLng(p.lat, p.lon),
          child: Container(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            width: radius,
            height: radius,
          ),
        ));
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Neerslagkaart'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _loading = true);
              _fetchPrecipGrid();
            },
            tooltip: 'Vernieuwen',
          ),
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
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 8,
              minZoom: 5,
              maxZoom: 12,
            ),
            children: [
              // OpenStreetMap standard tiles — most reliable
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.danield.weerapp',
                tileProvider: NetworkTileProvider(),
              ),
              MarkerLayer(markers: precipMarkers),
              MarkerLayer(
                markers: [
                  Marker(
                    point: center,
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [BoxShadow(color: Colors.black.withAlpha(100), blurRadius: 4)],
                      ),
                      width: 16,
                      height: 16,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Time label
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withAlpha(230),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isFuture ? Icons.schedule : (isNow ? Icons.my_location : Icons.history),
                    size: 16,
                    color: isFuture ? const Color(0xFFFF9800) : (isNow ? const Color(0xFF4CAF50) : theme.colorScheme.primary),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_formatClock(frame.time)} — ${_formatTime(frame.time)}',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
                  ),
                ],
              ),
            ),
          ),
          // Controls
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withAlpha(230),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => _playing ? _pauseAnimation() : _resumeAnimation(),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle),
                          child: Icon(_playing ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 20),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final barWidth = constraints.maxWidth;
                            return GestureDetector(
                              onTapDown: (details) {
                                final ratio = (details.localPosition.dx / barWidth).clamp(0.0, 1.0);
                                _jumpToFrame((ratio * (_frames.length - 1)).round());
                              },
                              child: SizedBox(
                                height: 32,
                                child: Stack(
                                  alignment: Alignment.centerLeft,
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.only(top: 14, bottom: 14),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.onSurface.withAlpha(40),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    Positioned(
                                      left: 0,
                                      top: 14,
                                      bottom: 14,
                                      width: barWidth * (_pastHours / _totalHours),
                                      child: Container(decoration: BoxDecoration(color: theme.colorScheme.primary.withAlpha(120), borderRadius: BorderRadius.circular(2))),
                                    ),
                                    Positioned(
                                      right: 0,
                                      top: 14,
                                      bottom: 14,
                                      width: barWidth * (_futureHours / _totalHours),
                                      child: Container(decoration: BoxDecoration(color: const Color(0xFFFF9800).withAlpha(120), borderRadius: BorderRadius.circular(2))),
                                    ),
                                    Positioned(
                                      left: barWidth * (_pastHours / _totalHours) - 1,
                                      top: 10,
                                      bottom: 10,
                                      child: Container(width: 2, color: const Color(0xFF4CAF50)),
                                    ),
                                    AnimatedPositioned(
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeOut,
                                      left: (_currentFrame / (_frames.length - 1)) * barWidth - 8,
                                      top: 8,
                                      child: Container(
                                        width: 16,
                                        height: 16,
                                        decoration: BoxDecoration(
                                          color: isFuture ? const Color(0xFFFF9800) : (isNow ? const Color(0xFF4CAF50) : theme.colorScheme.primary),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 2),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('-${_pastHours}u', style: TextStyle(fontSize: 9, color: theme.colorScheme.onSurface.withAlpha(120))),
                      Text('nu', style: TextStyle(fontSize: 9, color: const Color(0xFF4CAF50), fontWeight: FontWeight.w700)),
                      Text('+${_futureHours}u', style: const TextStyle(fontSize: 9, color: Color(0xFFFF9800))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _legendItem('Licht', const Color(0xFF81D4FA)),
                      _legendItem('Matig', const Color(0xFF29B6F6)),
                      _legendItem('Zwaar', const Color(0xFF0288D1)),
                      _legendItem('Zwaar+', const Color(0xFF01579B)),
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
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 3),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    );
  }

  void _showInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Neerslagkaart'),
        content: const Text(
          'Deze kaart toont een animatie van neerslag:\n\n'
          '• Blauwe cirkels = afgelopen 2 uur\n'
          '• Oranje cirkels = komende 5 uur voorspelling\n'
          '• Groene streep = nu\n\n'
          'Druk op play/pause om de animatie te starten of stoppen. '
          'Schuif over de balk om naar een specifiek tijdstip te gaan.\n\n'
          'Data: Open-Meteo (25 punten raster)',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Sluiten')),
        ],
      ),
    );
  }
}

class _GridPointData {
  final double lat;
  final double lon;
  final List<double> precipitation;
  _GridPointData({required this.lat, required this.lon, required this.precipitation});
}

class _PrecipPoint {
  final double lat;
  final double lon;
  final double precipitation;
  _PrecipPoint({required this.lat, required this.lon, required this.precipitation});
}

class _PrecipFrame {
  final DateTime time;
  final List<_PrecipPoint> points;
  _PrecipFrame({required this.time, required this.points});
}