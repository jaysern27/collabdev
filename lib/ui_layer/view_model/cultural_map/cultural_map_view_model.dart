import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../data_layer/model/repositories/attraction/attraction_repository.dart';
import '../../../data_layer/model/services/location_geofencing/location_geofencing_service.dart';
import '../../../external_data_sources/google_maps/google_maps_data_source.dart';

class CulturalMapViewModel extends ChangeNotifier {
  final AttractionRepository _attractionRepository;
  final LocationGeofencingService _locationService;
  final GoogleMapsDataSource _googleMapsDataSource;

  CulturalMapViewModel({
    AttractionRepository? attractionRepository,
    LocationGeofencingService? locationService,
    GoogleMapsDataSource? googleMapsDataSource,
  })  : _attractionRepository =
      attractionRepository ?? AttractionRepository(),
        _locationService =
            locationService ?? LocationGeofencingService(),
        _googleMapsDataSource =
            googleMapsDataSource ?? GoogleMapsDataSource();

  List<Map<String, dynamic>> _allAttractions = [];

  List<Map<String, dynamic>> _filteredAttractions = [];

  Position? _currentPosition;

  String _selectedCategory = 'All';

  bool _isLoading = false;

  String? _errorMessage;

  List<Map<String, dynamic>> get attractions =>
      _filteredAttractions;

  Position? get currentPosition => _currentPosition;

  String get selectedCategory => _selectedCategory;

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  bool get hasLocation => _currentPosition != null;

  // Load attractions from Firestore
  Future<void> loadAttractions() async {
    _setLoading(true);

    try {
      _errorMessage = null;

      _allAttractions =
      await _attractionRepository.getAllAttractions();

      _applyCurrentFilter();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // Get user's current GPS location
  Future<void> loadCurrentLocation() async {
    try {
      _errorMessage = null;

      _currentPosition =
      await _locationService.getCurrentLocation();

      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();

      notifyListeners();
    }
  }

  // Change cultural attraction category
  void filterByCategory(String category) {
    _selectedCategory = category;

    _applyCurrentFilter();

    notifyListeners();
  }

  void _applyCurrentFilter() {
    if (_selectedCategory == 'All') {
      _filteredAttractions =
      List<Map<String, dynamic>>.from(
        _allAttractions,
      );

      return;
    }

    _filteredAttractions =
        _allAttractions.where((attraction) {
          return attraction['category'] ==
              _selectedCategory;
        }).toList();
  }

  // Search attraction name
  void searchAttractions(String searchText) {
    final query = searchText.trim().toLowerCase();

    if (query.isEmpty) {
      _applyCurrentFilter();

      notifyListeners();

      return;
    }

    final source = _selectedCategory == 'All'
        ? _allAttractions
        : _allAttractions.where((attraction) {
      return attraction['category'] ==
          _selectedCategory;
    }).toList();

    _filteredAttractions =
        source.where((attraction) {
          final name =
          (attraction['name'] ?? '')
              .toString()
              .toLowerCase();

          return name.contains(query);
        }).toList();

    notifyListeners();
  }

  // Convert attractions into Google Maps markers
  Set<Marker> getMarkers() {
    final markers = <Marker>{};

    for (final attraction in _filteredAttractions) {
      final latitude = attraction['latitude'];
      final longitude = attraction['longitude'];

      if (latitude is! num || longitude is! num) {
        continue;
      }

      markers.add(
        _googleMapsDataSource.createMarker(
          id: attraction['id'].toString(),
          latitude: latitude.toDouble(),
          longitude: longitude.toDouble(),
          title: attraction['name']?.toString() ??
              'Attraction',
          snippet:
          attraction['category']?.toString(),
        ),
      );
    }

    return markers;
  }

  // Initial camera position
  CameraPosition getInitialCameraPosition() {
    if (_currentPosition != null) {
      return _googleMapsDataSource
          .createCameraPosition(
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        zoom: 14,
      );
    }

    // Default Malaysia / Kuala Lumpur location
    return _googleMapsDataSource
        .createCameraPosition(
      latitude: 3.1390,
      longitude: 101.6869,
      zoom: 11,
    );
  }

  // Move map back to user's current position
  Future<void> recenterMap(
      GoogleMapController controller,
      ) async {
    if (_currentPosition == null) {
      await loadCurrentLocation();
    }

    final position = _currentPosition;

    if (position == null) {
      return;
    }

    await _googleMapsDataSource.recenterMap(
      controller: controller,
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  void clearError() {
    _errorMessage = null;

    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;

    notifyListeners();
  }
}