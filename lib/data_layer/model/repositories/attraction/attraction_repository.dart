import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../services/firestore/firestore_service.dart';
import '../../services/location_geofencing/location_geofencing_service.dart';

class AttractionRepository {
  final FirestoreService _firestoreService;
  final LocationGeofencingService
  _locationGeofencingService;

  static const String _collection = 'attractions';

  AttractionRepository({
    FirestoreService? firestoreService,
    LocationGeofencingService?
    locationGeofencingService,
  })  : _firestoreService =
      firestoreService ?? FirestoreService(),
        _locationGeofencingService =
            locationGeofencingService ??
                LocationGeofencingService();

  // =========================================================
  // ATTRACTION DATA
  // =========================================================

  Future<List<Map<String, dynamic>>>
  getAllAttractions() async {
    final snapshot =
    await _firestoreService.getCollection(
      collection: _collection,
    );

    return snapshot.docs
        .map(
          (doc) => {
        'id': doc.id,
        ...doc.data(),
      },
    )
        .where(
          (attraction) =>
      attraction['isSupported'] == true,
    )
        .toList();
  }

  Future<Map<String, dynamic>?>
  getAttractionById(
      String attractionId,
      ) async {
    final document =
    await _firestoreService.getDocument(
      collection: _collection,
      documentId: attractionId,
    );

    if (!document.exists) {
      return null;
    }

    final data = document.data();

    if (data == null) {
      return null;
    }

    return {
      'id': document.id,
      ...data,
    };
  }

  Future<List<Map<String, dynamic>>>
  getAttractionsByCategory(
      String category,
      ) async {
    final attractions =
    await getAllAttractions();

    return attractions
        .where(
          (attraction) =>
      attraction['category'] == category,
    )
        .toList();
  }

  Future<List<Map<String, dynamic>>>
  searchAttractions(
      String searchText,
      ) async {
    final attractions =
    await getAllAttractions();

    final query =
    searchText.trim().toLowerCase();

    if (query.isEmpty) {
      return attractions;
    }

    return attractions.where((attraction) {
      final name =
      (attraction['name'] ?? '')
          .toString()
          .toLowerCase();

      return name.contains(query);
    }).toList();
  }

  Stream<List<Map<String, dynamic>>>
  watchAttractions() {
    return _firestoreService
        .watchCollection(
      collection: _collection,
    )
        .map(
          (snapshot) => snapshot.docs
          .map(
            (doc) => {
          'id': doc.id,
          ...doc.data(),
        },
      )
          .where(
            (attraction) =>
        attraction['isSupported'] ==
            true,
      )
          .toList(),
    );
  }

  // =========================================================
  // LOCATION
  // =========================================================

  Future<Position> getCurrentLocation() async {
    return await _locationGeofencingService
        .getCurrentLocation();
  }

  double getDistanceFromAttraction({
    required Position currentPosition,
    required double attractionLatitude,
    required double attractionLongitude,
  }) {
    return _locationGeofencingService
        .getDistanceFromAttraction(
      currentPosition: currentPosition,
      attractionLatitude: attractionLatitude,
      attractionLongitude: attractionLongitude,
    );
  }

  // =========================================================
  // MAP
  // =========================================================

  CameraPosition getInitialCameraPosition({
    Position? currentPosition,
  }) {
    return _locationGeofencingService
        .createInitialCameraPosition(
      currentPosition: currentPosition,
    );
  }

  Set<Marker> createAttractionMarkers(
      List<Map<String, dynamic>> attractions,
      ) {
    return _locationGeofencingService
        .createAttractionMarkers(
      attractions,
    );
  }

  Future<void> recenterMap({
    required GoogleMapController controller,
    required Position position,
  }) async {
    await _locationGeofencingService.recenterMap(
      controller: controller,
      position: position,
    );
  }

  // =========================================================
  // GEOFENCE (UC03 – Configure Geofence)
  // =========================================================

  // UC03 A2.3/A2.6: the Admin sets or updates the geofence
  // location and radius, or toggles its active status. The
  // geofence location defaults to the attraction's own map pin
  // when the Admin hasn't set a distinct one.
  Future<void> updateGeofenceConfig({
    required String attractionId,
    required double radiusMeters,
    required bool active,
    double? latitude,
    double? longitude,
  }) async {
    await _firestoreService.updateDocument(
      collection: _collection,
      documentId: attractionId,
      data: {
        'geofenceRadiusMeters': radiusMeters,
        'geofenceActive': active,
        if (latitude != null) 'geofenceLatitude': latitude,
        if (longitude != null) 'geofenceLongitude': longitude,
      },
    );
  }

  // The geofence's centre point: the Admin-configured
  // geofenceLatitude/geofenceLongitude when set, otherwise the
  // attraction's own map location.
  static Map<String, double>? geofenceCenter(
      Map<String, dynamic> attraction,
      ) {
    final latitude =
        attraction['geofenceLatitude'] ?? attraction['latitude'];
    final longitude =
        attraction['geofenceLongitude'] ?? attraction['longitude'];

    if (latitude is! num || longitude is! num) {
      return null;
    }

    return {
      'latitude': latitude.toDouble(),
      'longitude': longitude.toDouble(),
    };
  }

  // Attractions within [radiusKm] of the tourist that have an
  // active, configured geofence (UC02 constraint C1).
  Future<List<Map<String, dynamic>>>
  getGeofenceEnabledAttractionsNear(
      Position position, {
        double radiusKm = 5.0,
      }) async {
    final attractions = await getAllAttractions();

    return attractions.where((attraction) {
      if (attraction['geofenceActive'] != true) {
        return false;
      }

      final radius = attraction['geofenceRadiusMeters'];

      if (radius is! num || radius <= 0) {
        return false;
      }

      final center = geofenceCenter(attraction);

      if (center == null) {
        return false;
      }

      final distanceKm = getDistanceFromAttraction(
            currentPosition: position,
            attractionLatitude: center['latitude']!,
            attractionLongitude: center['longitude']!,
          ) /
          1000.0;

      return distanceKm < radiusKm;
    }).toList();
  }
}