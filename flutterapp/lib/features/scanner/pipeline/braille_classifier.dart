// lib/features/scanner/pipeline/braille_classifier.dart
//
// ============================================================
// INTEGRATION ENGINEER — ML inference (TFLite).
// Wraps the Custom CNN exported by the ML Engineer
// (braille_vision_f16_synth.tflite). Classifies a single Braille
// cell crop into a letter A–Z with a confidence score.
//
// Input MUST match training (model_training.ipynb / load_and_preprocess):
//   grayscale → resize 64x64 → value/255.0 → replicate to 3 channels.
// Output: softmax over 26 classes.
// ============================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';
import '../../../core/constants/app_constants.dart';
import 'gray_image.dart';

class CellPrediction {
  const CellPrediction(this.letter, this.confidence);
  final String letter;
  final double confidence;

  static const empty = CellPrediction('', 0.0);
}

class BrailleClassifier {
  Interpreter? _interpreter;
  List<String> _labels = const [];

  bool get isReady => _interpreter != null;

  Future<void> load() async {
    if (_interpreter != null) return;
    _interpreter = await Interpreter.fromAsset(AppConstants.modelAssetPath);

    final raw = await rootBundle.loadString(AppConstants.labelMapAssetPath);
    final map = (json.decode(raw) as Map<String, dynamic>);
    final labels = List<String>.filled(map.length, '?');
    map.forEach((k, v) => labels[int.parse(k)] = (v as String).toUpperCase());
    _labels = labels;

    debugPrint('[BrailleClassifier] Model loaded — ${_labels.length} classes.');
  }

  /// Classifies one Braille cell. The crop is normalized to match the
  /// model's training distribution (dark dots on a light background,
  /// one cell centered with margins) before inference.
  CellPrediction classify(GrayImage cell) {
    final interp = _interpreter;
    if (interp == null) return CellPrediction.empty;

    const size = AppConstants.modelInputWidth; // 64 (square)

    // 1. Normalize polarity: training = DARK dots / LIGHT background.
    //    If this crop's background is dark (mean < 127), invert it.
    final normalized = cell.mean < 127 ? cell.inverted() : cell;

    // 2. Frame like training: center on a light canvas with margins
    //    (no stretching), so the cell's proportions are preserved.
    final resized = normalized.framedSquare(
      size,
      AppConstants.classifierMarginFraction,
      255, // light background
    );

    return _run(resized);
  }

  /// Runs inference on an already-prepared 64×64 image (dark dots on a
  /// light background) without polarity/framing — used to classify the
  /// clean cell rendered from a decoded pattern (ML cross-check).
  CellPrediction classifyDirect(GrayImage image64) {
    if (_interpreter == null) return CellPrediction.empty;
    final img = image64.width == AppConstants.modelInputWidth &&
            image64.height == AppConstants.modelInputHeight
        ? image64
        : image64.resize(
            AppConstants.modelInputWidth, AppConstants.modelInputHeight);
    return _run(img);
  }

  CellPrediction _run(GrayImage img) {
    final interp = _interpreter!;
    const size = AppConstants.modelInputWidth;

    // Build input tensor [1, 64, 64, 3], normalized to [0,1].
    final input = List.generate(
      1,
      (_) => List.generate(
        size,
        (y) => List.generate(size, (x) {
          final v = img.at(x, y) / 255.0;
          return [v, v, v];
        }),
      ),
    );

    final output = List.generate(1, (_) => List<double>.filled(_labels.length, 0.0));
    interp.run(input, output);

    final scores = output[0];
    var bestIdx = 0;
    var bestScore = scores[0];
    for (int i = 1; i < scores.length; i++) {
      if (scores[i] > bestScore) {
        bestScore = scores[i];
        bestIdx = i;
      }
    }
    return CellPrediction(_labels[bestIdx], bestScore);
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}
