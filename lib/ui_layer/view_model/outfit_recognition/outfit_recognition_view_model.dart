import 'package:flutter/foundation.dart';

import '../../../data_layer/model/repositories/etiquette/etiquette_repository.dart';
import '../../../data_layer/model/repositories/outfit/outfit_repository.dart';
import '../../../data_layer/model/services/outfit_recognition/outfit_recognition_service.dart';

class OutfitRecognitionViewModel extends ChangeNotifier {
  final OutfitRepository _outfitRepository;
  final EtiquetteRepository _etiquetteRepository;

  OutfitRecognitionViewModel({
    OutfitRepository? outfitRepository,
    EtiquetteRepository? etiquetteRepository,
  })  : _outfitRepository =
      outfitRepository ?? OutfitRepository(),
        _etiquetteRepository =
            etiquetteRepository ?? EtiquetteRepository();

  // =========================================================
  // STATE
  // =========================================================

  bool _consentGiven = false;
  bool _isLoading = false;
  bool _isAnalysing = false;
  bool _isModelReady = false;

  String? _selectedAttractionId;
  String? _selectedAttractionName;

  OutfitImageData? _selectedImage;
  PreparedOutfitInput? _preparedInput;

  SleeveCoveragePrediction? _sleevePrediction;
  LowerBodyCoveragePrediction? _lowerBodyPrediction;
  ShoulderCoveragePrediction? _shoulderPrediction;
  HeadwearPrediction? _headwearPrediction;

  final Map<String, OutfitAttributePrediction>
  _detectedAttributes = {};

  List<Map<String, dynamic>> _dressCodeRules = [];

  OutfitAdvisoryResult? _advisoryResult;

  String? _errorMessage;

  // =========================================================
  // GETTERS
  // =========================================================

  bool get consentGiven => _consentGiven;

  bool get isLoading => _isLoading;

  bool get isAnalysing => _isAnalysing;

  bool get isModelReady => _isModelReady;

  bool get areModelsReady =>
      _outfitRepository.areOutfitModelsReady;

  bool get hasSelectedImage => _selectedImage != null;

  bool get hasSelectedDestination =>
      _selectedAttractionId != null;

  String? get selectedAttractionId =>
      _selectedAttractionId;

  String? get selectedAttractionName =>
      _selectedAttractionName;

  OutfitImageData? get selectedImage =>
      _selectedImage;

  PreparedOutfitInput? get preparedInput =>
      _preparedInput;

  SleeveCoveragePrediction? get sleevePrediction =>
      _sleevePrediction;

  LowerBodyCoveragePrediction? get lowerBodyPrediction =>
      _lowerBodyPrediction;

  ShoulderCoveragePrediction? get shoulderPrediction =>
      _shoulderPrediction;

  HeadwearPrediction? get headwearPrediction =>
      _headwearPrediction;

  Map<String, OutfitAttributePrediction>
  get detectedAttributes =>
      Map.unmodifiable(_detectedAttributes);

  List<Map<String, dynamic>> get dressCodeRules =>
      List.unmodifiable(_dressCodeRules);

  OutfitAdvisoryResult? get advisoryResult =>
      _advisoryResult;

  String? get result =>
      _advisoryResult?.displayStatus;

  String? get recommendation =>
      _advisoryResult?.message;

  String? get errorMessage =>
      _errorMessage;

  // =========================================================
  // CONSENT
  // =========================================================

  void setConsent(bool value) {
    _consentGiven = value;

    if (!value) {
      clearPhoto();
    }

    notifyListeners();
  }

  // =========================================================
  // DESTINATION
  // =========================================================

  Future<void> selectDestination({
    required String attractionId,
    required String attractionName,
  }) async {
    _selectedAttractionId = attractionId;
    _selectedAttractionName = attractionName;

    _dressCodeRules = [];
    _advisoryResult = null;
    _errorMessage = null;

    notifyListeners();

    await loadDressCodeRules();
  }

  Future<void> loadDressCodeRules() async {
    final attractionId = _selectedAttractionId;

    if (attractionId == null) {
      _errorMessage =
      'Please select a destination first.';

      notifyListeners();
      return;
    }

    _setLoading(true);

    try {
      _errorMessage = null;

      _dressCodeRules =
      await _etiquetteRepository
          .getDressCodeRules(
        attractionId,
      );
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // =========================================================
  // CAMERA
  // =========================================================

  Future<void> capturePhoto() async {
    if (!_checkConsent()) {
      return;
    }

    _setLoading(true);

    try {
      _errorMessage = null;

      final image =
      await _outfitRepository.capturePhoto(
        consentGiven: _consentGiven,
      );

      if (image != null) {
        _setSelectedImage(image);
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // =========================================================
  // GALLERY
  // =========================================================

  Future<void> selectPhoto() async {
    if (!_checkConsent()) {
      return;
    }

    _setLoading(true);

    try {
      _errorMessage = null;

      final image =
      await _outfitRepository.selectPhoto(
        consentGiven: _consentGiven,
      );

      if (image != null) {
        _setSelectedImage(image);
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // =========================================================
  // ANDROID LOST PHOTO RECOVERY
  // =========================================================

  Future<void> recoverLostPhoto() async {
    try {
      final image =
      await _outfitRepository
          .recoverLostPhoto();

      if (image != null) {
        _setSelectedImage(image);
      }
    } catch (e) {
      _errorMessage = e.toString();

      notifyListeners();
    }
  }

  // =========================================================
  // MODEL INITIALIZATION
  // =========================================================

  Future<void> initializeModel({
    required String modelAssetPath,
  }) async {
    _setLoading(true);

    try {
      _errorMessage = null;

      await _outfitRepository.initializeModel(
        modelAssetPath: modelAssetPath,
      );

      _isModelReady =
          _outfitRepository.isModelReady;
    } catch (e) {
      _isModelReady = false;
      _errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> initializeOutfitModels({
    required String sleeveModelAssetPath,
    required String lowerBodyModelAssetPath,
    required String shoulderModelAssetPath,
    required String headwearModelAssetPath,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _outfitRepository.initializeModel(
        modelAssetPath: sleeveModelAssetPath,
      );

      await _outfitRepository.initializeLowerBodyModel(
        modelAssetPath: lowerBodyModelAssetPath,
      );

      await _outfitRepository.initializeShoulderModel(
        modelAssetPath: shoulderModelAssetPath,
      );

      await _outfitRepository.initializeHeadwearModel(
        modelAssetPath: headwearModelAssetPath,
      );

      _isModelReady =
          _outfitRepository.areOutfitModelsReady;
    } catch (e) {
      _errorMessage =
      'Failed to initialize outfit models: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // =========================================================
  // REAL SLEEVE COVERAGE ANALYSIS
  // =========================================================

  Future<void> analyseSleeveCoverage() async {
    final image = _selectedImage;

    if (image == null) {
      _errorMessage =
      'Please take or upload an outfit photo first.';

      notifyListeners();
      return;
    }

    if (!_outfitRepository.isModelReady) {
      _errorMessage =
      'Outfit recognition model is not ready.';

      notifyListeners();
      return;
    }

    _setAnalysing(true);

    try {
      _errorMessage = null;
      _advisoryResult = null;

      // Prepare model input
      _preparedInput =
          _outfitRepository
              .prepareImageForModel(
            image,
          );

      // Run real TensorFlow Lite model
      final prediction =
      _outfitRepository
          .predictSleeveCoverage(
        preparedInput:
        _preparedInput!,
      );

      _sleevePrediction =
          prediction;

      _detectedAttributes.clear();

      // Only accept AI prediction when
      // confidence is at least 75%.
      if (prediction.confidence >= 0.75) {
        _detectedAttributes[
        'sleeveCoverage'
        ] = OutfitAttributePrediction(
          attribute: 'sleeveCoverage',
          value: prediction.value,
          confidence:
          prediction.confidence,
        );
      }

      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _setAnalysing(false);
    }
  }

  Future<void> analyseOutfit() async {
    final image = _selectedImage;

    if (image == null) {
      _errorMessage =
      'Please take or upload an outfit photo first.';

      notifyListeners();
      return;
    }

    if (!_outfitRepository.areOutfitModelsReady) {
      _errorMessage =
      'Outfit recognition models are not ready.';

      notifyListeners();
      return;
    }

    _setAnalysing(true);

    try {
      _errorMessage = null;
      _advisoryResult = null;

      // =====================================================
      // 1. SLEEVE COVERAGE
      // =====================================================

      final sleeveInput =
      _outfitRepository.prepareImageForModel(
        image,
      );

      final sleevePrediction =
      _outfitRepository.predictSleeveCoverage(
        preparedInput: sleeveInput,
      );

      _sleevePrediction =
          sleevePrediction;

      // =====================================================
      // 2. LOWER-BODY COVERAGE
      // =====================================================

      final lowerBodyInput =
      _outfitRepository
          .prepareLowerBodyImageForModel(
        image,
      );

      final lowerBodyPrediction =
      _outfitRepository
          .predictLowerBodyCoverage(
        preparedInput: lowerBodyInput,
      );

      _lowerBodyPrediction =
          lowerBodyPrediction;

      // =====================================================
      // 3. SHOULDER COVERAGE
      // =====================================================

      final shoulderInput =
      _outfitRepository
          .prepareShoulderImageForModel(
        image,
      );

      final headwearInput =
      _outfitRepository.prepareHeadwearImageForModel(
        image,
      );

      final headwearPrediction =
      _outfitRepository.predictHeadwear(
        preparedInput: headwearInput,
      );

      _headwearPrediction =
          headwearPrediction;

      final shoulderPrediction =
      _outfitRepository
          .predictShoulderCoverage(
        preparedInput: shoulderInput,
      );

      _shoulderPrediction =
          shoulderPrediction;

      // =====================================================
      // 4. STORE ALL ATTRIBUTES
      // =====================================================

      _detectedAttributes.clear();

      _detectedAttributes[
      'sleeveCoverage'
      ] = OutfitAttributePrediction(
        attribute: 'sleeveCoverage',
        value: sleevePrediction.value,
        confidence: sleevePrediction.confidence,
      );

      _detectedAttributes[
      'lowerBodyCoverage'
      ] = OutfitAttributePrediction(
        attribute: 'lowerBodyCoverage',
        value: lowerBodyPrediction.value,
        confidence: lowerBodyPrediction.confidence,
      );

      _detectedAttributes[
      'shoulderCoverage'
      ] = OutfitAttributePrediction(
        attribute: 'shoulderCoverage',
        value: shoulderPrediction.value,
        confidence: shoulderPrediction.confidence,
      );

      _detectedAttributes[
      'headwearPresence'
      ] = OutfitAttributePrediction(
        attribute: 'headwearPresence',
        value: headwearPrediction.value,
        confidence: headwearPrediction.confidence,
      );

      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _setAnalysing(false);
    }
  }

  // =========================================================
  // PREPARE IMAGE ONLY
  // =========================================================

  Future<bool> prepareSelectedImage() async {
    final image = _selectedImage;

    if (image == null) {
      _errorMessage =
      'Please take or upload an outfit photo first.';

      notifyListeners();
      return false;
    }

    if (!_outfitRepository.isModelReady) {
      _errorMessage =
      'Outfit recognition model is not ready.';

      notifyListeners();
      return false;
    }

    _setAnalysing(true);

    try {
      _errorMessage = null;

      _preparedInput =
          _outfitRepository
              .prepareImageForModel(
            image,
          );

      return true;
    } catch (e) {
      _errorMessage = e.toString();

      return false;
    } finally {
      _setAnalysing(false);
    }
  }

  // =========================================================
  // GENERIC ATTRIBUTE RESULTS
  // =========================================================

  void setDetectedAttributes(
      Map<String, OutfitAttributePrediction>
      predictions,
      ) {
    _detectedAttributes
      ..clear()
      ..addAll(predictions);

    _advisoryResult = null;
    _errorMessage = null;

    notifyListeners();
  }

  // =========================================================
  // DRESS CODE COMPARISON
  // =========================================================

  Future<void> evaluateOutfit({
    double minimumConfidence = 0.75,
  }) async {
    if (_detectedAttributes.isEmpty) {
      _errorMessage =
      'No confident outfit attributes were detected.';

      notifyListeners();
      return;
    }

    if (_selectedAttractionId == null) {
      _errorMessage =
      'Please select a destination first.';

      notifyListeners();
      return;
    }

    _setAnalysing(true);

    try {
      _errorMessage = null;

      if (_dressCodeRules.isEmpty) {
        await loadDressCodeRules();
      }

      _advisoryResult =
          _outfitRepository
              .compareWithDressCode(
            detectedAttributes:
            _detectedAttributes,
            dressCodeRules:
            _dressCodeRules,
            minimumConfidence:
            minimumConfidence,
          );
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _setAnalysing(false);
    }
  }

  // =========================================================
  // CLEAR / RESET
  // =========================================================

  void clearPhoto() {
    _selectedImage = null;
    _preparedInput = null;

    _sleevePrediction = null;
    _lowerBodyPrediction = null;
    _shoulderPrediction = null;
    _headwearPrediction = null;

    _detectedAttributes.clear();

    _advisoryResult = null;
    _errorMessage = null;

    notifyListeners();
  }

  void resetAnalysis() {
    _preparedInput = null;

    _sleevePrediction = null;
    _lowerBodyPrediction = null;
    _shoulderPrediction = null;
    _headwearPrediction = null;

    _detectedAttributes.clear();

    _advisoryResult = null;
    _errorMessage = null;

    notifyListeners();
  }

  void clearDestination() {
    _selectedAttractionId = null;
    _selectedAttractionName = null;

    _dressCodeRules = [];
    _advisoryResult = null;

    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;

    notifyListeners();
  }

  // =========================================================
  // PRIVATE METHODS
  // =========================================================

  bool _checkConsent() {
    if (_consentGiven) {
      return true;
    }

    _errorMessage =
    'Please provide consent before using outfit recognition.';

    notifyListeners();

    return false;
  }

  void _setSelectedImage(
      OutfitImageData image,
      ) {
    _selectedImage = image;

    _preparedInput = null;
    _sleevePrediction = null;
    _lowerBodyPrediction = null;
    _shoulderPrediction = null;
    _headwearPrediction = null;

    _detectedAttributes.clear();

    _advisoryResult = null;
    _errorMessage = null;

    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;

    notifyListeners();
  }

  void _setAnalysing(bool value) {
    _isAnalysing = value;

    notifyListeners();
  }

  @override
  void dispose() {
    _outfitRepository.dispose();

    super.dispose();
  }
}