import '../../services/firestore/firestore_service.dart';
class AttractionRepository {
  final FirestoreService _firestoreService;

  static const String _collection = 'attractions';

  AttractionRepository({
    FirestoreService? firestoreService,
  }) : _firestoreService =
      firestoreService ?? FirestoreService();

  // Get all supported cultural attractions
  Future<List<Map<String, dynamic>>> getAllAttractions() async {
    final snapshot = await _firestoreService.getCollection(
      collection: _collection,
    );

    return snapshot.docs
        .map(
          (doc) => {
        'id': doc.id,
        ...doc.data(),
      },
    )
        .where(
          (attraction) =>
      attraction['isSupported'] == true,
    )
        .toList();
  }

  // Get one attraction using its document ID
  Future<Map<String, dynamic>?> getAttractionById(
      String attractionId,
      ) async {
    final document = await _firestoreService.getDocument(
      collection: _collection,
      documentId: attractionId,
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

  // Get attractions by cultural category
  Future<List<Map<String, dynamic>>> getAttractionsByCategory(
      String category,
      ) async {
    final attractions = await getAllAttractions();

    return attractions
        .where(
          (attraction) =>
      attraction['category'] == category,
    )
        .toList();
  }

  // Search attractions by name
  Future<List<Map<String, dynamic>>> searchAttractions(
      String searchText,
      ) async {
    final attractions = await getAllAttractions();

    final query = searchText.trim().toLowerCase();

    if (query.isEmpty) {
      return attractions;
    }

    return attractions.where((attraction) {
      final name =
      (attraction['name'] ?? '').toString().toLowerCase();

      return name.contains(query);
    }).toList();
  }

  // Listen for attraction changes in real time
  Stream<List<Map<String, dynamic>>> watchAttractions() {
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
          .where(
            (attraction) =>
        attraction['isSupported'] == true,
      )
          .toList(),
    );
  }
}