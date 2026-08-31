import '../../services/firestore/firestore_service.dart';

/// Persists etiquette alert notifications (UC02) so that cooldown checks
/// (FR-GEA6) and alert history (proposal Module 2, functionality #6) survive
/// app restarts instead of living only in memory.
class NotificationRepository {
  final FirestoreService _firestoreService;

  static const String _collection = 'notifications';

  NotificationRepository({
    FirestoreService? firestoreService,
  }) : _firestoreService =
      firestoreService ?? FirestoreService();

  // =========================================================
  // RECORD (FR-GEA5)
  // =========================================================

  /// Records a notification attempt.
  ///
  /// [status] is 'sent' when actually delivered to the Tourist, or
  /// 'suppressed' when cancelled by an active cooldown (UC02 A1). Only
  /// 'sent' records should ever count toward cooldown checks.
  Future<String> recordNotification({
    required String userId,
    required String attractionId,
    required String attractionName,
    required String message,
    required List<String> ruleIds,
    required String status,
  }) async {
    final document = await _firestoreService.addDocument(
      collection: _collection,
      data: {
        'userId': userId,
        'attractionId': attractionId,
        'attractionName': attractionName,
        'message': message,
        'ruleIds': ruleIds,
        'status': status,
        'isRead': false,
        'dismissedAt': null,
        'sentAt': DateTime.now().toIso8601String(),
      },
    );

    return document.id;
  }

  // =========================================================
  // COOLDOWN LOOKUP (FR-GEA6 / C3)
  // =========================================================

  /// Returns when the last *sent* (not suppressed) notification for this
  /// Tourist/attraction pair went out, or null if none exists yet.
  Future<DateTime?> getLastSentTime({
    required String userId,
    required String attractionId,
  }) async {
    final notifications = await _getAllForUser(userId);

    final sentForAttraction = notifications.where((notification) {
      return notification['attractionId'] == attractionId &&
          notification['status'] == 'sent';
    });

    if (sentForAttraction.isEmpty) {
      return null;
    }

    final timestamps = sentForAttraction
        .map(
          (notification) => DateTime.tryParse(
        notification['sentAt']?.toString() ?? '',
      ),
    )
        .whereType<DateTime>()
        .toList();

    if (timestamps.isEmpty) {
      return null;
    }

    timestamps.sort((a, b) => b.compareTo(a));

    return timestamps.first;
  }

  // =========================================================
  // ALERT HISTORY (proposal Module 2 #6; FR-GEA8 support)
  // =========================================================

  Future<List<Map<String, dynamic>>> getHistoryForUser(
      String userId,
      ) async {
    final notifications = await _getAllForUser(userId);

    notifications.sort((a, b) {
      final sentA = a['sentAt']?.toString() ?? '';
      final sentB = b['sentAt']?.toString() ?? '';

      return sentB.compareTo(sentA);
    });

    return notifications;
  }

  Stream<List<Map<String, dynamic>>> watchHistoryForUser(
      String userId,
      ) {
    return _firestoreService
        .watchCollection(collection: _collection)
        .map((snapshot) {
      final notifications = snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .where(
            (notification) => notification['userId'] == userId,
      )
          .toList();

      notifications.sort((a, b) {
        final sentA = a['sentAt']?.toString() ?? '';
        final sentB = b['sentAt']?.toString() ?? '';

        return sentB.compareTo(sentA);
      });

      return notifications;
    });
  }

  // =========================================================
  // MARK AS READ / DISMISS (proposal Module 2 #5)
  // =========================================================

  Future<void> markAsRead(String notificationId) async {
    await _firestoreService.updateDocument(
      collection: _collection,
      documentId: notificationId,
      data: {'isRead': true},
    );
  }

  Future<void> dismiss(String notificationId) async {
    await _firestoreService.updateDocument(
      collection: _collection,
      documentId: notificationId,
      data: {
        'isRead': true,
        'dismissedAt': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Hard-deletes a notification record. Unlike dismiss(), this also
  /// clears it from the cooldown lookup (getLastSentTime) -- useful for
  /// admin/dev tooling that needs to reset a Tourist's cooldown state.
  Future<void> deleteNotification(String notificationId) async {
    await _firestoreService.deleteDocument(
      collection: _collection,
      documentId: notificationId,
    );
  }

  Future<void> markAllAsRead(String userId) async {
    final notifications = await _getAllForUser(userId);

    final unreadIds = notifications
        .where((notification) => notification['isRead'] != true)
        .map((notification) => notification['id'].toString());

    for (final id in unreadIds) {
      await markAsRead(id);
    }
  }

  // =========================================================
  // INTERNAL
  // =========================================================

  Future<List<Map<String, dynamic>>> _getAllForUser(
      String userId,
      ) async {
    final snapshot = await _firestoreService.getCollection(
      collection: _collection,
    );

    return snapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .where((notification) => notification['userId'] == userId)
        .toList();
  }
}
