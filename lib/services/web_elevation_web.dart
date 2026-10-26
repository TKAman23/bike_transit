import 'dart:js_interop';

import 'package:google_maps_flutter/google_maps_flutter.dart';

@JS('google.maps.ElevationService')
extension type _ElevationService._(JSObject _) implements JSObject {
  external _ElevationService();
  external JSPromise<_PathElevationResponse> getElevationAlongPath(
      _PathElevationRequest request);
}

extension type _PathElevationRequest._(JSObject _) implements JSObject {
  external factory _PathElevationRequest({
    JSArray<_LatLngLiteral> path,
    int samples,
  });
}

extension type _LatLngLiteral._(JSObject _) implements JSObject {
  external factory _LatLngLiteral({double lat, double lng});
}

extension type _PathElevationResponse._(JSObject _) implements JSObject {
  external JSArray<_ElevationResult> get results;
}

extension type _ElevationResult._(JSObject _) implements JSObject {
  external double get elevation;
}

/// Evenly spaced elevations along [path] (at most 512 samples).
Future<List<double>> elevationsAlongPathJs(List<LatLng> path, int samples) async {
  final request = _PathElevationRequest(
    path: [
      for (final p in path) _LatLngLiteral(lat: p.latitude, lng: p.longitude),
    ].toJS,
    samples: samples,
  );
  final response = await _ElevationService().getElevationAlongPath(request).toDart;
  return [for (final r in response.results.toDart) r.elevation];
}
