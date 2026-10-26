import 'package:bike_transit/constants/route_constants.dart';
import 'package:bike_transit/constants/theme.dart';
import 'package:bike_transit/models/route_option.dart';
import 'package:bike_transit/models/user_preferences.dart';
import 'package:bike_transit/state/map_screen_controller.dart';
import 'package:bike_transit/widgets/control_row.dart';
import 'package:bike_transit/widgets/route_card.dart';
import 'package:bike_transit/widgets/route_parts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

RouteOption sampleRoute() {
  final t0 = DateTime(2026, 10, 25, 8);
  final stops = [
    for (var i = 0; i < 9; i++)
      TransitStop(
        name: 'Stop $i',
        location: LatLng(47.6 + i * 0.002, -122.33),
        time: t0.add(Duration(minutes: 6 + i * 2)),
      ),
  ];
  return RouteOption(
    id: 'r0',
    departAt: t0,
    duration: const Duration(minutes: 31),
    accentColor: RouteConstants.routeAccentPalette[0],
    sections: [
      RouteSection(
        type: SectionType.bike,
        path: const [LatLng(47.6, -122.33), LatLng(47.601, -122.33)],
        distanceM: 1200,
        color: RouteConstants.bikeColor,
        elevation: ElevationProfile(distancesM: [0, 600, 1200], elevationsM: [10, 40, 25]),
      ),
      RouteSection(
        type: SectionType.transit,
        path: const [LatLng(47.601, -122.33), LatLng(47.62, -122.33)],
        distanceM: 4000,
        color: RouteConstants.transitPalette[0],
        transit: TransitInfo(
          routeShortName: '49',
          headsign: 'University District',
          departureStop: stops.first,
          arrivalStop: stops.last,
          departureTime: stops.first.time!,
          arrivalTime: stops.last.time!,
          stopCount: 8,
          stops: stops,
        ),
      ),
    ],
  );
}

Widget host(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  testWidgets('RouteCard shows time, sections and real route number', (tester) async {
    await tester.pumpWidget(host(RouteCard(
      route: sampleRoute(),
      units: Units.imperial,
      expanded: false,
      onTap: () {},
      onStart: () {},
    )));
    expect(find.text('31 min'), findsOneWidget);
    expect(find.text('49'), findsOneWidget);
    expect(find.text('Details'), findsOneWidget);
    expect(find.byIcon(Icons.directions_bike), findsOneWidget);
    expect(find.text('0.7 mi'), findsOneWidget);
    expect(find.byType(RouteDetails), findsNothing);
    final rotation = tester.widget<AnimatedRotation>(find.byType(AnimatedRotation));
    expect(rotation.turns, 0); // chevron up
  });

  testWidgets('expanded RouteCard shows terrain, elevations and stop ellipsis',
      (tester) async {
    var started = false;
    await tester.pumpWidget(host(RouteCard(
      route: sampleRoute(),
      units: Units.metric,
      expanded: true,
      onTap: () {},
      onStart: () => started = true,
    )));
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedRotation>(find.byType(AnimatedRotation)).turns, 0.5);
    expect(find.byType(TerrainGraph), findsOneWidget);
    expect(find.byType(MountainOutlineIcon), findsOneWidget);
    expect(find.textContaining('Low 10 m'), findsOneWidget);
    expect(find.textContaining('High 40 m'), findsOneWidget);
    // 9 stops → first two, ⋮ 5 stops, last two.
    expect(find.text('Stop 0'), findsOneWidget);
    expect(find.text('Stop 4'), findsNothing);
    expect(find.text('5 stops'), findsOneWidget);
    expect(find.text('Stop 8'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.chevron_right));
    expect(started, isTrue);
  });

  testWidgets('ControlRow: segment fills left half, buttons share right half',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    SheetSegment? chosen;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: ControlRow(
          segment: SheetSegment.route,
          onSegment: (s) => chosen = s,
          locationMode: LocationMode.free,
          onLocation: () {},
          bearing: 45,
          onCompass: () {},
        ),
      ),
    ));
    final width = 1080 / 2.625;
    final seg = tester.getRect(find.byType(SegmentedButton<SheetSegment>));
    expect(seg.left, 10);
    expect(seg.right, closeTo(width / 2, 0.5));
    expect(seg.height, 50);
    final buttons = find.byType(ElevatedButton);
    final b1 = tester.getRect(buttons.at(0)), b2 = tester.getRect(buttons.at(1));
    expect(b1.left, closeTo(width / 2 + 10, 0.5));
    expect(b2.right, closeTo(width - 10, 0.5));
    expect(b1.width, closeTo(b2.width, 0.5));
    await tester.tap(find.text('Options'));
    expect(chosen, SheetSegment.options);
  });
}
