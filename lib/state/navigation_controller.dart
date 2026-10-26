import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:bike_transit/constants/route_constants.dart';
import 'package:bike_transit/models/place.dart';
import 'package:bike_transit/models/route_option.dart';
import 'package:bike_transit/models/trip_record.dart';
import 'package:bike_transit/services/location_service.dart';
import 'package:bike_transit/services/ride_telemetry_service.dart';
import 'package:bike_transit/utils/geo.dart';

/// Live en-route state: snaps GPS fixes to the route, tracks the current
/// section/step, collects ride telemetry and reports arrival.
class NavigationController extends ChangeNotifier {
  NavigationController({
    required this.route,
    required this.origin,
    required this.destination,
    required this._location,
    this.onArrived,
  }) {
    var acc = 0.0;
    for (final s in route.sections) {
      _sectionStart.add(acc);
      acc += s.pathLengthM;
    }
    totalM = acc;
  }

  final RouteOption route;
  final Place origin;
  final Place destination;
  final LocationService _location;
  final VoidCallback? onArrived;

  final List<double> _sectionStart = [];
  late final double totalM;
  final DateTime startedAt = DateTime.now();
  final _telemetry = RideTelemetryService();
  StreamSubscription<Position>? _sub;
  Position? _lastFix;

  double progressM = 0;
  int sectionIndex = 0;
  int stepIndex = 0;
  LatLng? position;
  double? headingDeg;
  bool arrived = false;
  String? error;

  RouteSection get section => route.sections[sectionIndex];

  Future<void> start() async {
    if (await _location.ensurePermission() != LocationAccess.granted) {
      error = 'Location access is needed for live navigation.';
      notifyListeners();
      return;
    }
    _listen();
  }

  /// Subscribes to position updates, recovering from transient errors
  /// (browsers in particular report occasional geolocation failures).
  void _listen() {
    _sub?.cancel();
    _sub = _location.positions().listen(
      (fix) {
        if (error != null) error = null;
        update(fix);
      },
      onError: (Object e) {
        error = 'Waiting for GPS signal…';
        notifyListeners();
        _sub?.cancel();
        _retry?.cancel();
        _retry = Timer(const Duration(seconds: 2), () {
          if (!_disposed) _listen();
        });
      },
      cancelOnError: true,
    );
  }

  Timer? _retry;
  bool _disposed = false;

  double sectionStartM(int i) => _sectionStart[i];

  /// Distance travelled within section [i], clamped to its length.
  double progressIn(int i) => (progressM - _sectionStart[i])
      .clamp(0.0, route.sections[i].pathLengthM);

  /// Step offsets are in Google step distances; scale to path meters.
  double stepOffsetOnPath(RouteSection s, NavStep step) =>
      s.distanceM <= 0 ? step.offsetM : step.offsetM * s.pathLengthM / s.distanceM;

  @visibleForTesting
  void update(Position fix) {
    final here = LatLng(fix.latitude, fix.longitude);
    position = here;
    if (fix.heading >= 0 && fix.speed > RouteConstants.movingSpeedMps) {
      headingDeg = fix.heading;
    }

    // Snap to the nearest point of the route near the current progress.
    final from = progressM - RouteConstants.snapLookBackM;
    final to = progressM + RouteConstants.snapLookAheadM;
    var bestAlong = progressM, bestOff = double.infinity;
    for (var i = 0; i < route.sections.length; i++) {
      final s = route.sections[i];
      final start = _sectionStart[i];
      if (start > to || start + s.pathLengthM < from) continue;
      final (along, off) = Geo.project(here, s.path, s.cumulative,
          fromM: from - start, toM: to - start);
      if (off < bestOff) {
        bestOff = off;
        bestAlong = start + along;
      }
    }
    progressM = math.max(progressM, bestAlong);

    while (sectionIndex < route.sections.length - 1 &&
        progressM >= _sectionStart[sectionIndex + 1]) {
      sectionIndex++;
      stepIndex = 0;
    }
    final s = section;
    final local = progressIn(sectionIndex);
    var step = 0;
    for (var i = 0; i < s.steps.length; i++) {
      if (stepOffsetOnPath(s, s.steps[i]) <= local + 15) step = i;
    }
    stepIndex = step;

    // Ride telemetry while on a bike section (NAV-11).
    final last = _lastFix;
    if (s.type == SectionType.bike && last != null) {
      final dt = fix.timestamp.difference(last.timestamp).inMilliseconds / 1000;
      // Trust the reported speed only when it shows movement; otherwise use
      // displacement, but only beyond the fix's accuracy (GPS jitter isn't riding).
      final moved = Geo.distance(LatLng(last.latitude, last.longitude), here);
      final speed = fix.speed >= RouteConstants.movingSpeedMps
          ? fix.speed
          : (dt > 0 && moved > math.max(5.0, fix.accuracy) ? moved / dt : 0.0);
      _telemetry.addSample(
        speedMps: speed,
        grade: s.elevation?.gradeAt(local) ?? 0,
        dtSeconds: dt,
      );
    }
    _lastFix = fix;

    if (!arrived &&
        progressM > totalM * 0.8 &&
        Geo.distance(here, route.sections.last.path.last) <=
            RouteConstants.arrivalRadiusM) {
      arrived = true;
      progressM = totalM;
      onArrived?.call();
    }
    notifyListeners();
  }

  /// Time left in the current section.
  Duration get timeToNextSection {
    final s = section;
    final t = s.transit;
    if (t != null) {
      final left = t.arrivalTime.difference(DateTime.now());
      return left.isNegative ? Duration.zero : left;
    }
    final frac = s.pathLengthM <= 0 ? 1.0 : progressIn(sectionIndex) / s.pathLengthM;
    return s.duration * (1 - frac.clamp(0.0, 1.0));
  }

  Duration get timeRemaining {
    var total = timeToNextSection;
    for (var i = sectionIndex + 1; i < route.sections.length; i++) {
      total += route.sections[i].duration;
    }
    return total;
  }

  DateTime get eta => DateTime.now().add(timeRemaining);

  NavStep? get currentStep =>
      section.steps.isEmpty ? null : section.steps[stepIndex];

  /// The next instruction: the following step, or the next section's first.
  String get nextInstruction {
    final s = section;
    if (stepIndex + 1 < s.steps.length) return s.steps[stepIndex + 1].instruction;
    if (sectionIndex + 1 < route.sections.length) {
      final n = route.sections[sectionIndex + 1];
      if (n.steps.isNotEmpty) return n.steps.first.instruction;
    }
    return 'Arrive at ${destination.name}';
  }

  /// (completed, remaining) geometry of section [i] for the map.
  (List<LatLng>, List<LatLng>) splitSection(int i) {
    final s = route.sections[i];
    return Geo.splitAt(s.path, s.cumulative, progressIn(i));
  }

  TripRecord buildTrip() {
    var bike = 0.0, transit = 0.0;
    for (var i = 0; i < route.sections.length; i++) {
      final s = route.sections[i];
      final frac = s.pathLengthM <= 0 ? 0.0 : progressIn(i) / s.pathLengthM;
      final done = s.distanceM * frac;
      if (s.type == SectionType.bike) bike += done;
      if (s.type == SectionType.transit) transit += done;
    }
    final now = DateTime.now();
    return TripRecord(
      startedAt: startedAt,
      endedAt: now,
      origin: origin,
      destination: destination,
      bikeDistanceM: bike,
      transitDistanceM: transit,
      durationS: now.difference(startedAt).inSeconds.toDouble(),
      sections: [for (final s in route.sections) s.label],
      ride: _telemetry.hasData ? _telemetry.build() : null,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _retry?.cancel();
    _sub?.cancel();
    super.dispose();
  }
}
