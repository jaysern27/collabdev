import 'package:flutter/foundation.dart';

import '../../../data_layer/model/repositories/attraction/attraction_repository.dart';
import '../../../data_layer/model/repositories/user_preference/user_preference_repository.dart';
import '../../../data_layer/model/services/firebase_authentication/firebase_authentication_service.dart';

class HomeViewModel extends ChangeNotifier {
  final AttractionRepository _attractionRepository;
  final UserPreferenceRepository _userPreferenceRepository;
  final FirebaseAuthenticationService _authenticationService;

  HomeViewModel({
    AttractionRepository? attractionRepository,
    UserPreferenceRepository? userPreferenceRepository,
    FirebaseAuthenticationService? authenticationService,
  })  : _attractionRepository =
      attractionRepository ?? AttractionRepository(),
        _userPreferenceRepository =
            userPreferenceRepository ?? UserPreferenceRepository(),
        _authenticationService =
            authenticationService ??
                FirebaseAuthenticationService();

  // =========================================================
  // STATE
  // =========================================================

  List<Map<String, dynamic>> _attractions = [];

  List<Map<String, dynamic>> _recommendedAttractions = [];

  List<Map<String, dynamic>> _searchResults = [];

  Map<String, dynamic>? _userPreferences;

  bool _isLoading = false;

  bool _isSearching = false;

  String? _errorMessage;

  // =========================================================
  // GETTERS
  // =========================================================

  List<Map<String, dynamic>> get attractions =>
      List.unmodifiable(_attractions);

  List<Map<String, dynamic>> get recommendedAttractions =>
      List.unmodifiable(
        _recommendedAttractions,
      );

  List<Map<String, dynamic>> get searchResults =>
      List.unmodifiable(
        _searchResults,
      );

  Map<String, dynamic>? get userPreferences =>
      _userPreferences;

  bool get isLoading => _isLoading;

  bool get isSearching => _isSearching;

  String? get errorMessage => _errorMessage;

  String? get currentUserId =>
      _authenticationService.currentUser?.uid;

  bool get isLoggedIn =>
      _authenticationService.isLoggedIn;

  String get selectedLanguage =>
      _userPreferences?['language']?.toString() ??
          'English';

  bool get hasAttractions =>
      _attractions.isNotEmpty;

  bool get hasRecommendations =>
      _recommendedAttractions.isNotEmpty;

  bool get hasSearchResults =>
      _searchResults.isNotEmpty;

  // =========================================================
  // USER DISPLAY NAME
  // =========================================================

  String get greetingName {
    final user =
        _authenticationService.currentUser;

    final displayName =
    user?.displayName?.trim();

    if (displayName != null &&
        displayName.isNotEmpty) {
      return displayName
          .split(
        RegExp(r'\s+'),
      )
          .first;
    }

    final email =
    user?.email?.trim();

    if (email != null &&
        email.isNotEmpty &&
        email.contains('@')) {
      final name =
          email.split('@').first;

      if (name.isNotEmpty) {
        return _capitalise(name);
      }
    }

    return 'Traveller';
  }

  // =========================================================
  // LOAD HOME DATA
  // =========================================================

  Future<void> loadHomeData() async {
    _setLoading(true);

    try {
      _errorMessage = null;

      _attractions =
      await _attractionRepository
          .getAllAttractions();

      final userId =
          currentUserId;

      if (userId != null) {
        _userPreferences =
        await _userPreferenceRepository
            .getPreferences(
          userId,
        );

        _generateRecommendations();
      } else {
        _userPreferences = null;

        _recommendedAttractions =
        List<Map<String, dynamic>>.from(
          _attractions,
        );
      }
    } catch (e) {
      _errorMessage =
      'Unable to load home data: $e';
    } finally {
      _setLoading(false);
    }
  }

  // =========================================================
  // SEARCH DESTINATION
  // =========================================================

  Future<List<Map<String, dynamic>>>
  searchDestination(
      String searchText,
      ) async {
    final query =
    searchText.trim();

    if (query.isEmpty) {
      _searchResults = [];

      notifyListeners();

      return [];
    }

    _setSearching(true);

    try {
      _errorMessage = null;

      final results =
      await _attractionRepository
          .searchAttractions(
        query,
      );

      _searchResults =
      List<Map<String, dynamic>>.from(
        results,
      );

      return _searchResults;
    } catch (e) {
      _searchResults = [];

      _errorMessage =
      'Unable to search destinations: $e';

      return [];
    } finally {
      _setSearching(false);
    }
  }

  // =========================================================
  // RECOMMENDATIONS
  // =========================================================

  void _generateRecommendations() {
    final rawCategories =
        _userPreferences?[
        'preferredCategories'] ??
            [];

    final preferredCategories =
    rawCategories is List
        ? rawCategories
        .map(
          (item) => item
          .toString()
          .toLowerCase()
          .trim(),
    )
        .where(
          (item) =>
      item.isNotEmpty,
    )
        .toList()
        : <String>[];

    if (preferredCategories.isEmpty) {
      _recommendedAttractions =
      List<Map<String, dynamic>>.from(
        _attractions,
      );

      return;
    }

    _recommendedAttractions =
        _attractions.where(
              (attraction) {
            final category =
            attraction['category']
                ?.toString()
                .toLowerCase()
                .trim();

            if (category == null ||
                category.isEmpty) {
              return false;
            }

            return preferredCategories
                .contains(
              category,
            );
          },
        ).toList();

    // Do not leave Home empty if no category matched.
    if (_recommendedAttractions.isEmpty) {
      _recommendedAttractions =
      List<Map<String, dynamic>>.from(
        _attractions,
      );
    }
  }

  // =========================================================
  // HELPERS
  // =========================================================

  String attractionName(
      Map<String, dynamic> attraction,
      ) {
    return attraction['name']
        ?.toString() ??
        attraction['attractionName']
            ?.toString() ??
        'Cultural Attraction';
  }

  String attractionCategory(
      Map<String, dynamic> attraction,
      ) {
    final category =
    attraction['category']
        ?.toString();

    if (category == null ||
        category.trim().isEmpty) {
      return 'Cultural Attraction';
    }

    return category;
  }

  String attractionLocation(
      Map<String, dynamic> attraction,
      ) {
    final address =
    attraction['address']
        ?.toString();

    if (address != null &&
        address.trim().isNotEmpty) {
      return address;
    }

    final location =
    attraction['locationName']
        ?.toString();

    if (location != null &&
        location.trim().isNotEmpty) {
      return location;
    }

    final city =
    attraction['city']
        ?.toString();

    if (city != null &&
        city.trim().isNotEmpty) {
      return city;
    }

    return 'Malaysia';
  }

  String? attractionDescription(
      Map<String, dynamic> attraction,
      ) {
    final description =
    attraction['description']
        ?.toString();

    if (description == null ||
        description.trim().isEmpty) {
      return null;
    }

    return description;
  }

  void clearSearchResults() {
    _searchResults = [];

    notifyListeners();
  }

  Future<void> refresh() async {
    await loadHomeData();
  }

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

  void _setSearching(
      bool value,
      ) {
    _isSearching = value;

    notifyListeners();
  }

  String _capitalise(
      String text,
      ) {
    if (text.isEmpty) {
      return text;
    }

    return '${text[0].toUpperCase()}'
        '${text.substring(1)}';
  }
}