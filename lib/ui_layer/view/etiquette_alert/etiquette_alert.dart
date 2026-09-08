import 'package:flutter/material.dart';

import '../../view_model/etiquette_alert/etiquette_alert_view_model.dart';
import '../../view_model/settings/app_settings_controller.dart';

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

class _EtiquetteAlertViewState
    extends State<EtiquetteAlertView> {
  final EtiquetteAlertViewModel _viewModel =
      EtiquetteAlertViewModel();

  final AppSettingsController _settings =
      AppSettingsController.instance;

  static const Color _teal = Color(0xFF00A77E);
  static const Color _blue = Color(0xFF3CC8AE);
  static const Color _doColor = Color(0xFF238B45);
  static const Color _dontColor = Color(0xFFD43F3A);
  static const Color _warning = Color(0xFFF59E0B);

  @override
  void initState() {
    super.initState();

    _viewModel.addListener(_onViewModelChanged);
    _settings.addListener(_onSettingsChanged);

    _viewModel.loadForAttraction(
      widget.attractionId,
    );
  }

  void _onViewModelChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onSettingsChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  String _t({
    required String en,
    required String zh,
    required String ms,
  }) {
    return _settings.text(
      en: en,
      zh: zh,
      ms: ms,
    );
  }

  @override
  void dispose() {
    _viewModel.removeListener(
      _onViewModelChanged,
    );
    _settings.removeListener(
      _onSettingsChanged,
    );
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor:
          Theme.of(context)
              .scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor:
            Colors.transparent,
        surfaceTintColor:
            Colors.transparent,
        foregroundColor:
            colorScheme.onSurface,
        title: Text(
          _t(
            en:
                'Etiquette Guidance',
            zh:
                '礼仪指南',
            ms:
                'Panduan Etika',
          ),
          style:
              const TextStyle(
            fontWeight:
                FontWeight.w900,
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
      return _buildErrorState();
    }

    return RefreshIndicator(
      onRefresh: _viewModel.refresh,
      color: _blue,
      child: ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding:
            const EdgeInsets.fromLTRB(
          16,
          16,
          16,
          28,
        ),
        children: [
          _buildHeader(),
          if (_viewModel.priorityDont != null) ...[
            const SizedBox(height: 14),
            _buildPriorityReminder(
              _viewModel.priorityDont!,
            ),
          ],
          const SizedBox(height: 22),
          _buildGuideHeading(),
          const SizedBox(height: 12),
          if (!_viewModel.hasGuidance)
            _buildEmptyState()
          else ...[
            if (_viewModel.dos.isNotEmpty)
              _buildRuleSection(
                title: _t(
                  en: 'DO',
                  zh: '应该做',
                  ms: 'BOLEH',
                ),
                subtitle: _t(
                  en:
                      'Recommended respectful behaviour',
                  zh: '建议遵守的尊重行为',
                  ms:
                      'Tingkah laku sopan yang disyorkan',
                ),
                icon:
                    Icons.check_circle_rounded,
                color: _doColor,
                rules: _viewModel.dos,
              ),
            if (_viewModel.dos.isNotEmpty &&
                _viewModel.donts.isNotEmpty)
              const SizedBox(height: 14),
            if (_viewModel.donts.isNotEmpty)
              _buildRuleSection(
                title: _t(
                  en: 'DON\'T',
                  zh: '不应该做',
                  ms: 'JANGAN',
                ),
                subtitle: _t(
                  en:
                      'Behaviours to avoid at this place',
                  zh: '在此地点应避免的行为',
                  ms:
                      'Tingkah laku yang perlu dielakkan di tempat ini',
                ),
                icon: Icons.cancel_rounded,
                color: _dontColor,
                rules: _viewModel.donts,
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(24),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: _dontColor,
              size: 42,
            ),
            const SizedBox(height: 12),
            Text(
              _t(
                en:
                    'Unable to load etiquette guidance',
                zh: '无法加载礼仪指南',
                ms:
                    'Tidak dapat memuatkan panduan etika',
              ),
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 17,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _viewModel.errorMessage!,
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed:
                  _viewModel.refresh,
              icon:
                  const Icon(
                Icons.refresh_rounded,
              ),
              label:
                  Text(
                _t(
                  en: 'Retry',
                  zh: '重试',
                  ms: 'Cuba Lagi',
                ),
              ),
              style:
                  FilledButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor:
                    Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isDark =
        Theme.of(context).brightness ==
            Brightness.dark;

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin:
              Alignment.topLeft,
          end:
              Alignment.bottomRight,
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
            BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration:
                BoxDecoration(
              color:
                  const Color(
                0xFF00A77E,
              ).withValues(
                alpha: 0.14,
              ),
              borderRadius:
                  BorderRadius.circular(
                15,
              ),
            ),
            child: const Icon(
              Icons
                  .volunteer_activism_rounded,
              color:
                  Color(
                0xFF00A77E,
              ),
              size: 27,
            ),
          ),
          const SizedBox(
            width: 14,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  _t(
                    en:
                        'You have entered',
                    zh:
                        '您已进入',
                    ms:
                        'Anda telah memasuki',
                  ),
                  style:
                      TextStyle(
                    color: isDark
                        ? Colors.white
                            .withValues(
                            alpha:
                                0.72,
                          )
                        : const Color(
                            0xFF4A6872,
                          ),
                    fontSize: 12,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
                const SizedBox(
                  height: 3,
                ),
                Text(
                  _viewModel
                      .attractionName,
                  style:
                      TextStyle(
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
                const SizedBox(
                  height: 5,
                ),
                Text(
                  _t(
                    en:
                        'Learn the local customs before you continue.',
                    zh:
                        '继续旅程前，先了解当地文化礼仪。',
                    ms:
                        'Kenali adat tempatan sebelum anda meneruskan perjalanan.',
                  ),
                  style:
                      TextStyle(
                    color: isDark
                        ? Colors.white
                            .withValues(
                            alpha:
                                0.78,
                          )
                        : const Color(
                            0xFF4A6872,
                          ),
                    fontSize: 12.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityReminder(
    Map<String, dynamic> rule,
  ) {
    final text =
        _ruleText(rule);

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? _warning.withValues(alpha: 0.10)
            : const Color(0xFFFFF7E6),
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: _warning.withValues(
            alpha: 0.38,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration:
                BoxDecoration(
              color: _warning.withValues(
                alpha: 0.14,
              ),
              borderRadius:
                  BorderRadius.circular(
                13,
              ),
            ),
            child:
                const Icon(
              Icons
                  .warning_amber_rounded,
              color: _warning,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  _t(
                    en:
                        'Priority Etiquette Reminder',
                    zh: '优先礼仪提醒',
                    ms:
                        'Peringatan Etika Keutamaan',
                  ),
                  style: TextStyle(
                    color:
                        Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFFFFC65C)
                            : const Color(0xFF8A5A00),
                    fontSize: 12.5,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  text,
                  style:
                      TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 15,
                    fontWeight:
                        FontWeight.w800,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _t(
                    en:
                        'Please pay extra attention to this rule at ${_viewModel.attractionName}.',
                    zh:
                        '在 ${_viewModel.attractionName} 请特别注意这项礼仪。',
                    ms:
                        'Sila beri perhatian khusus kepada peraturan ini di ${_viewModel.attractionName}.',
                  ),
                  style:
                      TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideHeading() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          _t(
            en:
                'At ${_viewModel.attractionName}',
            zh:
                '在 ${_viewModel.attractionName}',
            ms:
                'Di ${_viewModel.attractionName}',
          ),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 18,
            fontWeight:
                FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _t(
            en:
                'DOs keep their recommended order. DON\'Ts are prioritised using Admin-approved etiquette reports.',
            zh:
                '“应该做”会保持建议顺序；“不应该做”会根据管理员批准的礼仪报告调整优先顺序。',
            ms:
                'Perkara BOLEH kekal mengikut susunan yang disyorkan. Perkara JANGAN diberi keutamaan berdasarkan laporan etika yang diluluskan Admin.',
          ),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12.5,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 34,
      ),
      decoration:
          BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons
                .menu_book_outlined,
            color: _blue,
            size: 38,
          ),
          const SizedBox(height: 10),
          Text(
            _t(
              en:
                  'No etiquette guidance is available for this destination yet.',
              zh:
                  '此景点目前还没有可用的礼仪指南。',
              ms:
                  'Belum ada panduan etika tersedia untuk destinasi ini.',
            ),
            textAlign:
                TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight:
                  FontWeight.w700,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<Map<String, dynamic>>
        rules,
  }) {
    return Container(
      width: double.infinity,
      decoration:
          BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(
            alpha: 0.22,
          ),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D0F172A),
            blurRadius: 16,
            offset: Offset(0, 5),
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
              16,
              15,
              16,
              13,
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration:
                      BoxDecoration(
                    color:
                        color.withValues(
                      alpha: 0.10,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 21,
                  ),
                ),
                const SizedBox(
                  width: 11,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Text(
                        title,
                        style:
                            TextStyle(
                          color: color,
                          fontSize: 15.5,
                          fontWeight:
                              FontWeight
                                  .w900,
                        ),
                      ),
                      Text(
                        subtitle,
                        style:
                            TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        color.withValues(
                      alpha: 0.08,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),
                  ),
                  child: Text(
                    '${rules.length}',
                    style:
                        TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          for (var i = 0;
              i < rules.length;
              i++) ...[
            _buildRuleRow(
              rule: rules[i],
              index: i,
              icon: icon,
              color: color,
            ),
            if (i < rules.length - 1)
              Divider(
                height: 1,
                indent: 54,
                endIndent: 16,
                color:
                    Theme.of(context).colorScheme.outlineVariant,
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildRuleRow({
    required Map<String, dynamic> rule,
    required int index,
    required IconData icon,
    required Color color,
  }) {
    final rank =
        _rankOf(rule, index);
    final text =
        _ruleText(rule);

    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        14,
        12,
        16,
        12,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration:
                BoxDecoration(
              color: color.withValues(
                alpha: 0.10,
              ),
              borderRadius:
                  BorderRadius.circular(
                10,
              ),
            ),
            child: Text(
              '$rank',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight:
                    FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Padding(
            padding:
                const EdgeInsets.only(
              top: 4,
            ),
            child: Icon(
              icon,
              color: color,
              size: 19,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style:
                  TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 13.5,
                height: 1.4,
                fontWeight:
                    FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _rankOf(
    Map<String, dynamic> rule,
    int index,
  ) {
    final value = rule['rank'];

    if (value is int &&
        value > 0) {
      return value;
    }

    if (value is num &&
        value > 0) {
      return value.toInt();
    }

    final parsed = int.tryParse(
      value?.toString() ?? '',
    );

    return parsed != null &&
            parsed > 0
        ? parsed
        : index + 1;
  }

  String _ruleText(
    Map<String, dynamic> rule,
  ) {
    final english =
        (rule['ruleName'] ??
                rule['title'] ??
                rule['description'] ??
                '')
            .toString()
            .trim();

    final chinese =
        (rule['ruleNameZh'] ?? '')
            .toString()
            .trim();

    final malay =
        (rule['ruleNameMs'] ?? '')
            .toString()
            .trim();

    switch (_settings.language) {
      case AppLanguage.chinese:
        return chinese.isNotEmpty
            ? chinese
            : english;

      case AppLanguage.malay:
        return malay.isNotEmpty
            ? malay
            : english;

      case AppLanguage.english:
        return english;
    }
  }
}
