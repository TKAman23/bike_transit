// Loads the Google Maps JS SDK on web; a no-op on mobile/desktop.
export 'web_maps_loader_stub.dart'
    if (dart.library.js_interop) 'web_maps_loader_web.dart';
