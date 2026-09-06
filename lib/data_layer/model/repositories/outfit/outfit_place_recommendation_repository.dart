import '../attraction/cultural_map_repository.dart';

import 'outfit_etiquette_repository.dart';

import '../../services/location_geofencing/'
    'cultural_map_location_service.dart';

class NearbyCulturalAttractionsResult {
  final List<Map<String, dynamic>>
  attractions;

  final bool usingDefaultArea;

  final double referenceLatitude;

  final double referenceLongitude;

  const NearbyCulturalAttractionsResult({
    required this.attractions,
    required this.usingDefaultArea,
    required this.referenceLatitude,
    required this.referenceLongitude,
  });
}

class OutfitPlaceRecommendationRepository {
  final CulturalMapRepository
  _culturalMapRepository;

  final CulturalMapLocationService
  _locationService;

  final OutfitEtiquetteRepository
  _outfitEtiquetteRepository;

  OutfitPlaceRecommendationRepository({
    CulturalMapRepository?
    culturalMapRepository,
    CulturalMapLocationService?
    locationService,
    OutfitEtiquetteRepository?
    outfitEtiquetteRepository,
  })  : _culturalMapRepository =
      culturalMapRepository ??
          CulturalMapRepository(),
        _locationService =
            locationService ??
                CulturalMapLocationService(),
        _outfitEtiquetteRepository =
            outfitEtiquetteRepository ??
                OutfitEtiquetteRepository();

  // =========================================================
  // SAME RADIUS AS CULTURAL MAP
  // =========================================================

  static const double
  defaultRadiusKm =
  20.0;

  // =========================================================
  // GET NEARBY CULTURAL ATTRACTIONS
  // =========================================================

  Future<NearbyCulturalAttractionsResult>
  getNearbyCulturalAttractions({
    double radiusKm =
        defaultRadiusKm,
  }) async {
    if (radiusKm <= 0) {
      throw ArgumentError(
        'radiusKm must be greater than 0.',
      );
    }

    final position =
    await _locationService
        .getCurrentPosition();

    final bool usingDefaultArea =
        position == null;

    final double userLatitude =
        position?.latitude ??
            CulturalMapLocationService
                .defaultLatitude;

    final double userLongitude =
        position?.longitude ??
            CulturalMapLocationService
                .defaultLongitude;

    final attractions =
    await _culturalMapRepository
        .getSupportedAttractions();

    final nearby =
    <Map<String, dynamic>>[];

    for (final attraction
    in attractions) {
      final latitude =
      _toDouble(
        attraction['latitude'],
      );

      final longitude =
      _toDouble(
        attraction['longitude'],
      );

      if (latitude == null ||
          longitude == null) {
        continue;
      }

      final distanceKm =
      _locationService
          .calculateDistanceInKm(
        startLatitude:
        userLatitude,
        startLongitude:
        userLongitude,
        endLatitude:
        latitude,
        endLongitude:
        longitude,
      );

      if (distanceKm >
          radiusKm) {
        continue;
      }

      nearby.add({
        ...attraction,
        'distanceKm':
        distanceKm,
        'distanceText':
        _locationService
            .formatDistance(
          distanceKm,
        ),
      });
    }

    nearby.sort(
          (first, second) {
        final firstDistance =
            (first['distanceKm']
            as num?)
                ?.toDouble() ??
                double.infinity;

        final secondDistance =
            (second['distanceKm']
            as num?)
                ?.toDouble() ??
                double.infinity;

        return firstDistance
            .compareTo(
          secondDistance,
        );
      },
    );

    return NearbyCulturalAttractionsResult(
      attractions: nearby,
      usingDefaultArea:
      usingDefaultArea,
      referenceLatitude:
      userLatitude,
      referenceLongitude:
      userLongitude,
    );
  }

  // =========================================================
  // GET STRUCTURED OUTFIT RULES FOR CATEGORY
  //
  // Firestore stores simple rules:
  //
  // sleeve: covered
  // lowerbody: covered
  // shoulder: covered
  // headwear: optional
  //
  // But OutfitRecognitionService expects:
  //
  // attribute
  // acceptedValues
  //
  // This method translates between them.
  // =========================================================

  Future<List<Map<String, dynamic>>>
  getStructuredDressCodeRulesForCategory(
      String category,
      ) async {
    final etiquette =
    await _outfitEtiquetteRepository
        .getOutfitByCategory(
      category,
    );

    if (etiquette == null) {
      return [];
    }

    final rules =
    <Map<String, dynamic>>[];

    // =======================================================
    // SLEEVE
    // =======================================================

    _addRule(
      target: rules,
      attribute:
      'sleeveCoverage',
      title:
      'Sleeve Requirement',
      requirement:
      etiquette['sleeve'],
      acceptedValuesFor:
      _acceptedSleeveValues,
    );

    // =======================================================
    // LOWER BODY
    // =======================================================

    _addRule(
      target: rules,
      attribute:
      'lowerBodyCoverage',
      title:
      'Lower-Body Requirement',
      requirement:
      etiquette['lowerbody'] ??
          etiquette[
          'lowerBody'],
      acceptedValuesFor:
      _acceptedLowerBodyValues,
    );

    // =======================================================
    // SHOULDER
    // =======================================================

    _addRule(
      target: rules,
      attribute:
      'shoulderCoverage',
      title:
      'Shoulder Requirement',
      requirement:
      etiquette['shoulder'],
      acceptedValuesFor:
      _acceptedShoulderValues,
    );

    // =======================================================
    // HEADWEAR
    // =======================================================

    _addRule(
      target: rules,
      attribute:
      'headwearPresence',
      title:
      'Headwear Requirement',
      requirement:
      etiquette['headwear'],
      acceptedValuesFor:
      _acceptedHeadwearValues,
    );

    return rules;
  }

  // =========================================================
  // ADD ONE STRUCTURED RULE
  // =========================================================

  void _addRule({
    required List<Map<String, dynamic>>
    target,
    required String attribute,
    required String title,
    required dynamic requirement,
    required List<String> Function(
        String requirement,
        )
    acceptedValuesFor,
  }) {
    final cleanedRequirement =
    _normaliseRequirement(
      requirement,
    );

    if (cleanedRequirement
        .isEmpty) {
      return;
    }

    final acceptedValues =
    acceptedValuesFor(
      cleanedRequirement,
    );

    if (acceptedValues
        .isEmpty) {
      return;
    }

    target.add({
      'attribute':
      attribute,
      'title':
      title,
      'acceptedValues':
      acceptedValues,
      'isActive':
      true,

      // Helpful for debugging.
      'sourceRequirement':
      cleanedRequirement,
    });
  }

  // =========================================================
  // SLEEVE TRANSLATION
  // =========================================================

  List<String>
  _acceptedSleeveValues(
      String requirement,
      ) {
    switch (requirement) {
      case 'optional':
      case 'not required':
        return const [
          'long',
          'short',
          'sleeveless',
        ];

      case 'covered':
        return const [
          'long',
          'short',
        ];

      case 'long':
      case 'long sleeve':
      case 'long sleeves':
        return const [
          'long',
        ];

      case 'short':
      case 'short sleeve':
      case 'short sleeves':
        return const [
          'short',
        ];

      case 'sleeveless':
        return const [
          'sleeveless',
        ];

      default:
        return const [];
    }
  }

  // =========================================================
  // LOWER BODY TRANSLATION
  // =========================================================

  List<String>
  _acceptedLowerBodyValues(
      String requirement,
      ) {
    switch (requirement) {
      case 'optional':
      case 'not required':
        return const [
          'short',
          'medium',
          'long',
        ];

    // This follows the rule we agreed on:
    //
    // Firestore "covered"
    // maps to the AI model's "long".
    //
    // If you later want "covered" to allow
    // medium too, change this to:
    //
    // ['medium', 'long']

      case 'covered':
        return const [
          'long',
        ];

      case 'long':
      case 'maxi':
      case 'floor':
      case 'floor length':
        return const [
          'long',
        ];

      case 'medium':
      case 'midi':
      case 'knee':
      case 'knee length':
        return const [
          'medium',
        ];

      case 'short':
        return const [
          'short',
        ];

      default:
        return const [];
    }
  }

  // =========================================================
  // SHOULDER TRANSLATION
  // =========================================================

  List<String>
  _acceptedShoulderValues(
      String requirement,
      ) {
    switch (requirement) {
      case 'optional':
      case 'not required':
        return const [
          'covered',
          'uncovered',
        ];

      case 'covered':
        return const [
          'covered',
        ];

      case 'uncovered':
        return const [
          'uncovered',
        ];

      default:
        return const [];
    }
  }

  // =========================================================
  // HEADWEAR TRANSLATION
  // =========================================================

  List<String>
  _acceptedHeadwearValues(
      String requirement,
      ) {
    switch (requirement) {
      case 'optional':
      case 'not required':
        return const [
          'headwear',
          'no_headwear',
        ];

      case 'required':
      case 'covered':
      case 'yes':
      case 'headwear':
        return const [
          'headwear',
        ];

      case 'none':
      case 'no':
      case 'no headwear':
        return const [
          'no_headwear',
        ];

      default:
        return const [];
    }
  }

  // =========================================================
  // REQUIREMENT NORMALISATION
  // =========================================================

  String _normaliseRequirement(
      dynamic value,
      ) {
    return value
        ?.toString()
        .trim()
        .toLowerCase()
        .replaceAll(
      '_',
      ' ',
    )
        .replaceAll(
      '-',
      ' ',
    )
        .replaceAll(
      RegExp(r'\s+'),
      ' ',
    ) ??
        '';
  }

  // =========================================================
  // DOUBLE CONVERSION
  // =========================================================

  double? _toDouble(
      dynamic value,
      ) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value?.toString() ??
          '',
    );
  }
}