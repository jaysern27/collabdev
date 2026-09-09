  import 'package:flutter/foundation.dart';

  import '../../../data_layer/model/repositories/etiquette/etiquette_repository.dart';
  import '../../../data_layer/model/repositories/outfit/outfit_place_recommendation_repository.dart';
  import '../../../data_layer/model/repositories/outfit/outfit_repository.dart';
  import '../../../data_layer/model/services/outfit_recognition/outfit_recognition_service.dart';

  class OutfitRecognitionViewModel extends ChangeNotifier {
    final OutfitRepository _outfitRepository;
    final EtiquetteRepository _etiquetteRepository;
    final OutfitPlaceRecommendationRepository
    _placeRecommendationRepository;

    OutfitRecognitionViewModel({
      OutfitRepository? outfitRepository,
      EtiquetteRepository? etiquetteRepository,
      OutfitPlaceRecommendationRepository?
      placeRecommendationRepository,
    })  : _outfitRepository =
        outfitRepository ?? OutfitRepository(),
          _etiquetteRepository =
              etiquetteRepository ?? EtiquetteRepository(),
          _placeRecommendationRepository =
              placeRecommendationRepository ??
                  OutfitPlaceRecommendationRepository();

    // =========================================================
    // HUMAN DETECTION SETTINGS
    // =========================================================

    static const double minimumHumanConfidence = 0.60;

    // Keep this aligned with the Cultural Map module.
    static const double recommendationRadiusKm = 20.0;

    // Recommendations remain conservative even though the UI
    // always displays the classifier's highest-scoring label.
    //
    // Lowered from 0.75 -- the shoulder model in particular
    // regularly sits around ~50-55% confidence even on correct
    // predictions (it hasn't been retrained/improved like the
    // other models), so 0.75 was excluding almost every place from
    // recommendations regardless of whether the outfit actually
    // matched. Revisit this once the shoulder model itself is
    // retrained to be more confident.
    static const double recommendationMinimumConfidence = 0.5;

    static const int maximumPlaceRecommendations = 5;

    // =========================================================
    // STATE
    // =========================================================

    bool _consentGiven = false;
    bool _isLoading = false;
    bool _isAnalysing = false;
    bool _isModelReady = false;

    OutfitGender? _selectedGender;

    String? _selectedAttractionId;
    String? _selectedAttractionName;

    OutfitImageData? _selectedImage;
    PreparedOutfitInput? _preparedInput;

    // =========================================================
    // AI PREDICTIONS
    // =========================================================

    HumanDetectionPrediction? _humanDetectionPrediction;
    FullBodyValidationResult? _fullBodyValidationResult;
    SleeveCoveragePrediction? _sleevePrediction;
    LowerBodyCoveragePrediction? _lowerBodyPrediction;
    ShoulderCoveragePrediction? _shoulderPrediction;
    HeadwearPrediction? _headwearPrediction;

    final Map<String, OutfitAttributePrediction>
    _detectedAttributes = {};

    List<Map<String, dynamic>> _dressCodeRules = [];

    OutfitAdvisoryResult? _advisoryResult;

    // =========================================================
    // NEARBY OUTFIT-MATCHED PLACE RECOMMENDATIONS
    // =========================================================

    bool _isFindingPlaceRecommendations = false;

    bool _recommendationsUsingDefaultArea = false;

    List<Map<String, dynamic>>
    _placeRecommendations = [];

    String? _placeRecommendationMessage;

    String? _errorMessage;

    // =========================================================
    // GETTERS
    // =========================================================

    bool get consentGiven => _consentGiven;

    bool get isLoading => _isLoading;

    bool get isAnalysing => _isAnalysing;

    bool get isModelReady => _isModelReady;

    OutfitGender? get selectedGender => _selectedGender;

    bool get hasSelectedGender => _selectedGender != null;

    bool get areModelsReady =>
        _outfitRepository.areOutfitModelsReady;

    bool get hasSelectedImage =>
        _selectedImage != null;

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

    FullBodyValidationResult?
    get fullBodyValidationResult =>
        _fullBodyValidationResult;

    bool get hasValidFullBody =>
        _fullBodyValidationResult
            ?.isValid ??
            false;

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

    bool get isHumanDetectionModelReady =>
        _outfitRepository
            .isHumanDetectionModelReady;

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
        Map.unmodifiable(
          _detectedAttributes,
        );

    List<Map<String, dynamic>> get dressCodeRules =>
        List.unmodifiable(
          _dressCodeRules,
        );

    OutfitAdvisoryResult? get advisoryResult =>
        _advisoryResult;

    String? get result =>
        _advisoryResult?.displayStatus;

    String? get recommendation =>
        _advisoryResult?.message;

    bool get isFindingPlaceRecommendations =>
        _isFindingPlaceRecommendations;

    bool get recommendationsUsingDefaultArea =>
        _recommendationsUsingDefaultArea;

    List<Map<String, dynamic>>
    get placeRecommendations =>
        List.unmodifiable(
          _placeRecommendations,
        );

    String? get placeRecommendationMessage =>
        _placeRecommendationMessage;

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
    // GENDER
    //
    // Some dress-code rules (e.g. headwear) differ by gender,
    // so this must be selected before outfit analysis runs.
    // =========================================================

    void setGender(OutfitGender gender) {
      _selectedGender = gender;

      notifyListeners();
    }

    // =========================================================
    // DESTINATION
    // =========================================================

    Future<void> selectDestination({
      required String attractionId,
      required String attractionName,
    }) async {
      _selectedAttractionId =
          attractionId;

      _selectedAttractionName =
          attractionName;

      _dressCodeRules = [];

      _advisoryResult = null;

      _errorMessage = null;

      notifyListeners();

      await loadDressCodeRules();
    }

    Future<void> loadDressCodeRules() async {
      final attractionId =
          _selectedAttractionId;

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
        _errorMessage =
            e.toString();
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
        await _outfitRepository
            .capturePhoto(
          consentGiven:
          _consentGiven,
        );

        if (image != null) {
          _setSelectedImage(
            image,
          );
        }
      } catch (e) {
        _errorMessage =
            e.toString();
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
        await _outfitRepository
            .selectPhoto(
          consentGiven:
          _consentGiven,
        );

        if (image != null) {
          _setSelectedImage(
            image,
          );
        }
      } catch (e) {
        _errorMessage =
            e.toString();
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
          _setSelectedImage(
            image,
          );
        }
      } catch (e) {
        _errorMessage =
            e.toString();

        notifyListeners();
      }
    }

    // =========================================================
    // LEGACY SINGLE MODEL INITIALIZATION
    // =========================================================

    Future<void> initializeModel({
      required String modelAssetPath,
    }) async {
      _setLoading(true);

      try {
        _errorMessage = null;

        await _outfitRepository
            .initializeModel(
          modelAssetPath:
          modelAssetPath,
        );

        // Do not report the entire module
        // ready unless ALL models are loaded.
        _isModelReady =
            _outfitRepository
                .areOutfitModelsReady;
      } catch (e) {
        _isModelReady = false;

        _errorMessage =
            e.toString();
      } finally {
        _setLoading(false);
      }
    }

    // =========================================================
    // INITIALIZE ALL OUTFIT MODELS
    // =========================================================

    Future<void> initializeOutfitModels({
      required String humanModelAssetPath,
      required String sleeveModelAssetPath,
      required String lowerBodyModelAssetPath,
      required String shoulderModelAssetPath,
      required String headwearModelAssetPath,
    }) async {
      try {
        _isLoading = true;

        _isModelReady = false;

        _errorMessage = null;

        notifyListeners();

        // =====================================================
        // 1. HUMAN DETECTION MODEL
        // =====================================================

        await _outfitRepository
            .initializeHumanDetectionModel(
          modelAssetPath:
          humanModelAssetPath,
        );

        // =====================================================
        // 2. SLEEVE MODEL
        // =====================================================

        await _outfitRepository
            .initializeModel(
          modelAssetPath:
          sleeveModelAssetPath,
        );

        // =====================================================
        // 3. LOWER BODY MODEL
        // =====================================================

        await _outfitRepository
            .initializeLowerBodyModel(
          modelAssetPath:
          lowerBodyModelAssetPath,
        );

        // =====================================================
        // 4. SHOULDER MODEL
        // =====================================================

        await _outfitRepository
            .initializeShoulderModel(
          modelAssetPath:
          shoulderModelAssetPath,
        );

        // =====================================================
        // 5. HEADWEAR MODEL
        // =====================================================

        await _outfitRepository
            .initializeHeadwearModel(
          modelAssetPath:
          headwearModelAssetPath,
        );

        // =====================================================
        // CHECK ALL FIVE MODELS
        // =====================================================

        _isModelReady =
            _outfitRepository
                .areOutfitModelsReady;

        if (!_isModelReady) {
          _errorMessage =
          'One or more AI models failed to become ready.';
        }
      } catch (e) {
        _isModelReady = false;

        _errorMessage =
        'Failed to initialize outfit models: $e';
      } finally {
        _isLoading = false;

        notifyListeners();
      }
    }

    // =========================================================
    // HUMAN DETECTION
    // =========================================================

    bool _detectHuman(
        OutfitImageData image,
        ) {
      if (!_outfitRepository
          .isHumanDetectionModelReady) {
        _errorMessage =
        'Human detection model is not ready.';

        return false;
      }

      final humanInput =
      _outfitRepository
          .prepareHumanDetectionImageForModel(
        image,
      );

      final prediction =
      _outfitRepository
          .predictHumanPresence(
        preparedInput:
        humanInput,
      );

      debugPrint(
        '================ HUMAN DEBUG ================',
      );

      debugPrint(
        'prediction.value = ${prediction.value}',
      );

      debugPrint(
        'prediction.confidence = ${prediction.confidence}',
      );

      debugPrint(
        'humanConfidence = ${prediction.humanConfidence}',
      );

      debugPrint(
        'noHumanConfidence = ${prediction.noHumanConfidence}',
      );

      debugPrint(
        'minimum required = $minimumHumanConfidence',
      );

      debugPrint(
        '=============================================',
      );

      _humanDetectionPrediction =
          prediction;

      if (!prediction.passesThreshold(
        minimumConfidence:
        minimumHumanConfidence,
      )) {
        // Clear all outfit predictions.
        // Keep the human prediction so it can
        // still be inspected if needed.

        _preparedInput = null;

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

        return false;
      }

      return true;
    }

    // =========================================================
  // FULL-BODY / POSE VALIDATION
  // =========================================================

    Future<bool> _validateFullBody(
        OutfitImageData image,
        ) async {
      final validation =
      await _outfitRepository
          .validateFullBodyVisibility(
        image,
        minimumLandmarkLikelihood:
        0.55,
        minimumBodyHeightRatio:
        0.55,
      );

      _fullBodyValidationResult =
          validation;

      if (!validation.isValid) {
        _preparedInput = null;

        _sleevePrediction = null;
        _lowerBodyPrediction = null;
        _shoulderPrediction = null;
        _headwearPrediction = null;

        _detectedAttributes.clear();

        _advisoryResult =
            OutfitAdvisoryResult(
              status:
              OutfitAdvisoryStatus
                  .unableToDetermine,
              checks: const [],
              message:
              validation.message,
            );

        _errorMessage =
            validation.message;

        return false;
      }

      return true;
    }

    // =========================================================
    // REAL SLEEVE COVERAGE ANALYSIS
    // =========================================================

    Future<void> analyseSleeveCoverage() async {
      final image =
          _selectedImage;

      if (image == null) {
        _errorMessage =
        'Please take or upload an outfit photo first.';

        notifyListeners();

        return;
      }

      if (!_outfitRepository
          .isHumanDetectionModelReady ||
          !_outfitRepository
              .isModelReady) {
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
        // HUMAN GATE FIRST
        // =====================================================

        if (!_detectHuman(
          image,
        )) {
          notifyListeners();

          return;
        }

        if (!await _validateFullBody(
          image,
        )) {
          notifyListeners();

          return;
        }

        // =====================================================
        // PREPARE SLEEVE INPUT
        // =====================================================

        _preparedInput =
            _outfitRepository
                .prepareImageForModel(
              image,
            );

        // =====================================================
        // RUN SLEEVE MODEL
        // =====================================================

        final prediction =
        _outfitRepository
            .predictSleeveCoverage(
          preparedInput:
          _preparedInput!,
        );

        _sleevePrediction =
            prediction;

        _detectedAttributes.clear();

        if (prediction.confidence >=
            0.75) {
          _detectedAttributes[
          'sleeveCoverage'] =
              OutfitAttributePrediction(
                attribute:
                'sleeveCoverage',
                value:
                prediction.value,
                confidence:
                prediction.confidence,
              );
        }

        notifyListeners();
      } catch (e) {
        _errorMessage =
            e.toString();

        notifyListeners();
      } finally {
        _setAnalysing(false);
      }
    }

    // =========================================================
    // FULL OUTFIT ANALYSIS
    // =========================================================

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

      if (!hasSelectedGender) {
        _errorMessage =
        'Please select your gender before analysing your outfit.';

        notifyListeners();
        return;
      }

      _setAnalysing(true);

      try {
        _errorMessage = null;
        _advisoryResult = null;

        // =====================================================
        // STEP 1
        // HUMAN DETECTION
        // =====================================================

        if (!_detectHuman(image)) {
          notifyListeners();
          return;
        }

        // =====================================================
        // STEP 2
        // FULL-BODY / ARM VISIBILITY
        // =====================================================

        if (!await _validateFullBody(image)) {
          notifyListeners();
          return;
        }

        // =====================================================
        // STEP 3
        // SLEEVE COVERAGE
        // =====================================================

        final sleeveInput =
        _outfitRepository.prepareImageForModel(
          image,
        );

        final sleevePrediction =
        _outfitRepository.predictSleeveCoverage(
          preparedInput: sleeveInput,
        );

        _sleevePrediction = sleevePrediction;

        // =====================================================
        // STEP 4
        // LOWER-BODY COVERAGE
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

        _lowerBodyPrediction = lowerBodyPrediction;

        // =====================================================
        // STEP 5
        // SHOULDER COVERAGE
        // =====================================================

        final shoulderInput =
        _outfitRepository
            .prepareShoulderImageForModel(
          image,
        );

        final shoulderPrediction =
        _outfitRepository
            .predictShoulderCoverage(
          preparedInput: shoulderInput,
        );

        _shoulderPrediction = shoulderPrediction;

        // =====================================================
        // STEP 6
        // HEADWEAR
        // =====================================================

        final headwearInput =
        _outfitRepository
            .prepareHeadwearImageForModel(
          image,
        );

        final headwearPrediction =
        _outfitRepository.predictHeadwear(
          preparedInput: headwearInput,
        );

        _headwearPrediction = headwearPrediction;

        // =====================================================
        // STEP 7
        // STORE ALL ATTRIBUTES
        // =====================================================

        _detectedAttributes.clear();

        _detectedAttributes['sleeveCoverage'] =
            OutfitAttributePrediction(
              attribute: 'sleeveCoverage',
              value: sleevePrediction.value,
              confidence: sleevePrediction.confidence,
            );

        _detectedAttributes['lowerBodyCoverage'] =
            OutfitAttributePrediction(
              attribute: 'lowerBodyCoverage',
              value: lowerBodyPrediction.value,
              confidence: lowerBodyPrediction.confidence,
            );

        _detectedAttributes['shoulderCoverage'] =
            OutfitAttributePrediction(
              attribute: 'shoulderCoverage',
              value: shoulderPrediction.value,
              confidence: shoulderPrediction.confidence,
            );

        _detectedAttributes['headwearPresence'] =
            OutfitAttributePrediction(
              attribute: 'headwearPresence',
              value: headwearPrediction.value,
              confidence: headwearPrediction.confidence,
            );

        // =====================================================
        // STEP 8
        // FIND NEARBY PLACES THAT MATCH THIS OUTFIT
        // =====================================================

        await _generatePlaceRecommendations();

        notifyListeners();
      } catch (e) {
        _errorMessage = e.toString();

        notifyListeners();
      } finally {
        _setAnalysing(false);
      }
    }

    // =========================================================
    // NEARBY PLACE RECOMMENDATIONS
    // =========================================================

    Future<void> refreshPlaceRecommendations() async {
      if (_detectedAttributes.isEmpty ||
          !hasValidHuman ||
          !hasValidFullBody) {
        _placeRecommendationMessage =
        'Analyse a clear full-body outfit photo first.';

        notifyListeners();

        return;
      }

      await _generatePlaceRecommendations();
    }

    Future<void>
    _generatePlaceRecommendations() async {
      if (_detectedAttributes.isEmpty) {
        return;
      }

      _isFindingPlaceRecommendations =
      true;

      _placeRecommendations = [];

      _placeRecommendationMessage =
      null;

      notifyListeners();

      try {
        // =======================================================
        // STEP 1
        // GET NEARBY CULTURAL ATTRACTIONS
        // =======================================================

        final nearbyResult =
        await _placeRecommendationRepository
            .getNearbyCulturalAttractions(
          radiusKm:
          recommendationRadiusKm,
        );

        _recommendationsUsingDefaultArea =
            nearbyResult.usingDefaultArea;

        final nearbyAttractions =
            nearbyResult.attractions;

        if (nearbyAttractions.isEmpty) {
          _placeRecommendationMessage =
          nearbyResult
              .usingDefaultArea
              ? 'No supported cultural attractions were found '
              'within ${recommendationRadiusKm.toStringAsFixed(0)} km '
              'of the default Kuala Lumpur pilot area.'
              : 'No supported cultural attractions were found '
              'within ${recommendationRadiusKm.toStringAsFixed(0)} km '
              'of your current location.';

          return;
        }

        // =======================================================
        // STEP 2
        // CHECK EACH NEARBY ATTRACTION
        // =======================================================

        final matches =
        <Map<String, dynamic>>[];

        for (final attraction
        in nearbyAttractions) {
          final category =
              attraction['category']
                  ?.toString()
                  .trim() ??
                  '';

          if (category.isEmpty) {
            continue;
          }

          // =====================================================
          // STEP 3
          // GET CATEGORY OUTFIT RULE
          //
          // Example:
          //
          // Islamic Culture
          //        ↓
          // etiquette_outfit/islamic_culture
          //        ↓
          // sleeve = covered
          // lowerbody = covered
          // shoulder = covered
          // headwear = optional
          // =====================================================

          var dressCodeRules =
          await _placeRecommendationRepository
              .getStructuredDressCodeRulesForCategory(
            category,
            gender: _selectedGender,
          );

          debugPrint(
            '=============================================',
          );

          debugPrint(
            'OUTFIT PLACE CHECK',
          );

          debugPrint(
            'place = ${attraction['name']}',
          );

          debugPrint(
            'category = $category',
          );

          debugPrint(
            'structured rules = '
                '${dressCodeRules.length}',
          );

          // No category-level outfit rule exists yet -- fall back to
          // this specific attraction's free-text dos/donts (shown on
          // the Cultural Map) rather than skipping it outright.
          if (dressCodeRules.isEmpty) {
            dressCodeRules =
                _outfitRepository
                    .deriveDressCodeRulesFromText(
                  dos: attraction['dos'] is List
                      ? attraction['dos'] as List
                      : const [],
                  donts: attraction['donts'] is List
                      ? attraction['donts'] as List
                      : const [],
                  gender: _selectedGender,
                );

            debugPrint(
              'derived rules from dos/donts = '
                  '${dressCodeRules.length}',
            );
          }

          if (dressCodeRules.isEmpty) {
            debugPrint(
              'SKIPPED: no outfit etiquette found.',
            );

            continue;
          }

          // =====================================================
          // STEP 4
          // COMPARE AI RESULTS AGAINST FIRESTORE RULE
          // =====================================================

          final advisory =
          _outfitRepository
              .compareWithDressCode(
            detectedAttributes:
            _detectedAttributes,
            dressCodeRules:
            dressCodeRules,
            minimumConfidence:
            recommendationMinimumConfidence,
          );

          debugPrint(
            'result = '
                '${advisory.displayStatus}',
          );

          debugPrint(
            '=============================================',
          );

          // =====================================================
          // STEP 5
          // ONLY RECOMMEND SUITABLE PLACES
          // =====================================================

          if (advisory.status !=
              OutfitAdvisoryStatus
                  .suitable) {
            continue;
          }

          matches.add({
            ...attraction,

            'outfitStatus':
            advisory.displayStatus,

            'outfitMessage':
            advisory.message,
          });
        }

        // =======================================================
        // STEP 6
        // NEAREST SUITABLE PLACES FIRST
        // =======================================================

        matches.sort(
              (first, second) {
            final firstDistance =
                (first['distanceKm']
                as num?)
                    ?.toDouble() ??
                    double.infinity;

            final secondDistance =
                (second['distanceKm']
                as num?)
                    ?.toDouble() ??
                    double.infinity;

            return firstDistance
                .compareTo(
              secondDistance,
            );
          },
        );

        // =======================================================
        // STEP 7
        // LIMIT TO TOP 5
        // =======================================================

        _placeRecommendations =
            matches
                .take(
              maximumPlaceRecommendations,
            )
                .toList();

        // =======================================================
        // STEP 8
        // RESULT MESSAGE
        // =======================================================

        if (_placeRecommendations
            .isEmpty) {
          _placeRecommendationMessage =
          'No nearby cultural attraction matched '
              'your current outfit requirements.';
        } else {
          final count =
              _placeRecommendations
                  .length;

          _placeRecommendationMessage =
          '$count nearby '
              '${count == 1 ? 'place matches' : 'places match'} '
              'your current outfit.';
        }
      } catch (e, stackTrace) {
      debugPrint(
      'PLACE RECOMMENDATION ERROR: $e',
      );

      debugPrint(
      '$stackTrace',
      );

      _placeRecommendations = [];

      _placeRecommendationMessage =
      'Unable to load nearby place '
      'recommendations right now.';
      } finally {
      _isFindingPlaceRecommendations =
      false;

      notifyListeners();
      }
    }

    // =========================================================
    // PREPARE IMAGE ONLY
    // =========================================================

    Future<bool> prepareSelectedImage() async {
      final image =
          _selectedImage;

      if (image == null) {
        _errorMessage =
        'Please take or upload an outfit photo first.';

        notifyListeners();

        return false;
      }

      if (!_outfitRepository
          .isHumanDetectionModelReady ||
          !_outfitRepository
              .isModelReady) {
        _errorMessage =
        'Outfit recognition models are not ready.';

        notifyListeners();

        return false;
      }

      _setAnalysing(true);

      try {
        _errorMessage = null;

        // Human gate must pass before we
        // prepare the outfit model input.
        if (!_detectHuman(
          image,
        )) {
          notifyListeners();

          return false;
        }

        if (!await _validateFullBody(
          image,
        )) {
          notifyListeners();

          return false;
        }

        _preparedInput =
            _outfitRepository
                .prepareImageForModel(
              image,
            );

        return true;
      } catch (e) {
        _errorMessage =
            e.toString();

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
        ..addAll(
          predictions,
        );

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
      if (!hasValidHuman) {
        _errorMessage =
        'A valid person photo is required before '
            'evaluating outfit etiquette.';

        notifyListeners();

        return;
      }

      if (!hasValidFullBody) {
        _errorMessage =
            _fullBodyValidationResult
                ?.message ??
                'A clear full-body photo is required before '
                    'evaluating outfit etiquette.';

        notifyListeners();

        return;
      }

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
        _errorMessage =
            e.toString();
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

      _humanDetectionPrediction = null;
      _fullBodyValidationResult = null;
      _sleevePrediction = null;
      _lowerBodyPrediction = null;
      _shoulderPrediction = null;
      _headwearPrediction = null;

      _detectedAttributes.clear();

      _advisoryResult = null;

      _placeRecommendations = [];
      _placeRecommendationMessage = null;
      _recommendationsUsingDefaultArea = false;
      _isFindingPlaceRecommendations = false;

      _errorMessage = null;

      notifyListeners();
    }

    void resetAnalysis() {
      _preparedInput = null;

      _humanDetectionPrediction = null;
      _fullBodyValidationResult = null;
      _sleevePrediction = null;
      _lowerBodyPrediction = null;
      _shoulderPrediction = null;
      _headwearPrediction = null;

      _detectedAttributes.clear();

      _advisoryResult = null;

      _placeRecommendations = [];
      _placeRecommendationMessage = null;
      _recommendationsUsingDefaultArea = false;
      _isFindingPlaceRecommendations = false;

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
      'Please provide consent before using '
          'outfit recognition.';

      notifyListeners();

      return false;
    }

    void _setSelectedImage(
        OutfitImageData image,
        ) {
      _selectedImage = image;

      _preparedInput = null;

      _humanDetectionPrediction = null;
      _fullBodyValidationResult = null;
      _sleevePrediction = null;
      _lowerBodyPrediction = null;
      _shoulderPrediction = null;
      _headwearPrediction = null;

      _detectedAttributes.clear();

      _advisoryResult = null;

      _placeRecommendations = [];
      _placeRecommendationMessage = null;
      _recommendationsUsingDefaultArea = false;
      _isFindingPlaceRecommendations = false;

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

    // =========================================================
    // CLEANUP
    // =========================================================

    @override
    void dispose() {
      _outfitRepository.dispose();

      super.dispose();
    }
  }