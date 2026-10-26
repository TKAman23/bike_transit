import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:bike_transit/utils/geo.dart';

enum SectionType { bike, transit, walk }

/// One navigation instruction. For bike/walk sections this is a turn; for
/// transit sections it is a stop.
class NavStep {
  const NavStep({
    required this.instruction,
    required this.location,
    required this.offsetM,
    this.distanceM = 0,
    this.maneuver,
    this.time,
  });

  final String instruction;
  final LatLng location;

  /// Distance from the start of the section to this step.
  final double offsetM;

  /// Length of this step (bike/walk).
  final double distanceM;
  final String? maneuver;

  /// Scheduled/predicted time at a stop (transit).
  final DateTime? time;
}

class TransitStop {
  const TransitStop({required this.name, required this.location, this.time});

  final String name;
  final LatLng location;
  final DateTime? time;
}

class TransitInfo {
  const TransitInfo({
    required this.routeShortName,
    required this.departureStop,
    required this.arrivalStop,
    required this.departureTime,
    required this.arrivalTime,
    required this.stopCount,
    required this.stops,
    this.lineName,
    this.headsign,
    this.vehicleType,
    this.realtime = false,
    this.withBike = true,
  });

  /// The actual route number/name shown to riders, e.g. "44" or "1 Line".
  final String routeShortName;
  final String? lineName;
  final String? headsign;
  final String? vehicleType;
  final TransitStop departureStop;
  final TransitStop arrivalStop;
  final DateTime departureTime;
  final DateTime arrivalTime;

  /// Number of stops ridden (Google `stopCount`).
  final int stopCount;

  /// Ordered stops from boarding to alighting. Contains every intermediate stop
  /// when One Bus Away enrichment succeeded, otherwise only the two ends.
  final List<TransitStop> stops;

  /// Times come from One Bus Away real-time predictions.
  final bool realtime;

  /// False for park-and-ride legs where the bike stays parked.
  final bool withBike;

  bool get isRail =>
      vehicleType != null && !(vehicleType!.contains('BUS'));

  TransitInfo copyWith({
    DateTime? departureTime,
    DateTime? arrivalTime,
    List<TransitStop>? stops,
    bool? realtime,
    bool? withBike,
  }) {
    return TransitInfo(
      routeShortName: routeShortName,
      lineName: lineName,
      headsign: headsign,
      vehicleType: vehicleType,
      departureStop: departureStop,
      arrivalStop: arrivalStop,
      departureTime: departureTime ?? this.departureTime,
      arrivalTime: arrivalTime ?? this.arrivalTime,
      stopCount: stopCount,
      stops: stops ?? this.stops,
      realtime: realtime ?? this.realtime,
      withBike: withBike ?? this.withBike,
    );
  }
}

/// Elevation samples evenly spaced along a section.
class ElevationProfile {
  ElevationProfile({required this.distancesM, required this.elevationsM})
      : assert(distancesM.length == elevationsM.length);

  final List<double> distancesM;
  final List<double> elevationsM;

  double get minM => elevationsM.isEmpty ? 0 : elevationsM.reduce(math.min);
  double get maxM => elevationsM.isEmpty ? 0 : elevationsM.reduce(math.max);

  double get gainM {
    var gain = 0.0;
    for (var i = 1; i < elevationsM.length; i++) {
      gain += math.max(0, elevationsM[i] - elevationsM[i - 1]);
    }
    return gain;
  }

  /// Grade (rise/run) of the sample interval containing [d].
  double gradeAt(double d) {
    if (distancesM.length < 2) return 0;
    var i = 1;
    while (i < distancesM.length - 1 && distancesM[i] < d) {
      i++;
    }
    final run = distancesM[i] - distancesM[i - 1];
    return run <= 0 ? 0 : (elevationsM[i] - elevationsM[i - 1]) / run;
  }
}

class RouteSection {
  RouteSection({
    required this.type,
    required this.path,
    required this.distanceM,
    this.steps = const [],
    this.transit,
    this.elevation,
    this.duration = Duration.zero,
    this.color = const Color(0xFF4FC3F7),
    this.endLabel,
  });

  final SectionType type;
  final List<LatLng> path;
  final double distanceM;
  final List<NavStep> steps;
  final TransitInfo? transit;
  final ElevationProfile? elevation;

  /// Estimated time for this section; for transit this includes the wait.
  final Duration duration;

  /// Line color shared by the map, the card section row and the details.
  final Color color;

  /// Optional label for where the section ends (e.g. a parking spot).
  final String? endLabel;

  late final List<double> cumulative = Geo.cumulative(path);

  double get pathLengthM => cumulative.isEmpty ? 0 : cumulative.last;

  String get label => switch (type) {
        SectionType.bike => 'Bike',
        SectionType.walk => 'Walk',
        SectionType.transit => transit!.routeShortName,
      };

  RouteSection copyWith({
    Duration? duration,
    Color? color,
    TransitInfo? transit,
    ElevationProfile? elevation,
    List<NavStep>? steps,
  }) {
    return RouteSection(
      type: type,
      path: path,
      distanceM: distanceM,
      steps: steps ?? this.steps,
      transit: transit ?? this.transit,
      elevation: elevation ?? this.elevation,
      duration: duration ?? this.duration,
      color: color ?? this.color,
      endLabel: endLabel,
    );
  }
}

class RouteOption {
  RouteOption({
    required this.id,
    required this.sections,
    required this.departAt,
    this.duration = Duration.zero,
    this.strain = 0,
    this.score = 0,
    this.accentColor = const Color(0xFF1E6FD9),
    this.note,
    this.usesPersonalizedSpeed = false,
  });

  final String id;
  final List<RouteSection> sections;
  final DateTime departAt;

  /// Door-to-door estimate, including waits.
  final Duration duration;
  final double strain;
  final double score;
  final Color accentColor;
  final String? note;
  final bool usesPersonalizedSpeed;

  DateTime get arriveAt => departAt.add(duration);

  double _distanceOf(SectionType t) => sections
      .where((s) => s.type == t)
      .fold(0.0, (sum, s) => sum + s.distanceM);

  double get bikeDistanceM => _distanceOf(SectionType.bike);
  double get transitDistanceM => _distanceOf(SectionType.transit);
  double get walkDistanceM => _distanceOf(SectionType.walk);
  double get totalDistanceM =>
      sections.fold(0.0, (sum, s) => sum + s.distanceM);

  int get transitCount =>
      sections.where((s) => s.type == SectionType.transit).length;

  double get climbM => sections
      .where((s) => s.type != SectionType.transit)
      .fold(0.0, (sum, s) => sum + (s.elevation?.gainM ?? 0));

  /// Identifies "the same route" for de-duplication.
  String get signature => sections
      .map((s) => '${s.type.name}:${s.label}:${(s.distanceM / 200).round()}')
      .join('|');

  Iterable<LatLng> get allPoints => sections.expand((s) => s.path);

  RouteOption copyWith({
    List<RouteSection>? sections,
    Duration? duration,
    double? strain,
    double? score,
    Color? accentColor,
    bool? usesPersonalizedSpeed,
  }) {
    return RouteOption(
      id: id,
      sections: sections ?? this.sections,
      departAt: departAt,
      duration: duration ?? this.duration,
      strain: strain ?? this.strain,
      score: score ?? this.score,
      accentColor: accentColor ?? this.accentColor,
      note: note,
      usesPersonalizedSpeed:
          usesPersonalizedSpeed ?? this.usesPersonalizedSpeed,
    );
  }
}
