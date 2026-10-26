// Elevation through the Maps JavaScript API on web (the Elevation REST API
// doesn't send CORS headers, so browsers can't call it directly).
export 'web_elevation_stub.dart'
    if (dart.library.js_interop) 'web_elevation_web.dart';
