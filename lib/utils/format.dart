import 'package:flutter/material.dart';

import 'package:bike_transit/models/user_preferences.dart';

/// Unit-aware formatting. Units always come from the user's preferences.
class Fmt {
  Fmt._();

  static const double _metersPerMile = 1609.344;
  static const double _feetPerMeter = 3.28084;

  static String distance(double meters, Units units) {
    if (units == Units.metric) {
      return meters < 1000
          ? '${(meters / 10).round() * 10} m'
          : '${(meters / 1000).toStringAsFixed(meters < 10000 ? 1 : 0)} km';
    }
    final miles = meters / _metersPerMile;
    return miles < 0.1
        ? '${(meters * _feetPerMeter / 10).round() * 10} ft'
        : '${miles.toStringAsFixed(miles < 10 ? 1 : 0)} mi';
  }

  static String elevation(double meters, Units units) => units == Units.metric
      ? '${meters.round()} m'
      : '${(meters * _feetPerMeter).round()} ft';

  static String duration(Duration d) {
    final mins = (d.inSeconds / 60).ceil();
    if (mins < 60) return '$mins min';
    final h = mins ~/ 60, m = mins % 60;
    return m == 0 ? '$h h' : '$h h $m min';
  }

  static String clock(BuildContext context, DateTime t) =>
      TimeOfDay.fromDateTime(t.toLocal()).format(context);

  static String speedFromKph(double kph, Units units) => units == Units.metric
      ? '${kph.toStringAsFixed(0)} km/h'
      : '${(kph / 1.609344).toStringAsFixed(0)} mph';

  static String speedFromMps(double mps, Units units) =>
      speedFromKph(mps * 3.6, units);

  static double kmToDisplay(double km, Units units) =>
      units == Units.metric ? km : km / 1.609344;

  static double displayToKm(double value, Units units) =>
      units == Units.metric ? value : value * 1.609344;

  static String distanceUnit(Units units) =>
      units == Units.metric ? 'km' : 'mi';

  static String speedUnit(Units units) =>
      units == Units.metric ? 'km/h' : 'mph';
}
