import 'dart:io';

import 'package:flutter/widgets.dart';

import '../data_layer/model/repositories/attraction/attraction_repository.dart';
import '../external_data_sources/firebase/firebase_data_source.dart';

/// One-off fix: re-enables every attraction that was switched off while
/// testing the (now-fixed) Admin > Environment Settings screen.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await FirebaseDataSource.instance.initialize();

  final attractionRepository = AttractionRepository();

  final attractions = await attractionRepository.getAllAttractionsForAdmin();

  var reEnabledCount = 0;

  for (final attraction in attractions) {
    if (attraction['isSupported'] != true) {
      await attractionRepository.setAttractionEnabled(
        attractionId: attraction['id'].toString(),
        isSupported: true,
      );

      reEnabledCount++;
    }
  }

  // ignore: avoid_print
  print('FIX_RESULT::Re-enabled $reEnabledCount of ${attractions.length} '
      'attractions.');

  exit(0);
}
