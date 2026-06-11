// lib/features/scanner/providers/scanner_provider.dart
//
// ============================================================
// INTEGRATION ENGINEER NOTES:
// This is the central state of the scanner screen.
// Call [updateTranslation] from your frame processing callback
// to push new translation results into the UI.
// ============================================================

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/camera_service.dart';
import '../services/tts_service.dart';
import '../../../core/constants/app_constants.dart';

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
  });

  final PermissionStatus permissionStatus;
  final bool isCameraReady;
  final bool isFlashOn;
  final DetectionState detectionState;
  final String translatedText;
  final TtsState ttsState;
  final String? errorMessage;

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
  }) {
    return ScannerState(
      permissionStatus: permissionStatus ?? this.permissionStatus,
      isCameraReady: isCameraReady ?? this.isCameraReady,
      isFlashOn: isFlashOn ?? this.isFlashOn,
      detectionState: detectionState ?? this.detectionState,
      translatedText: translatedText ?? this.translatedText,
      ttsState: ttsState ?? this.ttsState,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
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
  Timer? _mockDetectionTimer;

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
      // Wire up the frame result callback
      _cameraService.onFrameResult = _onFrameResult;

      await _cameraService.initialize();
      await _cameraService.startStream();

      state = state.copyWith(isCameraReady: true, clearError: true);
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Gagal menginisialisasi kamera: $e',
      );
    }
  }

  // ─── INTEGRATION POINT ───────────────────────────────────
  // This method is called by the camera stream callback.
  // Your ML pipeline should eventually call this (via onFrameResult).
  //
  // You can also call this directly for testing:
  // ref.read(scannerProvider.notifier).updateTranslation('Halo Dunia', DetectionState.detected);

  void _onFrameResult({
    required String translatedText,
    required DetectionState state,
  }) {
    updateTranslation(translatedText, state);
  }

  /// Public method for Integration Engineer to push translation results.
  void updateTranslation(String text, DetectionState detectionState) {
    state = state.copyWith(
      translatedText: text,
      detectionState: detectionState,
    );
  }

  // ─── Mock Detection (UI Demo) ─────────────────────────────
  // Simulates Braille detection for UI development/testing.
  // Remove or disable this once real ML integration is wired.

  // void startMockDetection() {
  //   _mockDetectionTimer?.cancel();
  //   state = state.copyWith(detectionState: DetectionState.detecting);

  //   _mockDetectionTimer = Timer(
  //     const Duration(milliseconds: AppConstants.detectionSimulateDelayMs),
  //     () {
  //       state = state.copyWith(
  //         detectionState: DetectionState.detected,
  //         translatedText: 'Ini adalah teks hasil terjemahan Braille.',
  //       );
  //     },
  //   );
  // }

  // void resetDetection() {
  //   _mockDetectionTimer?.cancel();
  //   state = state.copyWith(
  //     detectionState: DetectionState.idle,
  //     translatedText: '',
  //   );
  // }

  // ─── Controls ────────────────────────────────────────────

  Future<void> toggleFlash() async {
    final newVal = !state.isFlashOn;
    await _cameraService.toggleFlash(newVal);
    state = state.copyWith(isFlashOn: newVal);
  }

  Future<void> toggleCamera() async {
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
    _mockDetectionTimer?.cancel();
    _ttsService.stateNotifier.removeListener(_onTtsStateChange);
    _ttsService.dispose();
    _cameraService.dispose();
    super.dispose();
  }
}

// ─── Provider ────────────────────────────────────────────────

final scannerProvider =
    StateNotifierProvider<ScannerNotifier, ScannerState>((ref) {
  return ScannerNotifier();
});
