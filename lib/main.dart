import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'data_layer/model/services/notification/notification_service.dart';
import 'external_data_sources/firebase/firebase_data_source.dart';
import 'ui_layer/view/etiquette_alert/etiquette_alert.dart';
import 'ui_layer/view/home/admin_home_page.dart';
import 'ui_layer/view/home/home.dart';
import 'ui_layer/view/home/login_page.dart';
import 'data_layer/model/services/firebase_authentication/firebase_authentication_service.dart';
import 'data_layer/model/services/firebase_authentication/user_role_service.dart';
import 'data_layer/model/services/geofence_alert_monitor/geofence_alert_monitor_service.dart';
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
          home: const _AuthGate(),
        );
      },
    );
  }
}


/// Decides which page to show when the app starts.
///
/// Firebase Authentication keeps the signed-in session on the device, so
/// when the app is opened again we can restore the existing account instead
/// of asking the user to log in again.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final authService = FirebaseAuthenticationService();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _AuthLoadingPage();
        }

        final user = snapshot.data;

        if (user == null) {
          return const LoginPage();
        }

        return _LoggedInRoute(user: user);
      },
    );
  }
}

class _LoggedInRoute extends StatefulWidget {
  final User user;

  const _LoggedInRoute({required this.user});

  @override
  State<_LoggedInRoute> createState() => _LoggedInRouteState();
}

class _LoggedInRouteState extends State<_LoggedInRoute> {
  final UserRoleService _roleService = UserRoleService();
  final FirebaseAuthenticationService _authService =
  FirebaseAuthenticationService();

  late Future<String?> _roleFuture;

  @override
  void initState() {
    super.initState();
    _roleFuture = _roleService.getUserRole(widget.user.uid);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _roleFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _AuthLoadingPage();
        }

        final role = snapshot.data;

        if (role == 'admin') {
          return const AdminHomePage();
        }

        if (role == 'user') {
          // Keep the same background geofence behaviour as normal login.
          GeofenceAlertMonitorService.instance.start(
            userId: widget.user.uid,
          );
          return const HomeView();
        }

        // If the saved Firebase session belongs to an account that no
        // longer has a valid application role, clear it and return to login.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _signOutInvalidSession();
        });
        return const LoginPage();
      },
    );
  }

  bool _signingOut = false;

  Future<void> _signOutInvalidSession() async {
    if (_signingOut) return;
    _signingOut = true;

    try {
      await _authService.logout();
    } catch (_) {
      // If sign-out fails, the login page is still shown and the user can
      // retry from there.
    }
  }
}

class _AuthLoadingPage extends StatelessWidget {
  const _AuthLoadingPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
