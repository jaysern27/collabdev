import '../../services/outfit_recognition/outfit_recognition_service.dart';

class OutfitRepository {
  final OutfitRecognitionService _outfitRecognitionService;

  OutfitRepository({
    OutfitRecognitionService? outfitRecognitionService,
  }) : _outfitRecognitionService =
      outfitRecognitionService ??
          OutfitRecognitionService();

  // =========================================================
  // MODEL STATUS
  // =========================================================

  bool get isModelReady =>
      _outfitRecognitionService.isReady;
  bool get isSleeveModelReady =>
      _outfitRecognitionService.isSleeveModelReady;
  bool get isLowerBodyModelReady =>
      _outfitRecognitionService.isLowerBodyModelReady;
  bool get isShoulderModelReady =>
      _outfitRecognitionService.isShoulderModelReady;
  bool get isHeadwearModelReady =>
      _outfitRecognitionService.isHeadwearModelReady;

  bool get areOutfitModelsReady =>
      isSleeveModelReady &&
          isLowerBodyModelReady &&
          isShoulderModelReady &&
          isHeadwearModelReady;
  // =========================================================
  // MODEL INITIALIZATION
  // =========================================================

  Future<void> initializeModel({
    required String modelAssetPath,
  }) async {
    await _outfitRecognitionService.initialize(
      modelAssetPath: modelAssetPath,
    );
  }

  Future<void> initializeLowerBodyModel({
    required String modelAssetPath,
  }) async {
    await _outfitRecognitionService
        .initializeLowerBodyModel(
      modelAssetPath: modelAssetPath,
    );
  }

  Future<void> initializeShoulderModel({
    required String modelAssetPath,
  }) async {
    await _outfitRecognitionService
        .initializeShoulderModel(
      modelAssetPath: modelAssetPath,
    );
  }

  Future<void> initializeHeadwearModel({
    required String modelAssetPath,
  }) async {
    await _outfitRecognitionService
        .initializeHeadwearModel(
      modelAssetPath: modelAssetPath,
    );
  }

  // =========================================================
  // CAMERA
  // =========================================================

  Future<OutfitImageData?> capturePhoto({
    required bool consentGiven,
  }) async {
    return await _outfitRecognitionService
        .capturePhoto(
      consentGiven: consentGiven,
    );
  }

  // =========================================================
  // GALLERY
  // =========================================================

  Future<OutfitImageData?> selectPhoto({
    required bool consentGiven,
  }) async {
    return await _outfitRecognitionService
        .selectPhoto(
      consentGiven: consentGiven,
    );
  }

  // =========================================================
  // RECOVER LOST PHOTO
  // =========================================================

  Future<OutfitImageData?> recoverLostPhoto() async {
    return await _outfitRecognitionService
        .recoverLostPhoto();
  }

  // =========================================================
  // IMAGE PREPROCESSING
  // =========================================================

  PreparedOutfitInput prepareImageForModel(
      OutfitImageData outfitImage,
      ) {
    return _outfitRecognitionService
        .prepareImageForModel(
      outfitImage,
    );
  }

  PreparedOutfitInput prepareLowerBodyImageForModel(
      OutfitImageData outfitImage,
      ) {
    return _outfitRecognitionService
        .prepareLowerBodyImageForModel(
      outfitImage,
    );
  }

  PreparedOutfitInput prepareShoulderImageForModel(
      OutfitImageData outfitImage,
      ) {
    return _outfitRecognitionService
        .prepareShoulderImageForModel(
      outfitImage,
    );
  }

  PreparedOutfitInput prepareHeadwearImageForModel(
      OutfitImageData outfitImage,
      ) {
    return _outfitRecognitionService
        .prepareHeadwearImageForModel(
      outfitImage,
    );
  }

  // =========================================================
  // REAL SLEEVE COVERAGE PREDICTION
  // =========================================================

  SleeveCoveragePrediction predictSleeveCoverage({
    required PreparedOutfitInput preparedInput,
  }) {
    return _outfitRecognitionService
        .predictSleeveCoverage(
      preparedInput: preparedInput,
    );
  }

  LowerBodyCoveragePrediction
  predictLowerBodyCoverage({
    required PreparedOutfitInput preparedInput,
  }) {
    return _outfitRecognitionService
        .predictLowerBodyCoverage(
      preparedInput: preparedInput,
    );
  }

  ShoulderCoveragePrediction
  predictShoulderCoverage({
    required PreparedOutfitInput preparedInput,
  }) {
    return _outfitRecognitionService
        .predictShoulderCoverage(
      preparedInput: preparedInput,
    );
  }

  HeadwearPrediction predictHeadwear({
    required PreparedOutfitInput preparedInput,
  }) {
    return _outfitRecognitionService
        .predictHeadwear(
      preparedInput: preparedInput,
    );
  }

  // =========================================================
  // GENERIC AI INFERENCE
  // =========================================================

  void analyseOutfit({
    required Object input,
    required Object output,
  }) {
    if (!isModelReady) {
      throw Exception(
        'Outfit recognition model is not ready.',
      );
    }

    _outfitRecognitionService.analyse(
      input: input,
      output: output,
    );
  }

  // =========================================================
  // DRESS-CODE COMPARISON
  // =========================================================

  OutfitAdvisoryResult compareWithDressCode({
    required Map<String, OutfitAttributePrediction>
    detectedAttributes,
    required List<Map<String, dynamic>>
    dressCodeRules,
    required double minimumConfidence,
  }) {
    return _outfitRecognitionService
        .compareWithDressCode(
      detectedAttributes: detectedAttributes,
      dressCodeRules: dressCodeRules,
      minimumConfidence: minimumConfidence,
    );
  }

  // =========================================================
  // MODEL INFORMATION
  // =========================================================

  List<int> getInputShape() {
    return _outfitRecognitionService
        .getInputShape();
  }

  List<int> getOutputShape() {
    return _outfitRecognitionService
        .getOutputShape();
  }

  List<int> getLowerBodyInputShape() {
    return _outfitRecognitionService
        .getLowerBodyInputShape();
  }

  List<int> getLowerBodyOutputShape() {
    return _outfitRecognitionService
        .getLowerBodyOutputShape();
  }

  List<int> getShoulderInputShape() {
    return _outfitRecognitionService
        .getShoulderInputShape();
  }

  List<int> getShoulderOutputShape() {
    return _outfitRecognitionService
        .getShoulderOutputShape();
  }

  List<int> getHeadwearInputShape() {
    return _outfitRecognitionService
        .getHeadwearInputShape();
  }

  List<int> getHeadwearOutputShape() {
    return _outfitRecognitionService
        .getHeadwearOutputShape();
  }

  // =========================================================
  // CLEANUP
  // =========================================================

  void dispose() {
    _outfitRecognitionService.dispose();
  }
}