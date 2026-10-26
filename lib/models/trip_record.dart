import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:bike_transit/constants/route_constants.dart';
import 'package:bike_transit/models/place.dart';

/// Speed collected on one range of road grades.
class GradeBucket {
  const GradeBucket({
    required this.fromPct,
    required this.meters,
    required this.seconds,
  });

  /// Lower bound of the grade range in percent (-100 for the open-ended first bucket).
  final int fromPct;
  final double meters;
  final double seconds;

  double get speedMps => seconds <= 0 ? 0 : meters / seconds;

  /// Index of the bucket that contains [grade] (rise/run).
  static int indexFor(double grade) {
    final pct = grade * 100;
    var i = 0;
    for (final bound in RouteConstants.gradeBucketBounds) {
      if (pct >= bound) i++;
    }
    return i;
  }

  static int fromPctForIndex(int index) =>
      index == 0 ? -100 : RouteConstants.gradeBucketBounds[index - 1];

  factory GradeBucket.fromMap(Map<String, dynamic> map) => GradeBucket(
        fromPct: (map['fromPct'] as num).toInt(),
        meters: (map['meters'] as num).toDouble(),
        seconds: (map['seconds'] as num).toDouble(),
      );

  Map<String, dynamic> toMap() =>
      {'fromPct': fromPct, 'meters': meters, 'seconds': seconds};
}

/// Per-ride telemetry collected while biking (NAV-11).
class RideTelemetry {
  const RideTelemetry({
    required this.movingTimeS,
    required this.avgSpeedMps,
    required this.climbM,
    required this.gradeBuckets,
  });

  final double movingTimeS;
  final double avgSpeedMps;
  final double climbM;
  final List<GradeBucket> gradeBuckets;

  factory RideTelemetry.fromMap(Map<String, dynamic> map) => RideTelemetry(
        movingTimeS: (map['movingTimeS'] as num?)?.toDouble() ?? 0,
        avgSpeedMps: (map['avgSpeedMps'] as num?)?.toDouble() ?? 0,
        climbM: (map['climbM'] as num?)?.toDouble() ?? 0,
        gradeBuckets: [
          for (final b in (map['gradeBuckets'] as List? ?? const []))
            GradeBucket.fromMap(Map<String, dynamic>.from(b as Map)),
        ],
      );

  Map<String, dynamic> toMap() => {
        'movingTimeS': movingTimeS,
        'avgSpeedMps': avgSpeedMps,
        'climbM': climbM,
        'gradeBuckets': [for (final b in gradeBuckets) b.toMap()],
      };
}

/// A completed (or ended) trip, stored at `users/{uid}/trips/{id}`.
class TripRecord {
  const TripRecord({
    required this.startedAt,
    required this.endedAt,
    required this.origin,
    required this.destination,
    required this.bikeDistanceM,
    required this.transitDistanceM,
    required this.durationS,
    required this.sections,
    this.ride,
    this.id,
  });

  final String? id;
  final DateTime startedAt;
  final DateTime endedAt;
  final Place origin;
  final Place destination;
  final double bikeDistanceM;
  final double transitDistanceM;
  final double durationS;

  /// Section labels in order, e.g. ["Bike", "44", "Bike"].
  final List<String> sections;
  final RideTelemetry? ride;

  factory TripRecord.fromMap(String id, Map<String, dynamic> map) {
    DateTime time(Object? v) =>
        v is Timestamp ? v.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
    return TripRecord(
      id: id,
      startedAt: time(map['startedAt']),
      endedAt: time(map['endedAt']),
      origin: Place.fromMap(Map<String, dynamic>.from(map['origin'] as Map)),
      destination:
          Place.fromMap(Map<String, dynamic>.from(map['destination'] as Map)),
      bikeDistanceM: (map['bikeDistanceM'] as num?)?.toDouble() ?? 0,
      transitDistanceM: (map['transitDistanceM'] as num?)?.toDouble() ?? 0,
      durationS: (map['durationS'] as num?)?.toDouble() ?? 0,
      sections: [for (final s in (map['sections'] as List? ?? const [])) '$s'],
      ride: map['ride'] == null
          ? null
          : RideTelemetry.fromMap(Map<String, dynamic>.from(map['ride'] as Map)),
    );
  }

  Map<String, dynamic> toMap() => {
        'startedAt': Timestamp.fromDate(startedAt),
        'endedAt': Timestamp.fromDate(endedAt),
        'origin': origin.toMap(),
        'destination': destination.toMap(),
        'bikeDistanceM': bikeDistanceM,
        'transitDistanceM': transitDistanceM,
        'durationS': durationS,
        'sections': sections,
        if (ride != null) 'ride': ride!.toMap(),
      };
}
