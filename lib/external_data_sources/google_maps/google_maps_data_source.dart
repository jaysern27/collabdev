import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class GoogleMapsDataSource {
  LatLng createLatLng({
    required double latitude,
    required double longitude,
  }) {
    return LatLng(
      latitude,
      longitude,
    );
  }

  CameraPosition createCameraPosition({
    required double latitude,
    required double longitude,
    double zoom = 15.0,
  }) {
    return CameraPosition(
      target: LatLng(
        latitude,
        longitude,
      ),
      zoom: zoom,
    );
  }

  Marker createMarker({
    required String id,
    required double latitude,
    required double longitude,
    required String title,
    String? snippet,
  }) {
    return Marker(
      markerId: MarkerId(id),
      position: LatLng(
        latitude,
        longitude,
      ),
      infoWindow: InfoWindow(
        title: title,
        snippet: snippet,
      ),
    );
  }

  Future<void> moveCamera({
    required GoogleMapController controller,
    required double latitude,
    required double longitude,
    double zoom = 15.0,
  }) async {
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(
            latitude,
            longitude,
          ),
          zoom: zoom,
        ),
      ),
    );
  }

  Future<void> recenterMap({
    required GoogleMapController controller,
    required double latitude,
    required double longitude,
  }) async {
    await controller.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(
          latitude,
          longitude,
        ),
        14.0,
      ),
    );
  }

  Future<void> openDirections({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.https(
      'www.google.com',
      '/maps/dir/',
      {
        'api': '1',
        'destination': '$latitude,$longitude',
        'travelmode': 'driving',
      },
    );

    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened) {
      throw Exception(
        'Unable to open directions.',
      );
    }
  }
}