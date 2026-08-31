import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data_layer/model/repositories/notification/notification_repository.dart';
import '../../view_model/etiquette_alert/etiquette_alert_view_model.dart';
import '../shared/app_theme.dart';
import '../shared/etiquette_guidance_card.dart';

/// Full etiquette guidance for a notification the Tourist tapped from
/// the inbox or alert history (UC02 A2 - Tourist Opens Notification).
/// Shows the complete Do's/Don'ts for that attraction, not just the
/// short summary shown in the notification/list row.
class NotificationDetailView extends StatelessWidget {
  const NotificationDetailView({super.key, required this.notification});

  final Map<String, dynamic> notification;

  @override
  Widget build(BuildContext context) {
    final attractionId = notification['attractionId']?.toString() ?? '';

    if (notification['isRead'] != true) {
      NotificationRepository().markAsRead(notification['id'].toString());
    }

    return ChangeNotifierProvider(
      create: (_) => EtiquetteAlertViewModel()..loadEtiquetteRules(attractionId),
      child: _NotificationDetailContent(notification: notification),
    );
  }
}

class _NotificationDetailContent extends StatelessWidget {
  const _NotificationDetailContent({required this.notification});

  final Map<String, dynamic> notification;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<EtiquetteAlertViewModel>();

    final attractionName =
        notification['attractionName']?.toString() ?? '';
    final sentAt = notification['sentAt']?.toString().split('T').first ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: viewModel.isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Row(
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
                  child: Text('Etiquette Guide', style: AppText.screenTitle),
                ),
              ],
            ),
            if (sentAt.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text('Alerted on $sentAt', style: AppText.caption),
              ),

            if (viewModel.errorMessage != null)
              AppCard(
                color: AppColors.dangerBackground,
                margin: const EdgeInsets.only(bottom: 16),
                child: Text(
                  viewModel.errorMessage!,
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),

            EtiquetteGuidanceCard(
              attractionName: attractionName,
              dos: viewModel.getDos(),
              donts: viewModel.getDonts(),
            ),
          ],
        ),
      ),
    );
  }
}
