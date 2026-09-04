import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../../data_layer/model/repositories/outfit/outfit_repository.dart';
import '../../../data_layer/model/repositories/outfit/outfit_etiquette_repository.dart';
import '../../../data_layer/model/repositories/attraction/attraction_repository.dart';
import '../../../data_layer/model/services/outfit_recognition/outfit_recognition_service.dart';

class OutfitViewModel extends ChangeNotifier {
  final OutfitRepository _outfitRepository;
  final AttractionRepository _attractionRepository;
  final OutfitEtiquetteRepository _outfitEtiquetteRepository;

  OutfitViewModel({
    OutfitRepository? outfitRepository,
    AttractionRepository? attractionRepository,
    OutfitEtiquetteRepository? outfitEtiquetteRepository,
  })  : _outfitRepository =
      outfitRepository ?? OutfitRepository(),
        _attractionRepository =
            attractionRepository ?? AttractionRepository(),
        _outfitEtiquetteRepository =
            outfitEtiquetteRepository ??
                OutfitEtiquetteRepository();

  // =========================================================
  // HUMAN DETECTION SETTINGS
  // =========================================================

  static const double minimumHumanConfidence = 0.60;

  // =========================================================
  // STATE
  // =========================================================

  bool _isLoading = false;

  String? _errorMessage;

  OutfitImageData? _outfitImage;

  Position? _currentPosition;

  List<Map<String, dynamic>> _nearbyAttractions = [];

  List<Map<String, dynamic>> _recommendations = [];

  Map<String, dynamic>? _selectedAttraction;

  Map<String, dynamic>? _outfitEtiquette;

  // =========================================================
  // AI PREDICTIONS
  // =========================================================

  HumanDetectionPrediction? _humanDetectionPrediction;

  SleeveCoveragePrediction? _sleevePrediction;

  LowerBodyCoveragePrediction? _lowerBodyPrediction;

  ShoulderCoveragePrediction? _shoulderPrediction;

  HeadwearPrediction? _headwearPrediction;

  final Map<String, OutfitAttributePrediction>
  _detectedAttributes = {};

  OutfitAdvisoryResult? _advisoryResult;

  // =========================================================
  // GETTERS
  // =========================================================

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  OutfitImageData? get outfitImage => _outfitImage;

  Position? get currentPosition => _currentPosition;

  List<Map<String, dynamic>> get nearbyAttractions =>
      List.unmodifiable(_nearbyAttractions);

  List<Map<String, dynamic>> get recommendations =>
      List.unmodifiable(_recommendations);

  Map<String, dynamic>? get selectedAttraction =>
      _selectedAttraction;

  Map<String, dynamic>? get outfitEtiquette =>
      _outfitEtiquette;

  // =========================================================
  // HUMAN DETECTION GETTERS
  // =========================================================

  HumanDetectionPrediction?
  get humanDetectionPrediction =>
      _humanDetectionPrediction;

  bool get hasValidHuman =>
      _humanDetectionPrediction?.passesThreshold(
        minimumConfidence:
        minimumHumanConfidence,
      ) ??
          false;

  // =========================================================
  // OUTFIT PREDICTION GETTERS
  // =========================================================

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

  OutfitAdvisoryResult? get advisoryResult =>
      _advisoryResult;

  String? get result =>
      _advisoryResult?.displayStatus;

  String? get recommendation =>
      _advisoryResult?.message;

  // =========================================================
  // MODEL STATUS
  // =========================================================

  bool get isHumanDetectionModelReady =>
      _outfitRepository
          .isHumanDetectionModelReady;

  bool get isModelReady =>
      _outfitRepository.isModelReady;

  bool get isSleeveModelReady =>
      _outfitRepository.isSleeveModelReady;

  bool get isLowerBodyModelReady =>
      _outfitRepository.isLowerBodyModelReady;

  bool get isShoulderModelReady =>
      _outfitRepository.isShoulderModelReady;

  bool get isHeadwearModelReady =>
      _outfitRepository.isHeadwearModelReady;

  bool get areOutfitModelsReady =>
      _outfitRepository.areOutfitModelsReady;

  // =========================================================
  // INITIALIZE MODELS
  // =========================================================

  Future<void> initializeModels({
    required String humanModelAssetPath,
    required String modelAssetPath,
    required String lowerBodyModelAssetPath,
    required String shoulderModelAssetPath,
    required String headwearModelAssetPath,
  }) async {
    try {
      _setLoading(true);

      _errorMessage = null;

      // =====================================================
      // HUMAN DETECTION MODEL
      // =====================================================

      await _outfitRepository
          .initializeHumanDetectionModel(
        modelAssetPath:
        humanModelAssetPath,
      );

      // =====================================================
      // SLEEVE MODEL
      // =====================================================

      await _outfitRepository.initializeModel(
        modelAssetPath: modelAssetPath,
      );

      // =====================================================
      // LOWER BODY MODEL
      // =====================================================

      await _outfitRepository
          .initializeLowerBodyModel(
        modelAssetPath:
        lowerBodyModelAssetPath,
      );

      // =====================================================
      // SHOULDER MODEL
      // =====================================================

      await _outfitRepository
          .initializeShoulderModel(
        modelAssetPath:
        shoulderModelAssetPath,
      );

      // =====================================================
      // HEADWEAR MODEL
      // =====================================================

      await _outfitRepository
          .initializeHeadwearModel(
        modelAssetPath:
        headwearModelAssetPath,
      );
    } catch (e) {
      _errorMessage = e.toString();

      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  // =========================================================
  // CAMERA
  // =========================================================

  Future<void> capturePhoto({
    required bool consentGiven,
  }) async {
    try {
      _setLoading(true);

      _errorMessage = null;

      final result =
      await _outfitRepository.capturePhoto(
        consentGiven: consentGiven,
      );

      if (result != null) {
        setOutfitImage(result);
      }
    } catch (e) {
      _errorMessage = e.toString();

      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  // =========================================================
  // GALLERY
  // =========================================================

  Future<void> selectPhoto({
    required bool consentGiven,
  }) async {
    try {
      _setLoading(true);

      _errorMessage = null;

      final result =
      await _outfitRepository.selectPhoto(
        consentGiven: consentGiven,
      );

      if (result != null) {
        setOutfitImage(result);
      }
    } catch (e) {
      _errorMessage = e.toString();

      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  // =========================================================
  // RECOVER LOST PHOTO
  // =========================================================

  Future<void> recoverLostPhoto() async {
    try {
      _setLoading(true);

      _errorMessage = null;

      final result =
      await _outfitRepository.recoverLostPhoto();

      if (result != null) {
        setOutfitImage(result);
      }
    } catch (e) {
      _errorMessage = e.toString();

      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  // =========================================================
  // SET OUTFIT IMAGE
  // =========================================================

  void setOutfitImage(
      OutfitImageData image,
      ) {
    _outfitImage = image;

    _clearAnalysisResults();

    notifyListeners();
  }

  // =========================================================
  // ANALYSE OUTFIT
  // =========================================================

  Future<void> analyseOutfit() async {
    final image = _outfitImage;

    // =======================================================
    // IMAGE VALIDATION
    // =======================================================

    if (image == null) {
      _errorMessage =
      'Please take or upload an outfit photo first.';

      notifyListeners();

      return;
    }

    // =======================================================
    // MODEL VALIDATION
    // =======================================================

    if (!_outfitRepository.areOutfitModelsReady) {
      _errorMessage =
      'Outfit recognition models are not ready.';

      notifyListeners();

      return;
    }

    _setLoading(true);

    try {
      _errorMessage = null;

      _advisoryResult = null;

      // =====================================================
      // STEP 1
      // HUMAN DETECTION
      //
      // THIS MUST PASS BEFORE ANY OUTFIT MODEL RUNS.
      // =====================================================

      final humanInput =
      _outfitRepository
          .prepareHumanDetectionImageForModel(
        image,
      );

      _humanDetectionPrediction =
          _outfitRepository
              .predictHumanPresence(
            preparedInput: humanInput,
          );

      // =====================================================
      // HUMAN GATE
      // =====================================================

      if (!_humanDetectionPrediction!
          .passesThreshold(
        minimumConfidence:
        minimumHumanConfidence,
      )) {
        // Clear all outfit predictions.
        //
        // We deliberately KEEP the human prediction
        // so the UI can inspect/display the result.

        _sleevePrediction = null;

        _lowerBodyPrediction = null;

        _shoulderPrediction = null;

        _headwearPrediction = null;

        _detectedAttributes.clear();

        _advisoryResult =
        const OutfitAdvisoryResult(
          status:
          OutfitAdvisoryStatus
              .unableToDetermine,
          checks: [],
          message:
          'No person was detected confidently in this image.',
        );

        _errorMessage =
        'No person detected. Please take or upload '
            'a clear photo showing a person.';

        notifyListeners();

        // ===================================================
        // IMPORTANT
        //
        // STOP HERE.
        //
        // Sleeve, lower-body, shoulder and headwear
        // models DO NOT RUN.
        // ===================================================

        return;
      }

      // =====================================================
      // STEP 2
      // SLEEVE COVERAGE
      // =====================================================

      final sleeveInput =
      _outfitRepository.prepareImageForModel(
        image,
      );

      _sleevePrediction =
          _outfitRepository
              .predictSleeveCoverage(
            preparedInput: sleeveInput,
          );

      // =====================================================
      // STEP 3
      // LOWER BODY COVERAGE
      // =====================================================

      final lowerBodyInput =
      _outfitRepository
          .prepareLowerBodyImageForModel(
        image,
      );

      _lowerBodyPrediction =
          _outfitRepository
              .predictLowerBodyCoverage(
            preparedInput: lowerBodyInput,
          );

      // =====================================================
      // STEP 4
      // SHOULDER COVERAGE
      // =====================================================

      final shoulderInput =
      _outfitRepository
          .prepareShoulderImageForModel(
        image,
      );

      _shoulderPrediction =
          _outfitRepository
              .predictShoulderCoverage(
            preparedInput: shoulderInput,
          );

      // =====================================================
      // STEP 5
      // HEADWEAR
      // =====================================================

      final headwearInput =
      _outfitRepository
          .prepareHeadwearImageForModel(
        image,
      );

      _headwearPrediction =
          _outfitRepository.predictHeadwear(
            preparedInput: headwearInput,
          );

      // =====================================================
      // STEP 6
      // STORE DETECTED ATTRIBUTES
      // =====================================================

      _detectedAttributes.clear();

      _detectedAttributes[
      'sleeveCoverage'] =
          OutfitAttributePrediction(
            attribute: 'sleeveCoverage',
            value:
            _sleevePrediction!.value,
            confidence:
            _sleevePrediction!.confidence,
          );

      _detectedAttributes[
      'lowerBodyCoverage'] =
          OutfitAttributePrediction(
            attribute:
            'lowerBodyCoverage',
            value:
            _lowerBodyPrediction!.value,
            confidence:
            _lowerBodyPrediction!.confidence,
          );

      _detectedAttributes[
      'shoulderCoverage'] =
          OutfitAttributePrediction(
            attribute:
            'shoulderCoverage',
            value:
            _shoulderPrediction!.value,
            confidence:
            _shoulderPrediction!.confidence,
          );

      _detectedAttributes[
      'headwearPresence'] =
          OutfitAttributePrediction(
            attribute:
            'headwearPresence',
            value:
            _headwearPrediction!.value,
            confidence:
            _headwearPrediction!.confidence,
          );

      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();

      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  // =========================================================
  // GET CURRENT LOCATION
  // =========================================================

  Future<void> getCurrentLocation() async {
    try {
      _errorMessage = null;

      _currentPosition =
      await _attractionRepository
          .getCurrentLocation();

      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();

      notifyListeners();
    }
  }

  // =========================================================
  // FIND NEARBY ATTRACTIONS
  // =========================================================

  Future<void> loadNearbyAttractions({
    double radiusInMeters = 10000,
  }) async {
    try {
      _setLoading(true);

      _errorMessage = null;

      if (_currentPosition == null) {
        await getCurrentLocation();
      }

      if (_currentPosition == null) {
        throw Exception(
          'Unable to determine your current location.',
        );
      }

      final attractions =
      await _attractionRepository
          .getAllAttractions();

      final nearby =
      <Map<String, dynamic>>[];

      for (final attraction in attractions) {
        final latitude = _toDouble(
          attraction['latitude'] ??
              attraction['lat'],
        );

        final longitude = _toDouble(
          attraction['longitude'] ??
              attraction['lng'] ??
              attraction['lon'],
        );

        if (latitude == null ||
            longitude == null) {
          continue;
        }

        final distance =
        _attractionRepository
            .getDistanceFromAttraction(
          currentPosition:
          _currentPosition!,
          attractionLatitude:
          latitude,
          attractionLongitude:
          longitude,
        );

        if (distance <= radiusInMeters) {
          nearby.add({
            ...attraction,
            'distance': distance,
          });
        }
      }

      nearby.sort(
            (a, b) {
          final distanceA =
          a['distance'] as double;

          final distanceB =
          b['distance'] as double;

          return distanceA.compareTo(
            distanceB,
          );
        },
      );

      _nearbyAttractions = nearby;

      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();

      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  // =========================================================
  // GET ETIQUETTE FOR ATTRACTION
  // =========================================================

  Future<Map<String, dynamic>?>
  getEtiquetteForAttraction(
      Map<String, dynamic> attraction,
      ) async {
    final category =
    attraction['category']?.toString();

    if (category == null ||
        category.isEmpty) {
      return null;
    }

    return await _outfitEtiquetteRepository
        .getOutfitByCategory(
      category,
    );
  }

  // =========================================================
  // GENERATE RECOMMENDATIONS
  // =========================================================

  Future<void> generateRecommendations() async {
    try {
      _setLoading(true);

      _errorMessage = null;

      if (_nearbyAttractions.isEmpty) {
        await loadNearbyAttractions();
      }

      final results =
      <Map<String, dynamic>>[];

      for (final attraction
      in _nearbyAttractions) {
        final category =
        attraction['category']?.toString();

        if (category == null ||
            category.isEmpty) {
          continue;
        }

        final etiquette =
        await _outfitEtiquetteRepository
            .getOutfitByCategory(
          category,
        );

        results.add({
          ...attraction,
          'outfitEtiquette': etiquette,
        });
      }

      _recommendations = results;

      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();

      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  // =========================================================
  // SELECT ATTRACTION
  // =========================================================

  Future<void> selectAttraction(
      Map<String, dynamic> attraction,
      ) async {
    try {
      _selectedAttraction =
          attraction;

      final category =
      attraction['category']?.toString();

      if (category != null &&
          category.isNotEmpty) {
        _outfitEtiquette =
        await _outfitEtiquetteRepository
            .getOutfitByCategory(
          category,
        );
      } else {
        _outfitEtiquette = null;
      }

      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();

      notifyListeners();
    }
  }

  // =========================================================
  // CHECK OUTFIT AGAINST ETIQUETTE
  // =========================================================

  bool isSuitableForSelectedAttraction({
    required double minimumConfidence,
  }) {
    // Human detection must have passed first.

    if (!hasValidHuman) {
      return false;
    }

    if (_outfitEtiquette == null) {
      return false;
    }

    if (_detectedAttributes.isEmpty) {
      return false;
    }

    final result =
    _outfitRepository.compareWithDressCode(
      detectedAttributes:
      _detectedAttributes,
      dressCodeRules: [
        _outfitEtiquette!,
      ],
      minimumConfidence:
      minimumConfidence,
    );

    _advisoryResult = result;

    notifyListeners();

    return result.status ==
        OutfitAdvisoryStatus.suitable;
  }

  // =========================================================
  // RUN FULL OUTFIT CHECK
  // =========================================================

  Future<void> checkOutfitForAttraction({
    required Map<String, dynamic> attraction,
    double minimumConfidence = 0.75,
  }) async {
    try {
      _setLoading(true);

      _errorMessage = null;

      await selectAttraction(
        attraction,
      );

      // =====================================================
      // IMAGE MUST EXIST
      // =====================================================

      if (_outfitImage == null) {
        throw Exception(
          'Please take or upload an outfit photo first.',
        );
      }

      // =====================================================
      // RUN AI ANALYSIS IF NEEDED
      // =====================================================

      if (_detectedAttributes.isEmpty ||
          _humanDetectionPrediction == null) {
        await analyseOutfit();
      }

      // =====================================================
      // HUMAN DETECTION SAFEGUARD
      //
      // If analyseOutfit() rejected the image,
      // stop the attraction etiquette flow too.
      // =====================================================

      if (!hasValidHuman ||
          _detectedAttributes.isEmpty) {
        return;
      }

      // =====================================================
      // ETIQUETTE MUST EXIST
      // =====================================================

      if (_outfitEtiquette == null) {
        _advisoryResult =
        const OutfitAdvisoryResult(
          status:
          OutfitAdvisoryStatus
              .unableToDetermine,
          checks: [],
          message:
          'No outfit etiquette rules were found for this attraction.',
        );

        notifyListeners();

        return;
      }

      // =====================================================
      // COMPARE OUTFIT WITH ETIQUETTE
      // =====================================================

      final result =
      _outfitRepository
          .compareWithDressCode(
        detectedAttributes:
        _detectedAttributes,
        dressCodeRules: [
          _outfitEtiquette!,
        ],
        minimumConfidence:
        minimumConfidence,
      );

      _advisoryResult = result;

      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();

      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  // =========================================================
  // CLEAR ANALYSIS
  // =========================================================

  void _clearAnalysisResults() {
    _humanDetectionPrediction = null;

    _sleevePrediction = null;

    _lowerBodyPrediction = null;

    _shoulderPrediction = null;

    _headwearPrediction = null;

    _detectedAttributes.clear();

    _advisoryResult = null;
  }

  // =========================================================
  // CLEAR ALL RESULTS
  // =========================================================

  void clearResults() {
    _outfitImage = null;

    _clearAnalysisResults();

    _nearbyAttractions = [];

    _recommendations = [];

    _selectedAttraction = null;

    _outfitEtiquette = null;

    notifyListeners();
  }

  // =========================================================
  // CLEAR ERROR
  // =========================================================

  void clearError() {
    _errorMessage = null;

    notifyListeners();
  }

  // =========================================================
  // LOADING
  // =========================================================

  void _setLoading(bool value) {
    _isLoading = value;

    notifyListeners();
  }

  // =========================================================
  // DOUBLE CONVERSION
  // =========================================================

  double? _toDouble(
      dynamic value,
      ) {
    if (value == null) {
      return null;
    }

    if (value is double) {
      return value;
    }

    if (value is int) {
      return value.toDouble();
    }

    return double.tryParse(
      value.toString(),
    );
  }

  // =========================================================
  // CLEANUP
  // =========================================================

  @override
  void dispose() {
    _outfitRepository.dispose();

    super.dispose();
  }
}