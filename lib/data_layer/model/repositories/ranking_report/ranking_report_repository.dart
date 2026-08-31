import '../../services/firestore/firestore_service.dart';

class RankingReportRepository {
  final FirestoreService _firestoreService;

  static const String _reportCollection = 'etiquette_reports';
  static const String _rankingCollection = 'etiquette_rankings';

  RankingReportRepository({
    FirestoreService? firestoreService,
  }) : _firestoreService =
      firestoreService ?? FirestoreService();

  // Submit a new etiquette report
  Future<String> submitReport({
    required String userId,
    required String attractionId,
    required String category,
    required String description,
    String? evidenceImageUrl,
  }) async {
    final document = await _firestoreService.addDocument(
      collection: _reportCollection,
      data: {
        'userId': userId,
        'attractionId': attractionId,
        'category': category,
        'description': description,
        'evidenceImageUrl': evidenceImageUrl,
        'status': 'pending',
        'createdAt': DateTime.now().toIso8601String(),
      },
    );

    return document.id;
  }

  // Get reports submitted by one user
  Future<List<Map<String, dynamic>>> getReportsByUser(
      String userId,
      ) async {
    final reports = await _getAllReports();

    return reports
        .where(
          (report) => report['userId'] == userId,
    )
        .toList();
  }

  // Get reports for an attraction
  Future<List<Map<String, dynamic>>> getReportsByAttraction(
      String attractionId,
      ) async {
    final reports = await _getAllReports();

    return reports
        .where(
          (report) =>
      report['attractionId'] == attractionId,
    )
        .toList();
  }

  // Get pending reports for admin review
  Future<List<Map<String, dynamic>>> getPendingReports() async {
    final reports = await _getAllReports();

    return reports
        .where(
          (report) =>
      report['status'] == 'pending',
    )
        .toList();
  }

  // Admin approves report
  Future<void> approveReport(
      String reportId,
      ) async {
    await _firestoreService.updateDocument(
      collection: _reportCollection,
      documentId: reportId,
      data: {
        'status': 'approved',
        'reviewedAt': DateTime.now().toIso8601String(),
      },
    );
  }

  // Admin rejects report
  Future<void> rejectReport(
      String reportId,
      ) async {
    await _firestoreService.updateDocument(
      collection: _reportCollection,
      documentId: reportId,
      data: {
        'status': 'rejected',
        'reviewedAt': DateTime.now().toIso8601String(),
      },
    );
  }

  // Write a computed ranking record (Module 4's Priority Score output).
  // Exposed here so Module 2 (UC02) can display/seed priority data before
  // the real weighted-scoring Cloud Function exists.
  Future<String> addRanking({
    required String attractionId,
    required String ruleId,
    required double priorityScore,
  }) async {
    final document = await _firestoreService.addDocument(
      collection: _rankingCollection,
      data: {
        'attractionId': attractionId,
        'ruleId': ruleId,
        'priorityScore': priorityScore,
        'updatedAt': DateTime.now().toIso8601String(),
      },
    );

    return document.id;
  }

  // Get stored ranking data for one attraction
  Future<List<Map<String, dynamic>>> getRankingByAttraction(
      String attractionId,
      ) async {
    final snapshot = await _firestoreService.getCollection(
      collection: _rankingCollection,
    );

    final rankings = snapshot.docs
        .map(
          (doc) => {
        'id': doc.id,
        ...doc.data(),
      },
    )
        .where(
          (ranking) =>
      ranking['attractionId'] == attractionId,
    )
        .toList();

    rankings.sort(
          (a, b) {
        final scoreA =
        (a['priorityScore'] ?? 0).toDouble();
        final scoreB =
        (b['priorityScore'] ?? 0).toDouble();

        return scoreB.compareTo(scoreA);
      },
    );

    return rankings;
  }

  // Get all reports internally
  Future<List<Map<String, dynamic>>> _getAllReports() async {
    final snapshot = await _firestoreService.getCollection(
      collection: _reportCollection,
    );

    return snapshot.docs
        .map(
          (doc) => {
        'id': doc.id,
        ...doc.data(),
      },
    )
        .toList();
  }

  // Watch ranking updates in real time
  Stream<List<Map<String, dynamic>>> watchRankings() {
    return _firestoreService
        .watchCollection(
      collection: _rankingCollection,
    )
        .map(
          (snapshot) => snapshot.docs
          .map(
            (doc) => {
          'id': doc.id,
          ...doc.data(),
        },
      )
          .toList(),
    );
  }
}