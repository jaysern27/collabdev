  import 'package:flutter/foundation.dart';

  import '../../../data_layer/model/repositories/etiquette/etiquette_repository.dart';
  import '../../../data_layer/model/repositories/outfit/outfit_place_recommendation_repository.dart';
  import '../../../data_layer/model/repositories/outfit/outfit_repository.dart';
  import '../../../data_layer/model/services/outfit_recognition/outfit_recognition_service.dart';
  import '../settings/app_settings_controller.dart';

  String _t({
    required String en,
    required String zh,
    required String ms,
  }) {
    return AppSettingsController.instance.text(
      en: en,
      zh: zh,
      ms: ms,
    );
  }

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
        _errorMessage = _t(
          en: 'Please select a destination first.',
          zh: '请先选择目的地。',
          ms: 'Sila pilih destinasi dahulu.',
        );

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
          _errorMessage = _t(
            en: 'One or more AI models failed to become ready.',
            zh: '一个或多个 AI 模型未能成功加载。',
            ms: 'Satu atau lebih model AI gagal disediakan.',
          );
        }
      } catch (e) {
        _isModelReady = false;

        _errorMessage =
        '${_t(
          en: 'Failed to initialize outfit models',
          zh: '初始化穿搭模型失败',
          ms: 'Gagal memulakan model pakaian',
        )}: $e';
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
        _errorMessage = _t(
          en: 'Human detection model is not ready.',
          zh: '人体检测模型尚未就绪。',
          ms: 'Model pengesanan orang belum sedia.',
        );

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
        OutfitAdvisoryResult(
          status:
          OutfitAdvisoryStatus
              .unableToDetermine,
          checks: const [],
          message: _t(
            en: 'No person was detected confidently in this image.',
            zh: '未能在此照片中确认检测到人物。',
            ms: 'Tiada orang dikesan dengan yakin dalam gambar ini.',
          ),
        );

        _errorMessage = _t(
          en: 'No person detected. Please take or upload '
              'a clear photo showing a person.',
          zh: '未检测到人物。请拍摄或上传一张能清楚看到人物的照片。',
          ms: 'Tiada orang dikesan. Sila ambil atau muat naik foto '
              'jelas yang menunjukkan seseorang.',
        );

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
        _errorMessage = _t(
          en: 'Please take or upload an outfit photo first.',
          zh: '请先拍摄或上传一张穿搭照片。',
          ms: 'Sila ambil atau muat naik foto pakaian dahulu.',
        );

        notifyListeners();

        return;
      }

      if (!_outfitRepository
          .isHumanDetectionModelReady ||
          !_outfitRepository
              .isModelReady) {
        _errorMessage = _t(
          en: 'Outfit recognition models are not ready.',
          zh: '穿搭识别模型尚未就绪。',
          ms: 'Model pengecaman pakaian belum sedia.',
        );

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
        _errorMessage = _t(
          en: 'Please take or upload an outfit photo first.',
          zh: '请先拍摄或上传一张穿搭照片。',
          ms: 'Sila ambil atau muat naik foto pakaian dahulu.',
        );

        notifyListeners();
        return;
      }

      if (!_outfitRepository.areOutfitModelsReady) {
        _errorMessage = _t(
          en: 'Outfit recognition models are not ready.',
          zh: '穿搭识别模型尚未就绪。',
          ms: 'Model pengecaman pakaian belum sedia.',
        );

        notifyListeners();
        return;
      }

      if (!hasSelectedGender) {
        _errorMessage = _t(
          en: 'Please select your gender before analysing your outfit.',
          zh: '请先选择性别再分析您的穿搭。',
          ms: 'Sila pilih jantina anda sebelum menganalisis pakaian anda.',
        );

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
        _placeRecommendationMessage = _t(
          en: 'Analyse a clear full-body outfit photo first.',
          zh: '请先分析一张清晰的全身穿搭照片。',
          ms: 'Analisis foto pakaian sepenuh badan yang jelas dahulu.',
        );

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
          final radiusText =
          recommendationRadiusKm.toStringAsFixed(0);

          _placeRecommendationMessage =
          nearbyResult.usingDefaultArea
              ? _t(
            en: 'No supported cultural attractions were found '
                'within $radiusText km of the default Kuala '
                'Lumpur pilot area.',
            zh: '在默认的吉隆坡试点区域 $radiusText 公里范围内，'
                '未找到受支持的文化景点。',
            ms: 'Tiada tarikan budaya yang disokong ditemui dalam '
                'jarak $radiusText km dari kawasan perintis Kuala '
                'Lumpur lalai.',
          )
              : _t(
            en: 'No supported cultural attractions were found '
                'within $radiusText km of your current location.',
            zh: '在您当前位置 $radiusText 公里范围内，'
                '未找到受支持的文化景点。',
            ms: 'Tiada tarikan budaya yang disokong ditemui dalam '
                'jarak $radiusText km dari lokasi semasa anda.',
          );

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
          _placeRecommendationMessage = _t(
            en: 'No nearby cultural attraction matched '
                'your current outfit requirements.',
            zh: '附近没有符合您当前穿搭要求的文化景点。',
            ms: 'Tiada tarikan budaya berdekatan yang sepadan '
                'dengan keperluan pakaian anda semasa ini.',
          );
        } else {
          final count =
              _placeRecommendations
                  .length;

          _placeRecommendationMessage = _t(
            en: '$count nearby '
                '${count == 1 ? 'place matches' : 'places match'} '
                'your current outfit.',
            zh: '附近有 $count 个地点符合您的穿搭。',
            ms: '$count tempat berdekatan sepadan dengan pakaian anda.',
          );
        }
      } catch (e, stackTrace) {
      debugPrint(
      'PLACE RECOMMENDATION ERROR: $e',
      );

      debugPrint(
      '$stackTrace',
      );

      _placeRecommendations = [];

      _placeRecommendationMessage = _t(
        en: 'Unable to load nearby place recommendations right now.',
        zh: '目前无法加载附近的地点推荐。',
        ms: 'Tidak dapat memuatkan cadangan tempat berdekatan buat masa ini.',
      );
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
        _errorMessage = _t(
          en: 'Please take or upload an outfit photo first.',
          zh: '请先拍摄或上传一张穿搭照片。',
          ms: 'Sila ambil atau muat naik foto pakaian dahulu.',
        );

        notifyListeners();

        return false;
      }

      if (!_outfitRepository
          .isHumanDetectionModelReady ||
          !_outfitRepository
              .isModelReady) {
        _errorMessage = _t(
          en: 'Outfit recognition models are not ready.',
          zh: '穿搭识别模型尚未就绪。',
          ms: 'Model pengecaman pakaian belum sedia.',
        );

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
        _errorMessage = _t(
          en: 'A valid person photo is required before '
              'evaluating outfit etiquette.',
          zh: '在评估穿搭礼仪之前，需要一张有效的人物照片。',
          ms: 'Foto seseorang yang sah diperlukan sebelum '
              'menilai etika pakaian.',
        );

        notifyListeners();

        return;
      }

      if (!hasValidFullBody) {
        _errorMessage =
            _fullBodyValidationResult
                ?.message ??
                _t(
                  en: 'A clear full-body photo is required before '
                      'evaluating outfit etiquette.',
                  zh: '在评估穿搭礼仪之前，需要一张清晰的全身照片。',
                  ms: 'Foto sepenuh badan yang jelas diperlukan '
                      'sebelum menilai etika pakaian.',
                );

        notifyListeners();

        return;
      }

      if (_detectedAttributes.isEmpty) {
        _errorMessage = _t(
          en: 'No confident outfit attributes were detected.',
          zh: '未能可靠地检测到任何穿搭特征。',
          ms: 'Tiada ciri pakaian yang dikesan dengan yakin.',
        );

        notifyListeners();

        return;
      }

      if (_selectedAttractionId == null) {
        _errorMessage = _t(
          en: 'Please select a destination first.',
          zh: '请先选择目的地。',
          ms: 'Sila pilih destinasi dahulu.',
        );

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

      _errorMessage = _t(
        en: 'Please provide consent before using outfit recognition.',
        zh: '请先同意使用条款，才能使用穿搭识别功能。',
        ms: 'Sila berikan persetujuan sebelum menggunakan '
            'pengecaman pakaian.',
      );

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