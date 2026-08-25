import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../data_layer/model/repositories/attraction/attraction_repository.dart';

class CulturalMapViewModel
    extends ChangeNotifier {

  // =========================================================
  // MODEL DEPENDENCY
  // =========================================================

  final AttractionRepository
  _attractionRepository;

  CulturalMapViewModel({
    AttractionRepository?
    attractionRepository,
  }) : _attractionRepository =
      attractionRepository ??
          AttractionRepository();

  // =========================================================
  // DATA
  // =========================================================

  List<Map<String, dynamic>>
  _allAttractions = [];

  List<Map<String, dynamic>>
  _filteredAttractions = [];

  Position? _currentPosition;

  // =========================================================
  // FILTER STATE
  // =========================================================

  String _selectedCategory = 'All';

  String _searchText = '';

  // =========================================================
  // UI STATE
  // =========================================================

  bool _isLoading = false;

  String? _errorMessage;

  // =========================================================
  // GETTERS FOR DATA BINDING
  // =========================================================

  List<Map<String, dynamic>>
  get attractions =>
      _filteredAttractions;

  Position? get currentPosition =>
      _currentPosition;

  String get selectedCategory =>
      _selectedCategory;

  String get searchText =>
      _searchText;

  bool get isLoading =>
      _isLoading;

  String? get errorMessage =>
      _errorMessage;

  bool get hasLocation =>
      _currentPosition != null;

  // =========================================================
  // LOAD ATTRACTIONS
  // =========================================================

  Future<void> loadAttractions() async {
    _setLoading(true);

    try {
      _errorMessage = null;

      _allAttractions =
      await _attractionRepository
          .getAllAttractions();

      _applyFilters();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // =========================================================
  // LOAD CURRENT LOCATION
  // =========================================================

  Future<void> loadCurrentLocation() async {
    try {
      _errorMessage = null;

      _currentPosition =
      await _attractionRepository
          .getCurrentLocation();

      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();

      notifyListeners();
    }
  }

  // =========================================================
  // CATEGORY FILTER
  // =========================================================

  void filterByCategory(
      String category,
      ) {
    _selectedCategory = category;

    _applyFilters();

    notifyListeners();
  }

  // =========================================================
  // SEARCH
  // =========================================================

  void searchAttractions(
      String searchText,
      ) {
    _searchText = searchText;

    _applyFilters();

    notifyListeners();
  }

  // =========================================================
  // APPLY ALL FILTERS
  // =========================================================

  void _applyFilters() {
    Iterable<Map<String, dynamic>>
    result = _allAttractions;

    // Category
    if (_selectedCategory != 'All') {
      result = result.where(
            (attraction) {
          return attraction['category']
              ?.toString() ==
              _selectedCategory;
        },
      );
    }

    // Search
    final query =
    _searchText.trim().toLowerCase();

    if (query.isNotEmpty) {
      result = result.where(
            (attraction) {
          final name =
              attraction['name']
                  ?.toString()
                  .toLowerCase() ??
                  '';

          return name.contains(query);
        },
      );
    }

    _filteredAttractions =
        result.toList();
  }

  // =========================================================
  // GOOGLE MAP MARKERS
  // =========================================================

  Set<Marker> getMarkers() {
    return _attractionRepository
        .createAttractionMarkers(
      _filteredAttractions,
    );
  }

  // =========================================================
  // INITIAL MAP POSITION
  // =========================================================

  CameraPosition
  getInitialCameraPosition() {
    return _attractionRepository
        .getInitialCameraPosition(
      currentPosition:
      _currentPosition,
    );
  }

  // =========================================================
  // RECENTER MAP
  // =========================================================

  Future<void> recenterMap(
      GoogleMapController controller,
      ) async {
    if (_currentPosition == null) {
      await loadCurrentLocation();
    }

    final position =
        _currentPosition;

    if (position == null) {
      return;
    }

    await _attractionRepository
        .recenterMap(
      controller: controller,
      position: position,
    );
  }

  // =========================================================
  // CLEAR FILTERS
  // =========================================================

  void resetFilters() {
    _selectedCategory = 'All';
    _searchText = '';

    _applyFilters();

    notifyListeners();
  }

  // =========================================================
  // ERROR
  // =========================================================

  void clearError() {
    _errorMessage = null;

    notifyListeners();
  }

  // =========================================================
  // LOADING
  // =========================================================

  void _setLoading(
      bool value,
      ) {
    _isLoading = value;

    notifyListeners();
  }
}