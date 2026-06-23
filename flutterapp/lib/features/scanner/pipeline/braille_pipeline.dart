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

    // 5. Per cell: rule decode (deterministic) + ML on the REAL cell
    //    pixels (B2, PRD-faithful).
    //
    //    ARSITEKTUR (Fix v2): Rule table adalah PRIMARY translator.
    //    Alasan: model TFLite dilatih dari data sintetis bersih;
    //    pada crop kamera nyata model sering collapse ke kelas A (index 0)
    //    → output "AAA". Rule table deterministik jauh lebih andal.
    //    ML tetap dijalankan sebagai CROSS-CHECK dan fallback ketika
    //    rule table tidak bisa decode pola (cell.letter kosong).
    final ruleLetters = <String>[]; // valid rule letters → validation count
    final chosen = <String>[]; // final per-cell output (rule-primary)
    final ruleDbg = StringBuffer();
    final mlDbg = <String>[];
    for (final cell in cells) {
      if (cell.letter.isNotEmpty) ruleLetters.add(cell.letter);

      final crop = work.crop(cell.x0, cell.y0, cell.width, cell.height);
      final pred = _classifier.classify(crop);

      // Rule table DULU (deterministik, lebih andal di kondisi kamera nyata).
      // ML hanya dipakai bila rule tidak bisa decode (pola tidak dikenal).
      final String pick;
      if (cell.letter.isNotEmpty) {
        pick = cell.letter; // ✅ Rule table PRIMARY
      } else if (pred.confidence >= AppConstants.minCellConfidence) {
        pick = pred.letter; // ML fallback ketika pola tidak dikenal rule
      } else {
        pick = ''; // keduanya tidak cukup confident → skip
      }
      if (pick.isNotEmpty) chosen.add(pick);

      ruleDbg.write(cell.letter.isEmpty ? '·' : cell.letter);
      mlDbg.add('${pred.letter}${(pred.confidence * 100).round()}');
    }

    // 6. Validation gate — structural check via the rule decode. Only
    //    feed the voter when it actually looks like braille.
    final isBraille = _looksLikeBraille(result, ruleLetters.length, cells.length);
    final votedInput = isBraille ? chosen : const <String>[];

    // Clear stale text quickly once we're confident it's NOT braille.
    if (isBraille) {
      _rejectStreak = 0;
    } else if (++_rejectStreak >= AppConstants.gridRejectStreakToClear) {
      _voter.reset();
    }

    // 7. Temporal voting → stable text (ML-primary letters).
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
          'rule:$ruleDbg\n'
          'ml:${mlDbg.join(" ")}  →  "$stableText"';
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
