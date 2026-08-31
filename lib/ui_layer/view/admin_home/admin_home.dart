import 'package:flutter/material.dart';

import '../environment_parameter/environment_parameter.dart';
import '../shared/app_theme.dart';

/// Admin landing page. UC03 (Environment Settings) is one sub-function
/// here rather than the whole Admin experience -- other admin use cases
/// (UC05 Manage/Evaluate Report, Module 4's violation dashboard) belong
/// to other members' modules and are listed as "Coming soon" until their
/// owners wire them in.
class AdminHomeView extends StatelessWidget {
  const AdminHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
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
                  child: Text('Admin Panel', style: AppText.screenTitle),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'Configure the environment that supports the cultural '
                    'map and etiquette alert system.',
                style: AppText.caption,
              ),
            ),

            _AdminFunctionTile(
              icon: Icons.tune,
              iconBackground: AppColors.infoBackground,
              iconColor: AppColors.info,
              title: 'Environment Settings',
              subtitle: 'Manage attractions, geofences & alert '
                  'cooldown (UC03)',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const EnvironmentParameterView(),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),

            const _AdminFunctionTile(
              icon: Icons.fact_check_outlined,
              iconBackground: AppColors.warningBackground,
              iconColor: AppColors.warning,
              title: 'Report Moderation',
              subtitle: 'Approve or reject Tourist reports (UC05) -- '
                  'coming soon',
              enabled: false,
            ),
            const SizedBox(height: 10),

            const _AdminFunctionTile(
              icon: Icons.bar_chart_outlined,
              iconBackground: AppColors.successBackground,
              iconColor: AppColors.success,
              title: 'Violation Analytics',
              subtitle: 'Top violations & report trends (Module 4) -- '
                  'coming soon',
              enabled: false,
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminFunctionTile extends StatelessWidget {
  const _AdminFunctionTile({
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.enabled = true,
    this.onTap,
  });

  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: enabled ? onTap : null,
        child: AppCard(
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.sectionTitle),
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppText.caption),
                  ],
                ),
              ),
              if (enabled)
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.textSecondary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
