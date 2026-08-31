import 'package:flutter/material.dart';

import '../../view_model/home/home_view_model.dart';
import '../admin_home/admin_home.dart';
import '../etiquette_alert/etiquette_alert.dart';
import '../notification_inbox/notification_inbox.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final HomeViewModel _viewModel = HomeViewModel();

  final TextEditingController _searchController =
  TextEditingController();

  bool _isSearching = false;

  @override
  void initState() {
    super.initState();

    _viewModel.addListener(_onViewModelChanged);
    _viewModel.loadHomeData();
  }

  void _onViewModelChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _viewModel.dispose();
    _searchController.dispose();

    super.dispose();
  }

  Future<void> _showEtiquette() async {
    final query = _searchController.text.trim();

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
    await _viewModel.searchDestination(query);

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

    final attraction = results.first;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Found: ${attraction['name'] ?? 'Attraction'}',
        ),
      ),
    );

    // Later:
    // Navigate to attraction etiquette details.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9ED),

      body: SafeArea(
        child: ScrollConfiguration(
          behavior: const _NoScrollbarBehavior(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
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

                const SizedBox(height: 14),

                _buildHeroSection(),

                const SizedBox(height: 12),

                _buildQuickAccess(),

                const SizedBox(height: 10),
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
  // TOP HEADER
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
                    color: Color(0xFFFF4F73),
                  ),

                  SizedBox(width: 3),

                  Text(
                    'Kuala Lumpur, Malaysia',
                    style: TextStyle(
                      color: Color(0xFF0093A3),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 3),

              RichText(
                text: const TextSpan(
                  style: TextStyle(
                    fontSize: 17,
                    color: Color(0xFF14213D),
                    fontWeight: FontWeight.w800,
                  ),
                  children: [
                    TextSpan(
                      text: 'Good morning, Jay ',
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

        // Temporary Admin entry point (UC03) until a real role-based
        // navigation exists -- long-press opens Environment Parameters.
        GestureDetector(
          onLongPress: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const AdminHomeView(),
              ),
            );
          },
          child: Container(
            width: 34,
            height: 34,
            margin: const EdgeInsets.only(right: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFEFEFF4),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.settings_outlined,
              color: Color(0xFF667085),
              size: 18,
            ),
          ),
        ),

        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0xFFFFF0C9),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const NotificationInboxView(),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.notifications,
                  color: Color(0xFFFFA800),
                  size: 22,
                ),
              ),
            ),

            if (_viewModel.unreadNotificationCount > 0)
              Positioned(
                right: -1,
                top: -3,
                child: Container(
                  width: 17,
                  height: 17,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF4057),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    _viewModel.unreadNotificationCount > 9
                        ? '9+'
                        : '${_viewModel.unreadNotificationCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // =========================================================
  // BLUE HERO CARD
  // =========================================================

  Widget _buildHeroSection() {
    return Container(
      width: double.infinity,
      height: 515,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF08A8AD),
            Color(0xFF146BD9),
          ],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            _buildBackgroundDecoration(),

            Positioned(
              top: 14,
              left: 55,
              right: 22,
              child: _buildSearchCard(),
            ),

            const Positioned(
              left: 0,
              right: 0,
              bottom: 20,
              child: _TouristIllustration(),
            ),

            Positioned(
              bottom: 14,
              right: 16,
              child: Text(
                'CultureGuide',
                style: TextStyle(
                  color:
                  Colors.white.withValues(
                    alpha: 0.55,
                  ),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // SEARCH CARD
  // =========================================================

  Widget _buildSearchCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        15,
        15,
        15,
        14,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          const Text(
            'Where are you thinking of going?',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF071B54),
            ),
          ),

          const SizedBox(height: 5),

          const Text(
            "Tell me the destination and I'll give you the\ncultural etiquette.",
            style: TextStyle(
              fontSize: 10.5,
              height: 1.25,
              color: Color(0xFF667085),
            ),
          ),

          const SizedBox(height: 12),

          TextField(
            controller: _searchController,
            textInputAction:
            TextInputAction.search,
            onSubmitted: (_) {
              _showEtiquette();
            },
            decoration: InputDecoration(
              hintText:
              'e.g. Batu Caves, Masjid Jamek',
              hintStyle: const TextStyle(
                color: Color(0xFF9A9AB0),
                fontSize: 11,
              ),
              prefixIcon: const Icon(
                Icons.search,
                size: 19,
                color: Color(0xFF1491C4),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding:
              const EdgeInsets.symmetric(
                vertical: 11,
              ),
              enabledBorder:
              OutlineInputBorder(
                borderRadius:
                BorderRadius.circular(12),
                borderSide:
                const BorderSide(
                  color: Color(0xFFB5E7DD),
                ),
              ),
              focusedBorder:
              OutlineInputBorder(
                borderRadius:
                BorderRadius.circular(12),
                borderSide:
                const BorderSide(
                  color: Color(0xFF00A6A6),
                  width: 1.5,
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            height: 39,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius:
                BorderRadius.circular(12),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFFFBBAA),
                    Color(0xFFFFDB79),
                  ],
                ),
              ),
              child: ElevatedButton(
                onPressed:
                _isSearching
                    ? null
                    : _showEtiquette,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                  Colors.transparent,
                  shadowColor:
                  Colors.transparent,
                  foregroundColor:
                  Colors.white,
                  disabledBackgroundColor:
                  Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(12),
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
                    : const Text(
                  'Show Me the Etiquette →',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // DECORATIVE BACKGROUND
  // =========================================================

  Widget _buildBackgroundDecoration() {
    return Stack(
      children: [
        Positioned(
          left: -36,
          top: 155,
          child: Container(
            width: 105,
            height: 105,
            decoration: BoxDecoration(
              color:
              Colors.tealAccent.withValues(
                alpha: 0.13,
              ),
              shape: BoxShape.circle,
            ),
          ),
        ),

        Positioned(
          right: -38,
          bottom: 17,
          child: Container(
            width: 105,
            height: 105,
            decoration: BoxDecoration(
              border: Border.all(
                color:
                Colors.white.withValues(
                  alpha: 0.17,
                ),
              ),
              shape: BoxShape.circle,
            ),
          ),
        ),

        Positioned(
          right: -4,
          bottom: -4,
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              border: Border.all(
                color:
                Colors.white.withValues(
                  alpha: 0.10,
                ),
              ),
              shape: BoxShape.circle,
            ),
          ),
        ),

        _bubble(
          left: 63,
          top: 184,
          size: 8,
        ),

        _bubble(
          left: 66,
          top: 198,
          size: 7,
        ),

        _bubble(
          right: 60,
          top: 179,
          size: 7,
        ),

        _bubble(
          right: 27,
          top: 229,
          size: 4,
        ),

        _bubble(
          right: 58,
          top: 332,
          size: 7,
        ),

        _bubble(
          right: 112,
          top: 314,
          size: 5,
        ),

        _bubble(
          right: 119,
          top: 322,
          size: 4,
        ),

        _bubble(
          right: 126,
          top: 331,
          size: 4,
        ),
      ],
    );
  }

  Widget _bubble({
    double? left,
    double? right,
    required double top,
    required double size,
  }) {
    return Positioned(
      left: left,
      right: right,
      top: top,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withValues(
            alpha: 0.35,
          ),
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  // =========================================================
  // QUICK ACCESS BUTTONS
  // =========================================================

  Widget _buildQuickAccess() {
    return SizedBox(
      height: 36,
      child: Row(
        children: [
          Expanded(
            child: _quickAccessButton(
              icon:
              Icons.menu_book_outlined,
              text: 'Etiquette Guide',
              background:
              const Color(0xFFDDFDF5),
              foreground:
              const Color(0xFF009F8C),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const EtiquetteAlertView(),
                  ),
                );
              },
            ),
          ),

          const SizedBox(width: 7),

          Expanded(
            child: _quickAccessButton(
              icon:
              Icons.checkroom_outlined,
              text: 'Check Outfit',
              background:
              const Color(0xFFE9ECFF),
              foreground:
              const Color(0xFF315CD6),
              onTap: () {
                // Outfit Recognition page later.
              },
            ),
          ),

          const SizedBox(width: 7),

          Expanded(
            child: _quickAccessButton(
              icon:
              Icons.map_outlined,
              text: 'Explore Map',
              background:
              const Color(0xFFFFF2C7),
              foreground:
              const Color(0xFFE69B00),
              onTap: () {
                // Cultural Map page later.
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickAccessButton({
    required IconData icon,
    required String text,
    required Color background,
    required Color foreground,
    required VoidCallback onTap,
  }) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 7,
          ),
          child: Row(
            mainAxisAlignment:
            MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 13,
                color: foreground,
              ),

              const SizedBox(width: 4),

              Flexible(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow:
                  TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9.5,
                    color: foreground,
                    fontWeight:
                    FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================
  // BOTTOM NAVIGATION
  // =========================================================

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Color(0xFFE9E2D7),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 59,
          child: Row(
            mainAxisAlignment:
            MainAxisAlignment.spaceAround,
            children: [
              _navItem(
                icon: Icons.home_rounded,
                label: 'Home',
                selected: true,
              ),
              _navItem(
                icon:
                Icons.explore_outlined,
                label: 'Explore',
              ),
              _navItem(
                icon:
                Icons.checkroom_outlined,
                label: 'Outfit',
              ),
              _navItem(
                icon:
                Icons.person_outline,
                label: 'Profile',
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
  }) {
    final color = selected
        ? const Color(0xFF2864DE)
        : const Color(0xFF1F3157);

    return InkWell(
      onTap: () {
        // Navigation will be connected later.
      },
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
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 9.5,
                fontWeight: selected
                    ? FontWeight.w700
                    : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================
// SIMPLE TOURIST ILLUSTRATION
// No external image asset required.
// ===========================================================

class _TouristIllustration
    extends StatelessWidget {
  const _TouristIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 205,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            bottom: 2,
            child: Container(
              width: 68,
              height: 10,
              decoration: BoxDecoration(
                color: const Color(
                  0xFF074AA6,
                ).withValues(
                  alpha: 0.6,
                ),
                borderRadius:
                BorderRadius.circular(50),
              ),
            ),
          ),

          Positioned(
            bottom: 17,
            child: Row(
              children: [
                _leg(),
                const SizedBox(width: 8),
                _leg(),
              ],
            ),
          ),

          Positioned(
            bottom: 73,
            child: Container(
              width: 74,
              height: 68,
              decoration: BoxDecoration(
                color:
                const Color(0xFF02A7A6),
                borderRadius:
                BorderRadius.circular(8),
              ),
            ),
          ),

          Positioned(
            bottom: 130,
            child: Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: Color(0xFFFFDA65),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text(
                  '😊',
                  style:
                  TextStyle(fontSize: 23),
                ),
              ),
            ),
          ),

          Positioned(
            bottom: 165,
            child: Container(
              width: 42,
              height: 11,
              decoration: BoxDecoration(
                color:
                const Color(0xFF14213D),
                borderRadius:
                BorderRadius.circular(50),
              ),
            ),
          ),

          Positioned(
            bottom: 168,
            child: Container(
              width: 35,
              height: 9,
              decoration: BoxDecoration(
                color:
                const Color(0xFFF5C85C),
                borderRadius:
                BorderRadius.circular(50),
              ),
            ),
          ),

          Positioned(
            left:
            MediaQuery.sizeOf(context)
                .width /
                2 -
                58,
            bottom: 80,
            child: Container(
              width: 12,
              height: 40,
              decoration: BoxDecoration(
                color:
                const Color(0xFF00AFA8),
                borderRadius:
                BorderRadius.circular(10),
              ),
            ),
          ),

          Positioned(
            right:
            MediaQuery.sizeOf(context)
                .width /
                2 -
                77,
            bottom: 88,
            child: Container(
              width: 24,
              height: 34,
              decoration: BoxDecoration(
                color:
                const Color(0xFFFFA600),
                borderRadius:
                BorderRadius.circular(8),
              ),
              child: Center(
                child: Container(
                  width: 13,
                  height: 18,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color:
                      const Color(
                        0xFFFFC94A,
                      ),
                      width: 2,
                    ),
                    borderRadius:
                    BorderRadius.circular(
                      4,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _leg() {
    return Column(
      children: [
        Container(
          width: 13,
          height: 58,
          decoration: BoxDecoration(
            color:
            const Color(0xFF165DD1),
            borderRadius:
            BorderRadius.circular(5),
          ),
        ),
        Container(
          width: 27,
          height: 10,
          decoration: BoxDecoration(
            color:
            const Color(0xFF14213D),
            borderRadius:
            BorderRadius.circular(10),
          ),
        ),
      ],
    );
  }
}

// Completely removes desktop/web scrollbar.
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