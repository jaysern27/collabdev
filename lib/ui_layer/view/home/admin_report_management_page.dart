import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../data_layer/model/repositories/ranking_report/ranking_report_repository.dart';
import '../shared/app_theme.dart';

// Shared with admin_home_page.dart's design language.
const Color _deepPurple = AppColors.primaryDark;
const Color _purple = AppColors.primary;
const Color _background = AppColors.background;
const Color _heading = AppColors.heading;
const Color _muted = AppColors.muted;
const Color _cardBorder = AppColors.cardBorder;
const Color _approveColor = AppColors.success;
const Color _rejectColor = AppColors.danger;


class AdminReportManagementPage extends StatefulWidget {
  const AdminReportManagementPage({
    super.key,
  });

  @override
  State<AdminReportManagementPage> createState() =>
      _AdminReportManagementPageState();
}

class _AdminReportManagementPageState
    extends State<AdminReportManagementPage> {
  final RankingReportRepository _repository =
  RankingReportRepository();

  List<Map<String, dynamic>> _reports =
  <Map<String, dynamic>>[];

  final Set<String> _actingOnIds =
  <String>{};

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final result =
      await _repository.getPendingReports();

      result.sort(
            (a, b) {
          final aDate =
          _parseDate(a['createdAt']);
          final bDate =
          _parseDate(b['createdAt']);

          if (aDate == null &&
              bDate == null) {
            return 0;
          }

          if (aDate == null) {
            return 1;
          }

          if (bDate == null) {
            return -1;
          }

          return bDate.compareTo(aDate);
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _reports = result;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = e
            .toString()
            .replaceFirst(
          'Exception: ',
          '',
        );
      });
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _approveReport(
      Map<String, dynamic> report,
      ) async {
    final id =
        report['id']?.toString() ?? '';

    if (id.isEmpty) {
      return;
    }

    final violations =
    _extractViolations(report);

    final confirmed =
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.verified_rounded,
            color: Color(0xFF148A66),
          ),
          title: const Text(
            'Approve this report?',
          ),
          content: Text(
            violations.length <= 1
                ? 'This verified violation will be included in the ranking.'
                : 'All ${violations.length} selected violations in this report will be included in the ranking.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text(
                'Cancel',
              ),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              style:
              FilledButton.styleFrom(
                backgroundColor:
                _approveColor,
              ),
              icon: const Icon(
                Icons.check_rounded,
              ),
              label: const Text(
                'Approve',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true ||
        !mounted) {
      return;
    }

    setState(() {
      _actingOnIds.add(id);
    });

    try {
      await _repository.approveReport(
        id,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _reports.removeWhere(
              (item) =>
          item['id']?.toString() ==
              id,
        );
      });

      _showMessage(
        violations.length <= 1
            ? 'Report approved. The violation now contributes to ranking.'
            : 'Report approved. ${violations.length} violations now contribute to ranking.',
        backgroundColor:
        _approveColor,
      );
    } catch (e) {
      _showMessage(
        'Unable to approve report: '
            '${e.toString().replaceFirst('Exception: ', '')}',
        backgroundColor:
        _rejectColor,
      );
    }

    if (mounted) {
      setState(() {
        _actingOnIds.remove(id);
      });
    }
  }

  Future<void> _rejectReport(
      Map<String, dynamic> report,
      ) async {
    final id =
        report['id']?.toString() ?? '';

    if (id.isEmpty) {
      return;
    }

    final confirmed =
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.block_rounded,
            color: Color(0xFFB43D3D),
          ),
          title: const Text(
            'Reject this report?',
          ),
          content: const Text(
            'The report will be marked Rejected and none of its selected violations will contribute to the ranking.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text(
                'Cancel',
              ),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              style:
              FilledButton.styleFrom(
                backgroundColor:
                _rejectColor,
              ),
              icon: const Icon(
                Icons.close_rounded,
              ),
              label: const Text(
                'Reject',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true ||
        !mounted) {
      return;
    }

    setState(() {
      _actingOnIds.add(id);
    });

    try {
      await _repository.rejectReport(
        id,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _reports.removeWhere(
              (item) =>
          item['id']?.toString() ==
              id,
        );
      });

      _showMessage(
        'Report rejected. It will not affect the ranking.',
        backgroundColor:
        _rejectColor,
      );
    } catch (e) {
      _showMessage(
        'Unable to reject report: '
            '${e.toString().replaceFirst('Exception: ', '')}',
        backgroundColor:
        _rejectColor,
      );
    }

    if (mounted) {
      setState(() {
        _actingOnIds.remove(id);
      });
    }
  }

  void _showMessage(
      String message, {
        required Color backgroundColor,
      }) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
          backgroundColor,
          behavior:
          SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: _heading,
        title: const Text(
          'Report Management',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: _heading,
          ),
        ),
        actions: [
          IconButton(
            onPressed:
            _isLoading
                ? null
                : _loadReports,
            tooltip:
            'Refresh reports',
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
          const SizedBox(
            width: 4,
          ),
        ],
      ),
      body: SafeArea(
        child: _buildBody(
          context,
        ),
      ),
    );
  }

  Widget _buildBody(
      BuildContext context,
      ) {
    if (_isLoading) {
      return const Center(
        child:
        CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return RefreshIndicator(
        color: _purple,
        onRefresh: _loadReports,
        child: ListView(
          physics:
          const AlwaysScrollableScrollPhysics(),
          padding:
          const EdgeInsets.all(
            22,
          ),
          children: [
            const SizedBox(
              height: 90,
            ),
            _MessageCard(
              icon:
              Icons.cloud_off_rounded,
              title:
              'Unable to load reports',
              message:
              _errorMessage!,
              buttonText:
              'Try Again',
              onPressed:
              _loadReports,
            ),
          ],
        ),
      );
    }

    if (_reports.isEmpty) {
      return RefreshIndicator(
        color: _purple,
        onRefresh: _loadReports,
        child: ListView(
          physics:
          const AlwaysScrollableScrollPhysics(),
          padding:
          const EdgeInsets.all(
            22,
          ),
          children: [
            const SizedBox(
              height: 90,
            ),
            const _MessageCard(
              icon:
              Icons.task_alt_rounded,
              title:
              'All caught up',
              message:
              'There are no pending etiquette reports to review right now.',
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadReports,
      child: ListView(
        physics:
        const AlwaysScrollableScrollPhysics(),
        padding:
        const EdgeInsets.fromLTRB(
          16,
          12,
          16,
          28,
        ),
        children: [
          _buildReviewHeader(
            context,
          ),
          const SizedBox(
            height: 14,
          ),
          ..._reports.map(
                (report) {
              final id =
                  report['id']
                      ?.toString() ??
                      '';

              return _AdminReportCard(
                report: report,
                isActing:
                _actingOnIds
                    .contains(id),
                onApprove: () {
                  _approveReport(
                    report,
                  );
                },
                onReject: () {
                  _rejectReport(
                    report,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReviewHeader(
      BuildContext context,
      ) {
    return Container(
      padding:
      const EdgeInsets.all(
        18,
      ),
      decoration: BoxDecoration(
        gradient:
        const LinearGradient(
          colors: [
            _deepPurple,
            _purple,
          ],
          begin:
          Alignment.topLeft,
          end:
          Alignment.bottomRight,
        ),
        borderRadius:
        BorderRadius.circular(
          22,
        ),
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration:
            BoxDecoration(
              color:
              Colors.white.withValues(
                alpha: 0.16,
              ),
              borderRadius:
              BorderRadius.circular(
                15,
              ),
            ),
            child: const Icon(
              Icons
                  .fact_check_outlined,
              color:
              Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(
            width: 13,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  '${_reports.length} report${_reports.length == 1 ? '' : 's'} waiting for review',
                  style:
                  const TextStyle(
                    color:
                    Colors.white,
                    fontSize:
                    17,
                    fontWeight:
                    FontWeight.w800,
                  ),
                ),
                const SizedBox(
                  height: 5,
                ),
                Text(
                  'Check the detected location, selected DON’T rules and evidence photo before approving.',
                  style:
                  TextStyle(
                    color:
                    Colors.white.withValues(
                      alpha:
                      0.88,
                    ),
                    height: 1.4,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.verified_user_outlined,
            color: Colors.white,
          ),
        ],
      ),
    );
  }
}

class _AdminReportCard
    extends StatelessWidget {
  final Map<String, dynamic> report;
  final bool isActing;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _AdminReportCard({
    required this.report,
    required this.isActing,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    final attractionName =
    (report['attractionName'] ??
        report['attractionId'] ??
        'Unknown attraction')
        .toString();

    final attractionCategory =
        report['attractionCategory']
            ?.toString() ??
            '';

    final userLabel =
    (report['userEmail'] ??
        report['userId'] ??
        'Unknown user')
        .toString();

    final distance =
    _toDouble(
      report[
      'distanceFromAttractionMeters'],
    );

    final latitude =
    _toDouble(
      report['latitude'],
    );

    final longitude =
    _toDouble(
      report['longitude'],
    );

    final violations =
    _extractViolations(report);

    final createdAt =
    _parseDate(
      report['createdAt'],
    );

    final evidence =
    (report['evidencePhotoUrl'] ??
        report['evidenceImageUrl'])
        ?.toString();

    return Container(
      margin:
      const EdgeInsets.only(
        bottom: 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(
          22,
        ),
        border: Border.all(
          color: _cardBorder,
        ),
        boxShadow: [
          BoxShadow(
            color:
            Colors.black.withValues(
              alpha:
              Theme.of(context)
                  .brightness ==
                  Brightness.dark
                  ? 0.18
                  : 0.05,
            ),
            blurRadius:
            16,
            offset:
            const Offset(
              0,
              6,
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
            const EdgeInsets.fromLTRB(
              17,
              17,
              17,
              12,
            ),
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration:
                      BoxDecoration(
                        color: AppColors.tintLight,
                        borderRadius:
                        BorderRadius.circular(
                          14,
                        ),
                      ),
                      child:
                      const Icon(
                        Icons
                            .report_problem_outlined,
                        color: _deepPurple,
                      ),
                    ),
                    const SizedBox(
                      width: 12,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Text(
                            attractionName,
                            style:
                            TextStyle(
                              color: _heading,
                              fontWeight:
                              FontWeight.w800,
                              fontSize:
                              17,
                            ),
                          ),
                          if (attractionCategory
                              .isNotEmpty) ...[
                            const SizedBox(
                              height: 3,
                            ),
                            Text(
                              attractionCategory,
                              style:
                              TextStyle(
                                color: _deepPurple,
                                fontSize:
                                12.5,
                                fontWeight:
                                FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding:
                      const EdgeInsets.symmetric(
                        horizontal:
                        9,
                        vertical:
                        5,
                      ),
                      decoration:
                      BoxDecoration(
                        color:
                        const Color(
                          0xFFFFF0D9,
                        ),
                        borderRadius:
                        BorderRadius.circular(
                          30,
                        ),
                      ),
                      child:
                      const Text(
                        'PENDING',
                        style:
                        TextStyle(
                          color:
                          Color(
                            0xFF8A5A13,
                          ),
                          fontSize:
                          10.5,
                          fontWeight:
                          FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 14,
                ),

                _DetailRow(
                  icon:
                  Icons.person_outline_rounded,
                  label:
                  'Submitted by',
                  value:
                  userLabel,
                ),

                if (createdAt != null)
                  _DetailRow(
                    icon:
                    Icons
                        .schedule_rounded,
                    label:
                    'Submitted',
                    value:
                    _dateText(
                      createdAt,
                    ),
                  ),

                if (distance != null)
                  _DetailRow(
                    icon:
                    Icons
                        .near_me_outlined,
                    label:
                    'Distance',
                    value:
                    _distanceText(
                      distance,
                    ),
                  ),

                if (latitude != null &&
                    longitude != null)
                  _DetailRow(
                    icon:
                    Icons
                        .my_location_rounded,
                    label:
                    'GPS',
                    value:
                    '${latitude.toStringAsFixed(5)}, '
                        '${longitude.toStringAsFixed(5)}',
                  ),

                const SizedBox(
                  height: 14,
                ),

                Row(
                  children: [
                    Icon(
                      Icons
                          .rule_folder_outlined,
                      color: _purple,
                      size: 20,
                    ),
                    const SizedBox(
                      width: 8,
                    ),
                    Text(
                      violations.length == 1
                          ? 'Selected Violation'
                          : 'Selected Violations (${violations.length})',
                      style:
                      TextStyle(
                        color: _heading,
                        fontWeight:
                        FontWeight.w800,
                        fontSize:
                        15,
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 9,
                ),

                if (violations.isEmpty)
                  Text(
                    'No structured violation was found in this report.',
                    style:
                    TextStyle(
                      color: _muted,
                    ),
                  )
                else
                  ...violations
                      .asMap()
                      .entries
                      .map(
                        (entry) {
                      final item =
                          entry.value;

                      return Container(
                        width:
                        double.infinity,
                        margin:
                        const EdgeInsets.only(
                          bottom: 7,
                        ),
                        padding:
                        const EdgeInsets.all(
                          12,
                        ),
                        decoration:
                        BoxDecoration(
                          color: AppColors.tintFaint,
                          borderRadius:
                          BorderRadius.circular(
                            14,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 26,
                              height: 26,
                              alignment:
                              Alignment.center,
                              decoration:
                              const BoxDecoration(
                                color:
                                Color(
                                  0xFFFFE1DB,
                                ),
                                shape:
                                BoxShape.circle,
                              ),
                              child:
                              Text(
                                '${entry.key + 1}',
                                style:
                                const TextStyle(
                                  color:
                                  Color(
                                    0xFFB94B36,
                                  ),
                                  fontSize:
                                  11,
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
                              Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['ruleName']
                                        ?.toString() ??
                                        'Etiquette violation',
                                    style:
                                    TextStyle(
                                      color: _heading,
                                      fontWeight:
                                      FontWeight.w700,
                                      height:
                                      1.35,
                                    ),
                                  ),
                                  const SizedBox(
                                    height: 3,
                                  ),
                                  Text(
                                    item['category']
                                        ?.toString() ??
                                        'Etiquette',
                                    style:
                                    TextStyle(
                                      color: _deepPurple,
                                      fontSize:
                                      11.5,
                                      fontWeight:
                                      FontWeight.w600,
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
          ),

          _EvidenceViewer(
            imageData:
            evidence,
          ),

          Padding(
            padding:
            const EdgeInsets.all(
              17,
            ),
            child: Column(
              children: [
                Container(
                  padding:
                  const EdgeInsets.all(
                    12,
                  ),
                  decoration:
                  BoxDecoration(
                    color:
                    const Color(
                      0xFFFFF6E4,
                    ),
                    borderRadius:
                    BorderRadius.circular(
                      14,
                    ),
                  ),
                  child:
                  const Row(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons
                            .info_outline_rounded,
                        color:
                        Color(
                          0xFF9A6712,
                        ),
                        size:
                        19,
                      ),
                      SizedBox(
                        width:
                        9,
                      ),
                      Expanded(
                        child:
                        Text(
                          'Approve only when the evidence clearly supports the selected violation(s).',
                          style:
                          TextStyle(
                            color:
                            Color(
                              0xFF7A5615,
                            ),
                            fontSize:
                            12,
                            height:
                            1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(
                  height: 14,
                ),
                Row(
                  children: [
                    Expanded(
                      child:
                      OutlinedButton.icon(
                        onPressed:
                        isActing
                            ? null
                            : onReject,
                        style:
                        OutlinedButton.styleFrom(
                          foregroundColor:
                          _rejectColor,
                          side: const BorderSide(
                            color: _rejectColor,
                          ),
                          padding:
                          const EdgeInsets.symmetric(
                            vertical:
                            13,
                          ),
                          shape:
                          RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(
                              14,
                            ),
                          ),
                        ),
                        icon:
                        const Icon(
                          Icons.close_rounded,
                        ),
                        label:
                        const Text(
                          'Reject',
                          style:
                          TextStyle(
                            fontWeight:
                            FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 10,
                    ),
                    Expanded(
                      child:
                      FilledButton.icon(
                        onPressed:
                        isActing
                            ? null
                            : onApprove,
                        style:
                        FilledButton.styleFrom(
                          backgroundColor:
                          _approveColor,
                          foregroundColor:
                          Colors.white,
                          padding:
                          const EdgeInsets.symmetric(
                            vertical:
                            13,
                          ),
                          shape:
                          RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(
                              14,
                            ),
                          ),
                        ),
                        icon:
                        isActing
                            ? const SizedBox(
                          width:
                          17,
                          height:
                          17,
                          child:
                          CircularProgressIndicator(
                            strokeWidth:
                            2,
                            color:
                            Colors.white,
                          ),
                        )
                            : const Icon(
                          Icons.check_rounded,
                        ),
                        label:
                        const Text(
                          'Approve',
                          style:
                          TextStyle(
                            fontWeight:
                            FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow
    extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Padding(
      padding:
      const EdgeInsets.only(
        bottom: 6,
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 16,
            color: _muted,
          ),
          const SizedBox(
            width: 7,
          ),
          SizedBox(
            width: 78,
            child: Text(
              label,
              style:
              TextStyle(
                color: _muted,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style:
              TextStyle(
                color: _heading,
                fontSize: 12.5,
                fontWeight:
                FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EvidenceViewer
    extends StatelessWidget {
  final String? imageData;

  const _EvidenceViewer({
    required this.imageData,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    if (imageData == null ||
        imageData!.trim().isEmpty) {
      return Container(
        margin:
        const EdgeInsets.symmetric(
          horizontal: 17,
        ),
        width:
        double.infinity,
        padding:
        const EdgeInsets.symmetric(
          vertical: 20,
        ),
        decoration:
        BoxDecoration(
          color:
          const Color(
            0xFFFFE8E8,
          ),
          borderRadius:
          BorderRadius.circular(
            14,
          ),
        ),
        child:
        const Column(
          children: [
            Icon(
              Icons
                  .no_photography_outlined,
              color:
              Color(
                0xFFB43D3D,
              ),
            ),
            SizedBox(
              height: 6,
            ),
            Text(
              'No evidence photo',
              style:
              TextStyle(
                color:
                Color(
                  0xFFB43D3D,
                ),
                fontWeight:
                FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    final value =
    imageData!.trim();

    if (value.startsWith('http://') ||
        value.startsWith('https://')) {
      return Padding(
        padding:
        const EdgeInsets.symmetric(
          horizontal: 17,
        ),
        child: ClipRRect(
          borderRadius:
          BorderRadius.circular(
            16,
          ),
          child:
          Image.network(
            value,
            height: 230,
            width:
            double.infinity,
            fit:
            BoxFit.cover,
            loadingBuilder:
                (
                context,
                child,
                loadingProgress,
                ) {
              if (loadingProgress ==
                  null) {
                return child;
              }

              return Container(
                height: 230,
                color: AppColors.tintFaint,
                alignment:
                Alignment.center,
                child:
                CircularProgressIndicator(color: _purple),
              );
            },
            errorBuilder:
                (
                context,
                error,
                stackTrace,
                ) {
              return const _InvalidEvidence();
            },
          ),
        ),
      );
    }

    try {
      String encoded =
          value;

      if (encoded.contains(',')) {
        encoded =
            encoded.split(',').last;
      }

      final bytes =
      base64Decode(encoded);

      return Padding(
        padding:
        const EdgeInsets.symmetric(
          horizontal: 17,
        ),
        child: ClipRRect(
          borderRadius:
          BorderRadius.circular(
            16,
          ),
          child:
          Image.memory(
            bytes,
            height: 230,
            width:
            double.infinity,
            fit:
            BoxFit.cover,
            errorBuilder:
                (
                context,
                error,
                stackTrace,
                ) =>
            const _InvalidEvidence(),
          ),
        ),
      );
    } catch (_) {
      return const Padding(
        padding:
        EdgeInsets.symmetric(
          horizontal: 17,
        ),
        child:
        _InvalidEvidence(),
      );
    }
  }
}

class _InvalidEvidence
    extends StatelessWidget {
  const _InvalidEvidence();

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      height: 150,
      width:
      double.infinity,
      decoration:
      BoxDecoration(
        color:
        const Color(
          0xFFFFE8E8,
        ),
        borderRadius:
        BorderRadius.circular(
          14,
        ),
      ),
      alignment:
      Alignment.center,
      child: const Text(
        'Unable to display evidence photo',
        textAlign:
        TextAlign.center,
        style: TextStyle(
          color:
          Color(
            0xFFB43D3D,
          ),
          fontWeight:
          FontWeight.w700,
        ),
      ),
    );
  }
}

class _MessageCard
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? buttonText;
  final VoidCallback? onPressed;

  const _MessageCard({
    required this.icon,
    required this.title,
    required this.message,
    this.buttonText,
    this.onPressed,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      padding:
      const EdgeInsets.all(
        24,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(
          22,
        ),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 46,
            color: _purple,
          ),
          const SizedBox(
            height: 12,
          ),
          Text(
            title,
            style:
            TextStyle(
              color: _heading,
              fontWeight:
              FontWeight.w800,
              fontSize: 17,
            ),
          ),
          const SizedBox(
            height: 6,
          ),
          Text(
            message,
            textAlign:
            TextAlign.center,
            style:
            TextStyle(
              color: _muted,
              height: 1.4,
            ),
          ),
          if (buttonText != null &&
              onPressed != null) ...[
            const SizedBox(
              height: 15,
            ),
            FilledButton(
              onPressed:
              onPressed,
              child: Text(
                buttonText!,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

List<Map<String, dynamic>>
_extractViolations(
    Map<String, dynamic> report,
    ) {
  final result =
  <Map<String, dynamic>>[];

  final seen =
  <String>{};

  final rawViolations =
  report['violations'];

  if (rawViolations is List) {
    for (final raw
    in rawViolations) {
      if (raw is! Map) {
        continue;
      }

      final item =
      Map<String, dynamic>.from(
        raw,
      );

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
          'Etiquette')
          .toString()
          .trim();

      final key =
          '$ruleName::$category';

      if (seen.add(key)) {
        result.add({
          'ruleName': ruleName,
          'category':
          category.isEmpty
              ? 'Etiquette'
              : category,
        });
      }
    }
  }

  if (result.isNotEmpty) {
    return result;
  }

  final selectedRules =
  report['selectedDontRules'];

  if (selectedRules is List) {
    for (final rawRule
    in selectedRules) {
      final rule =
      rawRule
          .toString()
          .trim();

      if (rule.isEmpty ||
          !seen.add(rule)) {
        continue;
      }

      result.add({
        'ruleName': rule,
        'category':
        _categoryForRule(
          rule,
          fallback:
          report['category']
              ?.toString(),
        ),
      });
    }
  }

  if (result.isNotEmpty) {
    return result;
  }

  final fallback =
  (report['selectedDontRule'] ??
      report['ruleName'] ??
      report['description'] ??
      '')
      .toString()
      .trim();

  if (fallback.isNotEmpty) {
    result.add({
      'ruleName': fallback,
      'category':
      report['category']
          ?.toString() ??
          'Etiquette',
    });
  }

  return result;
}

String _categoryForRule(
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

DateTime? _parseDate(
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

String _dateText(
    DateTime value,
    ) {
  final day =
  value.day
      .toString()
      .padLeft(
    2,
    '0',
  );

  final month =
  value.month
      .toString()
      .padLeft(
    2,
    '0',
  );

  final hour =
  value.hour
      .toString()
      .padLeft(
    2,
    '0',
  );

  final minute =
  value.minute
      .toString()
      .padLeft(
    2,
    '0',
  );

  return '$day/$month/${value.year}  $hour:$minute';
}

double? _toDouble(
    dynamic value,
    ) {
  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(
    value?.toString() ?? '',
  );
}

String _distanceText(
    double meters,
    ) {
  if (meters < 1000) {
    return '${meters.toStringAsFixed(0)} m from attraction';
  }

  return '${(meters / 1000).toStringAsFixed(2)} km from attraction';
}
