import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/firestore/firestore_service.dart';

class UserPreferenceRepository {
  final FirestoreService _firestoreService;

  static const String _collection = 'user_preferences';

  UserPreferenceRepository({
    FirestoreService? firestoreService,
  }) : _firestoreService =
      firestoreService ?? FirestoreService();

  // Create or save user preferences
  Future<void> savePreferences({
    required String userId,
    required String language,
    required List<String> preferredCategories,
    bool notificationsEnabled = true,
  }) async {
    await _firestoreService.setDocument(
      collection: _collection,
      documentId: userId,
      data: {
        'language': language,
        'preferredCategories': preferredCategories,
        'notificationsEnabled': notificationsEnabled,
        'favoriteAttractions': <String>[],
        'updatedAt': DateTime.now().toIso8601String(),
      },
    );
  }

  // Get preferences for one user
  Future<Map<String, dynamic>?> getPreferences(
      String userId,
      ) async {
    final document = await _firestoreService.getDocument(
      collection: _collection,
      documentId: userId,
    );

    if (!document.exists) {
      return null;
    }

    final data = document.data();

    if (data == null) {
      return null;
    }

    return {
      'userId': document.id,
      ...data,
    };
  }

  // Update selected preferences
  Future<void> updatePreferences({
    required String userId,
    required Map<String, dynamic> preferences,
  }) async {
    await _firestoreService.updateDocument(
      collection: _collection,
      documentId: userId,
      data: {
        ...preferences,
        'updatedAt': DateTime.now().toIso8601String(),
      },
    );
  }

  // Add attraction to favourites
  Future<void> addFavoriteAttraction({
    required String userId,
    required String attractionId,
  }) async {
    await _firestoreService.updateDocument(
      collection: _collection,
      documentId: userId,
      data: {
        'favoriteAttractions': FieldValue.arrayUnion(
          [attractionId],
        ),
        'updatedAt': DateTime.now().toIso8601String(),
      },
    );
  }

  // Remove attraction from favourites
  Future<void> removeFavoriteAttraction({
    required String userId,
    required String attractionId,
  }) async {
    await _firestoreService.updateDocument(
      collection: _collection,
      documentId: userId,
      data: {
        'favoriteAttractions': FieldValue.arrayRemove(
          [attractionId],
        ),
        'updatedAt': DateTime.now().toIso8601String(),
      },
    );
  }

  // Check whether attraction is already favourited
  Future<bool> isFavorite({
    required String userId,
    required String attractionId,
  }) async {
    final preferences = await getPreferences(userId);

    if (preferences == null) {
      return false;
    }

    final favorites = List<String>.from(
      preferences['favoriteAttractions'] ?? [],
    );

    return favorites.contains(attractionId);
  }

  // Listen to preference changes
  Stream<Map<String, dynamic>?> watchPreferences(
      String userId,
      ) {
    return _firestoreService
        .watchCollection(
      collection: _collection,
    )
        .map((snapshot) {
      for (final document in snapshot.docs) {
        if (document.id == userId) {
          return {
            'userId': document.id,
            ...document.data(),
          };
        }
      }

      return null;
    });
  }
}