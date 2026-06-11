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

/// Enum representing the current detection state of the viewfinder.
enum DetectionState {
  /// No Braille detected — viewfinder shows idle (white) border.
  idle,

  /// Braille is being analyzed — viewfinder shows warning (amber) border.
  detecting,

  /// Braille fully detected — viewfinder shows active (teal) border.
  detected,
}

/// Callback type for processed frame results.
/// [translatedText] — The Braille translation result.
/// [state] — The detection confidence state.
typedef FrameResultCallback = void Function({
  required String translatedText,
  required DetectionState state,
});

class CameraService {
  CameraService({this.onFrameResult});

  /// ─── INTEGRATION POINT ──────────────────────────────────────
  /// Assign this callback to receive processed frame results.
  /// Your ML pipeline should call this with the translation output.
  ///
  /// Example (from your integration code):
  /// ```dart
  /// cameraService.onFrameResult = ({translatedText, state}) {
  ///   ref.read(scannerProvider.notifier).updateResult(translatedText, state);
  /// };
  /// ```
  FrameResultCallback? onFrameResult;

  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;
  bool _isStreaming = false;

  CameraController? get controller => _controller;
  bool get isInitialized => _isInitialized;
  bool get isStreaming => _isStreaming;

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

  /// Starts the image stream for frame-by-frame processing.
  ///
  /// ─── INTEGRATION POINT ──────────────────────────────────────
  /// Replace the comment block below with your actual frame
  /// processing logic (TFLite inference, OpenCV preprocessing, etc.)
  ///
  /// The [CameraImage] provides raw YUV420 frames. Convert to
  /// RGB/grayscale as needed by your ML model.
  Future<void> startStream() async {
    if (!_isInitialized || _isStreaming) return;

    await _controller!.startImageStream((CameraImage frame) {
      // ── BEGIN INTEGRATION ZONE ──────────────────────────────
      // TODO (Integration Engineer): Process [frame] here.
      //
      // 1. Convert CameraImage (YUV420) to usable format.
      // 2. Run your Braille detection model (TFLite/OpenCV).
      // 3. Call [onFrameResult] with the result.
      //
      // Example:
      // final result = await myBrailleModel.process(frame);
      // onFrameResult?.call(
      //   translatedText: result.text,
      //   state: result.confidence > 0.85
      //       ? DetectionState.detected
      //       : DetectionState.detecting,
      // );
      // ── END INTEGRATION ZONE ────────────────────────────────
    });

    _isStreaming = true;
  }

  /// Stops the image stream (e.g., when app is backgrounded).
  Future<void> stopStream() async {
    if (!_isStreaming) return;
    await _controller?.stopImageStream();
    _isStreaming = false;
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
