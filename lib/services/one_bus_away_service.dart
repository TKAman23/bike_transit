import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:bike_transit/constants/app_config.dart';
import 'package:bike_transit/models/route_option.dart';
import 'package:bike_transit/services/api_client.dart';
import 'package:bike_transit/utils/geo.dart';

/// Puget Sound One Bus Away REST API. Used to enrich Google transit legs with
/// real-time departure predictions and the full list of stops ridden.
///
/// Every call is best-effort: when OBA is unconfigured, rate-limited or can't
/// match a trip, the Google schedule data is kept unchanged.
class OneBusAwayService {
  OneBusAwayService({ApiClient? client}) : _api = client ?? ApiClient();

  final ApiClient _api;
  DateTime _nextCallAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// Minimum spacing between calls; the shared TEST key rejects bursts (HTTP 429).
  static const _spacing = Duration(milliseconds: 700);

  bool get isConfigured => AppConfig.hasObaKey;

  static String _norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  Future<Map<String, dynamic>?> _get(String path, Map<String, String> query) async {
    final uri = Uri.parse('${AppConfig.obaBaseUrl}/$path.json')
        .replace(queryParameters: {'key': AppConfig.obaApiKey, ...query});
    // The shared development key is throttled; one retry after a pause.
    for (var attempt = 0; attempt < 2; attempt++) {
      final wait = _nextCallAt.difference(DateTime.now());
      if (!wait.isNegative) await Future<void>.delayed(wait);
      _nextCallAt = DateTime.now().add(_spacing);
      try {
        final json = await _api.getJson(uri);
        if (json['code'] == 200 && json['data'] is Map) {
          return Map<String, dynamic>.from(json['data'] as Map);
        }
      } catch (e) {
        debugPrint('OBA $path failed: $e');
      }
      _nextCallAt = DateTime.now().add(const Duration(seconds: 2));
    }
    return null;
  }

  Future<TransitInfo?> enrich(TransitInfo leg) async {
    if (!isConfigured) return null;
    final target = _norm(leg.routeShortName);

    // 1. Find the OBA stop matching Google's boarding stop.
    final near = await _get('stops-for-location', {
      'lat': '${leg.departureStop.location.latitude}',
      'lon': '${leg.departureStop.location.longitude}',
      'radius': '150',
    });
    if (near == null) return null;
    final routeNames = <String, String>{
      for (final r in ((near['references'] as Map?)?['routes'] as List? ?? const []))
        '${(r as Map)['id']}': _norm('${r['shortName'] ?? r['longName'] ?? ''}'),
    };
    final candidates = <(String, double)>[];
    for (final s in (near['list'] as List? ?? const [])) {
      final m = s as Map;
      final ids = [for (final id in (m['routeIds'] as List? ?? const [])) '$id'];
      if (!ids.any((id) => routeNames[id] == target)) continue;
      final loc = LatLng((m['lat'] as num).toDouble(), (m['lon'] as num).toDouble());
      candidates.add(('${m['id']}', Geo.distance(loc, leg.departureStop.location)));
    }
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => a.$2.compareTo(b.$2));

    // 2. Find the departure that Google scheduled.
    for (final (stopId, _) in candidates.take(2)) {
      final arrivals = await _get('arrivals-and-departures-for-stop/$stopId', {
        'minutesBefore': '2',
        'minutesAfter': '120',
      });
      final list = ((arrivals?['entry'] as Map?)?['arrivalsAndDepartures'] as List?) ?? const [];
      Map? best;
      var bestDelta = const Duration(minutes: 10);
      for (final a in list) {
        final m = a as Map;
        if (_norm('${m['routeShortName']}') != target) continue;
        final sched = DateTime.fromMillisecondsSinceEpoch(
            (m['scheduledDepartureTime'] as num).toInt());
        final delta = sched.difference(leg.departureTime).abs();
        if (delta <= bestDelta) {
          bestDelta = delta;
          best = m;
        }
      }
      if (best == null) continue;
      final predictedMs = (best['predictedDepartureTime'] as num?)?.toInt() ?? 0;
      final isLive = best['predicted'] == true && predictedMs > 0;
      final trip = await _tripStops(
        '${best['tripId']}',
        stopId,
        leg.arrivalStop.location,
      );
      if (trip == null) continue;
      final (stops, deviation) = trip;
      final shift = isLive ? deviation : Duration.zero;
      final shifted = [
        for (final s in stops)
          TransitStop(name: s.name, location: s.location, time: s.time?.add(shift)),
      ];
      return leg.copyWith(
        stops: shifted,
        departureTime: isLive
            ? DateTime.fromMillisecondsSinceEpoch(predictedMs)
            : shifted.first.time,
        arrivalTime: shifted.last.time,
        realtime: isLive,
      );
    }
    return null;
  }

  /// Stops from [fromStopId] to the stop nearest [alightAt], with times, plus
  /// the vehicle's current schedule deviation.
  Future<(List<TransitStop>, Duration)?> _tripStops(
    String tripId,
    String fromStopId,
    LatLng alightAt,
  ) async {
    final data = await _get('trip-details/$tripId', {
      'includeSchedule': 'true',
      'includeStatus': 'true',
    });
    final entry = data?['entry'] as Map?;
    if (entry == null) return null;
    final stopRefs = <String, Map>{
      for (final s in ((data!['references'] as Map?)?['stops'] as List? ?? const []))
        '${(s as Map)['id']}': s,
    };
    final stopTimes = ((entry['schedule'] as Map?)?['stopTimes'] as List?) ?? const [];
    final serviceDate = DateTime.fromMillisecondsSinceEpoch(
        (entry['serviceDate'] as num?)?.toInt() ?? 0);
    final deviation = Duration(
        seconds: (((entry['status'] as Map?)?['scheduleDeviation'] as num?) ?? 0).toInt());

    final from = stopTimes.indexWhere((t) => '${(t as Map)['stopId']}' == fromStopId);
    if (from < 0) return null;
    var to = -1;
    var bestDist = 250.0;
    for (var i = from + 1; i < stopTimes.length; i++) {
      final ref = stopRefs['${(stopTimes[i] as Map)['stopId']}'];
      if (ref == null) continue;
      final d = Geo.distance(
          LatLng((ref['lat'] as num).toDouble(), (ref['lon'] as num).toDouble()), alightAt);
      if (d < bestDist) {
        bestDist = d;
        to = i;
      }
    }
    if (to < 0) return null;
    final stops = <TransitStop>[];
    for (var i = from; i <= to; i++) {
      final t = stopTimes[i] as Map;
      final ref = stopRefs['${t['stopId']}'];
      if (ref == null) continue;
      stops.add(TransitStop(
        name: '${ref['name']}',
        location: LatLng((ref['lat'] as num).toDouble(), (ref['lon'] as num).toDouble()),
        time: serviceDate.add(Duration(seconds: (t['arrivalTime'] as num).toInt())),
      ));
    }
    return stops.length < 2 ? null : (stops, deviation);
  }
}
