import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../../external_data_sources/google_maps/google_maps_data_source.dart';
import '../../../data_layer/model/repositories/ranking_report/ranking_report_repository.dart';
import '../../view_model/cultural_map/cultural_map_view_model.dart';
import '../../view_model/settings/app_settings_controller.dart';
import '../saved_places/saved_places_page.dart';

class CulturalMapView extends StatefulWidget {
  final Map<String, dynamic>? initialAttraction;
  final String? initialQuery;

  const CulturalMapView({
    super.key,
    this.initialAttraction,
    this.initialQuery,
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

  final AppSettingsController _settings =
      AppSettingsController.instance;

  final TextEditingController _searchController =
  TextEditingController();

  GoogleMapController? _mapController;

  bool _viewModelReady = false;
  bool _initialAttractionHandled = false;

  @override
  void initState() {
    super.initState();


    _settings.addListener(
      _onSettingsChanged,
    );
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
        } else if (widget.initialQuery != null &&
            widget.initialQuery!.trim().isNotEmpty) {
          // Set the search state now; the camera is fitted to the
          // matching markers once onMapCreated fires below, since
          // _mapController is not ready yet at this point.
          _searchController.text = widget.initialQuery!;

          _viewModel.setSearchQuery(
            widget.initialQuery!,
          );
        } else {
          await _moveMapToCurrentArea();
        }
      },
    );
  }

  void _onSettingsChanged() {
    if (mounted) {
      setState(() {});
    }
  }

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

  String _localizedText(
      Map source, {
        required String enKey,
        required String zhKey,
        required String msKey,
      }) {
    final english =
    (source[enKey] ?? '')
        .toString()
        .trim();

    final chinese =
    (source[zhKey] ?? '')
        .toString()
        .trim();

    final malay =
    (source[msKey] ?? '')
        .toString()
        .trim();

    return _t(
      en: english,
      zh: chinese.isNotEmpty
          ? chinese
          : english,
      ms: malay.isNotEmpty
          ? malay
          : english,
    );
  }

  String _ruleText(Map<String, dynamic> rule) {
    final english =
    (rule['ruleName'] ??
        rule['title'] ??
        rule['description'] ??
        '')
        .toString()
        .trim();

    final chinese =
    (rule['ruleNameZh'] ?? '')
        .toString()
        .trim();

    final malay =
    (rule['ruleNameMs'] ?? '')
        .toString()
        .trim();

    switch (_settings.language) {
      case AppLanguage.chinese:
        return chinese.isNotEmpty ? chinese : english;
      case AppLanguage.malay:
        return malay.isNotEmpty ? malay : english;
      case AppLanguage.english:
        return english;
    }
  }

  String _categoryText(String category) {
    switch (category) {
      case 'Islamic Culture':
        return _t(
          en: 'Islamic Culture',
          zh: '伊斯兰文化',
          ms: 'Budaya Islam',
        );
      case 'Chinese Culture':
        return _t(
          en: 'Chinese Culture',
          zh: '中华文化',
          ms: 'Budaya Cina',
        );
      case 'Indian Culture':
        return _t(
          en: 'Indian Culture',
          zh: '印度文化',
          ms: 'Budaya India',
        );
      case 'Places of Worship':
        return _t(
          en: 'Places of Worship',
          zh: '宗教场所',
          ms: 'Tempat Ibadat',
        );
      case 'Historical Landmarks':
        return _t(
          en: 'Historical Landmarks',
          zh: '历史地标',
          ms: 'Mercu Tanda Bersejarah',
        );
      case 'Cultural Attraction':
        return _t(
          en: 'Cultural Attraction',
          zh: '文化景点',
          ms: 'Tarikan Budaya',
        );
      default:
        return category;
    }
  }

  String _statusText(String status) {
    final normalized = status.trim().toLowerCase();

    if (normalized.isEmpty ||
        normalized.contains('unknown')) {
      return _t(
        en: 'Status Unknown',
        zh: '状态未知',
        ms: 'Status Tidak Diketahui',
      );
    }

    if (normalized.contains('temporarily') &&
        normalized.contains('closed')) {
      return _t(
        en: 'Temporarily Closed',
        zh: '暂时关闭',
        ms: 'Ditutup Sementara',
      );
    }

    if (normalized.contains('closed')) {
      return _t(
        en: 'Closed',
        zh: '已关闭',
        ms: 'Ditutup',
      );
    }

    if (normalized.contains('open')) {
      return _t(
        en: 'Open',
        zh: '开放',
        ms: 'Dibuka',
      );
    }

    return status;
  }

  String _distanceText(
      Map<String, dynamic> attraction,
      ) {
    final distance =
    _viewModel.distanceKmFor(attraction);

    if (distance == null) {
      return _t(
        en: 'Distance unavailable',
        zh: '距离不可用',
        ms: 'Jarak tidak tersedia',
      );
    }

    return _viewModel.distanceTextFor(
      attraction,
    );
  }

  String _addressText(
      Map<String, dynamic> attraction,
      ) {
    final address =
        attraction['address']?.toString().trim() ?? '';

    if (address.isEmpty) {
      return _t(
        en: 'Location information unavailable.',
        zh: '暂无地点信息。',
        ms: 'Maklumat lokasi tidak tersedia.',
      );
    }

    return address;
  }

  String _nameText(
      Map<String, dynamic> attraction,
      ) {
    final name =
        attraction['name']?.toString().trim() ?? '';

    if (name.isEmpty) {
      return _t(
        en: 'Unknown attraction',
        zh: '未知景点',
        ms: 'Tarikan tidak diketahui',
      );
    }

    return name;
  }

  String _errorText(String? error) {
    final raw = error?.trim() ?? '';

    if (raw.isEmpty) {
      return _t(
        en: 'Unable to load map.',
        zh: '无法加载地图。',
        ms: 'Tidak dapat memuatkan peta.',
      );
    }

    switch (raw) {
      case 'Unable to obtain current location.':
        return _t(
          en: raw,
          zh: '无法获取当前位置。',
          ms: 'Tidak dapat mendapatkan lokasi semasa.',
        );
      case 'Unable to load saved attractions.':
        return _t(
          en: raw,
          zh: '无法加载已保存的景点。',
          ms: 'Tidak dapat memuatkan tarikan yang disimpan.',
        );
      case 'Please sign in to save favourites.':
        return _t(
          en: raw,
          zh: '请先登录以保存收藏。',
          ms: 'Sila log masuk untuk menyimpan kegemaran.',
        );
      case 'Attraction ID is missing.':
        return _t(
          en: raw,
          zh: '缺少景点 ID。',
          ms: 'ID tarikan tiada.',
        );
      case 'Unable to update favourite.':
        return _t(
          en: raw,
          zh: '无法更新收藏。',
          ms: 'Tidak dapat mengemas kini kegemaran.',
        );
    }

    if (raw.startsWith(
      'Current location is outside the supported Malaysia area.',
    )) {
      return _t(
        en: raw,
        zh: '当前位置不在支持的马来西亚区域内。正在显示默认的吉隆坡试点区域。',
        ms: 'Lokasi semasa berada di luar kawasan Malaysia yang disokong. Kawasan perintis Kuala Lumpur lalai sedang dipaparkan.',
      );
    }

    return raw;
  }

  @override
  void dispose() {
    _settings.removeListener(
      _onSettingsChanged,
    );

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

  // ============================================================
  // FIT MAP TO SEARCH RESULTS
  //
  // Search results can be spread across the whole country, so pan
  // and zoom the camera to fit every matching marker on screen
  // instead of leaving them scattered outside the current view.
  // ============================================================

  Future<void> _fitMapToVisibleAttractions() async {
    final controller =
        _mapController;

    if (controller == null) {
      return;
    }

    final points = <LatLng>[];

    for (final attraction
    in _viewModel.visibleAttractions) {
      final latitude =
      _viewModel.attractionLatitude(
        attraction,
      );

      final longitude =
      _viewModel.attractionLongitude(
        attraction,
      );

      if (latitude != null &&
          longitude != null) {
        points.add(
          LatLng(
            latitude,
            longitude,
          ),
        );
      }
    }

    if (points.isEmpty) {
      return;
    }

    if (points.length == 1) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(
          points.first,
          15,
        ),
      );

      return;
    }

    var minLatitude =
        points.first.latitude;

    var maxLatitude =
        points.first.latitude;

    var minLongitude =
        points.first.longitude;

    var maxLongitude =
        points.first.longitude;

    for (final point in points) {
      minLatitude = point.latitude < minLatitude
          ? point.latitude
          : minLatitude;

      maxLatitude = point.latitude > maxLatitude
          ? point.latitude
          : maxLatitude;

      minLongitude = point.longitude < minLongitude
          ? point.longitude
          : minLongitude;

      maxLongitude = point.longitude > maxLongitude
          ? point.longitude
          : maxLongitude;
    }

    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(
            minLatitude,
            minLongitude,
          ),
          northeast: LatLng(
            maxLatitude,
            maxLongitude,
          ),
        ),
        60,
      ),
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
    _nameText(
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
        ? _t(
      en: 'Current location unavailable. Showing Kuala Lumpur pilot area.',
      zh: '无法获取当前位置。正在显示吉隆坡试点区域。',
      ms: 'Lokasi semasa tidak tersedia. Kawasan perintis Kuala Lumpur sedang dipaparkan.',
    )
        : _t(
      en: 'Map centred on your current location.',
      zh: '地图已定位到您的当前位置。',
      ms: 'Peta dipusatkan pada lokasi semasa anda.',
    );

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
            _nameText(
              attraction,
            ),
            snippet:
            _categoryText(
              viewModel.attractionCategory(
                attraction,
              ),
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
          Text(
            _t(
              en: 'Sign In Required',
              zh: '需要登录',
              ms: 'Log Masuk Diperlukan',
            ),
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
              Text(
                _t(
                  en: 'OK',
                  zh: '确定',
                  ms: 'OK',
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // SAVED PLACES
  // ============================================================

  Future<void> _openSavedPlacesPage() async {
    if (!_viewModel.isLoggedIn) {
      await _showSignInRequiredDialog(
        _t(
          en: 'Please sign in to view your saved places.',
          zh: '请先登录以查看已保存的地点。',
          ms: 'Sila log masuk untuk melihat tempat yang disimpan.',
        ),
      );

      return;
    }

    if (!mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
        const SavedPlacesPage(),
      ),
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
        _t(
          en: 'Please sign in to save favourites.',
          zh: '请先登录以保存收藏。',
          ms: 'Sila log masuk untuk menyimpan kegemaran.',
        ),
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
        ? _t(
      en: 'Removed from favourites.',
      zh: '已从收藏中移除。',
      ms: 'Dialih keluar daripada kegemaran.',
    )
        : _t(
      en: 'Saved to favourites.',
      zh: '已保存到收藏。',
      ms: 'Disimpan ke kegemaran.',
    )
        : _errorText(
      _viewModel.errorMessage,
    );

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
              _nameText(
                attraction,
              ),
              category:
              _categoryText(
                _viewModel.attractionCategory(
                  attraction,
                ),
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
    _nameText(
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
    _statusText(
      _viewModel.attractionStatus(
        attraction,
      ),
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
                                _categoryText(category),
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
                                        _t(
                                          en: 'Direct Distance',
                                          zh: '直线距离',
                                          ms: 'Jarak Lurus',
                                        ),
                                        _distanceText(
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
                                        _t(
                                          en: 'Status',
                                          zh: '状态',
                                          ms: 'Status',
                                        ),
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
                                            _t(
                                              en: 'Rating',
                                              zh: '评分',
                                              ms: 'Penilaian',
                                            ),
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
                                        Row(
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
                                              _t(
                                                en: 'Know Before You Enter',
                                                zh: '进入前须知',
                                                ms: 'Sebelum Anda Masuk',
                                              ),
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
                                          _t(
                                            en: 'Essential etiquette for $name',
                                            zh: '$name 的重要礼仪',
                                            ms: 'Etika penting untuk $name',
                                          ),
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
                                        Text(
                                          _t(
                                            en: '✅ DO',
                                            zh: '✅ 应该做',
                                            ms: '✅ BOLEH',
                                          ),
                                          style: const TextStyle(
                                            color: Colors.green,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),

                                        const SizedBox(
                                          height: 8,
                                        ),

                                        if (previewDos.isEmpty)
                                          Text(
                                            _t(
                                              en: 'No specific DO guidance available.',
                                              zh: '目前没有具体的“应该做”礼仪建议。',
                                              ms: 'Tiada panduan BOLEH khusus buat masa ini.',
                                            ),
                                          )
                                        else
                                          ...previewDos.map(
                                                (item) =>
                                                _buildRankedRuleItem(
                                                  rank:
                                                  _rankValue(item),
                                                  text:
                                                  _ruleText(item).isNotEmpty
                                                      ? _ruleText(item)
                                                      : _t(
                                                    en: 'Etiquette rule',
                                                    zh: '礼仪规则',
                                                    ms: 'Peraturan etika',
                                                  ),
                                                  color:
                                                  Colors.green,
                                                ),
                                          ),

                                        const Divider(
                                          height: 28,
                                        ),

                                        Text(
                                          _t(
                                            en: "❌ DON'T",
                                            zh: '❌ 不应该做',
                                            ms: '❌ JANGAN',
                                          ),
                                          style: const TextStyle(
                                            color: Colors.red,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),

                                        const SizedBox(
                                          height: 8,
                                        ),

                                        if (previewDonts.isEmpty)
                                          Text(
                                            _t(
                                              en: "No specific DON'T guidance available.",
                                              zh: '目前没有具体的“不应该做”礼仪建议。',
                                              ms: 'Tiada panduan JANGAN khusus buat masa ini.',
                                            ),
                                          )
                                        else
                                          ...previewDonts.map(
                                                (item) =>
                                                _buildRankedRuleItem(
                                                  rank:
                                                  _rankValue(item),
                                                  text:
                                                  _ruleText(item).isNotEmpty
                                                      ? _ruleText(item)
                                                      : _t(
                                                    en: 'Etiquette rule',
                                                    zh: '礼仪规则',
                                                    ms: 'Peraturan etika',
                                                  ),
                                                  color:
                                                  Colors.red,
                                                ),
                                          ),

                                        const SizedBox(
                                          height: 10,
                                        ),

                                        Text(
                                          _t(
                                            en: "Top 3 ranked etiquette rules for this place. Approved reports can reprioritise the DON'T ranking. Open the full guide to see all rules.",
                                            zh: '此地点显示排名前三的礼仪规则。管理员批准的报告可能会调整“不应该做”的优先顺序。打开完整指南可查看所有规则。',
                                            ms: 'Tiga peraturan etika teratas untuk tempat ini. Laporan yang diluluskan boleh mengubah keutamaan kedudukan JANGAN. Buka panduan penuh untuk melihat semua peraturan.',
                                          ),
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
                                            Text(
                                              _t(
                                                en: 'View Full Etiquette Guide',
                                                zh: '查看完整礼仪指南',
                                                ms: 'Lihat Panduan Etika Penuh',
                                              ),
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
                                    Row(
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
                                                _t(
                                                  en: 'What You Can Do Here',
                                                  zh: '您可以在这里做什么',
                                                  ms: 'Aktiviti yang Boleh Dilakukan di Sini',
                                                ),
                                                style:
                                                TextStyle(
                                                  color:
                                                  Color(0xFF00796B),
                                                  fontWeight:
                                                  FontWeight.bold,
                                                ),
                                              ),
                                              Text(
                                                _t(
                                                  en: 'Tourist-friendly activities at this cultural attraction',
                                                  zh: '适合游客在此文化景点进行的活动',
                                                  ms: 'Aktiviti mesra pelancong di tarikan budaya ini',
                                                ),
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
                                    Padding(
                                      padding:
                                      EdgeInsets.all(
                                        16,
                                      ),
                                      child:
                                      Text(
                                        _t(
                                          en: 'Activity information is not available yet.',
                                          zh: '暂无活动信息。',
                                          ms: 'Maklumat aktiviti belum tersedia.',
                                        ),
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
                                          _localizedText(
                                            activity,
                                            enKey: 'title',
                                            zhKey: 'titleZh',
                                            msKey: 'titleMs',
                                          ),
                                          description:
                                          _localizedText(
                                            activity,
                                            enKey: 'description',
                                            zhKey: 'descriptionZh',
                                            msKey: 'descriptionMs',
                                          ),
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
                              _t(
                                en: 'About',
                                zh: '关于',
                                ms: 'Tentang',
                              ),
                              content:
                              _localizedText(
                                attraction,
                                enKey: 'description',
                                zhKey: 'descriptionZh',
                                msKey: 'descriptionMs',
                              ),
                            ),

                            const SizedBox(
                              height: 10,
                            ),

                            _buildInfoCard(
                              icon:
                              Icons.location_on_outlined,
                              title:
                              _t(
                                en: 'Location',
                                zh: '地点',
                                ms: 'Lokasi',
                              ),
                              content:
                              _addressText(
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
                              _t(
                                en: 'Opening Information',
                                zh: '开放信息',
                                ms: 'Maklumat Waktu Operasi',
                              ),
                              content:
                              _localizedText(
                                attraction,
                                enKey: 'openingInformation',
                                zhKey: 'openingInformationZh',
                                msKey: 'openingInformationMs',
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
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.info_outline,
                                    ),
                                    const SizedBox(
                                      width: 10,
                                    ),
                                    Expanded(
                                      child:
                                      Text(
                                        _t(
                                          en: 'Sign in to save this attraction to your Favourites.',
                                          zh: '登录后即可将此景点保存到收藏。',
                                          ms: 'Log masuk untuk menyimpan tarikan ini ke Kegemaran anda.',
                                        ),
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
                                      ? _t(
                                    en: 'Remove from Favourites',
                                    zh: '从收藏中移除',
                                    ms: 'Alih Keluar daripada Kegemaran',
                                  )
                                      : _t(
                                    en: 'Save to Favourites',
                                    zh: '保存到收藏',
                                    ms: 'Simpan ke Kegemaran',
                                  ),
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
                                        SnackBar(
                                          content:
                                          Text(
                                            _t(
                                              en: 'Unable to open directions.',
                                              zh: '无法打开导航。',
                                              ms: 'Tidak dapat membuka navigasi.',
                                            ),
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
                                Text(
                                  _t(
                                    en: 'Directions',
                                    zh: '导航',
                                    ms: 'Arah',
                                  ),
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
      Column(
        mainAxisAlignment:
        MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.temple_buddhist_outlined,
            size: 58,
          ),
          const SizedBox(
            height: 8,
          ),
          Text(
            _t(
              en: 'Cultural Attraction',
              zh: '文化景点',
              ms: 'Tarikan Budaya',
            ),
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
              title: Text(
                _t(
                  en: 'Cultural Map',
                  zh: '文化地图',
                  ms: 'Peta Budaya',
                ),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
              actions: [
                IconButton(
                  tooltip: _t(
                    en: 'Saved places',
                    zh: '已保存的地点',
                    ms: 'Tempat disimpan',
                  ),
                  onPressed: _openSavedPlacesPage,
                  icon: const Icon(
                    Icons.favorite_rounded,
                  ),
                ),
                IconButton(
                  tooltip: _t(
                    en: 'Refresh attractions',
                    zh: '刷新景点',
                    ms: 'Muat semula tarikan',
                  ),
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
                      } else if (widget.initialQuery != null &&
                          widget.initialQuery!.trim().isNotEmpty) {
                        await _fitMapToVisibleAttractions();
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
                      tooltip: _t(
                        en: 'My Location',
                        zh: '我的位置',
                        ms: 'Lokasi Saya',
                      ),
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
                                  _t(
                                    en: 'Loading cultural places...',
                                    zh: '正在加载文化景点...',
                                    ms: 'Memuatkan tempat budaya...',
                                  ),
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

          if (value.trim().isEmpty) {
            _moveMapToCurrentArea();
          } else {
            _fitMapToVisibleAttractions();
          }
        },
        decoration: InputDecoration(
          hintText: _t(
            en: 'Search cultural attractions',
            zh: '搜索文化景点',
            ms: 'Cari tarikan budaya',
          ),
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
            tooltip: _t(
              en: 'Clear search',
              zh: '清除搜索',
              ms: 'Kosongkan carian',
            ),
            onPressed: () {
              _searchController.clear();
              viewModel.clearSearch();
              setState(() {});
              _moveMapToCurrentArea();
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
              _t(
                en: 'Drag up for more places • drag down to view the map',
                zh: '向上拖查看更多景点 • 向下拖动查看地图',
                ms: 'Tarik ke atas untuk lebih banyak tempat • tarik ke bawah untuk melihat peta',
              ),
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
                            ? _t(
                          en: 'Kuala Lumpur pilot area',
                          zh: '吉隆坡试点区域',
                          ms: 'Kawasan perintis Kuala Lumpur',
                        )
                            : _t(
                          en: 'Places near your location',
                          zh: '您附近的景点',
                          ms: 'Tempat berhampiran lokasi anda',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                        Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _t(
                          en: '${viewModel.resultCount} cultural attraction${viewModel.resultCount == 1 ? '' : 's'} found',
                          zh: '找到 ${viewModel.resultCount} 个文化景点',
                          ms: '${viewModel.resultCount} tarikan budaya ditemui',
                        ),
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
                  label: Text(
                    _t(
                      en: 'Update',
                      zh: '更新位置',
                      ms: 'Kemas Kini',
                    ),
                  ),
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
                          ? _t(
                        en: 'Filters are active',
                        zh: '筛选条件已启用',
                        ms: 'Penapis sedang digunakan',
                      )
                          : _t(
                        en: 'Filter by cultural category',
                        zh: '按文化类别筛选',
                        ms: 'Tapis mengikut kategori budaya',
                      ),
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
                      child: Text(
                        _t(
                          en: 'Clear',
                          zh: '清除',
                          ms: 'Kosongkan',
                        ),
                      ),
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
                  label: Text(
                    _categoryText(category),
                  ),
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
                    _t(
                      en: 'Cultural places',
                      zh: '文化景点',
                      ms: 'Tempat budaya',
                    ),
                    style:
                    Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  _t(
                    en: '${viewModel.resultCount} found',
                    zh: '找到 ${viewModel.resultCount} 个',
                    ms: '${viewModel.resultCount} ditemui',
                  ),
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
                      _nameText(attraction),
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
                      _categoryText(category),
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
                            _distanceText(
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
              const SizedBox(width: 4),
              Column(
                children: [
                  IconButton(
                    tooltip: isFavourite
                        ? _t(
                      en: 'Remove from Favourites',
                      zh: '从收藏中移除',
                      ms: 'Alih Keluar daripada Kegemaran',
                    )
                        : _t(
                      en: 'Save to Favourites',
                      zh: '保存到收藏',
                      ms: 'Simpan ke Kegemaran',
                    ),
                    padding: EdgeInsets.zero,
                    constraints:
                    const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    visualDensity:
                    VisualDensity.compact,
                    onPressed: () =>
                        _toggleFavourite(
                          attraction,
                        ),
                    icon: Icon(
                      isFavourite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: isFavourite
                          ? colorScheme.error
                          : colorScheme.onSurfaceVariant,
                      size: 21,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color:
                    colorScheme.onSurfaceVariant,
                    size: 20,
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
            _t(
              en: 'No matching cultural attractions',
              zh: '没有符合条件的文化景点',
              ms: 'Tiada tarikan budaya yang sepadan',
            ),
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
                ? _t(
              en: 'Try changing or clearing your filters.',
              zh: '请尝试更改或清除筛选条件。',
              ms: 'Cuba ubah atau kosongkan penapis anda.',
            )
                : _t(
              en: 'No supported attraction is available in this area yet.',
              zh: '此区域目前没有受支持的文化景点。',
              ms: 'Belum ada tarikan yang disokong di kawasan ini.',
            ),
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
            _errorText(
              viewModel.errorMessage,
            ),
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
            label: Text(
              _t(
                en: 'Try Again',
                zh: '重试',
                ms: 'Cuba Lagi',
              ),
            ),
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

  final AppSettingsController _settings =
      AppSettingsController.instance;

  _FullEtiquetteGuidePage({
    required this.name,
    required this.category,
    required this.dos,
    required this.donts,
  });

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
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      appBar:
      AppBar(
        title:
        Text(
          _t(
            en: 'Etiquette Guide',
            zh: '礼仪指南',
            ms: 'Panduan Etika',
          ),
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
            _t(
              en: 'Ranked specifically for this attraction.',
              zh: '此排名专门针对这个景点。',
              ms: 'Kedudukan ini khusus untuk tarikan ini.',
            ),
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
            title: _t(
              en: '✅ DO',
              zh: '✅ 应该做',
              ms: '✅ BOLEH',
            ),
            titleColor:
            Colors.green,
            items: dos,
          ),

          const SizedBox(
            height: 18,
          ),

          _RankedGuideSection(
            title: _t(
              en: "❌ DON'T",
              zh: '❌ 不应该做',
              ms: '❌ JANGAN',
            ),
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

  final AppSettingsController _settings =
      AppSettingsController.instance;

  _RankedGuideSection({
    required this.title,
    required this.titleColor,
    required this.items,
  });

  String _ruleText(
      Map<String, dynamic> item,
      ) {
    final english =
    (item['ruleName'] ?? 'Etiquette rule')
        .toString()
        .trim();
    final chinese =
    (item['ruleNameZh'] ?? '').toString().trim();
    final malay =
    (item['ruleNameMs'] ?? '').toString().trim();

    switch (_settings.language) {
      case AppLanguage.chinese:
        return chinese.isNotEmpty
            ? chinese
            : english;
      case AppLanguage.malay:
        return malay.isNotEmpty
            ? malay
            : english;
      case AppLanguage.english:
        return english;
    }
  }

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
            Text(
              _settings.text(
                en: 'No information available.',
                zh: '暂无相关信息。',
                ms: 'Tiada maklumat tersedia.',
              ),
            )
          else
            ...items.map(
                  (item) {
                final rank =
                _intValue(
                  item['rank'],
                );

                final ruleName =
                _ruleText(
                  item,
                );

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