import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../view_model/violation_dashboard_report/violation_dashboard_report_view_model.dart';

class ViolationDashboardReportView extends StatefulWidget {
  const ViolationDashboardReportView({super.key});

  @override
  State<ViolationDashboardReportView> createState() =>
      _ViolationDashboardReportViewState();
}

class _ViolationDashboardReportViewState
    extends State<ViolationDashboardReportView> {
  final ViolationDashboardReportViewModel _viewModel =
  ViolationDashboardReportViewModel();

  @override
  void initState() {
    super.initState();
    _viewModel.addListener(_onChanged);
    _viewModel.loadDashboard();
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {});

    final success = _viewModel.successMessage;
    final error = _viewModel.errorMessage;
    if (success != null || error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(success ?? error!),
              behavior: SnackBarBehavior.floating,
            ),
          );
        _viewModel.clearMessages();
      });
    }
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onChanged);
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9ED),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF9ED),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 4,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Violation Insights',
              style: TextStyle(
                color: Color(0xFF10204A),
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'Etiquette Guidance & Ranking',
              style: TextStyle(
                color: Color(0xFF667085),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh ranking',
            onPressed: _viewModel.isRefreshingRanking
                ? null
                : _viewModel.refreshRanking,
            icon: _viewModel.isRefreshingRanking
                ? const SizedBox(
              width: 19,
              height: 19,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _viewModel.loadDashboard,
        child: _viewModel.isLoading && _viewModel.rankings.isEmpty
            ? ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 260),
            Center(child: CircularProgressIndicator()),
          ],
        )
            : ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            _buildFilterCard(),
            const SizedBox(height: 14),
            if (_viewModel.insufficientData) ...[
              _buildDataNotice(),
              const SizedBox(height: 14),
            ],
            _buildMetrics(),
            const SizedBox(height: 14),
            _buildRankingCard(),
            const SizedBox(height: 14),
            _buildTrendCard(),
            const SizedBox(height: 14),
            _buildLocationsCard(),
            const SizedBox(height: 14),
            _buildFormulaCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterCard() {
    final options = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: 'all', child: Text('All attractions')),
      ..._viewModel.attractions.map(
            (attraction) => DropdownMenuItem(
          value: attraction['id']?.toString(),
          child: Text(
            attraction['name']?.toString() ?? 'Attraction',
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    ];

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dashboard filters',
            style: TextStyle(
              color: Color(0xFF10204A),
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: options.any(
                    (item) => item.value == _viewModel.selectedAttractionId)
                ? _viewModel.selectedAttractionId
                : 'all',
            isExpanded: true,
            decoration: _inputDecoration('Attraction', Icons.place_outlined),
            items: options,
            onChanged: (value) {
              if (value != null) _viewModel.setAttraction(value);
            },
          ),
          const SizedBox(height: 10),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'week',
                label: Text('Weekly'),
                icon: Icon(Icons.view_week_outlined, size: 17),
              ),
              ButtonSegment(
                value: 'month',
                label: Text('Monthly'),
                icon: Icon(Icons.calendar_month_outlined, size: 17),
              ),
            ],
            selected: {_viewModel.selectedPeriod},
            onSelectionChanged: (value) =>
                _viewModel.setPeriod(value.first),
            showSelectedIcon: false,
          ),
        ],
      ),
    );
  }

  Widget _buildDataNotice() {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF2C7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFD66B)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Color(0xFFB87500), size: 20),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              'Insufficient verified data. Rankings are shown as a prototype preview until at least 3 approved reports are available.',
              style: TextStyle(
                color: Color(0xFF7A5400),
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetrics() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _metric(
              width: width,
              icon: Icons.description_outlined,
              label: 'All reports',
              value: _viewModel.totalReports.toString(),
              subtitle: '${_viewModel.pendingReports} pending',
            ),
            _metric(
              width: width,
              icon: Icons.verified_outlined,
              label: 'Approved',
              value: _viewModel.approvedReports.toString(),
              subtitle:
              '${_viewModel.rejectedReports} rejected • '
                  '${_viewModel.verificationRate.toStringAsFixed(0)}% verification rate',
            ),
            _metric(
              width: width,
              icon: Icons.trending_up_rounded,
              label: 'Current trend',
              value: _viewModel.trendDirection(),
              subtitle: _viewModel.selectedPeriod == 'month'
                  ? 'Compared with last month'
                  : 'Compared with last week',
            ),
            _metric(
              width: width,
              icon: Icons.warning_amber_rounded,
              label: 'Top score',
              value: _viewModel.topViolation == null
                  ? '—'
                  : _score(_viewModel.topViolation!).toStringAsFixed(0),
              subtitle: _viewModel.topViolation?['category']?.toString() ??
                  'No ranked violations yet',
            ),
          ],
        );
      },
    );
  }

  Widget _buildRankingCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            'Priority ranking',
            'Highest-priority etiquette issues first',
            Icons.leaderboard_outlined,
          ),
          const SizedBox(height: 12),
          if (_viewModel.rankings.isEmpty)
            _emptyState(
              Icons.analytics_outlined,
              'No ranking data yet',
              'Approved reports will appear here after evaluation.',
            )
          else
            ..._viewModel.rankings.take(8).toList().asMap().entries.map(
                  (entry) => _rankingRow(entry.key, entry.value),
            ),
        ],
      ),
    );
  }

  Widget _rankingRow(int index, Map<String, dynamic> row) {
    final score = _score(row);
    final frequency = _int(row['frequency']);
    final severity = _double(row['severity']);
    final confidence = _double(row['verificationConfidence']);

    return Padding(
      padding: EdgeInsets.only(bottom: index == _viewModel.rankings.length - 1 ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: index < 3
                  ? const Color(0xFFFFE7A6)
                  : const Color(0xFFEAF0FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${index + 1}',
              style: TextStyle(
                color: index < 3
                    ? const Color(0xFF9C6500)
                    : const Color(0xFF315CD6),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        row['ruleName']?.toString() ??
                            row['category']?.toString() ??
                            'Etiquette issue',
                        style: const TextStyle(
                          color: Color(0xFF10204A),
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      score.toStringAsFixed(0),
                      style: const TextStyle(
                        color: Color(0xFF146BD9),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: (score / 100).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: const Color(0xFFE9EEF7),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$frequency reports  •  severity ${severity.toStringAsFixed(1)}/5  •  confidence ${(confidence * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 10.5,
                  ),
                ),
                if (row['insufficientData'] == true)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Low sample size',
                      style: TextStyle(
                        color: Color(0xFFB87500),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            'Violation trend',
            _viewModel.selectedPeriod == 'month'
                ? 'Approved reports by month'
                : 'Approved reports by week',
            Icons.show_chart_rounded,
          ),
          const SizedBox(height: 15),
          SizedBox(
            height: 165,
            width: double.infinity,
            child: _viewModel.trend.isEmpty
                ? _emptyState(
              Icons.query_stats,
              'No trend data yet',
              'Trend points will appear after approved reports are available.',
            )
                : CustomPaint(
              painter: _TrendChartPainter(_viewModel.trend),
            ),
          ),
          const SizedBox(height: 9),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _viewModel.trend
                .map(
                  (item) => Expanded(
                child: Text(
                  item['label']?.toString() ?? '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF7B849B),
                    fontSize: 9.5,
                  ),
                ),
              ),
            )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationsCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            'Most affected locations',
            'Locations with the most approved etiquette reports',
            Icons.place_outlined,
          ),
          const SizedBox(height: 10),
          if (_viewModel.affectedLocations.isEmpty)
            _emptyState(
              Icons.location_off_outlined,
              'No location data yet',
              'Approved reports will be grouped by attraction here.',
            )
          else
            ..._viewModel.affectedLocations.take(5).toList().asMap().entries.map(
                  (entry) => ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: CircleAvatar(
                  radius: 17,
                  backgroundColor: const Color(0xFFDDFDF5),
                  child: Text(
                    '${entry.key + 1}',
                    style: const TextStyle(
                      color: Color(0xFF008E83),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                title: Text(
                  entry.value['name']?.toString() ?? 'Attraction',
                  style: const TextStyle(
                    color: Color(0xFF10204A),
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
                trailing: Text(
                  '${_int(entry.value['count'])} reports',
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFormulaCard() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF08A8AD), Color(0xFF146BD9)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calculate_outlined, color: Colors.white, size: 20),
              SizedBox(width: 7),
              Text(
                'Priority Score Formula',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            '50% Frequency  +  30% Severity  +  20% Verification Confidence',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Only Admin-approved reports contribute to the ranking. Stored server rankings are preferred; the app can show a read-only prototype preview when the Cloud Function is not configured.',
            style: TextStyle(
              color: Color(0xFFEAF7FF),
              fontSize: 10.5,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric({
    required double width,
    required IconData icon,
    required String label,
    required String value,
    required String subtitle,
  }) {
    return SizedBox(
      width: width,
      child: _card(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF146BD9), size: 20),
            const SizedBox(height: 9),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF10204A),
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF36415E),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF8A93A7),
                fontSize: 9.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, String subtitle, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFE9ECFF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF315CD6), size: 19),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF10204A),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF7B849B),
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _emptyState(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 34, color: const Color(0xFFB4BDCF)),
            const SizedBox(height: 7),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF59657D),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF929AAD),
                fontSize: 10.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({required Widget child, EdgeInsets? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0E8DD)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 19),
      filled: true,
      fillColor: const Color(0xFFFFFCF5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE4DED4)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE4DED4)),
      ),
    );
  }

  static int _int(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _double(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _score(Map<String, dynamic> row) => _double(row['priorityScore']);
}

class _TrendChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> points;

  _TrendChartPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final values = points
        .map((point) => (point['count'] as num?)?.toDouble() ?? 0)
        .toList();
    final maxValue = values.fold<double>(1.0, (maxSoFar, value) => math.max(maxSoFar, value).toDouble());
    final left = 8.0;
    final right = size.width - 8.0;
    final top = 12.0;
    final bottom = size.height - 12.0;
    final step = points.length <= 1 ? 0.0 : (right - left) / (points.length - 1);

    final gridPaint = Paint()
      ..color = const Color(0xFFE9EEF7)
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = top + (bottom - top) * i / 3;
      canvas.drawLine(Offset(left, y), Offset(right, y), gridPaint);
    }

    final linePaint = Paint()
      ..color = const Color(0xFF146BD9)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fillPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x553B82F6), Color(0x003B82F6)],
      ).createShader(Rect.fromLTWH(0, top, size.width, bottom - top));

    final path = Path();
    final fillPath = Path();
    for (var i = 0; i < values.length; i++) {
      final x = left + step * i;
      final y = bottom - (values[i] / maxValue) * (bottom - top);
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, bottom);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(left + step * (values.length - 1), bottom);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()..color = const Color(0xFF08A8AD);
    for (var i = 0; i < values.length; i++) {
      final x = left + step * i;
      final y = bottom - (values[i] / maxValue) * (bottom - top);
      canvas.drawCircle(Offset(x, y), 4.2, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) =>
      oldDelegate.points != points;
}
