import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data_layer/model/repositories/etiquette/etiquette_repository.dart';
import '../../../data_layer/model/services/location_geofencing/location_geofencing_service.dart';
import '../../../data_layer/model/services/notification/notification_service.dart';

class EtiquetteAlertViewModel extends ChangeNotifier {
  final EtiquetteRepository _etiquetteRepository;
  final LocationGeofencingService _locationService;
  final NotificationService _notificationService;

  EtiquetteAlertViewModel({
    EtiquetteRepository? etiquetteRepository,
    LocationGeofencingService? locationService,
    NotificationService? notificationService,
  })  : _etiquetteRepository =
      etiquetteRepository ?? EtiquetteRepository(),
        _locationService =
            locationService ?? LocationGeofencingService(),
        _notificationService =
            notificationService ?? NotificationService();

  StreamSubscription<bool>? _geofenceSubscription;

  List<Map<String, dynamic>> _etiquetteRules = [];

  bool _isInsideGeofence = false;
  bool _isMonitoring = false;
  bool _isLoading = false;

  String? _currentAttractionId;
  String? _currentAttractionName;
  String? _errorMessage;

  DateTime? _lastAlertTime;

  List<Map<String, dynamic>> get etiquetteRules =>
      _etiquetteRules;

  bool get isInsideGeofence => _isInsideGeofence;

  bool get isMonitoring => _isMonitoring;

  bool get isLoading => _isLoading;

  String? get currentAttractionId =>
      _currentAttractionId;

  String? get currentAttractionName =>
      _currentAttractionName;

  String? get errorMessage => _errorMessage;

  DateTime? get lastAlertTime => _lastAlertTime;

  // Load etiquette rules for one attraction
  Future<void> loadEtiquetteRules(
      String attractionId,
      ) async {
    _setLoading(true);

    try {
      _errorMessage = null;

      _etiquetteRules =
      await _etiquetteRepository.getRulesByAttraction(
        attractionId,
      );

      // Higher severity rules appear first
      _etiquetteRules.sort((a, b) {
        final severityA =
        (a['severity'] ?? 0) as num;

        final severityB =
        (b['severity'] ?? 0) as num;

        return severityB.compareTo(severityA);
      });
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // Start monitoring one attraction's geofence
  Future<void> startMonitoringAttraction({
    required String attractionId,
    required String attractionName,
    required double latitude,
    required double longitude,
    required double geofenceRadiusMeters,
  }) async {
    await stopMonitoring();

    _currentAttractionId = attractionId;
    _currentAttractionName = attractionName;
    _isInsideGeofence = false;
    _isMonitoring = true;
    _errorMessage = null;

    await loadEtiquetteRules(attractionId);

    _geofenceSubscription =
        _locationService
            .watchGeofence(
          attractionLatitude: latitude,
          attractionLongitude: longitude,
          geofenceRadiusMeters:
          geofenceRadiusMeters,
        )
            .listen(
              (inside) async {
            final wasInside = _isInsideGeofence;

            _isInsideGeofence = inside;

            notifyListeners();

            // Trigger only when user moves from
            // outside -> inside the geofence.
            if (!wasInside && inside) {
              await _handleGeofenceEntry();
            }
          },
          onError: (error) {
            _errorMessage = error.toString();

            notifyListeners();
          },
        );

    notifyListeners();
  }

  // Called when user enters attraction area
  Future<void> _handleGeofenceEntry() async {
    if (!_canSendAlert()) {
      return;
    }

    final attractionId = _currentAttractionId;
    final attractionName = _currentAttractionName;

    if (attractionId == null ||
        attractionName == null) {
      return;
    }

    if (_etiquetteRules.isEmpty) {
      await loadEtiquetteRules(attractionId);
    }

    final message = _buildAlertMessage();

    await _notificationService.showEtiquetteAlert(
      id: attractionId.hashCode & 0x7fffffff,
      attractionName: attractionName,
      message: message,
    );

    _lastAlertTime = DateTime.now();

    notifyListeners();
  }

  // Prevent repeated notifications
  bool _canSendAlert() {
    if (_lastAlertTime == null) {
      return true;
    }

    final difference =
    DateTime.now().difference(
      _lastAlertTime!,
    );

    // 30-minute cooldown
    return difference.inMinutes >= 30;
  }

  // Build notification using important etiquette rules
  String _buildAlertMessage() {
    if (_etiquetteRules.isEmpty) {
      return 'You are entering a cultural attraction. '
          'Please respect the local etiquette.';
    }

    final importantRules =
    _etiquetteRules.take(2).toList();

    return importantRules
        .map((rule) {
      return rule['title']?.toString() ??
          rule['description']?.toString() ??
          '';
    })
        .where(
          (message) => message.isNotEmpty,
    )
        .join(' • ');
  }

  // Get DO rules for the alert screen
  List<Map<String, dynamic>> getDos() {
    return _etiquetteRules.where((rule) {
      return rule['type']
          ?.toString()
          .toLowerCase() ==
          'do';
    }).toList();
  }

  // Get DON'T rules for the alert screen
  List<Map<String, dynamic>> getDonts() {
    return _etiquetteRules.where((rule) {
      return rule['type']
          ?.toString()
          .toLowerCase() ==
          'dont';
    }).toList();
  }

  // Stop GPS/geofence monitoring
  Future<void> stopMonitoring() async {
    await _geofenceSubscription?.cancel();

    _geofenceSubscription = null;
    _isMonitoring = false;
    _isInsideGeofence = false;

    notifyListeners();
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
    _geofenceSubscription?.cancel();

    super.dispose();
  }
}