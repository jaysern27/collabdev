import 'dart:io';

import 'package:flutter/widgets.dart';

import '../data_layer/model/repositories/notification/notification_repository.dart';
import '../external_data_sources/firebase/firebase_data_source.dart';

/// Dev-only: deletes the 'guest' user's existing notification for one
/// attraction so UC02's cooldown gate doesn't block a fresh live test.
/// Edit the `attractionId` constant below to target a different place.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await FirebaseDataSource.instance.initialize();

  const attractionId = 'batu_caves';
  const userId = 'guest';

  final notificationRepository = NotificationRepository();

  final history = await notificationRepository.getHistoryForUser(userId);

  var deletedCount = 0;

  for (final notification in history) {
    if (notification['attractionId'] == attractionId) {
      await notificationRepository.deleteNotification(
        notification['id'].toString(),
      );

      deletedCount++;
    }
  }

  // ignore: avoid_print
  print('RESET_RESULT::Deleted $deletedCount notification(s) for '
      '$attractionId, cooldown cleared.');

  exit(0);
}
