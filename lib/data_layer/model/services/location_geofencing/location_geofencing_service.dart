import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../external_data_sources/gps/gps_data_source.dart';
import '../../../../external_data_sources/google_maps/google_maps_data_source.dart';

class LocationGeofencingService {
  final GpsDataSource _gpsDataSource;
  final GoogleMapsDataSource _googleMapsDataSource;

  LocationGeofencingService({
    GpsDataSource? gpsDataSource,
    GoogleMapsDataSource? googleMapsDataSource,
  })  : _gpsDataSource =
      gpsDataSource ?? GpsDataSource(),
        _googleMapsDataSource =
            googleMapsDataSource ?? GoogleMapsDataSource();

  // =========================================================
  // LOCATION
  // =========================================================

  Future<Position> getCurrentLocation() async {
    return await _gpsDataSource.getCurrentPosition();
  }

  Stream<Position> watchLocation() {
    return _gpsDataSource.getPositionStream(
      distanceFilter: 10,
    );
  }

  // =========================================================
  // DISTANCE / GEOFENCING
  // =========================================================

  double getDistanceFromAttraction({
    required Position currentPosition,
    required double attractionLatitude,
    required double attractionLongitude,
  }) {
    return _gpsDataSource.calculateDistance(
      startLatitude: currentPosition.latitude,
      startLongitude: currentPosition.longitude,
      endLatitude: attractionLatitude,
      endLongitude: attractionLongitude,
    );
  }

  bool isInsideGeofence({
    required Position currentPosition,
    required double attractionLatitude,
    required double attractionLongitude,
    required double geofenceRadiusMeters,
  }) {
    final distance = getDistanceFromAttraction(
      currentPosition: currentPosition,
      attractionLatitude: attractionLatitude,
      attractionLongitude: attractionLongitude,
    );

    return distance <= geofenceRadiusMeters;
  }

  Stream<bool> watchGeofence({
    required double attractionLatitude,
    required double attractionLongitude,
    required double geofenceRadiusMeters,
  }) async* {
    await for (final position in watchLocation()) {
      yield isInsideGeofence(
        currentPosition: position,
        attractionLatitude: attractionLatitude,
        attractionLongitude: attractionLongitude,
        geofenceRadiusMeters: geofenceRadiusMeters,
      );
    }
  }

  // =========================================================
  // GOOGLE MAPS
  // =========================================================

  CameraPosition createInitialCameraPosition({
    Position? currentPosition,
  }) {
    if (currentPosition != null) {
      return _googleMapsDataSource.createCameraPosition(
        latitude: currentPosition.latitude,
        longitude: currentPosition.longitude,
        zoom: 14,
      );
    }

    // Default location: Kuala Lumpur
    return _googleMapsDataSource.createCameraPosition(
      latitude: 3.1390,
      longitude: 101.6869,
      zoom: 11,
    );
  }

  Set<Marker> createAttractionMarkers(
      List<Map<String, dynamic>> attractions,
      ) {
    final markers = <Marker>{};

    for (final attraction in attractions) {
      final latitude = attraction['latitude'];
      final longitude = attraction['longitude'];

      if (latitude is! num || longitude is! num) {
        continue;
      }

      markers.add(
        _googleMapsDataSource.createMarker(
          id: attraction['id']?.toString() ?? '',
          latitude: latitude.toDouble(),
          longitude: longitude.toDouble(),
          title:
          attraction['name']?.toString() ??
              'Attraction',
          snippet:
          attraction['category']?.toString(),
        ),
      );
    }

    return markers;
  }

  Future<void> recenterMap({
    required GoogleMapController controller,
    required Position position,
  }) async {
    await _googleMapsDataSource.recenterMap(
      controller: controller,
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }
}