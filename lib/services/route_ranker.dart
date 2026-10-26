import 'dart:math' as math;

import 'package:bike_transit/constants/route_constants.dart';
import 'package:bike_transit/models/route_option.dart';
import 'package:bike_transit/models/trip_record.dart';
import 'package:bike_transit/models/user_preferences.dart';

/// Personalized time and strain estimates, and the speed-vs-strain ranking.
///
/// Bike time: each ~100 m chunk is ridden at
///   base speed × grade factor × fatigue factor,
/// blended with the rider's recorded speed on that grade once enough ride
/// telemetry exists. Strain: flat-equivalent kilometres (climb converted with
/// [RouteConstants.climbMetersPerFlatKm], scaled by hill tolerance), multiplied
/// past the rider's endurance distance.
class RouteRanker {
  RouteRanker({
    required this.prefs,
    List<GradeBucket> learnedBuckets = const [],
  }) : _learned = {for (final b in learnedBuckets) b.fromPct: b};

  final UserPreferences prefs;
  final Map<int, GradeBucket> _learned;

  double get _enduranceM => math.max(500, prefs.enduranceKm * 1000);

  /// Model speed for a grade (rise/run) after [ridden] meters of biking.
  /// Returns (speed m/s, whether learned data contributed).
  (double, bool) bikeSpeed(double grade, double ridden) {
    final base = prefs.bikeSpeedMps;
    var v = grade >= 0
        ? base / (1 + RouteConstants.uphillSlowdown * grade)
        : base *
            (1 +
                math.min(RouteConstants.maxDownhillBoost,
                    RouteConstants.downhillSpeedup * -grade));
    var learnedUsed = false;
    final learned =
        _learned[GradeBucket.fromPctForIndex(GradeBucket.indexFor(grade))];
    if (learned != null && learned.speedMps > 0.5) {
      final alpha = math.min(RouteConstants.learnedSpeedMaxWeight,
          learned.meters / RouteConstants.learnedSpeedFullWeightM);
      v = (1 - alpha) * v + alpha * learned.speedMps;
      learnedUsed = alpha > 0;
    }
    final over = (ridden - _enduranceM) / _enduranceM;
    final fatigue = over <= 0
        ? 1.0
        : math.max(1 - RouteConstants.maxFatigueSlowdown,
            1 - RouteConstants.maxFatigueSlowdown * over);
    return (math.max(1.0, v * fatigue), learnedUsed);
  }

  double _strainMultiplier(double ridden) =>
      1 + math.max(0, (ridden - _enduranceM) / _enduranceM);

  /// (length, grade, climb) chunks covering a bike section.
  Iterable<(double, double, double)> _chunks(RouteSection s) sync* {
    final e = s.elevation;
    if (e == null || e.distancesM.length < 2 || e.distancesM.last <= 0) {
      yield (s.distanceM, 0, 0);
      return;
    }
    final scale = s.distanceM / e.distancesM.last;
    for (var i = 1; i < e.distancesM.length; i++) {
      final run = (e.distancesM[i] - e.distancesM[i - 1]) * scale;
      if (run <= 0) continue;
      final rise = e.elevationsM[i] - e.elevationsM[i - 1];
      yield (run, (rise / run).clamp(-0.3, 0.3), math.max(0, rise));
    }
  }

  /// Fills in section durations, total duration and strain.
  RouteOption estimate(RouteOption route) {
    var t = route.departAt;
    var ridden = 0.0;
    var strain = 0.0;
    var personalized = false;
    final hillWeight = 1.5 - prefs.hillTolerance;
    final sections = <RouteSection>[];

    for (final s in route.sections) {
      final start = t;
      switch (s.type) {
        case SectionType.bike:
          var seconds = 0.0;
          for (final (chunkLen, grade, chunkClimb) in _chunks(s)) {
            // Sub-divide so fatigue grows smoothly along long chunks.
            final pieces =
                (chunkLen / RouteConstants.elevationSampleSpacingM).ceil().clamp(1, 1000);
            final len = chunkLen / pieces, climb = chunkClimb / pieces;
            for (var k = 0; k < pieces; k++) {
              final (v, learned) = bikeSpeed(grade, ridden);
              personalized |= learned;
              seconds += len / v;
              strain += (len / 1000 +
                      climb / RouteConstants.climbMetersPerFlatKm * hillWeight) *
                  _strainMultiplier(ridden);
              ridden += len;
            }
          }
          t = t.add(Duration(seconds: seconds.round()));
        case SectionType.walk:
          t = t.add(Duration(
              seconds: (s.distanceM / RouteConstants.walkSpeedMps).round()));
          strain += s.distanceM / 1000 * RouteConstants.walkStrainPerKm;
        case SectionType.transit:
          final info = s.transit!;
          final ready = t.add(info.withBike
              ? RouteConstants.bikeBoardingBuffer
              : RouteConstants.walkBoardingBuffer);
          if (!ready.isAfter(info.departureTime)) {
            t = info.arrivalTime;
          } else {
            // Missed the planned vehicle: assume the next one.
            t = ready
                .add(info.arrivalTime.difference(info.departureTime))
                .add(RouteConstants.missedConnectionPenalty);
          }
      }
      sections.add(s.copyWith(duration: t.difference(start)));
    }
    return route.copyWith(
      sections: sections,
      duration: t.difference(route.departAt),
      strain: strain,
      usesPersonalizedSpeed: personalized,
    );
  }

  /// Scores by the weighted speed/strain tradeoff (lower is better) and sorts.
  List<RouteOption> rank(List<RouteOption> routes) {
    if (routes.isEmpty) return routes;
    final estimated = routes.map(estimate).toList();
    final tMin = estimated
        .map((r) => r.duration.inSeconds)
        .reduce(math.min)
        .clamp(1, 1 << 31);
    // Strain is measured against the rider's own endurance (flat-km
    // equivalent), so effort well within their ability costs little.
    final enduranceKm = math.max(0.5, prefs.enduranceKm);
    final w = prefs.speedStrainWeight;
    final scored = [
      for (final r in estimated)
        r.copyWith(
          score: w * r.duration.inSeconds / tMin +
              (1 - w) * (1 + r.strain / enduranceKm),
        ),
    ]..sort((a, b) => a.score.compareTo(b.score));
    return scored;
  }
}
