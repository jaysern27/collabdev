import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class DeviceNotificationsDataSource {
  final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    const androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosSettings = DarwinInitializationSettings();

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings: settings,
    );
  }

  Future<bool> requestPermission() async {
    final androidPlugin =
    _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    final androidGranted =
    await androidPlugin?.requestNotificationsPermission();

    final iosPlugin =
    _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();

    final iosGranted = await iosPlugin?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    return androidGranted ?? iosGranted ?? true;
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    bool playSound = true,
    bool enableVibration = true,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'etiquette_alerts',
      'Etiquette Alerts',
      channelDescription:
      'GPS-based cultural etiquette alerts',
      importance: Importance.high,
      priority: Priority.high,
      playSound: playSound,
      enableVibration: enableVibration,
    );

    final iosDetails = DarwinNotificationDetails(
      presentSound: playSound,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id: id);
  }

  Future<void> cancelAllNotifications() async {
    await _plugin.cancelAll();
  }
}