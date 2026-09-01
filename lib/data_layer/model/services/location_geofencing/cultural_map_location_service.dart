import 'package:geolocator/geolocator.dart';

class CulturalMapLocationService {
  // Default pilot area: Kuala Lumpur.
  static const double defaultLatitude = 3.1390;
  static const double defaultLongitude = 101.6869;

  /// Check whether the device location service is enabled.
  Future<bool> isLocationServiceEnabled() async {
    return Geolocator.isLocationServiceEnabled();
  }

  /// Check the current location permission.
  Future<LocationPermission> checkPermission() async {
    return Geolocator.checkPermission();
  }

  /// Request location permission from the Tourist.
  Future<LocationPermission> requestPermission() async {
    return Geolocator.requestPermission();
  }

  /// Gets the Tourist's current GPS position.
  ///
  /// Returns null when:
  /// - location service is disabled
  /// - permission is denied
  /// - permission is permanently denied
  Future<Position?> getCurrentPosition() async {
    final serviceEnabled =
    await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      return null;
    }

    var permission =
    await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission =
      await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      return null;
    }

    if (permission ==
        LocationPermission.deniedForever) {
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(
            seconds: 15,
          ),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  /// Calculates distance between the Tourist and
  /// an attraction.
  ///
  /// Returns distance in metres.
  double calculateDistanceInMetres({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  /// Calculates distance in kilometres.
  double calculateDistanceInKm({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    final metres =
    calculateDistanceInMetres(
      startLatitude: startLatitude,
      startLongitude: startLongitude,
      endLatitude: endLatitude,
      endLongitude: endLongitude,
    );

    return metres / 1000.0;
  }

  /// Determines whether an attraction is inside
  /// the selected map radius.
  bool isWithinRadius({
    required double userLatitude,
    required double userLongitude,
    required double attractionLatitude,
    required double attractionLongitude,
    double radiusKm = 20.0,
  }) {
    final distance =
    calculateDistanceInKm(
      startLatitude: userLatitude,
      startLongitude: userLongitude,
      endLatitude: attractionLatitude,
      endLongitude: attractionLongitude,
    );

    return distance <= radiusKm;
  }

  /// Human-readable distance for the UI.
  String formatDistance(
      double distanceKm,
      ) {
    if (distanceKm < 1) {
      final metres =
      (distanceKm * 1000).round();

      return '$metres m away';
    }

    return '${distanceKm.toStringAsFixed(1)} km away';
  }

  /// Used when location permission is unavailable.
  Map<String, double> getDefaultPilotArea() {
    return {
      'latitude': defaultLatitude,
      'longitude': defaultLongitude,
    };
  }

  /// Returns true when the application can access
  /// the Tourist's location.
  Future<bool> hasLocationPermission() async {
    final permission =
    await Geolocator.checkPermission();

    return permission ==
        LocationPermission.whileInUse ||
        permission ==
            LocationPermission.always;
  }

  /// Opens Android/iOS app settings when permission
  /// has been denied permanently.
  Future<bool> openAppSettings() async {
    return Geolocator.openAppSettings();
  }

  /// Opens device location settings.
  Future<bool> openLocationSettings() async {
    return Geolocator.openLocationSettings();
  }
}