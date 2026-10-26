import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:bike_transit/constants/route_constants.dart';
import 'package:bike_transit/models/bike_parking.dart';
import 'package:bike_transit/models/place.dart';
import 'package:bike_transit/models/trip_record.dart';
import 'package:bike_transit/models/user_preferences.dart';
import 'package:bike_transit/models/user_stats.dart';
import 'package:bike_transit/services/stats_service.dart';
import 'package:bike_transit/services/user_repository.dart';

/// The signed-in user's cloud data plus the session-only preference overrides.
///
/// OPT-4: [sessionPrefs] drive route suggestions and start each app session as
/// a copy of [cloudPrefs]. They are written to the cloud only when the rider
/// explicitly saves them.
class UserDataController extends ChangeNotifier {
  UserDataController({
    FirebaseAuth? auth,
    UserRepository Function(String uid)? repositoryFactory,
  }) : _repositoryFactory = repositoryFactory ?? UserRepository.new {
    final a = auth ?? FirebaseAuth.instance;
    _authSub = a.authStateChanges().listen(_onUser);
  }

  final UserRepository Function(String uid) _repositoryFactory;
  StreamSubscription<User?>? _authSub;
  UserRepository? _repo;
  final _stats = const StatsService();

  bool loaded = false;
  String? cloudError;
  UserPreferences? cloudPrefs;
  UserPreferences sessionPrefs = UserPreferences.defaults;
  List<BikeParkingSpot> parking = [];
  List<Place> recentPlaces = [];
  List<TripRecord> trips = [];

  bool get signedIn => _repo != null;

  /// No preferences document in the cloud yet (Q3).
  bool get isNewUser => loaded && cloudError == null && cloudPrefs == null;

  bool get hasSessionChanges =>
      sessionPrefs != (cloudPrefs ?? UserPreferences.defaults);

  UserStats get stats => _stats.compute(trips);

  List<GradeBucket> get learnedBuckets => UserStats.pooledGradeBuckets(
      trips.take(RouteConstants.ridesUsedForPersonalization));

  Future<void> _onUser(User? user) async {
    if (user?.uid == _repo?.uid && loaded) return;
    _repo = user == null ? null : _repositoryFactory(user.uid);
    loaded = false;
    cloudError = null;
    cloudPrefs = null;
    sessionPrefs = UserPreferences.defaults;
    parking = [];
    recentPlaces = [];
    trips = [];
    notifyListeners();
    if (_repo != null) await reload();
  }

  Future<void> reload() async {
    final repo = _repo;
    if (repo == null) return;
    try {
      final results = await Future.wait([
        repo.loadPreferences(),
        repo.loadParking(),
        repo.loadRecentPlaces(),
        repo.loadTrips(),
      ]);
      if (repo != _repo) return;
      cloudPrefs = results[0] as UserPreferences?;
      parking = results[1] as List<BikeParkingSpot>;
      recentPlaces = results[2] as List<Place>;
      trips = results[3] as List<TripRecord>;
      sessionPrefs = cloudPrefs ?? UserPreferences.defaults;
      cloudError = null;
    } catch (e) {
      debugPrint('Loading cloud data failed: $e');
      cloudError = _describe(e);
    }
    loaded = true;
    notifyListeners();
  }

  static String _describe(Object e) {
    final text = '$e';
    if (text.contains('permission-denied')) {
      return 'Cloud sync blocked (permission-denied). Deploy firestore.rules to your Firebase project.';
    }
    if (text.contains('not-found') || text.contains('NOT_FOUND') ||
        text.contains('does not exist')) {
      return 'Firestore is not enabled for this Firebase project yet.';
    }
    if (text.contains('unavailable')) {
      return 'Cloud sync is offline; using defaults until you reconnect.';
    }
    return 'Cloud sync failed: $text';
  }

  void updateSession(UserPreferences prefs) {
    if (prefs == sessionPrefs) return;
    sessionPrefs = prefs;
    notifyListeners();
  }

  void resetSessionToCloud() =>
      updateSession(cloudPrefs ?? UserPreferences.defaults);

  /// Explicitly persists the session values. Returns an error message or null.
  Future<String?> saveSessionToCloud() async {
    final repo = _repo;
    if (repo == null) return 'Sign in to save preferences.';
    try {
      await repo.savePreferences(sessionPrefs);
      cloudPrefs = sessionPrefs;
      cloudError = null;
      notifyListeners();
      return null;
    } catch (e) {
      return _describe(e);
    }
  }

  Future<String?> addParking(String name, LatLng location) async {
    final repo = _repo;
    if (repo == null) return 'Sign in to save bike parking.';
    try {
      final spot = await repo.addParking(
          BikeParkingSpot(id: '', name: name, location: location));
      parking = [...parking, spot];
      notifyListeners();
      return null;
    } catch (e) {
      return _describe(e);
    }
  }

  Future<String?> removeParking(String id) async {
    final repo = _repo;
    if (repo == null) return null;
    final before = parking;
    parking = parking.where((p) => p.id != id).toList();
    notifyListeners();
    try {
      await repo.removeParking(id);
      return null;
    } catch (e) {
      parking = before;
      notifyListeners();
      return _describe(e);
    }
  }

  /// Remembers a searched/selected place for future suggestions (ROUTE-6).
  Future<void> rememberPlace(Place place) async {
    if (place.isCurrentLocation) return;
    recentPlaces = [
      place,
      ...recentPlaces.where((p) => p.key != place.key),
    ].take(20).toList();
    notifyListeners();
    try {
      await _repo?.touchRecentPlace(place);
    } catch (e) {
      debugPrint('Saving recent place failed: $e');
    }
  }

  Future<String?> recordTrip(TripRecord trip) async {
    final repo = _repo;
    trips = [trip, ...trips];
    notifyListeners();
    if (repo == null) return 'Not signed in; trip kept for this session only.';
    try {
      final saved = await repo.addTrip(trip);
      trips = [saved, ...trips.skip(1)];
      notifyListeners();
      await Future.wait([
        repo.touchRecentPlace(trip.destination),
        if (!trip.origin.isCurrentLocation) repo.touchRecentPlace(trip.origin),
      ]);
      return null;
    } catch (e) {
      return _describe(e);
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
