import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:bike_transit/constants/app_config.dart';
import 'package:bike_transit/constants/route_constants.dart';
import 'package:bike_transit/models/route_option.dart';
import 'package:bike_transit/services/api_client.dart';
import 'package:bike_transit/services/web_elevation.dart';
import 'package:bike_transit/utils/geo.dart';

/// Google Elevation API: evenly spaced elevation samples along a path.
class ElevationService {
  ElevationService({ApiClient? client}) : _api = client ?? ApiClient();

  final ApiClient _api;

  Future<ElevationProfile?> profile(List<LatLng> path) async {
    if (!AppConfig.hasServicesKey || path.length < 2) return null;
    final length = Geo.pathLength(path);
    final samples = ((length / RouteConstants.elevationSampleSpacingM).ceil() + 1)
        .clamp(2, RouteConstants.maxElevationSamples);
    // Keep the request small; the samples are still spread along the full path.
    final points = Geo.downsample(path, 80);
    final elevations = kIsWeb
        ? await elevationsAlongPathJs(points, samples)
        : await _rest(points, samples);
    final n = elevations.length;
    return ElevationProfile(
      distancesM: [for (var i = 0; i < n; i++) n == 1 ? 0 : length * i / (n - 1)],
      elevationsM: elevations,
    );
  }

  Future<List<double>> _rest(List<LatLng> points, int samples) async {
    final json = await _api.getJson(Uri.parse(AppConfig.elevationUrl).replace(
      queryParameters: {
        'path': 'enc:${Geo.encodePolyline(points)}',
        'samples': '$samples',
        'key': AppConfig.servicesKey,
      },
    ));
    if (json['status'] != 'OK') {
      throw ApiException(
        'Elevation API: ${json['error_message'] ?? json['status']}',
        isConfiguration: json['status'] == 'REQUEST_DENIED',
      );
    }
    return [
      for (final r in json['results'] as List)
        ((r as Map)['elevation'] as num).toDouble(),
    ];
  }
}
