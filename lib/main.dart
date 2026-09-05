import 'package:flutter/material.dart';

import 'data_layer/model/services/notification/notification_service.dart';
import 'external_data_sources/firebase/firebase_data_source.dart';
import 'ui_layer/view/etiquette_alert/etiquette_alert.dart';
import 'ui_layer/view/home/login_page.dart';
import 'ui_layer/view/shared/app_theme.dart';
import 'ui_layer/view_model/settings/app_settings_controller.dart';


final navigatorKey =
GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await FirebaseDataSource.instance.initialize();
  await AppSettingsController.instance.load();



  final notificationService =
  NotificationService();

  await notificationService.initialize(
    onNotificationTap:
    _openEtiquetteAlert,
  );

  runApp(
    const CultureGuideApp(),
  );
}

void _openEtiquetteAlert(
    String? attractionId,
    ) {
  if (attractionId == null ||
      attractionId.isEmpty) {
    return;
  }

  navigatorKey.currentState?.push(
    MaterialPageRoute(
      builder: (_) =>
          EtiquetteAlertView(
            attractionId:
            attractionId,
          ),
    ),
  );
}

class CultureGuideApp
    extends StatelessWidget {
  const CultureGuideApp({
    super.key,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    final settings =
        AppSettingsController.instance;

    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        final lightScheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          brightness: Brightness.light,
        );

        final darkScheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.dark,
          surface: const Color(0xFF111827),
        );

        return MaterialApp(
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          title: 'CultureGuide',
          themeMode: settings.darkMode
              ? ThemeMode.dark
              : ThemeMode.light,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            colorScheme: lightScheme,
            scaffoldBackgroundColor:
            const Color(0xFFFCF9FF),
            appBarTheme: const AppBarTheme(
              centerTitle: false,
              elevation: 0,
              backgroundColor:
              Color(0xFFFCF9FF),
              surfaceTintColor:
              Colors.transparent,
            ),
            cardTheme: CardThemeData(
              color: lightScheme.surface,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: darkScheme,
            scaffoldBackgroundColor:
            const Color(0xFF0B1120),
            appBarTheme: const AppBarTheme(
              centerTitle: false,
              elevation: 0,
              backgroundColor:
              Color(0xFF0B1120),
              surfaceTintColor:
              Colors.transparent,
            ),
            cardTheme: CardThemeData(
              color: darkScheme.surface,
            ),
            inputDecorationTheme:
            InputDecorationTheme(
              filled: true,
              fillColor:
              darkScheme.surfaceContainerHighest,
            ),
          ),
          home: const LoginPage(),
        );
      },
    );
  }
}
