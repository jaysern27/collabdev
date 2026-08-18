import 'package:flutter/foundation.dart';

import '../../../data_layer/model/repositories/outfit/outfit_repository.dart';

class OutfitRecognitionViewModel extends ChangeNotifier {
  final OutfitRepository _outfitRepository;

  OutfitRecognitionViewModel({
    OutfitRepository? outfitRepository,
  }) : _outfitRepository =
      outfitRepository ?? OutfitRepository();

  bool _isLoading = false;
  bool _isModelReady = false;

  String? _result;
  String? _recommendation;
  String? _errorMessage;

  bool get isLoading => _isLoading;

  bool get isModelReady => _isModelReady;

  String? get result => _result;

  String? get recommendation => _recommendation;

  String? get errorMessage => _errorMessage;

  // Load TensorFlow Lite model
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
      _errorMessage = e.toString();
      _isModelReady = false;
    } finally {
      _setLoading(false);
    }
  }

  // Run outfit recognition
  Future<void> analyseOutfit({
    required Object input,
    required Object output,
  }) async {
    if (!_outfitRepository.isModelReady) {
      _errorMessage =
      'Outfit recognition model is not ready.';

      notifyListeners();

      return;
    }

    _setLoading(true);

    try {
      _errorMessage = null;
      _result = null;
      _recommendation = null;

      _outfitRepository.analyseOutfit(
        input: input,
        output: output,
      );

      _result = 'Analysis completed.';
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // Set final suitability result
  void setSuitabilityResult(
      String status,
      ) {
    _result = status;

    notifyListeners();
  }

  // Set personalised recommendation
  void setRecommendation(
      String recommendation,
      ) {
    _recommendation = recommendation;

    notifyListeners();
  }

  // Reset previous analysis
  void resetAnalysis() {
    _result = null;
    _recommendation = null;
    _errorMessage = null;

    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;

    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;

    notifyListeners();
  }

  @override
  void dispose() {
    _outfitRepository.dispose();

    super.dispose();
  }
}