import 'package:flutter/material.dart';

import '../../../data_layer/model/services/firebase_authentication/firebase_authentication_service.dart';
import '../../../data_layer/model/services/geofence_alert_monitor/geofence_alert_monitor_service.dart';
import '../../view_model/notification_inbox/notification_inbox_view_model.dart';
import '../../view_model/settings/app_settings_controller.dart';
import '../etiquette_alert/etiquette_alert.dart';

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

  final AppSettingsController _settings =
      AppSettingsController.instance;

  static const Color _background = Color(0xFFFFFFFF);
  static const Color _navy = Color(0xFF14213D);
  static const Color _teal = Color(0xFF18B7C8);
  static const Color _blue = Color(0xFF1E78D8);
  static const Color _orange = Color(0xFFFFA800);
  static const Color _orangeSoft = Color(0xFFFFF0C9);
  static const Color _red = Color(0xFFFF4057);

  static const List<Map<String, String>> _testAttractions = [
    {'id': 'batu_caves', 'name': 'Batu Caves'},
    {
      'id': 'national_mosque',
      'name': 'National Mosque of Malaysia',
    },
    {'id': 'thean_hou_temple', 'name': 'Thean Hou Temple'},
    {
      'id': 'sultan_abdul_samad_building',
      'name': 'Sultan Abdul Samad Building',
    },
    {
      'id': 'st_marys_cathedral',
      'name': "St. Mary's Cathedral",
    },
  ];

  int _testAttractionIndex = 0;
  bool _isSendingTestAlert = false;

  bool _isSelectionMode = false;
  final Set<String> _selectedReadNotificationIds = {};

  @override
  void initState() {
    super.initState();

    _viewModel.addListener(_onViewModelChanged);
    _settings.addListener(_onSettingsChanged);

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

  void _onSettingsChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _settings.removeListener(_onSettingsChanged);
    _viewModel.dispose();
    super.dispose();
  }

  String _t({
    required String en,
    required String zh,
    required String ms,
  }) {
    return _settings.text(en: en, zh: zh, ms: ms);
  }

  Future<void> _openNotification(
    Map<String, dynamic> notification,
  ) async {
    final id = notification['id']?.toString();
    final attractionId =
        notification['attractionId']?.toString();

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

  void _startSelectionMode([String? initialId]) {
    setState(() {
      _isSelectionMode = true;

      if (initialId != null) {
        _selectedReadNotificationIds.add(initialId);
      }
    });
  }

  void _cancelSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedReadNotificationIds.clear();
    });
  }

  void _toggleReadNotificationSelection(String id) {
    setState(() {
      if (_selectedReadNotificationIds.contains(id)) {
        _selectedReadNotificationIds.remove(id);
      } else {
        _selectedReadNotificationIds.add(id);
      }
    });
  }

  Future<void> _deleteSelectedNotifications() async {
    if (_selectedReadNotificationIds.isEmpty ||
        _viewModel.isDeleting) {
      return;
    }

    final selectedCount =
        _selectedReadNotificationIds.length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          _t(
            en: 'Delete notifications?',
            zh: '删除通知？',
            ms: 'Padam pemberitahuan?',
          ),
        ),
        content: Text(
          selectedCount == 1
              ? _t(
                  en: 'Delete this read notification permanently?',
                  zh: '要永久删除这则已读通知吗？',
                  ms: 'Padam pemberitahuan yang telah dibaca ini secara kekal?',
                )
              : _t(
                  en: 'Delete these $selectedCount read notifications permanently?',
                  zh: '要永久删除这 $selectedCount 则已读通知吗？',
                  ms: 'Padam $selectedCount pemberitahuan yang telah dibaca ini secara kekal?',
                ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(false),
            child: Text(
              _t(
                en: 'Cancel',
                zh: '取消',
                ms: 'Batal',
              ),
            ),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: _red,
              foregroundColor: Colors.white,
            ),
            child: Text(
              _t(
                en: 'Delete',
                zh: '删除',
                ms: 'Padam',
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final idsToDelete =
        Set<String>.from(_selectedReadNotificationIds);

    try {
      final deletedCount = await _viewModel
          .deleteReadNotifications(idsToDelete);

      if (!mounted) return;

      _cancelSelectionMode();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            deletedCount == 1
                ? _t(
                    en: '1 notification deleted.',
                    zh: '已删除 1 则通知。',
                    ms: '1 pemberitahuan telah dipadam.',
                  )
                : _t(
                    en: '$deletedCount notifications deleted.',
                    zh: '已删除 $deletedCount 则通知。',
                    ms: '$deletedCount pemberitahuan telah dipadam.',
                  ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              en: 'Unable to delete notification${selectedCount == 1 ? '' : 's'}: $e',
              zh: '无法删除通知：$e',
              ms: 'Tidak dapat memadam pemberitahuan: $e',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _sendTestAlert() async {
    final userId = _authService.currentUser?.uid;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              en: 'Please sign in first.',
              zh: '请先登录。',
              ms: 'Sila log masuk dahulu.',
            ),
          ),
        ),
      );
      return;
    }

    final attraction = _testAttractions[
        _testAttractionIndex % _testAttractions.length];

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
            _t(
              en: 'Test alert sent for ${attraction['name']}. Check your device notifications.',
              zh: '已为 ${attraction['name']} 发送测试提醒。请查看设备通知。',
              ms: 'Amaran ujian untuk ${attraction['name']} telah dihantar. Semak pemberitahuan peranti anda.',
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              en: 'Unable to send test alert: $e',
              zh: '无法发送测试提醒：$e',
              ms: 'Tidak dapat menghantar amaran ujian: $e',
            ),
          ),
        ),
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
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton.extended(
              backgroundColor: _orange,
              onPressed:
                  _isSendingTestAlert ? null : _sendTestAlert,
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
              label: Text(
                _t(
                  en: 'Test Alert',
                  zh: '测试提醒',
                  ms: 'Amaran Ujian',
                ),
                style: const TextStyle(color: Colors.white),
              ),
            ),
      bottomNavigationBar:
          _isSelectionMode ? _buildSelectionBar() : null,
    );
  }

  Widget _buildHeader() {
    final unreadCount =
        _viewModel.unreadNotifications.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 6, 12, 22),
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
            onPressed: _isSelectionMode
                ? _cancelSelectionMode
                : () => Navigator.of(context).pop(),
            icon: Icon(
              _isSelectionMode
                  ? Icons.close_rounded
                  : Icons.arrow_back,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              _isSelectionMode
                  ? _t(
                      en:
                          '${_selectedReadNotificationIds.length} selected',
                      zh:
                          '已选择 ${_selectedReadNotificationIds.length} 项',
                      ms:
                          '${_selectedReadNotificationIds.length} dipilih',
                    )
                  : _t(
                      en: 'Notifications',
                      zh: '通知',
                      ms: 'Pemberitahuan',
                    ),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (_isSelectionMode)
            IconButton(
              tooltip: _t(
                en: 'Delete selected',
                zh: '删除所选项目',
                ms: 'Padam yang dipilih',
              ),
              onPressed:
                  _selectedReadNotificationIds.isEmpty ||
                          _viewModel.isDeleting
                      ? null
                      : _deleteSelectedNotifications,
              icon: _viewModel.isDeleting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.white,
                    ),
            )
          else if (unreadCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color:
                    Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                unreadCount > 9
                    ? _t(
                        en: '9+ new',
                        zh: '9+ 新通知',
                        ms: '9+ baharu',
                      )
                    : _t(
                        en: '$unreadCount new',
                        zh: '$unreadCount 则新通知',
                        ms: '$unreadCount baharu',
                      ),
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

  Widget _buildBody() {
    if (_authService.currentUser == null) {
      return _buildEmptyState(
        icon: Icons.lock_outline,
        message: _t(
          en: 'Please sign in to view notifications.',
          zh: '请登录以查看通知。',
          ms: 'Sila log masuk untuk melihat pemberitahuan.',
        ),
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
                style: TextStyle(
                  color: Colors.grey.shade700,
                ),
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
                child: Text(
                  _t(
                    en: 'Retry',
                    zh: '重试',
                    ms: 'Cuba Lagi',
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final unread = _viewModel.unreadNotifications;
    final read = _viewModel.readNotifications;

    if (unread.isEmpty && read.isEmpty) {
      if (_isSelectionMode) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _cancelSelectionMode();
          }
        });
      }

      return _buildEmptyState(
        icon: Icons.notifications_none_rounded,
        message: _t(
          en:
              'No notifications yet.\nEtiquette reminders will appear here as you explore cultural attractions.',
          zh:
              '目前还没有通知。\n当您探索文化景点时，礼仪提醒会显示在这里。',
          ms:
              'Belum ada pemberitahuan.\nPeringatan etika akan muncul di sini semasa anda meneroka tarikan budaya.',
        ),
      );
    }

    return RefreshIndicator(
      color: _teal,
      onRefresh:
          _isSelectionMode ? () async {} : _viewModel.refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
        children: [
          if (unread.isNotEmpty) ...[
            _buildSectionTitle(
              _t(
                en: 'Unread',
                zh: '未读',
                ms: 'Belum Dibaca',
              ),
              count: unread.length,
            ),
            const SizedBox(height: 10),
            for (final n in unread) ...[
              _buildNotificationCard(
                n,
                isUnread: true,
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 10),
          ],
          if (read.isNotEmpty) ...[
            _buildSectionTitle(
              _t(
                en: 'Read',
                zh: '已读',
                ms: 'Telah Dibaca',
              ),
              count: read.length,
              showSelectAction: true,
            ),
            if (_isSelectionMode) ...[
              const SizedBox(height: 4),
              Text(
                _t(
                  en:
                      'Choose the read notifications you want to delete.',
                  zh: '选择您要删除的已读通知。',
                  ms:
                      'Pilih pemberitahuan yang telah dibaca untuk dipadam.',
                ),
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 10),
            for (final n in read) ...[
              _buildNotificationCard(
                n,
                isUnread: false,
              ),
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
              child: Icon(
                icon,
                color: _orange,
                size: 34,
              ),
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

  Widget _buildSectionTitle(
    String title, {
    required int count,
    bool showSelectAction = false,
  }) {
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
        if (showSelectAction && !_isSelectionMode) ...[
          const Spacer(),
          TextButton.icon(
            onPressed: _startSelectionMode,
            icon: const Icon(
              Icons.checklist_rounded,
              size: 18,
            ),
            label: Text(
              _t(
                en: 'Select',
                zh: '选择',
                ms: 'Pilih',
              ),
            ),
            style: TextButton.styleFrom(
              foregroundColor: _blue,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNotificationCard(
    Map<String, dynamic> notification, {
    required bool isUnread,
  }) {
    final id =
        notification['id']?.toString() ?? '';

    final attractionName =
        notification['attractionName']?.toString().trim();

    final displayAttractionName =
        attractionName == null || attractionName.isEmpty
            ? _t(
                en: 'Attraction',
                zh: '景点',
                ms: 'Tarikan',
              )
            : attractionName;

    // Do not display the stored English Firestore message directly.
    // Build the inbox message from the current app language so old
    // notifications also change immediately when the user changes language.
    final localizedMessage = _t(
      en:
          'You are near $displayAttractionName. Tap to view etiquette guidance.',
      zh:
          '您已到达 $displayAttractionName 附近。点击查看礼仪指南。',
      ms:
          'Anda berada berhampiran $displayAttractionName. Tekan untuk melihat panduan etika.',
    );

    final sentAt = DateTime.tryParse(
      notification['sentAt']?.toString() ?? '',
    );

    final canSelect =
        !isUnread && _isSelectionMode && id.isNotEmpty;
    final isSelected =
        _selectedReadNotificationIds.contains(id);

    return InkWell(
      onTap: canSelect
          ? () => _toggleReadNotificationSelection(id)
          : () => _openNotification(notification),
      onLongPress: !isUnread &&
              !_isSelectionMode &&
              id.isNotEmpty
          ? () => _startSelectionMode(id)
          : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFEAF4FF)
              : isUnread
                  ? _orangeSoft.withValues(alpha: 0.6)
                  : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            width: isSelected ? 1.5 : 1,
            color: isSelected
                ? _blue
                : isUnread
                    ? _orange.withValues(alpha: 0.4)
                    : Colors.grey.shade300,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (canSelect) ...[
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Checkbox(
                  value: isSelected,
                  activeColor: _blue,
                  onChanged: (_) =>
                      _toggleReadNotificationSelection(id),
                ),
              ),
              const SizedBox(width: 4),
            ] else ...[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isUnread
                      ? _orangeSoft
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.notifications_rounded,
                  color: isUnread
                      ? _orange
                      : Colors.grey.shade400,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_t(
                            en: 'Etiquette Reminder',
                            zh: '礼仪提醒',
                            ms: 'Peringatan Etika',
                          )}: $displayAttractionName',
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
                          margin: const EdgeInsets.only(
                            left: 8,
                            top: 3,
                          ),
                          decoration: const BoxDecoration(
                            color: _red,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    localizedMessage,
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

  Widget _buildSelectionBar() {
    final selectedCount =
        _selectedReadNotificationIds.length;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(
              color: Colors.grey.shade200,
            ),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 12,
              offset: Offset(0, -3),
            ),
          ],
        ),
        child: FilledButton.icon(
          onPressed: selectedCount == 0 ||
                  _viewModel.isDeleting
              ? null
              : _deleteSelectedNotifications,
          icon: _viewModel.isDeleting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.delete_outline_rounded),
          label: Text(
            selectedCount == 0
                ? _t(
                    en: 'Select read notifications',
                    zh: '选择已读通知',
                    ms: 'Pilih pemberitahuan yang telah dibaca',
                  )
                : _t(
                    en: 'Delete $selectedCount selected',
                    zh: '删除已选择的 $selectedCount 项',
                    ms: 'Padam $selectedCount yang dipilih',
                  ),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: _red,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
          ),
        ),
      ),
    );
  }

  String _formatRelativeTime(DateTime time) {
    final difference = DateTime.now().difference(time);

    if (difference.inMinutes < 1) {
      return _t(
        en: 'Just now',
        zh: '刚刚',
        ms: 'Baru sahaja',
      );
    }

    if (difference.inMinutes < 60) {
      return _t(
        en: '${difference.inMinutes} min ago',
        zh: '${difference.inMinutes} 分钟前',
        ms: '${difference.inMinutes} min lalu',
      );
    }

    if (difference.inHours < 24) {
      return _t(
        en: '${difference.inHours} hr ago',
        zh: '${difference.inHours} 小时前',
        ms: '${difference.inHours} jam lalu',
      );
    }

    return _t(
      en: '${difference.inDays} d ago',
      zh: '${difference.inDays} 天前',
      ms: '${difference.inDays} hari lalu',
    );
  }
}
