import 'dart:async';
import 'dart:typed_data';

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
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
// HUMAN DETECTION PREDICTION
// ============================================================

class HumanDetectionPrediction {
  final String value;

  final double confidence;

  final double humanConfidence;

  final double noHumanConfidence;

  const HumanDetectionPrediction({
    required this.value,
    required this.confidence,
    required this.humanConfidence,
    required this.noHumanConfidence,
  });

  bool get isHuman =>
      value == 'human';

  bool passesThreshold({
    double minimumConfidence = 0.60,
  }) {
    return isHuman &&
        humanConfidence >= minimumConfidence;
  }
}

// ============================================================
// FULL-BODY / POSE VALIDATION RESULT
// ============================================================

class FullBodyValidationResult {
  final bool poseDetected;
  final bool fullBodyVisible;
  final bool armsVisible;
  final double bodyHeightRatio;
  final List<String> missingLandmarks;
  final String message;

  const FullBodyValidationResult({
    required this.poseDetected,
    required this.fullBodyVisible,
    required this.armsVisible,
    required this.bodyHeightRatio,
    required this.missingLandmarks,
    required this.message,
  });

  bool get isValid =>
      poseDetected &&
          fullBodyVisible &&
          armsVisible;
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

class ShoulderCoveragePrediction {
  final String value;
  final double confidence;

  const ShoulderCoveragePrediction({
    required this.value,
    required this.confidence,
  });

  bool get isConfident =>
      confidence >= 0.75;
}

class HeadwearPrediction {
  final String value;
  final double confidence;

  const HeadwearPrediction({
    required this.value,
    required this.confidence,
  });

  bool get isConfident =>
      confidence >= 0.75;
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
  final MlKitTensorflowLiteDataSource
  _humanDetectionDataSource;
  final PoseDetector _poseDetector;
  final MlKitTensorflowLiteDataSource _dataSource;
  final MlKitTensorflowLiteDataSource _lowerBodyDataSource;
  final MlKitTensorflowLiteDataSource _shoulderDataSource;
  final MlKitTensorflowLiteDataSource _headwearDataSource;

  final ImagePicker _imagePicker;

  OutfitRecognitionService({
    MlKitTensorflowLiteDataSource?
    humanDetectionDataSource,
    PoseDetector? poseDetector,
    MlKitTensorflowLiteDataSource? dataSource,
    MlKitTensorflowLiteDataSource? lowerBodyDataSource,
    MlKitTensorflowLiteDataSource? shoulderDataSource,
    MlKitTensorflowLiteDataSource? headwearDataSource,
    ImagePicker? imagePicker,
  })  : _humanDetectionDataSource =
      humanDetectionDataSource ??
          MlKitTensorflowLiteDataSource(),
        _poseDetector =
            poseDetector ??
                PoseDetector(
                  options: PoseDetectorOptions(
                    model: PoseDetectionModel.accurate,
                    mode: PoseDetectionMode.single,
                  ),
                ),
        _dataSource =
            dataSource ??
                MlKitTensorflowLiteDataSource(),
        _lowerBodyDataSource =
            lowerBodyDataSource ??
                MlKitTensorflowLiteDataSource(),
        _shoulderDataSource =
            shoulderDataSource ??
                MlKitTensorflowLiteDataSource(),
        _headwearDataSource =
            headwearDataSource ??
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
  bool get isShoulderModelReady =>
      _shoulderDataSource.isModelLoaded;
  bool get isHeadwearModelReady =>
      _headwearDataSource.isModelLoaded;
  bool get isHumanDetectionModelReady =>
      _humanDetectionDataSource.isModelLoaded;

  // ==========================================================
  // MODEL INITIALIZATION
  // ==========================================================
  Future<void> initializeHumanDetectionModel({
    required String modelAssetPath,
  }) async {
    await _humanDetectionDataSource.loadModel(
      assetPath: modelAssetPath,
    );
  }

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

  Future<void> initializeShoulderModel({
    required String modelAssetPath,
  }) async {
    await _shoulderDataSource.loadModel(
      assetPath: modelAssetPath,
    );
  }

  Future<void> initializeHeadwearModel({
    required String modelAssetPath,
  }) async {
    await _headwearDataSource.loadModel(
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
// FULL-BODY / POSE VALIDATION
// ==========================================================

  Future<FullBodyValidationResult>
  validateFullBodyVisibility(
      OutfitImageData outfitImage, {
        double minimumLandmarkLikelihood = 0.55,
        double minimumBodyHeightRatio = 0.55,
      }) async {
    if (minimumLandmarkLikelihood < 0 ||
        minimumLandmarkLikelihood > 1) {
      throw ArgumentError(
        'minimumLandmarkLikelihood must be between 0 and 1.',
      );
    }

    if (minimumBodyHeightRatio < 0 ||
        minimumBodyHeightRatio > 1) {
      throw ArgumentError(
        'minimumBodyHeightRatio must be between 0 and 1.',
      );
    }

    if (outfitImage.path.trim().isEmpty) {
      return const FullBodyValidationResult(
        poseDetected: false,
        fullBodyVisible: false,
        armsVisible: false,
        bodyHeightRatio: 0,
        missingLandmarks: [],
        message:
        'Unable to validate body visibility for this image.',
      );
    }

    final decodedImage =
    img.decodeImage(
      outfitImage.bytes,
    );

    if (decodedImage == null) {
      return const FullBodyValidationResult(
        poseDetected: false,
        fullBodyVisible: false,
        armsVisible: false,
        bodyHeightRatio: 0,
        missingLandmarks: [],
        message:
        'Unable to read the selected image for full-body validation.',
      );
    }

    final orientedImage =
    img.bakeOrientation(
      decodedImage,
    );

    final imageWidth =
    orientedImage.width.toDouble();

    final imageHeight =
    orientedImage.height.toDouble();

    final inputImage =
    InputImage.fromFilePath(
      outfitImage.path,
    );

    final poses =
    await _poseDetector.processImage(
      inputImage,
    );

    if (poses.isEmpty) {
      return const FullBodyValidationResult(
        poseDetected: false,
        fullBodyVisible: false,
        armsVisible: false,
        bodyHeightRatio: 0,
        missingLandmarks: [],
        message:
        'A person was detected, but body landmarks could not be identified. '
            'Please use a clear full-body photo.',
      );
    }

    final pose =
    _selectBestPose(
      poses,
    );

    bool visible(
        PoseLandmarkType type,
        ) {
      final landmark =
      pose.landmarks[type];

      if (landmark == null) {
        return false;
      }

      if (landmark.likelihood <
          minimumLandmarkLikelihood) {
        return false;
      }

      if (landmark.x < 0 ||
          landmark.x > imageWidth ||
          landmark.y < 0 ||
          landmark.y > imageHeight) {
        return false;
      }

      return true;
    }

    final missing =
    <String>[];

    // ========================================================
    // HEAD
    // ========================================================

    final headVisible =
        visible(
          PoseLandmarkType.nose,
        ) ||
            visible(
              PoseLandmarkType.leftEye,
            ) ||
            visible(
              PoseLandmarkType.rightEye,
            ) ||
            visible(
              PoseLandmarkType.leftEar,
            ) ||
            visible(
              PoseLandmarkType.rightEar,
            );

    if (!headVisible) {
      missing.add(
        'head',
      );
    }

    // ========================================================
    // CORE FULL-BODY LANDMARKS
    // ========================================================

    final requiredBodyLandmarks =
    <PoseLandmarkType, String>{
      PoseLandmarkType.leftShoulder:
      'left shoulder',
      PoseLandmarkType.rightShoulder:
      'right shoulder',

      PoseLandmarkType.leftHip:
      'left hip',
      PoseLandmarkType.rightHip:
      'right hip',

      PoseLandmarkType.leftKnee:
      'left knee',
      PoseLandmarkType.rightKnee:
      'right knee',

      PoseLandmarkType.leftAnkle:
      'left ankle',
      PoseLandmarkType.rightAnkle:
      'right ankle',
    };

    for (final entry
    in requiredBodyLandmarks.entries) {
      if (!visible(
        entry.key,
      )) {
        missing.add(
          entry.value,
        );
      }
    }

    // ========================================================
    // ARM LANDMARKS
    //
    // We require these because sleeve analysis cannot be
    // trusted if the arms are hidden/cropped.
    // ========================================================

    final requiredArmLandmarks =
    <PoseLandmarkType, String>{
      PoseLandmarkType.leftElbow:
      'left elbow',
      PoseLandmarkType.rightElbow:
      'right elbow',

      PoseLandmarkType.leftWrist:
      'left wrist',
      PoseLandmarkType.rightWrist:
      'right wrist',
    };

    final missingArms =
    <String>[];

    for (final entry
    in requiredArmLandmarks.entries) {
      if (!visible(
        entry.key,
      )) {
        missingArms.add(
          entry.value,
        );
      }
    }

    // ========================================================
    // CHECK HOW MUCH OF THE IMAGE THE PERSON OCCUPIES
    // ========================================================

    final headLandmarks =
    <PoseLandmarkType>[
      PoseLandmarkType.nose,
      PoseLandmarkType.leftEye,
      PoseLandmarkType.rightEye,
      PoseLandmarkType.leftEar,
      PoseLandmarkType.rightEar,
    ];

    final headYValues =
    <double>[];

    for (final type
    in headLandmarks) {
      if (visible(type)) {
        final landmark =
        pose.landmarks[type];

        if (landmark != null) {
          headYValues.add(
            landmark.y,
          );
        }
      }
    }

    final ankleYValues =
    <double>[];

    for (final type in [
      PoseLandmarkType.leftAnkle,
      PoseLandmarkType.rightAnkle,
    ]) {
      if (visible(type)) {
        final landmark =
        pose.landmarks[type];

        if (landmark != null) {
          ankleYValues.add(
            landmark.y,
          );
        }
      }
    }

    double bodyHeightRatio = 0;

    if (headYValues.isNotEmpty &&
        ankleYValues.isNotEmpty &&
        imageHeight > 0) {
      final topY =
      headYValues.reduce(
            (a, b) =>
        a < b ? a : b,
      );

      final bottomY =
      ankleYValues.reduce(
            (a, b) =>
        a > b ? a : b,
      );

      bodyHeightRatio =
          ((bottomY - topY).abs() /
              imageHeight)
              .clamp(
            0.0,
            1.0,
          )
              .toDouble();
    }

    final bodyLargeEnough =
        bodyHeightRatio >=
            minimumBodyHeightRatio;

    final fullBodyVisible =
        headVisible &&
            missing.isEmpty &&
            bodyLargeEnough;

    final armsVisible =
        missingArms.isEmpty;

    final allMissing =
    <String>[
      ...missing,
      ...missingArms,
    ];

    // ========================================================
    // FULL BODY FAILED
    // ========================================================

    if (!fullBodyVisible) {
      if (!bodyLargeEnough &&
          missing.isEmpty) {
        return FullBodyValidationResult(
          poseDetected: true,
          fullBodyVisible: false,
          armsVisible: armsVisible,
          bodyHeightRatio:
          bodyHeightRatio,
          missingLandmarks:
          allMissing,
          message:
          'Your full body is visible, but you are too small in the frame. '
              'Move closer while keeping your head, shoulders, hips, knees '
              'and ankles visible.',
        );
      }

      return FullBodyValidationResult(
        poseDetected: true,
        fullBodyVisible: false,
        armsVisible: armsVisible,
        bodyHeightRatio:
        bodyHeightRatio,
        missingLandmarks:
        allMissing,
        message:
        'Full body not visible. Please make sure your head, shoulders, '
            'hips, knees and ankles are inside the photo.',
      );
    }

    // ========================================================
    // ARMS FAILED
    // ========================================================

    if (!armsVisible) {
      return FullBodyValidationResult(
        poseDetected: true,
        fullBodyVisible: true,
        armsVisible: false,
        bodyHeightRatio:
        bodyHeightRatio,
        missingLandmarks:
        allMissing,
        message:
        'Your full body is visible, but your arms are not clear enough. '
            'Please keep both elbows and wrists visible for sleeve analysis.',
      );
    }

    return FullBodyValidationResult(
      poseDetected: true,
      fullBodyVisible: true,
      armsVisible: true,
      bodyHeightRatio:
      bodyHeightRatio,
      missingLandmarks: const [],
      message:
      'Full body and arms are clearly visible.',
    );
  }

  Pose _selectBestPose(
      List<Pose> poses,
      ) {
    if (poses.length == 1) {
      return poses.first;
    }

    const scoringLandmarks =
    <PoseLandmarkType>[
      PoseLandmarkType.nose,

      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,

      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,

      PoseLandmarkType.leftKnee,
      PoseLandmarkType.rightKnee,

      PoseLandmarkType.leftAnkle,
      PoseLandmarkType.rightAnkle,

      PoseLandmarkType.leftElbow,
      PoseLandmarkType.rightElbow,

      PoseLandmarkType.leftWrist,
      PoseLandmarkType.rightWrist,
    ];

    double score(
        Pose pose,
        ) {
      double total = 0;

      for (final type
      in scoringLandmarks) {
        total +=
            pose.landmarks[type]
                ?.likelihood ??
                0;
      }

      return total;
    }

    Pose bestPose =
        poses.first;

    double bestScore =
    score(
      bestPose,
    );

    for (final pose
    in poses.skip(1)) {
      final currentScore =
      score(
        pose,
      );

      if (currentScore >
          bestScore) {
        bestPose = pose;
        bestScore = currentScore;
      }
    }

    return bestPose;
  }

  // ==========================================================
  // IMAGE PREPROCESSING
  // ==========================================================
  PreparedOutfitInput
  prepareHumanDetectionImageForModel(
      OutfitImageData outfitImage,
      ) {
    if (!_humanDetectionDataSource.isModelLoaded) {
      throw Exception(
        'Human detection model is not loaded.',
      );
    }

    final inputShape =
    _humanDetectionDataSource.getInputShape();

    if (inputShape.length != 4 ||
        inputShape[0] != 1 ||
        inputShape[3] != 3) {
      throw Exception(
        'Unexpected human detection model '
            'input shape: $inputShape',
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
        'Unable to decode image for '
            'human detection.',
      );
    }

    final resizedImage =
    img.copyResize(
      decodedImage,
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
                pixel.r.toDouble()/255.0,
                pixel.g.toDouble()/255.0,
                pixel.b.toDouble()/255.0,
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
                pixel.r.toDouble(),
                pixel.g.toDouble(),
                pixel.b.toDouble(),
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

  PreparedOutfitInput prepareHeadwearImageForModel(
      OutfitImageData outfitImage,
      ) {
    if (!_headwearDataSource.isModelLoaded) {
      throw Exception(
        'Headwear detection model is not loaded.',
      );
    }

    final inputShape =
    _headwearDataSource.getInputShape();

    if (inputShape.length != 4 ||
        inputShape[0] != 1 ||
        inputShape[3] != 3) {
      throw Exception(
        'Unexpected headwear model input shape: $inputShape',
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

    // Same strategy used during training:
    // keep the upper 60% of the image.
    final cropHeight =
    (decodedImage.height * 0.60).round();

    final headwearCrop =
    img.copyCrop(
      decodedImage,
      x: 0,
      y: 0,
      width: decodedImage.width,
      height: cropHeight,
    );

    final resizedImage =
    img.copyResize(
      headwearCrop,
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
  HumanDetectionPrediction
  predictHumanPresence({
    required PreparedOutfitInput
    preparedInput,
  }) {
    if (!_humanDetectionDataSource.isModelLoaded) {
      throw Exception(
        'Human detection model is not loaded.',
      );
    }

    final output =
    _humanDetectionDataSource
        .runSingleOutputInference(
      input: preparedInput.input,
      outputSize: 2,
    );

    if (output.length != 2) {
      throw Exception(
        'Unexpected human detection '
            'model output: $output',
      );
    }

    // Must exactly match Colab:
    //
    // 0 -> human
    // 1 -> no_human

    final humanConfidence =
    output[0];

    final noHumanConfidence =
    output[1];

    if (humanConfidence >=
        noHumanConfidence) {
      return HumanDetectionPrediction(
        value: 'human',
        confidence: humanConfidence,
        humanConfidence:
        humanConfidence,
        noHumanConfidence:
        noHumanConfidence,
      );
    }

    return HumanDetectionPrediction(
      value: 'no_human',
      confidence: noHumanConfidence,
      humanConfidence:
      humanConfidence,
      noHumanConfidence:
      noHumanConfidence,
    );
  }

  SleeveCoveragePrediction predictSleeveCoverage({
    required PreparedOutfitInput preparedInput,
  }) {
    if (!isReady) {
      throw Exception(
        'Sleeve recognition model is not ready.',
      );
    }

    final outputShape =
    _dataSource.getOutputShape();

    if (outputShape.isEmpty) {
      throw Exception(
        'Unable to determine sleeve model output shape.',
      );
    }

    final outputSize =
        outputShape.last;

    if (outputSize != 3) {
      throw Exception(
        'Expected sleeve model output size 3 '
            '[long, short, sleeveless], '
            'but received shape $outputShape.',
      );
    }

    final output =
    _dataSource.runSingleOutputInference(
      input: preparedInput.input,
      outputSize: outputSize,
    );

    if (output.length != 3) {
      throw Exception(
        'Unexpected sleeve model output: $output',
      );
    }

    // ==========================================================
    // NEW SLEEVE MODEL
    //
    // Must exactly match Colab:
    //
    // 0 -> long
    // 1 -> short
    // 2 -> sleeveless
    // ==========================================================

    const labels = [
      'long',
      'short',
      'sleeveless',
    ];

    int bestIndex = 0;
    double bestConfidence =
    output[0];

    for (int i = 1;
    i < output.length;
    i++) {
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

  PreparedOutfitInput prepareShoulderImageForModel(
      OutfitImageData outfitImage,
      ) {
    if (!_shoulderDataSource.isModelLoaded) {
      throw Exception(
        'Shoulder recognition model is not loaded.',
      );
    }

    final inputShape =
    _shoulderDataSource.getInputShape();

    if (inputShape.length != 4 ||
        inputShape[0] != 1 ||
        inputShape[3] != 3) {
      throw Exception(
        'Unexpected shoulder model input shape: $inputShape',
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

    // Shoulder model needs the upper-body region.
    // Keep roughly the top 60% of the photo.
    final cropHeight =
    (decodedImage.height * 0.60).round();

    final shoulderCrop =
    img.copyCrop(
      decodedImage,
      x: 0,
      y: 0,
      width: decodedImage.width,
      height: cropHeight,
    );

    final resizedImage =
    img.copyResize(
      shoulderCrop,
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

    if (output.length != 3) {
      throw Exception(
        'Unexpected lower-body model output: $output',
      );
    }

    const labels = [
      'short',
      'medium',
      'long',
    ];

    int bestIndex = 0;
    double bestConfidence = output[0];

    for (
    int i = 1;
    i < output.length;
    i++
    ) {
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

  ShoulderCoveragePrediction
  predictShoulderCoverage({
    required PreparedOutfitInput preparedInput,
  }) {
    final output =
    _shoulderDataSource
        .runSingleOutputInference(
      input: preparedInput.input,
      outputSize: 2,
    );

    if (output.length != 2) {
      throw Exception(
        'Unexpected shoulder model output: $output',
      );
    }

    // Must match Colab:
    // 0 -> covered
    // 1 -> uncovered
    const labels = [
      'covered',
      'uncovered',
    ];

    int bestIndex = 0;
    double bestConfidence = output[0];

    for (int i = 1; i < output.length; i++) {
      if (output[i] > bestConfidence) {
        bestConfidence = output[i];
        bestIndex = i;
      }
    }

    return ShoulderCoveragePrediction(
      value: labels[bestIndex],
      confidence: bestConfidence,
    );
  }

  HeadwearPrediction predictHeadwear({
    required PreparedOutfitInput preparedInput,
  }) {
    final output =
    _headwearDataSource
        .runSingleOutputInference(
      input: preparedInput.input,
      outputSize: 2,
    );

    if (output.length != 2) {
      throw Exception(
        'Unexpected headwear model output: $output',
      );
    }

    // Must match Colab:
    // 0 -> headwear
    // 1 -> no_headwear
    const labels = [
      'headwear',
      'no_headwear',
    ];

    int bestIndex = 0;
    double bestConfidence = output[0];

    for (int i = 1; i < output.length; i++) {
      if (output[i] > bestConfidence) {
        bestConfidence = output[i];
        bestIndex = i;
      }
    }

    return HeadwearPrediction(
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
  List<int> getHumanDetectionInputShape() {
    return _humanDetectionDataSource
        .getInputShape();
  }

  List<int> getHumanDetectionOutputShape() {
    return _humanDetectionDataSource
        .getOutputShape();
  }

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

  List<int> getShoulderInputShape() {
    return _shoulderDataSource
        .getInputShape();
  }

  List<int> getShoulderOutputShape() {
    return _shoulderDataSource
        .getOutputShape();
  }

  List<int> getHeadwearInputShape() {
    return _headwearDataSource
        .getInputShape();
  }

  List<int> getHeadwearOutputShape() {
    return _headwearDataSource
        .getOutputShape();
  }

  // ==========================================================
  // DISPOSE
  // ==========================================================
  void dispose() {
    _humanDetectionDataSource.close();

    unawaited(
      _poseDetector.close(),
    );

    _dataSource.close();
    _lowerBodyDataSource.close();
    _shoulderDataSource.close();
    _headwearDataSource.close();
  }
}