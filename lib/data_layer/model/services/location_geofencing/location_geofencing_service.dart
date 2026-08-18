import 'package:geolocator/geolocator.dart';

import '../../../../external_data_sources/gps/gps_data_source.dart';

class LocationGeofencingService {
  final GpsDataSource _gpsDataSource;

  LocationGeofencingService({
    GpsDataSource? gpsDataSource,
  }) : _gpsDataSource =
      gpsDataSource ?? GpsDataSource();

  Future<Position> getCurrentLocation() async {
    return await _gpsDataSource.getCurrentPosition();
  }

  Stream<Position> watchLocation() {
    return _gpsDataSource.getPositionStream(
      distanceFilter: 10,
    );
  }

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
}