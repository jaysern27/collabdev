import 'package:flutter/foundation.dart';

import '../../../data_layer/model/repositories/attraction/cultural_map_repository.dart';
import '../../../data_layer/model/repositories/attraction/cultural_map_saved_repository.dart';
import '../../../data_layer/model/services/location_geofencing/cultural_map_location_service.dart';

class CulturalMapViewModel extends ChangeNotifier {
  static const double selectedAreaRadiusKm = 20.0;

  final CulturalMapRepository _repository;
  final CulturalMapLocationService _locationService;
  final CulturalMapSavedRepository _savedRepository;

  CulturalMapViewModel({
    CulturalMapRepository? repository,
    CulturalMapLocationService? locationService,
    CulturalMapSavedRepository? savedRepository,
  })  : _repository =
      repository ?? CulturalMapRepository(),
        _locationService =
            locationService ??
                CulturalMapLocationService(),
        _savedRepository =
            savedRepository ??
                CulturalMapSavedRepository();

  // ============================================================
  // STATE
  // ============================================================

  bool _isLoading = false;
  bool _isLocating = false;
  bool _locationAvailable = false;
  bool _usingDefaultArea = true;
  bool _isSavingAttraction = false;

  String? _errorMessage;

  double _currentLatitude =
      CulturalMapLocationService.defaultLatitude;

  double _currentLongitude =
      CulturalMapLocationService.defaultLongitude;

  String _searchQuery = '';

  final Set<String> _selectedCategories = {};

  List<Map<String, dynamic>> _allAttractions = [];
  List<Map<String, dynamic>> _visibleAttractions = [];

  Map<String, dynamic>? _selectedAttraction;

  Set<String> _favouriteIds = <String>{};
  Set<String> _visitListIds = <String>{};

  // ============================================================
  // GETTERS
  // ============================================================

  bool get isLoading => _isLoading;

  bool get isLocating => _isLocating;

  bool get locationAvailable =>
      _locationAvailable;

  bool get usingDefaultArea =>
      _usingDefaultArea;

  bool get isSavingAttraction =>
      _isSavingAttraction;

  bool get isLoggedIn =>
      _savedRepository.isLoggedIn;

  String? get errorMessage =>
      _errorMessage;

  double get currentLatitude =>
      _currentLatitude;

  double get currentLongitude =>
      _currentLongitude;

  String get searchQuery =>
      _searchQuery;

  Set<String> get selectedCategories =>
      Set.unmodifiable(
        _selectedCategories,
      );

  Set<String> get favouriteIds =>
      Set.unmodifiable(
        _favouriteIds,
      );

  Set<String> get visitListIds =>
      Set.unmodifiable(
        _visitListIds,
      );

  List<String> get availableCategories =>
      CulturalMapRepository
          .supportedCategories;

  List<Map<String, dynamic>> get allAttractions =>
      List.unmodifiable(
        _allAttractions,
      );

  List<Map<String, dynamic>> get visibleAttractions =>
      List.unmodifiable(
        _visibleAttractions,
      );

  Map<String, dynamic>? get selectedAttraction =>
      _selectedAttraction;

  bool get hasActiveFilter =>
      _selectedCategories.isNotEmpty ||
          _searchQuery.trim().isNotEmpty;

  bool get hasAttractions =>
      _visibleAttractions.isNotEmpty;

  int get resultCount =>
      _visibleAttractions.length;

  // ============================================================
  // INITIALISE
  // ============================================================

  Future<void> initialise() async {
    _setLoading(true);

    try {
      _errorMessage = null;

      await _loadCurrentLocation();

      await _loadAttractions();

      await loadSavedAttractions();
    } catch (e) {
      _errorMessage =
          _cleanError(e);
    } finally {
      _setLoading(false);
    }
  }

  // ============================================================
  // LOCATION
  // ============================================================

  Future<void> _loadCurrentLocation() async {
    _isLocating = true;

    notifyListeners();

    try {
      final position =
      await _locationService
          .getCurrentPosition();

      if (position != null) {
        _currentLatitude =
            position.latitude;

        _currentLongitude =
            position.longitude;

        _locationAvailable = true;

        _usingDefaultArea = false;
      } else {
        _useDefaultPilotArea();
      }
    } catch (_) {
      _useDefaultPilotArea();
    } finally {
      _isLocating = false;

      notifyListeners();
    }
  }

  Future<void> refreshCurrentLocation() async {
    if (_isLocating) {
      return;
    }

    _isLocating = true;

    _errorMessage = null;

    notifyListeners();

    try {
      final position =
      await _locationService
          .getCurrentPosition();

      if (position == null) {
        _useDefaultPilotArea();

        _errorMessage =
        'Current location unavailable. '
            'Showing the default Kuala Lumpur pilot area.';
      } else {
        _currentLatitude =
            position.latitude;

        _currentLongitude =
            position.longitude;

        _locationAvailable = true;

        _usingDefaultArea = false;
      }

      _applyFilters();
    } catch (_) {
      _useDefaultPilotArea();

      _errorMessage =
      'Unable to obtain current location.';
    } finally {
      _isLocating = false;

      notifyListeners();
    }
  }

  // ============================================================
  // LOAD ATTRACTIONS
  // ============================================================

  Future<void> _loadAttractions() async {
    _allAttractions =
    await _repository
        .getSupportedAttractions();

    _applyFilters();
  }

  Future<void> refreshAttractions() async {
    _setLoading(true);

    try {
      _errorMessage = null;

      _allAttractions =
      await _repository
          .getSupportedAttractions();

      _applyFilters();

      await loadSavedAttractions();
    } catch (e) {
      _errorMessage =
          _cleanError(e);
    } finally {
      _setLoading(false);
    }
  }

  // ============================================================
  // SEARCH
  // ============================================================

  void setSearchQuery(
      String value,
      ) {
    _searchQuery = value;

    _applyFilters();
  }

  void clearSearch() {
    if (_searchQuery.isEmpty) {
      return;
    }

    _searchQuery = '';

    _applyFilters();
  }

  // ============================================================
  // CATEGORY FILTER
  // ============================================================

  void toggleCategory(
      String category,
      ) {
    if (_selectedCategories
        .contains(category)) {
      _selectedCategories
          .remove(category);
    } else {
      _selectedCategories
          .add(category);
    }

    _applyFilters();
  }

  bool isCategorySelected(
      String category,
      ) {
    return _selectedCategories
        .contains(category);
  }

  void clearFilters() {
    _selectedCategories.clear();

    _searchQuery = '';

    _applyFilters();
  }

  // ============================================================
  // SELECT ATTRACTION
  // ============================================================

  void selectAttraction(
      Map<String, dynamic> attraction,
      ) {
    _selectedAttraction =
    Map<String, dynamic>.from(
      attraction,
    );

    notifyListeners();
  }

  void clearSelectedAttraction() {
    _selectedAttraction = null;

    notifyListeners();
  }

  // ============================================================
  // GET ATTRACTION
  // ============================================================

  Future<Map<String, dynamic>?> getAttractionById(
      String attractionId,
      ) async {
    try {
      return await _repository
          .getAttractionById(
        attractionId,
      );
    } catch (e) {
      _errorMessage =
          _cleanError(e);

      notifyListeners();

      return null;
    }
  }

  // ============================================================
  // FAVOURITES
  // ============================================================

  Future<void> loadSavedAttractions() async {
    if (!_savedRepository.isLoggedIn) {
      _favouriteIds =
      <String>{};

      _visitListIds =
      <String>{};

      notifyListeners();

      return;
    }

    try {
      _favouriteIds =
      await _savedRepository
          .getFavouriteIds();

      _visitListIds =
      await _savedRepository
          .getVisitListIds();

      notifyListeners();
    } catch (_) {
      _errorMessage =
      'Unable to load saved attractions.';

      notifyListeners();
    }
  }

  bool isFavourite(
      String attractionId,
      ) {
    return _favouriteIds
        .contains(
      attractionId,
    );
  }

  bool isInVisitList(
      String attractionId,
      ) {
    return _visitListIds
        .contains(
      attractionId,
    );
  }

  Future<bool> toggleFavourite(
      Map<String, dynamic> attraction,
      ) async {
    final attractionId =
        attraction['id']
            ?.toString()
            .trim() ??
            '';

    if (!_savedRepository.isLoggedIn) {
      _errorMessage =
      'Please sign in to save favourites.';

      notifyListeners();

      return false;
    }

    if (attractionId.isEmpty) {
      _errorMessage =
      'Attraction ID is missing.';

      notifyListeners();

      return false;
    }

    _isSavingAttraction = true;

    _errorMessage = null;

    notifyListeners();

    try {
      if (_favouriteIds
          .contains(attractionId)) {
        await _savedRepository
            .removeFromFavourites(
          attractionId:
          attractionId,
        );

        _favouriteIds
            .remove(
          attractionId,
        );
      } else {
        await _savedRepository
            .addToFavourites(
          attraction: attraction,
        );

        _favouriteIds
            .add(
          attractionId,
        );
      }

      return true;
    } catch (_) {
      _errorMessage =
      'Unable to update favourite.';

      return false;
    } finally {
      _isSavingAttraction = false;

      notifyListeners();
    }
  }

  Future<bool> toggleVisitList(
      Map<String, dynamic> attraction,
      ) async {
    final attractionId =
        attraction['id']
            ?.toString()
            .trim() ??
            '';

    if (!_savedRepository.isLoggedIn) {
      _errorMessage =
      'Please sign in to use the visit list.';

      notifyListeners();

      return false;
    }

    if (attractionId.isEmpty) {
      _errorMessage =
      'Attraction ID is missing.';

      notifyListeners();

      return false;
    }

    _isSavingAttraction = true;

    _errorMessage = null;

    notifyListeners();

    try {
      if (_visitListIds
          .contains(attractionId)) {
        await _savedRepository
            .removeFromVisitList(
          attractionId:
          attractionId,
        );

        _visitListIds
            .remove(
          attractionId,
        );
      } else {
        await _savedRepository
            .addToVisitList(
          attraction: attraction,
        );

        _visitListIds
            .add(
          attractionId,
        );
      }

      return true;
    } catch (_) {
      _errorMessage =
      'Unable to update visit list.';

      return false;
    } finally {
      _isSavingAttraction = false;

      notifyListeners();
    }
  }

  // ============================================================
  // DISTANCE
  // ============================================================

  double? distanceKmFor(
      Map<String, dynamic> attraction,
      ) {
    final latitude =
    _toDouble(
      attraction['latitude'],
    );

    final longitude =
    _toDouble(
      attraction['longitude'],
    );

    if (latitude == null ||
        longitude == null) {
      return null;
    }

    return _locationService
        .calculateDistanceInKm(
      startLatitude:
      _currentLatitude,
      startLongitude:
      _currentLongitude,
      endLatitude:
      latitude,
      endLongitude:
      longitude,
    );
  }

  String distanceTextFor(
      Map<String, dynamic> attraction,
      ) {
    final distance =
    distanceKmFor(
      attraction,
    );

    if (distance == null) {
      return 'Distance unavailable';
    }

    return _locationService
        .formatDistance(
      distance,
    );
  }

  // ============================================================
  // BASIC ATTRACTION DATA
  // ============================================================

  String attractionName(
      Map<String, dynamic> attraction,
      ) {
    final value =
    attraction['name']
        ?.toString()
        .trim();

    if (value == null ||
        value.isEmpty) {
      return 'Unknown attraction';
    }

    return value;
  }

  String attractionCategory(
      Map<String, dynamic> attraction,
      ) {
    final value =
    attraction['category']
        ?.toString()
        .trim();

    if (value == null ||
        value.isEmpty) {
      return 'Cultural Attraction';
    }

    return value;
  }

  String attractionDescription(
      Map<String, dynamic> attraction,
      ) {
    final value =
    attraction['description']
        ?.toString()
        .trim();

    if (value == null ||
        value.isEmpty) {
      return 'No description available.';
    }

    return value;
  }

  String attractionAddress(
      Map<String, dynamic> attraction,
      ) {
    final value =
    attraction['address']
        ?.toString()
        .trim();

    if (value == null ||
        value.isEmpty) {
      return 'Location information unavailable.';
    }

    return value;
  }

  String attractionOpeningInformation(
      Map<String, dynamic> attraction,
      ) {
    final value =
    attraction[
    'openingInformation']
        ?.toString()
        .trim();

    if (value == null ||
        value.isEmpty) {
      return 'Opening information unavailable.';
    }

    return value;
  }

  String attractionEtiquettePreview(
      Map<String, dynamic> attraction,
      ) {
    final value =
    attraction[
    'etiquettePreview']
        ?.toString()
        .trim();

    if (value == null ||
        value.isEmpty) {
      return 'Respect the cultural and religious '
          'rules of this attraction.';
    }

    return value;
  }

  String? attractionImageUrl(
      Map<String, dynamic> attraction,
      ) {
    final value =
    attraction['imageUrl']
        ?.toString()
        .trim();

    if (value == null ||
        value.isEmpty) {
      return null;
    }

    return value;
  }

  double? attractionLatitude(
      Map<String, dynamic> attraction,
      ) {
    return _toDouble(
      attraction['latitude'],
    );
  }

  double? attractionLongitude(
      Map<String, dynamic> attraction,
      ) {
    return _toDouble(
      attraction['longitude'],
    );
  }

  // ============================================================
  // FIGMA DATA - STATUS
  // ============================================================

  String attractionStatus(
      Map<String, dynamic> attraction,
      ) {
    final value =
    attraction['status']
        ?.toString()
        .trim();

    if (value == null ||
        value.isEmpty) {
      return 'Status Unknown';
    }

    return value;
  }

  bool attractionIsOpen(
      Map<String, dynamic> attraction,
      ) {
    final status =
    attractionStatus(
      attraction,
    ).toLowerCase();

    return status.contains(
      'open',
    ) &&
        !status.contains(
          'closed',
        );
  }

  // ============================================================
  // FIGMA DATA - RATING
  // ============================================================

  double? attractionRating(
      Map<String, dynamic> attraction,
      ) {
    return _toDouble(
      attraction['rating'],
    );
  }

  String attractionRatingText(
      Map<String, dynamic> attraction,
      ) {
    final rating =
    attractionRating(
      attraction,
    );

    if (rating == null) {
      return 'N/A';
    }

    return rating
        .toStringAsFixed(
      1,
    );
  }

  // ============================================================
  // FIGMA DATA - DO
  // ============================================================

  List<String> attractionDos(
      Map<String, dynamic> attraction,
      ) {
    return _toStringList(
      attraction['dos'],
    );
  }

  // ============================================================
  // FIGMA DATA - DON'T
  // ============================================================

  List<String> attractionDonts(
      Map<String, dynamic> attraction,
      ) {
    return _toStringList(
      attraction['donts'],
    );
  }

  // ============================================================
  // FIGMA DATA - ACTIVITIES
  // ============================================================

  List<Map<String, String>> attractionActivities(
      Map<String, dynamic> attraction,
      ) {
    final raw =
    attraction['activities'];

    if (raw is! List) {
      return <Map<String, String>>[];
    }

    final result =
    <Map<String, String>>[];

    for (final item in raw) {
      if (item is Map) {
        final title =
            item['title']
                ?.toString()
                .trim() ??
                '';

        final description =
            item['description']
                ?.toString()
                .trim() ??
                '';

        if (title.isNotEmpty) {
          result.add({
            'title':
            title,
            'description':
            description,
          });
        }
      } else {
        final title =
            item?.toString().trim() ??
                '';

        if (title.isNotEmpty) {
          result.add({
            'title':
            title,
            'description':
            '',
          });
        }
      }
    }

    return result;
  }

  // ============================================================
  // FILTERING
  // ============================================================

  void _applyFilters() {
    var result =
    List<Map<String, dynamic>>
        .from(
      _allAttractions,
    );

    // ============================================================
    // FILTER BY SELECTED AREA
    // ============================================================

    result = result.where(
          (attraction) {
        final latitude =
        _toDouble(
          attraction[
          'latitude'],
        );

        final longitude =
        _toDouble(
          attraction[
          'longitude'],
        );

        if (latitude == null ||
            longitude == null) {
          return false;
        }

        return _locationService
            .isWithinRadius(
          userLatitude:
          _currentLatitude,
          userLongitude:
          _currentLongitude,
          attractionLatitude:
          latitude,
          attractionLongitude:
          longitude,
          radiusKm:
          selectedAreaRadiusKm,
        );
      },
    ).toList();

    // ============================================================
    // CATEGORY FILTER
    // ============================================================

    result =
        _repository
            .filterByCategories(
          attractions:
          result,
          selectedCategories:
          _selectedCategories,
        );

    // ============================================================
    // SEARCH
    // ============================================================

    result =
        _repository
            .searchAttractions(
          attractions:
          result,
          query:
          _searchQuery,
        );

    _visibleAttractions =
        result;

    // Nearest attraction appears first.
    _sortVisibleAttractionsByDistance();

    notifyListeners();
  }

  void _sortVisibleAttractionsByDistance() {
    _visibleAttractions.sort(
          (
          first,
          second,
          ) {
        final firstDistance =
        distanceKmFor(
          first,
        );

        final secondDistance =
        distanceKmFor(
          second,
        );

        if (firstDistance == null &&
            secondDistance == null) {
          return 0;
        }

        if (firstDistance == null) {
          return 1;
        }

        if (secondDistance == null) {
          return -1;
        }

        return firstDistance.compareTo(
          secondDistance,
        );
      },
    );
  }

  // ============================================================
  // DEFAULT AREA
  // ============================================================

  void _useDefaultPilotArea() {
    final defaultArea =
    _locationService
        .getDefaultPilotArea();

    _currentLatitude =
        defaultArea[
        'latitude'] ??
            CulturalMapLocationService
                .defaultLatitude;

    _currentLongitude =
        defaultArea[
        'longitude'] ??
            CulturalMapLocationService
                .defaultLongitude;

    _locationAvailable = false;

    _usingDefaultArea = true;
  }

  // ============================================================
  // ERROR
  // ============================================================

  void clearError() {
    _errorMessage = null;

    notifyListeners();
  }

  void _setLoading(
      bool value,
      ) {
    _isLoading = value;

    notifyListeners();
  }

  // ============================================================
  // HELPERS
  // ============================================================

  static List<String> _toStringList(
      dynamic value,
      ) {
    if (value is! List) {
      return <String>[];
    }

    return value
        .map(
          (item) =>
      item
          ?.toString()
          .trim() ??
          '',
    )
        .where(
          (item) =>
      item.isNotEmpty,
    )
        .toList();
  }

  static double? _toDouble(
      dynamic value,
      ) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value?.toString() ??
          '',
    );
  }

  static String _cleanError(
      Object error,
      ) {
    return error
        .toString()
        .replaceFirst(
      'Exception: ',
      '',
    );
  }
}