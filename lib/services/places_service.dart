import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:bike_transit/constants/app_config.dart';
import 'package:bike_transit/constants/route_constants.dart';
import 'package:bike_transit/models/place.dart';
import 'package:bike_transit/services/api_client.dart';

/// Google Places API (New) + Geocoding: search suggestions, place details,
/// nearby transit hubs and reverse geocoding.
class PlacesService {
  PlacesService({ApiClient? client}) : _api = client ?? ApiClient();

  final ApiClient _api;
  String _sessionToken = _newToken();

  static String _newToken() {
    final r = math.Random();
    return List.generate(32, (_) => r.nextInt(16).toRadixString(16)).join();
  }

  Map<String, String> _headers(String fieldMask) => {
        'X-Goog-Api-Key': AppConfig.servicesKey,
        'X-Goog-FieldMask': fieldMask,
      };

  void _requireKey() {
    if (!AppConfig.hasServicesKey) {
      throw ApiException(
        'MAPS_API_KEY / MAPS_SERVICES_KEY is not set. Run with --dart-define-from-file=config/keys.json.',
        isConfiguration: true,
      );
    }
  }

  Future<List<PlaceSuggestion>> autocomplete(
    String input, {
    LatLng? near,
  }) async {
    _requireKey();
    final center = near ?? RouteConstants.seattleCenter;
    final json = await _api.postJson(
      Uri.parse('${AppConfig.placesBaseUrl}/places:autocomplete'),
      {
        'input': input,
        'sessionToken': _sessionToken,
        'includedRegionCodes': ['us'],
        'locationBias': {
          'circle': {
            'center': {
              'latitude': center.latitude,
              'longitude': center.longitude,
            },
            'radius': RouteConstants.searchBiasRadiusM,
          },
        },
      },
      headers: {'X-Goog-Api-Key': AppConfig.servicesKey},
    );
    final out = <PlaceSuggestion>[];
    for (final s in (json['suggestions'] as List? ?? const [])) {
      final p = (s as Map)['placePrediction'] as Map?;
      if (p == null) continue;
      final structured = p['structuredFormat'] as Map?;
      final main = (structured?['mainText'] as Map?)?['text'] as String?;
      final secondary =
          (structured?['secondaryText'] as Map?)?['text'] as String?;
      final full = (p['text'] as Map?)?['text'] as String?;
      out.add(PlaceSuggestion(
        primaryText: main ?? full ?? 'Unknown place',
        secondaryText: secondary,
        placeId: p['placeId'] as String?,
      ));
    }
    return out;
  }

  Future<Place> details(String placeId) async {
    _requireKey();
    final uri = Uri.parse('${AppConfig.placesBaseUrl}/places/$placeId')
        .replace(queryParameters: {'sessionToken': _sessionToken});
    final json = await _api.getJson(
      uri,
      headers: _headers('id,displayName,formattedAddress,location'),
    );
    // A details call ends the autocomplete billing session.
    _sessionToken = _newToken();
    final loc = json['location'] as Map;
    return Place(
      placeId: json['id'] as String? ?? placeId,
      name: (json['displayName'] as Map?)?['text'] as String? ??
          json['formattedAddress'] as String? ??
          'Selected place',
      address: json['formattedAddress'] as String?,
      location: LatLng(
        (loc['latitude'] as num).toDouble(),
        (loc['longitude'] as num).toDouble(),
      ),
    );
  }

  /// Resolves free text (e.g. a typed address) to a place.
  Future<Place?> geocode(String text) async {
    _requireKey();
    final json = await _api.getJson(Uri.parse(AppConfig.geocodeUrl).replace(
      queryParameters: {
        'address': text,
        'bounds': '47.3,-122.6|47.9,-122.0',
        'key': AppConfig.servicesKey,
      },
    ));
    final results = json['results'] as List? ?? const [];
    if (results.isEmpty) return null;
    final r = results.first as Map;
    final loc = (r['geometry'] as Map)['location'] as Map;
    final address = r['formatted_address'] as String?;
    return Place(
      placeId: r['place_id'] as String?,
      name: address?.split(',').first ?? text,
      address: address,
      location: LatLng(
        (loc['lat'] as num).toDouble(),
        (loc['lng'] as num).toDouble(),
      ),
    );
  }

  /// Names a tapped map point. Falls back to a "Dropped pin" label.
  Future<Place> reverseGeocode(LatLng point) async {
    try {
      _requireKey();
      final json = await _api.getJson(Uri.parse(AppConfig.geocodeUrl).replace(
        queryParameters: {
          'latlng': '${point.latitude},${point.longitude}',
          'key': AppConfig.servicesKey,
        },
      ));
      // Skip plus-code-only results (e.g. "JMM8+GC Seattle") for a readable name.
      final results = [
        for (final r in (json['results'] as List? ?? const []))
          if (!(((r as Map)['types'] as List?) ?? const []).contains('plus_code')) r,
      ];
      if (results.isNotEmpty) {
        final address = (results.first as Map)['formatted_address'] as String?;
        if (address != null) {
          return Place(
            name: address.split(',').first,
            address: address,
            location: point,
          );
        }
      }
    } catch (_) {
      // Naming is best-effort; the coordinates are what matter.
    }
    return Place(name: 'Dropped pin', location: point);
  }

  /// Rail and major transit stations near [center], nearest first. Used as
  /// "bike to a better line" hubs for mixed routes.
  Future<List<Place>> nearbyTransitHubs(LatLng center, double radiusM) async {
    _requireKey();
    final json = await _api.postJson(
      Uri.parse('${AppConfig.placesBaseUrl}/places:searchNearby'),
      {
        'includedTypes': [
          'light_rail_station',
          'subway_station',
          'train_station',
          'transit_station',
        ],
        'maxResultCount': 10,
        'rankPreference': 'DISTANCE',
        'locationRestriction': {
          'circle': {
            'center': {
              'latitude': center.latitude,
              'longitude': center.longitude,
            },
            'radius': radiusM,
          },
        },
      },
      headers: _headers('places.id,places.displayName,places.location,places.types'),
    );
    final out = <Place>[];
    for (final p in (json['places'] as List? ?? const [])) {
      final m = p as Map;
      final loc = m['location'] as Map;
      out.add(Place(
        placeId: m['id'] as String?,
        name: (m['displayName'] as Map?)?['text'] as String? ?? 'Station',
        location: LatLng(
          (loc['latitude'] as num).toDouble(),
          (loc['longitude'] as num).toDouble(),
        ),
      ));
    }
    return out;
  }
}
