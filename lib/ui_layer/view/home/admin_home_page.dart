import 'package:flutter/material.dart';

import '../../../data_layer/model/repositories/ranking_report/ranking_report_repository.dart';
import '../../../data_layer/model/services/firebase_authentication/firebase_authentication_service.dart';
import '../../view_model/settings/app_settings_controller.dart';
import '../environment_parameter/environment_parameter.dart';
import '../profile_view/violation_dashboard_report.dart';
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
      backgroundColor:
          Theme.of(context).scaffoldBackgroundColor,
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
            fontWeight: FontWeight.w900,
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
            icon: const Icon(
              Icons.logout_rounded,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF00A77E),
          onRefresh: _refreshPendingCount,
          child: ListView(
            physics:
                const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              18,
              6,
              18,
              28,
            ),
            children: [
              // ==========================================
              // TOP WIDE RECTANGLE FROM YOUR SKETCH
              // ==========================================
              _buildHero(email),

              const SizedBox(height: 22),

              Row(
                children: [
                  Expanded(
                    child: Text(
                      _t(
                        en: 'Admin Tools',
                        zh: '管理员工具',
                        ms: 'Alat Pentadbir',
                      ),
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    _t(
                      en: 'Tap a card',
                      zh: '点击卡片',
                      ms: 'Tekan kad',
                    ),
                    style: TextStyle(
                      color:
                          colorScheme.onSurfaceVariant,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ==========================================
              // TWO CARDS SIDE BY SIDE
              // ==========================================
              Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _DashboardTile(
                      icon:
                          Icons.fact_check_rounded,
                      accent:
                          const Color(0xFF00A77E),
                      title: _t(
                        en: 'Report Management',
                        zh: '报告管理',
                        ms: 'Pengurusan Laporan',
                      ),
                      subtitle: _t(
                        en:
                            'Review pending etiquette reports',
                        zh:
                            '审核待处理的礼仪报告',
                        ms:
                            'Semak laporan etika tertunda',
                      ),
                      badgeCount:
                          _pendingReportCount,
                      onTap: () => _openModule(
                        const AdminReportManagementPage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DashboardTile(
                      icon:
                          Icons.emoji_events_rounded,
                      accent:
                          const Color(0xFFFFB744),
                      title: _t(
                        en: 'Violation Ranking',
                        zh: '违规排名',
                        ms: 'Kedudukan Pelanggaran',
                      ),
                      subtitle: _t(
                        en:
                            'View ranked places and issues',
                        zh:
                            '查看地点和违规排名',
                        ms:
                            'Lihat kedudukan lokasi dan isu',
                      ),
                      onTap: () => _openModule(
                        const ViolationDashboardReportView(),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ==========================================
              // THIRD CARD ON LEFT, EMPTY SPACE ON RIGHT
              // EXACTLY LIKE YOUR SKETCH
              // ==========================================
              Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _DashboardTile(
                      icon: Icons.tune_rounded,
                      accent:
                          const Color(0xFF4C8BFF),
                      title: _t(
                        en:
                            'Environment Parameters',
                        zh: '环境参数',
                        ms:
                            'Parameter Persekitaran',
                      ),
                      subtitle: _t(
                        en:
                            'Geofence radius and alert cooldown',
                        zh:
                            '地理围栏半径和提醒冷却时间',
                        ms:
                            'Jejari geofence dan tempoh bertenang',
                      ),
                      onTap: () => _openModule(
                        const EnvironmentParameterPage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: SizedBox(
                      height: 170,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // ==========================================
              // BOTTOM WIDE RECTANGLE FROM YOUR SKETCH
              // ==========================================
              _buildFooterBanner(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageMenu() {
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
      icon: const Icon(
        Icons.language_rounded,
        color: Color(0xFF00A77E),
      ),
    );
  }

  Widget _buildHero(String email) {
    final isDark =
        Theme.of(context).brightness ==
            Brightness.dark;

    return Container(
      height: 170,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [
                  Color(0xFF102D45),
                  Color(0xFF0D5F5A),
                ]
              : const [
                  Color(0xFFDDF4FF),
                  Color(0xFFE7FBF5),
                ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: isDark ? 0.18 : 0.06,
            ),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -12,
            bottom: -26,
            child: Icon(
              Icons.admin_panel_settings_rounded,
              size: 145,
              color:
                  const Color(0xFF00A77E)
                      .withValues(
                alpha:
                    isDark ? 0.17 : 0.10,
              ),
            ),
          ),
          const Positioned(
            right: 20,
            top: 10,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: Color(0xFFFFB744),
              size: 29,
            ),
          ),
          Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color:
                      const Color(0xFF00A77E)
                          .withValues(
                    alpha: 0.12,
                  ),
                  borderRadius:
                      BorderRadius.circular(14),
                ),
                child: Text(
                  _t(
                    en: 'CultureGuide Admin',
                    zh: 'CultureGuide 管理员',
                    ms:
                        'Pentadbir CultureGuide',
                  ),
                  style: const TextStyle(
                    color:
                        Color(0xFF00A77E),
                    fontSize: 11,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 15),
              Text(
                _t(
                  en: 'Welcome back',
                  zh: '欢迎回来',
                  ms: 'Selamat kembali',
                ),
                style: TextStyle(
                  color: isDark
                      ? Colors.white
                          .withValues(
                          alpha: 0.72,
                        )
                      : const Color(
                          0xFF4A6872,
                        ),
                  fontSize: 12,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              SizedBox(
                width: 245,
                child: Text(
                  email,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark
                        ? Colors.white
                        : const Color(
                            0xFF123B61,
                          ),
                    fontSize: 19,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooterBanner() {
    final colorScheme =
        Theme.of(context).colorScheme;
    final isDark =
        Theme.of(context).brightness ==
            Brightness.dark;

    return Container(
      constraints: const BoxConstraints(
        minHeight: 76,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 16,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: isDark
              ? const [
                  Color(0xFF15283B),
                  Color(0xFF173B39),
                ]
              : const [
                  Color(0xFFFFF6E6),
                  Color(0xFFEAFBF5),
                ],
        ),
        border: Border.all(
          color: colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color:
                  const Color(0xFFFF5F78)
                      .withValues(
                alpha: 0.12,
              ),
              borderRadius:
                  BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.favorite_rounded,
              color: Color(0xFFFF5F78),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  _t(
                    en:
                        'Respect the Culture, Keep Malaysia Beautiful',
                    zh:
                        '尊重文化，让马来西亚更美丽',
                    ms:
                        'Hormati Budaya, Kekalkan Keindahan Malaysia',
                  ),
                  style: TextStyle(
                    color:
                        colorScheme.onSurface,
                    fontSize: 13,
                    height: 1.3,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _t(
                    en:
                        'Review fairly • guide responsibly',
                    zh:
                        '公平审核 • 负责任地引导',
                    ms:
                        'Semak dengan adil • bimbing dengan bertanggungjawab',
                  ),
                  style: TextStyle(
                    color: colorScheme
                        .onSurfaceVariant,
                    fontSize: 11,
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

class _DashboardTile extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final int? badgeCount;
  final VoidCallback onTap;

  const _DashboardTile({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        Theme.of(context).colorScheme;
    final isDark =
        Theme.of(context).brightness ==
            Brightness.dark;

    return SizedBox(
      height: 170,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius:
              BorderRadius.circular(24),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: isDark
                  ? colorScheme
                      .surfaceContainerLow
                  : colorScheme.surface,
              borderRadius:
                  BorderRadius.circular(24),
              border: Border.all(
                color:
                    colorScheme.outlineVariant,
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      Colors.black.withValues(
                    alpha:
                        isDark ? 0.14 : 0.05,
                  ),
                  blurRadius: 16,
                  offset:
                      const Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -8,
                  bottom: -10,
                  child: Icon(
                    icon,
                    size: 70,
                    color:
                        accent.withValues(
                      alpha:
                          isDark ? 0.08 : 0.07,
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration:
                              BoxDecoration(
                            color: accent
                                .withValues(
                              alpha: isDark
                                  ? 0.17
                                  : 0.12,
                            ),
                            borderRadius:
                                BorderRadius
                                    .circular(
                              14,
                            ),
                          ),
                          child: Icon(
                            icon,
                            color: accent,
                            size: 24,
                          ),
                        ),
                        const Spacer(),
                        if (badgeCount !=
                                null &&
                            badgeCount! > 0)
                          Container(
                            padding:
                                const EdgeInsets
                                    .symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration:
                                BoxDecoration(
                              color:
                                  const Color(
                                0xFFFF5F78,
                              ),
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                20,
                              ),
                            ),
                            child: Text(
                              badgeCount! > 99
                                  ? '99+'
                                  : '${badgeCount!}',
                              style:
                                  const TextStyle(
                                color:
                                    Colors.white,
                                fontSize: 10,
                                fontWeight:
                                    FontWeight
                                        .w900,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      title,
                      maxLines: 2,
                      overflow:
                          TextOverflow.ellipsis,
                      style: TextStyle(
                        color:
                            colorScheme.onSurface,
                        fontSize: 14.2,
                        height: 1.15,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow:
                          TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colorScheme
                            .onSurfaceVariant,
                        fontSize: 10.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
