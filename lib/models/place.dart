import 'package:google_maps_flutter/google_maps_flutter.dart';

/// A resolved location: a searched place, a map tap, or the device location.
class Place {
  const Place({
    required this.name,
    required this.location,
    this.placeId,
    this.address,
    this.isCurrentLocation = false,
  });

  final String name;
  final LatLng location;
  final String? placeId;
  final String? address;
  final bool isCurrentLocation;

  /// Stable key used for the `recentPlaces` document id.
  String get key =>
      placeId ??
      '${location.latitude.toStringAsFixed(5)},${location.longitude.toStringAsFixed(5)}';

  factory Place.fromMap(Map<String, dynamic> map) => Place(
        name: map['name'] as String? ?? 'Saved place',
        address: map['address'] as String?,
        placeId: map['placeId'] as String?,
        location: LatLng(
          (map['lat'] as num).toDouble(),
          (map['lng'] as num).toDouble(),
        ),
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        if (address != null) 'address': address,
        if (placeId != null) 'placeId': placeId,
        'lat': location.latitude,
        'lng': location.longitude,
      };
}

/// One row in the search dropdown.
class PlaceSuggestion {
  const PlaceSuggestion({
    required this.primaryText,
    this.secondaryText,
    this.placeId,
    this.place,
    this.kind = SuggestionKind.prediction,
  });

  final String primaryText;
  final String? secondaryText;
  final String? placeId;

  /// Already-resolved place (recent places, current location).
  final Place? place;
  final SuggestionKind kind;
}

enum SuggestionKind { currentLocation, recent, typed, prediction }
