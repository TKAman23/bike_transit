import 'package:bike_transit/models/place.dart';
import 'package:bike_transit/models/route_option.dart';
import 'package:bike_transit/services/location_service.dart';
import 'package:bike_transit/state/navigation_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() {
  // A straight 1.11 km ride due north with a 10 m climb and three turns.
  const start = LatLng(47.60, -122.33);
  const end = LatLng(47.61, -122.33);
  final route = RouteOption(
    id: 'r',
    departAt: DateTime(2026, 10, 26, 8),
    sections: [
      RouteSection(
        type: SectionType.bike,
        path: const [start, end],
        distanceM: 1112,
        duration: const Duration(minutes: 4),
        elevation: ElevationProfile(distancesM: [0, 1112], elevationsM: [0, 10]),
        steps: const [
          NavStep(instruction: 'Head north', location: start, offsetM: 0),
          NavStep(instruction: 'Keep straight', location: LatLng(47.603, -122.33), offsetM: 333),
          NavStep(instruction: 'Arrive', location: end, offsetM: 1112),
        ],
      ),
    ],
  );

  Position fix(double lat, int second, {double speed = 0.00002}) => Position(
        latitude: lat,
        longitude: -122.33,
        timestamp: DateTime.utc(2026, 10, 26, 8, 0, second),
        accuracy: 5,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: speed, // emulator-style near-zero junk speed
        speedAccuracy: 0,
      );

  test('tracks progress, advances steps, records telemetry and arrives', () {
    var arrived = false;
    final nav = NavigationController(
      route: route,
      origin: const Place(name: 'A', location: start),
      destination: const Place(name: 'B', location: end),
      location: LocationService(),
      onArrived: () => arrived = true,
    );

    // 50 m every 5 s (10 m/s), slightly off the line like real GPS.
    for (var i = 0; i <= 22; i++) {
      nav.update(fix(47.60 + i * 0.00045, i * 5).copyWithLng(-122.33002));
    }
    expect(nav.stepIndex, 2);
    expect(arrived, isTrue);
    expect(nav.progressM, closeTo(nav.totalM, 1));

    final (done, rest) = nav.splitSection(0);
    expect(done.length, greaterThan(1));
    expect(rest.length, lessThanOrEqualTo(1));

    final trip = nav.buildTrip();
    expect(trip.bikeDistanceM, closeTo(1112, 1));
    expect(trip.ride, isNotNull);
    expect(trip.ride!.avgSpeedMps, closeTo(10, 0.5));
    expect(trip.ride!.movingTimeS, greaterThan(90));
    expect(trip.ride!.climbM, greaterThan(5));
  });

  test('GPS jitter while stopped is not recorded as riding', () {
    final nav = NavigationController(
      route: route,
      origin: const Place(name: 'A', location: start),
      destination: const Place(name: 'B', location: end),
      location: LocationService(),
    );
    for (var i = 0; i < 10; i++) {
      nav.update(fix(47.60 + (i.isEven ? 0.00001 : 0), i * 5));
    }
    expect(nav.buildTrip().ride, isNull);
  });
}

extension on Position {
  Position copyWithLng(double lng) => Position(
        latitude: latitude,
        longitude: lng,
        timestamp: timestamp,
        accuracy: accuracy,
        altitude: altitude,
        altitudeAccuracy: altitudeAccuracy,
        heading: heading,
        headingAccuracy: headingAccuracy,
        speed: speed,
        speedAccuracy: speedAccuracy,
      );
}
