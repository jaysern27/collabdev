import 'package:flutter/foundation.dart';

import '../../../data_layer/model/repositories/attraction/attraction_repository.dart';
import '../../../data_layer/model/repositories/etiquette/etiquette_repository.dart';
import '../../../data_layer/model/repositories/ranking_report/ranking_report_repository.dart';

// UC02 – Receive Etiquette Alert (Basic Flow steps 8-9, A2).
//
// Backs the screen the Tourist lands on after opening the
// etiquette notification: shows the destination's general
// ("default") etiquette list together with its location-specific
// list, plus that location's own violation ranking (Module 4,
// built from Admin-approved UC04 reports) so the Tourist can see
// the most commonly reported issue at that specific attraction.
// Geofence monitoring itself runs in GeofenceAlertMonitorService,
// not here.
class EtiquetteAlertViewModel extends ChangeNotifier {
  final EtiquetteRepository _etiquetteRepository;
  final AttractionRepository _attractionRepository;
  final RankingReportRepository _rankingReportRepository;

  EtiquetteAlertViewModel({
    EtiquetteRepository? etiquetteRepository,
    AttractionRepository? attractionRepository,
    RankingReportRepository? rankingReportRepository,
  })  : _etiquetteRepository =
      etiquetteRepository ?? EtiquetteRepository(),
        _attractionRepository =
            attractionRepository ?? AttractionRepository(),
        _rankingReportRepository =
            rankingReportRepository ?? RankingReportRepository();

  bool _isLoading = false;
  String? _errorMessage;

  String? _attractionId;
  Map<String, dynamic>? _attraction;

  List<Map<String, dynamic>> _defaultRules = [];
  List<Map<String, dynamic>> _locationRules = [];
  List<Map<String, dynamic>> _rankings = [];

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  Map<String, dynamic>? get attraction => _attraction;

  String get attractionName =>
      _attraction?['name']?.toString() ?? 'This attraction';

  List<Map<String, dynamic>> get defaultRules => _defaultRules;

  List<Map<String, dynamic>> get locationRules => _locationRules;

  List<Map<String, dynamic>> get defaultDos =>
      _filterByType(_defaultRules, 'do');

  List<Map<String, dynamic>> get defaultDonts =>
      _filterByType(_defaultRules, 'dont');

  List<Map<String, dynamic>> get locationDos =>
      _filterByType(_locationRules, 'do');

  List<Map<String, dynamic>> get locationDonts =>
      _filterByType(_locationRules, 'dont');

  // This attraction's own violation ranking (Module 4), most
  // commonly reported issue first. Null when there is not yet
  // enough approved-report data for this location.
  Map<String, dynamic>? get topViolation =>
      _rankings.isEmpty ? null : _rankings.first;

  // A2 – Tourist Opens Notification: query the default etiquette
  // list and the location-based etiquette list, then display both.
  Future<void> loadForAttraction(String attractionId) async {
    _attractionId = attractionId;
    _setLoading(true);
    _errorMessage = null;

    try {
      final attraction =
      await _attractionRepository.getAttractionById(attractionId);

      final defaultRules = await _etiquetteRepository
          .getDefaultRulesForAttraction(attractionId);

      final locationRules = await _etiquetteRepository
          .getLocationRulesForAttraction(attractionId);

      // Best-effort: the ranking may not exist yet (too few
      // approved reports), so this should never block the rest of
      // the screen from loading.
      List<Map<String, dynamic>> rankings = [];
      try {
        rankings = await _rankingReportRepository
            .getRankingByAttraction(attractionId);
      } catch (_) {
        rankings = [];
      }

      _attraction = attraction;
      _defaultRules = defaultRules;
      _locationRules = locationRules;
      _rankings = rankings;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> refresh() async {
    final attractionId = _attractionId;

    if (attractionId != null) {
      await loadForAttraction(attractionId);
    }
  }

  List<Map<String, dynamic>> _filterByType(
      List<Map<String, dynamic>> rules,
      String type,
      ) {
    return rules
        .where(
          (rule) =>
      rule['type']?.toString().toLowerCase() == type,
    )
        .toList();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
