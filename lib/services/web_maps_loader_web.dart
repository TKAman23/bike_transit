import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Injects the Maps JS script with the key from build-time config, so the key
/// never has to live in web/index.html.
Future<void> loadGoogleMapsJs(String apiKey) {
  if (apiKey.isEmpty) return Future.value();
  final done = Completer<void>();
  final script = web.HTMLScriptElement()
    ..src = 'https://maps.googleapis.com/maps/api/js?key=$apiKey'
    ..async = true;
  script.onload = ((web.Event _) => done.complete()).toJS;
  script.onerror = ((web.Event _) => done.complete()).toJS;
  web.document.head!.append(script);
  return done.future;
}
