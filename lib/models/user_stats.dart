import 'package:bike_transit/models/trip_record.dart';

/// Aggregates derived from trip history (not stored separately in the cloud).
class UserStats {
  const UserStats({
    required this.tripCount,
    required this.bikeDistanceM,
    required this.transitDistanceM,
    required this.movingTimeS,
    required this.climbM,
    required this.co2SavedKg,
    required this.avgSpeedMps,
    required this.last7DaysBikeM,
  });

  final int tripCount;
  final double bikeDistanceM;
  final double transitDistanceM;
  final double movingTimeS;
  final double climbM;
  final double co2SavedKg;
  final double avgSpeedMps;

  /// Bike distance per day, oldest first, ending today.
  final List<double> last7DaysBikeM;

  static const empty = UserStats(
    tripCount: 0,
    bikeDistanceM: 0,
    transitDistanceM: 0,
    movingTimeS: 0,
    climbM: 0,
    co2SavedKg: 0,
    avgSpeedMps: 0,
    last7DaysBikeM: [0, 0, 0, 0, 0, 0, 0],
  );

  /// Per-grade speeds pooled across [trips]; used to personalize estimates.
  static List<GradeBucket> pooledGradeBuckets(Iterable<TripRecord> trips) {
    final meters = <int, double>{};
    final seconds = <int, double>{};
    for (final t in trips) {
      for (final b in t.ride?.gradeBuckets ?? const <GradeBucket>[]) {
        meters[b.fromPct] = (meters[b.fromPct] ?? 0) + b.meters;
        seconds[b.fromPct] = (seconds[b.fromPct] ?? 0) + b.seconds;
      }
    }
    return [
      for (final k in meters.keys)
        GradeBucket(fromPct: k, meters: meters[k]!, seconds: seconds[k]!),
    ];
  }
}
