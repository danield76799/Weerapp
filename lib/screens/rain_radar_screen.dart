import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/weather.dart';
import '../services/saved_locations_service.dart';
import '../widgets/buien_card.dart';

/// Neerslagkaart met echte radar-beelden van RainViewer (gratis API, geen key).
/// Toont de afgelopen 2 uur radar + de neerslagvoorspelling (nowcast) als
/// animatie met 10-min-intervallen, als tile-layer over de kaart.
class RainRadarScreen extends StatefulWidget {
  final SavedLocation location;
  final List<HourlyForecast>? hourlyForecast;
  const RainRadarScreen({
    super.key,
    required this.location,
    this.hourlyForecast,
  });

  @override
  State<RainRadarScreen> createState() => _RainRadarScreenState();
}

class _RadarFrame {
  final DateTime time;
  final String path; // bijv. /v2/radar/1134a9702115
  _RadarFrame({required this.time, required this.path});
}

class _RainRadarScreenState extends State<RainRadarScreen> {
  final MapController _mapController = MapController();
  final Dio _dio = Dio();

  List<_RadarFrame> _frames = [];
  int _currentFrame = 0;
  int _nowIndex = 0; // index van het 'nu'-moment (grens verleden ↔ voorspelling)
  Timer? _timer;
  bool _playing = true;
  bool _loading = true;
  String? _error;
  String? _tileHost;

  static const _animDuration = Duration(milliseconds: 700);

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
      final response = await _dio.get<Map<String, dynamic>>(
        'https://api.rainviewer.com/public/weather-maps.json',
        options: Options(receiveTimeout: const Duration(seconds: 15)),
      );
      final data = response.data!;
      final host = data['host'] as String? ?? 'https://tilecache.rainviewer.com';
      final radar = data['radar'] as Map<String, dynamic>? ?? {};
      final past = radar['past'] as List<dynamic>? ?? [];
      final nowcast = radar['nowcast'] as List<dynamic>? ?? [];

      _RadarFrame parseFrame(dynamic item) => _RadarFrame(
            time: DateTime.fromMillisecondsSinceEpoch(
              (item['time'] as int) * 1000,
              isUtc: true,
            ),
            path: item['path'] as String,
          );

      final frames = <_RadarFrame>[];
      for (final item in past) {
        frames.add(parseFrame(item));
      }
      final nowIndex = frames.length - 1; // laatste observatie = 'nu'
      for (final item in nowcast) {
        frames.add(parseFrame(item));
      }

      if (frames.isEmpty) {
        if (!mounted) return;
        setState(() {
          _error = 'Geen radar-beelden beschikbaar';
          _loading = false;
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _tileHost = host;
        _frames = frames;
        _nowIndex = nowIndex;
        _currentFrame = nowIndex >= 0 ? nowIndex : 0; // start op 'nu'
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

  String _tileUrl(_RadarFrame frame) =>
      '$_tileHost${frame.path}/256/{z}/{x}/{y}/2/1_1.png';

  void _startAnimation() {
    _timer?.cancel();
    _timer = Timer.periodic(_animDuration, (_) {
      if (!mounted) return;
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

  String _formatClock(DateTime dt) {
    final local = dt.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  String _formatRelative(DateTime dt) {
    final diff = dt.difference(DateTime.now().toUtc());
    final mins = diff.inMinutes;
    if (mins.abs() < 5) return 'nu';
    if (mins < 0) return '${-mins} min geleden';
    return 'over $mins min';
  }

  /// Voortgang (0..1) van de huidige frame over de tijdlijn.
  /// Guard tegen delen door nul wanneer er maar één frame is.
  double get _progress {
    if (_frames.length <= 1) return 1.0;
    return _currentFrame / (_frames.length - 1);
  }

  bool get _isNowFrame => _currentFrame == _nowIndex;
  bool get _isFutureFrame => _currentFrame > _nowIndex;

  /// Voortgang (0..1) van het 'nu'-moment over de tijdlijn.
  double get _nowProgress {
    if (_frames.length <= 1) return 1.0;
    final idx = _nowIndex < 0 ? 0 : _nowIndex;
    return idx / (_frames.length - 1);
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
                    _fetchRadarFrames();
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Neerslagkaart'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _loading = true);
              _fetchRadarFrames();
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
                    // Echte radar-tiles — elke frame is een eigen layer.
                    // RainViewer's gratis tiles stoppen bij zoom 7 (was 10 in
                    // jul 2026); boven native zoom schaalt flutter_map de
                    // tiles op i.p.v. de "Zoom Level Not Supported"-tegel.
                    TileLayer(
                      key: ValueKey(frame.path),
                      urlTemplate: _tileUrl(frame),
                      userAgentPackageName: 'com.danield.weerapp',
                      tileProvider: NetworkTileProvider(),
                      maxNativeZoom: 7,
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
                            _isFutureFrame
                                ? Icons.trending_up
                                : _isNowFrame
                                    ? Icons.my_location
                                    : Icons.history,
                            size: 16,
                            color: _isFutureFrame
                                ? const Color(0xFFFFB300)
                                : _isNowFrame
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
          // Neerslagverwachting (future) — Open-Meteo uurlijkse voorspelling.
          // RainViewer's gratis nowcast is gestopt, dus de radar toont alleen
          // het verleden; de toekomst komt uit Open-Meteo (geen key nodig).
          if (widget.hourlyForecast != null && widget.hourlyForecast!.isNotEmpty)
            Flexible(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: BuienCard(nextHours: widget.hourlyForecast!),
                ),
              ),
            ),
          // Bediening — vaste footer onder de kaart, geen overflow.
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
                                    // Marker van het 'nu'-moment (grens verleden ↔ voorspelling)
                                    Positioned(
                                      left: (_nowProgress * barWidth - 1).clamp(0.0, barWidth - 2),
                                      top: 6,
                                      bottom: 6,
                                      child: Container(
                                        width: 2,
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.onSurface.withAlpha(180),
                                          borderRadius: BorderRadius.circular(1),
                                        ),
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
                                          color: _isFutureFrame
                                              ? const Color(0xFFFFB300)
                                              : _isNowFrame
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
                      Text(_formatClock(_frames.last.time), style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface.withAlpha(120))),
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
          'Deze kaart toont echte radar-beelden van de afgelopen 2 uur + de neerslagvoorspelling:\n\n'
          '• De animatie speelt verleden → nu → voorspelling\n'
          '• Gekleurde marker = jouw locatie · witte lijn = nu · oranje = voorspelling\n'
          '• Sleep de balk om naar een specifiek tijdstip te gaan\n\n'
          'Data: RainViewer (radar + nowcast) + OpenStreetMap (kaart)',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Sluiten')),
        ],
      ),
    );
  }
}