import 'package:bike_transit/models/route_option.dart';
import 'package:bike_transit/models/trip_record.dart';
import 'package:bike_transit/models/user_preferences.dart';
import 'package:bike_transit/services/ride_telemetry_service.dart';
import 'package:bike_transit/services/route_ranker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

RouteSection bike(double meters, {double climb = 0}) => RouteSection(
      type: SectionType.bike,
      path: const [LatLng(47.6, -122.33), LatLng(47.61, -122.33)],
      distanceM: meters,
      elevation: ElevationProfile(
        distancesM: [0, meters],
        elevationsM: [0, climb],
      ),
    );

void main() {
  final t0 = DateTime(2026, 10, 25, 8);
  const prefs = UserPreferences.defaults; // 18 km/h, 10 km endurance

  test('flat ride time follows biking speed', () {
    final r = RouteRanker(prefs: prefs)
        .estimate(RouteOption(id: 'a', sections: [bike(3000)], departAt: t0));
    expect(r.duration.inSeconds, closeTo(600, 2)); // 3 km at 5 m/s
  });

  test('uphill is slower and more strenuous than flat', () {
    final ranker = RouteRanker(prefs: prefs);
    final flat = ranker.estimate(RouteOption(id: 'f', sections: [bike(2000)], departAt: t0));
    final hill = ranker.estimate(
        RouteOption(id: 'h', sections: [bike(2000, climb: 120)], departAt: t0));
    expect(hill.duration, greaterThan(flat.duration));
    expect(hill.strain, greaterThan(flat.strain));
  });

  test('riding beyond endurance slows down and adds strain', () {
    final weak = RouteRanker(prefs: prefs.copyWith(enduranceKm: 2))
        .estimate(RouteOption(id: 'w', sections: [bike(6000)], departAt: t0));
    final strong = RouteRanker(prefs: prefs.copyWith(enduranceKm: 20))
        .estimate(RouteOption(id: 's', sections: [bike(6000)], departAt: t0));
    expect(weak.duration, greaterThan(strong.duration));
    expect(weak.strain, greaterThan(strong.strain));
  });

  test('transit waits for the departure and penalizes a missed one', () {
    TransitInfo bus(DateTime dep) => TransitInfo(
          routeShortName: '44',
          departureStop: const TransitStop(name: 'A', location: LatLng(0, 0)),
          arrivalStop: const TransitStop(name: 'B', location: LatLng(0, 0)),
          departureTime: dep,
          arrivalTime: dep.add(const Duration(minutes: 10)),
          stopCount: 5,
          stops: const [],
        );
    RouteOption trip(DateTime dep) => RouteOption(id: 't', departAt: t0, sections: [
          bike(1500), // 5 min
          RouteSection(
              type: SectionType.transit,
              path: const [],
              distanceM: 4000,
              transit: bus(dep)),
        ]);
    final ranker = RouteRanker(prefs: prefs);
    final caught = ranker.estimate(trip(t0.add(const Duration(minutes: 12))));
    expect(caught.duration, const Duration(minutes: 22));
    final missed = ranker.estimate(trip(t0.add(const Duration(minutes: 5))));
    expect(missed.duration, greaterThan(const Duration(minutes: 30)));
  });

  test('weighting chooses between fast-hilly and slow-flat', () {
    final fastHilly = RouteOption(id: 'fast', sections: [bike(2000, climb: 60)], departAt: t0);
    final slowFlat = RouteOption(id: 'flat', sections: [bike(2600)], departAt: t0);
    final speedFirst = RouteRanker(prefs: prefs.copyWith(speedStrainWeight: 1, hillTolerance: 0))
        .rank([slowFlat, fastHilly]);
    final strainFirst = RouteRanker(prefs: prefs.copyWith(speedStrainWeight: 0, hillTolerance: 0))
        .rank([fastHilly, slowFlat]);
    expect(speedFirst.first.duration <= speedFirst.last.duration, isTrue);
    expect(strainFirst.first.id, 'flat');
  });

  test('balanced ranking depends on the rider\'s endurance', () {
    final bus = TransitInfo(
      routeShortName: '40',
      departureStop: const TransitStop(name: 'A', location: LatLng(0, 0)),
      arrivalStop: const TransitStop(name: 'B', location: LatLng(0, 0)),
      departureTime: t0.add(const Duration(minutes: 4)),
      arrivalTime: t0.add(const Duration(minutes: 24)),
      stopCount: 12,
      stops: const [],
    );
    final ride = RouteOption(id: 'bike', sections: [bike(3900)], departAt: t0);
    final transit = RouteOption(id: 'bus', departAt: t0, sections: [
      bike(400),
      RouteSection(type: SectionType.transit, path: const [], distanceM: 4800, transit: bus),
      bike(400),
    ]);
    final fit = RouteRanker(prefs: prefs.copyWith(enduranceKm: 10)).rank([transit, ride]);
    expect(fit.first.id, 'bike');
    final tired = RouteRanker(prefs: prefs.copyWith(enduranceKm: 2)).rank([ride, transit]);
    expect(tired.first.id, 'bus');
  });

  test('recorded rides personalize the estimate', () {
    final telemetry = RideTelemetryService();
    for (var i = 0; i < 300; i++) {
      telemetry.addSample(speedMps: 3, grade: 0, dtSeconds: 10); // 9 km at 3 m/s
    }
    final learned = telemetry.build().gradeBuckets;
    final base = RouteRanker(prefs: prefs)
        .estimate(RouteOption(id: 'a', sections: [bike(3000)], departAt: t0));
    final personal = RouteRanker(prefs: prefs, learnedBuckets: learned)
        .estimate(RouteOption(id: 'a', sections: [bike(3000)], departAt: t0));
    expect(personal.usesPersonalizedSpeed, isTrue);
    expect(personal.duration, greaterThan(base.duration));
  });

  test('telemetry buckets by grade and ignores stops', () {
    final t = RideTelemetryService()
      ..addSample(speedMps: 5, grade: 0.0, dtSeconds: 10)
      ..addSample(speedMps: 3, grade: 0.06, dtSeconds: 10)
      ..addSample(speedMps: 0.2, grade: 0.0, dtSeconds: 10);
    final r = t.build();
    expect(r.movingTimeS, 20);
    expect(r.gradeBuckets.map((b) => b.fromPct), containsAll([-1, 4]));
    expect(r.climbM, closeTo(1.8, 0.01));
    expect(GradeBucket.indexFor(-0.2), 0);
  });

  test('preferences round-trip through the cloud map', () {
    final p = prefs.copyWith(units: Units.metric, bikeSpeedKph: 22, transitEnabled: false);
    expect(UserPreferences.fromMap(p.toMap()), p);
  });
}
