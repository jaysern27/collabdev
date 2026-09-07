import 'package:flutter/foundation.dart';

import '../../../data_layer/model/repositories/attraction/attraction_repository.dart';
import '../../../data_layer/model/repositories/ranking_report/ranking_report_repository.dart';

class EtiquetteAlertViewModel extends ChangeNotifier {
  final AttractionRepository _attractionRepository;
  final RankingReportRepository _rankingReportRepository;

  EtiquetteAlertViewModel({
    AttractionRepository? attractionRepository,
    RankingReportRepository? rankingReportRepository,
  })  : _attractionRepository =
            attractionRepository ?? AttractionRepository(),
        _rankingReportRepository =
            rankingReportRepository ?? RankingReportRepository();

  bool _isLoading = false;
  String? _errorMessage;
  String? _attractionId;
  Map<String, dynamic>? _attraction;

  List<Map<String, dynamic>> _dos = [];
  List<Map<String, dynamic>> _donts = [];

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic>? get attraction => _attraction;

  String get attractionName {
    final name = _attraction?['name']?.toString().trim() ?? '';
    return name.isNotEmpty ? name : 'This attraction';
  }

  List<Map<String, dynamic>> get dos => List.unmodifiable(_dos);
  List<Map<String, dynamic>> get donts => List.unmodifiable(_donts);

  bool get hasGuidance => _dos.isNotEmpty || _donts.isNotEmpty;

  Map<String, dynamic>? get priorityDont =>
      _donts.isEmpty ? null : _donts.first;

  Future<void> loadForAttraction(String attractionId) async {
    _attractionId = attractionId;
    _errorMessage = null;
    _setLoading(true);

    try {
      final attraction =
          await _attractionRepository.getAttractionById(attractionId);

      final guide = await _rankingReportRepository
          .getEtiquetteGuideRankingByAttraction(attractionId);

      _attraction = attraction;
      _dos = List<Map<String, dynamic>>.from(
        guide['dos'] ?? const <Map<String, dynamic>>[],
      );
      _donts = List<Map<String, dynamic>>.from(
        guide['donts'] ?? const <Map<String, dynamic>>[],
      );
    } catch (e) {
      _errorMessage = e.toString();
      _dos = [];
      _donts = [];
    } finally {
      _setLoading(false);
    }
  }

  Future<void> refresh() async {
    final attractionId = _attractionId;
    if (attractionId != null && attractionId.isNotEmpty) {
      await loadForAttraction(attractionId);
    }
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
