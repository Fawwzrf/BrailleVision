// lib/features/scanner/pipeline/braille_pipeline.dart
//
// ============================================================
// INTEGRATION ENGINEER — pipeline orchestrator.
// One place that runs the full per-frame DIP + ML + voting chain
// described in the PRD §6:
//
//   CameraImage
//     → YUV/Y-plane → upright grayscale          (YuvConverter)
//     → center-crop ROI + scale to work height   (GrayImage)
//     → binarize (adaptive threshold + morph)     (BraillePreprocessor)
//     → projection-profile cell boxes             (BrailleSegmenter)
//     → classify each cell (TFLite, grayscale)    (BrailleClassifier)
//     → assemble letters → temporal voting         (TemporalVoter)
//     → stable text + DetectionState
//
// Owned by ScannerNotifier; runs on demand for the frames that
// survive CameraService's frame-skipping.
// ============================================================

import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import '../../../core/constants/app_constants.dart';
import '../services/camera_service.dart' show DetectionState;
import 'braille_classifier.dart';
import 'braille_grid_decoder.dart';
import 'braille_preprocessor.dart';
import 'temporal_voter.dart';
import 'yuv_converter.dart';

class PipelineResult {
  const PipelineResult(this.text, this.state, this.confidence, [this.debug = '']);
  final String text;
  final DetectionState state;
  final double confidence; // mean per-cell confidence this frame
  final String debug; // human-readable per-frame diagnostics

  static const idle = PipelineResult('', DetectionState.idle, 0.0);
}

class BraillePipeline {
  final BrailleClassifier _classifier = BrailleClassifier();
  final TemporalVoter _voter = TemporalVoter(
    windowSize: AppConstants.votingWindowSize,
    minAgreement: AppConstants.votingMinAgreement,
  );
  int _rejectStreak = 0;

  bool get isReady => _classifier.isReady;

  Future<void> init() => _classifier.load();

  /// Clears the temporal buffer (e.g. on camera switch / resume).
  void reset() => _voter.reset();

  /// Runs the full chain on a single frame and returns the stable,
  /// vote-smoothed result.
  PipelineResult process(CameraImage frame, {int rotationQuarterTurns = 1}) {
    if (!_classifier.isReady) return PipelineResult.idle;

    // 1. Ingest → upright grayscale.
    final gray =
        YuvConverter.toGray(frame, rotationQuarterTurns: rotationQuarterTurns);

    // 2. ROI center-crop + scale to a fixed working height.
    final work = gray
        .cropCenter(AppConstants.roiWidthFactor, AppConstants.roiHeightFactor)
        .scaledToHeight(AppConstants.segmentWorkHeight);

    // 3. Binarize (DIP, polarity-aware) → dots = white.
    final binary = BraillePreprocessor.forSegmentation(work);

    // 4. Detect dots, reconstruct the grid, decode each cell (rule-based).
    final result = BrailleGridDecoder.decode(binary);
    final cells = result.cells;

    // 5. Rule-decoded letters (skip unknown patterns).
    final letters = <String>[];
    for (final cell in cells) {
      if (cell.letter.isNotEmpty) letters.add(cell.letter);
    }

    // 6. Validation gate — is this actually braille (not a random object
    //    or textured noise)? Only feed the voter when it passes.
    final isBraille = _looksLikeBraille(result, letters.length, cells.length);
    final votedInput = isBraille ? letters : const <String>[];

    // Clear stale text quickly once we're confident it's NOT braille.
    if (isBraille) {
      _rejectStreak = 0;
    } else if (++_rejectStreak >= AppConstants.gridRejectStreakToClear) {
      _voter.reset();
    }

    // 7. ML cross-check: render each cell clean and classify with TFLite.
    final mlCells = <String>[];
    if (AppConstants.debugOverlayEnabled && isBraille) {
      for (final cell in cells) {
        final clean = BrailleGridDecoder.renderCleanCell(cell.pattern);
        final pred = _classifier.classifyDirect(clean);
        mlCells.add('${pred.letter}${(pred.confidence * 100).round()}');
      }
    }

    // 8. Temporal voting → stable text.
    final stableText = _voter.add(votedInput);

    final DetectionState state;
    if (stableText.isNotEmpty) {
      state = DetectionState.detected;
    } else if (votedInput.isNotEmpty) {
      state = DetectionState.detecting;
    } else {
      state = DetectionState.idle;
    }

    var debug = '';
    if (AppConstants.debugOverlayEnabled) {
      final ratio = result.diameter > 0 ? result.pitch / result.diameter : 0.0;
      debug = 'dots:${result.blobCount} d:${result.diameter.toStringAsFixed(1)} '
          'a:${result.pitch.toStringAsFixed(1)} '
          'a/d:${ratio.toStringAsFixed(1)} cells:${cells.length} '
          '${isBraille ? "OK" : "REJECT"}\n'
          'rule:${letters.join()}\n'
          'ml:${mlCells.join(" ")}  →  "$stableText"';
      debugPrint('[BraillePipeline] $debug');
    }

    return PipelineResult(stableText, state, 1.0, debug);
  }

  /// Rejects non-braille structures: too few dots, irregular pitch, or a
  /// low fraction of cells decoding to real letters.
  bool _looksLikeBraille(GridDecodeResult r, int validCells, int totalCells) {
    if (r.blobCount < AppConstants.gridAcceptMinDots) return false;
    if (totalCells < AppConstants.gridAcceptMinCells) return false;
    if (r.diameter <= 0) return false;

    final ratio = r.pitch / r.diameter;
    if (ratio < AppConstants.gridPitchRatioMin ||
        ratio > AppConstants.gridPitchRatioMax) {
      return false;
    }
    final validFraction = totalCells > 0 ? validCells / totalCells : 0.0;
    return validFraction >= AppConstants.gridAcceptMinValidFraction;
  }

  void dispose() {
    _classifier.dispose();
    _voter.reset();
  }
}
