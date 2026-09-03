import 'package:flutter/material.dart';

import 'external_data_sources/firebase/firebase_data_source.dart';
import 'data_layer/model/services/notification/notification_service.dart';
import 'ui_layer/view/etiquette_alert/etiquette_alert.dart';
import 'ui_layer/view/home/login_page.dart';
import 'ui_layer/view/shared/app_theme.dart';

// Notification taps have no BuildContext of their own (UC02 A2 –
// Tourist Opens Notification), so navigation to the etiquette
// alert screen goes through this global key instead.
final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await FirebaseDataSource.instance.initialize();

  final notificationService = NotificationService();
  await notificationService.initialize(
    onNotificationTap: _openEtiquetteAlert,
  );

  runApp(const CultureGuideApp());
}

void _openEtiquetteAlert(String? attractionId) {
  if (attractionId == null || attractionId.isEmpty) {
    return;
  }

  navigatorKey.currentState?.push(
    MaterialPageRoute(
      builder: (_) => EtiquetteAlertView(
        attractionId: attractionId,
      ),
    ),
  );
}

class CultureGuideApp extends StatelessWidget {
  const CultureGuideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'CultureGuide',
      // Without an explicit theme, Flutter's Material 3 default
      // seed colour is Colors.deepPurple — which is why widgets
      // using default Material styling (buttons, switches, form
      // fields) showed up purple even where no screen coded that
      // on purpose. Seeding from the app's actual brand blue fixes
      // every one of those at once.
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          surface: AppColors.surface,
        ),
      ),
      home: const LoginPage(),
    );
  }
}