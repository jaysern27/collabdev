import 'dart:async';

import 'package:collab_dev/ui_layer/view/cultural_map/cultural_map.dart';
import 'package:flutter/material.dart';

import '../../view_model/settings/app_settings_controller.dart';
import '../../view_model/violation_dashboard_report/violation_dashboard_report_view_model.dart';
import '../violation_dashboard_report/violation_ranking_page.dart';

import '../../../data_layer/model/repositories/notification/etiquette_notification_repository.dart';
import '../../../data_layer/model/services/firebase_authentication/firebase_authentication_service.dart';
import '../../view_model/home/home_view_model.dart';
import '../notification_inbox/notification_inbox.dart';
import '../outfit_recognition/outfit_recognition.dart';
import 'profile.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final HomeViewModel _viewModel =
  HomeViewModel();

  final EtiquetteNotificationRepository
  _etiquetteNotificationRepository =
  EtiquetteNotificationRepository();

  final FirebaseAuthenticationService _authService =
  FirebaseAuthenticationService();

  final AppSettingsController _settings =
      AppSettingsController.instance;

  final ViolationDashboardReportViewModel _rankingViewModel =
  ViolationDashboardReportViewModel();

  final TextEditingController _searchController =
  TextEditingController();

  bool _isSearching = false;

  Timer? _greetingTimer;

  // =========================================================
  // INITIALIZATION
  // =========================================================

  @override
  void initState() {
    super.initState();

    _viewModel.addListener(
      _onViewModelChanged,
    );

    _settings.addListener(
      _onViewModelChanged,
    );

    _rankingViewModel.addListener(
      _onViewModelChanged,
    );

    _viewModel.loadHomeData();
    _rankingViewModel.loadDashboard();

    // Keep the greeting in sync with the phone's local clock.
    _greetingTimer =
        Timer.periodic(
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
    _viewModel.removeListener(
      _onViewModelChanged,
    );

    _settings.removeListener(
      _onViewModelChanged,
    );

    _rankingViewModel.removeListener(
      _onViewModelChanged,
    );

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
    final query =
    _searchController.text.trim();

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
      final results =
      await _viewModel.searchDestination(
        query,
      );

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
              behavior:
              SnackBarBehavior.floating,
            ),
          );

        return;
      }

      final attraction =
      Map<String, dynamic>.from(
        results.first,
      );

      // Go directly to Cultural Map, centre the map on the matched
      // attraction, and automatically open that attraction's details.
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              CulturalMapView(
                initialAttraction:
                attraction,
              ),
        ),
      );
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
            behavior:
            SnackBarBehavior.floating,
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
        builder: (context) =>
        const OutfitRecognitionView(),
      ),
    );
  }

  void _openExplorePage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
        const CulturalMapView(),
      ),
    );
  }


  void _openViolationRankingPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
        const ViolationRankingPage(),
      ),
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,

      body: SafeArea(
        child: ScrollConfiguration(
          behavior:
          const _NoScrollbarBehavior(),
          child: SingleChildScrollView(
            padding:
            const EdgeInsets.fromLTRB(
              18,
              12,
              18,
              12,
            ),
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                _buildTopSection(),

                const SizedBox(
                  height: 16,
                ),

                _buildHeroSection(),

                const SizedBox(
                  height: 22,
                ),

                _buildViolationBubbleMap(),

                const SizedBox(
                  height: 14,
                ),
              ],
            ),
          ),
        ),
      ),

      bottomNavigationBar:
      _buildBottomNavigationBar(),
    );
  }

  String _homeDisplayName() {
    final user =
        _authService.currentUser;

    final displayName =
        user?.displayName?.trim() ?? '';

    if (displayName.isNotEmpty) {
      return displayName;
    }

    final email =
        user?.email?.trim() ?? '';

    if (email.contains('@')) {
      final prefix =
      email.split('@').first.trim();

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
    final hour =
        DateTime.now().hour;

    final name =
    _homeDisplayName();

    if (hour >= 5 &&
        hour < 12) {
      return _settings.text(
        en: 'Good morning, $name',
        zh: '早上好，$name',
        ms: 'Selamat pagi, $name',
      );
    }

    if (hour >= 12 &&
        hour < 17) {
      return _settings.text(
        en: 'Good afternoon, $name',
        zh: '下午好，$name',
        ms: 'Selamat tengah hari, $name',
      );
    }

    if (hour >= 17 &&
        hour < 22) {
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
    return Row(
      crossAxisAlignment:
      CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    size: 13,
                    color: Color(
                      0xFFFF4F73,
                    ),
                  ),

                  const SizedBox(
                    width: 3,
                  ),

                  Text(
                    _settings.text(
                      en: 'Kuala Lumpur, Malaysia',
                      zh: '马来西亚 · 吉隆坡',
                      ms: 'Kuala Lumpur, Malaysia',
                    ),
                    style: const TextStyle(
                      color: Color(
                        0xFF0093A3,
                      ),
                      fontSize: 11,
                      fontWeight:
                      FontWeight.w600,
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 3,
              ),

              RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 17,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface,
                    fontWeight:
                    FontWeight.w800,
                  ),
                  children: [
                    TextSpan(
                      text:
                      '${_timeBasedGreeting()} ',
                    ),
                    const TextSpan(
                      text: '👋',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        _buildNotificationButton(),
      ],
    );
  }

  Widget _buildNotificationButton() {
    final userId = _authService.currentUser?.uid;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration:
          const BoxDecoration(
            color: Color(
              0xFFFFF0C9,
            ),
            shape: BoxShape.circle,
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
              Icons.notifications,
              color: Color(
                0xFFFFA800,
              ),
              size: 22,
            ),
          ),
        ),

        if (userId != null)
          StreamBuilder<int>(
            stream: _etiquetteNotificationRepository
                .watchUnreadCount(userId),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;

              if (unreadCount == 0) {
                return const SizedBox.shrink();
              }

              return Positioned(
                right: -1,
                top: -3,
                child: Container(
                  width: 17,
                  height: 17,
                  alignment:
                  Alignment.center,
                  decoration:
                  const BoxDecoration(
                    color: Color(
                      0xFFFF4057,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    unreadCount > 9 ? '9+' : '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight:
                      FontWeight.bold,
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
    return Container(
      height: 710,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius:
        BorderRadius.circular(
          28,
        ),
        gradient:
        const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(
              0xFF18B7C8,
            ),
            Color(
              0xFF1E78D8,
            ),
          ],
        ),
      ),
      child: ClipRRect(
        borderRadius:
        BorderRadius.circular(
          28,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Decorative circle
            Positioned(
              left: -35,
              top: 120,
              child: Container(
                width: 95,
                height: 95,
                decoration:
                BoxDecoration(
                  color: Colors.white
                      .withValues(
                    alpha: 0.10,
                  ),
                  shape:
                  BoxShape.circle,
                ),
              ),
            ),

            // Decorative circle
            Positioned(
              right: 18,
              bottom: 35,
              child: Container(
                width: 90,
                height: 90,
                decoration:
                BoxDecoration(
                  border: Border.all(
                    color: Colors.white
                        .withValues(
                      alpha: 0.15,
                    ),
                    width: 1.2,
                  ),
                  shape:
                  BoxShape.circle,
                ),
              ),
            ),

            // Smaller decorative circle
            Positioned(
              right: 35,
              bottom: 55,
              child: Container(
                width: 55,
                height: 55,
                decoration:
                BoxDecoration(
                  border: Border.all(
                    color: Colors.white
                        .withValues(
                      alpha: 0.12,
                    ),
                  ),
                  shape:
                  BoxShape.circle,
                ),
              ),
            ),

            // Thinking bubble
            Positioned(
              left: 42,
              right: 42,
              top: 40,
              child:
              _buildThinkingBubbleCard(),
            ),

            // Avatar
            Positioned(
              left: 0,
              right: 0,
              bottom: 30,
              child:
              _buildHomeAvatar(),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // THINKING BUBBLE
  // =========================================================

  Widget _buildThinkingBubbleCard() {
    final colorScheme =
        Theme.of(context).colorScheme;

    return SizedBox(
      height: 430,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(
                18,
                18,
                18,
                18,
              ),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: colorScheme.outlineVariant,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: Theme.of(context).brightness ==
                          Brightness.dark
                          ? 0.22
                          : 0.08,
                    ),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    _settings.text(
                      en: 'Where are you thinking of going?',
                      zh: '你想去哪里？',
                      ms: 'Anda bercadang hendak pergi ke mana?',
                    ),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _settings.text(
                      en: "Tell me the destination and I'll give you the cultural etiquette.",
                      zh: '告诉我目的地，我会为你提供当地的文化礼仪指南。',
                      ms: 'Beritahu destinasi anda dan saya akan tunjukkan panduan etika budaya.',
                    ),
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: colorScheme.primary,
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search,
                          color: colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            textInputAction:
                            TextInputAction.search,
                            onSubmitted: (_) {
                              _showEtiquette();
                            },
                            style: TextStyle(
                              color: colorScheme.onSurface,
                            ),
                            decoration: InputDecoration(
                              hintText: _settings.text(
                                en: 'e.g. Batu Caves, Masjid Jamek',
                                zh: '例如：黑风洞、占美清真寺',
                                ms: 'cth. Batu Caves, Masjid Jamek',
                              ),
                              hintStyle: TextStyle(
                                color:
                                colorScheme.onSurfaceVariant,
                                fontSize: 13,
                              ),
                              border: InputBorder.none,
                              isCollapsed: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFF6A88F),
                            Color(0xFFF3CE59),
                          ],
                        ),
                      ),
                      child: TextButton(
                        onPressed: _isSearching
                            ? null
                            : _showEtiquette,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          disabledForegroundColor:
                          Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(14),
                          ),
                        ),
                        child: _isSearching
                            ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                          CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                            : Text(
                          _settings.text(
                            en: 'Show Me the Etiquette →',
                            zh: '查看文化礼仪 →',
                            ms: 'Tunjukkan Etika →',
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight:
                            FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 43,
            top: 270,
            child: _buildThoughtBubbleCircle(24),
          ),
          Positioned(
            left: 50,
            top: 310,
            child: _buildThoughtBubbleCircle(20),
          ),
          Positioned(
            left: 58,
            top: 348,
            child: _buildThoughtBubbleCircle(16),
          ),
          Positioned(
            left: 70,
            top: 380,
            child: _buildThoughtBubbleCircle(12),
          ),
          Positioned(
            left: 90,
            top: 410,
            child: _buildThoughtBubbleCircle(8),
          ),
        ],
      ),
    );
  }

  Widget _buildThoughtBubbleCircle(
      double size,
      ) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withValues(
              alpha: 0.05,
            ),
            blurRadius: 6,
            offset:
            const Offset(
              0,
              3,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // TOP 3 VIOLATION RANKING BAR CHART
  // =========================================================

  Widget _buildViolationBubbleMap() {
    final colorScheme =
        Theme.of(context).colorScheme;

    final rows =
    List<Map<String, dynamic>>.from(
      _rankingViewModel.rankings,
    );

    // Keep the actual ranking order based on priority points.
    rows.sort(
          (a, b) => _rankingScore(b)
          .compareTo(_rankingScore(a)),
    );

    final topThree =
    rows.take(3).toList();

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    _settings.text(
                      en: 'Violation Ranking',
                      zh: '礼仪违规排名',
                      ms: 'Kedudukan Pelanggaran',
                    ),
                    style: TextStyle(
                      color:
                      colorScheme.onSurface,
                      fontSize: 19,
                      fontWeight:
                      FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _settings.text(
                      en: 'Top 3 approved etiquette violations.',
                      zh: '获批准次数最高的前三项礼仪违规。',
                      ms: '3 pelanggaran etika diluluskan teratas.',
                    ),
                    style: TextStyle(
                      color: colorScheme
                          .onSurfaceVariant,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed:
              _openViolationRankingPage,
              child: Text(
                _settings.text(
                  en: 'View All',
                  zh: '查看全部',
                  ms: 'Lihat Semua',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Material(
          color: colorScheme.surface,
          borderRadius:
          BorderRadius.circular(24),
          child: InkWell(
            onTap: topThree.isEmpty
                ? null
                : _openViolationRankingPage,
            borderRadius:
            BorderRadius.circular(24),
            child: Container(
              width: double.infinity,
              padding:
              const EdgeInsets.fromLTRB(
                16,
                18,
                16,
                15,
              ),
              decoration: BoxDecoration(
                borderRadius:
                BorderRadius.circular(24),
                border: Border.all(
                  color:
                  colorScheme.outlineVariant,
                ),
              ),
              child:
              _rankingViewModel.isLoading &&
                  topThree.isEmpty
                  ? const Center(
                child: Padding(
                  padding:
                  EdgeInsets.all(40),
                  child:
                  CircularProgressIndicator(),
                ),
              )
                  : topThree.isEmpty
                  ? _buildRankingEmptyState()
                  : _buildRankingBarChart(
                topThree,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRankingBarChart(
      List<Map<String, dynamic>> topThree,
      ) {
    final colorScheme =
        Theme.of(context).colorScheme;

    final frequencies = topThree
        .map(
          (row) => _rankingFrequency(row),
    )
        .toList();

    final maxFrequency =
    frequencies.isEmpty
        ? 1
        : frequencies.reduce(
          (a, b) => a > b ? a : b,
    );

    return Column(
      children: [
        ...topThree.asMap().entries.map(
              (entry) {
            final index = entry.key;
            final row = entry.value;

            final rank = index + 1;
            final frequency =
            _rankingFrequency(row);
            final score =
            _rankingScore(row);

            final title =
            _translatedViolationTitle(
              row['ruleName']
                  ?.toString() ??
                  row['category']
                      ?.toString() ??
                  _settings.text(
                    en: 'Etiquette issue',
                    zh: '礼仪问题',
                    ms: 'Isu etika',
                  ),
            );

            final progress =
            maxFrequency <= 0
                ? 0.0
                : (frequency /
                maxFrequency)
                .clamp(
              0.0,
              1.0,
            );

            return Padding(
              padding: EdgeInsets.only(
                bottom: index ==
                    topThree.length - 1
                    ? 0
                    : 16,
              ),
              child: Row(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment:
                    Alignment.center,
                    decoration:
                    BoxDecoration(
                      color: rank <= 3
                          ? colorScheme
                          .primaryContainer
                          : colorScheme
                          .surfaceContainerHighest,
                      borderRadius:
                      BorderRadius.circular(
                        12,
                      ),
                    ),
                    child: Text(
                      '#$rank',
                      style: TextStyle(
                        color: rank <= 3
                            ? colorScheme
                            .onPrimaryContainer
                            : colorScheme
                            .onSurfaceVariant,
                        fontWeight:
                        FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                      children: [
                        Row(
                          crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 2,
                                overflow:
                                TextOverflow
                                    .ellipsis,
                                style:
                                TextStyle(
                                  color:
                                  colorScheme
                                      .onSurface,
                                  fontSize: 13,
                                  height: 1.2,
                                  fontWeight:
                                  FontWeight
                                      .w800,
                                ),
                              ),
                            ),
                            const SizedBox(
                              width: 10,
                            ),
                            Column(
                              crossAxisAlignment:
                              CrossAxisAlignment
                                  .end,
                              children: [
                                Text(
                                  '$frequency',
                                  style:
                                  TextStyle(
                                    color:
                                    colorScheme
                                        .primary,
                                    fontSize: 20,
                                    fontWeight:
                                    FontWeight
                                        .w900,
                                    height: 1,
                                  ),
                                ),
                                Text(
                                  _settings.text(
                                    en: 'approved',
                                    zh: '已批准',
                                    ms: 'diluluskan',
                                  ),
                                  style:
                                  TextStyle(
                                    color:
                                    colorScheme
                                        .onSurfaceVariant,
                                    fontSize: 9,
                                    fontWeight:
                                    FontWeight
                                        .w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius:
                          BorderRadius.circular(
                            30,
                          ),
                          child:
                          LinearProgressIndicator(
                            value: progress,
                            minHeight: 8,
                            backgroundColor:
                            colorScheme
                                .surfaceContainerHighest,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _settings.text(
                            en: 'Priority ${score.toStringAsFixed(0)} pts',
                            zh: '优先级 ${score.toStringAsFixed(0)} 分',
                            ms: 'Keutamaan ${score.toStringAsFixed(0)} mata',
                          ),
                          style: TextStyle(
                            color: colorScheme
                                .onSurfaceVariant,
                            fontSize: 10.5,
                            fontWeight:
                            FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 15),
        Divider(
          height: 1,
          color: colorScheme.outlineVariant,
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            Icon(
              Icons.touch_app_outlined,
              size: 16,
              color:
              colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                _settings.text(
                  en: 'Tap to view the full ranking',
                  zh: '点击查看完整排名',
                  ms: 'Tekan untuk melihat kedudukan penuh',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colorScheme
                      .onSurfaceVariant,
                  fontSize: 11.5,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRankingEmptyState() {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding:
        const EdgeInsets.symmetric(
          vertical: 42,
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
                fontWeight:
                FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              _settings.text(
                en: 'Approved etiquette violations will appear here.',
                zh: '获批准的礼仪违规会显示在这里。',
                ms: 'Pelanggaran etika yang diluluskan akan dipaparkan di sini.',
              ),
              textAlign:
              TextAlign.center,
              style: TextStyle(
                color: colorScheme
                    .onSurfaceVariant,
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

    return int.tryParse(
      value.toString(),
    ) ??
        0;
  }

  double _rankingScore(
      Map<String, dynamic> row,
      ) {
    final value =
        row['priorityScore'] ??
            row['score'] ??
            row['rankingScore'] ??
            0;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value.toString(),
    ) ??
        0;
  }

  String _translatedViolationTitle(
      String raw,
      ) {
    final normalized =
    raw.trim().toLowerCase();

    if (normalized.contains('dress')) {
      return _settings.text(
        en: 'Dress Code',
        zh: '着装规范',
        ms: 'Etika Pakaian',
      );
    }

    if (normalized.contains('photo')) {
      return _settings.text(
        en: 'Photography',
        zh: '摄影礼仪',
        ms: 'Etika Fotografi',
      );
    }

    if (normalized.contains('worship') ||
        normalized.contains('prayer')) {
      return _settings.text(
        en: 'Worship Etiquette',
        zh: '礼拜礼仪',
        ms: 'Etika Ibadah',
      );
    }

    if (normalized.contains('noise') ||
        normalized.contains('loud')) {
      return _settings.text(
        en: 'Noise & Behaviour',
        zh: '噪音与行为',
        ms: 'Bunyi & Tingkah Laku',
      );
    }

    return raw;
  }

  // =========================================================
  // HOME AVATAR
  // =========================================================

  Widget _buildHomeAvatar() {
    return Center(
      child: SizedBox(
        width: 230,
        height: 230,
        child: Image.asset(
          'lib/assets/images/home_avatar.png',
          fit: BoxFit.contain,
          alignment:
          Alignment.bottomCenter,
        ),
      ),
    );
  }

  // =========================================================
  // BOTTOM NAVIGATION
  // =========================================================

  Widget _buildBottomNavigationBar() {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Container(
      decoration:
      BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 59,
          child: Row(
            mainAxisAlignment:
            MainAxisAlignment
                .spaceAround,
            children: [
              _navItem(
                icon:
                Icons.home_rounded,
                label: _settings.text(en: 'Home', zh: '主页', ms: 'Utama'),
                selected: true,
              ),

              _navItem(
                icon: Icons
                    .explore_outlined,
                label: _settings.text(en: 'Explore', zh: '探索', ms: 'Teroka'),
                onTap:
                _openExplorePage,
              ),

              _navItem(
                icon: Icons
                    .checkroom_outlined,
                label: _settings.text(en: 'Outfit', zh: '穿搭', ms: 'Pakaian'),
                onTap:
                _openOutfitPage,
              ),

              _navItem(

                icon: Icons.person_outline,

                label: _settings.text(en: 'Profile', zh: '我的', ms: 'Profil'),

                onTap: (){

                  Navigator.push(

                    context,

                    MaterialPageRoute(

                      builder: (context)=>
                      const ProfileView(),

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
    final colorScheme =
        Theme.of(context).colorScheme;

    final color =
    selected
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      borderRadius:
      BorderRadius.circular(
        12,
      ),
      child: SizedBox(
        width: 65,
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 22,
              color: color,
            ),

            const SizedBox(
              height: 2,
            ),

            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 9.5,
                fontWeight:
                selected
                    ? FontWeight
                    .w700
                    : FontWeight
                    .w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================
// REMOVE SCROLLBAR
// ===========================================================

class _NoScrollbarBehavior
    extends MaterialScrollBehavior {
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