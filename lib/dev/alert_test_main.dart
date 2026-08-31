import 'package:flutter/material.dart';

import '../data_layer/model/services/notification/notification_service.dart';
import '../external_data_sources/firebase/firebase_data_source.dart';
import '../ui_layer/view/etiquette_alert/etiquette_alert.dart';

/// Dev-only shortcut: opens straight into the Etiquette Alert screen
/// (UC02) so geofence monitoring starts immediately, without needing to
/// tap through Home first. Useful for testing with a spoofed GPS
/// location (emulator Extended Controls, or `adb emu geo fix`).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await FirebaseDataSource.instance.initialize();

  final notificationService = NotificationService();
  await notificationService.initialize();

  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: EtiquetteAlertView(),
    ),
  );
}
