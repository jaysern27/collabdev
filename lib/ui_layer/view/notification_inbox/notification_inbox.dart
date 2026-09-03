import 'package:flutter/material.dart';

import '../../../data_layer/model/services/firebase_authentication/firebase_authentication_service.dart';
import '../../../data_layer/model/services/geofence_alert_monitor/geofence_alert_monitor_service.dart';
import '../../view_model/notification_inbox/notification_inbox_view_model.dart';
import '../etiquette_alert/etiquette_alert.dart';

// Notification inbox opened from the bell icon on the home page.
// Lists the etiquette alerts UC02 has recorded for the tourist,
// split into Unread / Read. Tapping one marks it read and opens
// the same Etiquette Alert screen a real notification tap would
// (UC02 A2 – Tourist Opens Notification).
//
// Visually matches the home page / Cultural Map design language
// (cream background, teal-to-blue gradient header, navy text,
// orange bell accent) rather than introducing a new palette.
class NotificationInboxView extends StatefulWidget {
  const NotificationInboxView({super.key});

  @override
  State<NotificationInboxView> createState() =>
      _NotificationInboxViewState();
}

class _NotificationInboxViewState
    extends State<NotificationInboxView> {
  final NotificationInboxViewModel _viewModel =
  NotificationInboxViewModel();

  final FirebaseAuthenticationService _authService =
  FirebaseAuthenticationService();

  static const Color _background = Color(0xFFFFFFFF);
  static const Color _navy = Color(0xFF14213D);
  static const Color _teal = Color(0xFF18B7C8);
  static const Color _blue = Color(0xFF1E78D8);
  static const Color _orange = Color(0xFFFFA800);
  static const Color _orangeSoft = Color(0xFFFFF0C9);
  static const Color _red = Color(0xFFFF4057);

  // TESTING ONLY: cycles through a few real, geofence-enabled
  // attractions so the UC02 etiquette alert notification can be
  // fired on demand instead of waiting for an actual GPS geofence
  // entry. Remove once real device testing covers this.
  static const List<Map<String, String>> _testAttractions = [
    {'id': 'batu_caves', 'name': 'Batu Caves'},
    {'id': 'national_mosque', 'name': 'National Mosque of Malaysia'},
    {'id': 'thean_hou_temple', 'name': 'Thean Hou Temple'},
    {'id': 'sultan_abdul_samad_building', 'name': 'Sultan Abdul Samad Building'},
    {'id': 'st_marys_cathedral', 'name': "St. Mary's Cathedral"},
  ];

  int _testAttractionIndex = 0;
  bool _isSendingTestAlert = false;

  @override
  void initState() {
    super.initState();

    _viewModel.addListener(_onViewModelChanged);

    final userId = _authService.currentUser?.uid;

    if (userId != null) {
      _viewModel.loadNotifications(userId);
    }
  }

  void _onViewModelChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _viewModel.dispose();

    super.dispose();
  }

  Future<void> _openNotification(
      Map<String, dynamic> notification,
      ) async {
    final id = notification['id']?.toString();
    final attractionId = notification['attractionId']?.toString();

    if (id != null) {
      await _viewModel.markAsRead(id);
    }

    if (attractionId == null || !mounted) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EtiquetteAlertView(
          attractionId: attractionId,
        ),
      ),
    );
  }

  // TESTING ONLY: manually fires an etiquette alert notification
  // without waiting for an actual GPS geofence entry.
  Future<void> _sendTestAlert() async {
    final userId = _authService.currentUser?.uid;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in first.')),
      );
      return;
    }

    final attraction =
    _testAttractions[_testAttractionIndex % _testAttractions.length];

    setState(() {
      _isSendingTestAlert = true;
      _testAttractionIndex++;
    });

    try {
      await GeofenceAlertMonitorService.instance.sendTestAlert(
        userId: userId,
        attractionId: attraction['id']!,
        attractionName: attraction['name']!,
      );

      await _viewModel.refresh();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Test alert sent for ${attraction['name']}. '
                'Check your device notifications.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to send test alert: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSendingTestAlert = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _orange,
        onPressed: _isSendingTestAlert ? null : _sendTestAlert,
        icon: _isSendingTestAlert
            ? const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        )
            : const Icon(
          Icons.notifications_active,
          color: Colors.white,
        ),
        label: const Text(
          'Test Alert',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  // =========================================================
  // HEADER
  // =========================================================

  Widget _buildHeader() {
    final unreadCount = _viewModel.unreadNotifications.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 6, 18, 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_teal, _blue],
        ),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(28),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.arrow_back,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Text(
              'Notifications',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (unreadCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                unreadCount > 9 ? '9+ new' : '$unreadCount new',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // =========================================================
  // BODY
  // =========================================================

  Widget _buildBody() {
    if (_authService.currentUser == null) {
      return _buildEmptyState(
        icon: Icons.lock_outline,
        message: 'Please sign in to view notifications.',
      );
    }

    if (_viewModel.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _teal),
      );
    }

    if (_viewModel.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _viewModel.errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: _viewModel.refresh,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final unread = _viewModel.unreadNotifications;
    final read = _viewModel.readNotifications;

    if (unread.isEmpty && read.isEmpty) {
      return _buildEmptyState(
        icon: Icons.notifications_none_rounded,
        message:
        'No notifications yet.\nEtiquette reminders will appear '
            'here as you explore cultural attractions.',
      );
    }

    return RefreshIndicator(
      color: _teal,
      onRefresh: _viewModel.refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
        children: [
          if (unread.isNotEmpty) ...[
            _buildSectionTitle('Unread', count: unread.length),
            const SizedBox(height: 10),
            for (final n in unread) ...[
              _buildNotificationCard(n, isUnread: true),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 10),
          ],
          if (read.isNotEmpty) ...[
            _buildSectionTitle('Read', count: read.length),
            const SizedBox(height: 10),
            for (final n in read) ...[
              _buildNotificationCard(n, isUnread: false),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: _orangeSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: _orange, size: 34),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, {required int count}) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: _navy,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================
  // NOTIFICATION CARD
  // =========================================================

  Widget _buildNotificationCard(
      Map<String, dynamic> notification, {
        required bool isUnread,
      }) {
    final attractionName =
        notification['attractionName']?.toString() ?? 'Attraction';

    final message = notification['message']?.toString() ?? '';

    final sentAt = DateTime.tryParse(
      notification['sentAt']?.toString() ?? '',
    );

    return InkWell(
      onTap: () => _openNotification(notification),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 0),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isUnread
              ? _orangeSoft.withValues(alpha: 0.6)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUnread
                ? _orange.withValues(alpha: 0.4)
                : Colors.grey.shade300,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isUnread ? _orangeSoft : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.notifications_rounded,
                color: isUnread ? _orange : Colors.grey.shade400,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Etiquette Reminder: $attractionName',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isUnread
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: _navy,
                          ),
                        ),
                      ),
                      if (isUnread)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 8, top: 3),
                          decoration: const BoxDecoration(
                            color: _red,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                  ),
                  if (sentAt != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 13,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatRelativeTime(sentAt),
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatRelativeTime(DateTime time) {
    final difference = DateTime.now().difference(time);

    if (difference.inMinutes < 1) {
      return 'Just now';
    }

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    }

    if (difference.inHours < 24) {
      return '${difference.inHours} hr ago';
    }

    return '${difference.inDays} d ago';
  }
}
