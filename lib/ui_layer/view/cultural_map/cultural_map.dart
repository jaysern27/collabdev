import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../../external_data_sources/google_maps/google_maps_data_source.dart';
import '../../../data_layer/model/repositories/ranking_report/ranking_report_repository.dart';
import '../../view_model/cultural_map/cultural_map_view_model.dart';

class CulturalMapView extends StatefulWidget {
  final Map<String, dynamic>? initialAttraction;

  const CulturalMapView({
    super.key,
    this.initialAttraction,
  });

  @override
  State<CulturalMapView> createState() =>
      _CulturalMapViewState();
}

class _CulturalMapViewState
    extends State<CulturalMapView> {
  late final CulturalMapViewModel _viewModel;

  final GoogleMapsDataSource _googleMapsDataSource =
  GoogleMapsDataSource();

  final RankingReportRepository _rankingRepository =
  RankingReportRepository();

  final TextEditingController _searchController =
  TextEditingController();

  GoogleMapController? _mapController;

  bool _viewModelReady = false;
  bool _initialAttractionHandled = false;

  @override
  void initState() {
    super.initState();

    _viewModel =
        CulturalMapViewModel();

    WidgetsBinding.instance.addPostFrameCallback(
          (_) async {
        await _viewModel.initialise();

        if (!mounted) {
          return;
        }

        _viewModelReady = true;

        if (widget.initialAttraction != null) {
          await _focusInitialAttractionIfReady();
        } else {
          await _moveMapToCurrentArea();
        }
      },
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _searchController.dispose();
    _viewModel.dispose();

    super.dispose();
  }

  Future<void> _moveMapToCurrentArea() async {
    final controller =
        _mapController;

    if (controller == null) {
      return;
    }

    await _googleMapsDataSource.moveCamera(
      controller: controller,
      latitude:
      _viewModel.currentLatitude,
      longitude:
      _viewModel.currentLongitude,
      zoom: 13,
    );
  }

  Future<void> _focusInitialAttractionIfReady() async {
    if (_initialAttractionHandled ||
        !_viewModelReady ||
        _mapController == null) {
      return;
    }

    final attraction =
        widget.initialAttraction;

    if (attraction == null) {
      return;
    }

    final latitude =
    _viewModel.attractionLatitude(
      attraction,
    );

    final longitude =
    _viewModel.attractionLongitude(
      attraction,
    );

    if (latitude == null ||
        longitude == null) {
      _initialAttractionHandled = true;
      return;
    }

    // Mark before awaiting so initState and onMapCreated cannot open
    // the same attraction twice.
    _initialAttractionHandled = true;

    final name =
    _viewModel.attractionName(
      attraction,
    );

    _searchController.text =
        name;

    _viewModel.setSearchQuery(
      name,
    );

    _viewModel.selectAttraction(
      attraction,
    );

    await _googleMapsDataSource.moveCamera(
      controller:
      _mapController!,
      latitude:
      latitude,
      longitude:
      longitude,
      zoom:
      16,
    );

    if (!mounted) {
      return;
    }

    // Give the Google Map a short moment to finish its camera move,
    // then immediately show the selected place.
    await Future<void>.delayed(
      const Duration(
        milliseconds: 250,
      ),
    );

    if (!mounted) {
      return;
    }

    await _showAttractionDetails(
      attraction,
    );
  }

  Future<void> _refreshLocation() async {
    await _viewModel
        .refreshCurrentLocation();

    await _moveMapToCurrentArea();

    if (!mounted) {
      return;
    }

    final message =
    _viewModel.usingDefaultArea
        ? 'Current location unavailable. Showing Kuala Lumpur pilot area.'
        : 'Map centred on your current location.';

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
  }

  // ============================================================
  // MARKERS
  // ============================================================

  Set<Marker> _buildMarkers(
      CulturalMapViewModel viewModel,
      ) {
    final markers =
    <Marker>{};

    for (final attraction
    in viewModel.visibleAttractions) {
      final latitude =
      viewModel.attractionLatitude(
        attraction,
      );

      final longitude =
      viewModel.attractionLongitude(
        attraction,
      );

      if (latitude == null ||
          longitude == null) {
        continue;
      }

      final id =
          attraction['id']
              ?.toString()
              .trim() ??
              '${latitude}_$longitude';

      markers.add(
        Marker(
          markerId:
          MarkerId(id),
          position:
          LatLng(
            latitude,
            longitude,
          ),
          infoWindow:
          InfoWindow(
            title:
            viewModel.attractionName(
              attraction,
            ),
            snippet:
            viewModel.attractionCategory(
              attraction,
            ),
          ),
          onTap: () {
            viewModel.selectAttraction(
              attraction,
            );

            _showAttractionDetails(
              attraction,
            );
          },
        ),
      );
    }

    return markers;
  }

  // ============================================================
  // SIGN IN DIALOG
  // ============================================================

  Future<void> _showSignInRequiredDialog(
      String message,
      ) async {
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (
          dialogContext,
          ) {
        return AlertDialog(
          icon:
          const Icon(
            Icons.login,
            size: 36,
          ),
          title:
          const Text(
            'Sign In Required',
          ),
          content:
          Text(
            message,
            textAlign:
            TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop();
              },
              child:
              const Text(
                'OK',
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // FAVOURITE
  // ============================================================

  Future<void> _toggleFavourite(
      Map<String, dynamic> attraction,
      ) async {
    if (!_viewModel.isLoggedIn) {
      await _showSignInRequiredDialog(
        'Please sign in to save favourites.',
      );

      return;
    }

    final attractionId =
        attraction['id']
            ?.toString()
            .trim() ??
            '';

    final wasFavourite =
    _viewModel.isFavourite(
      attractionId,
    );

    final success =
    await _viewModel.toggleFavourite(
      attraction,
    );

    if (!mounted) {
      return;
    }

    final message =
    success
        ? wasFavourite
        ? 'Removed from favourites.'
        : 'Saved to favourites.'
        : _viewModel.errorMessage ??
        'Unable to update favourite.';

    if (!success) {
      _viewModel.clearError();
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content:
          Text(message),
        ),
      );
  }

  // ============================================================
  // VISIT LIST
  // ============================================================

  Future<void> _toggleVisitList(
      Map<String, dynamic> attraction,
      ) async {
    if (!_viewModel.isLoggedIn) {
      await _showSignInRequiredDialog(
        'Please sign in to use the visit list.',
      );

      return;
    }

    final attractionId =
        attraction['id']
            ?.toString()
            .trim() ??
            '';

    final wasInVisitList =
    _viewModel.isInVisitList(
      attractionId,
    );

    final success =
    await _viewModel.toggleVisitList(
      attraction,
    );

    if (!mounted) {
      return;
    }

    final message =
    success
        ? wasInVisitList
        ? 'Removed from visit list.'
        : 'Added to visit list.'
        : _viewModel.errorMessage ??
        'Unable to update visit list.';

    if (!success) {
      _viewModel.clearError();
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content:
          Text(message),
        ),
      );
  }

  // ============================================================
  // GOOGLE MAP ETIQUETTE RANKING
  // ============================================================

  /// Loads the COMPLETE ranked DO/DON'T guide for the selected place.
  ///
  /// Every attraction always has a default ranking:
  /// - DO: follows the attraction's default DO order.
  /// - DON'T: follows the attraction's default DON'T order.
  ///
  /// After Admin approves reports for THIS attraction, only this
  /// attraction's matching DON'T rules are reprioritised.
  ///
  /// The map preview displays only rank #1, #2 and #3.
  /// The full guide displays every ranked rule.
  Future<Map<String, List<Map<String, dynamic>>>>
  _loadRankedEtiquetteForAttraction({
    required String attractionId,
    required List<String> dos,
    required List<String> donts,
  }) async {
    if (attractionId.isNotEmpty) {
      try {
        final ranked =
        await _rankingRepository
            .getEtiquetteGuideRankingByAttraction(
          attractionId,
        );

        if ((ranked['dos']?.isNotEmpty ?? false) ||
            (ranked['donts']?.isNotEmpty ?? false)) {
          return ranked;
        }
      } catch (_) {
        // Fall through to deterministic default ranking.
      }
    }

    return {
      'dos': [
        for (var i = 0;
        i < dos.length;
        i++)
          {
            'ruleId': 'do_${i + 1}',
            'ruleName': dos[i],
            'defaultRank': i + 1,
            'rank': i + 1,
            'frequency': 0,
            'hasApprovedReports': false,
            'source': 'default-do-ranking',
          },
      ],
      'donts': [
        for (var i = 0;
        i < donts.length;
        i++)
          {
            'ruleId': 'dont_${i + 1}',
            'ruleName': donts[i],
            'defaultRank': i + 1,
            'rank': i + 1,
            'frequency': 0,
            'hasApprovedReports': false,
            'source': 'default-dont-ranking',
          },
      ],
    };
  }

  // ============================================================
  // FULL ETIQUETTE PAGE
  // ============================================================

  void _openFullEtiquetteGuide(
      Map<String, dynamic> attraction, {
        required List<Map<String, dynamic>> rankedDos,
        required List<Map<String, dynamic>> rankedDonts,
      }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            _FullEtiquetteGuidePage(
              name:
              _viewModel.attractionName(
                attraction,
              ),
              category:
              _viewModel.attractionCategory(
                attraction,
              ),
              dos: rankedDos,
              donts: rankedDonts,
            ),
      ),
    );
  }

  // ============================================================
  // ATTRACTION DETAILS
  // ============================================================

  Future<void> _showAttractionDetails(
      Map<String, dynamic> attraction,
      ) async {
    final name =
    _viewModel.attractionName(
      attraction,
    );

    final category =
    _viewModel.attractionCategory(
      attraction,
    );

    final imageUrl =
    _viewModel.attractionImageUrl(
      attraction,
    );

    final latitude =
    _viewModel.attractionLatitude(
      attraction,
    );

    final longitude =
    _viewModel.attractionLongitude(
      attraction,
    );

    final status =
    _viewModel.attractionStatus(
      attraction,
    );

    final rating =
    _viewModel.attractionRatingText(
      attraction,
    );

    final dos =
    _viewModel.attractionDos(
      attraction,
    );

    final donts =
    _viewModel.attractionDonts(
      attraction,
    );

    final activities =
    _viewModel.attractionActivities(
      attraction,
    );

    final attractionId =
        attraction['id']
            ?.toString()
            .trim() ??
            '';

    // Load the COMPLETE per-place ranking first.
    //
    // DO:
    //   default rank for every rule.
    //
    // DON'T:
    //   default rank for every rule, dynamically reprioritised only by
    //   Admin-approved reports belonging to THIS attraction.
    final rankedEtiquette =
    await _loadRankedEtiquetteForAttraction(
      attractionId: attractionId,
      dos: dos,
      donts: donts,
    );

    final rankedDos =
        rankedEtiquette['dos'] ??
            <Map<String, dynamic>>[];

    final rankedDonts =
        rankedEtiquette['donts'] ??
            <Map<String, dynamic>>[];

    final previewDos =
    rankedDos.take(3).toList();

    final previewDonts =
    rankedDonts.take(3).toList();

    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor:
      const Color(0xFFFFFBF5),
      builder: (
          sheetContext,
          ) {
        return AnimatedBuilder(
          animation:
          _viewModel,
          builder: (
              context,
              child,
              ) {
            final isFavourite =
                attractionId.isNotEmpty &&
                    _viewModel.isFavourite(
                      attractionId,
                    );

            final isInVisitList =
                attractionId.isNotEmpty &&
                    _viewModel.isInVisitList(
                      attractionId,
                    );

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.92,
              minChildSize: 0.65,
              maxChildSize: 0.97,
              builder: (
                  context,
                  scrollController,
                  ) {
                return SingleChildScrollView(
                  controller:
                  scrollController,
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      // ==================================================
                      // TOP IMAGE
                      // ==================================================

                      Stack(
                        children: [
                          if (imageUrl != null)
                            Image.network(
                              imageUrl,
                              width:
                              double.infinity,
                              height: 190,
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (
                                  context,
                                  error,
                                  stackTrace,
                                  ) {
                                return _buildHeroPlaceholder();
                              },
                            )
                          else
                            _buildHeroPlaceholder(),

                          Positioned(
                            top: 12,
                            left: 16,
                            child: SafeArea(
                              child: CircleAvatar(
                                backgroundColor:
                                Colors.white,
                                child: IconButton(
                                  icon:
                                  const Icon(
                                    Icons.arrow_back,
                                  ),
                                  onPressed: () {
                                    Navigator.of(
                                      sheetContext,
                                    ).pop();
                                  },
                                ),
                              ),
                            ),
                          ),

                          Positioned(
                            bottom: 14,
                            left: 18,
                            child: Container(
                              padding:
                              const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration:
                              BoxDecoration(
                                color:
                                Colors.black54,
                                borderRadius:
                                BorderRadius.circular(
                                  20,
                                ),
                              ),
                              child: Text(
                                category,
                                style:
                                const TextStyle(
                                  color:
                                  Colors.white,
                                  fontSize: 12,
                                  fontWeight:
                                  FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      Padding(
                        padding:
                        const EdgeInsets.fromLTRB(
                          18,
                          18,
                          18,
                          30,
                        ),
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            // ============================================
                            // NAME
                            // ============================================

                            Text(
                              name,
                              style:
                              const TextStyle(
                                fontSize: 24,
                                fontWeight:
                                FontWeight.bold,
                                color:
                                Color(0xFF14213D),
                              ),
                            ),

                            const SizedBox(
                              height: 18,
                            ),

                            // ============================================
                            // DISTANCE / STATUS / RATING
                            // ============================================

                            Container(
                              padding:
                              const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                              decoration:
                              BoxDecoration(
                                color:
                                Colors.white,
                                borderRadius:
                                BorderRadius.circular(
                                  14,
                                ),
                                border:
                                Border.all(
                                  color:
                                  Colors.grey.shade200,
                                ),
                              ),
                              child:
                              IntrinsicHeight(
                                child: Row(
                                  children: [
                                    Expanded(
                                      child:
                                      _buildMetric(
                                        'Distance',
                                        _viewModel
                                            .distanceTextFor(
                                          attraction,
                                        ),
                                        const Color(
                                          0xFF2864DE,
                                        ),
                                      ),
                                    ),

                                    const VerticalDivider(),

                                    Expanded(
                                      child:
                                      _buildMetric(
                                        'Status',
                                        status,
                                        _viewModel
                                            .attractionIsOpen(
                                          attraction,
                                        )
                                            ? Colors.green
                                            : Colors.orange,
                                      ),
                                    ),

                                    const VerticalDivider(),

                                    Expanded(
                                      child:
                                      Column(
                                        children: [
                                          Text(
                                            'Rating',
                                            style:
                                            TextStyle(
                                              color:
                                              Colors.grey.shade600,
                                              fontSize: 11,
                                            ),
                                          ),
                                          const SizedBox(
                                            height: 5,
                                          ),
                                          Row(
                                            mainAxisAlignment:
                                            MainAxisAlignment.center,
                                            children: [
                                              const Icon(
                                                Icons.star,
                                                color:
                                                Colors.amber,
                                                size: 18,
                                              ),
                                              const SizedBox(
                                                width: 3,
                                              ),
                                              Text(
                                                rating,
                                                style:
                                                const TextStyle(
                                                  fontWeight:
                                                  FontWeight.bold,
                                                  color:
                                                  Color(0xFF14213D),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(
                              height: 20,
                            ),

                            // ============================================
                            // KNOW BEFORE YOU ENTER
                            // ============================================

                            Container(
                              width:
                              double.infinity,
                              decoration:
                              BoxDecoration(
                                color:
                                Colors.white,
                                borderRadius:
                                BorderRadius.circular(
                                  16,
                                ),
                                border:
                                Border.all(
                                  color:
                                  const Color(0xFF18B6C9),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width:
                                    double.infinity,
                                    padding:
                                    const EdgeInsets.all(
                                      14,
                                    ),
                                    decoration:
                                    const BoxDecoration(
                                      gradient:
                                      LinearGradient(
                                        colors: [
                                          Color(
                                            0xFF1CB7AE,
                                          ),
                                          Color(
                                            0xFF2864DE,
                                          ),
                                        ],
                                      ),
                                      borderRadius:
                                      BorderRadius.vertical(
                                        top:
                                        Radius.circular(
                                          15,
                                        ),
                                      ),
                                    ),
                                    child:
                                    Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        const Row(
                                          children: [
                                            Text(
                                              '🙏',
                                              style:
                                              TextStyle(
                                                fontSize: 20,
                                              ),
                                            ),
                                            SizedBox(
                                              width: 8,
                                            ),
                                            Text(
                                              'Know Before You Enter',
                                              style:
                                              TextStyle(
                                                color:
                                                Colors.white,
                                                fontWeight:
                                                FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(
                                          height: 3,
                                        ),
                                        Text(
                                          'Essential etiquette for $name',
                                          style:
                                          const TextStyle(
                                            color:
                                            Colors.white,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  Padding(
                                    padding:
                                    const EdgeInsets.all(
                                      14,
                                    ),
                                    child:
                                    Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          '✅ DO',
                                          style:
                                          TextStyle(
                                            color:
                                            Colors.green,
                                            fontWeight:
                                            FontWeight.bold,
                                          ),
                                        ),

                                        const SizedBox(
                                          height: 8,
                                        ),

                                        if (previewDos.isEmpty)
                                          const Text(
                                            'No specific DO guidance available.',
                                          )
                                        else
                                          ...previewDos.map(
                                                (item) =>
                                                _buildRankedRuleItem(
                                                  rank:
                                                  _rankValue(item),
                                                  text:
                                                  item['ruleName']?.toString() ??
                                                      'Etiquette rule',
                                                  color:
                                                  Colors.green,
                                                ),
                                          ),

                                        const Divider(
                                          height: 28,
                                        ),

                                        const Text(
                                          "❌ DON'T",
                                          style:
                                          TextStyle(
                                            color:
                                            Colors.red,
                                            fontWeight:
                                            FontWeight.bold,
                                          ),
                                        ),

                                        const SizedBox(
                                          height: 8,
                                        ),

                                        if (previewDonts.isEmpty)
                                          const Text(
                                            "No specific DON'T guidance available.",
                                          )
                                        else
                                          ...previewDonts.map(
                                                (item) =>
                                                _buildRankedRuleItem(
                                                  rank:
                                                  _rankValue(item),
                                                  text:
                                                  item['ruleName']?.toString() ??
                                                      'Etiquette rule',
                                                  color:
                                                  Colors.red,
                                                ),
                                          ),

                                        const SizedBox(
                                          height: 10,
                                        ),

                                        Text(
                                          'Top 3 ranked etiquette rules for this place. Approved reports can reprioritise the DON\'T ranking. Open the full guide to see all rules.',
                                          style:
                                          TextStyle(
                                            color:
                                            Colors.grey.shade600,
                                            fontSize: 10.5,
                                            height: 1.35,
                                          ),
                                        ),

                                        const SizedBox(
                                          height: 12,
                                        ),

                                        SizedBox(
                                          width:
                                          double.infinity,
                                          child:
                                          FilledButton.icon(
                                            onPressed: () {
                                              _openFullEtiquetteGuide(
                                                attraction,
                                                rankedDos:
                                                rankedDos,
                                                rankedDonts:
                                                rankedDonts,
                                              );
                                            },
                                            icon:
                                            const Icon(
                                              Icons.menu_book_outlined,
                                            ),
                                            label:
                                            const Text(
                                              'View Full Etiquette Guide',
                                            ),
                                            style:
                                            FilledButton.styleFrom(
                                              padding:
                                              const EdgeInsets.symmetric(
                                                vertical: 13,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(
                              height: 18,
                            ),

                            // ============================================
                            // WHAT YOU CAN DO HERE
                            // ============================================

                            Container(
                              width:
                              double.infinity,
                              decoration:
                              BoxDecoration(
                                color:
                                Colors.white,
                                borderRadius:
                                BorderRadius.circular(
                                  16,
                                ),
                                border:
                                Border.all(
                                  color:
                                  Colors.teal.shade100,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    width:
                                    double.infinity,
                                    padding:
                                    const EdgeInsets.all(
                                      14,
                                    ),
                                    decoration:
                                    BoxDecoration(
                                      color:
                                      Colors.teal.shade50,
                                      borderRadius:
                                      const BorderRadius.vertical(
                                        top:
                                        Radius.circular(
                                          15,
                                        ),
                                      ),
                                    ),
                                    child:
                                    const Row(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.check_box,
                                          color:
                                          Colors.green,
                                          size: 20,
                                        ),
                                        SizedBox(
                                          width: 8,
                                        ),
                                        Expanded(
                                          child:
                                          Column(
                                            crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'What You Can Do Here',
                                                style:
                                                TextStyle(
                                                  color:
                                                  Color(0xFF00796B),
                                                  fontWeight:
                                                  FontWeight.bold,
                                                ),
                                              ),
                                              Text(
                                                'Tourist-friendly activities at this cultural attraction',
                                                style:
                                                TextStyle(
                                                  color:
                                                  Color(0xFF00796B),
                                                  fontSize:
                                                  11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  if (activities.isEmpty)
                                    const Padding(
                                      padding:
                                      EdgeInsets.all(
                                        16,
                                      ),
                                      child:
                                      Text(
                                        'Activity information is not available yet.',
                                      ),
                                    )
                                  else
                                    ...activities.asMap().entries.map(
                                          (
                                          entry,
                                          ) {
                                        final index =
                                            entry.key;

                                        final activity =
                                            entry.value;

                                        return _buildActivityItem(
                                          index:
                                          index,
                                          title:
                                          activity['title'] ??
                                              '',
                                          description:
                                          activity['description'] ??
                                              '',
                                        );
                                      },
                                    ),
                                ],
                              ),
                            ),

                            const SizedBox(
                              height: 18,
                            ),

                            // ============================================
                            // ABOUT
                            // ============================================

                            _buildInfoCard(
                              icon:
                              Icons.info_outline,
                              title:
                              'About',
                              content:
                              _viewModel.attractionDescription(
                                attraction,
                              ),
                            ),

                            const SizedBox(
                              height: 10,
                            ),

                            _buildInfoCard(
                              icon:
                              Icons.location_on_outlined,
                              title:
                              'Location',
                              content:
                              _viewModel.attractionAddress(
                                attraction,
                              ),
                            ),

                            const SizedBox(
                              height: 10,
                            ),

                            _buildInfoCard(
                              icon:
                              Icons.schedule_outlined,
                              title:
                              'Opening Information',
                              content:
                              _viewModel
                                  .attractionOpeningInformation(
                                attraction,
                              ),
                            ),

                            const SizedBox(
                              height: 18,
                            ),

                            // ============================================
                            // LOGIN MESSAGE
                            // ============================================

                            if (!_viewModel.isLoggedIn)
                              Container(
                                width:
                                double.infinity,
                                padding:
                                const EdgeInsets.all(
                                  12,
                                ),
                                margin:
                                const EdgeInsets.only(
                                  bottom: 12,
                                ),
                                decoration:
                                BoxDecoration(
                                  color:
                                  Colors.blueGrey.shade50,
                                  borderRadius:
                                  BorderRadius.circular(
                                    12,
                                  ),
                                  border:
                                  Border.all(
                                    color:
                                    Colors.blueGrey.shade100,
                                  ),
                                ),
                                child:
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                    ),
                                    SizedBox(
                                      width: 10,
                                    ),
                                    Expanded(
                                      child:
                                      Text(
                                        'Sign in to save this attraction to your Favourites or Visit List.',
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // ============================================
                            // FAVOURITE
                            // ============================================

                            SizedBox(
                              width:
                              double.infinity,
                              child:
                              OutlinedButton.icon(
                                onPressed:
                                _viewModel.isSavingAttraction
                                    ? null
                                    : () async {
                                  await _toggleFavourite(
                                    attraction,
                                  );
                                },
                                icon:
                                Icon(
                                  isFavourite
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                ),
                                label:
                                Text(
                                  isFavourite
                                      ? 'Remove from Favourites'
                                      : 'Save to Favourites',
                                ),
                              ),
                            ),

                            const SizedBox(
                              height: 10,
                            ),

                            // ============================================
                            // VISIT LIST
                            // ============================================

                            SizedBox(
                              width:
                              double.infinity,
                              child:
                              OutlinedButton.icon(
                                onPressed:
                                _viewModel.isSavingAttraction
                                    ? null
                                    : () async {
                                  await _toggleVisitList(
                                    attraction,
                                  );
                                },
                                icon:
                                Icon(
                                  isInVisitList
                                      ? Icons.bookmark_added
                                      : Icons.bookmark_add_outlined,
                                ),
                                label:
                                Text(
                                  isInVisitList
                                      ? 'Remove from Visit List'
                                      : 'Add to Visit List',
                                ),
                              ),
                            ),

                            const SizedBox(
                              height: 10,
                            ),

                            // ============================================
                            // DIRECTIONS
                            // ============================================

                            SizedBox(
                              width:
                              double.infinity,
                              child:
                              FilledButton.icon(
                                onPressed:
                                latitude == null ||
                                    longitude == null
                                    ? null
                                    : () async {
                                  try {
                                    await _googleMapsDataSource
                                        .openDirections(
                                      latitude:
                                      latitude,
                                      longitude:
                                      longitude,
                                    );
                                  } catch (_) {
                                    if (!mounted) {
                                      return;
                                    }

                                    ScaffoldMessenger.of(
                                      this.context,
                                    )
                                      ..hideCurrentSnackBar()
                                      ..showSnackBar(
                                        const SnackBar(
                                          content:
                                          Text(
                                            'Unable to open directions.',
                                          ),
                                        ),
                                      );
                                  }
                                },
                                icon:
                                const Icon(
                                  Icons.directions,
                                ),
                                label:
                                const Text(
                                  'Directions',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );

    _viewModel
        .clearSelectedAttraction();
  }

  // ============================================================
  // SMALL UI COMPONENTS
  // ============================================================

  Widget _buildHeroPlaceholder() {
    return Container(
      width:
      double.infinity,
      height: 190,
      color:
      const Color(0xFFEDEDED),
      child:
      const Column(
        mainAxisAlignment:
        MainAxisAlignment.center,
        children: [
          Icon(
            Icons.temple_buddhist_outlined,
            size: 58,
          ),
          SizedBox(
            height: 8,
          ),
          Text(
            'Cultural Attraction',
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(
      String title,
      String value,
      Color valueColor,
      ) {
    return Column(
      children: [
        Text(
          title,
          style:
          TextStyle(
            color:
            Colors.grey.shade600,
            fontSize: 11,
          ),
        ),
        const SizedBox(
          height: 5,
        ),
        Text(
          value,
          textAlign:
          TextAlign.center,
          style:
          TextStyle(
            color:
            valueColor,
            fontWeight:
            FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  int _rankValue(
      Map<String, dynamic> item,
      ) {
    final value =
    item['rank'];

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
      value?.toString() ?? '',
    ) ??
        0;
  }

  Widget _buildRankedRuleItem({
    required int rank,
    required String text,
    required Color color,
  }) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Padding(
      padding:
      const EdgeInsets.only(
        bottom: 11,
      ),
      child:
      Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment:
            Alignment.center,
            decoration:
            BoxDecoration(
              color:
              color.withValues(
                alpha: 0.11,
              ),
              borderRadius:
              BorderRadius.circular(
                10,
              ),
            ),
            child:
            Text(
              '$rank',
              style:
              TextStyle(
                color:
                color,
                fontSize: 12,
                fontWeight:
                FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(
            width: 10,
          ),
          Expanded(
            child:
            Text(
              text,
              style:
              TextStyle(
                color:
                colorScheme.onSurface,
                height: 1.38,
                fontSize: 13.2,
                fontWeight:
                FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildActivityItem({
    required int index,
    required String title,
    required String description,
  }) {
    final colorScheme =
        Theme.of(context).colorScheme;

    final icons = <IconData>[
      Icons.account_balance_outlined,
      Icons.self_improvement_rounded,
      Icons.photo_camera_outlined,
      Icons.history_edu_outlined,
    ];

    final icon =
    icons[index % icons.length];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 13,
      ),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color:
              colorScheme.secondaryContainer,
              borderRadius:
              BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 20,
              color:
              colorScheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(
                    fontWeight:
                    FontWeight.w700,
                  ),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                      color: colorScheme
                          .onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String content,
  }) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color:
        colorScheme.surfaceContainerLow,
        borderRadius:
        BorderRadius.circular(16),
        border: Border.all(
          color:
          colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color:
              colorScheme.primaryContainer,
              borderRadius:
              BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 20,
              color:
              colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(
                    fontWeight:
                    FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                    color: colorScheme
                        .onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MAIN PAGE
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<CulturalMapViewModel>.value(
      value: _viewModel,
      child: Consumer<CulturalMapViewModel>(
        builder: (context, viewModel, child) {
          final colorScheme = Theme.of(context).colorScheme;

          return Scaffold(
            backgroundColor: colorScheme.surface,
            appBar: AppBar(
              backgroundColor: colorScheme.surface,
              surfaceTintColor: Colors.transparent,
              title: const Text(
                'Cultural Map',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              actions: [
                IconButton(
                  tooltip: 'Refresh attractions',
                  onPressed: viewModel.isLoading
                      ? null
                      : () async {
                    await viewModel.refreshAttractions();
                  },
                  icon: const Icon(Icons.refresh_rounded),
                ),
                const SizedBox(width: 4),
              ],
            ),
            body: Stack(
              children: [
                Positioned.fill(
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(
                        viewModel.currentLatitude,
                        viewModel.currentLongitude,
                      ),
                      zoom: 13,
                    ),
                    markers: _buildMarkers(viewModel),
                    myLocationEnabled: viewModel.locationAvailable,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    onMapCreated: (controller) async {
                      _mapController = controller;

                      if (widget.initialAttraction != null) {
                        await _focusInitialAttractionIfReady();
                      } else {
                        await _moveMapToCurrentArea();
                      }
                    },
                  ),
                ),

                Positioned(
                  top: 12,
                  left: 14,
                  right: 14,
                  child: _buildMapSearchCard(viewModel),
                ),

                Positioned(
                  top: 92,
                  right: 16,
                  child: Material(
                    color: colorScheme.surface,
                    elevation: 3,
                    shadowColor:
                    colorScheme.shadow.withValues(alpha: 0.16),
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: 'My Location',
                      onPressed:
                      viewModel.isLocating ? null : _refreshLocation,
                      icon: viewModel.isLocating
                          ? const SizedBox(
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                          : const Icon(Icons.my_location_rounded),
                    ),
                  ),
                ),

                DraggableScrollableSheet(
                  initialChildSize: 0.34,
                  minChildSize: 0.18,
                  maxChildSize: 0.88,
                  snap: true,
                  snapSizes: const [0.18, 0.34, 0.88],
                  builder: (context, scrollController) {
                    return _buildMapResultsSheet(
                      viewModel: viewModel,
                      scrollController: scrollController,
                    );
                  },
                ),

                if (viewModel.isLoading)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        color:
                        colorScheme.scrim.withValues(alpha: 0.08),
                        alignment: Alignment.center,
                        child: Card(
                          elevation: 0,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Loading cultural places...',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMapSearchCard(CulturalMapViewModel viewModel) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      elevation: 4,
      shadowColor: colorScheme.shadow.withValues(alpha: 0.12),
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          viewModel.setSearchQuery(value);
          setState(() {});
        },
        decoration: InputDecoration(
          hintText: 'Search cultural attractions',
          hintStyle: TextStyle(
            color: colorScheme.onSurfaceVariant,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: colorScheme.primary,
          ),
          suffixIcon: _searchController.text.isEmpty
              ? Icon(
            Icons.travel_explore_rounded,
            color: colorScheme.onSurfaceVariant,
          )
              : IconButton(
            tooltip: 'Clear search',
            onPressed: () {
              _searchController.clear();
              viewModel.clearSearch();
              setState(() {});
            },
            icon: const Icon(Icons.close_rounded),
          ),
          filled: true,
          fillColor: colorScheme.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(
              color: colorScheme.outlineVariant,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(
              color: colorScheme.primary,
              width: 1.4,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildMapResultsSheet({
    required CulturalMapViewModel viewModel,
    required ScrollController scrollController,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final usingDefault = viewModel.usingDefaultArea;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.14),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView(
        controller: scrollController,
        padding: EdgeInsets.zero,
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 46,
              height: 5,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              'Drag up for more places • drag down to view the map',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 14),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    usingDefault
                        ? Icons.location_city_rounded
                        : Icons.location_on_rounded,
                    color: colorScheme.onPrimaryContainer,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        usingDefault
                            ? 'Kuala Lumpur pilot area'
                            : 'Places near your location',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                        Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${viewModel.resultCount} cultural attraction${viewModel.resultCount == 1 ? '' : 's'} found',
                        style:
                        Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: viewModel.isLocating ? null : _refreshLocation,
                  icon: const Icon(
                    Icons.my_location_rounded,
                    size: 17,
                  ),
                  label: const Text('Update'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colorScheme.outlineVariant,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.filter_alt_outlined,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      viewModel.hasActiveFilter
                          ? 'Filters are active'
                          : 'Filter by cultural category',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (viewModel.hasActiveFilter)
                    TextButton(
                      onPressed: () {
                        _searchController.clear();
                        viewModel.clearFilters();
                        setState(() {});
                      },
                      child: const Text('Clear'),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          SizedBox(
            height: 52,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              scrollDirection: Axis.horizontal,
              itemCount: viewModel.availableCategories.length,
              separatorBuilder: (context, index) =>
              const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category =
                viewModel.availableCategories[index];
                final selected =
                viewModel.isCategorySelected(category);

                return FilterChip(
                  label: Text(category),
                  selected: selected,
                  onSelected: (_) {
                    viewModel.toggleCategory(category);
                  },
                  showCheckmark: true,
                  side: BorderSide(
                    color: selected
                        ? colorScheme.primary
                        : colorScheme.outlineVariant,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 6),

          Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 10),
            child: Row(
              children: [
                Icon(
                  Icons.place_outlined,
                  color: colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cultural places',
                    style:
                    Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${viewModel.resultCount} found',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          if (viewModel.errorMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
              child: _buildErrorState(viewModel),
            )
          else if (viewModel.visibleAttractions.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
              child: _buildEmptyState(viewModel),
            )
          else
            ...viewModel.visibleAttractions.map(
                  (attraction) => Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 11),
                child: _buildAttractionCard(
                  viewModel,
                  attraction,
                ),
              ),
            ),

          const SizedBox(height: 22),
        ],
      ),
    );
  }

  // ============================================================
  // ATTRACTION CARD
  // ============================================================

  Widget _buildAttractionCard(
      CulturalMapViewModel viewModel,
      Map<String, dynamic> attraction,
      ) {
    final colorScheme = Theme.of(context).colorScheme;

    final attractionId =
        attraction['id']?.toString().trim() ?? '';

    final isFavourite =
        attractionId.isNotEmpty &&
            viewModel.isFavourite(attractionId);

    final isInVisitList =
        attractionId.isNotEmpty &&
            viewModel.isInVisitList(attractionId);

    final category =
    viewModel.attractionCategory(attraction);

    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () async {
          viewModel.selectAttraction(attraction);

          final latitude =
          viewModel.attractionLatitude(attraction);

          final longitude =
          viewModel.attractionLongitude(attraction);

          if (latitude != null &&
              longitude != null &&
              _mapController != null) {
            await _googleMapsDataSource.moveCamera(
              controller: _mapController!,
              latitude: latitude,
              longitude: longitude,
              zoom: 16,
            );
          }

          if (!mounted) {
            return;
          }

          await _showAttractionDetails(attraction);
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  _iconForAttractionCategory(category),
                  color: colorScheme.onPrimaryContainer,
                  size: 25,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      viewModel.attractionName(attraction),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                        color:
                        colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.near_me_outlined,
                          size: 15,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            viewModel.distanceTextFor(
                              attraction,
                            ),
                            maxLines: 1,
                            overflow:
                            TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                              color: colorScheme
                                  .onSurfaceVariant,
                              fontWeight:
                              FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color:
                    colorScheme.onSurfaceVariant,
                    size: 21,
                  ),
                  const SizedBox(height: 12),
                  if (isFavourite)
                    Icon(
                      Icons.favorite_rounded,
                      color: colorScheme.error,
                      size: 18,
                    ),
                  if (isInVisitList)
                    Padding(
                      padding:
                      const EdgeInsets.only(top: 7),
                      child: Icon(
                        Icons.bookmark_rounded,
                        color: colorScheme.primary,
                        size: 18,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForAttractionCategory(
      String category,
      ) {
    final value = category.toLowerCase();

    if (value.contains('islam') ||
        value.contains('mosque')) {
      return Icons.mosque_outlined;
    }

    if (value.contains('indian') ||
        value.contains('hindu')) {
      return Icons.temple_hindu_outlined;
    }

    if (value.contains('chinese') ||
        value.contains('buddh') ||
        value.contains('temple')) {
      return Icons.temple_buddhist_outlined;
    }

    if (value.contains('histor')) {
      return Icons.account_balance_outlined;
    }

    if (value.contains('worship')) {
      return Icons.church_outlined;
    }

    return Icons.place_outlined;
  }

  // ============================================================
  // EMPTY
  // ============================================================

  Widget _buildEmptyState(
      CulturalMapViewModel viewModel,
      ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 28,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.location_searching_rounded,
            size: 38,
            color: colorScheme.primary,
          ),
          const SizedBox(height: 10),
          Text(
            'No matching cultural attractions',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            viewModel.hasActiveFilter
                ? 'Try changing or clearing your filters.'
                : 'No supported attraction is available in this area yet.',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _buildErrorState(
      CulturalMapViewModel viewModel,
      ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: colorScheme.onErrorContainer,
            size: 36,
          ),
          const SizedBox(height: 10),
          Text(
            viewModel.errorMessage ??
                'Unable to load map.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colorScheme.onErrorContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: () async {
              await viewModel.refreshAttractions();
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// FULL ETIQUETTE GUIDE PAGE
// ============================================================

class _FullEtiquetteGuidePage
    extends StatelessWidget {
  final String name;
  final String category;
  final List<Map<String, dynamic>> dos;
  final List<Map<String, dynamic>> donts;

  const _FullEtiquetteGuidePage({
    required this.name,
    required this.category,
    required this.dos,
    required this.donts,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      appBar:
      AppBar(
        title:
        const Text(
          'Etiquette Guide',
        ),
      ),
      backgroundColor:
      const Color(0xFFFFFBF5),
      body:
      ListView(
        padding:
        const EdgeInsets.all(
          18,
        ),
        children: [
          Text(
            category,
            style:
            const TextStyle(
              color:
              Color(0xFF6C4DB5),
              fontWeight:
              FontWeight.w600,
            ),
          ),

          const SizedBox(
            height: 4,
          ),

          Text(
            name,
            style:
            const TextStyle(
              fontSize: 25,
              fontWeight:
              FontWeight.bold,
              color:
              Color(0xFF14213D),
            ),
          ),

          const SizedBox(
            height: 8,
          ),

          Text(
            'Ranked specifically for this attraction.',
            style:
            TextStyle(
              color:
              Colors.grey.shade600,
              fontSize: 12,
            ),
          ),

          const SizedBox(
            height: 22,
          ),

          _RankedGuideSection(
            title: '✅ DO',
            titleColor:
            Colors.green,
            items: dos,
          ),

          const SizedBox(
            height: 18,
          ),

          _RankedGuideSection(
            title: "❌ DON'T",
            titleColor:
            Colors.red,
            items: donts,
          ),
        ],
      ),
    );
  }
}

class _RankedGuideSection
    extends StatelessWidget {
  final String title;
  final Color titleColor;
  final List<Map<String, dynamic>> items;

  const _RankedGuideSection({
    required this.title,
    required this.titleColor,
    required this.items,
  });

  int _intValue(
      dynamic value,
      ) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
      value?.toString() ?? '',
    ) ??
        0;
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      padding:
      const EdgeInsets.all(
        16,
      ),
      decoration:
      BoxDecoration(
        color:
        Colors.white,
        borderRadius:
        BorderRadius.circular(
          16,
        ),
        border:
        Border.all(
          color:
          Colors.grey.shade200,
        ),
      ),
      child:
      Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style:
            TextStyle(
              color:
              titleColor,
              fontSize: 17,
              fontWeight:
              FontWeight.bold,
            ),
          ),

          const SizedBox(
            height: 12,
          ),

          if (items.isEmpty)
            const Text(
              'No information available.',
            )
          else
            ...items.map(
                  (item) {
                final rank =
                _intValue(
                  item['rank'],
                );

                final ruleName =
                    item['ruleName']
                        ?.toString() ??
                        'Etiquette rule';

                return Padding(
                  padding:
                  const EdgeInsets.only(
                    bottom: 12,
                  ),
                  child:
                  Row(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        alignment:
                        Alignment.center,
                        decoration:
                        BoxDecoration(
                          color:
                          titleColor.withValues(
                            alpha: 0.12,
                          ),
                          borderRadius:
                          BorderRadius.circular(
                            9,
                          ),
                        ),
                        child:
                        Text(
                          '$rank',
                          style:
                          TextStyle(
                            color:
                            titleColor,
                            fontSize: 12,
                            fontWeight:
                            FontWeight.w900,
                          ),
                        ),
                      ),

                      const SizedBox(
                        width: 10,
                      ),

                      Expanded(
                        child:
                        Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              ruleName,
                              style:
                              const TextStyle(
                                height: 1.35,
                                fontWeight:
                                FontWeight.w500,
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
        ],
      ),
    );
  }
}
