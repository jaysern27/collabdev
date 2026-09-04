import '../../services/firestore/firestore_service.dart';

// UC03 – Configure Cooldown Settings.
// A single config document shared by the whole app.
class SystemConfigRepository {
  final FirestoreService _firestoreService;

  static const String _collection = 'system_config';
  static const String _etiquetteAlertDocId = 'etiquette_alert';

  static const int defaultCooldownMinutesFallback = 30;

  SystemConfigRepository({
    FirestoreService? firestoreService,
  }) : _firestoreService =
      firestoreService ?? FirestoreService();

  Future<int> getDefaultCooldownMinutes() async {
    final document = await _firestoreService.getDocument(
      collection: _collection,
      documentId: _etiquetteAlertDocId,
    );

    if (!document.exists) {
      return defaultCooldownMinutesFallback;
    }

    final minutes = document.data()?['defaultCooldownMinutes'];

    if (minutes is num && minutes > 0) {
      return minutes.round();
    }

    return defaultCooldownMinutesFallback;
  }

  Future<void> setDefaultCooldownMinutes(
      int minutes,
      ) async {
    await _firestoreService.setDocument(
      collection: _collection,
      documentId: _etiquetteAlertDocId,
      data: {
        'defaultCooldownMinutes': minutes,
      },
    );
  }
}
