import 'package:flutter/foundation.dart';

import '../../../data_layer/model/repositories/ranking_report/ranking_report_repository.dart';
import '../../../data_layer/model/services/firebase_authentication/firebase_authentication_service.dart';

/// ViewModel for Module 4: Etiquette Guidance & Violation Ranking.
///
/// This version keeps the functions from the original project
/// (report submission, report loading, admin approve/reject)
/// and also includes the newer analytics dashboard functions
/// (priority ranking, filters, trend, verification rate, etc.).
class ViolationDashboardReportViewModel extends ChangeNotifier {
  final RankingReportRepository _rankingReportRepository;
  final FirebaseAuthenticationService _authenticationService;

  ViolationDashboardReportViewModel({
    RankingReportRepository? rankingReportRepository,
    FirebaseAuthenticationService? authenticationService,
  })  : _rankingReportRepository =
      rankingReportRepository ?? RankingReportRepository(),
        _authenticationService =
            authenticationService ?? FirebaseAuthenticationService();

  // ============================================================
  // ORIGINAL REPORT / ADMIN STATE
  // ============================================================

  List<Map<String, dynamic>> _reports = [];
  List<Map<String, dynamic>> _pendingReviewReports = [];

  bool _isSubmitting = false;

  // ============================================================
  // MODULE 4 DASHBOARD STATE
  // ============================================================

  List<Map<String, dynamic>> _rankings = [];
  List<Map<String, dynamic>> _trend = [];
  List<Map<String, dynamic>> _affectedLocations = [];
  List<Map<String, dynamic>> _attractions = [];

  bool _isLoading = false;
  bool _isRefreshingRanking = false;

  String? _errorMessage;
  String? _successMessage;

  String _selectedAttractionId = 'all';
  String _selectedPeriod = 'month';

  int _totalReports = 0;
  int _approvedReports = 0;
  int _rejectedReports = 0;
  int _pendingReports = 0;
  int _unclassifiedReports = 0;

  double _verificationRate = 0.0;

  bool _insufficientData = false;

  // ============================================================
  // GETTERS - ORIGINAL REPORT / ADMIN FUNCTIONS
  // ============================================================

  List<Map<String, dynamic>> get reports => _reports;

  /// Reports that are waiting for admin review.
  ///
  /// This is named differently from [pendingReports], which is the numeric
  /// dashboard count.
  List<Map<String, dynamic>> get pendingReviewReports =>
      List.unmodifiable(_pendingReviewReports);

  /// Compatibility alias for future admin screens.
  List<Map<String, dynamic>> get pendingReportsForReview =>
      List.unmodifiable(_pendingReviewReports);

  bool get isSubmitting => _isSubmitting;

  String? get currentUserId => _authenticationService.currentUser?.uid;

  // ============================================================
  // GETTERS - DASHBOARD
  // ============================================================

  bool get isLoading => _isLoading;

  bool get isRefreshingRanking => _isRefreshingRanking;

  String? get errorMessage => _errorMessage;

  String? get successMessage => _successMessage;

  String get selectedAttractionId => _selectedAttractionId;

  String get selectedPeriod => _selectedPeriod;

  List<Map<String, dynamic>> get rankings => List.unmodifiable(_rankings);

  List<Map<String, dynamic>> get trend => List.unmodifiable(_trend);

  List<Map<String, dynamic>> get affectedLocations =>
      List.unmodifiable(_affectedLocations);

  List<Map<String, dynamic>> get attractions =>
      List.unmodifiable(_attractions);

  int get totalReports => _totalReports;

  int get approvedReports => _approvedReports;

  int get rejectedReports => _rejectedReports;

  /// Numeric pending count used by the dashboard.
  int get pendingReports => _pendingReports;

  int get unclassifiedReports => _unclassifiedReports;

  double get verificationRate => _verificationRate;

  bool get insufficientData => _insufficientData;

  Map<String, dynamic>? get topViolation {
    if (_rankings.isEmpty) {
      return null;
    }
    return _rankings.first;
  }

  // ============================================================
  // ORIGINAL FUNCTION 1 - SUBMIT REPORT
  // ============================================================

  Future<bool> submitReport({
    required String attractionId,
    required String category,
    required String description,
    String? evidenceImageUrl,
  }) async {
    final userId = currentUserId;

    if (userId == null) {
      _errorMessage = 'You must be logged in to submit a report.';
      notifyListeners();
      return false;
    }

    _setSubmitting(true);

    try {
      _errorMessage = null;
      _successMessage = null;

      await _rankingReportRepository.submitReport(
        userId: userId,
        attractionId: attractionId,
        category: category,
        description: description,
        evidenceImageUrl: evidenceImageUrl,
      );

      _successMessage = 'Report submitted successfully.';
      return true;
    } catch (e) {
      _errorMessage = _cleanError(e);
      return false;
    } finally {
      _setSubmitting(false);
    }
  }

  // ============================================================
  // ORIGINAL FUNCTION 2 - LOAD CURRENT USER REPORTS
  // ============================================================

  Future<void> loadMyReports() async {
    final userId = currentUserId;

    if (userId == null) {
      _reports = [];
      _errorMessage = 'You must be logged in to view your reports.';
      notifyListeners();
      return;
    }

    _setLoading(true);

    try {
      _errorMessage = null;

      _reports =
      await _rankingReportRepository.getReportsByUser(userId);
    } catch (e) {
      _errorMessage = _cleanError(e);
    } finally {
      _setLoading(false);
    }
  }

  // ============================================================
  // ORIGINAL FUNCTION 3 - LOAD REPORTS BY ATTRACTION
  // ============================================================

  Future<void> loadReportsByAttraction(
      String attractionId,
      ) async {
    _setLoading(true);

    try {
      _errorMessage = null;

      _reports = await _rankingReportRepository.getReportsByAttraction(
        attractionId,
      );
    } catch (e) {
      _errorMessage = _cleanError(e);
    } finally {
      _setLoading(false);
    }
  }

  // ============================================================
  // ORIGINAL FUNCTION 4 - LOAD RANKING
  // ============================================================

  Future<void> loadRanking(
      String attractionId,
      ) async {
    _setLoading(true);

    try {
      _errorMessage = null;

      _rankings = await _rankingReportRepository.getRankingByAttraction(
        attractionId,
      );
    } catch (e) {
      _errorMessage = _cleanError(e);
    } finally {
      _setLoading(false);
    }
  }

  // ============================================================
  // ORIGINAL FUNCTION 5 - LOAD PENDING REPORTS FOR ADMIN
  // ============================================================

  Future<void> loadPendingReports() async {
    _setLoading(true);

    try {
      _errorMessage = null;

      _pendingReviewReports =
      await _rankingReportRepository.getPendingReports();
    } catch (e) {
      _errorMessage = _cleanError(e);
    } finally {
      _setLoading(false);
    }
  }

  // ============================================================
  // ORIGINAL FUNCTION 6 - APPROVE REPORT
  // ============================================================

  Future<void> approveReport(
      String reportId,
      ) async {
    try {
      _errorMessage = null;
      _successMessage = null;

      await _rankingReportRepository.approveReport(reportId);

      _pendingReviewReports.removeWhere(
            (report) => report['id'] == reportId,
      );

      _successMessage = 'Report approved.';

      notifyListeners();

      // Refresh analytics after approval so Module 4 immediately reflects it.
      await loadDashboard();
    } catch (e) {
      _errorMessage = _cleanError(e);
      notifyListeners();
    }
  }

  // ============================================================
  // ORIGINAL FUNCTION 7 - REJECT REPORT
  // ============================================================

  Future<void> rejectReport(
      String reportId,
      ) async {
    try {
      _errorMessage = null;
      _successMessage = null;

      await _rankingReportRepository.rejectReport(reportId);

      _pendingReviewReports.removeWhere(
            (report) => report['id'] == reportId,
      );

      _successMessage = 'Report rejected.';

      notifyListeners();

      // Refresh dashboard counts / verification rate.
      await loadDashboard();
    } catch (e) {
      _errorMessage = _cleanError(e);
      notifyListeners();
    }
  }

  // ============================================================
  // MODULE 4 - LOAD COMPLETE DASHBOARD
  // ============================================================

  Future<void> loadDashboard() async {
    _setLoading(true);

    try {
      _errorMessage = null;

      final data = await _rankingReportRepository.getDashboardData(
        attractionId: _selectedAttractionId,
        period: _selectedPeriod,
      );

      _rankings = List<Map<String, dynamic>>.from(
        data['rankings'] ?? const [],
      );

      _trend = List<Map<String, dynamic>>.from(
        data['trend'] ?? const [],
      );

      _affectedLocations = List<Map<String, dynamic>>.from(
        data['affectedLocations'] ?? const [],
      );

      _attractions = List<Map<String, dynamic>>.from(
        data['attractions'] ?? const [],
      );

      // Dashboard metrics count INDIVIDUAL selected violations.
      // One Firestore report can contain multiple DON'T rules.
      _totalReports = _asInt(
        data['totalViolationCount'] ??
            data['totalReports'],
      );

      _approvedReports = _asInt(
        data['approvedViolationCount'] ??
            data['approvedReports'],
      );

      _pendingReports = _asInt(
        data['pendingViolationCount'] ??
            data['pendingReports'],
      );

      _rejectedReports = _asInt(
        data['rejectedViolationCount'] ??
            data['rejectedReports'],
      );

      _unclassifiedReports = 0;

      _verificationRate =
          _asDouble(
            data['verificationRate'],
          );

      _insufficientData = data['insufficientData'] == true;

      debugPrint(
        'MODULE 4 VIEWMODEL => '
            'total=$_totalReports, '
            'approved=$_approvedReports, '
            'rejected=$_rejectedReports, '
            'pending=$_pendingReports, '
            'unclassified=$_unclassifiedReports, '
            'verificationRate=${_verificationRate.toStringAsFixed(1)}%',
      );
    } catch (e) {
      _errorMessage = _cleanError(e);
    } finally {
      _setLoading(false);
    }
  }

  // ============================================================
  // MODULE 4 - ATTRACTION FILTER
  // ============================================================

  Future<void> setAttraction(
      String value,
      ) async {
    if (_selectedAttractionId == value) {
      return;
    }

    _selectedAttractionId = value;
    notifyListeners();

    await loadDashboard();
  }

  // ============================================================
  // MODULE 4 - WEEKLY / MONTHLY FILTER
  // ============================================================

  Future<void> setPeriod(
      String value,
      ) async {
    if (_selectedPeriod == value) {
      return;
    }

    if (value != 'week' && value != 'month') {
      return;
    }

    _selectedPeriod = value;
    notifyListeners();

    await loadDashboard();
  }

  // ============================================================
  // MODULE 4 - REQUEST RANKING RECALCULATION
  // ============================================================

  Future<void> refreshRanking() async {
    if (_isRefreshingRanking) {
      return;
    }

    _isRefreshingRanking = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final requested =
      await _rankingReportRepository.requestRankingRecalculation(
        attractionId: _selectedAttractionId,
      );

      if (requested) {
        _successMessage =
        'Ranking recalculation requested successfully.';
      } else {
        _successMessage =
        'Cloud recalculation is not configured yet. '
            'Showing the latest approved-report preview.';
      }

      await loadDashboard();
    } catch (e) {
      _errorMessage = _cleanError(e);
    } finally {
      _isRefreshingRanking = false;
      notifyListeners();
    }
  }

  // ============================================================
  // MODULE 4 - TREND DIRECTION
  // ============================================================

  String trendDirection() {
    if (_trend.length < 2) {
      return 'Stable';
    }

    final previous = _asInt(
      _trend[_trend.length - 2]['count'],
    );

    final current = _asInt(
      _trend.last['count'],
    );

    if (current > previous) {
      return 'Increasing';
    }

    if (current < previous) {
      return 'Decreasing';
    }

    return 'Stable';
  }

  // ============================================================
  // HELPER FUNCTIONS
  // ============================================================

  int getRankNumber(int index) {
    return index + 1;
  }

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  void _setLoading(
      bool value,
      ) {
    _isLoading = value;
    notifyListeners();
  }

  void _setSubmitting(
      bool value,
      ) {
    _isSubmitting = value;
    notifyListeners();
  }

  static int _asInt(
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

  static double _asDouble(
      dynamic value,
      ) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value?.toString() ?? '',
    ) ??
        0.0;
  }

  static String _cleanError(
      Object error,
      ) {
    return error
        .toString()
        .replaceFirst(
      'Exception: ',
      '',
    );
  }
}
