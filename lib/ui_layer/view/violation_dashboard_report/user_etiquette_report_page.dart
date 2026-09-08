import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../view_model/settings/app_settings_controller.dart';

class UserEtiquetteReportPage extends StatefulWidget {
  const UserEtiquetteReportPage({super.key});

  @override
  State<UserEtiquetteReportPage> createState() =>
      _UserEtiquetteReportPageState();
}

class _UserEtiquetteReportPageState
    extends State<UserEtiquetteReportPage> {
  final ImagePicker _imagePicker = ImagePicker();
  final AppSettingsController _settings =
      AppSettingsController.instance;

  bool _isLoadingLocation = true;
  bool _isSubmitting = false;

  _AttractionInfo? _nearestAttraction;
  Position? _currentPosition;

  final Set<String> _selectedDontRules = <String>{};

  File? _evidencePhoto;
  String? _errorMessage;

  static const Color _purple = Color(0xFF00A77E);
  static const Color _blue = Color(0xFF3CC8AE);
  static const Color _peach = Color(0xFFFF8FA3);
  static const Color _gold = Color(0xFFFFB744);

  // =========================================================
  // THEME HELPERS
  // =========================================================

  Color get _textColor =>
      Theme.of(context).colorScheme.onSurface;

  Color get _mutedTextColor =>
      Theme.of(context).colorScheme.onSurfaceVariant;

  Color get _softPurpleBackground {
    final colorScheme = Theme.of(context).colorScheme;
    return Color.alphaBlend(
      _purple.withValues(alpha: 0.12),
      colorScheme.surfaceContainerLow,
    );
  }

  Color get _softOrangeBackground {
    final colorScheme = Theme.of(context).colorScheme;
    return Color.alphaBlend(
      Colors.deepOrange.withValues(alpha: 0.10),
      colorScheme.surfaceContainerLow,
    );
  }


  @override
  void initState() {
    super.initState();
    _settings.addListener(_onSettingsChanged);
    _loadNearestAttraction();
  }

  void _onSettingsChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  String _t({
    required String en,
    required String zh,
    required String ms,
  }) {
    return _settings.text(en: en, zh: zh, ms: ms);
  }

  String _categoryText(String category) {
    switch (category) {
      case 'Islamic Culture':
        return _t(en: 'Islamic Culture', zh: '伊斯兰文化', ms: 'Budaya Islam');
      case 'Chinese Culture':
        return _t(en: 'Chinese Culture', zh: '中华文化', ms: 'Budaya Cina');
      case 'Indian Culture':
        return _t(en: 'Indian Culture', zh: '印度文化', ms: 'Budaya India');
      case 'Places of Worship':
        return _t(en: 'Places of Worship', zh: '宗教场所', ms: 'Tempat Ibadat');
      case 'Historical Landmarks':
        return _t(en: 'Historical Landmarks', zh: '历史地标', ms: 'Mercu Tanda Bersejarah');
      default:
        return category;
    }
  }

  String _localizedRuleText(String english) {
    final target = english.trim().toLowerCase();
    final definitions =
        _nearestAttraction?.rankingRules ?? const <Map<String, dynamic>>[];

    Map<String, dynamic>? definition;
    for (final item in definitions) {
      final candidate =
      (item['ruleName'] ?? '').toString().trim().toLowerCase();
      if (candidate == target) {
        definition = item;
        break;
      }
    }

    final zh = (definition?['ruleNameZh'] ?? '').toString().trim();
    final ms = (definition?['ruleNameMs'] ?? '').toString().trim();

    switch (_settings.language) {
      case AppLanguage.chinese:
        return zh.isNotEmpty ? zh : english;
      case AppLanguage.malay:
        return ms.isNotEmpty ? ms : english;
      case AppLanguage.english:
        return english;
    }
  }

  Future<void> _loadNearestAttraction() async {
    if (mounted) {
      setState(() {
        _isLoadingLocation = true;
        _errorMessage = null;
        _selectedDontRules.clear();
      });
    }

    try {
      Position position;

      try {
        position = await _getCurrentPosition().timeout(
          const Duration(seconds: 12),
        );
      } catch (_) {
        final Position? lastKnown =
            await Geolocator.getLastKnownPosition();

        if (lastKnown == null) {
          rethrow;
        }

        position = lastKnown;
      }

      final List<_AttractionInfo> attractions =
          await _fetchAttractions().timeout(
        const Duration(seconds: 15),
      );

      if (attractions.isEmpty) {
        throw Exception(
          _t(
            en: 'No attractions found in Firestore.',
            zh: 'Firestore 中找不到景点。',
            ms: 'Tiada tarikan ditemui dalam Firestore.',
          ),
        );
      }

      _AttractionInfo? nearest;
      double nearestDistance = double.infinity;

      for (final _AttractionInfo attraction in attractions) {
        final double distance =
            Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          attraction.latitude,
          attraction.longitude,
        );

        if (distance < nearestDistance) {
          nearestDistance = distance;
          nearest = attraction.copyWith(
            distanceInMeters: distance,
          );
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _currentPosition = position;
        _nearestAttraction = nearest;
        _errorMessage = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = _t(
          en:
              'Unable to detect your location right now. Check location permission and try again.',
          zh:
              '目前无法检测您的位置。请检查定位权限后重试。',
          ms:
              'Lokasi anda tidak dapat dikesan sekarang. Semak kebenaran lokasi dan cuba lagi.',
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
      }
    }
  }

  Future<Position> _getCurrentPosition() async {
    final bool serviceEnabled =
    await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw Exception(_t(en: 'Location service is turned off.', zh: '定位服务已关闭。', ms: 'Perkhidmatan lokasi dimatikan.'));
    }

    LocationPermission permission =
    await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission =
      await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception(_t(en: 'Location permission denied.', zh: '定位权限被拒绝。', ms: 'Kebenaran lokasi ditolak.'));
    }

    if (permission ==
        LocationPermission.deniedForever) {
      throw Exception(_t(en: 'Location permission denied forever.', zh: '定位权限已被永久拒绝。', ms: 'Kebenaran lokasi ditolak secara kekal.'));
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
  }

  Future<List<_AttractionInfo>>
  _fetchAttractions() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot =
    await FirebaseFirestore.instance
        .collection('attractions')
        .get();

    return snapshot.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        final Map<String, dynamic> data =
        doc.data();

        return _AttractionInfo(
          id: doc.id,
          name:
          (data['name'] ?? '').toString(),
          category:
          (data['category'] ?? '').toString(),
          address:
          (data['address'] ?? '').toString(),
          latitude:
          _toDouble(data['latitude']),
          longitude:
          _toDouble(data['longitude']),
          donts:
          _toStringList(data['donts']),
          rankingRules:
          _toMapList(data['rankingRules']),
        );
      },
    )
        .where(
          (_AttractionInfo item) =>
      item.name.isNotEmpty &&
          item.latitude != 0 &&
          item.longitude != 0 &&
          item.donts.isNotEmpty,
    )
        .toList();
  }

  Future<void> _takeEvidencePhoto() async {
    final XFile? picked =
    await _imagePicker.pickImage(
      source: ImageSource.camera,

      // The project is currently using the Firebase Spark plan.
      // Evidence is stored as compressed Base64 inside the Firestore report
      // document, so keep the image small enough for Firestore's document
      // size limit.
      imageQuality: 55,
      maxWidth: 900,
      maxHeight: 900,
    );

    if (picked == null || !mounted) return;

    final File file =
    File(picked.path);

    final int byteLength =
    await file.length();

    // Base64 increases size by roughly 33%. Keep a conservative raw-image
    // ceiling so the final Firestore report stays below the 1 MiB document
    // limit even with the other report fields.
    const int maxEvidenceBytes =
        600 * 1024;

    if (byteLength > maxEvidenceBytes) {
      if (!mounted) return;

      _showMessage(
        _t(en: 'The evidence photo is still too large. Please take another photo.', zh: '证据照片仍然太大，请重新拍摄。', ms: 'Foto bukti masih terlalu besar. Sila ambil foto lain.'),
      );
      return;
    }

    setState(() {
      _evidencePhoto = file;
    });
  }

  Future<void> _showDontRuleSelector() async {
    final List<String> rules =
        _nearestAttraction?.donts ?? <String>[];

    if (rules.isEmpty) {
      _showMessage(
        _t(en: 'No DON’T rules are available for this attraction.', zh: '此景点没有可用的“不要做”规则。', ms: 'Tiada peraturan JANGAN tersedia untuk tarikan ini.'),
      );
      return;
    }

    final Set<String> temporarySelection =
    Set<String>.from(_selectedDontRules);

    final Set<String>? result =
    await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (
              BuildContext context,
              StateSetter setSheetState,
              ) {
            return Container(
              height:
              MediaQuery.of(context).size.height *
                  0.72,
              padding:
              const EdgeInsets.fromLTRB(
                18,
                14,
                18,
                18,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD7D1DE),
                      borderRadius:
                      BorderRadius.circular(30),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Icon(
                        Icons.rule_rounded,
                        color: _purple,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _t(en: 'Select Violated DON’T Rules', zh: '选择违反的“不要做”规则', ms: 'Pilih Peraturan JANGAN yang Dilanggar'),
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight:
                            FontWeight.w800,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment:
                    Alignment.centerLeft,
                    child: Text(
                      _t(en: 'You can select more than one violation.', zh: '您可以选择一个或多个违规项目。', ms: 'Anda boleh memilih lebih daripada satu pelanggaran.'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: ListView.separated(
                      itemCount: rules.length,
                      separatorBuilder:
                          (_, _) =>
                      const SizedBox(
                        height: 8,
                      ),
                      itemBuilder:
                          (BuildContext context,
                          int index) {
                        final String rule =
                        rules[index];

                        final bool selected =
                        temporarySelection
                            .contains(rule);

                        return Material(
                          color: selected
                              ? Color.alphaBlend(
                            _purple.withValues(alpha: 0.14),
                            Theme.of(context).colorScheme.surfaceContainerLow,
                          )
                              : Theme.of(context)
                              .colorScheme
                              .surfaceContainerLow,
                          borderRadius:
                          BorderRadius.circular(
                            16,
                          ),
                          child: CheckboxListTile(
                            value: selected,
                            activeColor: _purple,
                            shape:
                            RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius.circular(
                                16,
                              ),
                            ),
                            title: Text(
                              _localizedRuleText(rule),
                              style: TextStyle(
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            onChanged:
                                (bool? value) {
                              setSheetState(() {
                                if (value == true) {
                                  temporarySelection
                                      .add(rule);
                                } else {
                                  temporarySelection
                                      .remove(rule);
                                }
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setSheetState(() {
                              temporarySelection
                                  .clear();
                            });
                          },
                          child:
                          Text(_t(en: 'Clear', zh: '清除', ms: 'Kosongkan')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: () {
                            Navigator.pop(
                              sheetContext,
                              temporarySelection,
                            );
                          },
                          style:
                          FilledButton.styleFrom(
                            backgroundColor:
                            _purple,
                            foregroundColor:
                            Colors.white,
                            minimumSize:
                            const Size(
                              double.infinity,
                              48,
                            ),
                          ),
                          child: Text(
                            temporarySelection
                                .isEmpty
                                ? _t(en: 'Done', zh: '完成', ms: 'Selesai')
                                : _t(en: 'Done (${temporarySelection.length})', zh: '完成（${temporarySelection.length}）', ms: 'Selesai (${temporarySelection.length})'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result == null || !mounted) return;

    setState(() {
      _selectedDontRules
        ..clear()
        ..addAll(result);
    });
  }

  String _formatDistance(
      double? meters,
      ) {
    if (meters == null) return '-';

    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    }

    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  bool get _canSubmit =>
      !_isSubmitting &&
          _nearestAttraction != null &&
          _selectedDontRules.isNotEmpty &&
          _evidencePhoto != null &&
          _currentPosition != null;

  String _deriveViolationCategory(
      String rule,
      ) {
    final String text =
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
        text.contains('loud') ||
        text.contains('talk loudly')) {
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
        text.contains('smoke') ||
        text.contains('run') ||
        text.contains('queue') ||
        text.contains('restricted')) {
      return 'Behaviour';
    }

    return 'Etiquette';
  }

  Future<String> _encodeEvidencePhoto(
      File file,
      ) async {
    final List<int> bytes =
    await file.readAsBytes();

    const int maxEvidenceBytes =
        600 * 1024;

    if (bytes.length > maxEvidenceBytes) {
      throw Exception(
        _t(en: 'Evidence photo is too large. Please take another photo.', zh: '证据照片太大，请重新拍摄。', ms: 'Foto bukti terlalu besar. Sila ambil foto lain.'),
      );
    }

    return base64Encode(bytes);
  }

  Future<void> _submitReport() async {
    if (!_canSubmit) {
      _showMessage(
        _t(en: 'Please select at least one violation and take an evidence photo.', zh: '请选择至少一个违规项目并拍摄证据照片。', ms: 'Sila pilih sekurang-kurangnya satu pelanggaran dan ambil foto bukti.'),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final User? user =
          FirebaseAuth.instance.currentUser;

      final _AttractionInfo attraction =
      _nearestAttraction!;

      final List<String> selectedRules =
      _selectedDontRules.toList();

      final List<Map<String, dynamic>>
      violations = selectedRules
          .map(
            (String rule) =>
        <String, dynamic>{
          'ruleName': rule,
          'category':
          _deriveViolationCategory(
            rule,
          ),
        },
      )
          .toList();

      final List<String>
      violationCategories =
      violations
          .map(
            (Map<String, dynamic> item) =>
            item['category']
                .toString(),
      )
          .toSet()
          .toList();

      final String evidenceBase64 =
      await _encodeEvidencePhoto(
        _evidencePhoto!,
      );

      await FirebaseFirestore.instance
          .collection('etiquette_reports')
          .add(
        <String, dynamic>{
          'userId': user?.uid,
          'userEmail': user?.email,

          'attractionId': attraction.id,
          'attractionName': attraction.name,
          'attractionCategory':
          attraction.category,

          // NEW multi-selection fields.
          'selectedDontRules':
          selectedRules,
          'violationCategories':
          violationCategories,
          'violations': violations,

          // Backward-compatible fields for older code.
          'selectedDontRule':
          selectedRules.first,
          'category':
          violationCategories.first,
          'description':
          selectedRules.join('; '),

          'status': 'pending',
          'createdAt':
          FieldValue.serverTimestamp(),

          'latitude':
          _currentPosition!.latitude,
          'longitude':
          _currentPosition!.longitude,
          'distanceFromAttractionMeters':
          attraction.distanceInMeters,

          // Store compressed evidence directly in Firestore for the
          // prototype. This avoids Cloud Storage, which requires the Blaze
          // plan. The Admin Review page already supports Base64 evidence via
          // the legacy `evidenceImageUrl` field.
          'evidenceImageUrl':
          evidenceBase64,
          'evidenceStorage':
          'firestore_base64',

          'severity': 3,
          'verificationConfidence':
          0.0,
        },
      );

      if (!mounted) return;

      setState(() {
        _selectedDontRules.clear();
        _evidencePhoto = null;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            _t(en: 'Report submitted successfully.', zh: '报告提交成功。', ms: 'Laporan berjaya dihantar.'),
          ),
          backgroundColor:
          Color(0xFF1E9E74),
          behavior:
          SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            _t(en: 'Failed to submit report: $e', zh: '报告提交失败：$e', ms: 'Gagal menghantar laporan: $e'),
          ),
          backgroundColor:
          Colors.red,
          behavior:
          SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showMessage(
      String message,
      ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior:
          SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor:
          Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          _t(
            en: 'User Etiquette Report',
            zh: '用户礼仪报告',
            ms: 'Laporan Etika Pengguna',
          ),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
      ),
      body: SafeArea(
        child: _isLoadingLocation
            ? _buildLocationLoadingState()
            : RefreshIndicator(
                color: const Color(0xFF00A77E),
                onRefresh: _loadNearestAttraction,
                child: SingleChildScrollView(
                  physics:
                      const AlwaysScrollableScrollPhysics(),
                  padding:
                      const EdgeInsets.fromLTRB(
                    18,
                    8,
                    18,
                    28,
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      _buildHeaderCard(),
                      const SizedBox(height: 18),

                      if (_errorMessage != null) ...[
                        _buildErrorCard(),
                        const SizedBox(height: 4),
                      ],

                      _buildSectionTitle(
                        _t(
                          en: 'Detected Location',
                          zh: '检测到的位置',
                          ms: 'Lokasi Dikesan',
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildLocationCard(),

                      const SizedBox(height: 20),

                      _buildSectionTitle(
                        _t(
                          en:
                              'Select Violated DON’T Rules',
                          zh:
                              '选择违反的“不要做”规则',
                          ms:
                              'Pilih Peraturan JANGAN yang Dilanggar',
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _t(
                          en:
                              'You can select one or multiple violations.',
                          zh:
                              '您可以选择一个或多个违规项目。',
                          ms:
                              'Anda boleh memilih satu atau beberapa pelanggaran.',
                        ),
                        style: TextStyle(
                          color: _mutedTextColor,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildMultiSelectCard(),

                      const SizedBox(height: 20),

                      _buildSectionTitle(
                        _t(
                          en: 'Evidence Photo',
                          zh: '证据照片',
                          ms: 'Foto Bukti',
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildEvidenceCard(),

                      const SizedBox(height: 20),

                      _buildSectionTitle(
                        _t(
                          en: 'Report Summary',
                          zh: '报告摘要',
                          ms: 'Ringkasan Laporan',
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildSummaryCard(),

                      const SizedBox(height: 26),
                      _buildSubmitButton(),
                      const SizedBox(height: 10),

                      Center(
                        child: Text(
                          _t(
                            en:
                                'At least one violation and one photo are required.',
                            zh:
                                '至少需要选择一个违规项目并提供一张照片。',
                            ms:
                                'Sekurang-kurangnya satu pelanggaran dan satu foto diperlukan.',
                          ),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _mutedTextColor,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildLocationLoadingState() {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;
    final colorScheme =
        Theme.of(context).colorScheme;

    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(),
      padding:
          const EdgeInsets.fromLTRB(
        18,
        8,
        18,
        28,
      ),
      children: [
        Container(
          constraints:
              const BoxConstraints(
            minHeight: 200,
          ),
          padding:
              const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(28),
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
          ),
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color:
                      const Color(0xFF00A77E)
                          .withValues(
                    alpha: 0.12,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Padding(
                  padding:
                      EdgeInsets.all(17),
                  child:
                      CircularProgressIndicator(
                    strokeWidth: 3,
                    color:
                        Color(0xFF00A77E),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _t(
                  en:
                      'Detecting your location...',
                  zh:
                      '正在检测您的位置……',
                  ms:
                      'Mengesan lokasi anda...',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark
                      ? Colors.white
                      : const Color(
                          0xFF123B61,
                        ),
                  fontSize: 18,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                _t(
                  en:
                      'Finding the nearest cultural attraction for your report.',
                  zh:
                      '正在为您的报告寻找最近的文化景点。',
                  ms:
                      'Mencari tarikan budaya terdekat untuk laporan anda.',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark
                      ? Colors.white
                          .withValues(
                          alpha: 0.72,
                        )
                      : colorScheme
                          .onSurfaceVariant,
                  height: 1.4,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding:
              const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius:
                BorderRadius.circular(22),
            border: Border.all(
              color:
                  colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                color:
                    Color(0xFF00A77E),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  _t(
                    en:
                        'Please keep Location enabled while this page opens.',
                    zh:
                        '打开此页面时，请保持定位服务开启。',
                    ms:
                        'Pastikan Lokasi diaktifkan semasa halaman ini dibuka.',
                  ),
                  style: TextStyle(
                    color: colorScheme
                        .onSurfaceVariant,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderCard() {
    final isDark =
        Theme.of(context).brightness ==
            Brightness.dark;

    return Container(
      constraints: const BoxConstraints(minHeight: 185),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
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
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            bottom: -8,
            child: Icon(
              Icons.volunteer_activism_rounded,
              size: 125,
              color: const Color(0xFF00A77E)
                  .withValues(
                alpha: isDark ? 0.18 : 0.11,
              ),
            ),
          ),
          const Positioned(
            right: 18,
            top: 8,
            child: Icon(
              Icons.photo_camera_rounded,
              color: Color(0xFFFFB744),
              size: 30,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color:
                      const Color(0xFF00A77E)
                          .withValues(
                    alpha: 0.12,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),
                child: Text(
                  _t(
                    en:
                        'Community Etiquette',
                    zh:
                        '社区礼仪',
                    ms:
                        'Etika Komuniti',
                  ),
                  style:
                      const TextStyle(
                    color:
                        Color(0xFF00A77E),
                    fontSize: 11,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                _t(
                  en:
                      'Help keep every journey respectful',
                  zh:
                      '一起守护文明旅程',
                  ms:
                      'Bantu jadikan setiap perjalanan penuh hormat',
                ),
                style: TextStyle(
                  color: isDark
                      ? Colors.white
                      : const Color(
                          0xFF123B61,
                        ),
                  fontSize: 21,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: 270,
                child: Text(
                  _t(
                    en:
                        'Your location is detected automatically. Select the violated rules, take one evidence photo and submit.',
                    zh:
                        '系统会自动检测您的位置。选择违规规则、拍摄一张证据照片并提交。',
                    ms:
                        'Lokasi anda dikesan secara automatik. Pilih peraturan yang dilanggar, ambil satu foto bukti dan hantar.',
                  ),
                  style: TextStyle(
                    color: isDark
                        ? Colors.white
                            .withValues(
                            alpha: 0.78,
                          )
                        : const Color(
                            0xFF4A6872,
                          ),
                    fontSize: 12.5,
                    height: 1.4,
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

  Widget _buildErrorCard() {
    return Container(
      margin:
      const EdgeInsets.only(
        bottom: 16,
      ),
      padding:
      const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          Colors.red.withValues(alpha: 0.10),
          Theme.of(context).colorScheme.surfaceContainerLow,
        ),
        borderRadius:
        BorderRadius.circular(16),
        border: Border.all(
          color:
          Colors.red.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.red,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(
                color: Colors.red,
                fontWeight:
                FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    return Container(
      padding:
      const EdgeInsets.all(16),
      decoration:
      _whiteCardDecoration(),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration:
            BoxDecoration(
              color:
              _softPurpleBackground,
              borderRadius:
              BorderRadius.circular(
                16,
              ),
            ),
            child: const Icon(
              Icons.place_rounded,
              color: _purple,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child:
            _nearestAttraction ==
                null
                ? Text(
              _t(en: 'Unable to detect nearest attraction.', zh: '无法检测最近的景点。', ms: 'Tidak dapat mengesan tarikan terdekat.'),
              style:
              TextStyle(
                fontWeight:
                FontWeight.w600,
              ),
            )
                : Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  _nearestAttraction!
                      .name,
                  style:
                  TextStyle(
                    fontSize:
                    18,
                    fontWeight:
                    FontWeight.w800,
                    color:
                    _textColor,
                  ),
                ),
                const SizedBox(
                  height: 6,
                ),
                Text(
                  _categoryText(_nearestAttraction!
                      .category),
                  style:
                  const TextStyle(
                    fontSize:
                    13,
                    fontWeight:
                    FontWeight.w600,
                    color:
                    _purple,
                  ),
                ),
                const SizedBox(
                  height: 8,
                ),
                Text(
                  _nearestAttraction!
                      .address
                      .isNotEmpty
                      ? _nearestAttraction!
                      .address
                      : _t(en: 'Address not available', zh: '暂无地址', ms: 'Alamat tidak tersedia'),
                  style:
                  TextStyle(
                    color:
                    _mutedTextColor,
                    height:
                    1.4,
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildInfoChip(
                      icon:
                      Icons.near_me_rounded,
                      label:
                      _t(en: '${_formatDistance(_nearestAttraction!.distanceInMeters)} away', zh: '距离 ${_formatDistance(_nearestAttraction!.distanceInMeters)}', ms: '${_formatDistance(_nearestAttraction!.distanceInMeters)} jauhnya'),
                      color:
                      _blue,
                    ),
                    if (_currentPosition !=
                        null)
                      _buildInfoChip(
                        icon:
                        Icons.my_location_rounded,
                        label:
                        '${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}',
                        color:
                        const Color(0xFF00A86B),
                      ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed:
            _loadNearestAttraction,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
            tooltip:
            _t(en: 'Refresh location', zh: '刷新位置', ms: 'Muat semula lokasi'),
          ),
        ],
      ),
    );
  }

  Widget _buildMultiSelectCard() {
    return GestureDetector(
      onTap:
      _showDontRuleSelector,
      child: Container(
        width:
        double.infinity,
        padding:
        const EdgeInsets.all(16),
        decoration:
        _whiteCardDecoration(),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 45,
                  height: 45,
                  decoration:
                  BoxDecoration(
                    color:
                    _softOrangeBackground,
                    borderRadius:
                    BorderRadius.circular(
                      14,
                    ),
                  ),
                  child: const Icon(
                    Icons
                        .report_problem_outlined,
                    color:
                    Color(
                      0xFFE05A3F,
                    ),
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
                        _selectedDontRules
                            .isEmpty
                            ? _t(en: 'Choose violations', zh: '选择违规项目', ms: 'Pilih pelanggaran')
                            : _t(en: '${_selectedDontRules.length} violation(s) selected', zh: '已选择 ${_selectedDontRules.length} 个违规项目', ms: '${_selectedDontRules.length} pelanggaran dipilih'),
                        style:
                        TextStyle(
                          fontWeight:
                          FontWeight.w800,
                          color:
                          _textColor,
                          fontSize:
                          15,
                        ),
                      ),
                      const SizedBox(
                        height: 3,
                      ),
                      Text(
                        _t(en: 'Tap to select multiple DON’T rules', zh: '点击选择多个“不要做”规则', ms: 'Ketik untuk memilih beberapa peraturan JANGAN'),
                        style:
                        TextStyle(
                          color:
                          _mutedTextColor,
                          fontSize:
                          12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons
                      .keyboard_arrow_down_rounded,
                  color: _purple,
                ),
              ],
            ),

            if (_selectedDontRules
                .isNotEmpty) ...[
              const SizedBox(
                height: 14,
              ),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children:
                _selectedDontRules
                    .map(
                      (String rule) =>
                      InputChip(
                        label: Text(
                          _localizedRuleText(rule),
                        ),
                        backgroundColor:
                        _softPurpleBackground,
                        labelStyle:
                        TextStyle(
                          color:
                          _textColor,
                          fontWeight:
                          FontWeight.w600,
                          fontSize:
                          12,
                        ),
                        deleteIcon:
                        const Icon(
                          Icons.close,
                          size: 16,
                        ),
                        onDeleted:
                            () {
                          setState(() {
                            _selectedDontRules
                                .remove(
                              rule,
                            );
                          });
                        },
                      ),
                )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEvidenceCard() {
    return GestureDetector(
      onTap:
      _takeEvidencePhoto,
      child: Container(
        width:
        double.infinity,
        padding:
        const EdgeInsets.all(16),
        decoration:
        _whiteCardDecoration(),
        child:
        _evidencePhoto == null
            ? Column(
          children: [
            const _EvidenceIcon(),
            SizedBox(
              height: 12,
            ),
            Text(
              _t(en: 'Take Evidence Photo', zh: '拍摄证据照片', ms: 'Ambil Foto Bukti'),
              style:
              TextStyle(
                fontSize:
                16,
                fontWeight:
                FontWeight.w800,
                color:
                _textColor,
              ),
            ),
            SizedBox(
              height: 6,
            ),
            Text(
              _t(en: 'Camera only. A photo is required before submission.', zh: '仅限相机拍摄。提交前必须提供一张照片。', ms: 'Kamera sahaja. Foto diperlukan sebelum penghantaran.'),
              textAlign:
              TextAlign.center,
              style:
              TextStyle(
                color:
                _mutedTextColor,
                height: 1.4,
              ),
            ),
          ],
        )
            : Column(
          children: [
            ClipRRect(
              borderRadius:
              BorderRadius.circular(
                18,
              ),
              child:
              Image.file(
                _evidencePhoto!,
                height: 220,
                width:
                double.infinity,
                fit:
                BoxFit.cover,
              ),
            ),
            const SizedBox(
              height: 12,
            ),
            Row(
              children: [
                const Icon(
                  Icons
                      .check_circle,
                  color:
                  Colors.green,
                ),
                const SizedBox(
                  width: 8,
                ),
                Expanded(
                  child:
                  Text(
                    _t(en: 'Evidence photo captured.', zh: '证据照片已拍摄。', ms: 'Foto bukti telah diambil.'),
                    style:
                    TextStyle(
                      fontWeight:
                      FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed:
                  _takeEvidencePhoto,
                  child:
                  Text(
                    _t(en: 'Retake', zh: '重新拍摄', ms: 'Ambil Semula'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      width:
      double.infinity,
      padding:
      const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius:
        BorderRadius.circular(22),
        gradient: LinearGradient(
          colors:
          Theme.of(context).brightness == Brightness.dark
              ? [
            Color.alphaBlend(
              _peach.withValues(alpha: 0.10),
              Theme.of(context).colorScheme.surfaceContainerLow,
            ),
            Color.alphaBlend(
              _gold.withValues(alpha: 0.08),
              Theme.of(context).colorScheme.surfaceContainerLow,
            ),
          ]
              : const [
            Color(0xFFFFF1EC),
            Color(0xFFFFE6D9),
          ],
          begin: Alignment.topLeft,
          end:
          Alignment.bottomRight,
        ),
        border: Border.all(
          color:
          Theme.of(context).brightness == Brightness.dark
              ? Theme.of(context).colorScheme.outlineVariant
              : const Color(0xFFFFD8C7),
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          _buildSummaryRow(
            icon:
            Icons.place_rounded,
            title:
            _t(en: 'Detected Place', zh: '检测到的地点', ms: 'Tempat Dikesan'),
            value:
            _nearestAttraction
                ?.name ??
                '-',
          ),
          const SizedBox(
            height: 14,
          ),
          _buildSummaryRow(
            icon:
            Icons.rule_rounded,
            title:
            _t(en: 'Selected Violations', zh: '已选择的违规项目', ms: 'Pelanggaran Dipilih'),
            value:
            _selectedDontRules
                .isEmpty
                ? _t(en: 'No violation selected', zh: '尚未选择违规项目', ms: 'Tiada pelanggaran dipilih')
                : _t(en: '${_selectedDontRules.length} selected', zh: '已选择 ${_selectedDontRules.length} 个', ms: '${_selectedDontRules.length} dipilih'),
          ),

          if (_selectedDontRules
              .isNotEmpty) ...[
            const SizedBox(
              height: 10,
            ),
            ..._selectedDontRules.map(
                  (String rule) =>
                  Padding(
                    padding:
                    const EdgeInsets.only(
                      left: 30,
                      bottom: 7,
                    ),
                    child: Row(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '• ',
                          style:
                          TextStyle(
                            color:
                            _purple,
                            fontWeight:
                            FontWeight.w900,
                          ),
                        ),
                        Expanded(
                          child:
                          Text(
                            _localizedRuleText(rule),
                            style:
                            TextStyle(
                              color:
                              _textColor,
                              height:
                              1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
            ),
          ],

          const SizedBox(
            height: 10,
          ),

          _buildSummaryRow(
            icon: Icons
                .photo_camera_rounded,
            title:
            _t(en: 'Evidence Photo', zh: '证据照片', ms: 'Foto Bukti'),
            value:
            _evidencePhoto == null
                ? _t(en: 'Not captured yet', zh: '尚未拍摄', ms: 'Belum diambil')
                : _t(en: 'Photo ready', zh: '照片已准备好', ms: 'Foto sedia'),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width:
      double.infinity,
      height: 56,
      child:
      DecoratedBox(
        decoration:
        BoxDecoration(
          borderRadius:
          BorderRadius.circular(
            18,
          ),
          gradient:
          _canSubmit
              ? const LinearGradient(
            colors: [
              _peach,
              _gold,
            ],
          )
              : null,
          color:
          _canSubmit
              ? null
              : Theme.of(context)
              .colorScheme
              .surfaceContainerHighest,
          boxShadow:
          _canSubmit
              ? [
            BoxShadow(
              color:
              Colors.orange.withValues(
                alpha:
                0.20,
              ),
              blurRadius:
              14,
              offset:
              const Offset(
                0,
                6,
              ),
            ),
          ]
              : <BoxShadow>[],
        ),
        child:
        ElevatedButton(
          onPressed:
          _canSubmit
              ? _submitReport
              : null,
          style:
          ElevatedButton.styleFrom(
            backgroundColor:
            Colors.transparent,
            shadowColor:
            Colors.transparent,
            disabledBackgroundColor:
            Colors.transparent,
            shape:
            RoundedRectangleBorder(
              borderRadius:
              BorderRadius.circular(
                18,
              ),
            ),
          ),
          child:
          _isSubmitting
              ? const SizedBox(
            height:
            22,
            width:
            22,
            child:
            CircularProgressIndicator(
              strokeWidth:
              2.6,
              color:
              Colors.white,
            ),
          )
              : Text(
            _selectedDontRules
                .isEmpty
                ? _t(en: 'Select Violations First', zh: '请先选择违规项目', ms: 'Pilih Pelanggaran Dahulu')
                : _evidencePhoto ==
                null
                ? _t(en: 'Take Photo to Continue', zh: '拍照后继续', ms: 'Ambil Foto untuk Teruskan')
                : _t(en: 'Submit ${_selectedDontRules.length} Violation(s)', zh: '提交 ${_selectedDontRules.length} 个违规项目', ms: 'Hantar ${_selectedDontRules.length} Pelanggaran'),
            style:
            const TextStyle(
              color:
              Colors.white,
              fontWeight:
              FontWeight.w800,
              fontSize:
              15,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(
      String text,
      ) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 17,
        fontWeight:
        FontWeight.w800,
        color: _textColor,
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),
      decoration:
      BoxDecoration(
        color: color.withValues(
          alpha: 0.10,
        ),
        borderRadius:
        BorderRadius.circular(
          14,
        ),
      ),
      child: Row(
        mainAxisSize:
        MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: color,
          ),
          const SizedBox(
            width: 6,
          ),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight:
                FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: _purple,
          size: 20,
        ),
        const SizedBox(
          width: 10,
        ),
        Expanded(
          child: RichText(
            text: TextSpan(
              style:
              TextStyle(
                color:
                _textColor,
                fontSize: 14,
                height: 1.45,
              ),
              children: [
                TextSpan(
                  text:
                  '$title: ',
                  style:
                  const TextStyle(
                    fontWeight:
                    FontWeight.w800,
                  ),
                ),
                TextSpan(
                  text:
                  value,
                  style:
                  const TextStyle(
                    fontWeight:
                    FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  BoxDecoration _whiteCardDecoration() {
    final colorScheme =
        Theme.of(context).colorScheme;
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    return BoxDecoration(
      color: colorScheme.surfaceContainerLow,
      borderRadius:
      BorderRadius.circular(
        22,
      ),
      border: Border.all(
        color:
        colorScheme.outlineVariant,
      ),
      boxShadow: [
        BoxShadow(
          color:
          Colors.black.withValues(
            alpha: isDark ? 0.18 : 0.04,
          ),
          blurRadius: 10,
          offset:
          const Offset(
            0,
            4,
          ),
        ),
      ],
    );
  }
}

class _EvidenceIcon extends StatelessWidget {
  const _EvidenceIcon();

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Container(
      width: 64,
      height: 64,
      decoration:
      BoxDecoration(
        color: Color.alphaBlend(
          Colors.deepOrange.withValues(alpha: 0.10),
          colorScheme.surfaceContainerLow,
        ),
        borderRadius:
        BorderRadius.circular(
          18,
        ),
      ),
      child: const Icon(
        Icons.camera_alt_rounded,
        size: 30,
        color:
        Colors.deepOrange,
      ),
    );
  }
}

class _AttractionInfo {
  final String id;
  final String name;
  final String category;
  final String address;
  final double latitude;
  final double longitude;
  final List<String> donts;
  final List<Map<String, dynamic>> rankingRules;
  final double? distanceInMeters;

  const _AttractionInfo({
    required this.id,
    required this.name,
    required this.category,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.donts,
    required this.rankingRules,
    this.distanceInMeters,
  });

  _AttractionInfo copyWith({
    double? distanceInMeters,
  }) {
    return _AttractionInfo(
      id: id,
      name: name,
      category: category,
      address: address,
      latitude: latitude,
      longitude: longitude,
      donts: donts,
      rankingRules: rankingRules,
      distanceInMeters:
      distanceInMeters ??
          this.distanceInMeters,
    );
  }
}

double _toDouble(
    dynamic value,
    ) {
  if (value is double) {
    return value;
  }

  if (value is int) {
    return value.toDouble();
  }

  if (value is String) {
    return double.tryParse(value) ??
        0;
  }

  return 0;
}

List<String> _toStringList(
    dynamic value,
    ) {
  if (value is List) {
    return value
        .map(
          (dynamic e) =>
          e.toString().trim(),
    )
        .where(
          (String e) =>
      e.isNotEmpty,
    )
        .toList();
  }

  return <String>[];
}

List<Map<String, dynamic>> _toMapList(dynamic value) {
  if (value is! List) {
    return <Map<String, dynamic>>[];
  }

  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}


