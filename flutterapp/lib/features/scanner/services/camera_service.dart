// lib/features/scanner/services/camera_service.dart
//
// ============================================================
// INTEGRATION ENGINEER NOTES:
// This service manages camera lifecycle. The [onFrameAvailable]
// callback is the injection point for your ML frame processing.
// Replace the mock methods with real TFLite / OpenCV calls.
// ============================================================

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import '../../../core/constants/app_constants.dart';

/// Enum representing the current detection state of the viewfinder.
enum DetectionState {
  /// No Braille detected — viewfinder shows idle (white) border.
  idle,

  /// Braille is being analyzed — viewfinder shows warning (amber) border.
  detecting,

  /// Braille fully detected — viewfinder shows active (teal) border.
  detected,
}

/// Callback type for raw camera frames that survive frame-skipping.
/// The Integration Engineer's pipeline runs inside this callback.
/// It is awaited, so the busy-guard can drop frames while one is still
/// being processed (prevents inference pile-up / overheating).
typedef RawFrameCallback = Future<void> Function(CameraImage frame);

class CameraService {
  CameraService({this.onFrameAvailable});

  /// ─── INTEGRATION POINT ──────────────────────────────────────
  /// Assign this callback to receive raw frames for ML processing.
  /// Only ~1 of every (frameSkipCount + 1) frames is delivered, and
  /// a new frame is dropped while the previous one is still running.
  RawFrameCallback? onFrameAvailable;

  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;
  bool _isStreaming = false;

  // Frame-skipping / busy-guard state.
  int _frameCounter = 0;
  bool _isProcessing = false;

  CameraController? get controller => _controller;
  bool get isInitialized => _isInitialized;
  bool get isStreaming => _isStreaming;

  /// Quarter-turns needed to bring the sensor buffer upright, derived
  /// from the active camera's sensor orientation (90° → 1 turn).
  int get rotationQuarterTurns {
    final degrees = _controller?.description.sensorOrientation ?? 90;
    return (degrees ~/ 90) % 4;
  }

  /// Initializes the camera. Call after permissions are granted.
  Future<void> initialize() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) throw Exception('No cameras available');

      _controller = CameraController(
        _cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _controller!.initialize();
      _isInitialized = true;
    } catch (e) {
      debugPrint('[CameraService] Initialization error: $e');
      rethrow;
    }
  }

  /// Starts the image stream with frame-skipping for thermal/perf.
  ///
  /// Only ~1 of every (frameSkipCount + 1) frames is forwarded to
  /// [onFrameAvailable] (PRD target ≈6 FPS). A busy-guard additionally
  /// drops any frame that arrives while the previous one is still being
  /// processed, so heavy inference can never queue up and overheat.
  Future<void> startStream() async {
    if (!_isInitialized || _isStreaming) return;

    await _controller!.startImageStream((CameraImage frame) {
      // ── Frame skipping ──────────────────────────────────────
      const n = AppConstants.frameSkipCount + 1;
      if (_frameCounter++ % n != 0) return;

      // ── Busy-guard: drop frame if a previous one is in flight ─
      if (_isProcessing) return;
      final callback = onFrameAvailable;
      if (callback == null) return;

      _isProcessing = true;
      callback(frame).whenComplete(() => _isProcessing = false);
    });

    _isStreaming = true;
  }

  /// Stops the image stream (e.g., when app is backgrounded).
  Future<void> stopStream() async {
    if (!_isStreaming) return;
    await _controller?.stopImageStream();
    _isStreaming = false;
    _isProcessing = false;
    _frameCounter = 0;
  }

  /// Switches between front and rear cameras.
  Future<void> toggleCamera() async {
    if (_cameras.length < 2) return;
    final currentIndex = _cameras.indexOf(_controller!.description);
    final nextCamera = _cameras[(currentIndex + 1) % _cameras.length];

    await stopStream();
    await _controller?.dispose();

    _controller = CameraController(
      nextCamera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await _controller!.initialize();
    await startStream();
  }

  /// Toggles camera torch/flashlight.
  Future<void> toggleFlash(bool enable) async {
    if (!_isInitialized) return;
    await _controller?.setFlashMode(
      enable ? FlashMode.torch : FlashMode.off,
    );
  }

  Future<void> dispose() async {
    await stopStream();
    await _controller?.dispose();
    _controller = null;
    _isInitialized = false;
  }
}
