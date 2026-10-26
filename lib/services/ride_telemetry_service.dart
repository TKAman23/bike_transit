import 'dart:math' as math;

import 'package:bike_transit/constants/route_constants.dart';
import 'package:bike_transit/models/trip_record.dart';

/// Accumulates speed, incline and moving time while biking (NAV-11).
class RideTelemetryService {
  final _meters = List<double>.filled(RouteConstants.gradeBucketBounds.length + 1, 0);
  final _seconds = List<double>.filled(RouteConstants.gradeBucketBounds.length + 1, 0);
  double _climbM = 0;

  /// Records [dt] seconds of riding at [speedMps] on a road of [grade].
  void addSample({
    required double speedMps,
    required double grade,
    required double dtSeconds,
  }) {
    if (dtSeconds <= 0 || dtSeconds > 30) return; // ignore gaps / stale fixes
    if (speedMps < RouteConstants.movingSpeedMps) return;
    final meters = speedMps * dtSeconds;
    final i = GradeBucket.indexFor(grade);
    _meters[i] += meters;
    _seconds[i] += dtSeconds;
    _climbM += math.max(0, grade * meters);
  }

  bool get hasData => _seconds.any((s) => s > 0);

  RideTelemetry build() {
    final moving = _seconds.fold(0.0, (a, b) => a + b);
    final meters = _meters.fold(0.0, (a, b) => a + b);
    return RideTelemetry(
      movingTimeS: moving,
      avgSpeedMps: moving > 0 ? meters / moving : 0,
      climbM: _climbM,
      gradeBuckets: [
        for (var i = 0; i < _meters.length; i++)
          if (_seconds[i] > 0)
            GradeBucket(
              fromPct: GradeBucket.fromPctForIndex(i),
              meters: _meters[i],
              seconds: _seconds[i],
            ),
      ],
    );
  }
}
