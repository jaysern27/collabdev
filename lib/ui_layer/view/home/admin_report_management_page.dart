import 'dart:convert';

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

// UC05 – Manage/Evaluate Report.
// Lets the Admin review every Pending etiquette report and approve
// or reject it. Approved reports feed Module 4's ranking data.
class AdminReportManagementPage extends StatefulWidget {
  const AdminReportManagementPage({super.key});

  @override
  State<AdminReportManagementPage> createState() =>
      _AdminReportManagementPageState();
}

class _AdminReportManagementPageState
    extends State<AdminReportManagementPage> {
  final RankingReportRepository _repository = RankingReportRepository();

  List<Map<String, dynamic>> _reports = [];
  bool _isLoading = true;
  final Set<String> _actingOnIds = {};

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _repository.getPendingReports();

      if (!mounted) return;

      setState(() {
        _reports = result;
      });
    } catch (e) {
      debugPrint('Load report error: $e');
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _approveReport(String id) async {
    setState(() => _actingOnIds.add(id));

    try {
      await _repository.approveReport(id);
      await _loadReports();
    } finally {
      if (mounted) {
        setState(() => _actingOnIds.remove(id));
      }
    }
  }

  Future<void> _rejectReport(String id) async {
    setState(() => _actingOnIds.add(id));

    try {
      await _repository.rejectReport(id);
      await _loadReports();
    } finally {
      if (mounted) {
        setState(() => _actingOnIds.remove(id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: _heading,
        title: const Text(
          'Report Management',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
          child: CircularProgressIndicator(color: _purple),
        )
            : RefreshIndicator(
          color: _purple,
          onRefresh: _loadReports,
          child: _reports.isEmpty
              ? ListView(
            padding: const EdgeInsets.all(24),
            children: const [
              SizedBox(height: 80),
              _EmptyState(),
            ],
          )
              : ListView.builder(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
            itemCount: _reports.length,
            itemBuilder: (context, index) {
              final report = _reports[index];
              final id = report['id']?.toString() ?? '';
              final isActing = _actingOnIds.contains(id);

              return _ReportCard(
                report: report,
                isActing: isActing,
                onApprove: () => _approveReport(id),
                onReject: () => _rejectReport(id),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: const BoxDecoration(
            color: Color(0xFFE9F6EA),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.task_alt_rounded,
            color: _approveColor,
            size: 36,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'All caught up',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _heading,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'There are no pending etiquette reports to review\nright now.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted),
        ),
      ],
    );
  }
}

class _ReportCard extends StatelessWidget {
  final Map<String, dynamic> report;
  final bool isActing;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _ReportCard({
    required this.report,
    required this.isActing,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final category = report['category']?.toString() ?? 'Unknown';
    final attractionId = report['attractionId']?.toString() ?? '—';
    final userId = report['userId']?.toString() ?? '—';
    final description = report['description']?.toString() ?? '';
    final evidence = report['evidenceImageUrl']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.tintLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  category,
                  style: const TextStyle(
                    color: _deepPurple,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.hourglass_top_rounded,
                size: 14,
                color: Color(0xFFB8860B),
              ),
              const SizedBox(width: 4),
              const Text(
                'Pending',
                style: TextStyle(
                  color: Color(0xFFB8860B),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoRow(icon: Icons.place_outlined, label: attractionId),
          const SizedBox(height: 4),
          _InfoRow(icon: Icons.person_outline_rounded, label: userId),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              description,
              style: const TextStyle(color: _heading, height: 1.4),
            ),
          ],
          const SizedBox(height: 14),
          _EvidencePhoto(base64Image: evidence),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isActing ? null : onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _rejectColor,
                    side: const BorderSide(color: _rejectColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: isActing ? null : onApprove,
                  style: FilledButton.styleFrom(
                    backgroundColor: _approveColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: isActing
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Approve'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: _muted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: _muted, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _EvidencePhoto extends StatelessWidget {
  final String? base64Image;

  const _EvidencePhoto({required this.base64Image});

  @override
  Widget build(BuildContext context) {
    if (base64Image == null || base64Image!.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.tintFaint,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            'No evidence photo',
            style: TextStyle(color: _muted, fontSize: 12),
          ),
        ),
      );
    }

    try {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          base64Decode(base64Image!),
          height: 180,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
          const _InvalidPhoto(),
        ),
      );
    } catch (_) {
      return const _InvalidPhoto();
    }
  }
}

class _InvalidPhoto extends StatelessWidget {
  const _InvalidPhoto();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFDEDED),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Text(
          'Invalid image',
          style: TextStyle(color: _rejectColor, fontSize: 12),
        ),
      ),
    );
  }
}
