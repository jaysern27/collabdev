import '../../services/firestore/firestore_service.dart';
import '../../services/firebase_authentication/firebase_authentication_service.dart';

class CulturalMapSavedRepository {
  final FirestoreService _firestoreService;
  final FirebaseAuthenticationService _authService;

  CulturalMapSavedRepository({
    FirestoreService? firestoreService,
    FirebaseAuthenticationService? authService,
  })  : _firestoreService =
      firestoreService ?? FirestoreService(),
        _authService =
            authService ?? FirebaseAuthenticationService();

  // ============================================================
  // CURRENT USER
  // ============================================================

  String? get currentUserId =>
      _authService.currentUser?.uid;

  bool get isLoggedIn =>
      _authService.isLoggedIn;

  // ============================================================
  // FIRESTORE PATHS
  // ============================================================

  String _favouritesCollection(
      String userId,
      ) {
    return 'users/$userId/favourites';
  }

  String _visitListCollection(
      String userId,
      ) {
    return 'users/$userId/visit_list';
  }

  // ============================================================
  // FAVOURITES
  // ============================================================

  Future<void> addToFavourites({
    required Map<String, dynamic> attraction,
  }) async {
    final userId = _requireUser();

    final attractionId =
    attraction['id']?.toString();

    if (attractionId == null ||
        attractionId.isEmpty) {
      throw Exception(
        'Attraction ID is missing.',
      );
    }

    await _firestoreService.setDocument(
      collection:
      _favouritesCollection(userId),
      documentId: attractionId,
      data: {
        'attractionId': attractionId,
        'name':
        attraction['name']?.toString() ??
            '',
        'category':
        attraction['category']
            ?.toString() ??
            '',
        'savedAt':
        DateTime.now().toIso8601String(),
      },
    );
  }

  Future<void> removeFromFavourites({
    required String attractionId,
  }) async {
    final userId = _requireUser();

    await _firestoreService.deleteDocument(
      collection:
      _favouritesCollection(userId),
      documentId: attractionId,
    );
  }

  Future<bool> isFavourite(
      String attractionId,
      ) async {
    final userId = currentUserId;

    if (userId == null) {
      return false;
    }

    final document =
    await _firestoreService.getDocument(
      collection:
      _favouritesCollection(userId),
      documentId: attractionId,
    );

    return document.exists;
  }

  Future<Set<String>>
  getFavouriteIds() async {
    final userId = currentUserId;

    if (userId == null) {
      return <String>{};
    }

    final snapshot =
    await _firestoreService.getCollection(
      collection:
      _favouritesCollection(userId),
    );

    return snapshot.docs
        .map(
          (doc) => doc.id,
    )
        .toSet();
  }

  // ============================================================
  // VISIT LIST
  // ============================================================

  Future<void> addToVisitList({
    required Map<String, dynamic> attraction,
  }) async {
    final userId = _requireUser();

    final attractionId =
    attraction['id']?.toString();

    if (attractionId == null ||
        attractionId.isEmpty) {
      throw Exception(
        'Attraction ID is missing.',
      );
    }

    await _firestoreService.setDocument(
      collection:
      _visitListCollection(userId),
      documentId: attractionId,
      data: {
        'attractionId': attractionId,
        'name':
        attraction['name']?.toString() ??
            '',
        'category':
        attraction['category']
            ?.toString() ??
            '',
        'savedAt':
        DateTime.now().toIso8601String(),
      },
    );
  }

  Future<void> removeFromVisitList({
    required String attractionId,
  }) async {
    final userId = _requireUser();

    await _firestoreService.deleteDocument(
      collection:
      _visitListCollection(userId),
      documentId: attractionId,
    );
  }

  Future<bool> isInVisitList(
      String attractionId,
      ) async {
    final userId = currentUserId;

    if (userId == null) {
      return false;
    }

    final document =
    await _firestoreService.getDocument(
      collection:
      _visitListCollection(userId),
      documentId: attractionId,
    );

    return document.exists;
  }

  Future<Set<String>>
  getVisitListIds() async {
    final userId = currentUserId;

    if (userId == null) {
      return <String>{};
    }

    final snapshot =
    await _firestoreService.getCollection(
      collection:
      _visitListCollection(userId),
    );

    return snapshot.docs
        .map(
          (doc) => doc.id,
    )
        .toSet();
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String _requireUser() {
    final userId = currentUserId;

    if (userId == null) {
      throw Exception(
        'Please sign in to save this attraction.',
      );
    }

    return userId;
  }
}