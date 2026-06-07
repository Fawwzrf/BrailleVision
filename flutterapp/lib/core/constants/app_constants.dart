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
  static const int modelInputWidth   = 224;
  static const int modelInputHeight  = 224;

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
