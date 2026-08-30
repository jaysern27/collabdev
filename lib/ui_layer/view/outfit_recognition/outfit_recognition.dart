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
    await _viewModel.initializeModel(
      modelAssetPath:
      'lib/assets/models/sleeve_coverage_model.tflite',
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
    await _viewModel.analyseSleeveCoverage();

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
    final prediction =
        _viewModel.sleevePrediction;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF9F0),

      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF9F0),
        foregroundColor: const Color(0xFF14213D),
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

              const SizedBox(height: 20),

              _buildConsentCard(),

              const SizedBox(height: 20),

              _buildPhotoSection(),

              const SizedBox(height: 20),

              if (_viewModel.hasSelectedImage)
                _buildAnalyseButton(),

              if (_viewModel.isAnalysing) ...[
                const SizedBox(height: 18),
                const Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 10),
                      Text(
                        'Analysing your outfit...',
                      ),
                    ],
                  ),
                ),
              ],

              if (prediction != null &&
                  !_viewModel.isAnalysing) ...[
                const SizedBox(height: 24),

                _buildResultCard(),
              ],

              if (_viewModel.errorMessage !=
                  null) ...[
                const SizedBox(height: 18),

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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF02AAA8),
            Color(0xFF2374D8),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
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

          SizedBox(height: 12),

          Text(
            'Dress with confidence',
            style: TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),

          SizedBox(height: 6),

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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE5E5E5),
        ),
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: _viewModel.consentGiven,
            activeColor:
            const Color(0xFF00A6A6),
            onChanged: (value) {
              _viewModel.setConsent(
                value ?? false,
              );
            },
          ),

          const SizedBox(width: 4),

          const Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  'Photo Analysis Consent',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),

                SizedBox(height: 5),

                Text(
                  'I consent to local AI analysis of my '
                      'outfit photo. The image will not be '
                      'uploaded or stored by default.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Color(0xFF666666),
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
            color: Color(0xFF14213D),
          ),
        ),

        const SizedBox(height: 12),

        if (_viewModel.selectedImage == null)
          _buildEmptyPhotoBox()
        else
          _buildSelectedPhoto(),

        const SizedBox(height: 14),

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
                style: OutlinedButton.styleFrom(
                  minimumSize:
                  const Size.fromHeight(48),
                  foregroundColor:
                  const Color(0xFF008F8C),
                  side: const BorderSide(
                    color: Color(0xFF00A6A6),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(14),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 10),

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
                style: ElevatedButton.styleFrom(
                  minimumSize:
                  const Size.fromHeight(48),
                  backgroundColor:
                  const Color(0xFF00A6A6),
                  foregroundColor:
                  Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),

        if (_viewModel.isLoading) ...[
          const SizedBox(height: 10),
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFDADADA),
        ),
      ),
      child: const Column(
        mainAxisAlignment:
        MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_a_photo_outlined,
            size: 55,
            color: Color(0xFF00A6A6),
          ),

          SizedBox(height: 12),

          Text(
            'No outfit photo selected',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),

          SizedBox(height: 5),

          Text(
            'Make sure your upper body and sleeves\nare clearly visible.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF777777),
              fontSize: 12,
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
          BorderRadius.circular(20),
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
            !_viewModel.isModelReady
            ? null
            : _analyseOutfit,
        icon: const Icon(
          Icons.auto_awesome,
        ),
        label: Text(
          _viewModel.isModelReady
              ? 'Analyse Outfit'
              : 'Loading AI Model...',
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor:
          const Color(0xFF2864D7),
          foregroundColor:
          Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    final prediction =
    _viewModel.sleevePrediction!;

    final isAccepted =
        prediction.confidence >= 0.75;

    final String displayResult;

    final IconData icon;

    if (!isAccepted) {
      displayResult =
      'Unable to Determine';
      icon = Icons.help_outline;
    } else {
      displayResult =
          _formatPrediction(
            prediction.value,
          );

      icon = prediction.value ==
          'covered'
          ? Icons.check_circle_outline
          : prediction.value ==
          'partial'
          ? Icons.info_outline
          : Icons.warning_amber_rounded;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 50,
            color:
            const Color(0xFF00A6A6),
          ),

          const SizedBox(height: 10),

          const Text(
            'Sleeve Coverage',
            style: TextStyle(
              color: Color(0xFF666666),
              fontSize: 13,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            displayResult,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF14213D),
            ),
          ),

          const SizedBox(height: 12),

          Text(
            'AI Confidence: '
                '${(prediction.confidence * 100).toStringAsFixed(1)}%',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 15),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color:
              const Color(0xFFFFF8E8),
              borderRadius:
              BorderRadius.circular(14),
            ),
            child: Text(
              isAccepted
                  ? _getPredictionExplanation(
                prediction.value,
              )
                  : 'The AI confidence is below 75%. '
                  'Please take another photo with '
                  'your upper body and sleeves clearly visible.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEAEA),
        borderRadius: BorderRadius.circular(14),
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
              _viewModel.errorMessage!,
            ),
          ),
        ],
      ),
    );
  }

  String _formatPrediction(
      String value,
      ) {
    switch (value) {
      case 'covered':
        return 'Covered';

      case 'partial':
        return 'Partially Covered';

      case 'uncovered':
        return 'Uncovered';

      default:
        return value;
    }
  }

  String _getPredictionExplanation(
      String value,
      ) {
    switch (value) {
      case 'covered':
        return 'Your sleeves appear to provide good arm coverage.';

      case 'partial':
        return 'Your sleeves provide some arm coverage. '
            'The destination dress code will determine whether adjustment is needed.';

      case 'uncovered':
        return 'Your arms appear mostly uncovered. '
            'Some cultural or religious attractions may require additional coverage.';

      default:
        return '';
    }
  }
}