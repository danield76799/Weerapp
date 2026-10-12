import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/saved_locations_service.dart';

/// Neerslagkaart via RainViewer (https://www.rainviewer.com/).
///
/// Gratis, geen API-key, HTTPS, wereldwijd (incl. NL). De service levert elk
/// 10 minuten een manifest met radar-frames (verleden ~2u + nowcast ~30 min).
/// Elke frame is een wereldwijde tegel-set; we tonen één TileLayer per moment
/// en wisselen via een Timer, net als de oude DWD-proxy-versie.
///
/// Manifest: https://api.rainviewer.com/public/weather-maps.json
/// Tegel-URL: {host}{path}/{size}/{z}/{x}/{y}/{color}/{smooth}{snow}.png
class RainRadarScreen extends StatefulWidget {
  final SavedLocation location;
  const RainRadarScreen({super.key, required this.location});

  @override
  State<RainRadarScreen> createState() => _RainRadarScreenState();
}

class _RainViewerFrame {
  final DateTime time;
  final String path;
  final int offsetMin;
  _RainViewerFrame({
    required this.time,
    required this.path,
    required this.offsetMin,
  });
}

class _RainRadarScreenState extends State<RainRadarScreen> {
  static const _apiUrl = 'https://api.rainviewer.com/public/weather-maps.json';
  static const _animDuration = Duration(milliseconds: 700);

  final MapController _mapController = MapController();
  final Dio _dio = Dio();

  String _tileHost = 'https://tilecache.rainviewer.com';
  List<_RainViewerFrame> _frames = [];
  int _currentFrame = 0;
  Timer? _timer;
  bool _playing = true;
  bool _loading = true;
  String? _error;

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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _dio
          .get<Map<String, dynamic>>(
        _apiUrl,
        options: Options(
          receiveTimeout: const Duration(seconds: 8),
          sendTimeout: const Duration(seconds: 8),
        ),
      )
          .timeout(const Duration(seconds: 10));

      final data = res.data!;
      final host = data['host'] as String?;
      if (host != null && host.isNotEmpty) _tileHost = host;

      final radar = data['radar'] as Map<String, dynamic>?;
      final past = (radar?['past'] as List<dynamic>?) ?? const [];
      final nowcast = (radar?['nowcast'] as List<dynamic>?) ?? const [];

      final nowSec = (data['generated'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch ~/ 1000;

      final frames = <_RainViewerFrame>[];
      for (final item in past) {
        final f = item as Map<String, dynamic>;
        final ts = (f['time'] as num).toInt();
        frames.add(_RainViewerFrame(
          time: DateTime.fromMillisecondsSinceEpoch(ts * 1000),
          path: f['path'] as String,
          offsetMin: ((ts - nowSec) / 60).round(),
        ));
      }
      for (final item in nowcast) {
        final f = item as Map<String, dynamic>;
        final ts = (f['time'] as num).toInt();
        frames.add(_RainViewerFrame(
          time: DateTime.fromMillisecondsSinceEpoch(ts * 1000),
          path: f['path'] as String,
          offsetMin: ((ts - nowSec) / 60).round(),
        ));
      }

      if (frames.isEmpty) {
        setState(() {
          _error = 'Geen radar-frames in het manifest.';
          _loading = false;
        });
        return;
      }

      // Start op het laatste verleden-frame (meest actuele radarbeelden).
      var startIdx = frames.lastIndexWhere((f) => f.offsetMin <= 0);
      if (startIdx < 0) startIdx = 0;

      setState(() {
        _frames = frames;
        _currentFrame = startIdx;
        _loading = false;
      });
      _startAnimation();
    } catch (e) {
      final detail = e is DioException
          ? (e.type == DioExceptionType.connectionTimeout ||
                  e.type == DioExceptionType.receiveTimeout ||
                  e.type == DioExceptionType.sendTimeout
              ? 'tijdens het laden (timeout)'
              : 'HTTP-fout ${e.response?.statusCode ?? '-'}')
          : '$e';
      setState(() {
        _error = 'RainViewer onbereikbaar $detail.';
        _loading = false;
      });
    }
  }

  void _startAnimation() {
    _timer?.cancel();
    _timer = Timer.periodic(_animDuration, (_) {
      if (!mounted || _frames.isEmpty) return;
      setState(() {
        _currentFrame = (_currentFrame + 1) % _frames.length;
      });
    });
  }

  void _togglePlay() {
    if (_playing) {
      _timer?.cancel();
      _timer = null;
      setState(() => _playing = false);
    } else {
      _startAnimation();
      setState(() => _playing = true);
    }
  }

  void _jumpToFrame(int idx) {
    _timer?.cancel();
    _timer = null;
    setState(() {
      _currentFrame = idx.clamp(0, _frames.length - 1);
      _playing = false;
    });
    // Hervat de animatie na 3s stilstand.
    Timer(const Duration(seconds: 3), () {
      if (mounted && !_playing) {
        _startAnimation();
        setState(() => _playing = true);
      }
    });
  }

  String _formatClock(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatRelative(DateTime t) {
    final diff = t.difference(DateTime.now());
    final minutes = diff.inMinutes;
    if (minutes.abs() < 5) return 'nu';
    if (minutes < 0) return '${minutes.abs()} min geleden';
    return 'over $minutes min';
  }

  @override
  Widget build(BuildContext context) {
    final center = LatLng(widget.location.lat, widget.location.lon);

    if (_loading && _frames.isEmpty) {
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
                Icon(Icons.cloud_off,
                    size: 48,
                    color: Theme.of(context).colorScheme.onSurface.withAlpha(120)),
                const SizedBox(height: 16),
                const Text('Radar niet beschikbaar',
                    style: TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withAlpha(150)),
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _fetchManifest,
                  child: const Text('Opnieuw proberen'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final frame = _frames[_currentFrame];
    final newestPastIdx = _frames.lastIndexWhere((f) => f.offsetMin <= 0);
    final isNewest = _currentFrame == newestPastIdx;
    final isForecast = frame.offsetMin > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Neerslagkaart'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchManifest,
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
                    initialZoom: 7,
                    minZoom: 4,
                    maxZoom: 12,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.danield.weerapp',
                    ),
                    // RainViewer overlaid één frame per moment via de
                    // standaard TileLayer — geen handmatige PNG-preload:
                    // de kaart-cache regelt buffering zelf.
                    TileLayer(
                      urlTemplate:
                          '$_tileHost${frame.path}/256/{z}/{x}/{y}/2/1_1.png',
                      userAgentPackageName: 'com.danield.weerapp',
                      tileProvider: NetworkTileProvider(),
                      panBuffer: 0,
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: center,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color:
                                      Theme.of(context).colorScheme.onPrimary,
                                  width: 2),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withAlpha(100),
                                    blurRadius: 4)
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
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surface
                            .withAlpha(230),
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
                                    : Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${_formatClock(frame.time)} — ${_formatRelative(frame.time)}',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color:
                                    Theme.of(context).colorScheme.onSurface),
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
                color:
                    Theme.of(context).colorScheme.surface.withAlpha(230),
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
                          decoration: BoxDecoration(
                              color:
                                  Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle),
                          child: Icon(
                              _playing ? Icons.pause : Icons.play_arrow,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimary,
                              size: 20),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final barWidth = constraints.maxWidth;
                            return GestureDetector(
                              onTapDown: (details) {
                                final ratio = (details.localPosition.dx /
                                        barWidth)
                                    .clamp(0.0, 1.0);
                                _jumpToFrame(
                                    (ratio * (_frames.length - 1)).round());
                              },
                              child: SizedBox(
                                height: 32,
                                child: Stack(
                                  alignment: Alignment.centerLeft,
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.only(
                                          top: 14, bottom: 14),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withAlpha(40),
                                        borderRadius:
                                            BorderRadius.circular(2),
                                      ),
                                    ),
                                    Positioned(
                                      left: 0,
                                      top: 14,
                                      bottom: 14,
                                      width: (_currentFrame /
                                              (_frames.length - 1)) *
                                          barWidth,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withAlpha(60),
                                          borderRadius:
                                              BorderRadius.circular(2),
                                        ),
                                      ),
                                    ),
                                    AnimatedPositioned(
                                      duration: const Duration(
                                          milliseconds: 300),
                                      curve: Curves.easeOut,
                                      left: ((_currentFrame /
                                                  (_frames.length - 1)) *
                                              barWidth -
                                          8)
                                          .clamp(0.0, barWidth - 16),
                                      top: 8,
                                      child: Container(
                                        width: 16,
                                        height: 16,
                                        decoration: BoxDecoration(
                                          color: isForecast
                                              ? const Color(0xFFB388FF)
                                              : isNewest
                                                  ? const Color(0xFF4CAF50)
                                                  : Theme.of(context)
                                                      .colorScheme
                                                      .primary,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .surface,
                                              width: 2),
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
                      Text(
                        _formatClock(_frames.first.time),
                        style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withAlpha(120)),
                      ),
                      Text(
                        'verleden · nu · nowcast (RainViewer)',
                        style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withAlpha(120)),
                      ),
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
          'Neerslag-radar van de afgelopen 2 uur én de verwachting voor de '
          'komende 30-60 minuten:\n\n'
          '• Elke 10 minuten een frame (RainViewer, wereldwijd)\n'
          '• Paars icoon = verwachting, groen = live-beeld\n'
          '• Sleep de balk om naar een specifiek tijdstip te gaan\n\n'
          'Data: RainViewer + OpenStreetMap (kaart)',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Sluiten')),
        ],
      ),
    );
  }
}