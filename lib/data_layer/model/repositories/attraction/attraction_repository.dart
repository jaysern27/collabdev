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
}