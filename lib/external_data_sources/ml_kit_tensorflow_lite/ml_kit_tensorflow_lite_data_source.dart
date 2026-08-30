import 'package:tflite_flutter/tflite_flutter.dart';

class MlKitTensorflowLiteDataSource {
  Interpreter? _interpreter;

  bool get isModelLoaded => _interpreter != null;

  Future<void> loadModel({
    required String assetPath,
  }) async {
    _interpreter = await Interpreter.fromAsset(
      assetPath,
    );
  }

  // Generic inference method
  void runInference({
    required Object input,
    required Object output,
  }) {
    final interpreter = _interpreter;

    if (interpreter == null) {
      throw Exception(
        'TensorFlow Lite model has not been loaded.',
      );
    }

    interpreter.run(
      input,
      output,
    );
  }

  // Used by sleeve coverage model
  List<double> runSingleOutputInference({
    required Object input,
    required int outputSize,
  }) {
    final interpreter = _interpreter;

    if (interpreter == null) {
      throw Exception(
        'TensorFlow Lite model has not been loaded.',
      );
    }

    final output = [
      List<double>.filled(
        outputSize,
        0.0,
      ),
    ];

    interpreter.run(
      input,
      output,
    );

    return output.first;
  }

  List<int> getInputShape() {
    final interpreter = _interpreter;

    if (interpreter == null) {
      throw Exception(
        'TensorFlow Lite model has not been loaded.',
      );
    }

    return interpreter
        .getInputTensor(0)
        .shape;
  }

  List<int> getOutputShape() {
    final interpreter = _interpreter;

    if (interpreter == null) {
      throw Exception(
        'TensorFlow Lite model has not been loaded.',
      );
    }

    return interpreter
        .getOutputTensor(0)
        .shape;
  }

  void close() {
    _interpreter?.close();
    _interpreter = null;
  }
}