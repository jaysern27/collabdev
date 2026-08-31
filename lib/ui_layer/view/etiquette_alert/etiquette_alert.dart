import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../view_model/etiquette_alert/etiquette_alert_view_model.dart';
import '../notification_detail/notification_detail.dart';
import '../shared/app_theme.dart';
import '../shared/etiquette_guidance_card.dart';

/// UC02_Receive Etiquette Alert.
class EtiquetteAlertView extends StatelessWidget {
  const EtiquetteAlertView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => EtiquetteAlertViewModel()
        ..startMonitoring()
        ..loadAlertHistory(),
      child: const _EtiquetteAlertContent(),
    );
  }
}

class _EtiquetteAlertContent extends StatelessWidget {
  const _EtiquetteAlertContent();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<EtiquetteAlertViewModel>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: viewModel.isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _buildHeader(context, viewModel),
            const SizedBox(height: 16),

            if (viewModel.errorMessage != null)
              AppCard(
                color: AppColors.dangerBackground,
                margin: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.danger,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        viewModel.errorMessage!,
                        style: const TextStyle(color: AppColors.danger),
                      ),
                    ),
                  ],
                ),
              ),

            if (viewModel.hasActiveAlert)
              _buildActiveAlertCard(context, viewModel)
            else
              const AppEmptyState(
                icon: Icons.travel_explore,
                message: 'No active etiquette alert.\n'
                    'Walk into a supported cultural attraction to '
                    'receive one.',
              ),

            const SizedBox(height: 24),

            const Text('Alert History', style: AppText.sectionTitle),
            const SizedBox(height: 10),

            if (viewModel.alertHistory.isEmpty)
              const AppEmptyState(
                icon: Icons.history,
                message: 'No alerts recorded yet.',
              )
            else
              ...viewModel.alertHistory.map(
                    (alert) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _HistoryTile(alert: alert),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
      BuildContext context,
      EtiquetteAlertViewModel viewModel,
      ) {
    return Row(
      children: [
        const Expanded(
          child: Text('Etiquette Alerts', style: AppText.screenTitle),
        ),
        AppPill(
          label: viewModel.isMonitoring ? 'Monitoring' : 'Paused',
          background: viewModel.isMonitoring
              ? AppColors.successBackground
              : AppColors.dangerBackground,
          foreground:
          viewModel.isMonitoring ? AppColors.success : AppColors.danger,
          icon: viewModel.isMonitoring ? Icons.gps_fixed : Icons.gps_off,
        ),
      ],
    );
  }

  Widget _buildActiveAlertCard(
      BuildContext context,
      EtiquetteAlertViewModel viewModel,
      ) {
    return EtiquetteGuidanceCard(
      attractionName: viewModel.activeAttractionName ?? '',
      dos: viewModel.getDos(),
      donts: viewModel.getDonts(),
      actions: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => viewModel.markActiveAlertRead(),
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Mark as Read'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white70),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => viewModel.dismissActiveAlert(),
              icon: const Icon(Icons.close, size: 16),
              label: const Text('Dismiss'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.heroGradientEnd,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.alert});

  final Map<String, dynamic> alert;

  @override
  Widget build(BuildContext context) {
    final isRead = alert['isRead'] == true;
    final sentAt = alert['sentAt']?.toString().split('T').first ?? '';

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => NotificationDetailView(notification: alert),
          ),
        );
      },
      child: AppCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              isRead
                  ? Icons.mark_email_read_outlined
                  : Icons.mark_email_unread_outlined,
              size: 18,
              color: isRead ? AppColors.textSecondary : AppColors.warning,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alert['attractionName']?.toString() ?? '',
                    style: AppText.body.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    alert['message']?.toString() ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption,
                  ),
                ],
              ),
            ),
            Text(sentAt, style: AppText.caption),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
