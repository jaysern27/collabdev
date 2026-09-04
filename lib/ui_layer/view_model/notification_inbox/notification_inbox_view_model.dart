import 'package:flutter/foundation.dart';

import '../../../data_layer/model/repositories/notification/etiquette_notification_repository.dart';

// Notification inbox for the etiquette alerts recorded by UC02
// (Receive Etiquette Alert). Splits the tourist's alert history
// into unread / read, matching the bell icon on the home page.
class NotificationInboxViewModel extends ChangeNotifier {
  final EtiquetteNotificationRepository _repository;

  NotificationInboxViewModel({
    EtiquetteNotificationRepository? repository,
  }) : _repository =
      repository ?? EtiquetteNotificationRepository();

  bool _isLoading = false;
  String? _errorMessage;
  String? _userId;

  List<Map<String, dynamic>> _notifications = [];

  bool get isLoading => _isLoading;

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
          (n) => n['id'] == notificationId,
    );

    if (index == -1 || _notifications[index]['read'] == true) {
      return;
    }

    // Optimistic update so the item moves to "Read" immediately.
    _notifications[index] = {
      ..._notifications[index],
      'read': true,
    };

    notifyListeners();

    try {
      await _repository.markAsRead(notificationId);
    } catch (_) {
      // Keep the optimistic state; a manual refresh will
      // reconcile it if the write actually failed.
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
