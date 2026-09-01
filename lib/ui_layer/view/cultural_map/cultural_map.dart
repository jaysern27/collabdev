import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../../external_data_sources/google_maps/google_maps_data_source.dart';
import '../../view_model/cultural_map/cultural_map_view_model.dart';

class CulturalMapView extends StatefulWidget {
  const CulturalMapView({
    super.key,
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

  final TextEditingController _searchController =
  TextEditingController();

  GoogleMapController? _mapController;

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

        await _moveMapToCurrentArea();
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
  // FULL ETIQUETTE PAGE
  // ============================================================

  void _openFullEtiquetteGuide(
      Map<String, dynamic> attraction,
      ) {
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
              dos:
              _viewModel.attractionDos(
                attraction,
              ),
              donts:
              _viewModel.attractionDonts(
                attraction,
              ),
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

                                        if (dos.isEmpty)
                                          const Text(
                                            'No specific DO guidance available.',
                                          )
                                        else
                                          ...dos.map(
                                                (
                                                item,
                                                ) =>
                                                _buildRuleItem(
                                                  icon:
                                                  Icons.check_circle,
                                                  iconColor:
                                                  Colors.green,
                                                  text:
                                                  item,
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

                                        if (donts.isEmpty)
                                          const Text(
                                            "No specific DON'T guidance available.",
                                          )
                                        else
                                          ...donts.map(
                                                (
                                                item,
                                                ) =>
                                                _buildRuleItem(
                                                  icon:
                                                  Icons.cancel,
                                                  iconColor:
                                                  Colors.red,
                                                  text:
                                                  item,
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

  Widget _buildRuleItem({
    required IconData icon,
    required Color iconColor,
    required String text,
  }) {
    return Padding(
      padding:
      const EdgeInsets.only(
        bottom: 9,
      ),
      child:
      Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color:
            iconColor,
          ),
          const SizedBox(
            width: 8,
          ),
          Expanded(
            child:
            Text(
              text,
              style:
              const TextStyle(
                height: 1.35,
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
    final icons = [
      Icons.account_balance_outlined,
      Icons.self_improvement,
      Icons.photo_camera_outlined,
      Icons.history_edu_outlined,
    ];

    final icon =
    icons[index % icons.length];

    return Container(
      width:
      double.infinity,
      padding:
      const EdgeInsets.all(
        14,
      ),
      decoration:
      BoxDecoration(
        border:
        Border(
          top:
          BorderSide(
            color:
            Colors.grey.shade200,
          ),
        ),
      ),
      child:
      Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor:
            Colors.orange.shade50,
            child:
            Icon(
              icon,
              size: 19,
              color:
              Colors.orange,
            ),
          ),
          const SizedBox(
            width: 12,
          ),
          Expanded(
            child:
            Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                  const TextStyle(
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(
                    height: 4,
                  ),
                  Text(
                    description,
                    style:
                    TextStyle(
                      color:
                      Colors.grey.shade700,
                      height:
                      1.35,
                      fontSize:
                      12,
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
    return Container(
      width:
      double.infinity,
      padding:
      const EdgeInsets.all(
        14,
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
      Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color:
            const Color(
              0xFF6C4DB5,
            ),
          ),
          const SizedBox(
            width: 12,
          ),
          Expanded(
            child:
            Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                  const TextStyle(
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
                const SizedBox(
                  height: 4,
                ),
                Text(
                  content,
                  style:
                  TextStyle(
                    color:
                    Colors.grey.shade700,
                    height:
                    1.4,
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
  Widget build(
      BuildContext context,
      ) {
    return ChangeNotifierProvider<
        CulturalMapViewModel>.value(
      value:
      _viewModel,
      child:
      Consumer<
          CulturalMapViewModel>(
        builder:
            (
            context,
            viewModel,
            child,
            ) {
          return Scaffold(
            appBar:
            AppBar(
              title:
              const Text(
                'Cultural Map',
              ),
              actions: [
                IconButton(
                  tooltip:
                  'Refresh attractions',
                  onPressed:
                  viewModel.isLoading
                      ? null
                      : () async {
                    await viewModel
                        .refreshAttractions();
                  },
                  icon:
                  const Icon(
                    Icons.refresh,
                  ),
                ),
              ],
            ),
            body:
            Column(
              children: [
                _buildLocationBanner(
                  viewModel,
                ),

                Padding(
                  padding:
                  const EdgeInsets.fromLTRB(
                    16,
                    12,
                    16,
                    4,
                  ),
                  child:
                  TextField(
                    controller:
                    _searchController,
                    onChanged:
                    viewModel.setSearchQuery,
                    decoration:
                    InputDecoration(
                      hintText:
                      'Search cultural attractions',
                      prefixIcon:
                      const Icon(
                        Icons.search,
                      ),
                      suffixIcon:
                      _searchController.text.isEmpty
                          ? null
                          : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          viewModel.clearSearch();

                          setState(
                                () {},
                          );
                        },
                        icon:
                        const Icon(
                          Icons.close,
                        ),
                      ),
                      border:
                      OutlineInputBorder(
                        borderRadius:
                        BorderRadius.circular(
                          16,
                        ),
                      ),
                    ),
                  ),
                ),

                _buildCategoryFilters(
                  viewModel,
                ),

                Padding(
                  padding:
                  const EdgeInsets.symmetric(
                    horizontal:
                    16,
                    vertical:
                    6,
                  ),
                  child:
                  Row(
                    children: [
                      Expanded(
                        child:
                        Text(
                          '${viewModel.resultCount} cultural attraction${viewModel.resultCount == 1 ? '' : 's'} found',
                          style:
                          const TextStyle(
                            fontWeight:
                            FontWeight.w600,
                          ),
                        ),
                      ),
                      if (viewModel.hasActiveFilter)
                        TextButton(
                          onPressed: () {
                            _searchController.clear();
                            viewModel.clearFilters();

                            setState(
                                  () {},
                            );
                          },
                          child:
                          const Text(
                            'Clear Filters',
                          ),
                        ),
                    ],
                  ),
                ),

                Expanded(
                  child:
                  viewModel.isLoading
                      ? const Center(
                    child:
                    CircularProgressIndicator(),
                  )
                      : viewModel.errorMessage != null
                      ? _buildErrorState(
                    viewModel,
                  )
                      : _buildMapAndList(
                    viewModel,
                  ),
                ),
              ],
            ),
            floatingActionButton:
            FloatingActionButton(
              heroTag:
              'cultural_map_location',
              onPressed:
              viewModel.isLocating
                  ? null
                  : _refreshLocation,
              tooltip:
              'My Location',
              child:
              viewModel.isLocating
                  ? const SizedBox(
                width:
                22,
                height:
                22,
                child:
                CircularProgressIndicator(
                  strokeWidth:
                  2,
                ),
              )
                  : const Icon(
                Icons.my_location,
              ),
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // LOCATION BANNER
  // ============================================================

  Widget _buildLocationBanner(
      CulturalMapViewModel viewModel,
      ) {
    final usingDefault =
        viewModel.usingDefaultArea;

    return Container(
      width:
      double.infinity,
      padding:
      const EdgeInsets.symmetric(
        horizontal:
        16,
        vertical:
        10,
      ),
      color:
      usingDefault
          ? Colors.orange.shade50
          : Colors.green.shade50,
      child:
      Row(
        children: [
          Icon(
            usingDefault
                ? Icons.location_off_outlined
                : Icons.location_on_outlined,
            size:
            20,
          ),
          const SizedBox(
            width:
            10,
          ),
          Expanded(
            child:
            Text(
              usingDefault
                  ? 'Using Kuala Lumpur pilot area'
                  : 'Using your current location',
              style:
              const TextStyle(
                fontWeight:
                FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CATEGORY FILTERS
  // ============================================================

  Widget _buildCategoryFilters(
      CulturalMapViewModel viewModel,
      ) {
    return SizedBox(
      height:
      58,
      child:
      ListView.separated(
        padding:
        const EdgeInsets.symmetric(
          horizontal:
          16,
          vertical:
          8,
        ),
        scrollDirection:
        Axis.horizontal,
        itemCount:
        viewModel.availableCategories.length,
        separatorBuilder:
            (
            context,
            index,
            ) =>
        const SizedBox(
          width:
          8,
        ),
        itemBuilder:
            (
            context,
            index,
            ) {
          final category =
          viewModel.availableCategories[index];

          return FilterChip(
            label:
            Text(
              category,
            ),
            selected:
            viewModel.isCategorySelected(
              category,
            ),
            onSelected:
                (_) {
              viewModel.toggleCategory(
                category,
              );
            },
          );
        },
      ),
    );
  }

  // ============================================================
  // MAP + LIST
  // ============================================================

  Widget _buildMapAndList(
      CulturalMapViewModel viewModel,
      ) {
    return Column(
      children: [
        Expanded(
          flex:
          5,
          child:
          ClipRRect(
            borderRadius:
            const BorderRadius.vertical(
              top:
              Radius.circular(
                18,
              ),
            ),
            child:
            GoogleMap(
              initialCameraPosition:
              CameraPosition(
                target:
                LatLng(
                  viewModel.currentLatitude,
                  viewModel.currentLongitude,
                ),
                zoom:
                13,
              ),
              markers:
              _buildMarkers(
                viewModel,
              ),
              myLocationEnabled:
              viewModel.locationAvailable,
              myLocationButtonEnabled:
              false,
              zoomControlsEnabled:
              false,
              mapToolbarEnabled:
              false,
              onMapCreated:
                  (
                  controller,
                  ) async {
                _mapController =
                    controller;

                await _moveMapToCurrentArea();
              },
            ),
          ),
        ),

        Expanded(
          flex:
          4,
          child:
          viewModel.visibleAttractions.isEmpty
              ? _buildEmptyState(
            viewModel,
          )
              : ListView.separated(
            padding:
            const EdgeInsets.all(
              16,
            ),
            itemCount:
            viewModel.visibleAttractions.length,
            separatorBuilder:
                (
                context,
                index,
                ) =>
            const SizedBox(
              height:
              10,
            ),
            itemBuilder:
                (
                context,
                index,
                ) {
              final attraction =
              viewModel.visibleAttractions[index];

              return _buildAttractionCard(
                viewModel,
                attraction,
              );
            },
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ATTRACTION CARD
  // ============================================================

  Widget _buildAttractionCard(
      CulturalMapViewModel viewModel,
      Map<String, dynamic> attraction,
      ) {
    final attractionId =
        attraction['id']?.toString().trim() ?? '';

    final isFavourite =
        attractionId.isNotEmpty &&
            viewModel.isFavourite(
              attractionId,
            );

    final isInVisitList =
        attractionId.isNotEmpty &&
            viewModel.isInVisitList(
              attractionId,
            );

    return Card(
      elevation:
      0,
      shape:
      RoundedRectangleBorder(
        borderRadius:
        BorderRadius.circular(
          16,
        ),
        side:
        BorderSide(
          color:
          Colors.grey.shade300,
        ),
      ),
      child:
      InkWell(
        borderRadius:
        BorderRadius.circular(
          16,
        ),
        onTap:
            () async {
          viewModel.selectAttraction(
            attraction,
          );

          final latitude =
          viewModel.attractionLatitude(
            attraction,
          );

          final longitude =
          viewModel.attractionLongitude(
            attraction,
          );

          if (latitude != null &&
              longitude != null &&
              _mapController != null) {
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
          }

          if (!mounted) {
            return;
          }

          await _showAttractionDetails(
            attraction,
          );
        },
        child:
        Padding(
          padding:
          const EdgeInsets.all(
            14,
          ),
          child:
          Row(
            children: [
              Container(
                width:
                56,
                height:
                56,
                decoration:
                BoxDecoration(
                  color:
                  Theme.of(context)
                      .colorScheme
                      .primaryContainer,
                  borderRadius:
                  BorderRadius.circular(
                    14,
                  ),
                ),
                child:
                const Icon(
                  Icons.temple_buddhist_outlined,
                ),
              ),

              const SizedBox(
                width:
                12,
              ),

              Expanded(
                child:
                Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      viewModel.attractionName(
                        attraction,
                      ),
                      style:
                      const TextStyle(
                        fontWeight:
                        FontWeight.bold,
                        fontSize:
                        16,
                      ),
                    ),
                    const SizedBox(
                      height:
                      4,
                    ),
                    Text(
                      viewModel.attractionCategory(
                        attraction,
                      ),
                    ),
                    const SizedBox(
                      height:
                      4,
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.near_me_outlined,
                          size:
                          16,
                        ),
                        const SizedBox(
                          width:
                          4,
                        ),
                        Expanded(
                          child:
                          Text(
                            viewModel.distanceTextFor(
                              attraction,
                            ),
                            style:
                            TextStyle(
                              color:
                              Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              if (isFavourite)
                const Icon(
                  Icons.favorite,
                  size:
                  20,
                ),

              if (isInVisitList)
                const Padding(
                  padding:
                  EdgeInsets.only(
                    left:
                    5,
                  ),
                  child:
                  Icon(
                    Icons.bookmark,
                    size:
                    20,
                  ),
                ),

              const Icon(
                Icons.chevron_right,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY
  // ============================================================

  Widget _buildEmptyState(
      CulturalMapViewModel viewModel,
      ) {
    return Center(
      child:
      Padding(
        padding:
        const EdgeInsets.all(
          24,
        ),
        child:
        Column(
          mainAxisSize:
          MainAxisSize.min,
          children: [
            Icon(
              Icons.location_searching_outlined,
              size:
              52,
              color:
              Colors.grey.shade500,
            ),
            const SizedBox(
              height:
              12,
            ),
            const Text(
              'No matching cultural attractions found.',
              textAlign:
              TextAlign.center,
              style:
              TextStyle(
                fontWeight:
                FontWeight.bold,
              ),
            ),
            const SizedBox(
              height:
              8,
            ),
            Text(
              viewModel.hasActiveFilter
                  ? 'Try changing or clearing your filters.'
                  : 'Add supported attractions to Firebase to display them here.',
              textAlign:
              TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _buildErrorState(
      CulturalMapViewModel viewModel,
      ) {
    return Center(
      child:
      Padding(
        padding:
        const EdgeInsets.all(
          24,
        ),
        child:
        Column(
          mainAxisSize:
          MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size:
              52,
            ),
            const SizedBox(
              height:
              12,
            ),
            Text(
              viewModel.errorMessage ??
                  'Unable to load map.',
              textAlign:
              TextAlign.center,
            ),
            const SizedBox(
              height:
              16,
            ),
            FilledButton.icon(
              onPressed:
                  () async {
                viewModel.clearError();

                await viewModel.refreshAttractions();
              },
              icon:
              const Icon(
                Icons.refresh,
              ),
              label:
              const Text(
                'Retry',
              ),
            ),
          ],
        ),
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
  final List<String> dos;
  final List<String> donts;

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
            height:
            4,
          ),

          Text(
            name,
            style:
            const TextStyle(
              fontSize:
              25,
              fontWeight:
              FontWeight.bold,
              color:
              Color(0xFF14213D),
            ),
          ),

          const SizedBox(
            height:
            22,
          ),

          _GuideSection(
            title:
            '✅ DO',
            titleColor:
            Colors.green,
            items:
            dos,
            icon:
            Icons.check_circle,
            iconColor:
            Colors.green,
          ),

          const SizedBox(
            height:
            18,
          ),

          _GuideSection(
            title:
            "❌ DON'T",
            titleColor:
            Colors.red,
            items:
            donts,
            icon:
            Icons.cancel,
            iconColor:
            Colors.red,
          ),
        ],
      ),
    );
  }
}

class _GuideSection
    extends StatelessWidget {
  final String title;
  final Color titleColor;
  final List<String> items;
  final IconData icon;
  final Color iconColor;

  const _GuideSection({
    required this.title,
    required this.titleColor,
    required this.items,
    required this.icon,
    required this.iconColor,
  });

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
              fontSize:
              17,
              fontWeight:
              FontWeight.bold,
            ),
          ),

          const SizedBox(
            height:
            12,
          ),

          if (items.isEmpty)
            const Text(
              'No information available.',
            )
          else
            ...items.map(
                  (
                  item,
                  ) =>
                  Padding(
                    padding:
                    const EdgeInsets.only(
                      bottom:
                      12,
                    ),
                    child:
                    Row(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Icon(
                          icon,
                          size:
                          19,
                          color:
                          iconColor,
                        ),
                        const SizedBox(
                          width:
                          9,
                        ),
                        Expanded(
                          child:
                          Text(
                            item,
                            style:
                            const TextStyle(
                              height:
                              1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
            ),
        ],
      ),
    );
  }
}