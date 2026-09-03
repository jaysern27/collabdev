import 'package:flutter/material.dart';

import '../../view_model/etiquette_alert/etiquette_alert_view_model.dart';

// UC02 – Receive Etiquette Alert (BF-8/BF-9, A2).
//
// Opened when the Tourist taps the etiquette notification. Shows
// the destination's general ("default") etiquette list together
// with its location-specific list, each split into Do / Don't.
class EtiquetteAlertView extends StatefulWidget {
  final String attractionId;

  const EtiquetteAlertView({
    super.key,
    required this.attractionId,
  });

  @override
  State<EtiquetteAlertView> createState() =>
      _EtiquetteAlertViewState();
}

class _EtiquetteAlertViewState extends State<EtiquetteAlertView> {
  final EtiquetteAlertViewModel _viewModel =
  EtiquetteAlertViewModel();

  // Matches the home page / Cultural Map design language (cream
  // background, teal-to-blue gradient, navy text, orange accent)
  // instead of a separate palette.
  static const Color _teal = Color(0xFF18B7C8);
  static const Color _blue = Color(0xFF1E78D8);
  static const Color _navy = Color(0xFF14213D);
  static const Color _background = Color(0xFFFFFFFF);

  @override
  void initState() {
    super.initState();

    _viewModel.addListener(_onViewModelChanged);
    _viewModel.loadForAttraction(widget.attractionId);
  }

  void _onViewModelChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _viewModel.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text('Etiquette Guidance'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_teal, _blue],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_viewModel.isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: _teal,
        ),
      );
    }

    if (_viewModel.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.redAccent,
                size: 40,
              ),
              const SizedBox(height: 12),
              Text(
                _viewModel.errorMessage!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _viewModel.refresh,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final hasNoRules = _viewModel.defaultRules.isEmpty &&
        _viewModel.locationRules.isEmpty;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHeader(),
        if (_viewModel.topViolation != null) ...[
          const SizedBox(height: 14),
          _buildTopViolationCard(_viewModel.topViolation!),
        ],
        const SizedBox(height: 20),
        if (hasNoRules)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                'No etiquette guidance is available for this '
                    'destination yet.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
            ),
          ),
        if (_viewModel.locationRules.isNotEmpty)
          _buildSection(
            title: 'At ${_viewModel.attractionName}',
            dos: _viewModel.locationDos,
            donts: _viewModel.locationDonts,
          ),
        if (_viewModel.defaultRules.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildSection(
            title: 'General Etiquette',
            dos: _viewModel.defaultDos,
            donts: _viewModel.defaultDonts,
          ),
        ],
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_teal, _blue],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.notifications_active_rounded,
            color: Colors.white,
            size: 32,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You have entered',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                  ),
                ),
                Text(
                  _viewModel.attractionName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Module 4: this attraction's own violation ranking, built from
  // Admin-approved UC04 reports — the most commonly reported issue
  // at this specific location.
  Widget _buildTopViolationCard(Map<String, dynamic> topViolation) {
    final issue = topViolation['ruleName']?.toString() ??
        topViolation['category']?.toString() ??
        'Etiquette issue';

    final frequency = topViolation['frequency'];
    final isLimitedData = topViolation['insufficientData'] == true;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0C9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFA800).withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFFFA800),
            size: 24,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Most commonly reported issue here',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8A5A00),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  issue,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _navy,
                  ),
                ),
                if (frequency is num) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Reported $frequency time${frequency == 1 ? '' : 's'} '
                        'by other tourists'
                        '${isLimitedData ? ' (limited data so far)' : ''}.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Map<String, dynamic>> dos,
    required List<Map<String, dynamic>> donts,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: _navy,
          ),
        ),
        const SizedBox(height: 10),
        if (dos.isNotEmpty)
          _buildRuleList(
            icon: Icons.check_circle,
            color: const Color(0xFF2E7D32),
            rules: dos,
          ),
        if (dos.isNotEmpty && donts.isNotEmpty)
          const SizedBox(height: 10),
        if (donts.isNotEmpty)
          _buildRuleList(
            icon: Icons.cancel,
            color: const Color(0xFFC62828),
            rules: donts,
          ),
      ],
    );
  }

  Widget _buildRuleList({
    required IconData icon,
    required Color color,
    required List<Map<String, dynamic>> rules,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < rules.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    rules[i]['title']?.toString() ??
                        rules[i]['description']?.toString() ??
                        '',
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
