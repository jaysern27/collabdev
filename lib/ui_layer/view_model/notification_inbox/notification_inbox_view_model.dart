import 'package:flutter/foundation.dart';

import '../../../data_layer/model/repositories/notification/etiquette_notification_repository.dart';

// Notification inbox for the etiquette alerts recorded by UC02.
// Unread notifications can be opened and become Read.
// Only Read notifications are eligible for deletion.
class NotificationInboxViewModel extends ChangeNotifier {
  final EtiquetteNotificationRepository _repository;

  NotificationInboxViewModel({
    EtiquetteNotificationRepository? repository,
  }) : _repository =
            repository ?? EtiquetteNotificationRepository();

  bool _isLoading = false;
  bool _isDeleting = false;
  String? _errorMessage;
  String? _userId;

  List<Map<String, dynamic>> _notifications = [];

  bool get isLoading => _isLoading;
  bool get isDeleting => _isDeleting;
  String? get errorMessage => _errorMessage;

  List<Map<String, dynamic>> get unreadNotifications =>
      _notifications
          .where((n) => n['read'] != true)
          .toList();

  List<Map<String, dynamic>> get readNotifications =>
      _notifications
          .where((n) => n['read'] == true)
          .toList();

  Future<void> loadNotifications(String userId) async {
    _userId = userId;
    _setLoading(true);
    _errorMessage = null;

    try {
      _notifications =
          await _repository.getNotificationsForUser(userId);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> refresh() async {
    final userId = _userId;

    if (userId != null) {
      await loadNotifications(userId);
    }
  }

  Future<void> markAsRead(String notificationId) async {
    final index = _notifications.indexWhere(
      (n) => n['id']?.toString() == notificationId,
    );

    if (index == -1 || _notifications[index]['read'] == true) {
      return;
    }

    // Optimistic update so the item moves to Read immediately.
    _notifications[index] = {
      ..._notifications[index],
      'read': true,
    };

    notifyListeners();

    try {
      await _repository.markAsRead(notificationId);
    } catch (_) {
      // A refresh will reconcile the local state if the write failed.
    }
  }

  // Deletes only IDs that currently belong to Read notifications.
  // This prevents the UI from accidentally deleting an unread alert.
  Future<int> deleteReadNotifications(
    Iterable<String> notificationIds,
  ) async {
    final requested = notificationIds.toSet();

    final allowedIds = _notifications
        .where(
          (n) =>
              n['read'] == true &&
              requested.contains(n['id']?.toString()),
        )
        .map((n) => n['id']!.toString())
        .toList();

    if (allowedIds.isEmpty) {
      return 0;
    }

    _isDeleting = true;
    notifyListeners();

    try {
      await _repository.deleteNotifications(allowedIds);

      final deletedIds = allowedIds.toSet();
      _notifications.removeWhere(
        (n) => deletedIds.contains(n['id']?.toString()),
      );

      return allowedIds.length;
    } finally {
      _isDeleting = false;
      notifyListeners();
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
