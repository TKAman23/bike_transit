import 'package:flutter/foundation.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

enum LocationAccess { granted, denied, deniedForever, serviceDisabled }

/// Device position and heading.
class LocationService {
  LatLng? lastKnown;

  Future<LocationAccess> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAccess.serviceDisabled;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return switch (permission) {
      LocationPermission.always ||
      LocationPermission.whileInUse =>
        LocationAccess.granted,
      LocationPermission.deniedForever => LocationAccess.deniedForever,
      _ => LocationAccess.denied,
    };
  }

  Future<LatLng?> current() async {
    if (await ensurePermission() != LocationAccess.granted) return null;
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return lastKnown = LatLng(p.latitude, p.longitude);
    } catch (_) {
      final p = await Geolocator.getLastKnownPosition();
      return p == null ? lastKnown : lastKnown = LatLng(p.latitude, p.longitude);
    }
  }

  Stream<Position> positions() => Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 2,
        ),
      ).map((p) {
        lastKnown = LatLng(p.latitude, p.longitude);
        return p;
      });

  /// Compass heading in degrees from north; empty on devices without a sensor.
  Stream<double> headings() {
    // flutter_compass has no web implementation.
    if (kIsWeb) return const Stream<double>.empty();
    return (FlutterCompass.events ?? const Stream<CompassEvent>.empty())
        .where((e) => e.heading != null)
        .map((e) => (e.heading! + 360) % 360)
        .handleError((Object _) {});
  }
}
