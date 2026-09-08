import 'package:flutter/material.dart';

import '../../../data_layer/model/repositories/ranking_report/ranking_report_repository.dart';
import '../../../data_layer/model/services/firebase_authentication/firebase_authentication_service.dart';
import '../../view_model/settings/app_settings_controller.dart';
import '../environment_parameter/environment_parameter.dart';
import '../violation_dashboard_report/violation_dashboard_report.dart';
import 'admin_report_management_page.dart';
import 'login_page.dart';

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
  final AppSettingsController _settings = AppSettingsController.instance;

  int? _pendingReportCount;

  String _t({
    required String en,
    required String zh,
    required String ms,
  }) {
    return _settings.text(
      en: en,
      zh: zh,
      ms: ms,
    );
  }

  @override
  void initState() {
    super.initState();
    _settings.addListener(_onSettingsChanged);
    _refreshPendingCount();
  }

  void _onSettingsChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  Future<void> _refreshPendingCount() async {
    try {
      final pending =
      await _rankingReportRepository.getPendingReports();

      if (!mounted) return;

      setState(() {
        _pendingReportCount = pending.length;
      });
    } catch (_) {
      // Keep badge hidden if the count cannot be fetched.
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
      MaterialPageRoute(
        builder: (_) => const LoginPage(),
      ),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final email =
        _authService.currentUser?.email ??
            _t(
              en: 'Administrator',
              zh: '管理员',
              ms: 'Pentadbir',
            );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        title: Text(
          _t(
            en: 'Admin Dashboard',
            zh: '管理员仪表板',
            ms: 'Papan Pemuka Pentadbir',
          ),
          style: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          _buildLanguageMenu(),
          IconButton(
            onPressed: _logout,
            tooltip: _t(
              en: 'Log out',
              zh: '退出登录',
              ms: 'Log keluar',
            ),
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: colorScheme.primary,
          onRefresh: _refreshPendingCount,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              20,
              8,
              20,
              24,
            ),
            children: [
              _buildHero(email),
              const SizedBox(height: 26),
              Text(
                _t(
                  en: 'Modules',
                  zh: '功能模块',
                  ms: 'Modul',
                ),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              _ModuleCard(
                icon: Icons.fact_check_rounded,
                iconBackground:
                colorScheme.primaryContainer,
                iconColor:
                colorScheme.onPrimaryContainer,
                title: _t(
                  en: 'Report Management',
                  zh: '报告管理',
                  ms: 'Pengurusan Laporan',
                ),
                subtitle: _t(
                  en:
                  'Review submitted etiquette reports and approve or reject them',
                  zh: '审核已提交的礼仪报告，并批准或拒绝报告',
                  ms:
                  'Semak laporan etika yang dihantar dan luluskan atau tolak laporan tersebut',
                ),
                badgeCount: _pendingReportCount,
                onTap: () => _openModule(
                  const AdminReportManagementPage(),
                ),
              ),
              const SizedBox(height: 12),
              _ModuleCard(
                icon: Icons.leaderboard_rounded,
                iconBackground:
                colorScheme.secondaryContainer,
                iconColor:
                colorScheme.onSecondaryContainer,
                title: _t(
                  en: 'Violation Ranking',
                  zh: '违规排名',
                  ms: 'Kedudukan Pelanggaran',
                ),
                subtitle: _t(
                  en:
                  'See which locations and issues rank highest from approved reports',
                  zh: '查看获批准报告中排名最高的地点和礼仪问题',
                  ms:
                  'Lihat lokasi dan isu yang menduduki kedudukan tertinggi daripada laporan yang diluluskan',
                ),
                onTap: () => _openModule(
                  const ViolationDashboardReportView(),
                ),
              ),
              const SizedBox(height: 12),
              _ModuleCard(
                icon: Icons.tune_rounded,
                iconBackground:
                colorScheme.tertiaryContainer,
                iconColor:
                colorScheme.onTertiaryContainer,
                title: _t(
                  en: 'Environment Parameters',
                  zh: '环境参数',
                  ms: 'Parameter Persekitaran',
                ),
                subtitle: _t(
                  en:
                  'Configure each attraction\'s geofence radius and the default alert cooldown',
                  zh:
                  '配置每个景点的地理围栏半径以及默认提醒冷却时间',
                  ms:
                  'Tetapkan jejari geofence setiap tarikan dan tempoh bertenang amaran lalai',
                ),
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

  Widget _buildLanguageMenu() {
    final colorScheme = Theme.of(context).colorScheme;

    return PopupMenuButton<AppLanguage>(
      initialValue: _settings.language,
      tooltip: _t(
        en: 'Change language',
        zh: '更改语言',
        ms: 'Tukar bahasa',
      ),
      onSelected: _settings.setLanguage,
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: AppLanguage.english,
          child: Text('English'),
        ),
        PopupMenuItem(
          value: AppLanguage.chinese,
          child: Text('中文'),
        ),
        PopupMenuItem(
          value: AppLanguage.malay,
          child: Text('Bahasa Melayu'),
        ),
      ],
      icon: Icon(
        Icons.language_rounded,
        color: colorScheme.primary,
      ),
    );
  }

  Widget _buildHero(String email) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary,
            colorScheme.tertiary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(
              alpha:
              Theme.of(context).brightness ==
                  Brightness.dark
                  ? 0.18
                  : 0.28,
            ),
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
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  _t(
                    en: 'Welcome back',
                    zh: '欢迎回来',
                    ms: 'Selamat kembali',
                  ),
                  style: TextStyle(
                    color:
                    Colors.white.withValues(
                      alpha: 0.86,
                    ),
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
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius:
            BorderRadius.circular(20),
            border: Border.all(
              color: colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius:
                  BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                        FontWeight.w700,
                        color:
                        colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: colorScheme
                            .onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (badgeCount != null &&
                  badgeCount! > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                  const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.error,
                    borderRadius:
                    BorderRadius.circular(20),
                  ),
                  child: Text(
                    badgeCount! > 99
                        ? '99+'
                        : '${badgeCount!}',
                    style: TextStyle(
                      color:
                      colorScheme.onError,
                      fontSize: 11,
                      fontWeight:
                      FontWeight.w700,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color:
                colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
