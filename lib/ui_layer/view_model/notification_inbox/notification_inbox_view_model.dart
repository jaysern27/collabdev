import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data_layer/model/repositories/notification/notification_repository.dart';
import '../../../data_layer/model/services/firebase_authentication/firebase_authentication_service.dart';

/// Notification filter categories, opened from the bell icon on Home.
/// Backs UC02's alert history (proposal Module 2 #6) and the
/// mark-as-read/dismiss behaviour from proposal Module 2 #5.
enum NotificationFilter { all, unread, read }

class NotificationInboxViewModel extends ChangeNotifier {
  final NotificationRepository _notificationRepository;
  final FirebaseAuthenticationService _authenticationService;

  NotificationInboxViewModel({
    NotificationRepository? notificationRepository,
    FirebaseAuthenticationService? authenticationService,
  })  : _notificationRepository =
      notificationRepository ?? NotificationRepository(),
        _authenticationService =
            authenticationService ?? FirebaseAuthenticationService();

  StreamSubscription<List<Map<String, dynamic>>>? _subscription;

  List<Map<String, dynamic>> _notifications = [];

  NotificationFilter _filter = NotificationFilter.all;

  bool _isLoading = false;

  String? _errorMessage;

  String get _currentUserId =>
      _authenticationService.currentUser?.uid ?? 'guest';

  NotificationFilter get filter => _filter;

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  int get unreadCount => _notifications
      .where((notification) => notification['isRead'] != true)
      .length;

  int get readCount => _notifications
      .where((notification) => notification['isRead'] == true)
      .length;

  List<Map<String, dynamic>> get notifications {
    switch (_filter) {
      case NotificationFilter.unread:
        return _notifications
            .where((notification) => notification['isRead'] != true)
            .toList();
      case NotificationFilter.read:
        return _notifications
            .where((notification) => notification['isRead'] == true)
            .toList();
      case NotificationFilter.all:
        return _notifications;
    }
  }

  // =========================================================
  // LOAD / WATCH (proposal Module 2 #6: keep an alert history)
  // =========================================================

  void startWatching() {
    _setLoading(true);

    _subscription?.cancel();

    _subscription = _notificationRepository
        .watchHistoryForUser(_currentUserId)
        .listen(
          (notifications) {
        _errorMessage = null;
        _notifications = notifications;

        _setLoading(false);
      },
      onError: (error) {
        _errorMessage = error.toString();

        _setLoading(false);
      },
    );
  }

  void setFilter(NotificationFilter filter) {
    _filter = filter;

    notifyListeners();
  }

  // =========================================================
  // MARK AS READ / DISMISS (proposal Module 2 #5)
  // =========================================================

  Future<void> markAsRead(String notificationId) async {
    await _notificationRepository.markAsRead(notificationId);
  }

  Future<void> dismiss(String notificationId) async {
    await _notificationRepository.dismiss(notificationId);
  }

  Future<void> markAllAsRead() async {
    await _notificationRepository.markAllAsRead(_currentUserId);
  }

  void _setLoading(bool value) {
    _isLoading = value;

    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();

    super.dispose();
  }
}
