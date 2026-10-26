import 'package:bike_transit/constants/route_constants.dart';
import 'package:bike_transit/models/trip_record.dart';
import 'package:bike_transit/models/user_stats.dart';

class StatsService {
  const StatsService();

  UserStats compute(List<TripRecord> trips, {DateTime? now}) {
    if (trips.isEmpty) return UserStats.empty;
    final today = _day(now ?? DateTime.now());
    final week = List<double>.filled(7, 0);
    var bike = 0.0, transit = 0.0, moving = 0.0, climb = 0.0;
    for (final t in trips) {
      bike += t.bikeDistanceM;
      transit += t.transitDistanceM;
      moving += t.ride?.movingTimeS ?? 0;
      climb += t.ride?.climbM ?? 0;
      final age = today.difference(_day(t.startedAt.toLocal())).inDays;
      if (age >= 0 && age < 7) week[6 - age] += t.bikeDistanceM;
    }
    return UserStats(
      tripCount: trips.length,
      bikeDistanceM: bike,
      transitDistanceM: transit,
      movingTimeS: moving,
      climbM: climb,
      co2SavedKg: bike / 1000 * RouteConstants.co2KgPerKmAvoided,
      avgSpeedMps: moving > 0 ? _ridden(trips) / moving : 0,
      last7DaysBikeM: week,
    );
  }

  static double _ridden(List<TripRecord> trips) => trips.fold(
      0.0,
      (sum, t) =>
          sum +
          (t.ride?.gradeBuckets.fold<double>(0, (s, b) => s + b.meters) ?? 0));

  static DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);
}
