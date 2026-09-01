import '../../services/firestore/firestore_service.dart';

class CulturalMapRepository {
  final FirestoreService _firestoreService;

  CulturalMapRepository({
    FirestoreService? firestoreService,
  }) : _firestoreService =
      firestoreService ?? FirestoreService();

  static const String _collectionName =
      'attractions';

  // ============================================================
  // SUPPORTED CULTURAL CATEGORIES
  // ============================================================

  static const List<String> supportedCategories = [
    'Islamic Culture',
    'Chinese Culture',
    'Indian Culture',
    'Places of Worship',
    'Historical Landmarks',
  ];

  // Categories that must not appear on the Cultural Map.
  static const List<String> excludedCategories = [
    'Shopping Centre',
    'Shopping Mall',
    'Theme Park',
    'Entertainment',
    'General Entertainment',
  ];

  // ============================================================
  // GET ALL SUPPORTED ATTRACTIONS
  // ============================================================

  Future<List<Map<String, dynamic>>>
  getSupportedAttractions() async {
    try {
      final snapshot =
      await _firestoreService.getCollection(
        collection: _collectionName,
      );

      final attractions = snapshot.docs
          .map(
            (doc) => <String, dynamic>{
          'id': doc.id,
          ...doc.data(),
        },
      )
          .where(_isValidSupportedAttraction)
          .toList();

      attractions.sort(
            (a, b) => _getName(a).compareTo(
          _getName(b),
        ),
      );

      return attractions;
    } catch (e) {
      throw Exception(
        'Unable to load cultural attractions: $e',
      );
    }
  }

  // ============================================================
  // GET ATTRACTION BY ID
  // ============================================================

  Future<Map<String, dynamic>?>
  getAttractionById(
      String attractionId,
      ) async {
    final attractions =
    await getSupportedAttractions();

    for (final attraction in attractions) {
      if (attraction['id'] == attractionId) {
        return attraction;
      }
    }

    return null;
  }

  // ============================================================
  // FILTER BY CATEGORY
  // ============================================================

  List<Map<String, dynamic>> filterByCategories({
    required List<Map<String, dynamic>>
    attractions,
    required Set<String> selectedCategories,
  }) {
    if (selectedCategories.isEmpty) {
      return List<Map<String, dynamic>>.from(
        attractions,
      );
    }

    return attractions.where((attraction) {
      final category =
      _normaliseCategory(
        attraction['category'],
      );

      return selectedCategories.any(
            (selected) =>
        _normaliseCategory(selected) ==
            category,
      );
    }).toList();
  }

  // ============================================================
  // SEARCH
  // ============================================================

  List<Map<String, dynamic>> searchAttractions({
    required List<Map<String, dynamic>>
    attractions,
    required String query,
  }) {
    final cleanedQuery =
    query.trim().toLowerCase();

    if (cleanedQuery.isEmpty) {
      return List<Map<String, dynamic>>.from(
        attractions,
      );
    }

    return attractions.where((attraction) {
      final name =
          attraction['name']
              ?.toString()
              .toLowerCase() ??
              '';

      final category =
          attraction['category']
              ?.toString()
              .toLowerCase() ??
              '';

      final address =
          attraction['address']
              ?.toString()
              .toLowerCase() ??
              '';

      final description =
          attraction['description']
              ?.toString()
              .toLowerCase() ??
              '';

      return name.contains(cleanedQuery) ||
          category.contains(cleanedQuery) ||
          address.contains(cleanedQuery) ||
          description.contains(cleanedQuery);
    }).toList();
  }

  // ============================================================
  // VALIDATE SUPPORTED ATTRACTION
  // ============================================================

  bool _isValidSupportedAttraction(
      Map<String, dynamic> attraction,
      ) {
    final name =
        attraction['name']?.toString().trim() ??
            '';

    if (name.isEmpty) {
      return false;
    }

    // If the field does not exist yet, treat it as enabled
    // so existing prototype Firebase data can still work.
    final isEnabled =
        attraction['isEnabled'] != false;

    if (!isEnabled) {
      return false;
    }

    // If isSupported is explicitly false, do not show it.
    final isSupported =
        attraction['isSupported'] != false;

    if (!isSupported) {
      return false;
    }

    final category =
        attraction['category']
            ?.toString()
            .trim() ??
            '';

    if (category.isEmpty) {
      return false;
    }

    if (_isExcludedCategory(category)) {
      return false;
    }

    if (!_isSupportedCategory(category)) {
      return false;
    }

    final latitude =
    _toDouble(
      attraction['latitude'],
    );

    final longitude =
    _toDouble(
      attraction['longitude'],
    );

    // Design requirement:
    // only attractions with valid coordinates should
    // appear on the map.
    if (latitude == null ||
        longitude == null) {
      return false;
    }

    if (latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return false;
    }

    return true;
  }

  // ============================================================
  // CATEGORY CHECKS
  // ============================================================

  bool _isSupportedCategory(
      String category,
      ) {
    final normalised =
    _normaliseCategory(category);

    return supportedCategories.any(
          (supported) =>
      _normaliseCategory(supported) ==
          normalised,
    );
  }

  bool _isExcludedCategory(
      String category,
      ) {
    final normalised =
    _normaliseCategory(category);

    return excludedCategories.any(
          (excluded) =>
      _normaliseCategory(excluded) ==
          normalised,
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  static String _normaliseCategory(
      dynamic value,
      ) {
    return value
        ?.toString()
        .trim()
        .toLowerCase()
        .replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    ) ??
        '';
  }

  static String _getName(
      Map<String, dynamic> attraction,
      ) {
    return attraction['name']
        ?.toString()
        .toLowerCase() ??
        '';
  }

  static double? _toDouble(
      dynamic value,
      ) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value?.toString() ?? '',
    );
  }
}