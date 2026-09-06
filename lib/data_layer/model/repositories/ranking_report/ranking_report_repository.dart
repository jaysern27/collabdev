import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../services/cloud_functions/cloud_functions_service.dart';
import '../../services/firestore/firestore_service.dart';

class RankingReportRepository {
  final FirestoreService _firestoreService;
  final CloudFunctionsService _cloudFunctionsService;

  static const String _reportCollection = 'etiquette_reports';
  static const String _rankingCollection = 'etiquette_rankings';
  static const String _attractionCollection = 'attractions';
  static const String _ruleCollection = 'etiquette_rules';

  RankingReportRepository({
    FirestoreService? firestoreService,
    CloudFunctionsService? cloudFunctionsService,
  })  : _firestoreService =
            firestoreService ?? FirestoreService(),
        _cloudFunctionsService =
            cloudFunctionsService ?? CloudFunctionsService();

  // ---------------------------------------------------------------------------
  // REPORT SUBMISSION
  // ---------------------------------------------------------------------------
  //
  // Kept for compatibility with older code.
  // Newer user-report UI may write directly to Firestore and save:
  //   selectedDontRules: [...]
  //   violations: [{ruleName, category}, ...]
  //
  // Ranking still works for both old and new report formats.
  Future<String> submitReport({
    required String userId,
    required String attractionId,
    required String category,
    required String description,
    String? evidenceImageUrl,
    int severity = 3,
    double verificationConfidence = 0.0,
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

        // A newly submitted report is NOT trusted for ranking yet.
        // Admin approval changes this to 1.0.
        'verificationConfidence':
            verificationConfidence.clamp(0.0, 1.0),

        'status': 'pending',
        'createdAt': DateTime.now().toIso8601String(),
      },
    );

    return document.id;
  }

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

  Future<List<Map<String, dynamic>>> getPendingReports() async {
    final reports = await _getAllReports();

    return reports
        .where(
          (report) =>
              _normaliseStatus(report['status']) ==
              'pending',
        )
        .toList();
  }

  /// Public accessor kept for the existing All Reports / Approved Reports UI.
  Future<List<Map<String, dynamic>>> getAllReports() async {
    return _getAllReports();
  }

  // ---------------------------------------------------------------------------
  // ADMIN REVIEW
  // ---------------------------------------------------------------------------

  /// IMPORTANT:
  /// A report contributes to ranking ONLY after the Admin approves it.
  ///
  /// If one approved report contains 3 selected DON’T rules, each of the
  /// 3 unique violations contributes +1 to its own ranking frequency.
  Future<void> approveReport(
    String reportId,
  ) async {
    await _firestoreService.updateDocument(
      collection: _reportCollection,
      documentId: reportId,
      data: {
        'status': 'approved',
        'verificationConfidence': 1.0,
        'reviewedAt': DateTime.now().toIso8601String(),
      },
    );

    // IMPORTANT FOR THE PROTOTYPE:
    // Rebuild the stored ranking documents immediately from ALL approved
    // reports. This means a newly approved report changes the ranking
    // frequency straight away, even when the Cloud Function is unavailable.
    try {
      await _syncStoredRankingsFromApprovedReports();
    } catch (e) {
      // If Firestore rules protect the ranking collection, approval still
      // succeeds. The UI also recalculates live from approved reports.
      debugPrint(
        'Stored ranking sync skipped: $e',
      );
    }

    // Best-effort protected server recalculation.
    // The local prototype already updated correctly above.
    await requestRankingRecalculation();
  }

  /// Rejected reports never contribute to ranking.
  Future<void> rejectReport(
    String reportId,
  ) async {
    await _firestoreService.updateDocument(
      collection: _reportCollection,
      documentId: reportId,
      data: {
        'status': 'rejected',
        'verificationConfidence': 0.0,
        'reviewedAt': DateTime.now().toIso8601String(),
      },
    );

    // Keep stored ranking documents consistent with approved reports.
    try {
      await _syncStoredRankingsFromApprovedReports();
    } catch (e) {
      debugPrint(
        'Stored ranking sync skipped: $e',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // RANKING
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getRankingByAttraction(
    String attractionId,
  ) async {
    final reports = await _getAllReports();

    // Prefer a live calculation from approved reports so newly approved
    // multi-select violations immediately appear in the prototype.
    final calculated = _calculateRankings(
      reports
          .where(
            (report) =>
                report['attractionId'] == attractionId,
          )
          .toList(),
      groupByAttraction: true,
    );

    if (calculated.isNotEmpty) {
      return calculated;
    }

    // Fallback to stored server ranking documents when there are no
    // approved reports available locally.
    return _getStoredRankings(
      attractionId: attractionId,
    );
  }


  /// Returns the COMPLETE ranked etiquette guide for ONE attraction.
  ///
  /// DO ranking:
  /// - Every DO has a default rank.
  /// - Default rank comes from `doRankingRules.defaultRank` when available.
  /// - Otherwise the current `dos` array order is used.
  /// - DO ranking is static and is NOT changed by violation reports.
  ///
  /// DON'T ranking:
  /// - Every DON'T has a default rank.
  /// - Admin-approved reports for THIS attraction dynamically reprioritise
  ///   matching DON'T rules.
  /// - Pending / rejected reports do not affect ranking.
  /// - Rules with approved report data appear first in dynamic priority order.
  /// - Rules without approved reports keep their original default order.
  ///
  /// This method always returns all current attraction rules, including rules
  /// that have never been reported.
  Future<Map<String, List<Map<String, dynamic>>>>
      getEtiquetteGuideRankingByAttraction(
    String attractionId,
  ) async {
    final attractionSnapshot =
        await FirebaseFirestore.instance
            .collection(_attractionCollection)
            .doc(attractionId)
            .get();

    final attractionData =
        attractionSnapshot.data();

    if (!attractionSnapshot.exists ||
        attractionData == null) {
      return {
        'dos': <Map<String, dynamic>>[],
        'donts': <Map<String, dynamic>>[],
      };
    }

    final dos =
        _toStringList(
      attractionData['dos'],
    );

    final donts =
        _toStringList(
      attractionData['donts'],
    );

    final doDefinitions =
        _toMapList(
      attractionData['doRankingRules'],
    );

    final dontDefinitions =
        _toMapList(
      attractionData['rankingRules'],
    );

    final liveDontRankings =
        await getRankingByAttraction(
      attractionId,
    );

    final liveByRuleId =
        <String, Map<String, dynamic>>{};

    final liveByName =
        <String, Map<String, dynamic>>{};

    for (final ranking
        in liveDontRankings) {
      final ruleId =
          (ranking['ruleId'] ?? '')
              .toString()
              .trim();

      final ruleName =
          (ranking['ruleName'] ?? '')
              .toString()
              .trim();

      if (ruleId.isNotEmpty) {
        liveByRuleId[ruleId] =
            ranking;
      }

      if (ruleName.isNotEmpty) {
        liveByName[
                ruleName.toLowerCase()] =
            ranking;
      }
    }

    final rankedDos =
        <Map<String, dynamic>>[];

    for (var i = 0;
        i < dos.length;
        i++) {
      final ruleName =
          dos[i];

      final definition =
          _matchingRuleDefinition(
        definitions: doDefinitions,
        ruleName: ruleName,
      );

      final defaultRank =
          _positiveInt(
        definition?['defaultRank'],
        fallback: i + 1,
      );

      rankedDos.add({
        'ruleId':
            (definition?['ruleId'] ?? '')
                    .toString()
                    .trim()
                    .isNotEmpty
                ? definition!['ruleId']
                    .toString()
                    .trim()
                : _slug(ruleName),
        'ruleName': ruleName,
        'defaultRank': defaultRank,
        'rank': defaultRank,
        'frequency': 0,
        'hasApprovedReports': false,
        'source': 'default-do-ranking',
      });
    }

    rankedDos.sort(
      (a, b) =>
          _positiveInt(
            a['defaultRank'],
            fallback: 9999,
          ).compareTo(
            _positiveInt(
              b['defaultRank'],
              fallback: 9999,
            ),
          ),
    );

    for (var i = 0;
        i < rankedDos.length;
        i++) {
      rankedDos[i]['rank'] =
          i + 1;
    }

    final rankedDonts =
        <Map<String, dynamic>>[];

    for (var i = 0;
        i < donts.length;
        i++) {
      final ruleName =
          donts[i];

      final definition =
          _matchingRuleDefinition(
        definitions: dontDefinitions,
        ruleName: ruleName,
      );

      final ruleId =
          (definition?['ruleId'] ?? '')
                  .toString()
                  .trim()
                  .isNotEmpty
              ? definition!['ruleId']
                  .toString()
                  .trim()
              : _slug(ruleName);

      final defaultRank =
          _positiveInt(
        definition?['defaultRank'],
        fallback: i + 1,
      );

      final live =
          liveByRuleId[ruleId] ??
              liveByName[
                  ruleName.toLowerCase()];

      final frequency =
          _positiveInt(
        live?['frequency'],
        fallback: 0,
        allowZero: true,
      );

      rankedDonts.add({
        'ruleId': ruleId,
        'ruleName': ruleName,
        'category':
            definition?['category'] ??
                live?['category'] ??
                _categoryForRule(
                  ruleName,
                ),
        'defaultRank': defaultRank,
        'dynamicRank':
            live?['rank'],
        'frequency': frequency,
        'severity':
            live?['severity'] ?? 0.0,
        'verificationConfidence':
            live?[
                    'verificationConfidence'] ??
                0.0,
        'priorityScore':
            live?['priorityScore'] ?? 0.0,
        'hasApprovedReports':
            frequency > 0,
        'source': frequency > 0
            ? 'approved-report-ranking'
            : 'default-dont-ranking',
      });
    }

    rankedDonts.sort(
      (a, b) {
        final aHasData =
            a['hasApprovedReports'] ==
                true;

        final bHasData =
            b['hasApprovedReports'] ==
                true;

        // Approved report data takes priority over default-only rules.
        if (aHasData != bHasData) {
          return aHasData ? -1 : 1;
        }

        // If both rules have approved reports, keep the live per-place
        // ranking produced by the current ranking formula.
        if (aHasData && bHasData) {
          final aDynamicRank =
              _positiveInt(
            a['dynamicRank'],
            fallback: 9999,
          );

          final bDynamicRank =
              _positiveInt(
            b['dynamicRank'],
            fallback: 9999,
          );

          final byDynamicRank =
              aDynamicRank.compareTo(
            bDynamicRank,
          );

          if (byDynamicRank != 0) {
            return byDynamicRank;
          }

          final byScore =
              _toDouble(
                b['priorityScore'],
              ).compareTo(
                _toDouble(
                  a['priorityScore'],
                ),
              );

          if (byScore != 0) {
            return byScore;
          }
        }

        // No approved data (or an exact tie): preserve the attraction's
        // default order.
        return _positiveInt(
          a['defaultRank'],
          fallback: 9999,
        ).compareTo(
          _positiveInt(
            b['defaultRank'],
            fallback: 9999,
          ),
        );
      },
    );

    for (var i = 0;
        i < rankedDonts.length;
        i++) {
      rankedDonts[i]['rank'] =
          i + 1;
    }

    return {
      'dos': rankedDos,
      'donts': rankedDonts,
    };
  }

  /// Dashboard behaviour:
  /// - Pending reports: excluded
  /// - Rejected reports: excluded
  /// - Approved reports: included
  /// - Multi-select report: each unique selected violation is counted once
  ///
  /// When no attraction filter is selected, the ranking aggregates the same
  /// violation rule across attractions so the Home Top 3 does not show
  /// duplicate rows simply because the same rule happened at different places.
  Future<Map<String, dynamic>> getDashboardData({
    String? attractionId,
    String period = 'month',
  }) async {
    final reports = await _getAllReports();
    final attractions = await _getAttractionNames();

    final scopedReports =
        attractionId == null || attractionId == 'all'
            ? reports
            : reports
                .where(
                  (report) =>
                      report['attractionId'] ==
                      attractionId,
                )
                .toList();

    final approved = scopedReports
        .where(
          (report) =>
              _normaliseStatus(report['status']) ==
              'approved',
        )
        .toList();

    final rejected = scopedReports
        .where(
          (report) =>
              _normaliseStatus(report['status']) ==
              'rejected',
        )
        .toList();

    final pending = scopedReports
        .where(
          (report) =>
              _normaliseStatus(report['status']) ==
              'pending',
        )
        .toList();

    List<Map<String, dynamic>> rankings =
        _calculateRankings(
      scopedReports,
      groupByAttraction:
          attractionId != null && attractionId != 'all',
    );

    // Only use stored ranking documents when there is no live approved data.
    if (rankings.isEmpty) {
      rankings = await _getStoredRankings(
        attractionId:
            attractionId != null && attractionId != 'all'
                ? attractionId
                : null,
      );
    }

    final locationCounts = <String, int>{};

    for (final report in approved) {
      final id =
          report['attractionId']?.toString() ??
              'Unknown';

      locationCounts[id] =
          (locationCounts[id] ?? 0) + 1;
    }

    final affectedLocations =
        locationCounts.entries
            .map(
              (entry) => {
                'attractionId': entry.key,
                'name':
                    attractions[entry.key] ??
                        entry.key,
                'count': entry.value,
              },
            )
            .toList()
          ..sort(
            (a, b) =>
                (b['count'] as int).compareTo(
              a['count'] as int,
            ),
          );

    // A report can contain several selected DON'T rules.
    // Dashboard counters should therefore represent the number of individual
    // violation items, not only the number of Firestore report documents.
    final totalViolationCount =
        scopedReports.fold<int>(
      0,
      (total, report) =>
          total + _extractViolations(report).length,
    );

    final approvedViolationCount =
        approved.fold<int>(
      0,
      (total, report) =>
          total + _extractViolations(report).length,
    );

    final rejectedViolationCount =
        rejected.fold<int>(
      0,
      (total, report) =>
          total + _extractViolations(report).length,
    );

    final pendingViolationCount =
        pending.fold<int>(
      0,
      (total, report) =>
          total + _extractViolations(report).length,
    );

    final evaluatedViolationCount =
        approvedViolationCount +
            rejectedViolationCount;

    final violationVerificationRate =
        evaluatedViolationCount == 0
            ? 0.0
            : (approvedViolationCount /
                    evaluatedViolationCount) *
                100.0;

    return {
      'rankings': rankings,
      'trend': _buildTrend(
        approved,
        period: period,
      ),

      // Keep document counts for compatibility / admin pages.
      'totalReports': scopedReports.length,
      'approvedReports': approved.length,
      'rejectedReports': rejected.length,
      'pendingReports': pending.length,

      // Dashboard counters use individual violations.
      'totalViolationCount':
          totalViolationCount,
      'approvedViolationCount':
          approvedViolationCount,
      'rejectedViolationCount':
          rejectedViolationCount,
      'pendingViolationCount':
          pendingViolationCount,

      'verificationRate':
          violationVerificationRate,
      'affectedLocations': affectedLocations,
      'attractions': attractions.entries
          .map(
            (entry) => {
              'id': entry.key,
              'name': entry.value,
            },
          )
          .toList(),

      // Ranking confidence is more meaningful based on the number of
      // approved individual violations, not only report documents.
      'insufficientData':
          approvedViolationCount < 3,
    };
  }

  /// Requests protected server-side recalculation.
  ///
  /// The mobile prototype does not depend on this being successful because
  /// getDashboardData() can calculate ranking from approved Firestore reports.
  Future<bool> requestRankingRecalculation({
    String? attractionId,
  }) async {
    try {
      await _cloudFunctionsService.callFunction(
        functionName:
            'recalculateEtiquetteRankings',
        data: {
          if (attractionId != null &&
              attractionId != 'all')
            'attractionId': attractionId,
        },
      );

      return true;
    } catch (_) {
      return false;
    }
  }

  Stream<List<Map<String, dynamic>>> watchRankings() {
    // Watch REPORTS rather than the stored ranking collection.
    //
    // Why:
    // The hardcoded demo rankings are only snapshots. When an Admin changes
    // a report from pending -> approved, the report document changes
    // immediately. Recalculating from the report stream makes Home Top 3 /
    // ranking widgets update automatically.
    return _firestoreService
        .watchCollection(
          collection: _reportCollection,
        )
        .map(
          (snapshot) {
            final reports = snapshot.docs
                .map(
                  (doc) => {
                    'id': doc.id,
                    ...doc.data(),
                  },
                )
                .toList();

            return _calculateRankings(
              reports,
              groupByAttraction: false,
            );
          },
        );
  }

  // ---------------------------------------------------------------------------
  // PROTOTYPE STORED-RANKING SYNC
  // ---------------------------------------------------------------------------

  /// Rebuilds `etiquette_rankings` from the current APPROVED reports.
  ///
  /// This is a prototype fallback so Admin approval immediately updates both:
  ///   1. the live UI ranking, and
  ///   2. the Firestore `etiquette_rankings` collection.
  ///
  /// In a production deployment this write should normally be performed by
  /// the protected Cloud Function instead of the mobile client.
  Future<void> _syncStoredRankingsFromApprovedReports() async {
    final reports = await _getAllReports();

    final rankings = _calculateRankings(
      reports,
      groupByAttraction: false,
    );

    final FirebaseFirestore firestore =
        FirebaseFirestore.instance;

    // Delete the previous stored ranking snapshot first. This also removes
    // the original hardcoded demo ranking rows, while keeping the demo REPORTS.
    // The demo reports remain the source data and are included again below.
    while (true) {
      final snapshot = await firestore
          .collection(_rankingCollection)
          .limit(400)
          .get();

      if (snapshot.docs.isEmpty) {
        break;
      }

      final WriteBatch deleteBatch =
          firestore.batch();

      for (final doc in snapshot.docs) {
        deleteBatch.delete(doc.reference);
      }

      await deleteBatch.commit();

      if (snapshot.docs.length < 400) {
        break;
      }
    }

    if (rankings.isEmpty) {
      return;
    }

    WriteBatch writeBatch =
        firestore.batch();

    var writesInBatch = 0;

    for (final ranking in rankings) {
      final ruleId =
          (ranking['ruleId'] ?? '')
              .toString()
              .trim();

      final ruleName =
          (ranking['ruleName'] ?? 'Etiquette issue')
              .toString()
              .trim();

      final documentId =
          'global_${_slug(
        ruleId.isNotEmpty ? ruleId : ruleName,
      )}';

      final documentData =
          Map<String, dynamic>.from(ranking);

      documentData['updatedAt'] =
          FieldValue.serverTimestamp();

      documentData['source'] =
          'approved-report-live-sync';


      writeBatch.set(
        firestore
            .collection(_rankingCollection)
            .doc(documentId),
        documentData,
        SetOptions(merge: false),
      );

      writesInBatch++;

      if (writesInBatch >= 400) {
        await writeBatch.commit();
        writeBatch = firestore.batch();
        writesInBatch = 0;
      }
    }

    if (writesInBatch > 0) {
      await writeBatch.commit();
    }
  }

  // ---------------------------------------------------------------------------
  // DATA HELPERS
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>>
      _getAllReports() async {
    final snapshot =
        await _firestoreService.getCollection(
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

  Future<Map<String, String>>
      _getAttractionNames() async {
    try {
      final snapshot =
          await _firestoreService.getCollection(
        collection: _attractionCollection,
      );

      return {
        for (final doc in snapshot.docs)
          doc.id:
              (doc.data()['name'] ?? doc.id)
                  .toString(),
      };
    } catch (_) {
      return {};
    }
  }

  Future<List<Map<String, dynamic>>>
      _getStoredRankings({
    String? attractionId,
  }) async {
    try {
      final snapshot =
          await _firestoreService.getCollection(
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
                attractionId == null ||
                ranking['attractionId'] ==
                    attractionId,
          )
          .toList();

      // GitHub latest compatibility:
      // Stored server ranking rows may contain only a ruleId. Resolve the
      // readable rule name/category from etiquette_rules before sorting.
      await _resolveRuleNames(rankings);

      rankings.sort(
        (a, b) =>
            _score(b).compareTo(
          _score(a),
        ),
      );

      return rankings;
    } catch (_) {
      return [];
    }
  }

  Future<void> _resolveRuleNames(
    List<Map<String, dynamic>> rankings,
  ) async {
    for (final ranking in rankings) {
      if (ranking['ruleName'] != null ||
          ranking['category'] != null) {
        continue;
      }

      final ruleId =
          ranking['ruleId']?.toString();

      if (ruleId == null ||
          ruleId.isEmpty) {
        continue;
      }

      try {
        final ruleDoc =
            await _firestoreService.getDocument(
          collection: _ruleCollection,
          documentId: ruleId,
        );

        if (!ruleDoc.exists) {
          continue;
        }

        final ruleData =
            ruleDoc.data();

        ranking['ruleName'] =
            ruleData?['title'] ??
                ruleData?['description'];

        ranking['category'] =
            ruleData?['ruleCategory'];
      } catch (_) {
        // Keep the existing ranking row if rule lookup is unavailable.
      }
    }
  }

  // ---------------------------------------------------------------------------
  // MULTI-VIOLATION RANKING
  // ---------------------------------------------------------------------------

  List<Map<String, dynamic>> _calculateRankings(
    List<Map<String, dynamic>> reports, {
    required bool groupByAttraction,
  }) {
    final approved = reports
        .where(
          (report) =>
              _normaliseStatus(report['status']) ==
              'approved',
        )
        .toList();

    if (approved.isEmpty) {
      return [];
    }

    // Each item represents ONE verified violation from ONE approved report.
    final violationEvents =
        <Map<String, dynamic>>[];

    for (final report in approved) {
      final violations =
          _extractViolations(report);

      for (final violation in violations) {
        violationEvents.add({
          'reportId': report['id'],
          'attractionId':
              report['attractionId']?.toString() ??
                  'unknown',
          'attractionName':
              report['attractionName']?.toString(),
          'ruleId':
              violation['ruleId']?.toString() ??
                  '',
          'ruleName':
              violation['ruleName']?.toString() ??
                  'Etiquette issue',
          'category':
              violation['category']?.toString() ??
                  'Other',
          'severity': _toDouble(
            report['severity'],
            fallback: 3.0,
          ).clamp(1, 5),
          'verificationConfidence':
              _toDouble(
            report['verificationConfidence'],
            fallback: 1.0,
          ).clamp(0.0, 1.0),
        });
      }
    }

    if (violationEvents.isEmpty) {
      return [];
    }

    final groups =
        <String, List<Map<String, dynamic>>>{};

    for (final event in violationEvents) {
      final attractionId =
          event['attractionId']?.toString() ??
              'unknown';

      final ruleId =
          event['ruleId']?.toString().trim() ?? '';

      final ruleName =
          event['ruleName']?.toString().trim() ??
              'Etiquette issue';

      final ruleKey = ruleId.isNotEmpty
          ? ruleId
          : _slug(ruleName);

      final key = groupByAttraction
          ? '$attractionId::$ruleKey'
          : ruleKey;

      groups
          .putIfAbsent(
            key,
            () => <Map<String, dynamic>>[],
          )
          .add(event);
    }

    final rows =
        groups.entries.map(
      (entry) {
        final sample =
            entry.value.first;

        final frequency =
            entry.value.length;

        final avgSeverity =
            entry.value
                    .map(
                      (event) => _toDouble(
                        event['severity'],
                        fallback: 3.0,
                      ).clamp(1, 5),
                    )
                    .reduce(
                      (a, b) => a + b,
                    ) /
                frequency;

        final severityScore =
            avgSeverity / 5.0;

        final avgConfidence =
            entry.value
                    .map(
                      (event) => _toDouble(
                        event[
                            'verificationConfidence'],
                        fallback: 1.0,
                      ).clamp(0.0, 1.0),
                    )
                    .reduce(
                      (a, b) => a + b,
                    ) /
                frequency;

        // CUMULATIVE PRIORITY POINTS
        //
        // The old implementation normalised frequency against the current
        // highest-frequency rule, which capped the leader at 100.
        //
        // The user-facing prototype now uses cumulative points:
        //   Frequency     = 5 points per approved occurrence
        //   Severity      = up to 30 points
        //   Verification  = up to 20 points
        //
        // This preserves the 50 / 30 / 20 emphasis around the first
        // 10 occurrences, but DOES NOT cap the result at 100.
        //
        // Example with severity 5/5 and confidence 100%:
        //   10 reports = 100 points
        //   11 reports = 105 points
        //   12 reports = 110 points
        final frequencyPoints =
            frequency * 5.0;

        final severityPoints =
            severityScore * 30.0;

        final confidencePoints =
            avgConfidence * 20.0;

        final priorityScore =
            frequencyPoints +
                severityPoints +
                confidencePoints;

        final attractionIds =
            entry.value
                .map(
                  (event) =>
                      event['attractionId']
                          ?.toString() ??
                      'unknown',
                )
                .toSet()
                .toList();

        return <String, dynamic>{
          'attractionId':
              groupByAttraction
                  ? sample['attractionId']
                          ?.toString() ??
                      'unknown'
                  : 'all',

          'attractionIds':
              attractionIds,

          'category':
              sample['category']?.toString() ??
                  'Other',

          'ruleId':
              sample['ruleId']?.toString() ??
                  _slug(
                    sample['ruleName']
                            ?.toString() ??
                        'Etiquette issue',
                  ),

          'ruleName':
              sample['ruleName']?.toString() ??
                  'Etiquette issue',

          'frequency':
              frequency,

          'severity':
              avgSeverity,

          'verificationConfidence':
              avgConfidence,

          'priorityScore':
              priorityScore,

          'insufficientData':
              frequency < 3,

          'source':
              'approved-multi-violation-preview',
        };
      },
    ).toList();

    rows.sort(
      (a, b) =>
          _score(b).compareTo(
        _score(a),
      ),
    );

    for (var i = 0;
        i < rows.length;
        i++) {
      rows[i]['rank'] = i + 1;
    }

    return rows;
  }

  /// Converts both NEW and OLD report formats into a list of unique
  /// individual violations.
  ///
  /// NEW preferred format:
  /// violations: [
  ///   {ruleId: "...", ruleName: "...", category: "..."},
  ///   ...
  /// ]
  ///
  /// Also supports:
  /// selectedDontRules: ["...", "..."]
  ///
  /// OLD fallback:
  /// selectedDontRule / ruleName / category / description
  List<Map<String, dynamic>> _extractViolations(
    Map<String, dynamic> report,
  ) {
    final result =
        <Map<String, dynamic>>[];

    final seen = <String>{};

    final rawViolations =
        report['violations'];

    if (rawViolations is List) {
      for (final raw in rawViolations) {
        if (raw is! Map) {
          continue;
        }

        final item =
            Map<String, dynamic>.from(raw);

        final ruleName =
            (item['ruleName'] ??
                    item['name'] ??
                    '')
                .toString()
                .trim();

        if (ruleName.isEmpty) {
          continue;
        }

        final category =
            (item['category'] ??
                    report['category'] ??
                    'Other')
                .toString()
                .trim();

        final rawRuleId =
            (item['ruleId'] ?? '')
                .toString()
                .trim();

        final ruleId =
            rawRuleId.isNotEmpty
                ? rawRuleId
                : _slug(ruleName);

        final uniqueKey =
            '$ruleId::$category';

        if (seen.add(uniqueKey)) {
          result.add({
            'ruleId': ruleId,
            'ruleName': ruleName,
            'category':
                category.isEmpty
                    ? 'Other'
                    : category,
          });
        }
      }
    }

    if (result.isNotEmpty) {
      return result;
    }

    // Newer compatibility format when only selectedDontRules was saved.
    final selectedDontRules =
        report['selectedDontRules'];

    if (selectedDontRules is List) {
      for (final rawRule
          in selectedDontRules) {
        final ruleName =
            rawRule.toString().trim();

        if (ruleName.isEmpty) {
          continue;
        }

        final category =
            _categoryForRule(
          ruleName,
          fallback:
              report['category']?.toString(),
        );

        final ruleId =
            _slug(ruleName);

        final uniqueKey =
            '$ruleId::$category';

        if (seen.add(uniqueKey)) {
          result.add({
            'ruleId': ruleId,
            'ruleName': ruleName,
            'category': category,
          });
        }
      }
    }

    if (result.isNotEmpty) {
      return result;
    }

    // Old single-violation report fallback.
    final singleRule =
        (report['selectedDontRule'] ??
                report['ruleName'] ??
                report['description'] ??
                report['category'] ??
                '')
            .toString()
            .trim();

    if (singleRule.isEmpty) {
      return [];
    }

    final category =
        (report['category'] ?? 'Other')
            .toString()
            .trim();

    return [
      {
        'ruleId': _slug(singleRule),
        'ruleName': singleRule,
        'category':
            category.isEmpty
                ? 'Other'
                : category,
      },
    ];
  }

  static String _categoryForRule(
    String rule, {
    String? fallback,
  }) {
    final text =
        rule.toLowerCase();

    if (text.contains('wear') ||
        text.contains('dress') ||
        text.contains('clothing') ||
        text.contains('shorts') ||
        text.contains('sleeve') ||
        text.contains('shoe') ||
        text.contains('footwear') ||
        text.contains('pants') ||
        text.contains('trousers') ||
        text.contains('head')) {
      return 'Dress Code';
    }

    if (text.contains('photo') ||
        text.contains('photograph') ||
        text.contains('camera') ||
        text.contains('video') ||
        text.contains('flash')) {
      return 'Photography';
    }

    if (text.contains('noise') ||
        text.contains('quiet') ||
        text.contains('silent') ||
        text.contains('shout') ||
        text.contains('loud')) {
      return 'Noise';
    }

    if (text.contains('worship') ||
        text.contains('ritual') ||
        text.contains('ceremon') ||
        text.contains('prayer')) {
      return 'Worship Etiquette';
    }

    if (text.contains('touch') ||
        text.contains('climb') ||
        text.contains('disturb') ||
        text.contains('litter') ||
        text.contains('restricted')) {
      return 'Behaviour';
    }

    final cleanFallback =
        fallback?.trim() ?? '';

    return cleanFallback.isNotEmpty
        ? cleanFallback
        : 'Etiquette';
  }

  // ---------------------------------------------------------------------------
  // TREND
  // ---------------------------------------------------------------------------

  List<Map<String, dynamic>> _buildTrend(
    List<Map<String, dynamic>> approved, {
    required String period,
  }) {
    final monthly =
        period == 'month';

    final now =
        DateTime.now();

    final buckets =
        <Map<String, dynamic>>[];

    for (var offset = 5;
        offset >= 0;
        offset--) {
      late DateTime start;
      late DateTime end;
      late String label;

      if (monthly) {
        final month = DateTime(
          now.year,
          now.month - offset,
          1,
        );

        start = month;

        end = DateTime(
          month.year,
          month.month + 1,
          1,
        );

        label =
            _monthLabel(month.month);
      } else {
        final today = DateTime(
          now.year,
          now.month,
          now.day,
        );

        final monday =
            today.subtract(
          Duration(
            days:
                today.weekday - 1,
          ),
        );

        start =
            monday.subtract(
          Duration(
            days: 7 * offset,
          ),
        );

        end =
            start.add(
          const Duration(
            days: 7,
          ),
        );

        label =
            '${start.day}/${start.month}';
      }

      // Trend still counts approved REPORTS, not individual rules.
      // This keeps the dashboard's report trend meaning clear.
      final count =
          approved.where(
        (report) {
          final date =
              _parseDate(
            report['createdAt'],
          );

          return date != null &&
              !date.isBefore(start) &&
              date.isBefore(end);
        },
      ).length;

      buckets.add({
        'label': label,
        'count': count,
      });
    }

    return buckets;
  }

  static List<String> _toStringList(
    dynamic value,
  ) {
    if (value is! List) {
      return <String>[];
    }

    return value
        .map(
          (item) =>
              item.toString().trim(),
        )
        .where(
          (item) => item.isNotEmpty,
        )
        .toList();
  }

  static List<Map<String, dynamic>> _toMapList(
    dynamic value,
  ) {
    if (value is! List) {
      return <Map<String, dynamic>>[];
    }

    return value
        .whereType<Map>()
        .map(
          (item) =>
              Map<String, dynamic>.from(
            item,
          ),
        )
        .toList();
  }

  static Map<String, dynamic>? _matchingRuleDefinition({
    required List<Map<String, dynamic>> definitions,
    required String ruleName,
  }) {
    final target =
        ruleName.trim().toLowerCase();

    for (final definition
        in definitions) {
      final candidate =
          (definition['ruleName'] ?? '')
              .toString()
              .trim()
              .toLowerCase();

      if (candidate == target) {
        return definition;
      }
    }

    return null;
  }

  static int _positiveInt(
    dynamic value, {
    required int fallback,
    bool allowZero = false,
  }) {
    final parsed =
        value is num
            ? value.toInt()
            : int.tryParse(
                value?.toString() ?? '',
              );

    if (parsed == null) {
      return fallback;
    }

    if (allowZero) {
      return parsed >= 0
          ? parsed
          : fallback;
    }

    return parsed > 0
        ? parsed
        : fallback;
  }

  // ---------------------------------------------------------------------------
  // BASIC HELPERS
  // ---------------------------------------------------------------------------

  static String _monthLabel(
    int month,
  ) {
    const labels = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return labels[month - 1];
  }

  static DateTime? _parseDate(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is Timestamp) {
      return value.toDate().toLocal();
    }

    if (value is DateTime) {
      return value.toLocal();
    }

    try {
      return DateTime.parse(
        value.toString(),
      ).toLocal();
    } catch (_) {
      return null;
    }
  }

  static String _normaliseStatus(
    dynamic value,
  ) {
    return value
            ?.toString()
            .trim()
            .toLowerCase() ??
        '';
  }

  static double _toDouble(
    dynamic value, {
    double fallback = 0,
  }) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        fallback;
  }

  static double _score(
    Map<String, dynamic> row,
  ) {
    return _toDouble(
      row['priorityScore'],
    );
  }

  static String _slug(
    String value,
  ) {
    final clean =
        value
            .trim()
            .toLowerCase()
            .replaceAll(
              RegExp(r'[^a-z0-9]+'),
              '_',
            )
            .replaceAll(
              RegExp(r'^_+|_+$'),
              '',
            );

    return clean.isEmpty
        ? 'etiquette_issue'
        : clean;
  }
}
