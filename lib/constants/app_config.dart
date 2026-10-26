/// Environment configuration. Values are injected at build time with
/// `--dart-define-from-file=config/keys.json` (see config/keys.example.json);
/// nothing secret is stored in source.
class AppConfig {
  AppConfig._();

  /// Maps SDK + Firebase key (can be restricted to the Android/iOS app).
  static const String mapsApiKey = String.fromEnvironment('MAPS_API_KEY');

  /// Optional separate key for the REST web services (Routes, Places,
  /// Geocoding, Elevation). These calls come from the device without a web
  /// referrer, so this key must not be HTTP-referrer restricted.
  static const String _servicesKey = String.fromEnvironment('MAPS_SERVICES_KEY');
  static String get servicesKey =>
      _servicesKey.isNotEmpty ? _servicesKey : mapsApiKey;

  static const String obaApiKey = String.fromEnvironment('OBA_API_KEY');

  static bool get hasMapsKey => mapsApiKey.isNotEmpty;
  static bool get hasServicesKey => servicesKey.isNotEmpty;
  static bool get hasObaKey => obaApiKey.isNotEmpty;

  static const String routesBaseUrl =
      'https://routes.googleapis.com/directions/v2:computeRoutes';
  static const String placesBaseUrl = 'https://places.googleapis.com/v1';
  static const String elevationUrl =
      'https://maps.googleapis.com/maps/api/elevation/json';
  static const String geocodeUrl =
      'https://maps.googleapis.com/maps/api/geocode/json';
  static const String obaBaseUrl =
      'https://api.pugetsound.onebusaway.org/api/where';
}
