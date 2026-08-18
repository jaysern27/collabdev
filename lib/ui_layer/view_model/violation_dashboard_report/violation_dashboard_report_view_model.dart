import 'package:flutter/foundation.dart';

import '../../../data_layer/model/repositories/ranking_report/ranking_report_repository.dart';
import '../../../data_layer/model/services/firebase_authentication/firebase_authentication_service.dart';

class ViolationDashboardReportViewModel
    extends ChangeNotifier {
  final RankingReportRepository _rankingReportRepository;
  final FirebaseAuthenticationService _authenticationService;

  ViolationDashboardReportViewModel({
    RankingReportRepository? rankingReportRepository,
    FirebaseAuthenticationService? authenticationService,
  })  : _rankingReportRepository =
      rankingReportRepository ??
          RankingReportRepository(),
        _authenticationService =
            authenticationService ??
                FirebaseAuthenticationService();

  List<Map<String, dynamic>> _reports = [];
  List<Map<String, dynamic>> _rankings = [];
  List<Map<String, dynamic>> _pendingReports = [];

  bool _isLoading = false;
  bool _isSubmitting = false;

  String? _errorMessage;
  String? _successMessage;

  List<Map<String, dynamic>> get reports => _reports;

  List<Map<String, dynamic>> get rankings => _rankings;

  List<Map<String, dynamic>> get pendingReports =>
      _pendingReports;

  bool get isLoading => _isLoading;

  bool get isSubmitting => _isSubmitting;

  String? get errorMessage => _errorMessage;

  String? get successMessage => _successMessage;

  String? get currentUserId =>
      _authenticationService.currentUser?.uid;

  // Submit a new etiquette violation report
  Future<bool> submitReport({
    required String attractionId,
    required String category,
    required String description,
    String? evidenceImageUrl,
  }) async {
    final userId = currentUserId;

    if (userId == null) {
      _errorMessage =
      'You must be logged in to submit a report.';

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

      _successMessage =
      'Report submitted successfully.';

      return true;
    } catch (e) {
      _errorMessage = e.toString();

      return false;
    } finally {
      _setSubmitting(false);
    }
  }

  // Load reports submitted by current user
  Future<void> loadMyReports() async {
    final userId = currentUserId;

    if (userId == null) {
      _reports = [];

      _errorMessage =
      'You must be logged in to view your reports.';

      notifyListeners();

      return;
    }

    _setLoading(true);

    try {
      _errorMessage = null;

      _reports =
      await _rankingReportRepository
          .getReportsByUser(userId);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // Load reports for a selected attraction
  Future<void> loadReportsByAttraction(
      String attractionId,
      ) async {
    _setLoading(true);

    try {
      _errorMessage = null;

      _reports =
      await _rankingReportRepository
          .getReportsByAttraction(
        attractionId,
      );
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // Load ranked etiquette violations
  Future<void> loadRanking(
      String attractionId,
      ) async {
    _setLoading(true);

    try {
      _errorMessage = null;

      _rankings =
      await _rankingReportRepository
          .getRankingByAttraction(
        attractionId,
      );
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // Load reports waiting for admin review
  Future<void> loadPendingReports() async {
    _setLoading(true);

    try {
      _errorMessage = null;

      _pendingReports =
      await _rankingReportRepository
          .getPendingReports();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // Admin approves a report
  Future<void> approveReport(
      String reportId,
      ) async {
    try {
      _errorMessage = null;

      await _rankingReportRepository
          .approveReport(reportId);

      _pendingReports.removeWhere(
            (report) => report['id'] == reportId,
      );

      _successMessage = 'Report approved.';

      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();

      notifyListeners();
    }
  }

  // Admin rejects a report
  Future<void> rejectReport(
      String reportId,
      ) async {
    try {
      _errorMessage = null;

      await _rankingReportRepository
          .rejectReport(reportId);

      _pendingReports.removeWhere(
            (report) => report['id'] == reportId,
      );

      _successMessage = 'Report rejected.';

      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();

      notifyListeners();
    }
  }

  // Ranking number for UI
  int getRankNumber(int index) {
    return index + 1;
  }

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;

    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;

    notifyListeners();
  }

  void _setSubmitting(bool value) {
    _isSubmitting = value;

    notifyListeners();
  }
}