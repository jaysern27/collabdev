import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../../data_layer/model/repositories/attraction/attraction_repository.dart';
import '../../../data_layer/model/repositories/environment_settings/environment_settings_repository.dart';
import '../../../data_layer/model/repositories/etiquette/etiquette_repository.dart';
import '../../../data_layer/model/repositories/notification/notification_repository.dart';
import '../../../data_layer/model/repositories/ranking_report/ranking_report_repository.dart';
import '../../../data_layer/model/repositories/user_preference/user_preference_repository.dart';
import '../../../data_layer/model/services/location_geofencing/location_geofencing_service.dart';
import '../../../data_layer/model/services/notification/notification_service.dart';
import '../../../external_data_sources/firebase/firebase_data_source.dart';

/// UC02_Receive Etiquette Alert.
///
/// Watches a single GPS stream against every supported attraction's
/// geofence, and for each entry: checks the Tourist's notification
/// preference (FR-GEA4), resolves the cooldown period from the
/// per-attraction override or the Admin-configured default set in UC03
/// (FR-GEA6 / C3), and only records + sends the alert (FR-GEA5, FR-GEA7)
/// once the cooldown gate has actually cleared -- suppressed attempts are
/// never written to the database.
class EtiquetteAlertViewModel extends ChangeNotifier {
  final AttractionRepository _attractionRepository;
  final EtiquetteRepository _etiquetteRepository;
  final NotificationRepository _notificationRepository;
  final EnvironmentSettingsRepository _environmentSettingsRepository;
  final UserPreferenceRepository _userPreferenceRepository;
  final RankingReportRepository _rankingReportRepository;
  final LocationGeofencingService _locationService;
  final NotificationService _notificationService;

  // Pre-filter radius for pulling candidate attractions near the Tourist's
  // GPS position before running the precise per-attraction geofence check
  // (UC02 C1). Not currently Admin-configurable -- see UC03 analysis.
  static const double _activationRadiusMeters = 5000;

  EtiquetteAlertViewModel({
    AttractionRepository? attractionRepository,
    EtiquetteRepository? etiquetteRepository,
    NotificationRepository? notificationRepository,
    EnvironmentSettingsRepository? environmentSettingsRepository,
    UserPreferenceRepository? userPreferenceRepository,
    RankingReportRepository? rankingReportRepository,
    LocationGeofencingService? locationService,
    NotificationService? notificationService,
  })  : _attractionRepository =
      attractionRepository ?? AttractionRepository(),
        _etiquetteRepository =
            etiquetteRepository ?? EtiquetteRepository(),
        _notificationRepository =
            notificationRepository ?? NotificationRepository(),
        _environmentSettingsRepository = environmentSettingsRepository ??
            EnvironmentSettingsRepository(),
        _userPreferenceRepository =
            userPreferenceRepository ?? UserPreferenceRepository(),
        _rankingReportRepository =
            rankingReportRepository ?? RankingReportRepository(),
        _locationService =
            locationService ?? LocationGeofencingService(),
        _notificationService =
            notificationService ?? NotificationService();

  StreamSubscription<Position>? _positionSubscription;

  List<Map<String, dynamic>> _attractions = [];

  final Set<String> _insideAttractionIds = {};

  List<Map<String, dynamic>> _etiquetteRules = [];

  List<Map<String, dynamic>> _alertHistory = [];

  bool _isMonitoring = false;
  bool _isLoading = false;

  String? _activeAttractionId;
  String? _activeAttractionName;
  String? _activeNotificationId;
  String? _errorMessage;

  // =========================================================
  // GETTERS FOR DATA BINDING
  // =========================================================

  List<Map<String, dynamic>> get etiquetteRules => _etiquetteRules;

  List<Map<String, dynamic>> get alertHistory => _alertHistory;

  Set<String> get insideAttractionIds => _insideAttractionIds;

  bool get isMonitoring => _isMonitoring;

  bool get isLoading => _isLoading;

  String? get activeAttractionId => _activeAttractionId;

  String? get activeAttractionName => _activeAttractionName;

  String? get errorMessage => _errorMessage;

  bool get hasActiveAlert => _activeNotificationId != null;

  String get _currentUserId =>
      FirebaseDataSource.instance.auth.currentUser?.uid ?? 'guest';

  // =========================================================
  // START / STOP MONITORING (UC02 BF-1..BF-3)
  // =========================================================

  Future<void> startMonitoring() async {
    if (_isMonitoring) {
      return;
    }

    _setLoading(true);

    try {
      _errorMessage = null;

      _attractions = await _attractionRepository.getAllAttractions();

      _isMonitoring = true;

      _positionSubscription =
          _locationService.watchLocation().listen(
                _onPositionUpdate,
            onError: (error) {
              _errorMessage = error.toString();
              notifyListeners();
            },
          );
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> stopMonitoring() async {
    await _positionSubscription?.cancel();

    _positionSubscription = null;
    _isMonitoring = false;
    _insideAttractionIds.clear();

    notifyListeners();
  }

  // =========================================================
  // GEOFENCE EVALUATION (UC02 BF-1..BF-3, C1, C2)
  // =========================================================

  Future<void> _onPositionUpdate(Position position) async {
    for (final attraction in _attractions) {
      final attractionId = attraction['id']?.toString();

      final latitude = attraction['latitude'];
      final longitude = attraction['longitude'];

      final geofence =
      attraction['geofence'] as Map<String, dynamic>?;

      final isGeofenceActive = geofence?['isActive'] == true;

      if (attractionId == null ||
          latitude is! num ||
          longitude is! num ||
          !isGeofenceActive) {
        continue;
      }

      final radiusMeters =
      (geofence?['radiusMeters'] as num?)?.toDouble();

      if (radiusMeters == null) {
        continue;
      }

      final distance = _locationService.getDistanceFromAttraction(
        currentPosition: position,
        attractionLatitude: latitude.toDouble(),
        attractionLongitude: longitude.toDouble(),
      );

      // C1: only evaluate the precise geofence for attractions within the
      // coarse activation radius.
      if (distance > _activationRadiusMeters) {
        if (_insideAttractionIds.remove(attractionId)) {
          await _handleGeofenceExit(attraction);
        }
        continue;
      }

      // C2: enter geofence = current GPS distance <= geofence radius.
      final isInside = distance <= radiusMeters;

      final wasInside = _insideAttractionIds.contains(attractionId);

      if (isInside && !wasInside) {
        _insideAttractionIds.add(attractionId);
        await _handleGeofenceEntry(attraction);
      } else if (!isInside && wasInside) {
        _insideAttractionIds.remove(attractionId);
        await _handleGeofenceExit(attraction);
      }
    }
  }

  // =========================================================
  // ENTRY (UC02 BF-4..BF-7, FR-GEA4..FR-GEA7)
  // =========================================================

  Future<void> _handleGeofenceEntry(
      Map<String, dynamic> attraction,
      ) async {
    final attractionId = attraction['id'].toString();
    final attractionName =
        attraction['name']?.toString() ?? 'this attraction';

    try {
      // FR-GEA4: get the Tourist's notification preference.
      final preferences =
      await _userPreferenceRepository.getPreferences(_currentUserId);

      final notificationsEnabled =
          preferences?['notificationsEnabled'] != false;

      if (!notificationsEnabled) {
        return;
      }

      final soundEnabled = preferences?['soundEnabled'] != false;
      final vibrationEnabled = preferences?['vibrationEnabled'] != false;

      await loadEtiquetteRules(attractionId);

      // FR-GEA6 / C3: per-attraction override, else Admin-configured
      // default from UC03.
      final cooldownMinutes = await _resolveCooldownMinutes(attraction);

      // Cooldown gate runs BEFORE any record/send -- fixes UC02's original
      // ordering bug where a notification was recorded before the cooldown
      // check could still cancel it (A1).
      final lastSent = await _notificationRepository.getLastSentTime(
        userId: _currentUserId,
        attractionId: attractionId,
      );

      if (lastSent != null) {
        final elapsed = DateTime.now().difference(lastSent);

        if (elapsed.inMinutes < cooldownMinutes) {
          // A1 - In Cooldown Period: delivery cancelled, nothing recorded.
          return;
        }
      }

      final message = _buildAlertMessage();
      final ruleIds = _etiquetteRules
          .map((rule) => rule['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();

      // FR-GEA7: send only after the cooldown gate has cleared.
      await _notificationService.showEtiquetteAlert(
        id: attractionId.hashCode & 0x7fffffff,
        attractionName: attractionName,
        message: message,
        playSound: soundEnabled,
        enableVibration: vibrationEnabled,
      );

      // FR-GEA5: record only once the alert has actually been sent.
      final notificationId = await _notificationRepository.recordNotification(
        userId: _currentUserId,
        attractionId: attractionId,
        attractionName: attractionName,
        message: message,
        ruleIds: ruleIds,
        status: 'sent',
      );

      _activeAttractionId = attractionId;
      _activeAttractionName = attractionName;
      _activeNotificationId = notificationId;

      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<int> _resolveCooldownMinutes(
      Map<String, dynamic> attraction,
      ) async {
    final customCooldown = attraction['cooldownMinutes'];

    if (customCooldown is num) {
      return customCooldown.toInt();
    }

    final settings = await _environmentSettingsRepository.getSettings();

    return settings['defaultCooldownMinutes'] as int;
  }

  // =========================================================
  // EXIT (proposal Module 2 #2: "entry into and exit from")
  // =========================================================

  Future<void> _handleGeofenceExit(
      Map<String, dynamic> attraction,
      ) async {
    final attractionId = attraction['id']?.toString();

    if (_activeAttractionId == attractionId) {
      _activeAttractionId = null;
      _activeAttractionName = null;
      _activeNotificationId = null;
      _etiquetteRules = [];
    }

    notifyListeners();
  }

  // =========================================================
  // ETIQUETTE RULES (FR-GEA8)
  // =========================================================

  Future<void> loadEtiquetteRules(String attractionId) async {
    try {
      var rules = await _etiquetteRepository.getRulesByAttraction(
        attractionId,
      );

      // If no location-specific rules exist, fall back to category-level
      // guidance (proposal Module 2 #4).
      if (rules.isEmpty) {
        final attraction = _attractions.firstWhere(
              (item) => item['id']?.toString() == attractionId,
          orElse: () => const {},
        );

        final category = attraction['category']?.toString();

        if (category != null) {
          rules = await _etiquetteRepository.getRulesByCategory(category);
        }
      }

      _etiquetteRules = await _withPriorityScores(
        attractionId: attractionId,
        rules: rules,
      );

      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// UC02 FR-GEA8 / proposal Module 2 #4: the do's and don'ts shown in
  /// the alert should be "prioritised ... received from Module 4"
  /// (Etiquette Guidance & Violation Ranking). This merges each rule
  /// with its computed Priority Score from the `etiquette_rankings`
  /// collection and sorts highest priority first. Rules Module 4 hasn't
  /// scored yet (empty collection, or a rule not covered) fall back to
  /// severity so the alert still has a sensible order.
  Future<List<Map<String, dynamic>>> _withPriorityScores({
    required String attractionId,
    required List<Map<String, dynamic>> rules,
  }) async {
    final rankings = await _rankingReportRepository.getRankingByAttraction(
      attractionId,
    );

    final scoreByRuleId = <String, num>{};

    for (final ranking in rankings) {
      final ruleId = ranking['ruleId']?.toString();
      final score = ranking['priorityScore'];

      if (ruleId != null && score is num) {
        scoreByRuleId[ruleId] = score;
      }
    }

    final scoredRules = rules.map((rule) {
      final score = scoreByRuleId[rule['id']?.toString()];

      if (score == null) {
        return rule;
      }

      return {...rule, 'priorityScore': score};
    }).toList();

    scoredRules.sort((a, b) {
      final priorityA = a['priorityScore'] as num?;
      final priorityB = b['priorityScore'] as num?;

      // Ranked rules (from Module 4) always outrank unranked ones.
      if (priorityA != null && priorityB != null) {
        return priorityB.compareTo(priorityA);
      }
      if (priorityA != null) return -1;
      if (priorityB != null) return 1;

      final severityA = (a['severity'] ?? 0) as num;
      final severityB = (b['severity'] ?? 0) as num;

      return severityB.compareTo(severityA);
    });

    return scoredRules;
  }

  String _buildAlertMessage() {
    if (_etiquetteRules.isEmpty) {
      return 'You are entering a cultural attraction. '
          'Please respect the local etiquette.';
    }

    final importantRules = _etiquetteRules.take(2).toList();

    return importantRules
        .map((rule) {
      return rule['title']?.toString() ??
          rule['description']?.toString() ??
          '';
    })
        .where((message) => message.isNotEmpty)
        .join(' • ');
  }

  List<Map<String, dynamic>> getDos() {
    return _etiquetteRules
        .where(
          (rule) => rule['type']?.toString().toLowerCase() == 'do',
    )
        .toList();
  }

  List<Map<String, dynamic>> getDonts() {
    return _etiquetteRules
        .where(
          (rule) => rule['type']?.toString().toLowerCase() == 'dont',
    )
        .toList();
  }

  // =========================================================
  // MARK AS READ / DISMISS (UC02 A2; proposal Module 2 #5)
  // =========================================================

  Future<void> markActiveAlertRead() async {
    final notificationId = _activeNotificationId;

    if (notificationId == null) {
      return;
    }

    await _notificationRepository.markAsRead(notificationId);

    notifyListeners();
  }

  Future<void> dismissActiveAlert() async {
    final notificationId = _activeNotificationId;

    if (notificationId == null) {
      return;
    }

    await _notificationRepository.dismiss(notificationId);

    _activeAttractionId = null;
    _activeAttractionName = null;
    _activeNotificationId = null;

    notifyListeners();
  }

  // =========================================================
  // ALERT HISTORY (proposal Module 2 #6)
  // =========================================================

  Future<void> loadAlertHistory() async {
    try {
      _alertHistory =
      await _notificationRepository.getHistoryForUser(_currentUserId);

      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // =========================================================
  // ERROR
  // =========================================================

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
    _positionSubscription?.cancel();

    super.dispose();
  }
}
