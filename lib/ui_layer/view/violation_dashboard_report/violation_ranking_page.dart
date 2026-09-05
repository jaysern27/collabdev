import 'package:flutter/material.dart';

import '../../view_model/settings/app_settings_controller.dart';
import '../../view_model/violation_dashboard_report/violation_dashboard_report_view_model.dart';

class ViolationRankingPage extends StatefulWidget {
  const ViolationRankingPage({
    super.key,
  });

  @override
  State<ViolationRankingPage> createState() =>
      _ViolationRankingPageState();
}

class _ViolationRankingPageState
    extends State<ViolationRankingPage> {
  final ViolationDashboardReportViewModel _viewModel =
  ViolationDashboardReportViewModel();

  final AppSettingsController _settings =
      AppSettingsController.instance;

  @override
  void initState() {
    super.initState();
    _viewModel.addListener(_onChanged);
    _settings.addListener(_onChanged);
    _viewModel.loadDashboard();
  }

  void _onChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onChanged);
    _settings.removeListener(_onChanged);
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _settings.text(
                en: 'Violation Ranking',
                zh: '违规排名',
                ms: 'Kedudukan Pelanggaran',
              ),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 19,
              ),
            ),
            Text(
              _settings.text(
                en: 'Priority etiquette issues',
                zh: '优先礼仪问题',
                ms: 'Isu etika keutamaan',
              ),
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _settings.text(
              en: 'Refresh ranking',
              zh: '刷新排名',
              ms: 'Muat semula kedudukan',
            ),
            onPressed: _viewModel.isRefreshingRanking
                ? null
                : _viewModel.refreshRanking,
            icon: _viewModel.isRefreshingRanking
                ? const SizedBox(
              width: 19,
              height: 19,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            )
                : const Icon(
              Icons.refresh_rounded,
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _viewModel.loadDashboard,
        child: _viewModel.isLoading &&
            _viewModel.rankings.isEmpty
            ? ListView(
          physics:
          const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 260),
            Center(
              child: CircularProgressIndicator(),
            ),
          ],
        )
            : ListView(
          physics:
          const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            16,
            10,
            16,
            28,
          ),
          children: [
            _buildIntroCard(context),
            const SizedBox(height: 14),
            if (_viewModel.rankings.isEmpty)
              _buildEmptyState(context)
            else
              ..._viewModel.rankings
                  .asMap()
                  .entries
                  .map(
                    (entry) => _rankingCard(
                  context,
                  entry.key,
                  entry.value,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntroCard(
      BuildContext context,
      ) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary,
            colorScheme.tertiary,
          ],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.leaderboard_rounded,
            color: Colors.white,
            size: 30,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  _settings.text(
                    en: 'Etiquette Violation Ranking',
                    zh: '礼仪违规排名',
                    ms: 'Kedudukan Pelanggaran Etika',
                  ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _settings.text(
                    en: 'The large number shows approved occurrences. Ranking order still considers frequency, severity and verification confidence.',
                    zh: '右侧大数字表示获批准次数；排名顺序仍会综合出现频率、严重程度和验证可信度。',
                    ms: 'Nombor besar menunjukkan bilangan diluluskan; susunan masih mempertimbangkan kekerapan, keterukan dan keyakinan pengesahan.',
                  ),
                  style: TextStyle(
                    color: Colors.white
                        .withValues(alpha: 0.88),
                    height: 1.4,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _rankingCard(
      BuildContext context,
      int index,
      Map<String, dynamic> row,
      ) {
    final colorScheme =
        Theme.of(context).colorScheme;

    final score = _double(
      row['priorityScore'] ??
          row['score'] ??
          row['rankingScore'],
    );

    final frequency =
    _int(row['frequency']);

    final severity =
    _double(row['severity']);

    final confidence =
    _double(
      row['verificationConfidence'],
    );

    final topFrequency =
    _viewModel.rankings.isEmpty
        ? 0
        : _int(
      _viewModel
          .rankings.first['frequency'],
    );

    final progressValue =
    topFrequency <= 0
        ? 0.0
        : (frequency / topFrequency)
        .clamp(0.0, 1.0);

    final title =
        row['ruleName']?.toString() ??
            row['category']?.toString() ??
            _settings.text(
              en: 'Etiquette issue',
              zh: '礼仪问题',
              ms: 'Isu etika',
            );

    final isTopThree = index < 3;

    return Container(
      margin: const EdgeInsets.only(
        bottom: 11,
      ),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isTopThree
              ? colorScheme.primary
              .withValues(alpha: 0.35)
              : colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isTopThree
                  ? colorScheme.primaryContainer
                  : colorScheme.surfaceContainerHighest,
              borderRadius:
              BorderRadius.circular(14),
            ),
            child: Text(
              '#${index + 1}',
              style: TextStyle(
                color: isTopThree
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$frequency',
                          style: TextStyle(
                            color:
                            colorScheme.primary,
                            fontSize: 20,
                            fontWeight:
                            FontWeight.w900,
                            height: 1,
                          ),
                        ),
                        Text(
                          _settings.text(
                            en: 'approved',
                            zh: '已批准',
                            ms: 'diluluskan',
                          ),
                          style: TextStyle(
                            color: colorScheme
                                .onSurfaceVariant,
                            fontSize: 9,
                            fontWeight:
                            FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius:
                  BorderRadius.circular(30),
                  child: LinearProgressIndicator(
                    value: progressValue,
                    minHeight: 7,
                    backgroundColor:
                    colorScheme.surfaceContainerHighest,
                  ),
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 10,
                  runSpacing: 5,
                  children: [
                    _meta(
                      context,
                      Icons.analytics_outlined,
                      _settings.text(
                        en: 'Priority ${score.toStringAsFixed(0)} pts',
                        zh: '优先级 ${score.toStringAsFixed(0)} 分',
                        ms: 'Keutamaan ${score.toStringAsFixed(0)} mata',
                      ),
                    ),
                    _meta(
                      context,
                      Icons.warning_amber_rounded,
                      _settings.text(
                        en: 'Severity ${severity.toStringAsFixed(1)}/5',
                        zh: '严重度 ${severity.toStringAsFixed(1)}/5',
                        ms: 'Keterukan ${severity.toStringAsFixed(1)}/5',
                      ),
                    ),
                    _meta(
                      context,
                      Icons.verified_outlined,
                      _settings.text(
                        en: 'Confidence ${(confidence * 100).toStringAsFixed(0)}%',
                        zh: '可信度 ${(confidence * 100).toStringAsFixed(0)}%',
                        ms: 'Keyakinan ${(confidence * 100).toStringAsFixed(0)}%',
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

  Widget _meta(
      BuildContext context,
      IconData icon,
      String text,
      ) {
    final color =
        Theme.of(context)
            .colorScheme
            .onSurfaceVariant;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(
      BuildContext context,
      ) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 42,
            color: colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            _settings.text(
              en: 'No ranking data yet',
              zh: '暂无排名数据',
              ms: 'Belum ada data kedudukan',
            ),
            style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _settings.text(
              en: 'Approved etiquette reports will appear here after evaluation.',
              zh: '经过评估并获批准的礼仪报告会显示在这里。',
              ms: 'Laporan etika yang diluluskan akan dipaparkan di sini selepas penilaian.',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  int _int(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(
      value?.toString() ?? '',
    ) ??
        0;
  }

  double _double(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(
      value?.toString() ?? '',
    ) ??
        0.0;
  }
}
