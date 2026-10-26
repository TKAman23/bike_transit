import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:bike_transit/models/bike_parking.dart';
import 'package:bike_transit/models/place.dart';
import 'package:bike_transit/models/trip_record.dart';
import 'package:bike_transit/models/user_preferences.dart';

/// Firestore access for one signed-in user. Schema (approved 2026-10-25):
///
/// - `users/{uid}`: route preferences (+ `createdAt`). Missing doc ⇒ new user.
/// - `users/{uid}/bikeParking/{id}`: `name`, `lat`, `lng`
/// - `users/{uid}/recentPlaces/{placeKey}`: `name`, `address`, `lat`, `lng`, `lastUsedAt`
/// - `users/{uid}/trips/{id}`: see [TripRecord.toMap]
class UserRepository {
  UserRepository(this.uid, {FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final String uid;
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> get _user =>
      _db.collection('users').doc(uid);

  /// Returns null when the user has never saved preferences.
  Future<UserPreferences?> loadPreferences() async {
    final snap = await _user.get();
    final data = snap.data();
    return data == null ? null : UserPreferences.fromMap(data);
  }

  Future<void> savePreferences(UserPreferences prefs) async {
    final snap = await _user.get();
    await _user.set({
      ...prefs.toMap(),
      if (!snap.exists) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ---- Bike parking ----

  Future<List<BikeParkingSpot>> loadParking() async {
    final q = await _user.collection('bikeParking').get();
    return [for (final d in q.docs) BikeParkingSpot.fromMap(d.id, d.data())];
  }

  Future<BikeParkingSpot> addParking(BikeParkingSpot spot) async {
    final ref = await _user.collection('bikeParking').add(spot.toMap());
    return BikeParkingSpot(id: ref.id, name: spot.name, location: spot.location);
  }

  Future<void> removeParking(String id) =>
      _user.collection('bikeParking').doc(id).delete();

  // ---- Recent places ----

  Future<List<Place>> loadRecentPlaces({int limit = 20}) async {
    final q = await _user
        .collection('recentPlaces')
        .orderBy('lastUsedAt', descending: true)
        .limit(limit)
        .get();
    return [for (final d in q.docs) Place.fromMap(d.data())];
  }

  Future<void> touchRecentPlace(Place place) => _user
      .collection('recentPlaces')
      .doc(Uri.encodeComponent(place.key))
      .set({...place.toMap(), 'lastUsedAt': FieldValue.serverTimestamp()});

  // ---- Trips ----

  Future<List<TripRecord>> loadTrips({int limit = 100}) async {
    final q = await _user
        .collection('trips')
        .orderBy('startedAt', descending: true)
        .limit(limit)
        .get();
    return [for (final d in q.docs) TripRecord.fromMap(d.id, d.data())];
  }

  Future<TripRecord> addTrip(TripRecord trip) async {
    final ref = await _user.collection('trips').add(trip.toMap());
    return TripRecord.fromMap(ref.id, trip.toMap());
  }
}
