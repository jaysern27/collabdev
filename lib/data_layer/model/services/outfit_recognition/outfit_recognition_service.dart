import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../../../../external_data_sources/ml_kit_tensorflow_lite/ml_kit_tensorflow_lite_data_source.dart';


// ============================================================
// IMAGE DATA
// ============================================================

class OutfitImageData {
  final String name;
  final String path;
  final Uint8List bytes;

  const OutfitImageData({
    required this.name,
    required this.path,
    required this.bytes,
  });
}


// ============================================================
// PREPARED MODEL INPUT
// ============================================================

class PreparedOutfitInput {
  final Object input;
  final int width;
  final int height;

  const PreparedOutfitInput({
    required this.input,
    required this.width,
    required this.height,
  });
}


// ============================================================
// GENERIC ATTRIBUTE PREDICTION
// ============================================================

class OutfitAttributePrediction {
  final String attribute;
  final String value;
  final double confidence;

  const OutfitAttributePrediction({
    required this.attribute,
    required this.value,
    required this.confidence,
  });
}


// ============================================================
// SLEEVE COVERAGE PREDICTION
// ============================================================

class SleeveCoveragePrediction {
  final String value;
  final double confidence;

  const SleeveCoveragePrediction({
    required this.value,
    required this.confidence,
  });

  bool get isConfident =>
      confidence >= 0.75;
}

class LowerBodyCoveragePrediction {
  final String value;
  final double confidence;

  const LowerBodyCoveragePrediction({
    required this.value,
    required this.confidence,
  });

  bool get isConfident => confidence >= 0.75;
}


// ============================================================
// ADVISORY RESULT
// ============================================================

enum OutfitAdvisoryStatus {
  suitable,
  adjustmentRecommended,
  unableToDetermine,
}


class OutfitRuleCheck {
  final String attribute;
  final String ruleName;
  final List<String> acceptedValues;

  final String? detectedValue;
  final double? confidence;

  final bool? passed;

  final String message;

  const OutfitRuleCheck({
    required this.attribute,
    required this.ruleName,
    required this.acceptedValues,
    required this.detectedValue,
    required this.confidence,
    required this.passed,
    required this.message,
  });
}


class OutfitAdvisoryResult {
  final OutfitAdvisoryStatus status;

  final List<OutfitRuleCheck> checks;

  final String message;

  const OutfitAdvisoryResult({
    required this.status,
    required this.checks,
    required this.message,
  });

  String get displayStatus {
    switch (status) {
      case OutfitAdvisoryStatus.suitable:
        return 'Suitable';

      case OutfitAdvisoryStatus.adjustmentRecommended:
        return 'Adjustment Recommended';

      case OutfitAdvisoryStatus.unableToDetermine:
        return 'Unable to Determine';
    }
  }
}


// ============================================================
// OUTFIT RECOGNITION SERVICE
// ============================================================

class OutfitRecognitionService {
  final MlKitTensorflowLiteDataSource _dataSource;
  final MlKitTensorflowLiteDataSource _lowerBodyDataSource;

  final ImagePicker _imagePicker;

  OutfitRecognitionService({
    MlKitTensorflowLiteDataSource? dataSource,
    MlKitTensorflowLiteDataSource? lowerBodyDataSource,
    ImagePicker? imagePicker,
  })  : _dataSource =
      dataSource ??
          MlKitTensorflowLiteDataSource(),
        _lowerBodyDataSource =
            lowerBodyDataSource ??
                MlKitTensorflowLiteDataSource(),
        _imagePicker =
            imagePicker ??
                ImagePicker();

  bool get isReady =>
      _dataSource.isModelLoaded;
  bool get isSleeveModelReady =>
      _dataSource.isModelLoaded;

  bool get isLowerBodyModelReady =>
      _lowerBodyDataSource.isModelLoaded;

  // ==========================================================
  // MODEL INITIALIZATION
  // ==========================================================

  Future<void> initialize({
    required String modelAssetPath,
  }) async {
    await _dataSource.loadModel(
      assetPath: modelAssetPath,
    );
  }

  Future<void> initializeLowerBodyModel({
    required String modelAssetPath,
  }) async {
    await _lowerBodyDataSource.loadModel(
      assetPath: modelAssetPath,
    );
  }


  // ==========================================================
  // CAMERA
  // ==========================================================

  Future<OutfitImageData?> capturePhoto({
    required bool consentGiven,
  }) async {
    if (!consentGiven) {
      throw Exception(
        'Consent is required before analysing an outfit photo.',
      );
    }

    final image =
    await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
      maxWidth: 1600,
    );

    if (image == null) {
      return null;
    }

    return _convertImage(image);
  }


  // ==========================================================
  // GALLERY
  // ==========================================================

  Future<OutfitImageData?> selectPhoto({
    required bool consentGiven,
  }) async {
    if (!consentGiven) {
      throw Exception(
        'Consent is required before analysing an outfit photo.',
      );
    }

    final image =
    await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
      maxWidth: 1600,
    );

    if (image == null) {
      return null;
    }

    return _convertImage(image);
  }


  // ==========================================================
  // RECOVER LOST IMAGE
  // ==========================================================

  Future<OutfitImageData?>
  recoverLostPhoto() async {
    final response =
    await _imagePicker
        .retrieveLostData();

    if (response.isEmpty) {
      return null;
    }

    final files = response.files;

    if (files == null ||
        files.isEmpty) {
      return null;
    }

    return _convertImage(
      files.first,
    );
  }


  Future<OutfitImageData> _convertImage(
      XFile image,
      ) async {
    final bytes =
    await image.readAsBytes();

    return OutfitImageData(
      name: image.name,
      path: image.path,
      bytes: bytes,
    );
  }


  // ==========================================================
  // IMAGE PREPROCESSING
  // ==========================================================

  PreparedOutfitInput prepareImageForModel(
      OutfitImageData outfitImage,
      ) {
    if (!isReady) {
      throw Exception(
        'Outfit recognition model is not ready.',
      );
    }

    final inputShape =
    getInputShape();

    if (inputShape.length != 4) {
      throw Exception(
        'Unsupported model input shape: $inputShape',
      );
    }

    final batch =
    inputShape[0];

    final height =
    inputShape[1];

    final width =
    inputShape[2];

    final channels =
    inputShape[3];

    if (batch != 1 ||
        channels != 3) {
      throw Exception(
        'Expected model input shape '
            '[1, height, width, 3], '
            'but received $inputShape.',
      );
    }

    final decodedImage =
    img.decodeImage(
      outfitImage.bytes,
    );

    if (decodedImage == null) {
      throw Exception(
        'Unable to read the selected outfit image.',
      );
    }

    final resizedImage =
    img.copyResize(
      decodedImage,
      width: width,
      height: height,
    );

    /*
      Flutter sends pixels from 0.0 -> 1.0.

      Our trained sleeve model expects:
      [1, 224, 224, 3]
      Float32 RGB values between 0 and 1.
    */

    final input = [
      List.generate(
        height,
            (y) {
          return List.generate(
            width,
                (x) {
              final pixel =
              resizedImage.getPixel(
                x,
                y,
              );

              return [
                pixel.r.toDouble() /
                    255.0,

                pixel.g.toDouble() /
                    255.0,

                pixel.b.toDouble() /
                    255.0,
              ];
            },
          );
        },
      ),
    ];

    return PreparedOutfitInput(
      input: input,
      width: width,
      height: height,
    );
  }

  PreparedOutfitInput prepareLowerBodyImageForModel(
      OutfitImageData outfitImage,
      ) {
    if (!_lowerBodyDataSource.isModelLoaded) {
      throw Exception(
        'Lower-body recognition model is not loaded.',
      );
    }

    final inputShape =
    _lowerBodyDataSource.getInputShape();

    if (inputShape.length != 4 ||
        inputShape[0] != 1 ||
        inputShape[3] != 3) {
      throw Exception(
        'Unexpected lower-body model input shape: $inputShape',
      );
    }

    final height = inputShape[1];
    final width = inputShape[2];

    final decodedImage =
    img.decodeImage(
      outfitImage.bytes,
    );

    if (decodedImage == null) {
      throw Exception(
        'Unable to decode outfit image.',
      );
    }

    // Focus more on the lower-body region.
    //
    // We start around 30% down from the top so
    // the model still gets waist/body context.
    final cropY =
    (decodedImage.height * 0.30).round();

    final cropHeight =
        decodedImage.height - cropY;

    final lowerBodyCrop = img.copyCrop(
      decodedImage,
      x: 0,
      y: cropY,
      width: decodedImage.width,
      height: cropHeight,
    );

    final resizedImage =
    img.copyResize(
      lowerBodyCrop,
      width: width,
      height: height,
    );

    final input = [
      List.generate(
        height,
            (y) {
          return List.generate(
            width,
                (x) {
              final pixel =
              resizedImage.getPixel(
                x,
                y,
              );

              return [
                pixel.r / 255.0,
                pixel.g / 255.0,
                pixel.b / 255.0,
              ];
            },
          );
        },
      ),
    ];

    return PreparedOutfitInput(
      input: input,
      width: width,
      height: height,
    );
  }


  // ==========================================================
  // REAL SLEEVE COVERAGE AI
  // ==========================================================

  SleeveCoveragePrediction
  predictSleeveCoverage({
    required PreparedOutfitInput
    preparedInput,
  }) {
    if (!isReady) {
      throw Exception(
        'Outfit recognition model is not ready.',
      );
    }

    final output =
    _dataSource
        .runSingleOutputInference(
      input:
      preparedInput.input,
      outputSize: 3,
    );

    if (output.length != 3) {
      throw Exception(
        'Unexpected sleeve model output: '
            '$output',
      );
    }

    /*
      IMPORTANT:
      This order MUST match
      the Colab training output:

      0 -> covered
      1 -> partial
      2 -> uncovered
    */

    const labels = [
      'covered',
      'partial',
      'uncovered',
    ];

    int bestIndex = 0;

    double bestConfidence =
    output[0];

    for (
    int i = 1;
    i < output.length;
    i++
    ) {
      if (output[i] >
          bestConfidence) {
        bestConfidence =
        output[i];

        bestIndex = i;
      }
    }

    return SleeveCoveragePrediction(
      value:
      labels[bestIndex],
      confidence:
      bestConfidence,
    );
  }

  LowerBodyCoveragePrediction
  predictLowerBodyCoverage({
    required PreparedOutfitInput preparedInput,
  }) {
    final output =
    _lowerBodyDataSource
        .runSingleOutputInference(
      input: preparedInput.input,
      outputSize: 3,
    );

    const labels = [
      'short',
      'medium',
      'covered',
    ];

    int bestIndex = 0;
    double bestConfidence = output[0];

    for (int i = 1; i < output.length; i++) {
      if (output[i] > bestConfidence) {
        bestConfidence = output[i];
        bestIndex = i;
      }
    }

    return LowerBodyCoveragePrediction(
      value: labels[bestIndex],
      confidence: bestConfidence,
    );
  }


  // ==========================================================
  // GENERIC INFERENCE
  // ==========================================================

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


  // ==========================================================
  // DRESS CODE COMPARISON
  // ==========================================================

  OutfitAdvisoryResult
  compareWithDressCode({
    required Map<
        String,
        OutfitAttributePrediction>
    detectedAttributes,

    required List<
        Map<String, dynamic>>
    dressCodeRules,

    required double
    minimumConfidence,
  }) {
    if (minimumConfidence < 0 ||
        minimumConfidence > 1) {
      throw ArgumentError(
        'minimumConfidence must '
            'be between 0 and 1.',
      );
    }

    final checks =
    <OutfitRuleCheck>[];

    bool hasUncertainResult =
    false;

    bool hasFailedRule =
    false;


    for (
    final rule
    in dressCodeRules
    ) {
      if (rule['isActive'] ==
          false) {
        continue;
      }

      final attribute =
          rule['attribute']
              ?.toString()
              .trim() ??
              '';

      final ruleName =
          rule['title']
              ?.toString()
              .trim() ??
              'Dress Code Rule';

      final rawAcceptedValues =
      rule[
      'acceptedValues'];

      if (attribute.isEmpty ||
          rawAcceptedValues
          is! List) {
        continue;
      }

      final acceptedValues =
      rawAcceptedValues
          .map(
            (value) => value
            .toString()
            .trim()
            .toLowerCase(),
      )
          .where(
            (value) =>
        value.isNotEmpty,
      )
          .toList();

      if (acceptedValues
          .isEmpty) {
        continue;
      }

      final prediction =
      detectedAttributes[
      attribute];


      // ------------------------------------------------------
      // ATTRIBUTE NOT DETECTED
      // ------------------------------------------------------

      if (prediction == null) {
        hasUncertainResult =
        true;

        checks.add(
          OutfitRuleCheck(
            attribute:
            attribute,
            ruleName:
            ruleName,
            acceptedValues:
            acceptedValues,
            detectedValue:
            null,
            confidence:
            null,
            passed:
            null,
            message:
            'Unable to detect this clothing attribute.',
          ),
        );

        continue;
      }


      // ------------------------------------------------------
      // LOW CONFIDENCE
      // ------------------------------------------------------

      if (prediction
          .confidence <
          minimumConfidence) {
        hasUncertainResult =
        true;

        checks.add(
          OutfitRuleCheck(
            attribute:
            attribute,
            ruleName:
            ruleName,
            acceptedValues:
            acceptedValues,
            detectedValue:
            prediction.value,
            confidence:
            prediction
                .confidence,
            passed:
            null,
            message:
            'The image is not clear enough to determine this rule confidently.',
          ),
        );

        continue;
      }


      // ------------------------------------------------------
      // COMPARE RESULT
      // ------------------------------------------------------

      final detectedValue =
      prediction.value
          .trim()
          .toLowerCase();

      final passed =
      acceptedValues.contains(
        detectedValue,
      );

      if (!passed) {
        hasFailedRule =
        true;
      }

      checks.add(
        OutfitRuleCheck(
          attribute:
          attribute,
          ruleName:
          ruleName,
          acceptedValues:
          acceptedValues,
          detectedValue:
          prediction.value,
          confidence:
          prediction
              .confidence,
          passed:
          passed,
          message: passed
              ? 'This part of the outfit meets the dress-code requirement.'
              : 'This part of the outfit may need adjustment.',
        ),
      );
    }


    // --------------------------------------------------------
    // NO RULES
    // --------------------------------------------------------

    if (checks.isEmpty) {
      return const OutfitAdvisoryResult(
        status:
        OutfitAdvisoryStatus
            .unableToDetermine,
        checks: [],
        message:
        'No structured dress-code rules are available for this destination.',
      );
    }


    // --------------------------------------------------------
    // UNCERTAIN AI RESULT
    // --------------------------------------------------------

    if (hasUncertainResult) {
      return OutfitAdvisoryResult(
        status:
        OutfitAdvisoryStatus
            .unableToDetermine,
        checks:
        checks,
        message:
        'Some outfit attributes could not be identified confidently. Please check the destination rules manually.',
      );
    }


    // --------------------------------------------------------
    // FAILED RULE
    // --------------------------------------------------------

    if (hasFailedRule) {
      return OutfitAdvisoryResult(
        status:
        OutfitAdvisoryStatus
            .adjustmentRecommended,
        checks:
        checks,
        message:
        'Your outfit may need some adjustments before visiting this destination.',
      );
    }


    // --------------------------------------------------------
    // ALL PASSED
    // --------------------------------------------------------

    return OutfitAdvisoryResult(
      status:
      OutfitAdvisoryStatus
          .suitable,
      checks:
      checks,
      message:
      'Your outfit appears suitable for the selected destination.',
    );
  }


  // ==========================================================
  // MODEL INFORMATION
  // ==========================================================

  List<int> getInputShape() {
    return _dataSource
        .getInputShape();
  }

  List<int> getOutputShape() {
    return _dataSource
        .getOutputShape();
  }

  List<int> getLowerBodyInputShape() {
    return _lowerBodyDataSource
        .getInputShape();
  }

  List<int> getLowerBodyOutputShape() {
    return _lowerBodyDataSource
        .getOutputShape();
  }


  // ==========================================================
  // DISPOSE
  // ==========================================================

  void dispose() {
    _dataSource.close();
    _lowerBodyDataSource.close();
  }
}