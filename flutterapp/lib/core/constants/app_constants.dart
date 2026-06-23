// lib/core/constants/app_constants.dart

class AppConstants {
  AppConstants._();

  // ─── App Info ──────────────────────────────────────────────
  static const String appName    = 'BrailleVision';
  static const String appVersion = '1.0.0';
  static const String appTagline = 'Real-time Braille Translation';

  // ─── Viewfinder Geometry ───────────────────────────────────
  static const double viewfinderWidthFactor  = 0.88;
  static const double viewfinderAspectRatio  = 1.35;
  static const double viewfinderCornerLength = 22.0;
  static const double viewfinderCornerStroke = 2.5;
  static const double cornerRadius           = 6.0;

  // ─── Viewfinder Animation ──────────────────────────────────
  static const int    viewfinderPulseDurationMs = 1400;
  static const int    scanLineDurationMs        = 2000;
  static const double pulseOpacityMin           = 0.3;
  static const double pulseOpacityMax           = 1.0;

  // ─── UI Sizing ─────────────────────────────────────────────
  static const double pagePaddingH  = 16.0;
  static const double pagePaddingV  = 12.0;
  static const double cardRadius    = 20.0;
  static const double buttonRadius  = 50.0; // pill shape
  static const double chipRadius    = 50.0; // pill badge
  static const double appBarIconSize = 18.0;
  static const double statusDotSize  = 7.0;

  // ─── Card shadow ───────────────────────────────────────────
  static const double cardElevation   = 0.0;
  static const double cardShadowBlur  = 24.0;
  static const double cardShadowSpread = -4.0;

  // ─── Braille Dot Grid (decorative) ────────────────────────
  static const int    brailleColumns    = 11;
  static const int    brailleRows       = 4;
  static const double brailleDotSize    = 7.0;
  static const double brailleDotSpacing = 20.0;

  // ─── Animation Durations ───────────────────────────────────
  static const Duration animFast   = Duration(milliseconds: 200);
  static const Duration animNormal = Duration(milliseconds: 350);
  static const Duration animSlow   = Duration(milliseconds: 500);

  // ─── Mock / Demo ───────────────────────────────────────────
  static const int    detectionSimulateDelayMs = 2000;
  static const String mockTranslationResult    =
      'Hello, world! This is a Braille translation.';

  // ─── Camera ────────────────────────────────────────────────
  static const int frameThrottleMs   = 150;

  // ─── ML Model (Integration Engineer) ───────────────────────
  // Custom CNN: input (1, 64, 64, 3) float32, output (1, 26) softmax A–Z.
  // "realistic" = Anggota 3's retrain with heavy realistic augmentation
  // (zoom −50%, rotation ±25°, brightness ±40%, noise). Same I/O spec.
  static const String modelAssetPath    = 'assets/models/braille_vision_realistic.tflite';
  static const String labelMapAssetPath = 'assets/models/label_map.json';
  static const int    modelInputWidth   = 64;
  static const int    modelInputHeight  = 64;
  // Per-cell confidence below this is treated as "no reliable letter".
  static const double minCellConfidence = 0.55;

  // ─── Frame Skipping (thermal/perf — PRD target ~6 FPS) ─────
  // Process 1 frame, then skip [frameSkipCount] frames. With a 30 FPS
  // camera, skip=4 → ~6 FPS effective inference rate.
  static const int frameSkipCount = 4;

  // ─── Region of Interest (center crop fed to the pipeline) ──
  // Fraction of the frame (centered) that is processed. Kept generous
  // so the braille is captured even when not perfectly centered; the
  // grid validator rejects whatever isn't actually braille.
  static const double roiWidthFactor  = 0.94;
  static const double roiHeightFactor = 0.80;
  // Working height (px) the ROI is scaled to before segmentation.
  // Higher = more pixels per dot for shape/size analysis.
  static const int    segmentWorkHeight = 180;

  // ─── DIP Preprocessing (port of CV Engineer notebook) ──────
  static const int    threshBlockSize   = 11; // odd
  static const int    threshC           = 2;
  static const int    morphKernelSize   = 2;

  // ─── Cell Segmentation (Projection Profile — legacy) ───────
  static const double segProjThreshold = 0.5; // min white px (normalized) per row/col
  static const int    segMinGap        = 3;   // consecutive empty lines that end a segment
  static const int    segMinCellWidth  = 6;   // discard slivers narrower than this (px)

  // ─── Grid Decoder (dot-blob detection → braille grid) ──────
  // Active method. Detects individual dots, reconstructs the braille
  // lattice, reads the 6-dot pattern per cell, decodes via the table.
  //
  // The grid unit `a` (dot pitch) is derived from the spacing between
  // braille ROW clusters (stable), NOT from nearest-neighbour distance.
  // Distances below are expressed as multiples of the median dot
  // diameter `d`, which is the most stable scale we can measure.
  static const int    gridMinDotArea       = 3;    // reject specks smaller than this (px)
  static const double gridMaxDotAreaFactor  = 8.0;  // reject blobs > N× median dot area
  static const double gridMinDotAreaFactor  = 0.25; // reject blobs < N× median (fragments)
  static const double gridCellGapFactor     = 1.25; // x-gap > a*this → new cell
  static const double gridLineGapDiamFactor = 3.0;  // y-gap > d*this → new text line
  static const double gridRowClusterDiamFactor = 0.9; // y-gap > d*this → new row cluster
  static const double gridRowPitchFallbackDiam = 1.7; // a ≈ d*this when only one row
  static const int    gridMinDots           = 2;    // need at least this many dots to decode

  // Blob shape filter — real dots are roughly round and uniform.
  static const double gridMaxAspect      = 2.0;     // reject elongated blobs (edges)
  static const double gridMinFillRatio   = 0.40;    // area / bbox-area (circle ≈ 0.79)
  static const double gridMinDotAreaFrac = 0.0005;  // min area as fraction of ROI area

  // ─── Grid Validation (is this actually braille?) ───────────
  // Reject random objects / textured noise so the app doesn't claim a
  // false "braille detected". All conditions must hold.
  static const int    gridAcceptMinDots         = 4;    // need ≥ this many valid dots
  static const int    gridAcceptMinCells        = 2;    // need ≥ this many cells
  static const double gridAcceptMinValidFraction = 0.6; // valid letters / total cells
  static const double gridPitchRatioMin         = 1.25; // a/d sane braille range…
  static const double gridPitchRatioMax         = 2.8;  // …(real braille ≈ 1.7)
  static const int    gridRejectStreakToClear   = 2;    // consecutive REJECTs → clear text

  // ─── Temporal Voting (stability — PRD: text stable in 2s window) ─
  static const int    votingWindowSize    = 5;   // last N predictions
  static const int    votingMinAgreement  = 2;   // min votes for winner to be emitted

  // ─── Auto Text-to-Speech ───────────────────────────────────
  // Speak a stable result automatically once it settles (PRD 5.3).
  static const bool   autoSpeakEnabled  = true;
  static const int    autoSpeakDebounceMs = 1200;

  // ─── Classifier Framing ────────────────────────────────────
  // The model was trained on DARK dots over a LIGHT background, one
  // braille cell centered with margins (see synthetic_data_generation).
  // We normalize live crops to that look before inference.
  static const double classifierMarginFraction = 0.16; // border around cell

  // ─── Debug ─────────────────────────────────────────────────
  // Shows an on-screen overlay (cell count, per-cell letter+confidence)
  // and prints the same to the console. Turn OFF for production/demo.
  static const bool debugOverlayEnabled = true;

  // ─── TTS ───────────────────────────────────────────────────
  static const double ttsDefaultRate    = 0.48;
  static const double ttsDefaultPitch   = 1.0;
  static const double ttsDefaultVolume  = 1.0;
  static const String ttsDefaultLanguage = 'id-ID';
  static const int    snackbarDurationMs = 2000;

  // ─── UI Strings ────────────────────────────────────────────
  static const String strAppName             = 'BRAILLEVISION';
  static const String strResultTitle         = 'TRANSLATION RESULT';
  static const String strSpeakBtn            = 'Read Aloud';
  static const String strStopBtn             = 'Stop';
  static const String strCopyBtn             = 'SALIN';
  static const String strCopied              = 'Teks disalin ke clipboard';
  static const String strPlaceholder         =
      'Translation result will appear here in real-time.';
  static const String strScanningLabel       = 'Scanning...';
  static const String strLiveLabel           = 'LIVE';
  static const String strLangBadge           = 'ID';
  static const String strPermissionTitle     = 'IZIN KAMERA\nDIPERLUKAN';
  static const String strPermissionDenied    = 'AKSES KAMERA\nDITOLAK';
  static const String strPermissionBody      =
      'BrailleVision memerlukan akses kamera untuk mendeteksi dan '
      'menerjemahkan huruf Braille secara real-time.';
  static const String strPermissionBodyDenied =
      'Buka Pengaturan perangkat dan aktifkan izin kamera untuk BrailleVision.';
  static const String strPermissionBtn        = 'IZINKAN KAMERA';
  static const String strPermissionSettingBtn = 'BUKA PENGATURAN';
  static const String strCameraError          = 'Gagal menginisialisasi kamera';
  static const String strStatusIdle           = 'ARAHKAN KE BRAILLE';
  static const String strStatusDetecting      = 'SCANNING...';
  static const String strStatusDetected       = 'BRAILLE TERDETEKSI';
}
