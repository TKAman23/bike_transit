import 'package:google_maps_flutter/google_maps_flutter.dart';

/// A saved bike-parking spot (`users/{uid}/bikeParking/{id}`).
class BikeParkingSpot {
  const BikeParkingSpot({
    required this.id,
    required this.name,
    required this.location,
  });

  final String id;
  final String name;
  final LatLng location;

  factory BikeParkingSpot.fromMap(String id, Map<String, dynamic> map) =>
      BikeParkingSpot(
        id: id,
        name: map['name'] as String? ?? 'Bike parking',
        location: LatLng(
          (map['lat'] as num).toDouble(),
          (map['lng'] as num).toDouble(),
        ),
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'lat': location.latitude,
        'lng': location.longitude,
      };
}
