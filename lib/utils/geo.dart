import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Geometry helpers for polylines: encoding, distances, snapping and slicing.
/// Distances are in meters.
class Geo {
  Geo._();

  static const double _earthRadiusM = 6371000;

  static double _rad(double deg) => deg * math.pi / 180;

  static double distance(LatLng a, LatLng b) {
    final dLat = _rad(b.latitude - a.latitude);
    final dLng = _rad(b.longitude - a.longitude);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(a.latitude)) *
            math.cos(_rad(b.latitude)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return 2 * _earthRadiusM * math.asin(math.min(1, math.sqrt(h)));
  }

  static double pathLength(List<LatLng> path) {
    var total = 0.0;
    for (var i = 1; i < path.length; i++) {
      total += distance(path[i - 1], path[i]);
    }
    return total;
  }

  /// Cumulative distance from the start of [path] to each vertex.
  static List<double> cumulative(List<LatLng> path) {
    final out = List<double>.filled(path.length, 0);
    for (var i = 1; i < path.length; i++) {
      out[i] = out[i - 1] + distance(path[i - 1], path[i]);
    }
    return out;
  }

  static List<LatLng> decodePolyline(String encoded) {
    final points = <LatLng>[];
    var index = 0, lat = 0, lng = 0;
    while (index < encoded.length) {
      for (var coord = 0; coord < 2; coord++) {
        var shift = 0, result = 0, b = 0;
        do {
          b = encoded.codeUnitAt(index++) - 63;
          result |= (b & 0x1f) << shift;
          shift += 5;
        } while (b >= 0x20 && index < encoded.length);
        // Arithmetic instead of `~`: on web, bitwise ops are unsigned 32-bit.
        final delta = (result & 1) != 0 ? -(result >> 1) - 1 : (result >> 1);
        if (coord == 0) {
          lat += delta;
        } else {
          lng += delta;
        }
      }
      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }

  static String encodePolyline(List<LatLng> path) {
    final out = StringBuffer();
    var prevLat = 0, prevLng = 0;
    void encode(int value) {
      var v = value < 0 ? -value * 2 - 1 : value * 2;
      while (v >= 0x20) {
        out.writeCharCode((0x20 | (v & 0x1f)) + 63);
        v >>= 5;
      }
      out.writeCharCode(v + 63);
    }

    for (final p in path) {
      final lat = (p.latitude * 1e5).round();
      final lng = (p.longitude * 1e5).round();
      encode(lat - prevLat);
      encode(lng - prevLng);
      prevLat = lat;
      prevLng = lng;
    }
    return out.toString();
  }

  /// Keeps at most [maxPoints] evenly spaced vertices (always keeps both ends).
  static List<LatLng> downsample(List<LatLng> path, int maxPoints) {
    if (path.length <= maxPoints) return path;
    final step = (path.length - 1) / (maxPoints - 1);
    return [for (var i = 0; i < maxPoints; i++) path[(i * step).round()]];
  }

  static LatLng pointAt(List<LatLng> path, List<double> cum, double d) {
    if (path.isEmpty) return const LatLng(0, 0);
    if (d <= 0) return path.first;
    if (d >= cum.last) return path.last;
    var i = 1;
    while (i < cum.length && cum[i] < d) {
      i++;
    }
    final segLen = cum[i] - cum[i - 1];
    final t = segLen == 0 ? 0.0 : (d - cum[i - 1]) / segLen;
    return _lerp(path[i - 1], path[i], t);
  }

  static LatLng _lerp(LatLng a, LatLng b, double t) => LatLng(
        a.latitude + (b.latitude - a.latitude) * t,
        a.longitude + (b.longitude - a.longitude) * t,
      );

  /// Splits [path] at distance [d] into (before, after); both include the cut point.
  static (List<LatLng>, List<LatLng>) splitAt(
    List<LatLng> path,
    List<double> cum,
    double d,
  ) {
    if (path.length < 2 || d <= 0) return (<LatLng>[], path);
    if (d >= cum.last) return (path, <LatLng>[]);
    final cut = pointAt(path, cum, d);
    final before = <LatLng>[];
    final after = <LatLng>[cut];
    for (var i = 0; i < path.length; i++) {
      if (cum[i] < d) {
        before.add(path[i]);
      } else {
        after.add(path[i]);
      }
    }
    before.add(cut);
    return (before, after);
  }

  /// Projects [p] onto [path] and returns (distance along path, distance off path).
  /// Only vertices whose cumulative distance is within [fromM, toM] are considered.
  static (double, double) project(
    LatLng p,
    List<LatLng> path,
    List<double> cum, {
    double fromM = 0,
    double toM = double.infinity,
  }) {
    if (path.isEmpty) return (0, double.infinity);
    if (path.length == 1) return (0, distance(p, path.first));
    // Local equirectangular frame around p, in meters.
    final cosLat = math.cos(_rad(p.latitude));
    double x(LatLng q) => _rad(q.longitude - p.longitude) * cosLat * _earthRadiusM;
    double y(LatLng q) => _rad(q.latitude - p.latitude) * _earthRadiusM;

    var bestAlong = 0.0, bestOff = double.infinity;
    for (var i = 1; i < path.length; i++) {
      if (cum[i] < fromM || cum[i - 1] > toM) continue;
      final ax = x(path[i - 1]), ay = y(path[i - 1]);
      final bx = x(path[i]), by = y(path[i]);
      final dx = bx - ax, dy = by - ay;
      final len2 = dx * dx + dy * dy;
      var t = len2 == 0 ? 0.0 : -(ax * dx + ay * dy) / len2;
      t = t.clamp(0.0, 1.0);
      final px = ax + dx * t, py = ay + dy * t;
      final off = math.sqrt(px * px + py * py);
      if (off < bestOff) {
        bestOff = off;
        bestAlong = cum[i - 1] + (cum[i] - cum[i - 1]) * t;
      }
    }
    return (bestAlong, bestOff);
  }

  static LatLngBounds bounds(Iterable<LatLng> points) {
    var minLat = 90.0, maxLat = -90.0, minLng = 180.0, maxLng = -180.0;
    for (final p in points) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }
}
