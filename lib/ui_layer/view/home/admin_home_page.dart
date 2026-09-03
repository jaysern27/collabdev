import 'package:flutter/material.dart';

import '../../../data_layer/model/repositories/ranking_report/ranking_report_repository.dart';
import '../../../data_layer/model/services/firebase_authentication/firebase_authentication_service.dart';
import '../environment_parameter/environment_parameter.dart';
import '../shared/app_theme.dart';
import '../violation_dashboard_report/violation_dashboard_report.dart';
import 'admin_report_management_page.dart';
import 'login_page.dart';

// Admin's landing page. Fans out to one page per module (UC03/UC05
// plus the Module 4 ranking dashboard) instead of cramming
// everything into a single screen.
class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  final RankingReportRepository _rankingReportRepository =
  RankingReportRepository();
  final FirebaseAuthenticationService _authService =
  FirebaseAuthenticationService();

  int? _pendingReportCount;

  @override
  void initState() {
    super.initState();
    _refreshPendingCount();
  }

  Future<void> _refreshPendingCount() async {
    try {
      final pending = await _rankingReportRepository.getPendingReports();

      if (!mounted) return;

      setState(() {
        _pendingReportCount = pending.length;
      });
    } catch (_) {
      // Leave the badge hidden if the count can't be fetched.
    }
  }

  Future<void> _openModule(Widget page) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );

    _refreshPendingCount();
  }

  Future<void> _logout() async {
    await _authService.logout();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = _authService.currentUser?.email ?? 'Administrator';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.heading,
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: _logout,
            tooltip: 'Log out',
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _refreshPendingCount,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              _buildHero(email),
              const SizedBox(height: 26),
              const Text(
                'Modules',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.heading,
                ),
              ),
              const SizedBox(height: 12),
              _ModuleCard(
                icon: Icons.fact_check_rounded,
                iconBackground: AppColors.tintLight,
                iconColor: AppColors.primary,
                title: 'Report Management',
                subtitle:
                'Review submitted etiquette reports and approve '
                    'or reject them',
                badgeCount: _pendingReportCount,
                onTap: () => _openModule(
                  const AdminReportManagementPage(),
                ),
              ),
              const SizedBox(height: 12),
              _ModuleCard(
                icon: Icons.leaderboard_rounded,
                iconBackground: const Color(0xFFE6F0FE),
                iconColor: const Color(0xFF2864DE),
                title: 'Violation Ranking',
                subtitle:
                'See which locations and issues rank highest '
                    'from approved reports',
                onTap: () => _openModule(
                  const ViolationDashboardReportView(),
                ),
              ),
              const SizedBox(height: 12),
              _ModuleCard(
                icon: Icons.tune_rounded,
                iconBackground: const Color(0xFFE6F7EE),
                iconColor: const Color(0xFF1E8E5A),
                title: 'Environment Parameters',
                subtitle:
                'Configure each attraction\'s geofence radius and '
                    'the default alert cooldown',
                onTap: () => _openModule(
                  const EnvironmentParameterPage(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero(String email) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 27,
            backgroundColor: Color(0x24FFFFFF),
            child: Icon(
              Icons.admin_panel_settings_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome back',
                  style: TextStyle(
                    color: Color(0xFFE3EDFC),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final String title;
  final String subtitle;
  final int? badgeCount;
  final VoidCallback onTap;

  const _ModuleCard({
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.heading,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.muted,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (badgeCount != null && badgeCount! > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4057),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badgeCount! > 99 ? '99+' : '${badgeCount!}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
