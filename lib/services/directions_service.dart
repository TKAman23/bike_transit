import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:bike_transit/constants/app_config.dart';
import 'package:bike_transit/models/route_option.dart';
import 'package:bike_transit/services/api_client.dart';
import 'package:bike_transit/utils/geo.dart';

enum TravelMode { bicycle, transit, walk }

/// One step of a Google route, normalized.
class GStep {
  GStep({
    required this.mode,
    required this.distanceM,
    required this.duration,
    required this.path,
    required this.start,
    required this.end,
    this.instruction,
    this.maneuver,
    this.transit,
  });

  final TravelMode mode;
  final double distanceM;
  final Duration duration;
  final List<LatLng> path;
  final LatLng start;
  final LatLng end;
  final String? instruction;
  final String? maneuver;
  final TransitInfo? transit;
}

class GRoute {
  GRoute({required this.steps, required this.distanceM, required this.duration});

  final List<GStep> steps;
  final double distanceM;
  final Duration duration;
}

/// Google Routes API (`computeRoutes`) for bicycle, transit and walking legs.
class DirectionsService {
  DirectionsService({ApiClient? client}) : _api = client ?? ApiClient();

  final ApiClient _api;

  static const _fieldMask = 'routes.distanceMeters,routes.duration,'
      'routes.legs.steps.distanceMeters,routes.legs.steps.staticDuration,'
      'routes.legs.steps.polyline.encodedPolyline,'
      'routes.legs.steps.startLocation,routes.legs.steps.endLocation,'
      'routes.legs.steps.navigationInstruction,routes.legs.steps.travelMode,'
      'routes.legs.steps.transitDetails';

  Future<List<GRoute>> compute({
    required LatLng origin,
    required LatLng destination,
    required TravelMode mode,
    bool alternatives = false,
    DateTime? departureTime,
  }) async {
    if (!AppConfig.hasServicesKey) {
      throw ApiException(
        'MAPS_API_KEY / MAPS_SERVICES_KEY is not set. Run with --dart-define-from-file=config/keys.json.',
        isConfiguration: true,
      );
    }
    Map<String, dynamic> waypoint(LatLng p) => {
          'location': {
            'latLng': {'latitude': p.latitude, 'longitude': p.longitude},
          },
        };
    final json = await _api.postJson(
      Uri.parse(AppConfig.routesBaseUrl),
      {
        'origin': waypoint(origin),
        'destination': waypoint(destination),
        'travelMode': switch (mode) {
          TravelMode.bicycle => 'BICYCLE',
          TravelMode.transit => 'TRANSIT',
          TravelMode.walk => 'WALK',
        },
        'computeAlternativeRoutes': alternatives,
        'languageCode': 'en-US',
        if (mode == TravelMode.transit && departureTime != null)
          'departureTime': departureTime.toUtc().toIso8601String(),
      },
      headers: {
        'X-Goog-Api-Key': AppConfig.servicesKey,
        'X-Goog-FieldMask': _fieldMask,
      },
    );
    return [
      for (final r in (json['routes'] as List? ?? const []))
        _parseRoute(r as Map<String, dynamic>),
    ];
  }

  static Duration _seconds(Object? s) {
    if (s is! String || !s.endsWith('s')) return Duration.zero;
    return Duration(
        milliseconds: ((double.tryParse(s.substring(0, s.length - 1)) ?? 0) * 1000).round());
  }

  static LatLng _latLng(Object? loc) {
    final ll = (loc as Map?)?['latLng'] as Map?;
    return LatLng(
      (ll?['latitude'] as num?)?.toDouble() ?? 0,
      (ll?['longitude'] as num?)?.toDouble() ?? 0,
    );
  }

  GRoute _parseRoute(Map<String, dynamic> r) {
    final steps = <GStep>[];
    for (final leg in (r['legs'] as List? ?? const [])) {
      for (final s in ((leg as Map)['steps'] as List? ?? const [])) {
        steps.add(_parseStep(s as Map<String, dynamic>));
      }
    }
    return GRoute(
      steps: steps,
      distanceM: (r['distanceMeters'] as num?)?.toDouble() ?? 0,
      duration: _seconds(r['duration']),
    );
  }

  GStep _parseStep(Map<String, dynamic> s) {
    final encoded = (s['polyline'] as Map?)?['encodedPolyline'] as String?;
    final start = _latLng(s['startLocation']);
    final end = _latLng(s['endLocation']);
    final path = encoded == null ? [start, end] : Geo.decodePolyline(encoded);
    final mode = switch (s['travelMode']) {
      'TRANSIT' => TravelMode.transit,
      'WALK' => TravelMode.walk,
      _ => TravelMode.bicycle,
    };
    final nav = s['navigationInstruction'] as Map?;
    return GStep(
      mode: mode,
      distanceM: (s['distanceMeters'] as num?)?.toDouble() ?? Geo.pathLength(path),
      duration: _seconds(s['staticDuration']),
      path: path,
      start: start,
      end: end,
      instruction: nav?['instructions'] as String?,
      maneuver: nav?['maneuver'] as String?,
      transit: mode == TravelMode.transit
          ? _parseTransit(s['transitDetails'] as Map<String, dynamic>?)
          : null,
    );
  }

  TransitInfo? _parseTransit(Map<String, dynamic>? t) {
    if (t == null) return null;
    final stops = t['stopDetails'] as Map? ?? const {};
    final line = t['transitLine'] as Map? ?? const {};
    TransitStop stop(String key) {
      final m = stops[key] as Map? ?? const {};
      return TransitStop(
        name: m['name'] as String? ?? 'Stop',
        location: _latLng(m['location']),
      );
    }

    final dep = DateTime.tryParse(stops['departureTime'] as String? ?? '') ??
        DateTime.now();
    final arr =
        DateTime.tryParse(stops['arrivalTime'] as String? ?? '') ?? dep;
    final depStop = stop('departureStop');
    final arrStop = stop('arrivalStop');
    final shortName = (line['nameShort'] as String?)?.trim();
    return TransitInfo(
      routeShortName: (shortName == null || shortName.isEmpty)
          ? (line['name'] as String? ?? 'Transit')
          : shortName,
      lineName: line['name'] as String?,
      headsign: t['headsign'] as String?,
      vehicleType: (line['vehicle'] as Map?)?['type'] as String?,
      departureStop: TransitStop(
          name: depStop.name, location: depStop.location, time: dep),
      arrivalStop: TransitStop(
          name: arrStop.name, location: arrStop.location, time: arr),
      departureTime: dep,
      arrivalTime: arr,
      stopCount: (t['stopCount'] as num?)?.toInt() ?? 1,
      stops: [
        TransitStop(name: depStop.name, location: depStop.location, time: dep),
        TransitStop(name: arrStop.name, location: arrStop.location, time: arr),
      ],
    );
  }
}
