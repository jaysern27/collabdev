import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../view_model/notification_settings/notification_settings_view_model.dart';
import '../shared/app_theme.dart';

/// General etiquette-notification settings, reached from the
/// Notification Inbox's settings icon.
class NotificationSettingsView extends StatelessWidget {
  const NotificationSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => NotificationSettingsViewModel()..loadSettings(),
      child: const _NotificationSettingsContent(),
    );
  }
}

class _NotificationSettingsContent extends StatelessWidget {
  const _NotificationSettingsContent();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<NotificationSettingsViewModel>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: viewModel.isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 24),
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
                  child: Text(
                    'Notification Settings',
                    style: AppText.screenTitle,
                  ),
                ),
                if (viewModel.isSaving)
                  const Padding(
                    padding: EdgeInsets.only(right: 16),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'Choose how you\'d like to be reminded about cultural '
                    'etiquette when you enter a supported attraction.',
                style: AppText.caption,
              ),
            ),

            if (viewModel.errorMessage != null)
              AppCard(
                color: AppColors.dangerBackground,
                margin: const EdgeInsets.only(bottom: 12),
                child: Text(
                  viewModel.errorMessage!,
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),

            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _SettingRow(
                    icon: Icons.notifications_active_outlined,
                    iconColor: AppColors.warning,
                    iconBackground: AppColors.warningBackground,
                    title: 'Etiquette Alerts',
                    subtitle: 'Get notified when you enter a cultural, '
                        'religious, or heritage site.',
                    value: viewModel.notificationsEnabled,
                    onChanged: (value) =>
                        viewModel.setNotificationsEnabled(value),
                  ),
                  const Divider(height: 1, indent: 68),
                  _SettingRow(
                    icon: Icons.volume_up_outlined,
                    iconColor: AppColors.info,
                    iconBackground: AppColors.infoBackground,
                    title: 'Sound',
                    subtitle: 'Play a sound with each alert.',
                    value: viewModel.soundEnabled,
                    enabled: viewModel.notificationsEnabled,
                    onChanged: (value) => viewModel.setSoundEnabled(value),
                  ),
                  const Divider(height: 1, indent: 68),
                  _SettingRow(
                    icon: Icons.vibration,
                    iconColor: AppColors.success,
                    iconBackground: AppColors.successBackground,
                    title: 'Vibration',
                    subtitle: 'Vibrate the device with each alert.',
                    value: viewModel.vibrationEnabled,
                    enabled: viewModel.notificationsEnabled,
                    onChanged: (value) =>
                        viewModel.setVibrationEnabled(value),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            if (viewModel.defaultCooldownMinutes != null)
              AppCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'You\'ll only be re-alerted for the same place '
                            'after ${viewModel.defaultCooldownMinutes} '
                            'minutes, so alerts don\'t repeat while you '
                            'stay in one area. This cooldown is set by '
                            'the app admin.',
                        style: AppText.caption,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppText.body.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(subtitle, style: AppText.caption),
                ],
              ),
            ),
            Switch(
              value: value,
              activeThumbColor: AppColors.success,
              onChanged: enabled ? onChanged : null,
            ),
          ],
        ),
      ),
    );
  }
}
