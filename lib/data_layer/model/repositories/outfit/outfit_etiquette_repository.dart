import '../../services/firestore/firestore_service.dart';

class OutfitEtiquetteRepository {
  final FirestoreService _firestoreService;

  // =========================================================
  // FIRESTORE COLLECTION
  // =========================================================

  static const String _collection =
      'etiquette_outfit';

  OutfitEtiquetteRepository({
    FirestoreService? firestoreService,
  }) : _firestoreService =
      firestoreService ??
          FirestoreService();

  // =========================================================
  // GET OUTFIT ETIQUETTE BY CATEGORY
  // =========================================================

  Future<Map<String, dynamic>?>
  getOutfitByCategory(
      String category,
      ) async {
    final documentId =
    _documentIdForCategory(
      category,
    );

    // ---------------------------------------------------------
    // Best path:
    // map attraction category directly to the known
    // etiquette_outfit document ID.
    // ---------------------------------------------------------

    if (documentId != null) {
      final result =
      await getOutfitById(
        documentId,
      );

      if (result != null) {
        return result;
      }
    }

    // ---------------------------------------------------------
    // Fallback:
    // search by the category field itself.
    // ---------------------------------------------------------

    final allRules =
    await getAllOutfitRules();

    final requestedCategory =
    _canonicalCategory(
      category,
    );

    for (final rule in allRules) {
      final ruleCategory =
      _canonicalCategory(
        rule['category']
            ?.toString() ??
            '',
      );

      if (ruleCategory ==
          requestedCategory) {
        return rule;
      }
    }

    return null;
  }

  // =========================================================
  // GET OUTFIT BY DOCUMENT ID
  // =========================================================

  Future<Map<String, dynamic>?>
  getOutfitById(
      String documentId,
      ) async {
    final document =
    await _firestoreService
        .getDocument(
      collection: _collection,
      documentId: documentId,
    );

    if (!document.exists) {
      return null;
    }

    final data =
    document.data();

    if (data == null) {
      return null;
    }

    return {
      'id': document.id,
      ...data,
    };
  }

  // =========================================================
  // GET ALL OUTFIT RULES
  // =========================================================

  Future<List<Map<String, dynamic>>>
  getAllOutfitRules() async {
    final snapshot =
    await _firestoreService
        .getCollection(
      collection: _collection,
    );

    return snapshot.docs
        .map(
          (doc) => {
        'id': doc.id,
        ...doc.data(),
      },
    )
        .toList();
  }

  // =========================================================
  // GET OUTFIT RULES BY CATEGORIES
  // =========================================================

  Future<List<Map<String, dynamic>>>
  getOutfitByCategories(
      List<String> categories,
      ) async {
    if (categories.isEmpty) {
      return [];
    }

    final requestedCategories =
    categories
        .map(
      _canonicalCategory,
    )
        .toSet();

    final allRules =
    await getAllOutfitRules();

    return allRules.where(
          (rule) {
        final category =
        _canonicalCategory(
          rule['category']
              ?.toString() ??
              '',
        );

        return requestedCategories
            .contains(
          category,
        );
      },
    ).toList();
  }

  // =========================================================
  // CHECK CATEGORY
  // =========================================================

  Future<bool>
  hasOutfitForCategory(
      String category,
      ) async {
    final outfit =
    await getOutfitByCategory(
      category,
    );

    return outfit != null;
  }

  // =========================================================
  // GET SLEEVE REQUIREMENT
  // =========================================================

  Future<String?>
  getSleeveRequirement(
      String category,
      ) async {
    final outfit =
    await getOutfitByCategory(
      category,
    );

    return outfit?['sleeve']
        ?.toString();
  }

  // =========================================================
  // GET SHOULDER REQUIREMENT
  // =========================================================

  Future<String?>
  getShoulderRequirement(
      String category,
      ) async {
    final outfit =
    await getOutfitByCategory(
      category,
    );

    return outfit?['shoulder']
        ?.toString();
  }

  // =========================================================
  // GET LOWER-BODY REQUIREMENT
  // =========================================================

  Future<String?>
  getLowerBodyRequirement(
      String category,
      ) async {
    final outfit =
    await getOutfitByCategory(
      category,
    );

    // Your Firestore currently uses:
    //
    // lowerbody
    //
    // Keep lowerBody as a fallback so older
    // data will still work.

    return (
        outfit?['lowerbody'] ??
            outfit?['lowerBody']
    )?.toString();
  }

  // =========================================================
  // GET HEADWEAR REQUIREMENT
  // =========================================================

  Future<String?>
  getHeadwearRequirement(
      String category,
      ) async {
    final outfit =
    await getOutfitByCategory(
      category,
    );

    return outfit?['headwear']
        ?.toString();
  }

  // =========================================================
  // WATCH ALL OUTFIT RULES
  // =========================================================

  Stream<List<Map<String, dynamic>>>
  watchOutfitRules() {
    return _firestoreService
        .watchCollection(
      collection: _collection,
    )
        .map(
          (snapshot) =>
          snapshot.docs
              .map(
                (doc) => {
              'id':
              doc.id,
              ...doc
                  .data(),
            },
          )
              .toList(),
    );
  }

  // =========================================================
  // CATEGORY -> FIRESTORE DOCUMENT ID
  // =========================================================

  String? _documentIdForCategory(
      String category,
      ) {
    switch (
    _canonicalCategory(
      category,
    )) {
      case 'chinese culture':
        return 'chinese_culture';

      case 'historical landmarks':
        return 'historical_landmarks';

      case 'indian culture':
        return 'indian_culture';

      case 'islamic culture':
        return 'islamic_culture';

      case 'places of worship':
        return 'places_of_worship';

      default:
        return null;
    }
  }

  // =========================================================
  // CATEGORY NORMALISATION
  // =========================================================

  String _canonicalCategory(
      String value,
      ) {
    var result =
    value
        .trim()
        .toLowerCase()
        .replaceAll(
      '_',
      ' ',
    )
        .replaceAll(
      '-',
      ' ',
    )
        .replaceAll(
      RegExp(r'\s+'),
      ' ',
    );

    // Support the older Firestore wording
    // if it still exists anywhere.

    if (result ==
        'islamic cultural') {
      result =
      'islamic culture';
    }

    return result;
  }
}