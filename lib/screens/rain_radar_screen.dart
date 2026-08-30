import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/saved_locations_service.dart';

/// Neerslagkaart via de eigen DWD-radarproxy (VM 13.140.136.172:8090).
///
/// De proxy levert per 5 minuten één PNG (NL + omstreken, EPSG:4326-bbox
/// uit het manifest): verleden (-2u) én nowcast (+2u). De app toont
/// precies één overlay per moment (gaplessPlayback) — geen tile-stapel.
class RainRadarScreen extends StatefulWidget {
  final SavedLocation location;
  const RainRadarScreen({super.key, required this.location});

  @override
  State<RainRadarScreen> createState() => _RainRadarScreenState();
}

class _RadarFrame {
  final DateTime time;
  final String path;
  final int offsetMin;
  Uint8List? bytes;
  _RadarFrame({required this.time, required this.path, required this.offsetMin});
}

class _RainRadarScreenState extends State<RainRadarScreen> {
  static const _proxyBase = 'http://13.140.136.172:8090';
  final Dio _dio = Dio();
  final MapController _mapController = MapController();

  List<_RadarFrame> _frames = [];
  List<LatLng> _boundsSWNE = const [LatLng(49, 2), LatLng(55, 14.5)];
  int _currentFrame = 0;
  Timer? _timer;
  bool _playing = true;
  bool _loading = true;
  String? _error;

  static const _animDuration = Duration(milliseconds: 480);

  @override
  void initState() {
    super.initState();
    _fetchManifest();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _fetchManifest() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '$_proxyBase/manifest.json',
        options: Options(receiveTimeout: const Duration(seconds: 30)),
      );
      final data = res.data!;
      final rawBounds = (data['bounds'] as List).map((e) => (e as num).toDouble()).toList();
      // bounds: [south, west, north, east]
      _boundsSWNE = [
        LatLng(rawBounds[0], rawBounds[1]), // sw
        LatLng(rawBounds[2], rawBounds[3]), // ne
      ];

      final frames = <_RadarFrame>[];
      for (final item in (data['frames'] as List)) {
        final f = item as Map<String, dynamic>;
        final offset = (f['offset'] as num).toInt();
        // sla de allerlaatste toekomst-stap over als DWD hem (nog) niet publiceert:
        // de proxy geeft dan 404 en de app laadt de PNG alsnog lazily.
        frames.add(_RadarFrame(
          time: DateTime.parse(f['time'] as String),
          path: f['path'] as String,
          offsetMin: offset,
        ));
      }

      if (frames.isEmpty) {
        setState(() {
          _error = 'Geen radar-frames in manifest';
          _loading = false;
        });
        return;
      }

      // Laatste verleden-frame als start
      var startIdx = frames.lastIndexWhere((f) => f.offsetMin <= 0);
      if (startIdx < 0) startIdx = frames.length - 1;

      setState(() {
        _frames = frames;
        _currentFrame = startIdx;
        _loading = false;
      });
      _startAnimation();
      await _preloadNeighborhood(startIdx);
    } catch (e) {
      setState(() {
        _error = 'Proxy onbereikbaar: $e';
        _loading = false;
      });
    }
  }

  /// Laadt frames rond het actieve frame (breder naar voren dan achteren).
  Future<void> _preloadNeighborhood(int center) async {
    final idxs = <int>{};
    for (var d = 0; d <= 4; d++) {
      idxs.add((center + d).clamp(0, _frames.length - 1));
      idxs.add((center - d).clamp(0, _frames.length - 1));
    }
    for (final i in idxs) {
      final f = _frames[i];
      if (f.bytes != null) continue;
      try {
        final res = await _dio.get<List<int>>(
          '$_proxyBase${f.path}',
          options: Options(responseType: ResponseType.bytes),
        );
        if (!mounted) return;
        setState(() => _frames[i].bytes = Uint8List.fromList(res.data!));
      } catch (_) {
        // 404 of netwerk — frame blijft leeg en wordt overgeslagen in de build.
      }
    }
  }

  void _startAnimation() {
    _timer?.cancel();
    _timer = Timer.periodic(_animDuration, (_) async {
      if (!mounted || _frames.isEmpty) return;
      var next = (_currentFrame + 1) % _frames.length;
      // sla frames zonder beeld over
      var guard = 0;
      while (_frames[next].bytes == null && guard < _frames.length) {
        next = (next + 1) % _frames.length;
        guard++;
      }
      if (guard >= _frames.length) return;
      setState(() => _currentFrame = next);
      if (_currentFrame % 3 == 0) _preloadNeighborhood(_currentFrame);
    });
  }

  void _togglePlay() {
    if (_playing) {
      _timer?.cancel();
      _timer = null;
    } else {
      _startAnimation();
    }
    setState(() => _playing = !_playing);
  }

  void _jumpToFrame(int index) {
    _timer?.cancel();
    _timer = null;
    setState(() {
      _currentFrame = index.clamp(0, _frames.length - 1);
      _playing = false;
    });
    _preloadNeighborhood(_currentFrame);
  }

  String _formatClock(DateTime dt) {
    final local = dt.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  String _formatRelative(DateTime dt) {
    final diff = dt.difference(DateTime.now().toUtc());
    final mins = diff.inMinutes;
    if (mins.abs() < 3) return 'nu';
    if (mins < 0) return '${-mins} min geleden';
    return 'over ${((mins + 2) ~/ 5) * 5} min';
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

    if (_error != null || _frames.isEmpty) {
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
                const Text('Radar niet beschikbaar', style: TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                if (_error != null)
                  Text(_error!, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withAlpha(150)), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    setState(() => _loading = true);
                    _fetchManifest();
                  },
                  child: const Text('Opnieuw proberen'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final frame = _frames[_currentFrame];
    final isNewest = frame.offsetMin <= 0 && _currentFrame == _frames.lastIndexWhere((f) => f.offsetMin <= 0);
    final isForecast = frame.offsetMin > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Neerslagkaart'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _loading = true);
              _fetchManifest();
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
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.danield.weerapp',
                    ),
                    if (frame.bytes != null)
                      OverlayImageLayer(
                        overlayImages: [
                          OverlayImage(
                            key: ValueKey(frame.path),
                            imageProvider: MemoryImage(frame.bytes!),
                            bounds: LatLngBounds(_boundsSWNE[0], _boundsSWNE[1]),
                            gaplessPlayback: true,
                          ),
                        ],
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
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withAlpha(230),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isForecast
                                ? Icons.online_prediction
                                : isNewest
                                    ? Icons.my_location
                                    : Icons.history,
                            size: 16,
                            color: isForecast
                                ? const Color(0xFFB388FF)
                                : isNewest
                                    ? const Color(0xFF4CAF50)
                                    : theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${_formatClock(frame.time)} — ${_formatRelative(frame.time)}',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
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
                        onTap: _togglePlay,
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
                                    Positioned(
                                      left: 0,
                                      top: 14,
                                      bottom: 14,
                                      width: (_currentFrame / (_frames.length - 1)) * barWidth,
                                      child: Container(
                                        decoration: BoxDecoration(color: theme.colorScheme.primary.withAlpha(60), borderRadius: BorderRadius.circular(2)),
                                      ),
                                    ),
                                    AnimatedPositioned(
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeOut,
                                      left: ((_currentFrame / (_frames.length - 1)) * barWidth - 8).clamp(0.0, barWidth - 16),
                                      top: 8,
                                      child: Container(
                                        width: 16,
                                        height: 16,
                                        decoration: BoxDecoration(
                                          color: isForecast
                                              ? const Color(0xFFB388FF)
                                              : isNewest
                                                  ? const Color(0xFF4CAF50)
                                                  : theme.colorScheme.primary,
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
                      Text(_formatClock(_frames.first.time), style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface.withAlpha(120))),
                      Text('-2u · nu · +2u (DWD nowcast)', style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface.withAlpha(120))),
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

  void _showInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Neerslagkaart'),
        content: const Text(
          'Neerslag-radar van de afgelopen 2 uur én de verwachting voor de komende 2 uur:\n\n'
          '• Elke 5 minuten een frame (DWD radar-nowcast)\n'
          '• Paars icoon = verwachting, groen = live-beeld\n'
          '• Sleep de balk om naar een specifiek tijdstip te gaan\n\n'
          'Data: DWD (GeoServer) via eigen proxy + OpenStreetMap (kaart)',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Sluiten')),
        ],
      ),
    );
  }
}