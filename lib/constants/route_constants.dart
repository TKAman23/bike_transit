import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Map, planning and estimation constants shared by services and widgets.
class RouteConstants {
  RouteConstants._();

  static const LatLng seattleCenter = LatLng(47.6061, -122.3329);
  static const double seattleZoom = 13.0;
  static const double searchBiasRadiusM = 50000;

  // ---- Candidate generation ----
  static const int maxRoutesShown = 5;
  static const int maxTransfers = 2;
  static const int maxHubs = 2;
  static const double hubMinDistanceM = 800;
  static const double hubMaxDistanceM = 5000;
  /// Walking gaps shorter than this keep their walking geometry but are ridden.
  static const double rerouteWalkAsBikeMinM = 250;
  static const double destinationParkingRadiusM = 400;
  static const double parkAndRideMaxWalkM = 1500;
  static const int maxParkAndRideSpots = 2;

  // ---- Time / strain model ----
  static const double elevationSampleSpacingM = 100;
  static const int maxElevationSamples = 200;
  static const double uphillSlowdown = 9.0; // speed / (1 + k·grade)
  static const double downhillSpeedup = 4.0; // speed · (1 + k·|grade|)
  static const double maxDownhillBoost = 0.35;
  static const double maxFatigueSlowdown = 0.25;
  static const double walkSpeedMps = 1.3;
  static const Duration bikeBoardingBuffer = Duration(minutes: 2);
  static const Duration walkBoardingBuffer = Duration(minutes: 1);
  static const Duration missedConnectionPenalty = Duration(minutes: 15);
  /// Strain: this much climbing counts as 1 km of flat riding (before hill tolerance).
  static const double climbMetersPerFlatKm = 100;
  static const double walkStrainPerKm = 0.4;
  /// Meters ridden in a grade bucket for learned speed to fully count.
  static const double learnedSpeedFullWeightM = 10000;
  static const double learnedSpeedMaxWeight = 0.8;
  static const int ridesUsedForPersonalization = 20;

  // ---- Navigation ----
  static const double arrivalRadiusM = 30;
  static const double snapLookBackM = 60;
  static const double snapLookAheadM = 600;
  static const double movingSpeedMps = 1.0;

  /// Grade buckets (in percent) for ride telemetry, by lower bound.
  static const List<int> gradeBucketBounds = [-8, -4, -1, 1, 4, 8];

  // ---- Stats ----
  /// Average passenger vehicle ≈ 400 g CO2 per mile (US EPA) ≈ 0.25 kg/km.
  static const double co2KgPerKmAvoided = 0.25;

  // ---- Colors ----
  static const Color bikeColor = Color(0xFF4FC3F7); // light blue
  static const Color walkColor = Color(0xFF90A4AE);
  /// One distinct color per bus/rail route in a result set.
  static const List<Color> transitPalette = [
    Color(0xFFE65100),
    Color(0xFF8E24AA),
    Color(0xFF2E7D32),
    Color(0xFFC2185B),
    Color(0xFFF9A825),
    Color(0xFF00897B),
    Color(0xFF5D4037),
    Color(0xFF3949AB),
  ];
  /// Collapsed-list accent per route; matches that route's map line.
  static const List<Color> routeAccentPalette = [
    Color(0xFF1E6FD9),
    Color(0xFF7E57C2),
    Color(0xFF00897B),
    Color(0xFFEF6C00),
    Color(0xFFD81B60),
  ];
  static const Color fadedRouteColor = Color(0x669E9E9E);
}
