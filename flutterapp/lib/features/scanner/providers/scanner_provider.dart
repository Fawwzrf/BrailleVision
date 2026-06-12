// lib/features/scanner/providers/scanner_provider.dart
//
// ============================================================
// INTEGRATION ENGINEER NOTES:
// This is the central state of the scanner screen.
// Call [updateTranslation] from your frame processing callback
// to push new translation results into the UI.
// ============================================================

import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/constants/app_constants.dart';
import '../pipeline/braille_pipeline.dart';
import '../services/camera_service.dart';
import '../services/tts_service.dart';

// ─── State Model ─────────────────────────────────────────────

class ScannerState {
  const ScannerState({
    this.permissionStatus = PermissionStatus.denied,
    this.isCameraReady = false,
    this.isFlashOn = false,
    this.detectionState = DetectionState.idle,
    this.translatedText = '',
    this.ttsState = TtsState.idle,
    this.errorMessage,
    this.debugInfo = '',
  });

  final PermissionStatus permissionStatus;
  final bool isCameraReady;
  final bool isFlashOn;
  final DetectionState detectionState;
  final String translatedText;
  final TtsState ttsState;
  final String? errorMessage;
  final String debugInfo;

  bool get hasResult => translatedText.isNotEmpty;
  bool get isPermissionGranted => permissionStatus == PermissionStatus.granted;

  ScannerState copyWith({
    PermissionStatus? permissionStatus,
    bool? isCameraReady,
    bool? isFlashOn,
    DetectionState? detectionState,
    String? translatedText,
    TtsState? ttsState,
    String? errorMessage,
    bool clearError = false,
    String? debugInfo,
  }) {
    return ScannerState(
      permissionStatus: permissionStatus ?? this.permissionStatus,
      isCameraReady: isCameraReady ?? this.isCameraReady,
      isFlashOn: isFlashOn ?? this.isFlashOn,
      detectionState: detectionState ?? this.detectionState,
      translatedText: translatedText ?? this.translatedText,
      ttsState: ttsState ?? this.ttsState,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      debugInfo: debugInfo ?? this.debugInfo,
    );
  }
}

// ─── Notifier ────────────────────────────────────────────────

class ScannerNotifier extends StateNotifier<ScannerState> {
  ScannerNotifier() : super(const ScannerState()) {
    _ttsService.initialize();
    _ttsService.stateNotifier.addListener(_onTtsStateChange);
  }

  final CameraService _cameraService = CameraService();
  final TtsService _ttsService = TtsService();
  final BraillePipeline _pipeline = BraillePipeline();

  // Auto-TTS debounce.
  Timer? _autoSpeakTimer;
  String _lastSpokenText = '';

  // Expose camera service so ScannerScreen can attach the preview
  CameraService get cameraService => _cameraService;

  // ─── Permission & Initialization ─────────────────────────

  Future<void> requestPermissionAndInit() async {
    final status = await Permission.camera.request();
    state = state.copyWith(permissionStatus: status);

    if (status.isGranted) {
      await _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      // Load the TFLite model before streaming starts.
      await _pipeline.init();

      // Wire the raw-frame callback (runs the DIP+ML+voting pipeline).
      _cameraService.onFrameAvailable = _onFrame;

      await _cameraService.initialize();
      await _cameraService.startStream();

      state = state.copyWith(isCameraReady: true, clearError: true);
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Gagal menginisialisasi kamera: $e',
      );
    }
  }

  // ─── Frame Processing ────────────────────────────────────
  // Called for each frame that survives CameraService frame-skipping.
  // Runs the full pipeline and pushes the vote-stabilized result.

  Future<void> _onFrame(CameraImage frame) async {
    final result = _pipeline.process(
      frame,
      rotationQuarterTurns: _cameraService.rotationQuarterTurns,
    );

    if (result.text != state.translatedText ||
        result.state != state.detectionState ||
        result.debug != state.debugInfo) {
      state = state.copyWith(
        translatedText: result.text,
        detectionState: result.state,
        debugInfo: result.debug,
      );
    }

    if (result.state == DetectionState.detected) {
      _maybeAutoSpeak(result.text);
    }
  }

  /// Public injection point: push a translation result directly
  /// (kept for tests / external pipelines).
  void updateTranslation(String text, DetectionState detectionState) {
    state = state.copyWith(
      translatedText: text,
      detectionState: detectionState,
    );
  }

  // ─── Auto Text-to-Speech ─────────────────────────────────
  // Speaks a stable result once it settles, debounced so it doesn't
  // read out text that is still changing (PRD §5.3).

  void _maybeAutoSpeak(String text) {
    if (!AppConstants.autoSpeakEnabled) return;
    if (text.isEmpty || text == _lastSpokenText) return;

    _autoSpeakTimer?.cancel();
    _autoSpeakTimer = Timer(
      const Duration(milliseconds: AppConstants.autoSpeakDebounceMs),
      () {
        // Only speak if the text is still the current stable result.
        if (state.translatedText == text && text.isNotEmpty) {
          _lastSpokenText = text;
          _ttsService.speak(text);
        }
      },
    );
  }

  // ─── Controls ────────────────────────────────────────────

  Future<void> toggleFlash() async {
    final newVal = !state.isFlashOn;
    await _cameraService.toggleFlash(newVal);
    state = state.copyWith(isFlashOn: newVal);
  }

  Future<void> toggleCamera() async {
    _pipeline.reset(); // clear temporal votes for the new view
    await _cameraService.toggleCamera();
  }

  // ─── TTS ─────────────────────────────────────────────────

  Future<void> speakResult() async {
    if (!state.hasResult) return;
    await _ttsService.speak(state.translatedText);
  }

  Future<void> stopSpeaking() async {
    await _ttsService.stop();
  }

  void _onTtsStateChange() {
    state = state.copyWith(ttsState: _ttsService.stateNotifier.value);
  }

  @override
  void dispose() {
    _autoSpeakTimer?.cancel();
    _ttsService.stateNotifier.removeListener(_onTtsStateChange);
    _ttsService.dispose();
    _cameraService.dispose();
    _pipeline.dispose();
    super.dispose();
  }
}

// ─── Provider ────────────────────────────────────────────────

final scannerProvider =
    StateNotifierProvider<ScannerNotifier, ScannerState>((ref) {
  return ScannerNotifier();
});
