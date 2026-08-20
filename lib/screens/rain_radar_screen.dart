import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/saved_locations_service.dart';

/// Geanimeerde neerslagradar — echte radarbeelden via RainViewer
/// (gratis, geen API-key). Toont afgelopen 2u + komende 30min nowcast.
class RainRadarScreen extends StatefulWidget {
  final SavedLocation location;
  const RainRadarScreen({super.key, required this.location});

  @override
  State<RainRadarScreen> createState() => _RainRadarScreenState();
}

class _RainRadarScreenState extends State<RainRadarScreen> {
  static DateTime? _lastFetch;
  static List<_RadarFrame>? _cachedFrames;
  static const Duration _cacheDuration = Duration(minutes: 5);

  final MapController _mapController = MapController();
  List<_RadarFrame> _frames = [];
  int _currentFrame = 0;
  bool _playing = true;
  Timer? _timer;
  bool _loading = true;
  String? _error;

  static const _animDuration = Duration(milliseconds: 600);
  static const _tileSize = 256;
  static const _colorScheme = 2; // blauw
  static const _smooth = '1_1';

  @override
  void initState() {
    super.initState();
    _fetchRadar();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _fetchRadar() async {
    // Use cached data if recent
    final now = DateTime.now();
    if (_lastFetch != null &&
        _cachedFrames != null &&
        now.difference(_lastFetch!) < _cacheDuration) {
      setState(() {
        _frames = _cachedFrames!;
        _currentFrame = _frames.length - 1; // laatste = nu
        _loading = false;
      });
      _startAnimation();
      return;
    }
    try {
      final dio = Dio();
      final response = await dio.get<String>(
        'https://api.rainviewer.com/public/weather-maps.json',
        options: Options(
          responseType: ResponseType.plain,
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

      final decoded = jsonDecode(response.data!) as Map<String, dynamic>;
      final host = decoded['host'] as String;
      final radar = decoded['radar'] as Map<String, dynamic>;
      final past = (radar['past'] as List?) ?? [];
      final nowcast = (radar['nowcast'] as List?) ?? [];

      // Bouw frames: verleden (oud → nieuw) + nowcast (toekomst)
      final frames = <_RadarFrame>[];
      for (final item in past) {
        final m = item as Map<String, dynamic>;
        frames.add(_RadarFrame(
          time: DateTime.fromMillisecondsSinceEpoch(
            (m['time'] as num).toInt() * 1000,
            isUtc: true,
          ),
          tileUrl: '$host${m['path']}/$_tileSize/{z}/{x}/{y}/$_colorScheme/$_smooth.png',
        ));
      }
      for (final item in nowcast) {
        final m = item as Map<String, dynamic>;
        frames.add(_RadarFrame(
          time: DateTime.fromMillisecondsSinceEpoch(
            (m['time'] as num).toInt() * 1000,
            isUtc: true,
          ),
          tileUrl: '$host${m['path']}/$_tileSize/{z}/{x}/{y}/$_colorScheme/$_smooth.png',
        ));
      }

      if (frames.isEmpty) {
        throw Exception('Geen radarbeelden beschikbaar');
      }

      // Cache the result
      _lastFetch = now;
      _cachedFrames = frames;

      setState(() {
        _frames = frames;
        _currentFrame = frames.length - 1; // laatste = nu
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final center = LatLng(widget.location.lat, widget.location.lon);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Neerslagradar')),
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
        appBar: AppBar(title: const Text('Neerslagradar')),
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
                  _fetchRadar();
                }, child: const Text('Opnieuw proberen')),
              ],
            ),
          ),
        ),
      );
    }

    final frame = _frames[_currentFrame];
    final isFuture = frame.time.isAfter(DateTime.now().toUtc());
    final isNow = frame.time.difference(DateTime.now().toUtc()).inMinutes.abs() < 10;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Neerslagradar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _loading = true);
              _fetchRadar();
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
      body: Column(
        children: [
          Expanded(
            child: Stack(
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
                    // Echte radar overlay — wisselt per frame
                    Opacity(
                      opacity: 0.7,
                      child: TileLayer(
                        urlTemplate: frame.tileUrl,
                        userAgentPackageName: 'com.danield.weerapp',
                        tileProvider: NetworkTileProvider(),
                      ),
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: center,
                          child: Container(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: theme.colorScheme.onPrimary, width: 2),
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
              ],
            ),
          ),
          // Controls — fixed footer below the map, never overflows the bottom.
          SafeArea(
            top: false,
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
                          child: Icon(_playing ? Icons.pause : Icons.play_arrow, color: theme.colorScheme.onPrimary, size: 20),
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
                                    AnimatedPositioned(
                                      duration: const Duration(milliseconds: 450),
                                      curve: Curves.easeOut,
                                      left: (_currentFrame / (_frames.length - 1)) * barWidth - 8,
                                      top: 8,
                                      child: Container(
                                        width: 16,
                                        height: 16,
                                        decoration: BoxDecoration(
                                          color: isFuture ? const Color(0xFFFF9800) : (isNow ? const Color(0xFF4CAF50) : theme.colorScheme.primary),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: theme.colorScheme.surface, width: 2),
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
                      Text('-${_frames.length ~/ 2}u', style: TextStyle(fontSize: 9, color: theme.colorScheme.onSurface.withAlpha(120))),
                      Text('nu', style: TextStyle(fontSize: 9, color: const Color(0xFF4CAF50), fontWeight: FontWeight.w700)),
                      Text('+30min', style: const TextStyle(fontSize: 9, color: Color(0xFFFF9800))),
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
        title: const Text('Neerslagradar'),
        content: const Text(
          'Deze kaart toont een animatie van echte radarbeelden:\n\n'
          '• Blauw = neerslagintensiteit\n'
          '• Afgelopen 2 uur + komende 30 min nowcast\n'
          '• Groene stip = nu\n\n'
          'Druk op play/pause om de animatie te starten of stoppen. '
          'Schuif over de balk om naar een specifiek tijdstip te gaan.\n\n'
          'Data: RainViewer (echte radar, gratis)',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Sluiten')),
        ],
      ),
    );
  }
}

class _RadarFrame {
  final DateTime time;
  final String tileUrl;
  _RadarFrame({required this.time, required this.tileUrl});
}
