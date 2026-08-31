import 'dart:io';

import 'package:flutter/widgets.dart';

import '../external_data_sources/firebase/firebase_data_source.dart';
import 'seed_data.dart';

/// One-off entry point to actually create UC02/UC03's Firestore
/// collections on a real device/emulator, without needing to tap through
/// the Admin UI. Run with `flutter run -d [device] -t lib/dev/seed_main.dart`.
/// Prints `SEED_RESULT::[message]` and exits.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await FirebaseDataSource.instance.initialize();

  String result;

  try {
    result = await seedSampleData();
  } catch (e) {
    result = 'ERROR: $e';
  }

  // ignore: avoid_print
  print('SEED_RESULT::$result');

  exit(result.startsWith('ERROR') ? 1 : 0);
}
