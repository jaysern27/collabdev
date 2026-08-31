import 'dart:io';

import 'package:flutter/widgets.dart';

import '../data_layer/model/repositories/attraction/attraction_repository.dart';
import '../data_layer/model/services/firestore/firestore_service.dart';
import '../data_layer/model/repositories/environment_settings/environment_settings_repository.dart';
import '../data_layer/model/repositories/etiquette/etiquette_repository.dart';
import '../data_layer/model/repositories/notification/notification_repository.dart';
import '../data_layer/model/repositories/ranking_report/ranking_report_repository.dart';
import '../external_data_sources/firebase/firebase_data_source.dart';

/// Diagnostic-only entry point: prints what already exists in Firestore
/// so seeding decisions can be made on real data instead of guesses.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await FirebaseDataSource.instance.initialize();

  final attractionRepository = AttractionRepository();
  final etiquetteRepository = EtiquetteRepository();
  final notificationRepository = NotificationRepository();
  final environmentSettingsRepository = EnvironmentSettingsRepository();

  final attractions = await attractionRepository.getAllAttractions();

  // Bypass the isSupported filter to see the raw documents.
  final rawAttractionsSnapshot = await FirestoreService().getCollection(
    collection: 'attractions',
  );

  // ignore: avoid_print
  print('raw_attractions_docs:${rawAttractionsSnapshot.docs.length}');

  for (final doc in rawAttractionsSnapshot.docs) {
    // ignore: avoid_print
    print('  - ${doc.id} | ${doc.data()}');
  }
  final rules = await etiquetteRepository.getAllEtiquetteRules();
  final settings = await environmentSettingsRepository.getSettings();
  final notifications =
  await notificationRepository.getHistoryForUser('guest');

  final rankingRepository = RankingReportRepository();
  final reports = await rankingRepository.getReportsByAttraction('batu_caves');
  final rankings =
  await rankingRepository.getRankingByAttraction('batu_caves');

  // ignore: avoid_print
  print('INSPECT_START');
  // ignore: avoid_print
  print('attractions:${attractions.length}');

  for (final attraction in attractions) {
    final geofence = attraction['geofence'];

    // ignore: avoid_print
    print(
      '  - ${attraction['id']} | ${attraction['name']} | '
          'category=${attraction['category']} | '
          'lat=${attraction['latitude']} lng=${attraction['longitude']} | '
          'geofence=$geofence | '
          'cooldownMinutes=${attraction['cooldownMinutes']} | '
          'isSupported=${attraction['isSupported']}',
    );
  }

  // ignore: avoid_print
  print('etiquette_rules:${rules.length}');

  for (final rule in rules) {
    // ignore: avoid_print
    print(
      '  - ${rule['id']} | attractionId=${rule['attractionId']} | '
          'type=${rule['type']} | title=${rule['title']}',
    );
  }

  // ignore: avoid_print
  print('environment_settings:$settings');

  // ignore: avoid_print
  print('notifications(guest):${notifications.length}');

  // ignore: avoid_print
  print('etiquette_reports(batu_caves):${reports.length}');

  for (final report in reports.take(5)) {
    // ignore: avoid_print
    print('  - $report');
  }

  // ignore: avoid_print
  print('etiquette_rankings(batu_caves):${rankings.length}');

  for (final ranking in rankings.take(5)) {
    // ignore: avoid_print
    print('  - $ranking');
  }

  // ignore: avoid_print
  print('INSPECT_END');

  exit(0);
}
