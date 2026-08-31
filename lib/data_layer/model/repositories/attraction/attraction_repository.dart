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

  /// Admin-only: returns every attraction regardless of isSupported, so
  /// UC03's Manage Attractions screen can still find (and re-enable) a
  /// disabled attraction. getAllAttractions() intentionally hides
  /// disabled attractions for the Tourist-facing map (UC01).
  Future<List<Map<String, dynamic>>>
  getAllAttractionsForAdmin() async {
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
  // ADMIN: ATTRACTION MANAGEMENT (UC03 A1 / FR-CMF7)
  // =========================================================

  /// Creates a new attraction record. Coordinates and category must be
  /// present before the record can be enabled on the map (UC03 C1).
  Future<String> createAttraction(
      Map<String, dynamic> attractionData,
      ) async {
    _validateAttractionData(attractionData);

    final document = await _firestoreService.addDocument(
      collection: _collection,
      data: {
        ...attractionData,
        'isSupported': attractionData['isSupported'] ?? false,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      },
    );

    return document.id;
  }

  Future<void> updateAttraction({
    required String attractionId,
    required Map<String, dynamic> attractionData,
  }) async {
    _validateAttractionData(attractionData);

    await _firestoreService.updateDocument(
      collection: _collection,
      documentId: attractionId,
      data: {
        ...attractionData,
        'updatedAt': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Enables/disables an attraction on the Tourist-facing map (UC03 M1).
  Future<void> setAttractionEnabled({
    required String attractionId,
    required bool isSupported,
  }) async {
    await _firestoreService.updateDocument(
      collection: _collection,
      documentId: attractionId,
      data: {
        'isSupported': isSupported,
        'updatedAt': DateTime.now().toIso8601String(),
      },
    );
  }

  /// UC03 C1: an attraction needs validated coordinates and a confirmed
  /// category before it may be enabled.
  void _validateAttractionData(Map<String, dynamic> data) {
    final latitude = data['latitude'];
    final longitude = data['longitude'];
    final category = data['category']?.toString();

    final hasValidCoordinates =
        latitude is num && longitude is num;

    final hasCategory = category != null && category.isNotEmpty;

    if (!hasValidCoordinates || !hasCategory) {
      throw Exception(
        'Invalid or duplicate attraction data. Please correct the '
            'highlighted fields.',
      );
    }
  }

  // =========================================================
  // ADMIN: GEOFENCE CONFIGURATION (UC03 A2 / FR-GEA9)
  // =========================================================

  /// Saves the per-attraction geofence used by UC02's entry check (C2).
  /// [radiusMeters] must already have been validated by the caller against
  /// EnvironmentSettingsRepository's allowable range (UC03 E2).
  Future<void> updateGeofence({
    required String attractionId,
    required double radiusMeters,
    required bool isActive,
  }) async {
    await _firestoreService.updateDocument(
      collection: _collection,
      documentId: attractionId,
      data: {
        'geofence': {
          'radiusMeters': radiusMeters,
          'isActive': isActive,
        },
        'updatedAt': DateTime.now().toIso8601String(),
      },
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
}