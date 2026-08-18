import '../../services/outfit_recognition/outfit_recognition_service.dart';

class OutfitRepository {
  final OutfitRecognitionService _outfitRecognitionService;

  OutfitRepository({
    OutfitRecognitionService? outfitRecognitionService,
  }) : _outfitRecognitionService =
      outfitRecognitionService ?? OutfitRecognitionService();

  bool get isModelReady =>
      _outfitRecognitionService.isReady;

  Future<void> initializeModel({
    required String modelAssetPath,
  }) async {
    await _outfitRecognitionService.initialize(
      modelAssetPath: modelAssetPath,
    );
  }

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

  List<int> getInputShape() {
    return _outfitRecognitionService.getInputShape();
  }

  List<int> getOutputShape() {
    return _outfitRecognitionService.getOutputShape();
  }

  void dispose() {
    _outfitRecognitionService.dispose();
  }
}