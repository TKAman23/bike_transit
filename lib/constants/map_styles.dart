/// Google Maps style JSON. Both styles hide business POIs so the base map
/// stays bare (MAP-1); the dark style matches the app's dark theme.
class MapStyles {
  MapStyles._();

  static const String light = '''
[
  {"featureType": "poi.business", "stylers": [{"visibility": "off"}]},
  {"featureType": "poi", "elementType": "labels.icon", "stylers": [{"visibility": "off"}]}
]
''';

  static const String dark = '''
[
  {"elementType": "geometry", "stylers": [{"color": "#1d2730"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#8ea3b5"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#1d2730"}]},
  {"featureType": "administrative", "elementType": "geometry", "stylers": [{"color": "#3a4a58"}]},
  {"featureType": "poi", "elementType": "geometry", "stylers": [{"color": "#22303b"}]},
  {"featureType": "poi.business", "stylers": [{"visibility": "off"}]},
  {"featureType": "poi", "elementType": "labels.icon", "stylers": [{"visibility": "off"}]},
  {"featureType": "poi.park", "elementType": "geometry", "stylers": [{"color": "#1f3a2f"}]},
  {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#2f3d49"}]},
  {"featureType": "road", "elementType": "geometry.stroke", "stylers": [{"color": "#1a232b"}]},
  {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#405262"}]},
  {"featureType": "road", "elementType": "labels.text.fill", "stylers": [{"color": "#9fb2c2"}]},
  {"featureType": "transit", "elementType": "geometry", "stylers": [{"color": "#2b3a46"}]},
  {"featureType": "transit.station", "elementType": "labels.text.fill", "stylers": [{"color": "#b5c4d1"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#0e1a24"}]},
  {"featureType": "water", "elementType": "labels.text.fill", "stylers": [{"color": "#4e6577"}]}
]
''';
}
