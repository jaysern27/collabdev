import '../../services/firestore/firestore_service.dart';

// UC02 – Receive Etiquette Alert.
// Records every sent alert as its own document (so the Tourist can
// browse a read/unread notification inbox) and enforces the
// per-attraction cooldown (FR-GEA5 / FR-GEA6 / FR-GEA7 / A1).
class EtiquetteNotificationRepository {
  final FirestoreService _firestoreService;

  static const String _collection = 'etiquette_notifications';

  EtiquetteNotificationRepository({
    FirestoreService? firestoreService,
  }) : _firestoreService =
      firestoreService ?? FirestoreService();

  Future<List<Map<String, dynamic>>> _getAll() async {
    final snapshot = await _firestoreService.getCollection(
      collection: _collection,
    );

    return snapshot.docs
        .map(
          (doc) => <String, dynamic>{
        'id': doc.id,
        ...doc.data(),
      },
    )
        .toList();
  }

  static DateTime? _sentAt(Map<String, dynamic> notification) {
    final raw = notification['sentAt'];
    return raw is String ? DateTime.tryParse(raw) : null;
  }

  // Records a new alert unless the attraction is still within its
  // cooldown period for this tourist. Returns true when the alert
  // was actually recorded (i.e. allowed to be sent).
  Future<bool> recordIfAllowed({
    required String userId,
    required String attractionId,
    required String attractionName,
    required String message,
    required int cooldownMinutes,
  }) async {
    final existing = await _getAll();

    final forAttraction = existing
        .where(
          (n) =>
      n['userId'] == userId &&
          n['attractionId'] == attractionId,
    )
        .toList()
      ..sort(
            (a, b) {
          final aTime = _sentAt(a);
          final bTime = _sentAt(b);

          if (aTime == null || bTime == null) return 0;

          return bTime.compareTo(aTime);
        },
      );

    if (forAttraction.isNotEmpty) {
      final lastSentAt = _sentAt(forAttraction.first);

      if (lastSentAt != null) {
        final elapsed = DateTime.now().difference(lastSentAt);

        if (elapsed.inMinutes < cooldownMinutes) {
          // A1 – In Cooldown Period: cancel delivery.
          return false;
        }
      }
    }

    await _firestoreService.addDocument(
      collection: _collection,
      data: {
        'userId': userId,
        'attractionId': attractionId,
        'attractionName': attractionName,
        'message': message,
        'sentAt': DateTime.now().toIso8601String(),
        'read': false,
      },
    );

    return true;
  }

  // Notification inbox, newest first.
  Future<List<Map<String, dynamic>>> getNotificationsForUser(
      String userId,
      ) async {
    final all = await _getAll();

    final mine =
    all.where((n) => n['userId'] == userId).toList();

    mine.sort((a, b) {
      final aTime = _sentAt(a);
      final bTime = _sentAt(b);

      if (aTime == null || bTime == null) return 0;

      return bTime.compareTo(aTime);
    });

    return mine;
  }

  Future<void> markAsRead(String notificationId) async {
    await _firestoreService.updateDocument(
      collection: _collection,
      documentId: notificationId,
      data: {
        'read': true,
      },
    );
  }

  // Drives the unread badge on the home page.
  Stream<int> watchUnreadCount(String userId) {
    return _firestoreService
        .watchCollection(collection: _collection)
        .map(
          (snapshot) => snapshot.docs.where((doc) {
        final data = doc.data();

        return data['userId'] == userId &&
            data['read'] != true;
      }).length,
    );
  }
}
