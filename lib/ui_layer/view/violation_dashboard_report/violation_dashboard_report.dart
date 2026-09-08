import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../view_model/settings/app_settings_controller.dart';

import 'all_reports_page.dart';
import 'approved_reports_page.dart';
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

final AppSettingsController _settings =
AppSettingsController.instance;

String _t({
required String en,
required String zh,
required String ms,
}) {
return _settings.text(en: en, zh: zh, ms: ms);
}

String _localizedRuleName(Map<String, dynamic> row) {
final english = (row['ruleName'] ?? row['category'] ?? '').toString().trim();
final chinese = (row['ruleNameZh'] ?? '').toString().trim();
final malay = (row['ruleNameMs'] ?? '').toString().trim();

switch (_settings.language) {
case AppLanguage.chinese:
return chinese.isNotEmpty ? chinese : english;
case AppLanguage.malay:
return malay.isNotEmpty ? malay : english;
case AppLanguage.english:
return english;
}
}

String _localizedTrendDirection() {
final raw = _viewModel.trendDirection().trim().toLowerCase();
if (raw.contains('increas')) {
return _t(en: 'Increasing', zh: '上升', ms: 'Meningkat');
}
if (raw.contains('decreas')) {
return _t(en: 'Decreasing', zh: '下降', ms: 'Menurun');
}
if (raw.contains('stable') || raw.contains('same')) {
return _t(en: 'Stable', zh: '稳定', ms: 'Stabil');
}
return _viewModel.trendDirection();
}

@override
void initState() {
super.initState();
_viewModel.addListener(_onChanged);
_settings.addListener(_onSettingsChanged);
_viewModel.loadDashboard();
}

void _onSettingsChanged() {
if (mounted) setState(() {});
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
_settings.removeListener(_onSettingsChanged);
_viewModel.dispose();
super.dispose();
}

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: Theme.of(context).scaffoldBackgroundColor,
appBar: AppBar(
backgroundColor: Colors.transparent,
surfaceTintColor: Colors.transparent,
elevation: 0,
titleSpacing: 4,
title: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
_t(
en: 'Violation Insights',
zh: '违规分析',
ms: 'Analisis Pelanggaran',
),
style: TextStyle(
color: Theme.of(context).colorScheme.onSurface,
fontSize: 20,
fontWeight: FontWeight.w800,
),
),
Text(
_t(
en: 'Etiquette Guidance & Ranking',
zh: '礼仪指南与排名',
ms: 'Panduan Etika & Kedudukan',
),
style: TextStyle(
color: Theme.of(context).colorScheme.onSurfaceVariant,
fontSize: 11,
fontWeight: FontWeight.w500,
),
),
],
),
actions: [
IconButton(
tooltip: _t(
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
DropdownMenuItem(
value: 'all',
child: Text(
_t(en: 'All attractions', zh: '全部景点', ms: 'Semua tarikan'),
),
),
..._viewModel.attractions.map(
(attraction) => DropdownMenuItem(
value: attraction['id']?.toString(),
child: Text(
attraction['name']?.toString() ??
_t(en: 'Attraction', zh: '景点', ms: 'Tarikan'),
overflow: TextOverflow.ellipsis,
),
),
),
];

return _card(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
_t(en: 'Dashboard filters', zh: '仪表板筛选', ms: 'Penapis papan pemuka'),
style: TextStyle(
color: Theme.of(context).colorScheme.onSurface,
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
decoration: _inputDecoration(
_t(en: 'Attraction', zh: '景点', ms: 'Tarikan'),
Icons.place_outlined,
),
items: options,
onChanged: (value) {
if (value != null) _viewModel.setAttraction(value);
},
),
const SizedBox(height: 10),
SegmentedButton<String>(
segments: [
ButtonSegment(
value: 'week',
label: Text(_t(en: 'Weekly', zh: '每周', ms: 'Mingguan')),
icon: const Icon(Icons.view_week_outlined, size: 17),
),
ButtonSegment(
value: 'month',
label: Text(_t(en: 'Monthly', zh: '每月', ms: 'Bulanan')),
icon: const Icon(Icons.calendar_month_outlined, size: 17),
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
child: Row(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Icon(Icons.info_outline, color: Color(0xFFB87500), size: 20),
const SizedBox(width: 9),
Expanded(
child: Text(
_t(
en: 'Insufficient verified data. Rankings are shown as a prototype preview until at least 3 approved reports are available.',
zh: '已验证数据不足。在至少有 3 份获批准报告之前，排名将以原型预览方式显示。',
ms: 'Data disahkan tidak mencukupi. Kedudukan dipaparkan sebagai pratonton prototaip sehingga sekurang-kurangnya 3 laporan diluluskan tersedia.',
),
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
label: _t(en: 'All violations', zh: '所有违规', ms: 'Semua pelanggaran'),
value: _viewModel.totalReports.toString(),
subtitle: _t(
en: '${_viewModel.pendingReports} pending violations',
zh: '${_viewModel.pendingReports} 个待处理违规',
ms: '${_viewModel.pendingReports} pelanggaran menunggu',
),
onTap: () {
Navigator.push(
context,
MaterialPageRoute(
builder: (context) => const AllReportsPage(),
),
);
},
),
_metric(
width: width,
icon: Icons.verified_outlined,
label: _t(en: 'Approved violations', zh: '已批准违规', ms: 'Pelanggaran diluluskan'),
value: _viewModel.approvedReports.toString(),
subtitle: _t(
en: '${_viewModel.rejectedReports} rejected • ${_viewModel.verificationRate.toStringAsFixed(0)}% verification rate',
zh: '${_viewModel.rejectedReports} 个已拒绝 • 验证率 ${_viewModel.verificationRate.toStringAsFixed(0)}%',
ms: '${_viewModel.rejectedReports} ditolak • kadar pengesahan ${_viewModel.verificationRate.toStringAsFixed(0)}%',
),
onTap: () {
Navigator.push(
context,
MaterialPageRoute(
builder: (context) => const ApprovedReportsPage(),
),
);
},
),
_metric(
width: width,
icon: Icons.trending_up_rounded,
label: _t(en: 'Current trend', zh: '当前趋势', ms: 'Trend semasa'),
value: _localizedTrendDirection(),
subtitle: _viewModel.selectedPeriod == 'month'
? _t(en: 'Compared with last month', zh: '与上个月相比', ms: 'Berbanding bulan lalu')
    : _t(en: 'Compared with last week', zh: '与上周相比', ms: 'Berbanding minggu lalu'),
),
_metric(
width: width,
icon: Icons.warning_amber_rounded,
label: _t(en: 'Top violation count', zh: '最高违规次数', ms: 'Bilangan pelanggaran tertinggi'),
value: _viewModel.topViolation == null
? '—'
    : _int(
_viewModel.topViolation!['frequency'],
).toString(),
subtitle: _viewModel.topViolation == null
? _t(en: 'No ranked violations yet', zh: '暂无违规排名', ms: 'Belum ada pelanggaran berkedudukan')
    : _t(
en: 'Priority ${_score(_viewModel.topViolation!).toStringAsFixed(0)} points',
zh: '优先级 ${_score(_viewModel.topViolation!).toStringAsFixed(0)} 分',
ms: 'Keutamaan ${_score(_viewModel.topViolation!).toStringAsFixed(0)} mata',
),
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
_t(en: 'Priority ranking', zh: '优先级排名', ms: 'Kedudukan keutamaan'),
_t(en: 'Highest-priority etiquette issues first', zh: '优先显示最高优先级的礼仪问题', ms: 'Isu etika berkeutamaan tertinggi dipaparkan dahulu'),
Icons.leaderboard_outlined,
),
const SizedBox(height: 12),
if (_viewModel.rankings.isEmpty)
_emptyState(
Icons.analytics_outlined,
_t(en: 'No ranking data yet', zh: '暂无排名数据', ms: 'Belum ada data kedudukan'),
_t(en: 'Approved reports will appear here after evaluation.', zh: '经过评估并获批准的报告会显示在这里。', ms: 'Laporan yang diluluskan akan dipaparkan di sini selepas penilaian.'),
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

final topScore = _viewModel.rankings.isEmpty
? 0.0
    : _score(_viewModel.rankings.first);

final progressValue = topScore <= 0
? 0.0
    : (score / topScore).clamp(0.0, 1.0);

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
_localizedRuleName(row).isNotEmpty
? _localizedRuleName(row)
: _t(en: 'Etiquette issue', zh: '礼仪问题', ms: 'Isu etika'),
style: TextStyle(
color: Theme.of(context).colorScheme.onSurface,
fontSize: 13,
fontWeight: FontWeight.w800,
),
),
),
Column(
crossAxisAlignment: CrossAxisAlignment.end,
children: [
Text(
'$frequency',
style: TextStyle(
color: Color(0xFF146BD9),
fontSize: 16,
fontWeight: FontWeight.w900,
),
),
Text(
_t(en: 'approved', zh: '已批准', ms: 'diluluskan'),
style: TextStyle(
color: Theme.of(context).colorScheme.onSurfaceVariant,
fontSize: 9,
fontWeight: FontWeight.w600,
),
),
],
),
],
),
const SizedBox(height: 6),
Text(
_t(
en: 'Location: ${row['attractionName'] ?? row['attractionId'] ?? 'Unknown attraction'}',
zh: '地点：${row['attractionName'] ?? row['attractionId'] ?? '未知景点'}',
ms: 'Lokasi: ${row['attractionName'] ?? row['attractionId'] ?? 'Tarikan tidak diketahui'}',
),
style: TextStyle(
color: Theme.of(context).colorScheme.onSurfaceVariant,
fontSize: 10.5,
fontWeight: FontWeight.w500,
),
),
const SizedBox(height: 5),
ClipRRect(
borderRadius: BorderRadius.circular(20),
child: LinearProgressIndicator(
value: progressValue,
minHeight: 6,
backgroundColor: const Color(0xFFE9EEF7),
),
),
const SizedBox(height: 5),
Text(
_t(
en: 'Priority ${score.toStringAsFixed(0)} points  •  severity ${severity.toStringAsFixed(1)}/5  •  confidence ${(confidence * 100).toStringAsFixed(0)}%',
zh: '优先级 ${score.toStringAsFixed(0)} 分  •  严重度 ${severity.toStringAsFixed(1)}/5  •  可信度 ${(confidence * 100).toStringAsFixed(0)}%',
ms: 'Keutamaan ${score.toStringAsFixed(0)} mata  •  keterukan ${severity.toStringAsFixed(1)}/5  •  keyakinan ${(confidence * 100).toStringAsFixed(0)}%',
),
style: TextStyle(
color: Theme.of(context).colorScheme.onSurfaceVariant,
fontSize: 10.5,
),
),
if (row['insufficientData'] == true)
Padding(
padding: const EdgeInsets.only(top: 4),
child: Text(
_t(en: 'Low sample size', zh: '样本量较少', ms: 'Saiz sampel rendah'),
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
_t(en: 'Violation trend', zh: '违规趋势', ms: 'Trend pelanggaran'),
_viewModel.selectedPeriod == 'month'
? _t(en: 'Approved reports by month', zh: '每月获批准报告', ms: 'Laporan diluluskan mengikut bulan')
    : _t(en: 'Approved reports by week', zh: '每周获批准报告', ms: 'Laporan diluluskan mengikut minggu'),
Icons.show_chart_rounded,
),
const SizedBox(height: 15),
SizedBox(
height: 165,
width: double.infinity,
child: _viewModel.trend.isEmpty
? _emptyState(
Icons.query_stats,
_t(en: 'No trend data yet', zh: '暂无趋势数据', ms: 'Belum ada data trend'),
_t(en: 'Trend points will appear after approved reports are available.', zh: '有获批准报告后会显示趋势数据点。', ms: 'Titik trend akan dipaparkan selepas laporan diluluskan tersedia.'),
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
style: TextStyle(
color: Theme.of(context).colorScheme.onSurfaceVariant,
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
_t(en: 'Most affected locations', zh: '受影响最大的地点', ms: 'Lokasi paling terjejas'),
_t(en: 'Locations with the most approved etiquette reports', zh: '获批准礼仪报告最多的地点', ms: 'Lokasi dengan laporan etika diluluskan terbanyak'),
Icons.place_outlined,
),
const SizedBox(height: 10),
if (_viewModel.affectedLocations.isEmpty)
_emptyState(
Icons.location_off_outlined,
_t(en: 'No location data yet', zh: '暂无地点数据', ms: 'Belum ada data lokasi'),
_t(en: 'Approved reports will be grouped by attraction here.', zh: '获批准报告会按景点分组显示在这里。', ms: 'Laporan diluluskan akan dikumpulkan mengikut tarikan di sini.'),
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
style: TextStyle(
color: Color(0xFF008E83),
fontWeight: FontWeight.w800,
),
),
),
title: Text(
entry.value['name']?.toString() ?? 'Attraction',
style: TextStyle(
color: Theme.of(context).colorScheme.onSurface,
fontWeight: FontWeight.w700,
fontSize: 12.5,
),
),
trailing: Text(
_t(
en: '${_int(entry.value['count'])} reports',
zh: '${_int(entry.value['count'])} 份报告',
ms: '${_int(entry.value['count'])} laporan',
),
style: TextStyle(
color: Theme.of(context).colorScheme.onSurfaceVariant,
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
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
children: [
Icon(Icons.calculate_outlined, color: Colors.white, size: 20),
SizedBox(width: 7),
Text(
_t(
en: 'Cumulative Priority Points',
zh: '累计优先级分数',
ms: 'Mata Keutamaan Kumulatif',
),
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
_t(
en: '5 points per approved occurrence  +  up to 30 Severity  +  up to 20 Verification',
zh: '每次获批准出现计 5 分  +  严重度最高 30 分  +  验证最高 20 分',
ms: '5 mata bagi setiap kejadian diluluskan  +  sehingga 30 Keterukan  +  sehingga 20 Pengesahan',
),
style: TextStyle(
color: Colors.white,
fontSize: 12,
height: 1.35,
fontWeight: FontWeight.w700,
),
),
SizedBox(height: 5),
Text(
_t(
en: 'Only Admin-approved violations contribute. The points are not capped at 100: with maximum severity and confidence, 10 occurrences = 100 points, 11 = 105, 12 = 110, and so on.',
zh: '只有管理员批准的违规才会计分。分数不以 100 为上限：在严重度和可信度均为最高时，10 次 = 100 分，11 次 = 105 分，12 次 = 110 分，以此类推。',
ms: 'Hanya pelanggaran yang diluluskan Pentadbir menyumbang mata. Mata tidak dihadkan pada 100: dengan keterukan dan keyakinan maksimum, 10 kejadian = 100 mata, 11 = 105, 12 = 110 dan seterusnya.',
),
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
VoidCallback? onTap,
}) {
return SizedBox(
width: width,
child: GestureDetector(
onTap: onTap,
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
style: TextStyle(
color: Theme.of(context).colorScheme.onSurface,
fontSize: 20,
fontWeight: FontWeight.w900,
),
),
Text(
label,
style: TextStyle(
color: Theme.of(context).colorScheme.onSurface,
fontSize: 11,
fontWeight: FontWeight.w700,
),
),
const SizedBox(height: 2),
Text(
subtitle,
maxLines: 1,
overflow: TextOverflow.ellipsis,
style: TextStyle(
color: Theme.of(context).colorScheme.onSurfaceVariant,
fontSize: 9.5,
),
),
],
),
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
style: TextStyle(
color: Theme.of(context).colorScheme.onSurface,
fontSize: 14,
fontWeight: FontWeight.w800,
),
),
const SizedBox(height: 1),
Text(
subtitle,
style: TextStyle(
color: Theme.of(context).colorScheme.onSurfaceVariant,
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
style: TextStyle(
color: Color(0xFF59657D),
fontSize: 12,
fontWeight: FontWeight.w700,
),
),
const SizedBox(height: 2),
Text(
subtitle,
textAlign: TextAlign.center,
style: TextStyle(
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
color: Theme.of(context).colorScheme.surface,
borderRadius: BorderRadius.circular(18),
border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
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
fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
border: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
),
enabledBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
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
