import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Metadata over de KNMI nowcast-overlay (bounds + frames).
class KnmiNowcastMeta {
  final int frames;
  final double west;
  final double east;
  final double south;
  final double north;
  final int width;
  final int height;

  const KnmiNowcastMeta({
    required this.frames,
    required this.west,
    required this.east,
    required this.south,
    required this.north,
    required this.width,
    required this.height,
  });

  factory KnmiNowcastMeta.fromJson(Map<String, dynamic> json) {
    final b = json['bounds'] as Map<String, dynamic>? ?? {};
    return KnmiNowcastMeta(
      frames: (json['frames'] as num?)?.toInt() ?? 0,
      west: (b['west'] as num?)?.toDouble() ?? 0,
      east: (b['east'] as num?)?.toDouble() ?? 0,
      south: (b['south'] as num?)?.toDouble() ?? 0,
      north: (b['north'] as num?)?.toDouble() ?? 0,
      width: (json['width'] as num?)?.toInt() ?? 0,
      height: (json['height'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Haalt de KNMI nowcast-frames (PNG) op van de tile-server (Route A).
class KnmiNowcastService {
  final String baseUrl;
  final Dio _dio;

  KnmiNowcastService({required this.baseUrl})
      : _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 20),
        ));

  Future<KnmiNowcastMeta> fetchMeta() async {
    final res = await _dio.get<Map<String, dynamic>>('$baseUrl/meta');
    return KnmiNowcastMeta.fromJson(res.data!);
  }

  Future<Uint8List> fetchFrame(int n) async {
    final res = await _dio.get<List<int>>(
      '$baseUrl/frame/$n.png',
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(res.data!);
  }
}
