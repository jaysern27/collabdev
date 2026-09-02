import 'package:flutter/material.dart';

import 'external_data_sources/firebase/firebase_data_source.dart';
import 'data_layer/model/services/notification/notification_service.dart';
import 'ui_layer/view/home/home.dart';
import 'ui_layer/view/home/login_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await FirebaseDataSource.instance.initialize();

  final notificationService = NotificationService();
  await notificationService.initialize();

  runApp(const CultureGuideApp());
}

class CultureGuideApp extends StatelessWidget {
  const CultureGuideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CultureGuide',
      home: const LoginPage(),
    );
  }
}