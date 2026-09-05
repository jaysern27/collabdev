import 'package:flutter/material.dart';

import '../../view_model/outfit_recognition/outfit_recognition_view_model.dart';

class OutfitRecognitionView extends StatefulWidget {
  const OutfitRecognitionView({super.key});

  @override
  State<OutfitRecognitionView> createState() =>
      _OutfitRecognitionViewState();
}

class _OutfitRecognitionViewState
    extends State<OutfitRecognitionView> {
  final OutfitRecognitionViewModel _viewModel =
  OutfitRecognitionViewModel();

  @override
  void initState() {
    super.initState();

    _viewModel.addListener(_onViewModelChanged);

    _initializeModule();
  }

  Future<void> _initializeModule() async {
    await _viewModel.initializeOutfitModels(
      sleeveModelAssetPath:
      'lib/assets/models/sleeve_coverage_model.tflite',
      lowerBodyModelAssetPath:
      'lib/assets/models/lower_body_coverage_model.tflite',
      shoulderModelAssetPath:
      'lib/assets/models/shoulder_coverage_model.tflite',
      headwearModelAssetPath:
      'lib/assets/models/headwear_detection_model.tflite',
      humanModelAssetPath:
      'lib/assets/models/human_detection_model.tflite',
    );

    await _viewModel.recoverLostPhoto();
  }

  void _onViewModelChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _viewModel.removeListener(
      _onViewModelChanged,
    );

    _viewModel.dispose();

    super.dispose();
  }

  Future<void> _analyseOutfit() async {
    await _viewModel.analyseOutfit();

    if (!mounted) {
      return;
    }

    if (_viewModel.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _viewModel.errorMessage!,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(
        0xFFFFFFFF,
      ),

      appBar: AppBar(
        backgroundColor: const Color(
          0xFFFFFFFF,
        ),
        foregroundColor: const Color(
          0xFF14213D,
        ),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Check Your Outfit',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            20,
            10,
            20,
            30,
          ),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              _buildIntroduction(),

              const SizedBox(
                height: 20,
              ),

              _buildConsentCard(),

              const SizedBox(
                height: 20,
              ),

              _buildPhotoSection(),

              const SizedBox(
                height: 20,
              ),

              if (_viewModel.hasSelectedImage)
                _buildAnalyseButton(),

              if (_viewModel.isAnalysing) ...[
                const SizedBox(
                  height: 18,
                ),
                const Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(),

                      SizedBox(
                        height: 10,
                      ),

                      Text(
                        'Analysing your outfit...',
                      ),
                    ],
                  ),
                ),
              ],

              if (_viewModel.sleevePrediction != null &&
                  _viewModel.lowerBodyPrediction != null &&
                  _viewModel.shoulderPrediction != null &&
                  _viewModel.headwearPrediction != null) ...[
                const SizedBox(
                  height: 24,
                ),
                _buildResultCard(),
              ],

              if (_viewModel.errorMessage != null) ...[
                const SizedBox(
                  height: 18,
                ),

                _buildErrorCard(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntroduction() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(
        18,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(
              0xFF02AAA8,
            ),
            Color(
              0xFF2374D8,
            ),
          ],
        ),
        borderRadius: BorderRadius.circular(
          22,
        ),
      ),
      child: const Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.checkroom_outlined,
            color: Colors.white,
            size: 34,
          ),

          SizedBox(
            height: 12,
          ),

          Text(
            'Dress with confidence',
            style: TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),

          SizedBox(
            height: 6,
          ),

          Text(
            'Upload or take a photo of your outfit. '
                'CultureGuide will analyse visible clothing '
                'attributes and provide an advisory result.',
            style: TextStyle(
              color: Colors.white,
              height: 1.4,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsentCard() {
    return Container(
      padding: const EdgeInsets.all(
        16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          18,
        ),
        border: Border.all(
          color: const Color(
            0xFFE5E5E5,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: _viewModel.consentGiven,
            activeColor: const Color(
              0xFF00A6A6,
            ),
            onChanged: (value) {
              _viewModel.setConsent(
                value ?? false,
              );
            },
          ),

          const SizedBox(
            width: 4,
          ),

          const Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  'Photo Analysis Consent',
                  style: TextStyle(
                    fontWeight:
                    FontWeight.bold,
                    fontSize: 15,
                  ),
                ),

                SizedBox(
                  height: 5,
                ),

                Text(
                  'I consent to local AI analysis of my '
                      'outfit photo. The image will not be '
                      'uploaded or stored by default.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Color(
                      0xFF666666,
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

  Widget _buildPhotoSection() {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Outfit',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(
              0xFF14213D,
            ),
          ),
        ),

        const SizedBox(
          height: 12,
        ),

        if (_viewModel.selectedImage == null)
          _buildEmptyPhotoBox()
        else
          _buildSelectedPhoto(),

        const SizedBox(
          height: 14,
        ),

        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed:
                _viewModel.isLoading
                    ? null
                    : _viewModel.capturePhoto,
                icon: const Icon(
                  Icons.camera_alt_outlined,
                ),
                label: const Text(
                  'Take Photo',
                ),
                style:
                OutlinedButton.styleFrom(
                  minimumSize:
                  const Size.fromHeight(
                    48,
                  ),
                  foregroundColor:
                  const Color(
                    0xFF008F8C,
                  ),
                  side: const BorderSide(
                    color: Color(
                      0xFF00A6A6,
                    ),
                  ),
                  shape:
                  RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(
                      14,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(
              width: 10,
            ),

            Expanded(
              child: ElevatedButton.icon(
                onPressed:
                _viewModel.isLoading
                    ? null
                    : _viewModel.selectPhoto,
                icon: const Icon(
                  Icons.photo_library_outlined,
                ),
                label: const Text(
                  'Upload Photo',
                ),
                style:
                ElevatedButton.styleFrom(
                  minimumSize:
                  const Size.fromHeight(
                    48,
                  ),
                  backgroundColor:
                  const Color(
                    0xFF00A6A6,
                  ),
                  foregroundColor:
                  Colors.white,
                  elevation: 0,
                  shape:
                  RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(
                      14,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        if (_viewModel.isLoading) ...[
          const SizedBox(
            height: 10,
          ),

          const LinearProgressIndicator(),
        ],
      ],
    );
  }

  Widget _buildEmptyPhotoBox() {
    return Container(
      width: double.infinity,
      height: 260,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          20,
        ),
        border: Border.all(
          color: const Color(
            0xFFDADADA,
          ),
        ),
      ),
      child: const Column(
        mainAxisAlignment:
        MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_a_photo_outlined,
            size: 55,
            color: Color(
              0xFF00A6A6,
            ),
          ),

          SizedBox(
            height: 12,
          ),

          Text(
            'No outfit photo selected',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),

          SizedBox(
            height: 5,
          ),

          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 20,
            ),
            child: Text(
              'Make sure your full outfit, head, shoulders, '
                  'arms and legs are clearly visible.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(
                  0xFF777777,
                ),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedPhoto() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius:
          BorderRadius.circular(
            20,
          ),
          child: Image.memory(
            _viewModel.selectedImage!.bytes,
            width: double.infinity,
            height: 320,
            fit: BoxFit.contain,
          ),
        ),

        Positioned(
          top: 10,
          right: 10,
          child: Material(
            color: Colors.black54,
            shape: const CircleBorder(),
            child: IconButton(
              onPressed:
              _viewModel.clearPhoto,
              icon: const Icon(
                Icons.close,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyseButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed:
        _viewModel.isAnalysing ||
            !_viewModel
                .isModelReady
            ? null
            : _analyseOutfit,
        icon: const Icon(
          Icons.auto_awesome,
        ),
        label: Text(
          _viewModel.isModelReady
              ? 'Analyse Outfit'
              : 'Loading AI Models...',
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(
            0xFF2864D7,
          ),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(
              16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    final sleeve =
        _viewModel.sleevePrediction;

    final lowerBody =
        _viewModel.lowerBodyPrediction;

    final shoulder =
        _viewModel.shoulderPrediction;

    final headwear =
        _viewModel.headwearPrediction;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(
        20,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          20,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(
              0x11000000,
            ),
            blurRadius: 12,
            offset: Offset(
              0,
              4,
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.auto_awesome,
                color: Color(
                  0xFF00A6A6,
                ),
                size: 28,
              ),

              SizedBox(
                width: 10,
              ),

              Text(
                'Outfit Analysis',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight:
                  FontWeight.bold,
                  color: Color(
                    0xFF14213D,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 20,
          ),

          if (sleeve != null)
            _buildAttributeResult(
              title: 'Sleeve Coverage',
              value:
              _formatSleevePrediction(
                sleeve.value,
              ),
              confidence:
              sleeve.confidence,
              icon:
              Icons.checkroom_outlined,
            ),

          if (sleeve != null &&
              lowerBody != null)
            const Divider(
              height: 35,
            ),

          if (lowerBody != null)
            _buildAttributeResult(
              title:
              'Lower-Body Coverage',
              value:
              _formatLowerBodyPrediction(
                lowerBody.value,
              ),
              confidence:
              lowerBody.confidence,
              icon: Icons
                  .accessibility_new_outlined,
            ),

          if (lowerBody != null &&
              shoulder != null)
            const Divider(
              height: 35,
            ),

          if (shoulder != null)
            _buildAttributeResult(
              title:
              'Shoulder Coverage',
              value:
              _formatShoulderPrediction(
                shoulder.value,
              ),
              confidence:
              shoulder.confidence,
              icon: Icons
                  .accessibility_outlined,
            ),

          if (shoulder != null &&
              headwear != null)
            const Divider(
              height: 35,
            ),

          if (headwear != null)
            _buildAttributeResult(
              title:
              'Headwear Detection',
              value:
              _formatHeadwearPrediction(
                headwear.value,
              ),
              confidence:
              headwear.confidence,
              icon: Icons.person_outline,
            ),

          const SizedBox(
            height: 18,
          ),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(
              14,
            ),
            decoration: BoxDecoration(
              color: const Color(
                0xFFFFFFFF,
              ),
              borderRadius:
              BorderRadius.circular(
                14,
              ),
            ),
            child: const Text(
              'AI results show the highest-scoring prediction '
                  'from each clothing classifier.\n\n'
                  'The confidence percentage shows how strongly '
                  'the model preferred that result.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttributeResult({
    required String title,
    required String value,
    required double confidence,
    required IconData icon,
  }) {
    // Always display the model's highest-scoring prediction.
    //
    // We deliberately DO NOT reject predictions below 75%.
    final displayValue = value;

    return Row(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(
              0xFFE8F8F7,
            ),
            borderRadius:
            BorderRadius.circular(
              14,
            ),
          ),
          child: Icon(
            icon,
            color: const Color(
              0xFF00A6A6,
            ),
          ),
        ),

        const SizedBox(
          width: 14,
        ),

        Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(
                    0xFF777777,
                  ),
                ),
              ),

              const SizedBox(
                height: 4,
              ),

              Text(
                displayValue,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight:
                  FontWeight.bold,
                  color: Color(
                    0xFF14213D,
                  ),
                ),
              ),

              const SizedBox(
                height: 4,
              ),

              Text(
                'Confidence: '
                    '${(confidence * 100).toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(
                    0xFF008F8C,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(
        15,
      ),
      decoration: BoxDecoration(
        color: const Color(
          0xFFFFEAEA,
        ),
        borderRadius:
        BorderRadius.circular(
          14,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.red,
          ),

          const SizedBox(
            width: 10,
          ),

          Expanded(
            child: Text(
              _viewModel.errorMessage!,
            ),
          ),
        ],
      ),
    );
  }

  String _formatSleevePrediction(
      String value,
      ) {
    switch (value) {
      case 'long':
        return 'Long';

      case 'short':
        return 'Short';

      case 'sleeveless':
        return 'Sleeveless';

      default:
        return value;
    }
  }

  String _formatLowerBodyPrediction(
      String value,
      ) {
    switch (value) {
      case 'short':
        return 'Short';

      case 'medium':
        return 'Medium';

      case 'long':
        return 'Long';

      default:
        return value;
    }
  }

  String _formatShoulderPrediction(
      String value,
      ) {
    switch (value) {
      case 'covered':
        return 'Covered';

      case 'uncovered':
        return 'Uncovered';

      default:
        return value;
    }
  }

  String _formatHeadwearPrediction(
      String value,
      ) {
    switch (value) {
      case 'headwear':
        return 'Headwear Detected';

      case 'no_headwear':
        return 'No Headwear Detected';

      default:
        return value;
    }
  }
}