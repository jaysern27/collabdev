import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

class UserEtiquetteReportPage extends StatefulWidget {
  const UserEtiquetteReportPage({super.key});

  @override
  State<UserEtiquetteReportPage> createState() =>
      _UserEtiquetteReportPageState();
}

class _UserEtiquetteReportPageState
    extends State<UserEtiquetteReportPage> {
  final ImagePicker _imagePicker = ImagePicker();

  bool _isLoadingLocation = true;
  bool _isSubmitting = false;

  _AttractionInfo? _nearestAttraction;
  Position? _currentPosition;

  final Set<String> _selectedDontRules = <String>{};

  File? _evidencePhoto;
  String? _errorMessage;

  static const Color _purple = Color(0xFF7B61FF);
  static const Color _blue = Color(0xFF36A8E0);
  static const Color _peach = Color(0xFFFFB7A1);
  static const Color _gold = Color(0xFFF6D365);
  static const Color _darkText = Color(0xFF241B35);
  static const Color _backgroundColor = Color(0xFFF8F4FB);

  @override
  void initState() {
    super.initState();
    _loadNearestAttraction();
  }

  Future<void> _loadNearestAttraction() async {
    setState(() {
      _isLoadingLocation = true;
      _errorMessage = null;
      _selectedDontRules.clear();
    });

    try {
      final Position position = await _getCurrentPosition();
      final List<_AttractionInfo> attractions =
      await _fetchAttractions();

      if (attractions.isEmpty) {
        throw Exception('No attractions found in Firestore.');
      }

      _AttractionInfo? nearest;
      double nearestDistance = double.infinity;

      for (final _AttractionInfo attraction in attractions) {
        final double distance = Geolocator.distanceBetween(
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

      if (!mounted) return;

      setState(() {
        _currentPosition = position;
        _nearestAttraction = nearest;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage =
            e.toString().replaceFirst('Exception: ', '');
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
      throw Exception('Location service is turned off.');
    }

    LocationPermission permission =
    await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission =
      await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception('Location permission denied.');
    }

    if (permission ==
        LocationPermission.deniedForever) {
      throw Exception(
        'Location permission denied forever.',
      );
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
        'The evidence photo is still too large. Please take another photo.',
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
        'No DON’T rules are available for this attraction.',
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
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
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
                  const Row(
                    children: [
                      Icon(
                        Icons.rule_rounded,
                        color: _purple,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Select Violated DON’T Rules',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight:
                            FontWeight.w800,
                            color: _darkText,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Align(
                    alignment:
                    Alignment.centerLeft,
                    child: Text(
                      'You can select more than one violation.',
                      style: TextStyle(
                        color: Colors.black54,
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
                              ? const Color(
                            0xFFF0EBFF,
                          )
                              : const Color(
                            0xFFFAF8FC,
                          ),
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
                              rule,
                              style: TextStyle(
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: _darkText,
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
                          const Text('Clear'),
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
                                ? 'Done'
                                : 'Done (${temporarySelection.length})',
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
        'Evidence photo is too large. Please take another photo.',
      );
    }

    return base64Encode(bytes);
  }

  Future<void> _submitReport() async {
    if (!_canSubmit) {
      _showMessage(
        'Please select at least one violation and take an evidence photo.',
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
        const SnackBar(
          content: Text(
            'Report submitted successfully.',
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
            'Failed to submit report: $e',
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
    return Scaffold(
      backgroundColor:
      _backgroundColor,
      appBar: AppBar(
        title: const Text(
          'User Etiquette Report',
          style: TextStyle(
            fontWeight:
            FontWeight.w700,
            color: _darkText,
          ),
        ),
        backgroundColor:
        _backgroundColor,
        elevation: 0,
        iconTheme: const IconThemeData(
          color: _darkText,
        ),
      ),
      body: SafeArea(
        child: _isLoadingLocation
            ? const Center(
          child:
          CircularProgressIndicator(),
        )
            : RefreshIndicator(
          onRefresh:
          _loadNearestAttraction,
          child:
          SingleChildScrollView(
            physics:
            const AlwaysScrollableScrollPhysics(),
            padding:
            const EdgeInsets.fromLTRB(
              18,
              12,
              18,
              28,
            ),
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                _buildHeaderCard(),
                const SizedBox(
                  height: 18,
                ),

                if (_errorMessage !=
                    null)
                  _buildErrorCard(),

                _buildSectionTitle(
                  'Detected Location',
                ),
                const SizedBox(
                  height: 10,
                ),
                _buildLocationCard(),

                const SizedBox(
                  height: 20,
                ),

                _buildSectionTitle(
                  'Select Violated DON’T Rules',
                ),
                const SizedBox(
                  height: 5,
                ),
                const Text(
                  'You can select one or multiple violations.',
                  style: TextStyle(
                    color:
                    Colors.black54,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),

                _buildMultiSelectCard(),

                const SizedBox(
                  height: 20,
                ),

                _buildSectionTitle(
                  'Evidence Photo',
                ),
                const SizedBox(
                  height: 10,
                ),

                _buildEvidenceCard(),

                const SizedBox(
                  height: 20,
                ),

                _buildSectionTitle(
                  'Report Summary',
                ),
                const SizedBox(
                  height: 10,
                ),

                _buildSummaryCard(),

                const SizedBox(
                  height: 26,
                ),

                _buildSubmitButton(),

                const SizedBox(
                  height: 10,
                ),

                const Center(
                  child: Text(
                    'At least one violation and one photo are required.',
                    textAlign:
                    TextAlign.center,
                    style: TextStyle(
                      color:
                      Colors.black54,
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

  Widget _buildHeaderCard() {
    return Container(
      padding:
      const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius:
        BorderRadius.circular(24),
        gradient:
        const LinearGradient(
          colors: [
            _purple,
            _blue,
          ],
          begin: Alignment.topLeft,
          end:
          Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _purple.withValues(
              alpha: 0.18,
            ),
            blurRadius: 18,
            offset:
            const Offset(0, 8),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Text(
            'Submit Etiquette Violation',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight:
              FontWeight.w800,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Your location is detected automatically. Select all violated DON’T rules, take one evidence photo, and submit.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              height: 1.5,
            ),
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
        color: Colors.red.shade50,
        borderRadius:
        BorderRadius.circular(16),
        border: Border.all(
          color:
          Colors.red.shade200,
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
              const Color(
                0xFFEDE7FF,
              ),
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
                ? const Text(
              'Unable to detect nearest attraction.',
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
                  const TextStyle(
                    fontSize:
                    18,
                    fontWeight:
                    FontWeight.w800,
                    color:
                    _darkText,
                  ),
                ),
                const SizedBox(
                  height: 6,
                ),
                Text(
                  _nearestAttraction!
                      .category,
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
                      : 'Address not available',
                  style:
                  const TextStyle(
                    color:
                    Colors.black54,
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
                      '${_formatDistance(_nearestAttraction!.distanceInMeters)} away',
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
            'Refresh location',
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
                    const Color(
                      0xFFFFECE8,
                    ),
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
                            ? 'Choose violations'
                            : '${_selectedDontRules.length} violation(s) selected',
                        style:
                        const TextStyle(
                          fontWeight:
                          FontWeight.w800,
                          color:
                          _darkText,
                          fontSize:
                          15,
                        ),
                      ),
                      const SizedBox(
                        height: 3,
                      ),
                      const Text(
                        'Tap to select multiple DON’T rules',
                        style:
                        TextStyle(
                          color:
                          Colors.black54,
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
                          rule,
                        ),
                        backgroundColor:
                        const Color(
                          0xFFF1ECFF,
                        ),
                        labelStyle:
                        const TextStyle(
                          color:
                          _darkText,
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
            ? const Column(
          children: [
            _EvidenceIcon(),
            SizedBox(
              height: 12,
            ),
            Text(
              'Take Evidence Photo',
              style:
              TextStyle(
                fontSize:
                16,
                fontWeight:
                FontWeight.w800,
                color:
                _darkText,
              ),
            ),
            SizedBox(
              height: 6,
            ),
            Text(
              'Camera only. A photo is required before submission.',
              textAlign:
              TextAlign.center,
              style:
              TextStyle(
                color:
                Colors.black54,
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
                const Expanded(
                  child:
                  Text(
                    'Evidence photo captured.',
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
                  const Text(
                    'Retake',
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
        gradient:
        const LinearGradient(
          colors: [
            Color(0xFFFFF1EC),
            Color(0xFFFFE6D9),
          ],
          begin: Alignment.topLeft,
          end:
          Alignment.bottomRight,
        ),
        border: Border.all(
          color:
          const Color(
            0xFFFFD8C7,
          ),
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
            'Detected Place',
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
            'Selected Violations',
            value:
            _selectedDontRules
                .isEmpty
                ? 'No violation selected'
                : '${_selectedDontRules.length} selected',
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
                            rule,
                            style:
                            const TextStyle(
                              color:
                              _darkText,
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
            'Evidence Photo',
            value:
            _evidencePhoto == null
                ? 'Not captured yet'
                : 'Photo ready',
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
              : Colors.grey.shade300,
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
                ? 'Select Violations First'
                : _evidencePhoto ==
                null
                ? 'Take Photo to Continue'
                : 'Submit ${_selectedDontRules.length} Violation(s)',
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
      style: const TextStyle(
        fontSize: 17,
        fontWeight:
        FontWeight.w800,
        color: _darkText,
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
              const TextStyle(
                color:
                _darkText,
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
    return BoxDecoration(
      color: Colors.white,
      borderRadius:
      BorderRadius.circular(
        22,
      ),
      border: Border.all(
        color:
        const Color(
          0xFFE5DFF1,
        ),
      ),
      boxShadow: [
        BoxShadow(
          color:
          Colors.black.withValues(
            alpha: 0.04,
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
    return Container(
      width: 64,
      height: 64,
      decoration:
      BoxDecoration(
        color:
        const Color(
          0xFFFFF2E9,
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
  final double? distanceInMeters;

  const _AttractionInfo({
    required this.id,
    required this.name,
    required this.category,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.donts,
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
