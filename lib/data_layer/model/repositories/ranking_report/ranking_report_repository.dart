import 'package:flutter/foundation.dart';

import '../../services/cloud_functions/cloud_functions_service.dart';
import '../../services/firestore/firestore_service.dart';

class RankingReportRepository {
  final FirestoreService _firestoreService;
  final CloudFunctionsService _cloudFunctionsService;

  static const String _reportCollection = 'etiquette_reports';
  static const String _rankingCollection = 'etiquette_rankings';
  static const String _attractionCollection = 'attractions';

  RankingReportRepository({
    FirestoreService? firestoreService,
    CloudFunctionsService? cloudFunctionsService,
  })  : _firestoreService = firestoreService ?? FirestoreService(),
        _cloudFunctionsService =
            cloudFunctionsService ?? CloudFunctionsService();

  Future<String> submitReport({
    required String userId,
    required String attractionId,
    required String category,
    required String description,
    String? evidenceImageUrl,
    int severity = 3,
    double verificationConfidence = 1.0,
  }) async {
    final document = await _firestoreService.addDocument(
      collection: _reportCollection,
      data: {
        'userId': userId,
        'attractionId': attractionId,
        'category': category,
        'description': description,
        'evidenceImageUrl': evidenceImageUrl,
        'severity': severity.clamp(1, 5),
        'verificationConfidence': verificationConfidence.clamp(0.0, 1.0),
        'status': 'pending',
        'createdAt': DateTime.now().toIso8601String(),
      },
    );
    return document.id;
  }

  Future<List<Map<String, dynamic>>> getReportsByUser(String userId) async {
    final reports = await _getAllReports();
    return reports.where((report) => report['userId'] == userId).toList();
  }

  Future<List<Map<String, dynamic>>> getReportsByAttraction(
      String attractionId,
      ) async {
    final reports = await _getAllReports();
    return reports
        .where((report) => report['attractionId'] == attractionId)
        .toList();
  }

  Future<List<Map<String, dynamic>>> getPendingReports() async {
    final reports = await _getAllReports();
    return reports
        .where((report) => _normaliseStatus(report['status']) == 'pending')
        .toList();
  }

  Future<void> approveReport(String reportId) async {
    await _firestoreService.updateDocument(
      collection: _reportCollection,
      documentId: reportId,
      data: {
        'status': 'approved',
        'reviewedAt': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<void> rejectReport(String reportId) async {
    await _firestoreService.updateDocument(
      collection: _reportCollection,
      documentId: reportId,
      data: {
        'status': 'rejected',
        'reviewedAt': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<List<Map<String, dynamic>>> getRankingByAttraction(
      String attractionId,
      ) async {
    final stored = await _getStoredRankings(attractionId: attractionId);
    if (stored.isNotEmpty) return stored;

    final reports = await _getAllReports();
    return _calculateRankings(
      reports.where((report) => report['attractionId'] == attractionId).toList(),
    );
  }

  /// Reads stored server rankings when available. If the prototype backend has
  /// not generated them yet, it derives a read-only preview from approved
  /// reports using the documented 50/30/20 formula.
  Future<Map<String, dynamic>> getDashboardData({
    String? attractionId,
    String period = 'month',
  }) async {
    final reports = await _getAllReports();
    final attractions = await _getAttractionNames();

    final scopedReports = attractionId == null || attractionId == 'all'
        ? reports
        : reports
        .where((report) => report['attractionId'] == attractionId)
        .toList();

    // Classify report status in one pass. This also makes it easier to
    // diagnose unexpected Firestore values while testing.
    final approved = <Map<String, dynamic>>[];
    final rejected = <Map<String, dynamic>>[];
    final pending = <Map<String, dynamic>>[];
    final unknownStatus = <Map<String, dynamic>>[];

    for (final report in scopedReports) {
      final rawStatus = report['status'];
      final status = _normaliseStatus(rawStatus);

      debugPrint(
        'MODULE 4 REPORT ${report['id']} '
            'rawStatus="$rawStatus" normalisedStatus="$status"',
      );

      if (status == 'approved') {
        approved.add(report);
      } else if (status == 'rejected') {
        rejected.add(report);
      } else if (status == 'pending') {
        pending.add(report);
      } else {
        unknownStatus.add(report);
      }
    }

    List<Map<String, dynamic>> rankings;
    if (attractionId != null && attractionId != 'all') {
      rankings = await _getStoredRankings(attractionId: attractionId);
      if (rankings.isEmpty) rankings = _calculateRankings(scopedReports);
    } else {
      rankings = await _getStoredRankings();
      if (rankings.isEmpty) rankings = _calculateRankings(scopedReports);
    }

    // Verification rate counts only reports that have actually been evaluated.
    // Pending reports are not included in the denominator.
    // Example: 3 approved + 1 rejected = 75%.
    final evaluatedCount = approved.length + rejected.length;
    final verificationRate = evaluatedCount == 0
        ? 0.0
        : (approved.length / evaluatedCount) * 100.0;

    debugPrint(
      'MODULE 4 SUMMARY => '
          'total=${scopedReports.length}, '
          'approved=${approved.length}, '
          'rejected=${rejected.length}, '
          'pending=${pending.length}, '
          'unknown=${unknownStatus.length}, '
          'verificationRate=${verificationRate.toStringAsFixed(1)}%',
    );

    final locationCounts = <String, int>{};
    for (final report in approved) {
      final id = report['attractionId']?.toString() ?? 'Unknown';
      locationCounts[id] = (locationCounts[id] ?? 0) + 1;
    }
    final affectedLocations = locationCounts.entries
        .map((entry) => {
      'attractionId': entry.key,
      'name': attractions[entry.key] ?? entry.key,
      'count': entry.value,
    })
        .toList()
      ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

    return {
      'rankings': rankings,
      'trend': _buildTrend(approved, period: period),
      'totalReports': scopedReports.length,
      'approvedReports': approved.length,
      'rejectedReports': rejected.length,
      'pendingReports': pending.length,
      'verificationRate': verificationRate,
      'affectedLocations': affectedLocations,
      'attractions': attractions.entries
          .map((entry) => {'id': entry.key, 'name': entry.value})
          .toList(),
      'insufficientData': approved.length < 3,
    };
  }

  /// Requests protected server-side recalculation. This does not directly
  /// change ranking documents from the mobile client.
  Future<bool> requestRankingRecalculation({String? attractionId}) async {
    try {
      await _cloudFunctionsService.callFunction(
        functionName: 'recalculateEtiquetteRankings',
        data: {
          if (attractionId != null && attractionId != 'all')
            'attractionId': attractionId,
        },
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Stream<List<Map<String, dynamic>>> watchRankings() {
    return _firestoreService
        .watchCollection(collection: _rankingCollection)
        .map((snapshot) {
      final rows = snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
      rows.sort((a, b) => _score(b).compareTo(_score(a)));
      return rows;
    });
  }

  Future<List<Map<String, dynamic>>> _getAllReports() async {
    final snapshot =
    await _firestoreService.getCollection(collection: _reportCollection);
    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  Future<Map<String, String>> _getAttractionNames() async {
    try {
      final snapshot = await _firestoreService.getCollection(
        collection: _attractionCollection,
      );
      return {
        for (final doc in snapshot.docs)
          doc.id: (doc.data()['name'] ?? doc.id).toString(),
      };
    } catch (_) {
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> _getStoredRankings({
    String? attractionId,
  }) async {
    try {
      final snapshot = await _firestoreService.getCollection(
        collection: _rankingCollection,
      );
      final rankings = snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .where((ranking) =>
      attractionId == null || ranking['attractionId'] == attractionId)
          .toList();
      rankings.sort((a, b) => _score(b).compareTo(_score(a)));
      return rankings;
    } catch (_) {
      return [];
    }
  }

  List<Map<String, dynamic>> _calculateRankings(
      List<Map<String, dynamic>> reports,
      ) {
    final approved = reports
        .where((report) => _normaliseStatus(report['status']) == 'approved')
        .toList();
    if (approved.isEmpty) return [];

    final groups = <String, List<Map<String, dynamic>>>{};
    for (final report in approved) {
      final attractionId = report['attractionId']?.toString() ?? 'unknown';
      final category = report['category']?.toString() ?? 'Other';
      final key = '$attractionId::$category';
      groups.putIfAbsent(key, () => []).add(report);
    }

    final maxFrequency = groups.values
        .map((group) => group.length)
        .fold<int>(1, (current, value) => value > current ? value : current);

    final rows = groups.entries.map((entry) {
      final sample = entry.value.first;
      final frequency = entry.value.length;
      final frequencyScore = frequency / maxFrequency;
      final avgSeverity = entry.value
          .map((r) => _toDouble(r['severity'], fallback: 3.0).clamp(1, 5))
          .reduce((a, b) => a + b) /
          frequency;
      final severityScore = avgSeverity / 5.0;
      final avgConfidence = entry.value
          .map((r) => _toDouble(
        r['verificationConfidence'],
        fallback: 1.0,
      ).clamp(0.0, 1.0))
          .reduce((a, b) => a + b) /
          frequency;

      final priorityScore =
          (0.50 * frequencyScore + 0.30 * severityScore + 0.20 * avgConfidence) *
              100.0;

      return <String, dynamic>{
        'attractionId': sample['attractionId']?.toString() ?? 'unknown',
        'category': sample['category']?.toString() ?? 'Other',
        'ruleName': sample['ruleName']?.toString() ??
            sample['category']?.toString() ??
            'Etiquette issue',
        'frequency': frequency,
        'severity': avgSeverity,
        'verificationConfidence': avgConfidence,
        'priorityScore': priorityScore,
        'insufficientData': frequency < 3,
        'source': 'prototype-preview',
      };
    }).toList();

    rows.sort((a, b) => _score(b).compareTo(_score(a)));
    for (var i = 0; i < rows.length; i++) {
      rows[i]['rank'] = i + 1;
    }
    return rows;
  }

  List<Map<String, dynamic>> _buildTrend(
      List<Map<String, dynamic>> approved, {
        required String period,
      }) {
    final monthly = period == 'month';
    final now = DateTime.now();
    final buckets = <Map<String, dynamic>>[];

    for (var offset = 5; offset >= 0; offset--) {
      late DateTime start;
      late DateTime end;
      late String label;

      if (monthly) {
        final month = DateTime(now.year, now.month - offset, 1);
        start = month;
        end = DateTime(month.year, month.month + 1, 1);
        label = _monthLabel(month.month);
      } else {
        final today = DateTime(now.year, now.month, now.day);
        final monday = today.subtract(Duration(days: today.weekday - 1));
        start = monday.subtract(Duration(days: 7 * offset));
        end = start.add(const Duration(days: 7));
        label = '${start.day}/${start.month}';
      }

      final count = approved.where((report) {
        final date = _parseDate(report['createdAt']);
        return date != null && !date.isBefore(start) && date.isBefore(end);
      }).length;

      buckets.add({'label': label, 'count': count});
    }
    return buckets;
  }

  static String _monthLabel(int month) {
    const labels = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return labels[month - 1];
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    try {
      return DateTime.parse(value.toString()).toLocal();
    } catch (_) {
      return null;
    }
  }

  static String _normaliseStatus(dynamic value) {
    if (value == null) return '';

    // Remove spaces, punctuation and invisible characters so values such as
    // " rejected ", "REJECTED", or a copied value containing a zero-width
    // character are still recognised as "rejected".
    return value
        .toString()
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z]'), '');
  }

  static double _toDouble(dynamic value, {double fallback = 0}) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static double _score(Map<String, dynamic> row) {
    return _toDouble(row['priorityScore']);
  }
}
