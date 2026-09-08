import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../data_layer/model/repositories/ranking_report/ranking_report_repository.dart';
import '../../view_model/settings/app_settings_controller.dart';
import '../shared/app_theme.dart';

// Shared with admin_home_page.dart's design language.
const Color _deepPurple = Color(0xFF123B61);
const Color _purple = Color(0xFF00A77E);
const Color _approveColor = AppColors.success;
const Color _rejectColor = AppColors.danger;

String _adminT({
  required String en,
  required String zh,
  required String ms,
}) {
  return AppSettingsController.instance.text(
    en: en,
    zh: zh,
    ms: ms,
  );
}

String _adminRuleName(Map<String, dynamic> item) {
  final english =
      (item['ruleName'] ?? 'Etiquette violation').toString().trim();
  final chinese = (item['ruleNameZh'] ?? '').toString().trim();
  final malay = (item['ruleNameMs'] ?? '').toString().trim();

  switch (AppSettingsController.instance.language) {
    case AppLanguage.chinese:
      return chinese.isNotEmpty ? chinese : english;
    case AppLanguage.malay:
      return malay.isNotEmpty ? malay : english;
    case AppLanguage.english:
      return english;
  }
}

String _adminCategory(String value) {
  switch (value.trim()) {
    case 'Dress Code':
      return _adminT(en: 'Dress Code', zh: '穿着规范', ms: 'Kod Pakaian');
    case 'Photography':
      return _adminT(en: 'Photography', zh: '摄影礼仪', ms: 'Fotografi');
    case 'Noise':
      return _adminT(en: 'Noise', zh: '噪音礼仪', ms: 'Bunyi');
    case 'Worship Etiquette':
      return _adminT(en: 'Worship Etiquette', zh: '礼拜礼仪', ms: 'Etika Ibadat');
    case 'Behaviour':
      return _adminT(en: 'Behaviour', zh: '行为礼仪', ms: 'Tingkah Laku');
    case 'Etiquette':
      return _adminT(en: 'Etiquette', zh: '礼仪', ms: 'Etika');
    case 'Islamic Culture':
      return _adminT(en: 'Islamic Culture', zh: '伊斯兰文化', ms: 'Budaya Islam');
    case 'Chinese Culture':
      return _adminT(en: 'Chinese Culture', zh: '华人文化', ms: 'Budaya Cina');
    case 'Indian Culture':
      return _adminT(en: 'Indian Culture', zh: '印度文化', ms: 'Budaya India');
    case 'Historical Landmarks':
      return _adminT(en: 'Historical Landmarks', zh: '历史地标', ms: 'Mercu Tanda Bersejarah');
    default:
      return value;
  }
}


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

  void _onSettingsChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    AppSettingsController.instance.addListener(_onSettingsChanged);
    _loadReports();
  }

  @override
  void dispose() {
    AppSettingsController.instance.removeListener(_onSettingsChanged);
    super.dispose();
  }

  Future<void> _attachLocalizedViolationNames(
    List<Map<String, dynamic>> reports,
  ) async {
    final cache =
        <String, List<Map<String, dynamic>>>{};

    for (final report in reports) {
      final attractionId =
          (report['attractionId'] ?? '')
              .toString()
              .trim();

      if (attractionId.isEmpty) {
        continue;
      }

      List<Map<String, dynamic>> definitions;

      if (cache.containsKey(attractionId)) {
        definitions = cache[attractionId]!;
      } else {
        try {
          final guide =
              await _repository
                  .getEtiquetteGuideRankingByAttraction(
            attractionId,
          );

          definitions =
              List<Map<String, dynamic>>.from(
            guide['donts'] ??
                const <Map<String, dynamic>>[],
          );

          cache[attractionId] = definitions;
        } catch (_) {
          // Localization enrichment must never block Admin review.
          continue;
        }
      }

      final byEnglish =
          <String, Map<String, dynamic>>{};

      for (final definition in definitions) {
        final english =
            (definition['ruleName'] ?? '')
                .toString()
                .trim();

        if (english.isNotEmpty) {
          byEnglish[english.toLowerCase()] =
              definition;
        }
      }

      final existing = report['violations'];

      if (existing is List && existing.isNotEmpty) {
        final enriched =
            <Map<String, dynamic>>[];

        for (final raw in existing) {
          if (raw is! Map) {
            continue;
          }

          final item =
              Map<String, dynamic>.from(raw);

          final english =
              (item['ruleName'] ?? '')
                  .toString()
                  .trim();

          final definition =
              byEnglish[english.toLowerCase()];

          if (definition != null) {
            item['ruleNameZh'] =
                (definition['ruleNameZh'] ?? '')
                    .toString()
                    .trim();

            item['ruleNameMs'] =
                (definition['ruleNameMs'] ?? '')
                    .toString()
                    .trim();

            item['category'] ??=
                definition['category'];
          }

          enriched.add(item);
        }

        report['violations'] = enriched;
        continue;
      }

      // Compatibility with older reports that only saved
      // selectedDontRules.
      final selectedRules =
          report['selectedDontRules'];

      if (selectedRules is List) {
        final enriched =
            <Map<String, dynamic>>[];

        for (final raw in selectedRules) {
          final english =
              raw.toString().trim();

          if (english.isEmpty) {
            continue;
          }

          final definition =
              byEnglish[english.toLowerCase()];

          enriched.add({
            'ruleName': english,
            'ruleNameZh':
                (definition?['ruleNameZh'] ?? '')
                    .toString()
                    .trim(),
            'ruleNameMs':
                (definition?['ruleNameMs'] ?? '')
                    .toString()
                    .trim(),
            'category':
                definition?['category'] ??
                    _categoryForRule(
                      english,
                      fallback:
                          report['category']
                              ?.toString(),
                    ),
          });
        }

        if (enriched.isNotEmpty) {
          report['violations'] = enriched;
        }
      }
    }
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

      await _attachLocalizedViolationNames(
        result,
      );

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
          title: Text(
            _adminT(
              en: 'Approve this report?',
              zh: '批准这份报告？',
              ms: 'Luluskan laporan ini?',
            ),
          ),
          content: Text(
            violations.length <= 1
                ? _adminT(
                    en: 'This verified violation will be included in the ranking.',
                    zh: '此已验证的违规将计入排名。',
                    ms: 'Pelanggaran yang disahkan ini akan dimasukkan dalam kedudukan.',
                  )
                : _adminT(
                    en: 'All ${violations.length} selected violations in this report will be included in the ranking.',
                    zh: '此报告中所选的 ${violations.length} 个违规项目都会计入排名。',
                    ms: 'Kesemua ${violations.length} pelanggaran yang dipilih dalam laporan ini akan dimasukkan dalam kedudukan.',
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: Text(
                _adminT(
                  en: 'Cancel',
                  zh: '取消',
                  ms: 'Batal',
                ),
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
              label: Text(
                _adminT(
                  en: 'Approve',
                  zh: '批准',
                  ms: 'Lulus',
                ),
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
            ? _adminT(
                en: 'Report approved. The violation now contributes to ranking.',
                zh: '报告已批准。该违规现在会计入排名。',
                ms: 'Laporan diluluskan. Pelanggaran kini menyumbang kepada kedudukan.',
              )
            : _adminT(
                en: 'Report approved. ${violations.length} violations now contribute to ranking.',
                zh: '报告已批准。${violations.length} 个违规项目现在会计入排名。',
                ms: 'Laporan diluluskan. ${violations.length} pelanggaran kini menyumbang kepada kedudukan.',
              ),
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
          title: Text(
            _adminT(
              en: 'Reject this report?',
              zh: '拒绝这份报告？',
              ms: 'Tolak laporan ini?',
            ),
          ),
          content: Text(
            _adminT(
              en: 'The report will be marked Rejected and none of its selected violations will contribute to the ranking.',
              zh: '该报告将被标记为已拒绝，其中所选的违规项目都不会计入排名。',
              ms: 'Laporan akan ditandakan sebagai Ditolak dan tiada pelanggaran yang dipilih akan menyumbang kepada kedudukan.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: Text(
                _adminT(
                  en: 'Cancel',
                  zh: '取消',
                  ms: 'Batal',
                ),
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
              label: Text(
                _adminT(
                  en: 'Reject',
                  zh: '拒绝',
                  ms: 'Tolak',
                ),
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
        _adminT(
          en: 'Report rejected. It will not affect the ranking.',
          zh: '报告已拒绝，不会影响排名。',
          ms: 'Laporan ditolak dan tidak akan menjejaskan kedudukan.',
        ),
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        title: Text(
          _adminT(
            en: 'Report Management',
            zh: '报告管理',
            ms: 'Pengurusan Laporan',
          ),
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        actions: [
          IconButton(
            onPressed:
            _isLoading
                ? null
                : _loadReports,
            tooltip:
            _adminT(
              en: 'Refresh reports',
              zh: '刷新报告',
              ms: 'Muat semula laporan',
            ),
            icon: const Icon(
              Icons.refresh_rounded,
              color: Color(0xFF00A77E),
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
        CircularProgressIndicator(
          color: Color(0xFF00A77E),
        ),
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
              _adminT(
                en: 'Unable to load reports',
                zh: '无法加载报告',
                ms: 'Tidak dapat memuatkan laporan',
              ),
              message:
              _errorMessage!,
              buttonText:
              _adminT(
                en: 'Try Again',
                zh: '重试',
                ms: 'Cuba Lagi',
              ),
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
            _MessageCard(
              icon:
              Icons.task_alt_rounded,
              title:
              _adminT(
                en: 'All caught up',
                zh: '全部处理完成',
                ms: 'Semua telah selesai',
              ),
              message:
              _adminT(
                en: 'There are no pending etiquette reports to review right now.',
                zh: '目前没有待审核的礼仪报告。',
                ms: 'Tiada laporan etika yang menunggu semakan buat masa ini.',
              ),
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
    final isDark =
        Theme.of(context).brightness ==
            Brightness.dark;

    return Container(
      constraints:
          const BoxConstraints(
        minHeight: 175,
      ),
      padding:
          const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [
                  Color(0xFF102D45),
                  Color(0xFF0D5F5A),
                ]
              : const [
                  Color(0xFFDDF4FF),
                  Color(0xFFE7FBF5),
                ],
        ),
        borderRadius:
            BorderRadius.circular(28),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -8,
            bottom: -18,
            child: Icon(
              Icons.fact_check_rounded,
              size: 120,
              color:
                  const Color(0xFF00A77E)
                      .withValues(
                alpha:
                    isDark ? 0.18 : 0.10,
              ),
            ),
          ),
          Column(
            mainAxisSize:
                MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration:
                    BoxDecoration(
                  color:
                      const Color(
                    0xFFFFB744,
                  ).withValues(
                    alpha: 0.16,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),
                child: Text(
                  _adminT(
                    en: 'Pending Review',
                    zh: '待审核',
                    ms: 'Menunggu Semakan',
                  ),
                  style:
                      const TextStyle(
                    color:
                        Color(
                      0xFFFF9C12,
                    ),
                    fontSize: 11,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: 270,
                child: Text(
                  _adminT(
                    en:
                        '${_reports.length} report${_reports.length == 1 ? '' : 's'} waiting for review',
                    zh:
                        '有 ${_reports.length} 份报告等待审核',
                    ms:
                        '${_reports.length} laporan menunggu semakan',
                  ),
                  style: TextStyle(
                    color: isDark
                        ? Colors.white
                        : const Color(
                            0xFF123B61,
                          ),
                    fontSize: 20,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 7),
              SizedBox(
                width: 285,
                child: Text(
                  _adminT(
                    en:
                        'Check the detected location, selected DON’T rules and evidence photo before approving.',
                    zh:
                        '批准前请检查检测到的地点、所选“不应该做”规则和证据照片。',
                    ms:
                        'Semak lokasi yang dikesan, peraturan JANGAN yang dipilih dan foto bukti sebelum meluluskan.',
                  ),
                  style: TextStyle(
                    color: isDark
                        ? Colors.white
                            .withValues(
                            alpha: 0.76,
                          )
                        : const Color(
                            0xFF4A6872,
                          ),
                    height: 1.4,
                    fontSize: 12.5,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ),
            ],
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
        _adminT(en: 'Unknown attraction', zh: '未知景点', ms: 'Tarikan tidak diketahui'))
        .toString();

    final attractionCategory =
        report['attractionCategory']
            ?.toString() ??
            '';

    final userLabel =
    (report['userEmail'] ??
        report['userId'] ??
        _adminT(en: 'Unknown user', zh: '未知用户', ms: 'Pengguna tidak diketahui'))
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
    _displayViolations(report);

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
        color: Theme.of(context).colorScheme.surface,
        borderRadius:
        BorderRadius.circular(
          24,
        ),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
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
                              color: Theme.of(context).colorScheme.onSurface,
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
                      Text(
                        _adminT(
                          en: 'PENDING',
                          zh: '待审核',
                          ms: 'MENUNGGU',
                        ),
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
                  _adminT(
                    en: 'Submitted by',
                    zh: '提交者',
                    ms: 'Dihantar oleh',
                  ),
                  value:
                  userLabel,
                ),

                if (createdAt != null)
                  _DetailRow(
                    icon:
                    Icons
                        .schedule_rounded,
                    label:
                    _adminT(
                      en: 'Submitted',
                      zh: '提交时间',
                      ms: 'Dihantar',
                    ),
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
                    _adminT(
                      en: 'Distance',
                      zh: '距离',
                      ms: 'Jarak',
                    ),
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
                          ? _adminT(
                              en: 'Selected Violation',
                              zh: '所选违规',
                              ms: 'Pelanggaran Dipilih',
                            )
                          : _adminT(
                              en: 'Selected Violations (${violations.length})',
                              zh: '所选违规（${violations.length}）',
                              ms: 'Pelanggaran Dipilih (${violations.length})',
                            ),
                      style:
                      TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
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
                    _adminT(
                      en: 'No structured violation was found in this report.',
                      zh: '此报告中未找到结构化违规项目。',
                      ms: 'Tiada pelanggaran berstruktur ditemui dalam laporan ini.',
                    ),
                    style:
                    TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                                TextStyle(
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
                                    _adminRuleName(item),
                                    style:
                                    TextStyle(
                                      color: Theme.of(context).colorScheme.onSurface,
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
                                    _adminCategory(
                                      item['category']
                                          ?.toString() ??
                                          'Etiquette',
                                    ),
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
                  Row(
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
                          _adminT(
                            en: 'Approve only when the evidence clearly supports the selected violation(s).',
                            zh: '仅当证据明确支持所选违规项目时才批准。',
                            ms: 'Luluskan hanya apabila bukti jelas menyokong pelanggaran yang dipilih.',
                          ),
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
                        Text(
                          _adminT(
                            en: 'Reject',
                            zh: '拒绝',
                            ms: 'Tolak',
                          ),
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
                        Text(
                          _adminT(
                            en: 'Approve',
                            zh: '批准',
                            ms: 'Lulus',
                          ),
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
            color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style:
              TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
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
        Column(
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
              _adminT(
                en: 'No evidence photo',
                zh: '没有证据照片',
                ms: 'Tiada foto bukti',
              ),
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
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
      child: Text(
        _adminT(
          en: 'Unable to display evidence photo',
          zh: '无法显示证据照片',
          ms: 'Tidak dapat memaparkan foto bukti',
        ),
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
        color: Theme.of(context).colorScheme.surface,
        borderRadius:
        BorderRadius.circular(
          24,
        ),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
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
              color: Theme.of(context).colorScheme.onSurface,
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
              color: Theme.of(context).colorScheme.onSurfaceVariant,
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
List<Map<String, dynamic>> _displayViolations(
  Map<String, dynamic> report,
) {
  final raw = report['violations'];

  if (raw is List && raw.isNotEmpty) {
    return raw
        .whereType<Map>()
        .map(
          (item) =>
              Map<String, dynamic>.from(item),
        )
        .toList();
  }

  return _extractViolations(report);
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
          'ruleNameZh': item['ruleNameZh'],
          'ruleNameMs': item['ruleNameMs'],
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
    return _adminT(
      en: '${meters.toStringAsFixed(0)} m from attraction',
      zh: '距离景点 ${meters.toStringAsFixed(0)} 米',
      ms: '${meters.toStringAsFixed(0)} m dari tarikan',
    );
  }

  return _adminT(
    en: '${(meters / 1000).toStringAsFixed(2)} km from attraction',
    zh: '距离景点 ${(meters / 1000).toStringAsFixed(2)} 公里',
    ms: '${(meters / 1000).toStringAsFixed(2)} km dari tarikan',
  );
}
