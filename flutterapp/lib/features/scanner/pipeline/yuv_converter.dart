// lib/features/scanner/pipeline/yuv_converter.dart
//
// ============================================================
// INTEGRATION ENGINEER — frame ingestion.
// Converts a camera [CameraImage] (YUV420 on Android, BGRA on iOS)
// into an upright grayscale [GrayImage]. For YUV420 the Y plane IS
// the luminance, so grayscale is essentially free — we only copy
// the Y plane (honoring row stride) and rotate it upright.
// ============================================================

import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'gray_image.dart';

class YuvConverter {
  YuvConverter._();

  /// Extracts an upright grayscale image from [frame].
  ///
  /// [rotationQuarterTurns] brings the sensor-orientation buffer to
  /// display orientation (typically 1 for a back camera in portrait).
  static GrayImage toGray(CameraImage frame, {int rotationQuarterTurns = 1}) {
    final GrayImage gray;
    switch (frame.format.group) {
      case ImageFormatGroup.yuv420:
        gray = _fromYPlane(frame);
        break;
      case ImageFormatGroup.bgra8888:
        gray = _fromBgra(frame);
        break;
      default:
        // Best effort: assume the first plane is luminance-like.
        gray = _fromYPlane(frame);
    }
    return gray.rotate(rotationQuarterTurns);
  }

  /// YUV420 / NV21 — the Y (luma) plane already is grayscale.
  static GrayImage _fromYPlane(CameraImage frame) {
    final plane = frame.planes[0];
    final w = frame.width;
    final h = frame.height;
    final stride = plane.bytesPerRow;
    final src = plane.bytes;
    final out = Uint8List(w * h);

    if (stride == w) {
      // Tightly packed: single copy.
      out.setRange(0, w * h, src);
    } else {
      for (int y = 0; y < h; y++) {
        final srcRow = y * stride;
        out.setRange(y * w, y * w + w, src, srcRow);
      }
    }
    return GrayImage(w, h, out);
  }

  /// BGRA8888 (iOS) — derive luma from RGB (ITU-R BT.601).
  static GrayImage _fromBgra(CameraImage frame) {
    final plane = frame.planes[0];
    final w = frame.width;
    final h = frame.height;
    final stride = plane.bytesPerRow;
    final src = plane.bytes;
    final out = Uint8List(w * h);

    for (int y = 0; y < h; y++) {
      var p = y * stride;
      final dstRow = y * w;
      for (int x = 0; x < w; x++) {
        final b = src[p];
        final g = src[p + 1];
        final r = src[p + 2];
        out[dstRow + x] = ((r * 77 + g * 150 + b * 29) >> 8).clamp(0, 255);
        p += 4;
      }
    }
    return GrayImage(w, h, out);
  }
}
