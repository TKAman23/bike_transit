import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:bike_transit/models/place.dart';
import 'package:bike_transit/models/route_option.dart';
import 'package:bike_transit/models/user_preferences.dart';
import 'package:bike_transit/services/api_client.dart';
import 'package:bike_transit/services/location_service.dart';
import 'package:bike_transit/services/places_service.dart';
import 'package:bike_transit/services/route_planner.dart';
import 'package:bike_transit/state/user_data_controller.dart';

enum EndpointField { departure, destination, parking }

enum SheetSegment { route, options }

/// Sheet extent targets requested by state changes (SHEET-5).
enum SheetTarget { max, home, routes, min }

/// State for the map screen: endpoints, the active search field, route list,
/// selection and navigation mode. Widgets render this; they never call APIs.
class MapScreenController extends ChangeNotifier {
  MapScreenController({
    required this.userData,
    RoutePlanner? planner,
    PlacesService? places,
    LocationService? location,
  })  : _places = places ?? PlacesService(),
        location = location ?? LocationService() {
    _planner = planner ?? RoutePlanner(places: _places);
    _lastPrefs = userData.sessionPrefs;
    userData.addListener(_onUserData);
  }

  final UserDataController userData;
  final PlacesService _places;
  final LocationService location;
  late final RoutePlanner _planner;

  Place? departure;
  Place? destination;
  EndpointField activeField = EndpointField.destination;
  SheetSegment segment = SheetSegment.route;
  List<RouteOption> routes = [];
  List<String> notices = [];
  int? expandedIndex;
  bool loading = false;
  String? routeError;
  RouteOption? navRoute;
  LocationAccess? locationAccess;

  bool _appliedNewUser = false;
  late UserPreferences _lastPrefs;
  Timer? _replanDebounce;
  int _planGeneration = 0;

  final _sheetTargets = StreamController<SheetTarget>.broadcast();
  final _searchFocus = StreamController<EndpointField>.broadcast();
  final _messages = StreamController<String>.broadcast();

  Stream<SheetTarget> get sheetTargets => _sheetTargets.stream;
  Stream<EndpointField> get searchFocusRequests => _searchFocus.stream;
  Stream<String> get messages => _messages.stream;

  bool get navigating => navRoute != null;
  UserPreferences get prefs => userData.sessionPrefs;
  RouteOption? get expandedRoute =>
      expandedIndex == null || expandedIndex! >= routes.length
          ? null
          : routes[expandedIndex!];

  Future<void> init() async {
    _onUserData();
    locationAccess = await location.ensurePermission();
    notifyListeners();
    if (locationAccess == LocationAccess.granted) await location.current();
  }

  void _onUserData() {
    // New user: open on Options at full height once we know (SHEET-4/9).
    if (userData.loaded && !_appliedNewUser) {
      _appliedNewUser = true;
      if (userData.isNewUser && destination == null) {
        segment = SheetSegment.options;
        _sheetTargets.add(SheetTarget.max);
        notifyListeners();
      }
    }
    // OPT-4: session preference changes re-rank suggestions immediately.
    if (userData.sessionPrefs != _lastPrefs) {
      final onlyUnits = userData.sessionPrefs.copyWith(units: _lastPrefs.units) == _lastPrefs;
      _lastPrefs = userData.sessionPrefs;
      if (!onlyUnits && destination != null && !navigating) {
        _replanDebounce?.cancel();
        _replanDebounce = Timer(const Duration(milliseconds: 700), plan);
      }
      notifyListeners();
    }
  }

  // ---- Search ----

  Place get currentLocationPlace => Place(
        name: 'Your location',
        location: location.lastKnown ?? const LatLng(0, 0),
        isCurrentLocation: true,
      );

  Future<List<PlaceSuggestion>> suggestions(String query) async {
    final q = query.trim().toLowerCase();
    final out = <PlaceSuggestion>[];
    if (activeField == EndpointField.departure && location.lastKnown != null) {
      out.add(PlaceSuggestion(
        primaryText: 'Your location',
        kind: SuggestionKind.currentLocation,
        place: currentLocationPlace,
      ));
    }
    final recent = userData.recentPlaces
        .where((p) =>
            q.isEmpty ||
            p.name.toLowerCase().contains(q) ||
            (p.address?.toLowerCase().contains(q) ?? false))
        .take(q.isEmpty ? 6 : 3);
    for (final p in recent) {
      out.add(PlaceSuggestion(
        primaryText: p.name,
        secondaryText: p.address,
        place: p,
        kind: SuggestionKind.recent,
      ));
    }
    if (q.isEmpty) return out;
    out.add(PlaceSuggestion(
      primaryText: query.trim(),
      secondaryText: 'Search this address',
      kind: SuggestionKind.typed,
    ));
    try {
      final predictions =
          await _places.autocomplete(query, near: location.lastKnown);
      out.addAll(predictions);
    } on ApiException catch (e) {
      _messages.add('Place search failed: ${e.message}');
    } catch (e) {
      _messages.add('Place search failed. Check your connection.');
    }
    return out;
  }

  Future<void> chooseSuggestion(PlaceSuggestion s) async {
    try {
      final place = switch (s.kind) {
        SuggestionKind.currentLocation => await _freshCurrentLocation(),
        SuggestionKind.recent => s.place,
        SuggestionKind.typed => await _places.geocode(s.primaryText),
        SuggestionKind.prediction => await _places.details(s.placeId!),
      };
      if (place == null) {
        _messages.add('No address found for "${s.primaryText}".');
        return;
      }
      await selectPlace(place);
    } catch (e) {
      _messages.add('Could not load that place: $e');
    }
  }

  Future<Place?> _freshCurrentLocation() async {
    final here = await location.current();
    if (here == null) {
      _messages.add('Location unavailable. Allow location access to use it.');
      return null;
    }
    return currentLocationPlace;
  }

  /// Applies a chosen place to the active field (SRCH-3, ENDPT-3).
  Future<void> selectPlace(Place place) async {
    final field = activeField;
    activeField = EndpointField.destination;
    if (field == EndpointField.parking) {
      final err = await userData.addParking(place.name, place.location);
      _messages.add(err ?? 'Saved bike parking at ${place.name}.');
      segment = SheetSegment.options;
      notifyListeners();
      return;
    }
    if (field == EndpointField.departure) {
      departure = place;
    } else {
      destination = place;
      if (departure == null || departure!.isCurrentLocation) {
        departure = await _freshCurrentLocation();
      }
    }
    unawaited(userData.rememberPlace(place));
    segment = SheetSegment.route;
    _sheetTargets.add(SheetTarget.routes);
    notifyListeners();
    await plan();
  }

  Future<void> dropPin(LatLng point) async {
    if (navigating) return;
    final place = await _places.reverseGeocode(point);
    await selectPlace(place);
  }

  void focusEndpoint(EndpointField field) {
    activeField = field;
    notifyListeners();
    _searchFocus.add(field);
  }

  void cancelActiveField() {
    if (activeField == EndpointField.destination) return;
    activeField = EndpointField.destination;
    notifyListeners();
  }

  void swapEndpoints() {
    if (departure == null || destination == null) return;
    final d = departure;
    departure = destination;
    destination = d;
    notifyListeners();
    plan();
  }

  void clearDestination() {
    _planGeneration++;
    destination = null;
    routes = [];
    notices = [];
    expandedIndex = null;
    routeError = null;
    loading = false;
    _sheetTargets.add(SheetTarget.home);
    notifyListeners();
  }

  // ---- Routes ----

  Future<void> plan() async {
    final from = departure, to = destination;
    if (to == null) return;
    if (from == null) {
      routeError = locationAccess == LocationAccess.granted
          ? 'Waiting for your location. Choose a departure to continue.'
          : 'Location access is off. Tap the departure button to choose a start.';
      routes = [];
      notifyListeners();
      return;
    }
    final generation = ++_planGeneration;
    loading = true;
    routeError = null;
    notifyListeners();
    try {
      final result = await _planner.plan(
        origin: from,
        destination: to,
        prefs: userData.sessionPrefs,
        parking: userData.parking,
        learnedBuckets: userData.learnedBuckets,
      );
      if (generation != _planGeneration) return;
      routes = result.routes;
      notices = result.notices;
      expandedIndex = null;
      routeError = routes.isEmpty ? 'No routes found between these places.' : null;
    } on ApiException catch (e) {
      if (generation != _planGeneration) return;
      routes = [];
      routeError = e.isConfiguration
          ? 'Routing is not configured: ${e.message}'
          : 'Could not get routes: ${e.message}';
    } catch (e) {
      if (generation != _planGeneration) return;
      routes = [];
      routeError = 'Could not get routes. Check your connection and try again.';
      debugPrint('plan failed: $e');
    }
    loading = false;
    notifyListeners();
  }

  void toggleRoute(int index) {
    expandedIndex = expandedIndex == index ? null : index;
    notifyListeners();
  }

  void setSegment(SheetSegment s) {
    if (segment == s) return;
    segment = s;
    if (s == SheetSegment.route) cancelActiveField();
    notifyListeners();
  }

  // ---- Navigation mode ----

  void startNavigation(int index) {
    expandedIndex = index;
    navRoute = routes[index];
    segment = SheetSegment.route;
    _sheetTargets.add(SheetTarget.min);
    notifyListeners();
  }

  /// Leaves en-route mode. A finished trip returns to the home map (NAV-12).
  void stopNavigation({required bool finished}) {
    navRoute = null;
    if (finished) {
      clearDestination();
    } else {
      _sheetTargets.add(SheetTarget.routes);
      notifyListeners();
    }
  }

  void notify(String message) => _messages.add(message);

  @override
  void dispose() {
    _replanDebounce?.cancel();
    userData.removeListener(_onUserData);
    _sheetTargets.close();
    _searchFocus.close();
    _messages.close();
    super.dispose();
  }
}
