import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/saved_locations_service.dart';

/// Geanimeerde neerslagkaart met RainViewer radar tiles
/// Speelt afgelopen 2 uur + eventuele nowcast (voorspelling) af
class RainRadarScreen extends StatefulWidget {
  final SavedLocation location;

  const RainRadarScreen({super.key, required this.location});

  @override
  State<RainRadarScreen> createState() => _RainRadarScreenState();
}

class _RainRadarScreenState extends State<RainRadarScreen> {
  final MapController _mapController = MapController();

  List<_RadarFrame> _frames = [];
  int _currentFrame = 0;
  bool _playing = true;
  Timer? _timer;
  bool _loading = true;
  String? _error;

  static const _animDuration = Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    _fetchRadarFrames();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _fetchRadarFrames() async {
    try {
      final dio = Dio();
      final response = await dio.get<String>(
        'https://api.rainviewer.com/public/weather-maps.json',
        options: Options(responseType: ResponseType.plain),
      );
      final data = jsonDecode(response.data!) as Map<String, dynamic>;
      final host = data['host'] as String;
      final radar = data['radar'] as Map<String, dynamic>;
      final past = radar['past'] as List? ?? [];
      final nowcast = radar['nowcast'] as List? ?? [];

      final frames = <_RadarFrame>[];
      for (final f in past) {
        frames.add(_RadarFrame(
          host: host,
          path: f['path'] as String,
          time: f['time'] as int,
          isNowcast: false,
        ));
      }
      for (final f in nowcast) {
        frames.add(_RadarFrame(
          host: host,
          path: f['path'] as String,
          time: f['time'] as int,
          isNowcast: true,
        ));
      }

      if (frames.isEmpty) throw Exception('Geen radar frames beschikbaar');

      setState(() {
        _frames = frames;
        _currentFrame = frames.length - 1; // Begin bij meest recente
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
      setState(() {
        _currentFrame = (_currentFrame + 1) % _frames.length;
      });
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

  String _formatTime(int epoch) {
    final dt = DateTime.fromMillisecondsSinceEpoch(epoch * 1000);
    final now = DateTime.now();
    final diff = dt.difference(now);
    final hours = diff.inHours;
    final mins = diff.inMinutes.abs() % 60;
    if (hours == 0 && diff.isNegative) {
      return '${mins}min geleden';
    } else if (hours < 0) {
      return '${hours.abs()}u ${mins}min geleden';
    } else if (hours == 0) {
      return 'over ${mins}min';
    } else {
      return 'over ${hours}u ${mins}min';
    }
  }

  String _formatClock(int epoch) {
    final dt = DateTime.fromMillisecondsSinceEpoch(epoch * 1000);
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final center = LatLng(widget.location.lat, widget.location.lon);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Neerslagkaart')),
        body: const Center(child: CircularProgressIndicator()),
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
                FilledButton(onPressed: _fetchRadarFrames, child: const Text('Opnieuw proberen')),
              ],
            ),
          ),
        ),
      );
    }

    final frame = _frames[_currentFrame];
    final radarUrl = '${frame.host}${frame.path}/256/{z}/{x}/{y}/2/1_1.png';
    final nowcastCount = _frames.where((f) => f.isNowcast).length;
    final pastCount = _frames.length - nowcastCount;

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
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 7,
              minZoom: 5,
              maxZoom: 12,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.danield.weerapp',
              ),
              // Animated radar layer — key forces rebuild per frame
              TileLayer(
                key: ValueKey('radar_$currentFrameKey'),
                urlTemplate: radarUrl,
                subdomains: const ['a', 'b', 'c'],
                tileProvider: NetworkTileProvider(),
                userAgentPackageName: 'com.danield.weerapp',
              ),
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
          // Tijdlabel bovenaan
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
                    frame.isNowcast ? Icons.schedule : Icons.history,
                    size: 16,
                    color: frame.isNowcast ? const Color(0xFFFF9800) : theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_formatClock(frame.time)} — ${_formatTime(frame.time)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Scrubber + play/pause onderaan
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
                  // Scrubber bar
                  Row(
                    children: [
                      // Play/pause
                      GestureDetector(
                        onTap: () {
                          if (_playing) {
                            _pauseAnimation();
                          } else {
                            _resumeAnimation();
                          }
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _playing ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Timeline
                      Expanded(
                        child: Column(
                          children: [
                            // Frame indicators
                              GestureDetector(
                                onTapDown: (details) {
                                  final tapPos = details.localPosition.dx;
                                  final barWidth = (context.size?.width ?? 200) - 48;
                                  final ratio = (tapPos / (barWidth > 0 ? barWidth : 200)).clamp(0.0, 1.0);
                                  _jumpToFrame((ratio * (_frames.length - 1)).round());
                                },
                                child: SizedBox(
                                  height: 24,
                                  child: Stack(
                                    alignment: Alignment.centerLeft,
                                    children: [
                                      // Track
                                      Container(
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.onSurface.withAlpha(40),
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                      // Past portion
                                      FractionallySizedBox(
                                        widthFactor: pastCount / _frames.length,
                                        child: Container(
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.primary.withAlpha(120),
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                      ),
                                      // Nowcast portion
                                      FractionallySizedBox(
                                        alignment: Alignment.centerRight,
                                        widthFactor: nowcastCount / _frames.length,
                                        child: Container(
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFF9800).withAlpha(120),
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                      ),
                                      // Thumb
                                      AnimatedPositioned(
                                        duration: const Duration(milliseconds: 200),
                                        left: 0,
                                        child: AnimatedSlide(
                                          duration: const Duration(milliseconds: 200),
                                          offset: Offset.zero,
                                          child: Container(
                                            width: 16,
                                            height: 16,
                                            margin: EdgeInsets.only(
                                              left: (_currentFrame / (_frames.length - 1)) *
                                                  ((MediaQuery.of(context).size.width - 100)),
                                            ),
                                            decoration: BoxDecoration(
                                              color: frame.isNowcast
                                                  ? const Color(0xFFFF9800)
                                                  : theme.colorScheme.primary,
                                              shape: BoxShape.circle,
                                              border: Border.all(color: Colors.white, width: 2),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            const SizedBox(height: 4),
                            // Labels
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '$pastCount verleden',
                                  style: TextStyle(fontSize: 9, color: theme.colorScheme.onSurface.withAlpha(120)),
                                ),
                                if (nowcastCount > 0)
                                  Text(
                                    '$nowcastCount voorspeld',
                                    style: const TextStyle(fontSize: 9, color: Color(0xFFFF9800)),
                                  )
                                else
                                  Text(
                                    'geen nowcast',
                                    style: TextStyle(fontSize: 9, color: theme.colorScheme.onSurface.withAlpha(80)),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Legend
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

  int get currentFrameKey => _currentFrame;

  Widget _legendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
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
          'Deze kaart toont een animatie van de neerslagradar.\n\n'
          '• Blauwe tegels = regen (licht → zwaar)\n'
          '• Blauwe tijdlijn = afgelopen 2 uur\n'
          '• Oranje tijdlijn = voorspelling (nowcast)\n\n'
          'Druk op play/pause om de animatie te starten of stoppen. '
          'Schuif over de balk om naar een specifiek tijdstip te gaan.\n\n'
          'Data: RainViewer',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Sluiten')),
        ],
      ),
    );
  }
}

class _RadarFrame {
  final String host;
  final String path;
  final int time;
  final bool isNowcast;

  _RadarFrame({
    required this.host,
    required this.path,
    required this.time,
    required this.isNowcast,
  });

  String get tileUrl => '$host$path/256/{z}/{x}/{y}/2/1_1.png';
}