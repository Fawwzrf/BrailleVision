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
//     → dot detection + braille grid decode       (BrailleGridDecoder)
//     → classify each cell (TFLite, grayscale)    (BrailleClassifier)
//     → assemble letters → temporal voting         (TemporalVoter)
//     → output majority voting over string history (stability guard)
//     → stable text + DetectionState
//
// Owned by ScannerNotifier; runs on demand for the frames that
// survive CameraService's frame-skipping.
// ============================================================

import 'dart:collection';
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

  // ── Output Stability Guard (lapisan ketiga, di atas temporal voter) ──
  //
  // MASALAH dengan pendekatan "consecutive streak":
  //   Jika voter output berganti-ganti "HALO"/"HAL"/"HALO"/"HAL"...,
  //   streak counter terus reset → candidate tidak pernah dipromosikan.
  //
  // SOLUSI — Majority voting atas riwayat output:
  //   Simpan [pipelineOutputWindowSize] output voter terakhir.
  //   Tampilkan teks yang MENANG MAYORITAS (≥ pipelineOutputMinAgreement)
  //   dalam window itu, tanpa syarat berturut-turut.
  //   Contoh: "HALO" muncul 6 dari 8 frame → ditampilkan meski 2 frame
  //   noise muncul "HAL" atau "".
  String _lastDisplayedText = '';
  final Queue<String> _outputHistory = Queue<String>();

  bool get isReady => _classifier.isReady;

  Future<void> init() => _classifier.load();

  /// Clears all buffers (e.g. on camera switch / resume).
  void reset() {
    _voter.reset();
    _lastDisplayedText = '';
    _outputHistory.clear();
    _rejectStreak = 0;
  }

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

    // Clear stale text once we're confident it's NOT braille.
    if (isBraille) {
      _rejectStreak = 0;
    } else if (++_rejectStreak >= AppConstants.gridRejectStreakToClear) {
      // Cukup lama tidak ada braille → bersihkan semua buffer sekaligus.
      _voter.reset();
      _lastDisplayedText = '';
      _outputHistory.clear();
      _rejectStreak = 0; // reset agar tidak terus-menerus clear tiap frame
    }

    // 7. Temporal voting → voted text per posisi sel.
    final rawVoted = _voter.add(votedInput);

    // 8. Output majority-voting guard → stable displayed text.
    final stableText = _applyOutputGuard(rawVoted);

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
          'voted:"$rawVoted" hist:${_outputHistory.length}\n'
          'rule:$ruleDbg\n'
          'ml:${mlDbg.join(" ")}  →  "$stableText"';
      debugPrint('[BraillePipeline] $debug');
    }

    return PipelineResult(stableText, state, 1.0, debug);
  }

  // ── Output majority-voting guard ─────────────────────────────
  //
  // Simpan [pipelineOutputWindowSize] voted-string terakhir dalam queue.
  // String yang menang mayoritas (≥ pipelineOutputMinAgreement votes)
  // dipromosikan sebagai displayed text.
  //
  // TIDAK ada syarat "berturut-turut":
  //   "HALO" muncul 6×, "HAL" muncul 2× dari 8 frame terakhir
  //   → "HALO" menang (6 ≥ 5) → ditampilkan.
  //   Ini robust meski sesekali ada frame noise di antara frame benar.
  //
  // Displayed text TIDAK berubah selama tidak ada pemenang baru.
  // Sehingga teks lama tetap terlihat saat frame sesekali gagal.
  String _applyOutputGuard(String voted) {
    // Masukkan voted string ke history (string kosong juga dicatat).
    _outputHistory.addLast(voted);
    while (_outputHistory.length > AppConstants.pipelineOutputWindowSize) {
      _outputHistory.removeFirst();
    }

    // Hitung vote tiap string non-kosong.
    final counts = <String, int>{};
    for (final v in _outputHistory) {
      if (v.isNotEmpty) counts[v] = (counts[v] ?? 0) + 1;
    }
    if (counts.isEmpty) return _lastDisplayedText;

    // Cari pemenang (string dengan vote terbanyak).
    String? winner;
    int bestCount = 0;
    counts.forEach((text, count) {
      if (count > bestCount) {
        bestCount = count;
        winner = text;
      }
    });

    // Promosikan hanya jika pemenang melampaui threshold mayoritas.
    if (winner != null && bestCount >= AppConstants.pipelineOutputMinAgreement) {
      _lastDisplayedText = winner!;
    }

    return _lastDisplayedText;
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
