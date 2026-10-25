import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/weather.dart';
import '../services/knmi_nowcast_service.dart';
import '../services/saved_locations_service.dart';
import '../widgets/buien_card.dart';

/// Neerslagkaart met de KNMI-nowcast (toekomst-neerslag, +0 tot +120 min).
///
/// Haalt de 25 voorspelling-frames op van de tile-server (Route A), toont ze
/// als animatie over de OSM-kaart met een tijdlijn-scrubber. De Open-Meteo
/// uurlijkse verwachting (12u) blijft als extra onderaan staan.
class RainRadarScreen extends StatefulWidget {
  final SavedLocation location;
  final List<HourlyForecast>? hourlyForecast;
  final String serverBaseUrl;

  const RainRadarScreen({
    super.key,
    required this.location,
    this.hourlyForecast,
    this.serverBaseUrl = 'http://62.169.21.47:8090',
  });

  @override
  State<RainRadarScreen> createState() => _RainRadarScreenState();
}

class _NowcastFrame {
  final Uint8List bytes;
  final DateTime time; // 'nu' + (index * 5 min)
  _NowcastFrame({required this.bytes, required this.time});
}

class _RainRadarScreenState extends State<RainRadarScreen> {
  final MapController _mapController = MapController();

  KnmiNowcastMeta? _meta;
  List<_NowcastFrame> _frames = [];
  int _currentFrame = 0;
  Timer? _timer;
  bool _playing = true;
  bool _loading = true;
  String? _error;

  static const _animDuration = Duration(milliseconds: 400);

  @override
  void initState() {
    super.initState();
    _fetchNowcast();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _fetchNowcast() async {
    final service = KnmiNowcastService(baseUrl: widget.serverBaseUrl);
    try {
      final meta = await service.fetchMeta();
      if (!mounted) return;

      final now = DateTime.now();
      final frames = <_NowcastFrame>[];
      for (var i = 1; i <= meta.frames; i++) {
        final bytes = await service.fetchFrame(i);
        frames.add(_NowcastFrame(
          bytes: bytes,
          time: now.add(Duration(minutes: (i - 1) * 5)),
        ));
      }

      if (!mounted) return;
      setState(() {
        _meta = meta;
        _frames = frames;
        _loading = false;
      });
      _startAnimation();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
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
  }

  double get _progress {
    if (_frames.length <= 1) return 1.0;
    return _currentFrame / (_frames.length - 1);
  }

  String _formatRelative(DateTime dt) {
    final diff = dt.difference(DateTime.now());
    final mins = diff.inMinutes;
    if (mins.abs() < 5) return 'nu';
    if (mins < 0) return '${-mins} min geleden';
    return '+$mins min';
  }

  String _formatClock(DateTime dt) {
    final local = dt.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  /// Uurlijkse voorspelling voor de komende [hours] uur (vanaf het huidige uur).
  List<HourlyForecast> _nextHours(int hours) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day, now.hour);
    final end = start.add(Duration(hours: hours));
    return widget.hourlyForecast!
        .where((h) => !h.time.isBefore(start) && h.time.isBefore(end))
        .toList();
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
                    _fetchNowcast();
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
    final meta = _meta!;
    final isNow = _currentFrame == 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Neerslagkaart'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _loading = true);
              _fetchNowcast();
            },
            tooltip: 'Vernieuwen',
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
                    // KNMI-nowcast overlay (toekomst-neerslag, +0..+120 min).
                    OverlayImageLayer(
                      overlayImages: [
                        OverlayImage(
                          imageProvider: MemoryImage(frame.bytes),
                          bounds: LatLngBounds(
                            LatLng(meta.north, meta.west),
                            LatLng(meta.south, meta.east),
                          ),
                          opacity: 0.7,
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
                // Tijd-label
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
                            isNow ? Icons.my_location : Icons.trending_up,
                            size: 16,
                            color: isNow ? const Color(0xFF4CAF50) : const Color(0xFFFFB300),
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
          // Open-Meteo uurlijkse verwachting (12u) als extra.
          if (widget.hourlyForecast != null && widget.hourlyForecast!.isNotEmpty)
            Flexible(
              flex: 1,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: BuienCard(nextHours: _nextHours(12)),
                ),
              ),
            ),
          // Bediening — tijdlijn-scrubber
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
                                      left: _progress * barWidth,
                                      top: 14,
                                      bottom: 14,
                                      right: 0,
                                      child: Container(
                                        decoration: BoxDecoration(color: theme.colorScheme.primary.withAlpha(60), borderRadius: BorderRadius.circular(2)),
                                      ),
                                    ),
                                    AnimatedPositioned(
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeOut,
                                      left: (_progress * barWidth - 8).clamp(0.0, barWidth - 16),
                                      top: 8,
                                      child: Container(
                                        width: 16,
                                        height: 16,
                                        decoration: BoxDecoration(
                                          color: isNow ? const Color(0xFF4CAF50) : const Color(0xFFFFB300),
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
                      Text('nu', style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface.withAlpha(120))),
                      Text('+2 uur', style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface.withAlpha(120))),
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
}
