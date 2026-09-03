import 'package:collab_dev/ui_layer/view/cultural_map/cultural_map.dart';
import 'package:flutter/material.dart';

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

  final TextEditingController _searchController =
  TextEditingController();

  bool _isSearching = false;

  // =========================================================
  // INITIALIZATION
  // =========================================================

  @override
  void initState() {
    super.initState();

    _viewModel.addListener(
      _onViewModelChanged,
    );

    _viewModel.loadHomeData();
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

    _viewModel.dispose();
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter a destination first.',
          ),
        ),
      );

      return;
    }

    setState(() {
      _isSearching = true;
    });

    final results =
    await _viewModel.searchDestination(
      query,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isSearching = false;
    });

    if (results.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No cultural attraction found.',
          ),
        ),
      );

      return;
    }

    final attraction =
        results.first;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Found: '
              '${attraction['name'] ?? 'Attraction'}',
        ),
      ),
    );

    // Later:
    // Navigate to attraction etiquette details.
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

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(
        0xFFFFFFFF,
      ),

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
                  height: 14,
                ),

                _buildHeroSection(),
              ],
            ),
          ),
        ),
      ),

      bottomNavigationBar:
      _buildBottomNavigationBar(),
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
              const Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 13,
                    color: Color(
                      0xFFFF4F73,
                    ),
                  ),

                  SizedBox(
                    width: 3,
                  ),

                  Text(
                    'Kuala Lumpur, Malaysia',
                    style: TextStyle(
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
                text: const TextSpan(
                  style: TextStyle(
                    fontSize: 17,
                    color: Color(
                      0xFF14213D,
                    ),
                    fontWeight:
                    FontWeight.w800,
                  ),
                  children: [
                    TextSpan(
                      text:
                      'Good morning, Jay ',
                    ),
                    TextSpan(
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
    return SizedBox(
      height: 430,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Main bubble
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Container(
              padding:
              const EdgeInsets
                  .fromLTRB(
                18,
                18,
                18,
                18,
              ),
              decoration:
              BoxDecoration(
                color: const Color(
                  0xFFFFFFFF,
                ),
                borderRadius:
                BorderRadius.circular(
                  26,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black
                        .withValues(
                      alpha: 0.08,
                    ),
                    blurRadius: 14,
                    offset:
                    const Offset(
                      0,
                      6,
                    ),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment
                    .start,
                children: [
                  const Text(
                    'Where are you thinking of going?',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight:
                      FontWeight.w800,
                      color: Color(
                        0xFF14213D,
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 6,
                  ),

                  Text(
                    "Tell me the destination and I'll give you the\n"
                        'cultural etiquette.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: Colors.black
                          .withValues(
                        alpha: 0.45,
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 14,
                  ),

                  // Search field
                  Container(
                    height: 50,
                    padding:
                    const EdgeInsets
                        .symmetric(
                      horizontal: 14,
                    ),
                    decoration:
                    BoxDecoration(
                      color:
                      const Color(
                        0xFFF4F5F7,
                      ),
                      borderRadius:
                      BorderRadius
                          .circular(
                        14,
                      ),
                      border: Border.all(
                        color:
                        const Color(
                          0xFF00A8CC,
                        ),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.search,
                          color: Color(
                            0xFF00A8CC,
                          ),
                          size: 20,
                        ),

                        const SizedBox(
                          width: 10,
                        ),

                        Expanded(
                          child: TextField(
                            controller:
                            _searchController,
                            textInputAction:
                            TextInputAction
                                .search,
                            onSubmitted:
                                (_) {
                              _showEtiquette();
                            },
                            decoration:
                            InputDecoration(
                              hintText:
                              'e.g. Batu Caves, Masjid Jamek',
                              hintStyle:
                              TextStyle(
                                color: Colors
                                    .black
                                    .withValues(
                                  alpha:
                                  0.35,
                                ),
                                fontSize:
                                13,
                              ),
                              border:
                              InputBorder
                                  .none,
                              isCollapsed:
                              true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(
                    height: 14,
                  ),

                  // Search button
                  SizedBox(
                    width:
                    double.infinity,
                    height: 46,
                    child:
                    DecoratedBox(
                      decoration:
                      BoxDecoration(
                        borderRadius:
                        BorderRadius
                            .circular(
                          14,
                        ),
                        gradient:
                        const LinearGradient(
                          colors: [
                            Color(
                              0xFFF6B8A8,
                            ),
                            Color(
                              0xFFF2D26B,
                            ),
                          ],
                        ),
                      ),
                      child: TextButton(
                        onPressed:
                        _isSearching
                            ? null
                            : _showEtiquette,
                        style: TextButton
                            .styleFrom(
                          foregroundColor:
                          Colors.white,
                          disabledForegroundColor:
                          Colors.white,
                          shape:
                          RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius
                                .circular(
                              14,
                            ),
                          ),
                        ),
                        child:
                        _isSearching
                            ? const SizedBox(
                          width:
                          18,
                          height:
                          18,
                          child:
                          CircularProgressIndicator(
                            strokeWidth:
                            2,
                            color:
                            Colors
                                .white,
                          ),
                        )
                            : const Text(
                          'Show Me the Etiquette →',
                          style:
                          TextStyle(
                            color:
                            Colors
                                .white,
                            fontWeight:
                            FontWeight
                                .w700,
                            fontSize:
                            14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Thought bubble trail
          Positioned(
            left: 43,
            top: 270,
            child:
            _buildThoughtBubbleCircle(
              24,
            ),
          ),

          Positioned(
            left: 50,
            top: 310,
            child:
            _buildThoughtBubbleCircle(
              20,
            ),
          ),

          Positioned(
            left: 58,
            top: 348,
            child:
            _buildThoughtBubbleCircle(
              16,
            ),
          ),

          Positioned(
            left: 70,
            top: 380,
            child:
            _buildThoughtBubbleCircle(
              12,
            ),
          ),

          Positioned(
            left: 90,
            top: 410,
            child:
            _buildThoughtBubbleCircle(
              8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThoughtBubbleCircle(
      double size,
      ) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(
          0xFFFFFFFF,
        ),
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
    return Container(
      decoration:
      const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Color(
              0xFFE9E2D7,
            ),
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
                label: 'Home',
                selected: true,
              ),

              _navItem(
                icon: Icons
                    .explore_outlined,
                label: 'Explore',
                onTap:
                _openExplorePage,
              ),

              _navItem(
                icon: Icons
                    .checkroom_outlined,
                label: 'Outfit',
                onTap:
                _openOutfitPage,
              ),

              _navItem(

                icon: Icons.person_outline,

                label: 'Profile',

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
    final color =
    selected
        ? const Color(
      0xFF2864DE,
    )
        : const Color(
      0xFF1F3157,
    );

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