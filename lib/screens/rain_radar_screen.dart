import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/saved_locations_service.dart';

/// Neerslagkaart met echte radar-beelden van RainViewer (gratis API, geen key).
/// Toont de afgelopen 2 uur radar als animatie met 10-min-intervallen,
/// als tile-layer over de kaart — geen cirkels, geen interpolatie.
class RainRadarScreen extends StatefulWidget {
  final SavedLocation location;
  const RainRadarScreen({super.key, required this.location});

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
  Timer? _timer;
  bool _playing = true;
  bool _loading = true;
  String? _error;
  String? _tileHost;

  // Neerslagverwachting per kwartier (+2u) uit Open-Meteo.
  List<({DateTime time, double mm})> _forecast = [];

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

      final frames = <_RadarFrame>[];
      for (final item in past) {
        frames.add(_RadarFrame(
          time: DateTime.fromMillisecondsSinceEpoch(
            (item['time'] as int) * 1000,
            isUtc: true,
          ),
          path: item['path'] as String,
        ));
      }

      if (frames.isEmpty) {
        setState(() {
          _error = 'Geen radar-beelden beschikbaar';
          _loading = false;
        });
        return;
      }

      setState(() {
        _tileHost = host;
        _frames = frames;
        _currentFrame = frames.length - 1; // start op het nieuwste beeld
        _loading = false;
      });
      _startAnimation();
      _fetchForecast(); // asynchroon: balk verschijnt zodra klaar
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _fetchForecast() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'https://api.open-meteo.com/v1/forecast',
        queryParameters: {
          'latitude': widget.location.lat,
          'longitude': widget.location.lon,
          'minutely_15': 'precipitation',
          'forecast_minutely_15': '8',
          'past_minutely_15': '1',
          'timezone': 'auto',
        },
        options: Options(receiveTimeout: const Duration(seconds: 15)),
      );
      final m15 = response.data?['minutely_15'] as Map<String, dynamic>?;
      final times = m15?['time'] as List<dynamic>? ?? [];
      final vals = m15?['precipitation'] as List<dynamic>? ?? [];
      // past=1 geeft één slot vóór "nu" (kwartier waar we al in zitten).
      final now = DateTime.now();
      final list = <({DateTime time, double mm})>[];
      for (var i = 0; i < times.length; i++) {
        final t = DateTime.parse(times[i] as String);
        if (t.isBefore(now.subtract(const Duration(minutes: 20)))) continue;
        if (list.length >= 8) break;
        list.add((time: t, mm: (vals[i] as num?)?.toDouble() ?? 0.0));
      }
      if (mounted) setState(() => _forecast = list);
    } catch (_) {
      // Forecast is een bonus — faal stil.
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
    final isNewest = _currentFrame == _frames.length - 1;

    // Alle frames als eigen TileLayer stapelen; alleen het actieve frame is
    // zichtbaar. Tiles worden één keer geladen en blijven in de cache —
    // de frame-wissel is nu een instantswap zonder herlaad-flikker.
    final radarLayers = <Widget>[
      for (var i = 0; i < _frames.length; i++)
        AnimatedOpacity(
          key: ValueKey(_frames[i].path),
          duration: const Duration(milliseconds: 250),
          opacity: i == _currentFrame ? 1.0 : 0.0,
          child: TileLayer(
            urlTemplate: _tileUrl(_frames[i]),
            userAgentPackageName: 'com.danield.weerapp',
            tileProvider: NetworkTileProvider(),
            // RainViewer's gratis tiles stoppen bij zoom 7 (was 10 in jul
            // 2026); boven native zoom schaalt flutter_map de tiles op
            // i.p.v. de "Zoom Level Not Supported"-tegel te tonen.
            maxNativeZoom: 7,
          ),
        ),
    ];

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
                    // Gestapelde radar-frames — alleen actieve zichtbaar.
                    ...radarLayers,
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
                            isNewest ? Icons.my_location : Icons.history,
                            size: 16,
                            color: isNewest ? const Color(0xFF4CAF50) : theme.colorScheme.primary,
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
                                      left: (_currentFrame / (_frames.length - 1)) * barWidth,
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
                                      left: ((_currentFrame / (_frames.length - 1)) * barWidth - 8).clamp(0.0, barWidth - 16),
                                      top: 8,
                                      child: Container(
                                        width: 16,
                                        height: 16,
                                        decoration: BoxDecoration(
                                          color: isNewest ? const Color(0xFF4CAF50) : theme.colorScheme.primary,
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
                      Text('-2u · nu', style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface.withAlpha(120))),
                    ],
                  ),
                  // Neerslagverwachting +2u (Open-Meteo, per kwartier).
                  if (_forecast.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 56,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (final slot in _forecast)
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (slot.mm > 0)
                                    Text(
                                      slot.mm >= 1 ? slot.mm.toStringAsFixed(1) : '<0.1',
                                      style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface.withAlpha(160)),
                                    ),
                                  const SizedBox(height: 2),
                                  Container(
                                    height: 4.0 + (slot.mm.clamp(0.0, 4.0) / 4.0) * 28.0,
                                    decoration: BoxDecoration(
                                      color: slot.mm <= 0
                                          ? theme.colorScheme.onSurface.withAlpha(30)
                                          : Colors.blue.withAlpha(slot.mm < 0.5 ? 90 : slot.mm < 2.5 ? 160 : 255),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _formatClock(slot.time),
                                    style: TextStyle(fontSize: 8, color: theme.colorScheme.onSurface.withAlpha(120)),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'verwachting +2u · Open-Meteo',
                        style: TextStyle(fontSize: 9, color: theme.colorScheme.onSurface.withAlpha(110)),
                      ),
                    ),
                  ],
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
          'Deze kaart toont echte radar-beelden van de afgelopen 2 uur:\n\n'
          '• De animatie speelt alle radar-beelden van de afgelopen 2 uur achter elkaar\n'
          '• Groene stip = jouw locatie\n'
          '• Sleep de balk om naar een specifiek tijdstip te gaan\n\n'
          'Data: RainViewer (radar) + OpenStreetMap (kaart)',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Sluiten')),
        ],
      ),
    );
  }
}