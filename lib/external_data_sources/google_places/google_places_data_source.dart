import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class GooglePlacesDataSource {
  static const String _apiKey = String.fromEnvironment('GOOGLE_PLACES_API_KEY');

  final Map<String, Map<String, dynamic>> _cache =
      <String, Map<String, dynamic>>{};

  final Map<String, DateTime> _cacheTimes = <String, DateTime>{};

  static const Duration _cacheTtl = Duration(minutes: 5);

  bool get isConfigured => _apiKey.trim().isNotEmpty;

  Future<Map<String, dynamic>> getDisplayData(
    Map<String, dynamic> attraction,
  ) async {
    if (kIsWeb || !isConfigured) {
      if (!isConfigured) {
        debugPrint(
          'Google Places: GOOGLE_PLACES_API_KEY is missing. '
          'Using Firestore fallback.',
        );
      }

      return const <String, dynamic>{};
    }

    final name = (attraction['name'] ?? '').toString().trim();

    if (name.isEmpty) {
      return const <String, dynamic>{};
    }

    final latitude = _toDouble(attraction['latitude']);

    final longitude = _toDouble(attraction['longitude']);

    final id = (attraction['id'] ?? name).toString();

    final cacheKey = '$id|${latitude ?? ''}|${longitude ?? ''}';

    final cached = _cache[cacheKey];

    final cachedAt = _cacheTimes[cacheKey];

    if (cached != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < _cacheTtl) {
      return Map<String, dynamic>.from(cached);
    }

    try {
      debugPrint('Google Places: fetching live data for "$name"...');

      final place = await _searchBestPlace(
        name: name,
        latitude: latitude,
        longitude: longitude,
      ).timeout(const Duration(seconds: 10));

      if (place == null) {
        debugPrint('Google Places: no matching place found for "$name".');

        return const <String, dynamic>{};
      }

      final result = _toDisplayData(place);

      _cache[cacheKey] = Map<String, dynamic>.from(result);

      _cacheTimes[cacheKey] = DateTime.now();

      debugPrint(
        'Google Places: success for "$name" '
        'rating=${result['rating']} '
        'status=${result['status']} '
        'photo=${result['imageUrl'] != null}',
      );

      return result;
    } catch (error) {
      debugPrint('Google Places enrichment failed for "$name": $error');

      return const <String, dynamic>{};
    }
  }

  Future<Map<String, dynamic>?> _searchBestPlace({
    required String name,
    required double? latitude,
    required double? longitude,
  }) async {
    final uri = Uri.https('places.googleapis.com', '/v1/places:searchText');

    final body = <String, dynamic>{
      'textQuery': name,
      'pageSize': 5,
      'languageCode': 'en',
      'regionCode': 'MY',
      if (latitude != null && longitude != null)
        'locationBias': {
          'circle': {
            'center': {'latitude': latitude, 'longitude': longitude},
            'radius': 2500.0,
          },
        },
    };

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': _apiKey,
        'X-Goog-FieldMask':
            'places.id,'
            'places.displayName,'
            'places.location,'
            'places.rating,'
            'places.userRatingCount,'
            'places.businessStatus,'
            'places.currentOpeningHours,'
            'places.photos',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Places Text Search returned '
        '${response.statusCode}: '
        '${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map) {
      return null;
    }

    final rawPlaces = decoded['places'];

    if (rawPlaces is! List || rawPlaces.isEmpty) {
      return null;
    }

    final places = rawPlaces
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    if (places.isEmpty) {
      return null;
    }

    if (latitude == null || longitude == null) {
      return places.first;
    }

    Map<String, dynamic>? best;
    var bestDistance = double.infinity;

    for (final place in places) {
      final location = place['location'];

      if (location is! Map) {
        continue;
      }

      final placeLatitude = _toDouble(location['latitude']);

      final placeLongitude = _toDouble(location['longitude']);

      if (placeLatitude == null || placeLongitude == null) {
        continue;
      }

      final distance = _distanceMeters(
        latitude,
        longitude,
        placeLatitude,
        placeLongitude,
      );

      if (distance < bestDistance) {
        bestDistance = distance;
        best = place;
      }
    }

    if (best != null && bestDistance <= 5000) {
      return best;
    }

    return places.first;
  }

  Map<String, dynamic> _toDisplayData(Map<String, dynamic> place) {
    final result = <String, dynamic>{};

    final rating = place['rating'];

    if (rating is num) {
      result['rating'] = rating.toDouble();
    }

    final status = _statusFromPlace(place);

    if (status != null) {
      result['status'] = status;
    }

    final photos = place['photos'];

    if (photos is List && photos.isNotEmpty && photos.first is Map) {
      final photo = Map<String, dynamic>.from(photos.first as Map);

      final photoName = (photo['name'] ?? '').toString().trim();

      if (photoName.isNotEmpty) {
        result['imageUrl'] = Uri.https(
          'places.googleapis.com',
          '/v1/$photoName/media',
          {'maxWidthPx': '1200', 'key': _apiKey},
        ).toString();
      }

      final attributions = photo['authorAttributions'];

      if (attributions is List && attributions.isNotEmpty) {
        final names = <String>[];

        for (final item in attributions) {
          if (item is! Map) {
            continue;
          }

          final displayName = (item['displayName'] ?? '').toString().trim();

          if (displayName.isNotEmpty) {
            names.add(displayName);
          }
        }

        if (names.isNotEmpty) {
          result['photoAttribution'] = names.join(', ');
        }
      }
    }

    return result;
  }

  String? _statusFromPlace(Map<String, dynamic> place) {
    final businessStatus = (place['businessStatus'] ?? '')
        .toString()
        .trim()
        .toUpperCase();

    if (businessStatus == 'CLOSED_TEMPORARILY') {
      return 'Temporarily Closed';
    }

    if (businessStatus == 'CLOSED_PERMANENTLY') {
      return 'Permanently Closed';
    }

    final currentHours = place['currentOpeningHours'];

    if (currentHours is Map) {
      final openNow = currentHours['openNow'];

      if (openNow is bool) {
        return openNow ? 'Open' : 'Closed';
      }
    }

    return null;
  }

  static double? _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '');
  }

  static double _distanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371000.0;

    double toRadians(double value) => value * math.pi / 180.0;

    final dLat = toRadians(lat2 - lat1);

    final dLon = toRadians(lon2 - lon1);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(toRadians(lat1)) *
            math.cos(toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }
}
