import '../../services/firestore/firestore_service.dart';

class OutfitEtiquetteRepository {
  final FirestoreService _firestoreService;

  static const String _collection = 'outfit';

  OutfitEtiquetteRepository({
    FirestoreService? firestoreService,
  }) : _firestoreService =
      firestoreService ?? FirestoreService();

  // =========================================================
  // GET OUTFIT ETIQUETTE BY CATEGORY
  // =========================================================

  Future<Map<String, dynamic>?> getOutfitByCategory(
      String category,
      ) async {
    final snapshot =
    await _firestoreService.getCollection(
      collection: _collection,
    );

    final matchingDocuments = snapshot.docs
        .where(
          (doc) =>
      doc.data()['category']?.toString() ==
          category,
    )
        .toList();

    if (matchingDocuments.isEmpty) {
      return null;
    }

    final document = matchingDocuments.first;

    return {
      'id': document.id,
      ...document.data(),
    };
  }

  // =========================================================
  // GET OUTFIT BY DOCUMENT ID
  // =========================================================

  Future<Map<String, dynamic>?> getOutfitById(
      String documentId,
      ) async {
    final document =
    await _firestoreService.getDocument(
      collection: _collection,
      documentId: documentId,
    );

    if (!document.exists) {
      return null;
    }

    final data = document.data();

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
    await _firestoreService.getCollection(
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

    final allRules =
    await getAllOutfitRules();

    return allRules.where((rule) {
      final category =
      rule['category']?.toString();

      return category != null &&
          categories.contains(category);
    }).toList();
  }

  // =========================================================
  // CHECK CATEGORY
  // =========================================================

  Future<bool> hasOutfitForCategory(
      String category,
      ) async {
    final outfit =
    await getOutfitByCategory(category);

    return outfit != null;
  }

  // =========================================================
  // GET SHOULDER REQUIREMENT
  // =========================================================

  Future<String?> getShoulderRequirement(
      String category,
      ) async {
    final outfit =
    await getOutfitByCategory(category);

    return outfit?['shoulder']?.toString();
  }

  // =========================================================
  // GET LOWER BODY REQUIREMENT
  // =========================================================

  Future<String?> getLowerBodyRequirement(
      String category,
      ) async {
    final outfit =
    await getOutfitByCategory(category);

    return outfit?['lowerBody']?.toString();
  }

  // =========================================================
  // GET HEADWEAR REQUIREMENT
  // =========================================================

  Future<String?> getHeadwearRequirement(
      String category,
      ) async {
    final outfit =
    await getOutfitByCategory(category);

    return outfit?['headwear']?.toString();
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
          (snapshot) => snapshot.docs
          .map(
            (doc) => {
          'id': doc.id,
          ...doc.data(),
        },
      )
          .toList(),
    );
  }
}