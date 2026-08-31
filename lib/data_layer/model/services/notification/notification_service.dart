import '../../../../external_data_sources/device_notifications/device_notifications_data_source.dart';

class NotificationService {
  final DeviceNotificationsDataSource _dataSource;

  NotificationService({
    DeviceNotificationsDataSource? dataSource,
  }) : _dataSource =
      dataSource ?? DeviceNotificationsDataSource();

  Future<void> initialize() async {
    await _dataSource.initialize();
    await _dataSource.requestPermission();
  }

  Future<void> showEtiquetteAlert({
    required int id,
    required String attractionName,
    required String message,
    bool playSound = true,
    bool enableVibration = true,
  }) async {
    await _dataSource.showNotification(
      id: id,
      title: 'Etiquette Reminder: $attractionName',
      body: message,
      payload: attractionName,
      playSound: playSound,
      enableVibration: enableVibration,
    );
  }

  Future<void> cancelAlert(int id) async {
    await _dataSource.cancelNotification(id);
  }

  Future<void> cancelAllAlerts() async {
    await _dataSource.cancelAllNotifications();
  }
}