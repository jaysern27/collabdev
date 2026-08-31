import 'package:flutter/foundation.dart';

import '../../../data_layer/model/repositories/attraction/attraction_repository.dart';
import '../../../data_layer/model/repositories/environment_settings/environment_settings_repository.dart';

/// UC03_Setup Environment Parameter (Admin).
///
/// Covers all three alternative flows: A1 Manage Attraction Records
/// (FR-CMF7), A2 Configure Geofence (FR-GEA9), and A3 Configure Cooldown
/// Settings (FR-GEA10). Validation ranges come from
/// EnvironmentSettingsRepository so E2/E3 have concrete, testable bounds
/// instead of an unspecified "system-defined allowable range".
class EnvironmentParameterViewModel extends ChangeNotifier {
  final AttractionRepository _attractionRepository;
  final EnvironmentSettingsRepository _environmentSettingsRepository;

  EnvironmentParameterViewModel({
    AttractionRepository? attractionRepository,
    EnvironmentSettingsRepository? environmentSettingsRepository,
  })  : _attractionRepository =
      attractionRepository ?? AttractionRepository(),
        _environmentSettingsRepository =
            environmentSettingsRepository ??
                EnvironmentSettingsRepository();

  List<Map<String, dynamic>> _attractions = [];

  Map<String, dynamic> _environmentSettings = {};

  bool _isLoading = false;

  String? _errorMessage;
  String? _successMessage;

  List<Map<String, dynamic>> get attractions => _attractions;

  Map<String, dynamic> get environmentSettings => _environmentSettings;

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  String? get successMessage => _successMessage;

  // =========================================================
  // LOAD (UC03 BF-1..BF-2)
  // =========================================================

  Future<void> loadManagementData() async {
    _setLoading(true);

    try {
      _errorMessage = null;

      // Admin must see disabled attractions too, otherwise switching one
      // off makes it vanish from this screen with no way back in.
      _attractions = await _attractionRepository.getAllAttractionsForAdmin();

      _environmentSettings =
      await _environmentSettingsRepository.getSettings();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // =========================================================
  // A1 - MANAGE ATTRACTION RECORDS (FR-CMF7, C1, E1)
  // =========================================================

  Future<bool> saveAttraction({
    String? attractionId,
    required Map<String, dynamic> attractionData,
  }) async {
    _clearMessages();

    try {
      if (attractionId == null) {
        await _attractionRepository.createAttraction(attractionData);
      } else {
        await _attractionRepository.updateAttraction(
          attractionId: attractionId,
          attractionData: attractionData,
        );
      }

      _successMessage = 'Attraction saved and enabled on the cultural map.';

      await loadManagementData();

      return true;
    } catch (e) {
      // E1 - Invalid or Duplicate Attraction Data
      _errorMessage = e.toString();

      notifyListeners();

      return false;
    }
  }

  Future<void> setAttractionEnabled({
    required String attractionId,
    required bool isSupported,
  }) async {
    await _attractionRepository.setAttractionEnabled(
      attractionId: attractionId,
      isSupported: isSupported,
    );

    await loadManagementData();
  }

  // =========================================================
  // A2 - CONFIGURE GEOFENCE (FR-GEA9, C2, E2)
  // =========================================================

  Future<bool> saveGeofence({
    required String attractionId,
    required double radiusMeters,
    required bool isActive,
  }) async {
    _clearMessages();

    try {
      // E2 - Invalid Geofence Radius, validated against the
      // Admin-defined allowable range before saving.
      await _environmentSettingsRepository.validateGeofenceRadius(
        radiusMeters,
      );

      await _attractionRepository.updateGeofence(
        attractionId: attractionId,
        radiusMeters: radiusMeters,
        isActive: isActive,
      );

      _successMessage = 'Geofence configuration saved successfully.';

      await loadManagementData();

      return true;
    } catch (e) {
      _errorMessage = e.toString();

      notifyListeners();

      return false;
    }
  }

  // =========================================================
  // A3 - CONFIGURE COOLDOWN SETTINGS (FR-GEA10, C3, E3)
  // =========================================================

  Future<bool> saveDefaultCooldown(int minutes) async {
    _clearMessages();

    try {
      // E3 - Invalid Cooldown Duration
      await _environmentSettingsRepository.updateDefaultCooldown(minutes);

      _successMessage = 'Default cooldown duration updated successfully.';

      await loadManagementData();

      return true;
    } catch (e) {
      _errorMessage = e.toString();

      notifyListeners();

      return false;
    }
  }

  // =========================================================
  // MESSAGES / STATE
  // =========================================================

  void _clearMessages() {
    _errorMessage = null;
    _successMessage = null;
  }

  void clearMessages() {
    _clearMessages();

    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;

    notifyListeners();
  }
}
