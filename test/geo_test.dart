import 'package:bike_transit/utils/geo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() {
  const path = [
    LatLng(47.6000, -122.3300),
    LatLng(47.6010, -122.3300),
    LatLng(47.6020, -122.3300),
  ];

  test('polyline encode/decode round-trips', () {
    final decoded = Geo.decodePolyline(Geo.encodePolyline(path));
    expect(decoded.length, path.length);
    for (var i = 0; i < path.length; i++) {
      expect(decoded[i].latitude, closeTo(path[i].latitude, 1e-5));
      expect(decoded[i].longitude, closeTo(path[i].longitude, 1e-5));
    }
  });

  test('decodes Google sample polyline', () {
    final pts = Geo.decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@');
    expect(pts.first.latitude, closeTo(38.5, 1e-5));
    expect(pts.first.longitude, closeTo(-120.2, 1e-5));
    expect(pts.last.latitude, closeTo(43.252, 1e-5));
  });

  test('0.001° of latitude is about 111 m', () {
    expect(Geo.distance(path[0], path[1]), closeTo(111.2, 0.5));
    expect(Geo.pathLength(path), closeTo(222.4, 1));
  });

  test('project snaps a nearby point onto the path', () {
    final cum = Geo.cumulative(path);
    final (along, off) = Geo.project(const LatLng(47.6015, -122.3301), path, cum);
    expect(along, closeTo(166.8, 1.5));
    expect(off, closeTo(7.5, 1));
  });

  test('splitAt divides the path at a distance', () {
    final cum = Geo.cumulative(path);
    final (before, after) = Geo.splitAt(path, cum, 50);
    expect(Geo.pathLength(before), closeTo(50, 0.5));
    expect(Geo.pathLength(after), closeTo(cum.last - 50, 0.5));
    expect(before.last, after.first);
  });
}
