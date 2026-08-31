import 'package:flutter/foundation.dart';

import '../../../data_layer/model/repositories/environment_settings/environment_settings_repository.dart';
import '../../../data_layer/model/repositories/user_preference/user_preference_repository.dart';
import '../../../data_layer/model/services/firebase_authentication/firebase_authentication_service.dart';

/// General settings for etiquette notifications (UC02 FR-GEA4): whether
/// the Tourist wants to receive them at all, and whether they play sound
/// / vibrate. The cooldown duration is shown for context but is
/// Admin-controlled (UC03), not editable here.
class NotificationSettingsViewModel extends ChangeNotifier {
  final UserPreferenceRepository _userPreferenceRepository;
  final EnvironmentSettingsRepository _environmentSettingsRepository;
  final FirebaseAuthenticationService _authenticationService;

  NotificationSettingsViewModel({
    UserPreferenceRepository? userPreferenceRepository,
    EnvironmentSettingsRepository? environmentSettingsRepository,
    FirebaseAuthenticationService? authenticationService,
  })  : _userPreferenceRepository =
      userPreferenceRepository ?? UserPreferenceRepository(),
        _environmentSettingsRepository =
            environmentSettingsRepository ?? EnvironmentSettingsRepository(),
        _authenticationService =
            authenticationService ?? FirebaseAuthenticationService();

  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;

  int? _defaultCooldownMinutes;

  bool _isLoading = false;
  bool _isSaving = false;

  String? _errorMessage;

  bool get notificationsEnabled => _notificationsEnabled;

  bool get soundEnabled => _soundEnabled;

  bool get vibrationEnabled => _vibrationEnabled;

  int? get defaultCooldownMinutes => _defaultCooldownMinutes;

  bool get isLoading => _isLoading;

  bool get isSaving => _isSaving;

  String? get errorMessage => _errorMessage;

  String get _currentUserId =>
      _authenticationService.currentUser?.uid ?? 'guest';

  Future<void> loadSettings() async {
    _isLoading = true;
    notifyListeners();

    try {
      _errorMessage = null;

      final preferences =
      await _userPreferenceRepository.getPreferences(_currentUserId);

      _notificationsEnabled = preferences?['notificationsEnabled'] != false;
      _soundEnabled = preferences?['soundEnabled'] != false;
      _vibrationEnabled = preferences?['vibrationEnabled'] != false;

      final environmentSettings =
      await _environmentSettingsRepository.getSettings();

      _defaultCooldownMinutes =
      environmentSettings['defaultCooldownMinutes'] as int?;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setNotificationsEnabled(bool value) async {
    _notificationsEnabled = value;
    notifyListeners();

    await _persist();
  }

  Future<void> setSoundEnabled(bool value) async {
    _soundEnabled = value;
    notifyListeners();

    await _persist();
  }

  Future<void> setVibrationEnabled(bool value) async {
    _vibrationEnabled = value;
    notifyListeners();

    await _persist();
  }

  Future<void> _persist() async {
    _isSaving = true;
    notifyListeners();

    try {
      _errorMessage = null;

      await _userPreferenceRepository.updateNotificationSettings(
        userId: _currentUserId,
        notificationsEnabled: _notificationsEnabled,
        soundEnabled: _soundEnabled,
        vibrationEnabled: _vibrationEnabled,
      );
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
