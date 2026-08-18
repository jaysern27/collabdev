import '../../../../external_data_sources/ml_kit_tensorflow_lite/ml_kit_tensorflow_lite_data_source.dart';

class OutfitRecognitionService {
  final MlKitTensorflowLiteDataSource _dataSource;

  OutfitRecognitionService({
    MlKitTensorflowLiteDataSource? dataSource,
  }) : _dataSource =
      dataSource ?? MlKitTensorflowLiteDataSource();

  bool get isReady => _dataSource.isModelLoaded;

  Future<void> initialize({
    required String modelAssetPath,
  }) async {
    await _dataSource.loadModel(
      assetPath: modelAssetPath,
    );
  }

  void analyse({
    required Object input,
    required Object output,
  }) {
    if (!isReady) {
      throw Exception(
        'Outfit recognition model is not ready.',
      );
    }

    _dataSource.runInference(
      input: input,
      output: output,
    );
  }

  List<int> getInputShape() {
    return _dataSource.getInputShape();
  }

  List<int> getOutputShape() {
    return _dataSource.getOutputShape();
  }

  void dispose() {
    _dataSource.close();
  }
}