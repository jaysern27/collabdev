import '../../../../external_data_sources/device_notifications/device_notifications_data_source.dart';

class NotificationService {
  final DeviceNotificationsDataSource _dataSource;

  NotificationService({
    DeviceNotificationsDataSource? dataSource,
  }) : _dataSource =
      dataSource ?? DeviceNotificationsDataSource();

  Future<void> initialize({
    void Function(String? payload)? onNotificationTap,
  }) async {
    await _dataSource.initialize(
      onNotificationTap: onNotificationTap,
    );
    await _dataSource.requestPermission();
  }

  Future<void> showEtiquetteAlert({
    required int id,
    required String attractionName,
    required String message,
    String? payload,
  }) async {
    await _dataSource.showNotification(
      id: id,
      title: 'Etiquette Reminder: $attractionName',
      body: message,
      payload: payload ?? attractionName,
    );
  }

  Future<void> cancelAlert(int id) async {
    await _dataSource.cancelNotification(id);
  }

  Future<void> cancelAllAlerts() async {
    await _dataSource.cancelAllNotifications();
  }
}