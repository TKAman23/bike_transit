import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:bike_transit/constants/route_constants.dart';
import 'package:bike_transit/models/bike_parking.dart';
import 'package:bike_transit/models/place.dart';
import 'package:bike_transit/models/route_option.dart';
import 'package:bike_transit/models/trip_record.dart';
import 'package:bike_transit/models/user_preferences.dart';
import 'package:bike_transit/services/api_client.dart';
import 'package:bike_transit/services/directions_service.dart';
import 'package:bike_transit/services/elevation_service.dart';
import 'package:bike_transit/services/one_bus_away_service.dart';
import 'package:bike_transit/services/places_service.dart';
import 'package:bike_transit/services/route_ranker.dart';
import 'package:bike_transit/utils/geo.dart';

class PlanResult {
  const PlanResult(this.routes, {this.notices = const []});

  final List<RouteOption> routes;

  /// Non-fatal data issues to surface to the rider (e.g. no live transit data).
  final List<String> notices;
}

class _Candidate {
  _Candidate(this.sections, {this.note});

  List<RouteSection> sections;
  final String? note;
}

/// Builds bike-only, transit (bike access/egress), bike-to-hub and bike-parking
/// candidates, then estimates and ranks them. See README "Route generation".
class RoutePlanner {
  RoutePlanner({
    DirectionsService? directions,
    PlacesService? places,
    ElevationService? elevation,
    OneBusAwayService? oba,
  })  : _directions = directions ?? DirectionsService(),
        _places = places ?? PlacesService(),
        _elevation = elevation ?? ElevationService(),
        _oba = oba ?? OneBusAwayService();

  final DirectionsService _directions;
  final PlacesService _places;
  final ElevationService _elevation;
  final OneBusAwayService _oba;

  Future<PlanResult> plan({
    required Place origin,
    required Place destination,
    required UserPreferences prefs,
    List<BikeParkingSpot> parking = const [],
    List<GradeBucket> learnedBuckets = const [],
    DateTime? now,
  }) async {
    final start = now ?? DateTime.now();
    final notices = <String>{};
    final candidates = <_Candidate>[];
    final a = origin.location, b = destination.location;
    final directDistance = Geo.distance(a, b);

    Future<void> guard(String what, Future<void> Function() body) async {
      try {
        await body();
      } on ApiException catch (e) {
        if (e.isConfiguration) rethrow;
        debugPrint('$what failed: $e');
      } catch (e) {
        debugPrint('$what failed: $e');
      }
    }

    // Bike-only alternatives. Failure here is fatal: it's the core route type.
    final bikeRoutes = await _directions.compute(
        origin: a, destination: b, mode: TravelMode.bicycle, alternatives: true);
    for (final r in bikeRoutes) {
      candidates.add(_Candidate([_section(r.steps, SectionType.bike)]));
    }

    final tasks = <Future<void>>[];
    if (prefs.transitEnabled) {
      // Google transit itineraries with walking legs ridden by bike.
      tasks.add(guard('transit', () async {
        final routes = await _directions.compute(
          origin: a,
          destination: b,
          mode: TravelMode.transit,
          alternatives: true,
          departureTime: start,
        );
        for (final r in routes) {
          final sections = await _convertTransit(r, bikeAlong: true);
          if (sections != null) candidates.add(_Candidate(sections));
        }
      }));

      // Bike further to a rail/major transit hub, then ride transit.
      tasks.add(guard('hubs', () async {
        final radius = math.min(RouteConstants.hubMaxDistanceM,
            math.max(RouteConstants.hubMinDistanceM * 2, prefs.enduranceKm * 500));
        final hubs = (await _places.nearbyTransitHubs(a, radius))
            .where((h) =>
                Geo.distance(a, h.location) >= RouteConstants.hubMinDistanceM &&
                Geo.distance(h.location, b) < directDistance - 500)
            .take(RouteConstants.maxHubs);
        await Future.wait(hubs.map((hub) => guard('hub ${hub.name}', () async {
              final c = await _bikeThenTransit(a, hub.location, b, start,
                  bikeAlong: true);
              if (c != null) candidates.add(c);
            })));
      }));
    }

    // Saved bike parking near the destination: ride there, walk the rest.
    final destSpot = _nearest(parking, b, RouteConstants.destinationParkingRadiusM);
    if (destSpot != null) {
      tasks.add(guard('destination parking', () async {
        final ride = await _directions.compute(
            origin: a, destination: destSpot.location, mode: TravelMode.bicycle);
        final walk = await _directions.compute(
            origin: destSpot.location, destination: b, mode: TravelMode.walk);
        if (ride.isEmpty || walk.isEmpty) return;
        candidates.add(_Candidate([
          _section(ride.first.steps, SectionType.bike, endLabel: destSpot.name),
          _section(walk.first.steps, SectionType.walk),
        ], note: 'Parks at ${destSpot.name}'));
      }));
    }

    // Park & ride: ride to a saved spot, lock up, take transit without the bike.
    if (prefs.transitEnabled) {
      final reach = math.min(RouteConstants.hubMaxDistanceM, prefs.enduranceKm * 1000);
      final spots = parking
          .where((p) =>
              Geo.distance(a, p.location) > 300 &&
              Geo.distance(a, p.location) <= reach &&
              Geo.distance(p.location, b) < directDistance)
          .toList()
        ..sort((x, y) =>
            Geo.distance(a, x.location).compareTo(Geo.distance(a, y.location)));
      for (final spot in spots.take(RouteConstants.maxParkAndRideSpots)) {
        tasks.add(guard('park & ride ${spot.name}', () async {
          final c = await _bikeThenTransit(a, spot.location, b, start,
              bikeAlong: false, note: 'Park at ${spot.name}, ride without bike');
          if (c != null) candidates.add(c);
        }));
      }
    }

    await Future.wait(tasks);

    // Transfer limit and sanity filters.
    candidates.removeWhere((c) =>
        c.sections.where((s) => s.type == SectionType.transit).length >
        RouteConstants.maxTransfers + 1);

    // Elevation for every ridden/walked section.
    var elevationFailed = false;
    await Future.wait([
      for (final c in candidates)
        for (var i = 0; i < c.sections.length; i++)
          if (c.sections[i].type != SectionType.transit)
            () async {
              try {
                final profile = await _elevation.profile(c.sections[i].path);
                if (profile != null) {
                  c.sections[i] = c.sections[i].copyWith(elevation: profile);
                }
              } catch (e) {
                elevationFailed = true;
                debugPrint('elevation failed: $e');
              }
            }(),
    ]);
    if (elevationFailed) {
      notices.add('Elevation data unavailable for some routes; hills not counted.');
    }

    final ranker = RouteRanker(prefs: prefs, learnedBuckets: learnedBuckets);
    List<RouteOption> rankAndDedupe(List<_Candidate> list) {
      var i = 0;
      final ranked = ranker.rank([
        for (final c in list)
          RouteOption(
              id: 'c${i++}', sections: c.sections, departAt: start, note: c.note),
      ]);
      final seen = <String>{};
      return [
        for (final r in ranked)
          if (seen.add(r.signature)) r,
      ].take(RouteConstants.maxRoutesShown).toList();
    }

    var routes = rankAndDedupe(candidates);

    // One Bus Away: live departures + full stop lists for the shown routes.
    if (routes.any((r) => r.transitCount > 0)) {
      if (!_oba.isConfigured) {
        notices.add('Live transit data off (OBA_API_KEY not set); using schedules.');
      } else {
        var enrichedAny = false;
        final cache = <String, TransitInfo?>{};
        final enriched = <RouteOption>[];
        for (final r in routes) {
          final sections = <RouteSection>[];
          for (final s in r.sections) {
            final t = s.transit;
            if (t == null) {
              sections.add(s);
              continue;
            }
            final key = '${t.routeShortName}|${t.departureStop.name}|${t.departureTime}';
            final info = cache.containsKey(key)
                ? cache[key]
                : cache[key] = await _oba.enrich(t);
            if (info != null) enrichedAny = true;
            sections.add(info == null
                ? s
                : s.copyWith(transit: info.copyWith(withBike: t.withBike)));
          }
          enriched.add(r.copyWith(sections: sections));
        }
        if (!enrichedAny) {
          notices.add('One Bus Away had no live data for these trips; using schedules.');
        }
        routes = ranker.rank(enriched);
      }
    }

    return PlanResult(
      _finalize(routes, destination.name),
      notices: notices.toList(),
    );
  }

  Future<_Candidate?> _bikeThenTransit(
    LatLng a,
    LatLng via,
    LatLng b,
    DateTime start, {
    required bool bikeAlong,
    String? note,
  }) async {
    final ride = await _directions.compute(
        origin: a, destination: via, mode: TravelMode.bicycle);
    if (ride.isEmpty) return null;
    final leave = start.add(ride.first.duration).add(const Duration(minutes: 2));
    final transit = await _directions.compute(
        origin: via, destination: b, mode: TravelMode.transit, departureTime: leave);
    if (transit.isEmpty) return null;
    final rest = await _convertTransit(transit.first, bikeAlong: bikeAlong);
    if (rest == null) return null;
    if (!bikeAlong) {
      final walked = rest
          .where((s) => s.type == SectionType.walk)
          .fold(0.0, (sum, s) => sum + s.distanceM);
      if (walked > RouteConstants.parkAndRideMaxWalkM) return null;
    }
    return _Candidate(
      _mergeAdjacent([_section(ride.first.steps, SectionType.bike), ...rest]),
      note: note,
    );
  }

  /// Turns a Google transit itinerary into sections. Walking gaps become bike
  /// sections when the bike comes along (long gaps are re-routed for bikes).
  Future<List<RouteSection>?> _convertTransit(
    GRoute route, {
    required bool bikeAlong,
  }) async {
    final groups = <List<GStep>>[];
    for (final s in route.steps) {
      final isTransit = s.mode == TravelMode.transit;
      if (isTransit || groups.isEmpty || groups.last.first.mode == TravelMode.transit) {
        groups.add([s]);
      } else {
        groups.last.add(s);
      }
    }
    if (!groups.any((g) => g.first.mode == TravelMode.transit)) return null;

    final sections = await Future.wait(groups.map((g) async {
      final first = g.first;
      if (first.mode == TravelMode.transit) {
        final info = first.transit;
        if (info == null) return null;
        return RouteSection(
          type: SectionType.transit,
          path: first.path,
          distanceM: first.distanceM,
          transit: bikeAlong ? info : info.copyWith(withBike: false),
        );
      }
      if (!bikeAlong) return _section(g, SectionType.walk);
      final length = g.fold(0.0, (sum, s) => sum + s.distanceM);
      if (length >= RouteConstants.rerouteWalkAsBikeMinM) {
        try {
          final ride = await _directions.compute(
              origin: g.first.start,
              destination: g.last.end,
              mode: TravelMode.bicycle);
          if (ride.isNotEmpty) return _section(ride.first.steps, SectionType.bike);
        } catch (e) {
          debugPrint('bike reroute failed: $e');
        }
      }
      return _section(g, SectionType.bike);
    }));
    if (sections.contains(null)) return null;
    return _mergeAdjacent(sections.cast<RouteSection>());
  }

  RouteSection _section(List<GStep> steps, SectionType type, {String? endLabel}) {
    final path = <LatLng>[];
    final navSteps = <NavStep>[];
    var offset = 0.0;
    for (final s in steps) {
      final pts = (path.isNotEmpty && s.path.isNotEmpty && s.path.first == path.last)
          ? s.path.skip(1)
          : s.path;
      path.addAll(pts);
      navSteps.add(NavStep(
        instruction: s.instruction?.split('\n').first ??
            (type == SectionType.walk ? 'Walk' : 'Continue'),
        maneuver: s.maneuver,
        location: s.start,
        offsetM: offset,
        distanceM: s.distanceM,
      ));
      offset += s.distanceM;
    }
    return RouteSection(
      type: type,
      path: path,
      distanceM: offset,
      steps: navSteps,
      endLabel: endLabel,
    );
  }

  List<RouteSection> _mergeAdjacent(List<RouteSection> sections) {
    final out = <RouteSection>[];
    for (final s in sections) {
      final prev = out.isEmpty ? null : out.last;
      if (prev != null && prev.type == s.type && s.type != SectionType.transit) {
        out[out.length - 1] = RouteSection(
          type: s.type,
          path: [...prev.path, ...s.path],
          distanceM: prev.distanceM + s.distanceM,
          steps: [
            ...prev.steps,
            for (final st in s.steps)
              NavStep(
                instruction: st.instruction,
                maneuver: st.maneuver,
                location: st.location,
                offsetM: st.offsetM + prev.distanceM,
                distanceM: st.distanceM,
              ),
          ],
          endLabel: s.endLabel,
        );
      } else {
        out.add(s);
      }
    }
    return out;
  }

  BikeParkingSpot? _nearest(List<BikeParkingSpot> spots, LatLng p, double within) {
    BikeParkingSpot? best;
    var bestD = within;
    for (final s in spots) {
      final d = Geo.distance(s.location, p);
      if (d <= bestD) {
        bestD = d;
        best = s;
      }
    }
    return best;
  }

  /// Assigns ids, colors and arrival/stop steps once the order is final.
  List<RouteOption> _finalize(List<RouteOption> routes, String destinationName) {
    final transitColors = <String, int>{};
    for (final r in routes) {
      for (final s in r.sections) {
        final t = s.transit;
        if (t != null) {
          transitColors.putIfAbsent(t.routeShortName, () => transitColors.length);
        }
      }
    }
    final out = <RouteOption>[];
    for (var i = 0; i < routes.length; i++) {
      final r = routes[i];
      final sections = <RouteSection>[];
      for (var j = 0; j < r.sections.length; j++) {
        final s = r.sections[j];
        final next = j + 1 < r.sections.length ? r.sections[j + 1] : null;
        switch (s.type) {
          case SectionType.transit:
            final t = s.transit!;
            final color = RouteConstants.transitPalette[
                transitColors[t.routeShortName]! % RouteConstants.transitPalette.length];
            sections.add(s.copyWith(color: color, steps: _stopSteps(s, t)));
          case SectionType.bike || SectionType.walk:
            final arrive = next?.transit != null
                ? (next!.transit!.withBike
                    ? 'Arrive at ${next.transit!.departureStop.name} and load your bike'
                    : 'Arrive at ${next.transit!.departureStop.name}')
                : s.endLabel != null
                    ? 'Lock your bike at ${s.endLabel}'
                    : next == null
                        ? 'Arrive at $destinationName'
                        : 'Continue';
            final last = s.path.isEmpty ? const LatLng(0, 0) : s.path.last;
            sections.add(s.copyWith(
              color: s.type == SectionType.bike
                  ? RouteConstants.bikeColor
                  : RouteConstants.walkColor,
              steps: [
                ...s.steps,
                NavStep(instruction: arrive, location: last, offsetM: s.distanceM),
              ],
            ));
        }
      }
      out.add(RouteOption(
        id: 'route$i',
        sections: sections,
        departAt: r.departAt,
        duration: r.duration,
        strain: r.strain,
        score: r.score,
        accentColor: RouteConstants
            .routeAccentPalette[i % RouteConstants.routeAccentPalette.length],
        note: r.note,
        usesPersonalizedSpeed: r.usesPersonalizedSpeed,
      ));
    }
    return out;
  }

  List<NavStep> _stopSteps(RouteSection s, TransitInfo t) {
    final cum = s.cumulative;
    final stops = t.stops;
    return [
      for (var i = 0; i < stops.length; i++)
        NavStep(
          instruction: i == 0
              ? 'Board ${t.routeShortName}${t.headsign != null ? ' toward ${t.headsign}' : ''} at ${stops[i].name}'
              : i == stops.length - 1
                  ? 'Get off at ${stops[i].name}'
                  : stops[i].name,
          location: stops[i].location,
          offsetM: i == 0
              ? 0
              : i == stops.length - 1
                  ? s.pathLengthM
                  : Geo.project(stops[i].location, s.path, cum).$1,
          time: stops[i].time,
        ),
    ];
  }
}
