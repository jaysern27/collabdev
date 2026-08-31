import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data_layer/model/repositories/attraction/attraction_repository.dart';
import '../../../data_layer/model/repositories/notification/notification_repository.dart';
import '../../../data_layer/model/repositories/user_preference/user_preference_repository.dart';
import '../../../data_layer/model/services/firebase_authentication/firebase_authentication_service.dart';

class HomeViewModel extends ChangeNotifier {
  final AttractionRepository _attractionRepository;
  final UserPreferenceRepository _userPreferenceRepository;
  final NotificationRepository _notificationRepository;
  final FirebaseAuthenticationService _authenticationService;

  HomeViewModel({
    AttractionRepository? attractionRepository,
    UserPreferenceRepository? userPreferenceRepository,
    NotificationRepository? notificationRepository,
    FirebaseAuthenticationService? authenticationService,
  })  : _attractionRepository =
      attractionRepository ?? AttractionRepository(),
        _userPreferenceRepository =
            userPreferenceRepository ?? UserPreferenceRepository(),
        _notificationRepository =
            notificationRepository ?? NotificationRepository(),
        _authenticationService =
            authenticationService ?? FirebaseAuthenticationService();

  List<Map<String, dynamic>> _attractions = [];

  List<Map<String, dynamic>> _recommendedAttractions = [];

  Map<String, dynamic>? _userPreferences;

  StreamSubscription<List<Map<String, dynamic>>>?
  _notificationSubscription;

  int _unreadNotificationCount = 0;

  bool _isLoading = false;

  String? _errorMessage;

  List<Map<String, dynamic>> get attractions =>
      _attractions;

  List<Map<String, dynamic>> get recommendedAttractions =>
      _recommendedAttractions;

  Map<String, dynamic>? get userPreferences =>
      _userPreferences;

  int get unreadNotificationCount => _unreadNotificationCount;

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  String? get currentUserId =>
      _authenticationService.currentUser?.uid;

  bool get isLoggedIn =>
      _authenticationService.isLoggedIn;

  String get selectedLanguage =>
      _userPreferences?['language']?.toString() ??
          'English';

  // Load everything needed by the Home screen
  Future<void> loadHomeData() async {
    _setLoading(true);

    try {
      _errorMessage = null;

      _attractions =
      await _attractionRepository.getAllAttractions();

      final userId = currentUserId;

      if (userId != null) {
        _userPreferences =
        await _userPreferenceRepository.getPreferences(
          userId,
        );

        _generateRecommendations();
      } else {
        _recommendedAttractions =
        List<Map<String, dynamic>>.from(
          _attractions,
        );
      }

      // Home's notification bell badge (UC02 alert history, categorised
      // by read/unread) always tracks the signed-in user, or 'guest' when
      // sign-in has not been wired up yet.
      _watchUnreadNotifications(userId ?? 'guest');
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  void _watchUnreadNotifications(String userId) {
    _notificationSubscription?.cancel();

    _notificationSubscription = _notificationRepository
        .watchHistoryForUser(userId)
        .listen((notifications) {
      _unreadNotificationCount = notifications
          .where((notification) => notification['isRead'] != true)
          .length;

      notifyListeners();
    });
  }

  // Search destination from Home page
  Future<List<Map<String, dynamic>>> searchDestination(
      String searchText,
      ) async {
    try {
      _errorMessage = null;

      return await _attractionRepository.searchAttractions(
        searchText,
      );
    } catch (e) {
      _errorMessage = e.toString();

      notifyListeners();

      return [];
    }
  }

  // Generate recommendations based on
  // the user's preferred categories
  void _generateRecommendations() {
    final preferredCategories =
    List<String>.from(
      _userPreferences?['preferredCategories'] ?? [],
    );

    if (preferredCategories.isEmpty) {
      _recommendedAttractions =
      List<Map<String, dynamic>>.from(
        _attractions,
      );

      return;
    }

    _recommendedAttractions =
        _attractions.where((attraction) {
          final category =
          attraction['category']?.toString();

          return preferredCategories.contains(category);
        }).toList();
  }

  // Refresh home screen
  Future<void> refresh() async {
    await loadHomeData();
  }

  void clearError() {
    _errorMessage = null;

    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;

    notifyListeners();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();

    super.dispose();
  }
}