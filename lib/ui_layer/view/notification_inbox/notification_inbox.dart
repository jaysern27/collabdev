import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../view_model/notification_inbox/notification_inbox_view_model.dart';
import '../notification_detail/notification_detail.dart';
import '../notification_settings/notification_settings.dart';
import '../shared/app_theme.dart';

/// Notification inbox opened from the bell icon on Home. Lists every
/// etiquette alert recorded for the Tourist (UC02) and lets them filter
/// by All / Unread / Read, mark items read, or dismiss them.
class NotificationInboxView extends StatelessWidget {
  const NotificationInboxView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => NotificationInboxViewModel()..startWatching(),
      child: const _NotificationInboxContent(),
    );
  }
}

class _NotificationInboxContent extends StatelessWidget {
  const _NotificationInboxContent();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<NotificationInboxViewModel>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, viewModel),
            _buildFilterBar(context, viewModel),
            const SizedBox(height: 4),
            Expanded(
              child: viewModel.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : viewModel.errorMessage != null
                  ? AppEmptyState(
                icon: Icons.error_outline,
                message: viewModel.errorMessage!,
                color: AppColors.danger,
              )
                  : _buildList(context, viewModel),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
      BuildContext context,
      NotificationInboxViewModel viewModel,
      ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 16, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(
              Icons.arrow_back_ios_new,
              size: 18,
              color: AppColors.textPrimary,
            ),
          ),
          const Expanded(
            child: Text('Notifications', style: AppText.screenTitle),
          ),
          TextButton.icon(
            onPressed: viewModel.unreadCount == 0
                ? null
                : () => viewModel.markAllAsRead(),
            icon: const Icon(Icons.done_all, size: 16),
            label: const Text('Mark all read'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accentTeal,
              disabledForegroundColor: AppColors.textSecondary
                  .withValues(alpha: 0.4),
            ),
          ),
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const NotificationSettingsView(),
                ),
              );
            },
            icon: const Icon(
              Icons.settings_outlined,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(
      BuildContext context,
      NotificationInboxViewModel viewModel,
      ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          AppPill(
            label: 'All (${viewModel.unreadCount + viewModel.readCount})',
            background: AppColors.infoBackground,
            foreground: AppColors.info,
            icon: Icons.all_inbox_outlined,
            selected: viewModel.filter == NotificationFilter.all,
            onTap: () => context
                .read<NotificationInboxViewModel>()
                .setFilter(NotificationFilter.all),
          ),
          const SizedBox(width: 8),
          AppPill(
            label: 'Unread (${viewModel.unreadCount})',
            background: AppColors.warningBackground,
            foreground: AppColors.warning,
            icon: Icons.mark_email_unread_outlined,
            selected: viewModel.filter == NotificationFilter.unread,
            onTap: () => context
                .read<NotificationInboxViewModel>()
                .setFilter(NotificationFilter.unread),
          ),
          const SizedBox(width: 8),
          AppPill(
            label: 'Read (${viewModel.readCount})',
            background: AppColors.successBackground,
            foreground: AppColors.success,
            icon: Icons.mark_email_read_outlined,
            selected: viewModel.filter == NotificationFilter.read,
            onTap: () => context
                .read<NotificationInboxViewModel>()
                .setFilter(NotificationFilter.read),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
      BuildContext context,
      NotificationInboxViewModel viewModel,
      ) {
    final notifications = viewModel.notifications;

    if (notifications.isEmpty) {
      return const AppEmptyState(
        icon: Icons.notifications_off_outlined,
        message: 'No notifications here yet.\n'
            'Walk into a supported cultural attraction to receive one.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      itemCount: notifications.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final notification = notifications[index];
        final isRead = notification['isRead'] == true;
        final id = notification['id'].toString();

        return Dismissible(
          key: ValueKey(id),
          direction: DismissDirection.endToStart,
          background: Container(
            decoration: BoxDecoration(
              color: AppColors.dangerBackground,
              borderRadius: BorderRadius.circular(18),
            ),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Icon(
              Icons.delete_outline,
              color: AppColors.danger,
            ),
          ),
          onDismissed: (_) {
            context.read<NotificationInboxViewModel>().dismiss(id);
          },
          child: _NotificationTile(
            notification: notification,
            isRead: isRead,
            onTap: () {
              if (!isRead) {
                context.read<NotificationInboxViewModel>().markAsRead(id);
              }

              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      NotificationDetailView(notification: notification),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.isRead,
    required this.onTap,
  });

  final Map<String, dynamic> notification;
  final bool isRead;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sentAt = notification['sentAt']?.toString().split('T').first ?? '';

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AppCard(
        color: isRead ? AppColors.surface : AppColors.warningBackground
            .withValues(alpha: 0.5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isRead
                    ? AppColors.border.withValues(alpha: 0.6)
                    : AppColors.warningBackground,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.notifications,
                size: 18,
                color: isRead ? AppColors.textSecondary : AppColors.warning,
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
                          notification['attractionName']?.toString() ?? '',
                          style: AppText.sectionTitle.copyWith(
                            fontWeight:
                            isRead ? FontWeight.w600 : FontWeight.w800,
                          ),
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 6, top: 4),
                          decoration: const BoxDecoration(
                            color: AppColors.danger,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification['message']?.toString() ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(sentAt, style: AppText.caption),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
