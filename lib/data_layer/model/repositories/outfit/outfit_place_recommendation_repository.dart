import '../attraction/cultural_map_repository.dart';
import '../../services/location_geofencing/cultural_map_location_service.dart';

class NearbyCulturalAttractionsResult {
  final List<Map<String, dynamic>> attractions;
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
  final CulturalMapRepository _culturalMapRepository;
  final CulturalMapLocationService _locationService;

  OutfitPlaceRecommendationRepository({
    CulturalMapRepository? culturalMapRepository,
    CulturalMapLocationService? locationService,
  })  : _culturalMapRepository =
            culturalMapRepository ?? CulturalMapRepository(),
        _locationService =
            locationService ?? CulturalMapLocationService();

  // Keep this aligned with the Cultural Map module.
  static const double defaultRadiusKm = 20.0;

  Future<NearbyCulturalAttractionsResult>
      getNearbyCulturalAttractions({
    double radiusKm = defaultRadiusKm,
  }) async {
    if (radiusKm <= 0) {
      throw ArgumentError(
        'radiusKm must be greater than 0.',
      );
    }

    final position =
        await _locationService.getCurrentPosition();

    final bool usingDefaultArea =
        position == null;

    final double userLatitude =
        position?.latitude ??
            CulturalMapLocationService.defaultLatitude;

    final double userLongitude =
        position?.longitude ??
            CulturalMapLocationService.defaultLongitude;

    final attractions =
        await _culturalMapRepository
            .getSupportedAttractions();

    final nearby = <Map<String, dynamic>>[];

    for (final attraction in attractions) {
      final latitude = _toDouble(
        attraction['latitude'],
      );

      final longitude = _toDouble(
        attraction['longitude'],
      );

      if (latitude == null ||
          longitude == null) {
        continue;
      }

      final distanceKm =
          _locationService.calculateDistanceInKm(
        startLatitude: userLatitude,
        startLongitude: userLongitude,
        endLatitude: latitude,
        endLongitude: longitude,
      );

      if (distanceKm > radiusKm) {
        continue;
      }

      nearby.add({
        ...attraction,
        'distanceKm': distanceKm,
        'distanceText':
            _locationService.formatDistance(
          distanceKm,
        ),
      });
    }

    nearby.sort(
      (first, second) {
        final firstDistance =
            (first['distanceKm'] as num?)
                    ?.toDouble() ??
                double.infinity;

        final secondDistance =
            (second['distanceKm'] as num?)
                    ?.toDouble() ??
                double.infinity;

        return firstDistance.compareTo(
          secondDistance,
        );
      },
    );

    return NearbyCulturalAttractionsResult(
      attractions: nearby,
      usingDefaultArea: usingDefaultArea,
      referenceLatitude: userLatitude,
      referenceLongitude: userLongitude,
    );
  }

  double? _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value?.toString() ?? '',
    );
  }
}
