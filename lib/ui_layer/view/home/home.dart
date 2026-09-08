import 'dart:async';
import 'dart:math' as math;

import 'package:collab_dev/ui_layer/view/cultural_map/cultural_map.dart';
import 'package:flutter/material.dart';

import '../../../data_layer/model/repositories/notification/etiquette_notification_repository.dart';
import '../../../data_layer/model/services/firebase_authentication/firebase_authentication_service.dart';
import '../../view_model/home/home_view_model.dart';
import '../../view_model/settings/app_settings_controller.dart';
import '../../view_model/violation_dashboard_report/violation_dashboard_report_view_model.dart';
import '../notification_inbox/notification_inbox.dart';
import '../outfit_recognition/outfit_recognition.dart';
import '../violation_dashboard_report/violation_ranking_page.dart';
import 'profile.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final HomeViewModel _viewModel = HomeViewModel();

  final EtiquetteNotificationRepository _etiquetteNotificationRepository =
  EtiquetteNotificationRepository();

  final FirebaseAuthenticationService _authService =
  FirebaseAuthenticationService();

  final AppSettingsController _settings = AppSettingsController.instance;

  final ViolationDashboardReportViewModel _rankingViewModel =
  ViolationDashboardReportViewModel();

  final TextEditingController _searchController = TextEditingController();

  bool _isSearching = false;
  Timer? _greetingTimer;

  // =========================================================
  // INITIALIZATION
  // =========================================================

  @override
  void initState() {
    super.initState();

    _viewModel.addListener(_onViewModelChanged);
    _settings.addListener(_onViewModelChanged);
    _rankingViewModel.addListener(_onViewModelChanged);

    _viewModel.loadHomeData();
    _rankingViewModel.loadDashboard();

    _greetingTimer = Timer.periodic(
      const Duration(minutes: 1),
          (_) {
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  void _onViewModelChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _settings.removeListener(_onViewModelChanged);
    _rankingViewModel.removeListener(_onViewModelChanged);

    _greetingTimer?.cancel();

    _viewModel.dispose();
    _rankingViewModel.dispose();
    _searchController.dispose();

    super.dispose();
  }

  // =========================================================
  // SEARCH DESTINATION
  // =========================================================

  Future<void> _showEtiquette() async {
    final query = _searchController.text.trim();

    if (query.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              _settings.text(
                en: 'Please enter a destination first.',
                zh: '请先输入目的地。',
                ms: 'Sila masukkan destinasi terlebih dahulu.',
              ),
            ),
          ),
        );

      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSearching = true;
    });

    try {
      final results = await _viewModel.searchDestination(query);

      if (!mounted) {
        return;
      }

      if (results.isEmpty) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                _settings.text(
                  en: 'No cultural attraction found for "$query".',
                  zh: '找不到与“$query”相关的文化景点。',
                  ms: 'Tiada tarikan budaya ditemui untuk "$query".',
                ),
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );

        return;
      }

      if (results.length == 1) {
        final attraction = Map<String, dynamic>.from(results.first);

        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CulturalMapView(
              initialAttraction: attraction,
            ),
          ),
        );
      } else {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CulturalMapView(
              initialQuery: query,
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              _settings.text(
                en: 'Unable to search right now. Please try again.',
                zh: '目前无法搜索，请稍后再试。',
                ms: 'Carian tidak dapat dilakukan sekarang. Sila cuba lagi.',
              ),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  // =========================================================
  // NAVIGATION
  // =========================================================

  void _openOutfitPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const OutfitRecognitionView(),
      ),
    );
  }

  void _openExplorePage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const CulturalMapView(),
      ),
    );
  }

  void _openViolationRankingPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ViolationRankingPage(),
      ),
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        bottom: false,
        child: ScrollConfiguration(
          behavior: const _NoScrollbarBehavior(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopSection(),
                const SizedBox(height: 12),
                _buildHeroSection(),
                const SizedBox(height: 14),
                _buildEtiquetteCard(),
                const SizedBox(height: 18),
                _buildViolationBubbleMap(),
                const SizedBox(height: 18),
                _buildSloganSection(),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  String _homeDisplayName() {
    final user = _authService.currentUser;

    final displayName = user?.displayName?.trim() ?? '';

    if (displayName.isNotEmpty) {
      return displayName;
    }

    final email = user?.email?.trim() ?? '';

    if (email.contains('@')) {
      final prefix = email.split('@').first.trim();

      if (prefix.isNotEmpty) {
        return prefix;
      }
    }

    return _settings.text(
      en: 'Traveller',
      zh: '旅客',
      ms: 'Pelancong',
    );
  }

  String _timeBasedGreeting() {
    final hour = DateTime.now().hour;
    final name = _homeDisplayName();

    if (hour >= 5 && hour < 12) {
      return _settings.text(
        en: 'Good morning, $name',
        zh: '早上好，$name',
        ms: 'Selamat pagi, $name',
      );
    }

    if (hour >= 12 && hour < 17) {
      return _settings.text(
        en: 'Good afternoon, $name',
        zh: '下午好，$name',
        ms: 'Selamat tengah hari, $name',
      );
    }

    if (hour >= 17 && hour < 22) {
      return _settings.text(
        en: 'Good evening, $name',
        zh: '晚上好，$name',
        ms: 'Selamat petang, $name',
      );
    }

    return _settings.text(
      en: 'Good night, $name',
      zh: '晚安，$name',
      ms: 'Selamat malam, $name',
    );
  }

  // =========================================================
  // TOP SECTION
  // =========================================================

  Widget _buildTopSection() {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    size: 14,
                    color: Color(0xFFFF5E78),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _settings.text(
                      en: 'Kuala Lumpur, Malaysia',
                      zh: '马来西亚 · 吉隆坡',
                      ms: 'Kuala Lumpur, Malaysia',
                    ),
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 22,
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w900,
                    height: 1.08,
                  ),
                  children: [
                    TextSpan(text: '${_timeBasedGreeting()} '),
                    const TextSpan(text: '👋'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _buildNotificationButton(),
      ],
    );
  }

  Widget _buildNotificationButton() {
    final userId = _authService.currentUser?.uid;
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            shape: BoxShape.circle,
            border: Border.all(
              color: colorScheme.outlineVariant,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: Theme.of(context).brightness == Brightness.dark
                      ? 0.18
                      : 0.08,
                ),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: IconButton(
            padding: EdgeInsets.zero,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificationInboxView(),
                ),
              );
            },
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: Color(0xFF0F3158),
              size: 25,
            ),
          ),
        ),
        if (userId != null)
          StreamBuilder<int>(
            stream: _etiquetteNotificationRepository.watchUnreadCount(userId),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;

              if (unreadCount == 0) {
                return const SizedBox.shrink();
              }

              return Positioned(
                right: 1,
                top: -1,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 17,
                    minHeight: 17,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF4057),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    unreadCount > 9 ? '9+' : '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  // =========================================================
  // HERO SECTION
  // =========================================================

  Widget _buildHeroSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    final heroTop = isDark
        ? const Color(0xFF0E2B4A)
        : const Color(0xFFDDF3FF);
    final heroBottom = isDark
        ? const Color(0xFF0D4A58)
        : const Color(0xFFE8FFF7);

    return Container(
      height: 470,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            heroTop,
            heroBottom,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _ScenicBackgroundPainter(
                dark: isDark,
              ),
            ),

            Positioned(
              left: 18,
              top: 18,
              child: _buildHeroLabel(),
            ),

            Positioned(
              right: 20,
              top: 26,
              child: _buildHeroSideWords(),
            ),

            Positioned(
              left: 4,
              bottom: 52,
              child: SizedBox(
                width: 235,
                height: 300,
                child: Image.asset(
                  'lib/assets/images/home_avatar2.png',
                  fit: BoxFit.contain,
                  alignment: Alignment.bottomLeft,
                ),
              ),
            ),

            Positioned(
              left: 154,
              right: 18,
              top: 118,
              child: _buildSpeechBubble(),
            ),

            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: _buildSearchBar(),
            ),

            Positioned(
              right: 20,
              bottom: 78,
              child: Text(
                _settings.text(
                  en: 'Explore • Learn • Respect',
                  zh: '探索 · 学习 · 尊重',
                  ms: 'Teroka • Belajar • Hormat',
                ),
                style: TextStyle(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.78)
                      : const Color(0xFF326B70),
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroLabel() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.10)
            : Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.36),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.favorite_rounded,
            size: 14,
            color: isDark
                ? const Color(0xFFFFC9D2)
                : const Color(0xFFFF5A74),
          ),
          const SizedBox(width: 6),
          Text(
            _settings.text(
              en: 'Discover Malaysia',
              zh: '发现马来西亚',
              ms: 'Terokai Malaysia',
            ),
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF123B61),
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSideWords() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Text(
      _settings.text(
        en: 'Discover\nExplore\nRespect\nMalaysia',
        zh: '发现\n探索\n尊重\n马来西亚',
        ms: 'Temui\nTeroka\nHormati\nMalaysia',
      ),
      textAlign: TextAlign.right,
      style: TextStyle(
        color: isDark
            ? const Color(0xFFFFD978)
            : const Color(0xFF176E75),
        fontSize: 13,
        height: 1.08,
        fontWeight: FontWeight.w800,
        fontStyle: FontStyle.italic,
      ),
    );
  }

  Widget _buildSpeechBubble() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF142A3E).withValues(alpha: 0.96)
                : const Color(0xFFFFFBF4).withValues(alpha: 0.97),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: const Color(0xFFFFC456),
              width: 1.7,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: isDark ? 0.24 : 0.07,
                ),
                blurRadius: 16,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Text(
            _settings.text(
              en: 'Where would you like to go today?',
              zh: '你今天想去哪里？',
              ms: 'Ke mana anda mahu pergi hari ini?',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 16,
              height: 1.25,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Positioned(
          left: -10,
          bottom: 12,
          child: Transform.rotate(
            angle: math.pi / 4,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF142A3E)
                    : const Color(0xFFFFFBF4),
                border: Border(
                  left: const BorderSide(
                    color: Color(0xFFFFC456),
                    width: 1.7,
                  ),
                  bottom: const BorderSide(
                    color: Color(0xFFFFC456),
                    width: 1.7,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================
  // SEARCH + ETIQUETTE ACTION
  // =========================================================

  Widget _buildSearchBar() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: Theme.of(context).brightness == Brightness.dark
                  ? 0.18
                  : 0.07,
            ),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Icon(
            Icons.search_rounded,
            color: colorScheme.onSurface,
            size: 27,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) {
                _showEtiquette();
              },
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: _settings.text(
                  en: 'Search destination, place, or keyword...',
                  zh: '搜索目的地、景点或关键词...',
                  ms: 'Cari destinasi, tempat atau kata kunci...',
                ),
                hintStyle: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
          Container(
            width: 1,
            height: 26,
            color: colorScheme.outlineVariant,
          ),
          IconButton(
            tooltip: _settings.text(
              en: 'Search',
              zh: '搜索',
              ms: 'Cari',
            ),
            onPressed: _isSearching ? null : _showEtiquette,
            icon: _isSearching
                ? const SizedBox(
              width: 19,
              height: 19,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            )
                : Icon(
              Icons.tune_rounded,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildEtiquetteCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    final start = isDark
        ? const Color(0xFF143E43)
        : const Color(0xFFE6FFF9);
    final end = isDark
        ? const Color(0xFF0E6259)
        : const Color(0xFFD7F5E8);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isSearching ? null : _showEtiquette,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          height: 126,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [start, end],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.10),
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -18,
                bottom: -22,
                child: Icon(
                  Icons.menu_book_rounded,
                  size: 118,
                  color: isDark
                      ? const Color(0xFFFFD76A).withValues(alpha: 0.20)
                      : const Color(0xFF2DAA83).withValues(alpha: 0.15),
                ),
              ),
              Positioned(
                right: 28,
                top: 18,
                child: Container(
                  width: 47,
                  height: 47,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFFFFD76A).withValues(alpha: 0.18)
                        : Colors.white.withValues(alpha: 0.72),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lightbulb_rounded,
                    color: Color(0xFFFFB11B),
                    size: 30,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 110, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _settings.text(
                              en: 'Show Me the Etiquette',
                              zh: '查看文化礼仪',
                              ms: 'Tunjukkan Etika',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: colorScheme.onSurface,
                          size: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _settings.text(
                        en: "Learn the do's and don'ts before you go!",
                        zh: '出发前先了解当地的礼仪与禁忌！',
                        ms: 'Ketahui perkara yang patut dan tidak patut sebelum pergi!',
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 12.5,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================
  // TOP 3 VIOLATION RANKING
  // =========================================================

  Widget _buildViolationBubbleMap() {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final rows = List<Map<String, dynamic>>.from(
      _rankingViewModel.rankings,
    );

    rows.sort(
          (a, b) => _rankingScore(b).compareTo(_rankingScore(a)),
    );

    final topThree = rows.take(3).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surfaceContainerLow
            : const Color(0xFFFFFAF6),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: isDark
              ? colorScheme.outlineVariant
              : const Color(0xFFF4E7DC),
        ),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC145).withValues(
                    alpha: isDark ? 0.16 : 0.20,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: Color(0xFFFFAD16),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _settings.text(
                        en: 'Violation Ranking',
                        zh: '礼仪违规排名',
                        ms: 'Kedudukan Pelanggaran',
                      ),
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _settings.text(
                        en: 'Top 3 approved etiquette violations',
                        zh: '获批准次数最高的前三项礼仪违规',
                        ms: '3 pelanggaran etika diluluskan teratas',
                      ),
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _openViolationRankingPage,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _settings.text(
                        en: 'See All',
                        zh: '查看全部',
                        ms: 'Lihat Semua',
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_rankingViewModel.isLoading && topThree.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 44),
              child: CircularProgressIndicator(),
            )
          else if (topThree.isEmpty)
            _buildRankingEmptyState()
          else
            _buildRankingCards(topThree),
        ],
      ),
    );
  }

  Widget _buildRankingCards(
      List<Map<String, dynamic>> topThree,
      ) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final frequencies = topThree
        .map(
          (row) => _rankingFrequency(row),
    )
        .toList();

    final maxFrequency = frequencies.isEmpty
        ? 1
        : frequencies.reduce(
          (a, b) => a > b ? a : b,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = 9.0;
        final cardWidth =
            (constraints.maxWidth - gap * 2) / 3;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < topThree.length; index++) ...[
              if (index > 0) SizedBox(width: gap),
              SizedBox(
                width: cardWidth,
                child: _buildRankingCard(
                  topThree[index],
                  index + 1,
                  maxFrequency,
                  isDark,
                  colorScheme,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildRankingCard(
      Map<String, dynamic> row,
      int rank,
      int maxFrequency,
      bool isDark,
      ColorScheme colorScheme,
      ) {
    final frequency = _rankingFrequency(row);
    final score = _rankingScore(row);
    final title = _localizedViolationTitle(row);

    final rawLocation =
    (row['attractionName'] ?? row['attractionId'])
        ?.toString()
        .trim();

    final displayLocation = rawLocation == null || rawLocation.isEmpty
        ? _settings.text(
      en: 'Unknown attraction',
      zh: '未知景点',
      ms: 'Tarikan tidak diketahui',
    )
        : rawLocation;

    final progress = maxFrequency <= 0
        ? 0.0
        : (frequency / maxFrequency).clamp(0.0, 1.0);

    final accent = switch (rank) {
      1 => const Color(0xFFFFA62B),
      2 => const Color(0xFF9AA7B3),
      _ => const Color(0xFFC66A3A),
    };

    return InkWell(
      onTap: _openViolationRankingPage,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
        decoration: BoxDecoration(
          color: isDark
              ? colorScheme.surfaceContainerHighest
              : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  height: 82,
                  width: double.infinity,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        accent.withValues(
                          alpha: isDark ? 0.30 : 0.16,
                        ),
                        colorScheme.primary.withValues(
                          alpha: isDark ? 0.10 : 0.05,
                        ),
                      ],
                    ),
                  ),
                  child: Icon(
                    Icons.emoji_events_rounded,
                    size: 42,
                    color: accent,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.22),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text(
                      '#$rank',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 11.5,
                height: 1.18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '$frequency ${_settings.text(en: 'approved', zh: '已批准', ms: 'diluluskan')}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: accent,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              displayLocation,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: colorScheme.surfaceContainerHighest,
                color: accent,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _settings.text(
                en: '${score.toStringAsFixed(0)} pts',
                zh: '${score.toStringAsFixed(0)} 分',
                ms: '${score.toStringAsFixed(0)} mata',
              ),
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankingEmptyState() {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 38,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bar_chart_rounded,
              color: colorScheme.primary,
              size: 42,
            ),
            const SizedBox(height: 10),
            Text(
              _settings.text(
                en: 'No ranking data yet',
                zh: '暂时没有排名数据',
                ms: 'Belum ada data kedudukan',
              ),
              style: TextStyle(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              _settings.text(
                en: 'Approved etiquette violations will appear here.',
                zh: '获批准的礼仪违规会显示在这里。',
                ms: 'Pelanggaran etika yang diluluskan akan dipaparkan di sini.',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _rankingFrequency(
      Map<String, dynamic> row,
      ) {
    final value = row['frequency'] ?? 0;

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString()) ?? 0;
  }

  double _rankingScore(
      Map<String, dynamic> row,
      ) {
    final value = row['priorityScore'] ??
        row['score'] ??
        row['rankingScore'] ??
        0;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString()) ?? 0;
  }

  String _localizedViolationTitle(
      Map<String, dynamic> row,
      ) {
    final english = (row['ruleName'] ?? row['category'] ?? '')
        .toString()
        .trim();

    final chinese = (row['ruleNameZh'] ?? '')
        .toString()
        .trim();

    final malay = (row['ruleNameMs'] ?? '')
        .toString()
        .trim();

    final fallbackEnglish =
    english.isNotEmpty ? english : 'Etiquette issue';

    return _settings.text(
      en: fallbackEnglish,
      zh: chinese.isNotEmpty ? chinese : fallbackEnglish,
      ms: malay.isNotEmpty ? malay : fallbackEnglish,
    );
  }

  // =========================================================
  // SLOGAN
  // =========================================================

  Widget _buildSloganSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 124,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [
            Color(0xFF10273A),
            Color(0xFF163F46),
          ]
              : const [
            Color(0xFFF6FBFF),
            Color(0xFFE9FFF4),
          ],
        ),
        border: Border.all(
          color: colorScheme.outlineVariant,
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _SloganPainter(
                dark: isDark,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 112, 18),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _settings.text(
                  en: 'Respect the Culture,\nKeep Malaysia Beautiful ❤️',
                  zh: '尊重文化，\n让马来西亚更美丽 ❤️',
                  ms: 'Hormati Budaya,\nKekalkan Keindahan Malaysia ❤️',
                ),
                style: TextStyle(
                  color: isDark
                      ? Colors.white
                      : const Color(0xFF123B61),
                  fontSize: 17,
                  height: 1.25,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
          Positioned(
            right: 18,
            bottom: 13,
            child: Icon(
              Icons.local_florist_rounded,
              size: 66,
              color: isDark
                  ? const Color(0xFFFF607B).withValues(alpha: 0.88)
                  : const Color(0xFFFF5073),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // BOTTOM NAVIGATION - ONLY 4 ITEMS
  // =========================================================

  Widget _buildBottomNavigationBar() {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surfaceContainer
            : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: colorScheme.outlineVariant,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: isDark ? 0.24 : 0.08,
            ),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(
                icon: Icons.home_rounded,
                label: _settings.text(
                  en: 'Home',
                  zh: '主页',
                  ms: 'Utama',
                ),
                selected: true,
              ),
              _navItem(
                icon: Icons.explore_outlined,
                label: _settings.text(
                  en: 'Explore',
                  zh: '探索',
                  ms: 'Teroka',
                ),
                onTap: _openExplorePage,
              ),
              _navItem(
                icon: Icons.checkroom_outlined,
                label: _settings.text(
                  en: 'Outfit',
                  zh: '穿搭',
                  ms: 'Pakaian',
                ),
                onTap: _openOutfitPage,
              ),
              _navItem(
                icon: Icons.person_outline_rounded,
                label: _settings.text(
                  en: 'Profile',
                  zh: '我的',
                  ms: 'Profil',
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfileView(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem({
    required IconData icon,
    required String label,
    bool selected = false,
    VoidCallback? onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    final color = selected
        ? const Color(0xFF00A77E)
        : colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 37,
              height: 31,
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF00A77E).withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 23,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight:
                selected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================
// DECORATIVE PAINTERS
// ===========================================================

class _ScenicBackgroundPainter extends CustomPainter {
  final bool dark;

  const _ScenicBackgroundPainter({
    required this.dark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cloudPaint = Paint()
      ..color = dark
          ? Colors.white.withValues(alpha: 0.045)
          : Colors.white.withValues(alpha: 0.72);

    final mountainPaint = Paint()
      ..color = dark
          ? const Color(0xFF0C5A5A).withValues(alpha: 0.55)
          : const Color(0xFF9BD9CE).withValues(alpha: 0.46);

    final backMountainPaint = Paint()
      ..color = dark
          ? const Color(0xFF15536A).withValues(alpha: 0.38)
          : const Color(0xFF8EC8E8).withValues(alpha: 0.42);

    final waterPaint = Paint()
      ..color = dark
          ? const Color(0xFF0A5873).withValues(alpha: 0.34)
          : const Color(0xFF6ACFE1).withValues(alpha: 0.30);

    final foliagePaint = Paint()
      ..color = dark
          ? const Color(0xFF0D685B).withValues(alpha: 0.58)
          : const Color(0xFF46A976).withValues(alpha: 0.50);

    // Clouds
    for (final offset in [
      Offset(size.width * 0.12, size.height * 0.18),
      Offset(size.width * 0.34, size.height * 0.13),
      Offset(size.width * 0.77, size.height * 0.20),
    ]) {
      canvas.drawCircle(offset, 28, cloudPaint);
      canvas.drawCircle(offset + const Offset(28, 6), 22, cloudPaint);
      canvas.drawCircle(offset + const Offset(-24, 8), 18, cloudPaint);
    }

    // Back mountains
    final back = Path()
      ..moveTo(0, size.height * 0.59)
      ..lineTo(size.width * 0.14, size.height * 0.45)
      ..lineTo(size.width * 0.28, size.height * 0.57)
      ..lineTo(size.width * 0.43, size.height * 0.40)
      ..lineTo(size.width * 0.60, size.height * 0.57)
      ..lineTo(size.width * 0.73, size.height * 0.44)
      ..lineTo(size.width, size.height * 0.59)
      ..lineTo(size.width, size.height * 0.73)
      ..lineTo(0, size.height * 0.73)
      ..close();
    canvas.drawPath(back, backMountainPaint);

    // Front mountains
    final front = Path()
      ..moveTo(0, size.height * 0.67)
      ..lineTo(size.width * 0.18, size.height * 0.55)
      ..lineTo(size.width * 0.34, size.height * 0.68)
      ..lineTo(size.width * 0.55, size.height * 0.51)
      ..lineTo(size.width * 0.70, size.height * 0.68)
      ..lineTo(size.width * 0.88, size.height * 0.57)
      ..lineTo(size.width, size.height * 0.67)
      ..lineTo(size.width, size.height * 0.80)
      ..lineTo(0, size.height * 0.80)
      ..close();
    canvas.drawPath(front, mountainPaint);

    canvas.drawRect(
      Rect.fromLTWH(
        0,
        size.height * 0.70,
        size.width,
        size.height * 0.30,
      ),
      waterPaint,
    );

    // Decorative foliage
    for (var i = 0; i < 8; i++) {
      final x = i.isEven
          ? 12.0 + i * 3
          : size.width - 20.0 - i * 2;
      final y = size.height * (0.20 + i * 0.075);

      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, y),
          width: 42,
          height: 20,
        ),
        foliagePaint,
      );
    }

    // Simple landmark silhouettes on the right.
    final landmarkPaint = Paint()
      ..color = dark
          ? const Color(0xFFCCE8E9).withValues(alpha: 0.28)
          : const Color(0xFF2E7188).withValues(alpha: 0.33)
      ..style = PaintingStyle.fill;

    final baseY = size.height * 0.76;
    final towerX = size.width * 0.79;
    _drawTower(
      canvas,
      landmarkPaint,
      Offset(towerX, baseY),
      size.height * 0.27,
    );
    _drawTower(
      canvas,
      landmarkPaint,
      Offset(towerX + 36, baseY),
      size.height * 0.29,
    );

    final bridgePaint = Paint()
      ..color = landmarkPaint.color
      ..strokeWidth = 3;

    canvas.drawLine(
      Offset(towerX + 8, baseY - size.height * 0.13),
      Offset(towerX + 28, baseY - size.height * 0.13),
      bridgePaint,
    );
  }

  void _drawTower(
      Canvas canvas,
      Paint paint,
      Offset base,
      double height,
      ) {
    final bodyWidth = 18.0;

    canvas.drawRect(
      Rect.fromLTWH(
        base.dx,
        base.dy - height,
        bodyWidth,
        height,
      ),
      paint,
    );

    final spire = Path()
      ..moveTo(base.dx + bodyWidth / 2, base.dy - height - 28)
      ..lineTo(base.dx + 3, base.dy - height)
      ..lineTo(base.dx + bodyWidth - 3, base.dy - height)
      ..close();

    canvas.drawPath(spire, paint);

    for (var i = 0; i < 4; i++) {
      canvas.drawRect(
        Rect.fromLTWH(
          base.dx - 3 + i,
          base.dy - height + 18 + i * 28,
          bodyWidth + 6 - i * 2,
          5,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ScenicBackgroundPainter oldDelegate) {
    return oldDelegate.dark != dark;
  }
}

class _SloganPainter extends CustomPainter {
  final bool dark;

  const _SloganPainter({
    required this.dark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final hillPaint = Paint()
      ..color = dark
          ? const Color(0xFF235E62).withValues(alpha: 0.36)
          : const Color(0xFFB8E8D2).withValues(alpha: 0.54);

    final skylinePaint = Paint()
      ..color = dark
          ? const Color(0xFF83C8C4).withValues(alpha: 0.38)
          : const Color(0xFF4C9CA0).withValues(alpha: 0.38);

    final hill = Path()
      ..moveTo(size.width * 0.45, size.height)
      ..quadraticBezierTo(
        size.width * 0.63,
        size.height * 0.45,
        size.width * 0.78,
        size.height * 0.72,
      )
      ..quadraticBezierTo(
        size.width * 0.90,
        size.height * 0.55,
        size.width,
        size.height * 0.72,
      )
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(hill, hillPaint);

    final baseline = size.height * 0.86;

    for (var i = 0; i < 6; i++) {
      final x = size.width * 0.58 + i * 14;
      final h = 16.0 + (i % 3) * 9;

      canvas.drawRect(
        Rect.fromLTWH(
          x,
          baseline - h,
          8,
          h,
        ),
        skylinePaint,
      );
    }

    final towerX = size.width * 0.80;

    canvas.drawRect(
      Rect.fromLTWH(
        towerX,
        baseline - 52,
        8,
        52,
      ),
      skylinePaint,
    );

    canvas.drawRect(
      Rect.fromLTWH(
        towerX + 18,
        baseline - 58,
        8,
        58,
      ),
      skylinePaint,
    );

    final stroke = Paint()
      ..color = skylinePaint.color
      ..strokeWidth = 2;

    canvas.drawLine(
      Offset(towerX + 4, baseline - 52),
      Offset(towerX + 4, baseline - 68),
      stroke,
    );

    canvas.drawLine(
      Offset(towerX + 22, baseline - 58),
      Offset(towerX + 22, baseline - 74),
      stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _SloganPainter oldDelegate) {
    return oldDelegate.dark != dark;
  }
}

// ===========================================================
// REMOVE SCROLLBAR
// ===========================================================

class _NoScrollbarBehavior extends MaterialScrollBehavior {
  const _NoScrollbarBehavior();

  @override
  Widget buildScrollbar(
      BuildContext context,
      Widget child,
      ScrollableDetails details,
      ) {
    return child;
  }
}
