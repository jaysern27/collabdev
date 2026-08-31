import '../../services/firestore/firestore_service.dart';

/// Backs UC03 (Setup Environment Parameter). Holds the single
/// admin-configurable default cooldown duration plus the allowable ranges
/// for geofence radius and cooldown duration referenced by UC03's
/// constraints C2/C3, which the design specification left as an
/// unspecified "system-defined allowable range". Concrete defaults are
/// filled in here so E2/E3 are actually testable.
class EnvironmentSettingsRepository {
  final FirestoreService _firestoreService;

  static const String _collection = 'environment_settings';
  static const String _documentId = 'default';

  // Fallback values used until an Admin saves a document, and the
  // authoritative allowable ranges enforced by validateGeofenceRadius /
  // validateCooldownMinutes below.
  static const int defaultCooldownMinutes = 60;
  static const int minCooldownMinutes = 15;
  static const int maxCooldownMinutes = 1440; // 24 hours

  static const double minGeofenceRadiusMeters = 20;
  static const double maxGeofenceRadiusMeters = 1000;

  EnvironmentSettingsRepository({
    FirestoreService? firestoreService,
  }) : _firestoreService =
      firestoreService ?? FirestoreService();

  // =========================================================
  // READ (UC02 C3 / FR-GEA6)
  // =========================================================

  Future<Map<String, dynamic>> getSettings() async {
    final document = await _firestoreService.getDocument(
      collection: _collection,
      documentId: _documentId,
    );

    final data = document.data();

    return {
      'defaultCooldownMinutes':
      data?['defaultCooldownMinutes'] ?? defaultCooldownMinutes,
      'minCooldownMinutes':
      data?['minCooldownMinutes'] ?? minCooldownMinutes,
      'maxCooldownMinutes':
      data?['maxCooldownMinutes'] ?? maxCooldownMinutes,
      'minGeofenceRadiusMeters':
      data?['minGeofenceRadiusMeters'] ?? minGeofenceRadiusMeters,
      'maxGeofenceRadiusMeters':
      data?['maxGeofenceRadiusMeters'] ?? maxGeofenceRadiusMeters,
    };
  }

  Stream<Map<String, dynamic>> watchSettings() {
    return _firestoreService
        .watchCollection(collection: _collection)
        .asyncMap((_) => getSettings());
  }

  // =========================================================
  // WRITE (UC03 A3 / FR-GEA10)
  // =========================================================

  /// Throws if [minutes] falls outside the allowable range (UC03 E3).
  Future<void> updateDefaultCooldown(int minutes) async {
    final settings = await getSettings();

    final min = settings['minCooldownMinutes'] as int;
    final max = settings['maxCooldownMinutes'] as int;

    if (minutes < min || minutes > max) {
      throw Exception(
        'Invalid cooldown duration. Please enter a value between '
            '$min and $max minutes.',
      );
    }

    await _firestoreService.setDocument(
      collection: _collection,
      documentId: _documentId,
      data: {
        ...settings,
        'defaultCooldownMinutes': minutes,
        'updatedAt': DateTime.now().toIso8601String(),
      },
    );
  }

  // =========================================================
  // VALIDATION HELPERS (UC03 E2 / E3)
  // =========================================================

  Future<void> validateGeofenceRadius(double radiusMeters) async {
    final settings = await getSettings();

    final min = settings['minGeofenceRadiusMeters'] as double;
    final max = settings['maxGeofenceRadiusMeters'] as double;

    if (radiusMeters < min || radiusMeters > max) {
      throw Exception(
        'Invalid radius. Please enter a value between '
            '${min.toStringAsFixed(0)}m and '
            '${max.toStringAsFixed(0)}m.',
      );
    }
  }
}
