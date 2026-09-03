import 'package:flutter/material.dart';

import '../../../data_layer/model/repositories/ranking_report/ranking_report_repository.dart';
import '../../../data_layer/model/services/firebase_authentication/firebase_authentication_service.dart';

class MyEtiquetteReportsPage extends StatefulWidget {
  const MyEtiquetteReportsPage({super.key});

  @override
  State<MyEtiquetteReportsPage> createState() =>
      _MyEtiquetteReportsPageState();
}

class _MyEtiquetteReportsPageState
    extends State<MyEtiquetteReportsPage> {
  final RankingReportRepository repository =
  RankingReportRepository();
  final FirebaseAuthenticationService authService =
  FirebaseAuthenticationService();

  bool loading = true;
  String? errorMessage;
  String selectedFilter = 'all';

  List<Map<String, dynamic>> reports = [];

  static const Color _primary = Color(0xFF6C4DB5);
  static const Color _background = Color(0xFFFCF8FF);

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    final user = authService.currentUser;

    if (user == null) {
      setState(() {
        loading = false;
        errorMessage = 'Please sign in to view your reports.';
      });
      return;
    }

    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final result = await repository.getReportsByUser(user.uid);

      result.sort((a, b) {
        final aDate = _parseDate(a['createdAt']);
        final bDate = _parseDate(b['createdAt']);

        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;

        return bDate.compareTo(aDate);
      });

      if (!mounted) return;

      setState(() {
        reports = result;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
        errorMessage = e
            .toString()
            .replaceFirst('Exception: ', '');
      });
    }
  }

  List<Map<String, dynamic>> get filteredReports {
    if (selectedFilter == 'all') {
      return reports;
    }

    return reports.where((report) {
      return _status(report['status']) == selectedFilter;
    }).toList();
  }

  String _status(dynamic value) {
    return value?.toString().trim().toLowerCase() ?? 'pending';
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;

    try {
      return DateTime.parse(value.toString()).toLocal();
    } catch (_) {
      return null;
    }
  }

  String _dateText(dynamic value) {
    final date = _parseDate(value);
    if (date == null) return 'Date unavailable';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: const Text(
          'My Etiquette Reports',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: _background,
        surfaceTintColor: _background,
      ),
      body: RefreshIndicator(
        onRefresh: _loadReports,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          children: [
            _buildSummary(),
            const SizedBox(height: 16),
            _buildFilters(),
            const SizedBox(height: 14),
            if (loading)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (errorMessage != null)
              _buildMessageCard(
                icon: Icons.error_outline_rounded,
                title: 'Unable to load reports',
                message: errorMessage!,
              )
            else if (filteredReports.isEmpty)
                _buildMessageCard(
                  icon: Icons.inbox_outlined,
                  title: 'No reports here yet',
                  message: selectedFilter == 'all'
                      ? 'Your submitted etiquette reports will appear here.'
                      : 'No ${selectedFilter.toUpperCase()} reports were found.',
                )
              else
                ...filteredReports.map(_buildReportCard),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary() {
    final pending = reports.where(
          (report) => _status(report['status']) == 'pending',
    ).length;

    final approved = reports.where(
          (report) => _status(report['status']) == 'approved',
    ).length;

    final rejected = reports.where(
          (report) => _status(report['status']) == 'rejected',
    ).length;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFF0E5FF),
            Color(0xFFE5F6F1),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Report Status',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF241A35),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _summaryItem(
                '${reports.length}',
                'All',
                _primary,
              ),
              _summaryItem(
                '$pending',
                'Pending',
                const Color(0xFFB36B00),
              ),
              _summaryItem(
                '$approved',
                'Approved',
                const Color(0xFF16805F),
              ),
              _summaryItem(
                '$rejected',
                'Rejected',
                const Color(0xFFB43D3D),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(
      String value,
      String label,
      Color color,
      ) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF746B7E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    const filters = [
      ('all', 'All'),
      ('pending', 'Pending'),
      ('approved', 'Approved'),
      ('rejected', 'Rejected'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final selected = selectedFilter == filter.$1;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(filter.$2),
              selected: selected,
              onSelected: (_) {
                setState(() {
                  selectedFilter = filter.$1;
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildReportCard(
      Map<String, dynamic> report,
      ) {
    final status = _status(report['status']);
    final statusStyle = _statusStyle(status);

    final attraction = report['attractionId']
        ?.toString()
        .trim()
        .isNotEmpty ==
        true
        ? report['attractionId'].toString()
        : 'Unknown attraction';

    final category = report['category']
        ?.toString()
        .trim()
        .isNotEmpty ==
        true
        ? report['category'].toString()
        : 'Etiquette issue';

    final description = report['description']
        ?.toString()
        .trim()
        .isNotEmpty ==
        true
        ? report['description'].toString()
        : 'No description provided.';

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: const Color(0xFFE9E0F2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1EAFE),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.report_outlined,
                  color: _primary,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15.5,
                        color: Color(0xFF241A35),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      attraction,
                      style: const TextStyle(
                        color: Color(0xFF746B7E),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: statusStyle.$2,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  statusStyle.$1,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: statusStyle.$3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              height: 1.42,
              color: Color(0xFF4F4856),
            ),
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 15,
                color: Color(0xFF857C8D),
              ),
              const SizedBox(width: 6),
              Text(
                _dateText(report['createdAt']),
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF857C8D),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  (String, Color, Color) _statusStyle(
      String status,
      ) {
    switch (status) {
      case 'approved':
        return (
        'APPROVED',
        const Color(0xFFDDF5EA),
        const Color(0xFF136B4D),
        );
      case 'rejected':
        return (
        'REJECTED',
        const Color(0xFFFFE5E5),
        const Color(0xFFA63131),
        );
      default:
        return (
        'PENDING',
        const Color(0xFFFFF0D9),
        const Color(0xFF8A5A13),
        );
    }
  }

  Widget _buildMessageCard({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 34),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE9E0F2),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 42,
            color: _primary,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF746B7E),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
