import '../../services/firestore/firestore_service.dart';

class EtiquetteRepository {
  final FirestoreService _firestoreService;

  static const String _collection = 'etiquette_rules';

  EtiquetteRepository({
    FirestoreService? firestoreService,
  }) : _firestoreService =
      firestoreService ?? FirestoreService();

  // Get all etiquette rules
  Future<List<Map<String, dynamic>>> getAllEtiquetteRules() async {
    final snapshot = await _firestoreService.getCollection(
      collection: _collection,
    );

    return snapshot.docs
        .map(
          (doc) => {
        'id': doc.id,
        ...doc.data(),
      },
    )
        .toList();
  }

  // Get etiquette rules for one attraction
  Future<List<Map<String, dynamic>>> getRulesByAttraction(
      String attractionId,
      ) async {
    final rules = await getAllEtiquetteRules();

    return rules
        .where(
          (rule) => rule['attractionId'] == attractionId,
    )
        .toList();
  }

  // UC02 A2: an attraction's rules are split by a `scope` field
  // into "default" (general guidance for that destination, e.g.
  // dress code) and "location" (specific to that physical site).
  Future<List<Map<String, dynamic>>> getDefaultRulesForAttraction(
      String attractionId,
      ) async {
    final rules = await getRulesByAttraction(attractionId);

    return rules
        .where(
          (rule) =>
      (rule['scope']?.toString().toLowerCase() ??
          'default') ==
          'default',
    )
        .toList();
  }

  Future<List<Map<String, dynamic>>> getLocationRulesForAttraction(
      String attractionId,
      ) async {
    final rules = await getRulesByAttraction(attractionId);

    return rules
        .where(
          (rule) =>
      rule['scope']?.toString().toLowerCase() ==
          'location',
    )
        .toList();
  }

  // Get rules by category
  Future<List<Map<String, dynamic>>> getRulesByCategory(
      String category,
      ) async {
    final rules = await getAllEtiquetteRules();

    return rules
        .where(
          (rule) => rule['category'] == category,
    )
        .toList();
  }

  // Get only DO rules
  Future<List<Map<String, dynamic>>> getDos(
      String attractionId,
      ) async {
    final rules = await getRulesByAttraction(attractionId);

    return rules
        .where(
          (rule) =>
      rule['type']?.toString().toLowerCase() == 'do',
    )
        .toList();
  }

  // Get only DON'T rules
  Future<List<Map<String, dynamic>>> getDonts(
      String attractionId,
      ) async {
    final rules = await getRulesByAttraction(attractionId);

    return rules
        .where(
          (rule) =>
      rule['type']?.toString().toLowerCase() == 'dont',
    )
        .toList();
  }

  // Get dress-code related rules
  Future<List<Map<String, dynamic>>> getDressCodeRules(
      String attractionId,
      ) async {
    final rules = await getRulesByAttraction(attractionId);

    return rules
        .where(
          (rule) =>
      rule['ruleCategory']
          ?.toString()
          .toLowerCase() ==
          'dress_code',
    )
        .toList();
  }

  // Listen for real-time etiquette changes
  Stream<List<Map<String, dynamic>>> watchEtiquetteRules() {
    return _firestoreService
        .watchCollection(
      collection: _collection,
    )
        .map(
          (snapshot) => snapshot.docs
          .map(
            (doc) => {
          'id': doc.id,
          ...doc.data(),
        },
      )
          .toList(),
    );
  }
}