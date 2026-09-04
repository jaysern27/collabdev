import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../../repositories/attraction/attraction_repository.dart';
import '../../repositories/notification/etiquette_notification_repository.dart';
import '../../repositories/ranking_report/ranking_report_repository.dart';
import '../../repositories/system_config/system_config_repository.dart';
import '../../repositories/user_preference/user_preference_repository.dart';
import '../location_geofencing/location_geofencing_service.dart';
import '../notification/notification_service.dart';

// UC02 – Receive Etiquette Alert (Basic Flow steps 1-7).
//
// Runs in the background for as long as a Tourist is logged in,
// independent of which screen is on top. Watches GPS position,
// detects entry into any nearby attraction's configured geofence,
// and sends a local etiquette notification subject to the
// tourist's notification preference and the per-attraction
// cooldown period.
class GeofenceAlertMonitorService {
  GeofenceAlertMonitorService._internal();

  static final GeofenceAlertMonitorService instance =
  GeofenceAlertMonitorService._internal();

  final AttractionRepository _attractionRepository =
  AttractionRepository();
  final UserPreferenceRepository _userPreferenceRepository =
  UserPreferenceRepository();
  final SystemConfigRepository _systemConfigRepository =
  SystemConfigRepository();
  final EtiquetteNotificationRepository
  _etiquetteNotificationRepository =
  EtiquetteNotificationRepository();
  final RankingReportRepository _rankingReportRepository =
  RankingReportRepository();
  final LocationGeofencingService _locationService =
  LocationGeofencingService();
  final NotificationService _notificationService =
  NotificationService();

  StreamSubscription<Position>? _positionSubscription;

  String? _userId;
  bool _isProcessing = false;

  // Tracks which attractions the tourist is currently inside, so
  // an alert only fires on the outside -> inside transition.
  final Map<String, bool> _insideGeofence = {};

  bool get isRunning => _positionSubscription != null;

  void start({required String userId}) {
    if (_positionSubscription != null && _userId == userId) {
      return;
    }

    stop();

    _userId = userId;

    _positionSubscription = _locationService.watchLocation().listen(
          _onPositionUpdate,
      onError: (_) {},
    );
  }

  void stop() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _userId = null;
    _insideGeofence.clear();
  }

  Future<void> _onPositionUpdate(Position position) async {
    final userId = _userId;

    if (userId == null || _isProcessing) {
      return;
    }

    _isProcessing = true;

    try {
      final nearbyAttractions = await _attractionRepository
          .getGeofenceEnabledAttractionsNear(position);

      final nearbyIds =
      nearbyAttractions.map((a) => a['id']?.toString()).toSet();

      // Attractions that fell outside the 5km pre-filter are no
      // longer "inside" for the purpose of entry detection.
      _insideGeofence.removeWhere(
            (id, _) => !nearbyIds.contains(id),
      );

      for (final attraction in nearbyAttractions) {
        await _checkAttraction(
          userId: userId,
          attraction: attraction,
          position: position,
        );
      }
    } catch (_) {
      // Swallow transient errors (e.g. a flaky Firestore read) so
      // the background monitor keeps running on the next position
      // update instead of crashing.
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _checkAttraction({
    required String userId,
    required Map<String, dynamic> attraction,
    required Position position,
  }) async {
    final attractionId = attraction['id']?.toString();
    final attractionName =
        attraction['name']?.toString() ?? 'Attraction';

    final center = AttractionRepository.geofenceCenter(attraction);
    final radius = attraction['geofenceRadiusMeters'];

    if (attractionId == null || center == null || radius is! num) {
      return;
    }

    final isInside = _locationService.isInsideGeofence(
      currentPosition: position,
      attractionLatitude: center['latitude']!,
      attractionLongitude: center['longitude']!,
      geofenceRadiusMeters: radius.toDouble(),
    );

    final wasInside = _insideGeofence[attractionId] ?? false;

    _insideGeofence[attractionId] = isInside;

    if (!wasInside && isInside) {
      await _sendAlertIfAllowed(
        userId: userId,
        attractionId: attractionId,
        attractionName: attractionName,
      );
    }
  }

  Future<void> _sendAlertIfAllowed({
    required String userId,
    required String attractionId,
    required String attractionName,
  }) async {
    // FR-GEA4: respect the tourist's notification preference.
    final preferences =
    await _userPreferenceRepository.getPreferences(userId);

    final notificationsEnabled =
        preferences?['notificationsEnabled'] != false;

    if (!notificationsEnabled) {
      return;
    }

    // FR-GEA6/C3: default cooldown duration set by Admin (UC03).
    final cooldownMinutes =
    await _systemConfigRepository.getDefaultCooldownMinutes();

    final message = await _buildAlertMessage(attractionId);

    // FR-GEA5/FR-GEA7/A1: record the notification and skip
    // sending it while an active cooldown applies.
    final allowedToSend =
    await _etiquetteNotificationRepository.recordIfAllowed(
      userId: userId,
      attractionId: attractionId,
      attractionName: attractionName,
      message: message,
      cooldownMinutes: cooldownMinutes,
    );

    if (!allowedToSend) {
      return;
    }

    await _notificationService.showEtiquetteAlert(
      id: attractionId.hashCode & 0x7fffffff,
      attractionName: attractionName,
      message: message,
      payload: attractionId,
    );
  }

  // Manually fires an alert for [attractionId] without waiting for
  // an actual geofence entry — for testing the notification /
  // inbox / etiquette-alert-screen flow without needing to be
  // physically near the attraction. Still records the alert (and
  // still respects the notification preference) so it behaves like
  // a real one, but ignores the cooldown so it can be pressed
  // repeatedly while testing.
  Future<void> sendTestAlert({
    required String userId,
    required String attractionId,
    required String attractionName,
  }) async {
    final preferences =
    await _userPreferenceRepository.getPreferences(userId);

    final notificationsEnabled =
        preferences?['notificationsEnabled'] != false;

    if (!notificationsEnabled) {
      return;
    }

    final message = await _buildAlertMessage(attractionId);

    await _etiquetteNotificationRepository.recordIfAllowed(
      userId: userId,
      attractionId: attractionId,
      attractionName: attractionName,
      message: message,
      cooldownMinutes: 0,
    );

    await _notificationService.showEtiquetteAlert(
      id: attractionId.hashCode & 0x7fffffff,
      attractionName: attractionName,
      message: message,
      payload: attractionId,
    );
  }

  // Surfaces that attraction's own violation ranking (Module 4,
  // approved UC04 reports) in the alert itself: the most commonly
  // reported issue at that specific location.
  Future<String> _buildAlertMessage(String attractionId) async {
    const fallback =
        'You are entering a cultural attraction. '
        'Tap to view the etiquette guidance.';

    try {
      final rankings = await _rankingReportRepository
          .getRankingByAttraction(attractionId);

      if (rankings.isEmpty) {
        return fallback;
      }

      final topIssue = rankings.first['ruleName']?.toString() ??
          rankings.first['category']?.toString();

      if (topIssue == null || topIssue.isEmpty) {
        return fallback;
      }

      return 'The most commonly reported issue here is: '
          '$topIssue. Tap to view the etiquette guidance.';
    } catch (_) {
      return fallback;
    }
  }
}
