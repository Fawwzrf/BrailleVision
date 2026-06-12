// lib/features/scanner/pipeline/braille_preprocessor.dart
//
// ============================================================
// INTEGRATION ENGINEER — DIP module (Dart port of CV Engineer's
// OpenCV notebook: EngineeringCV/BrailleVision_CV_Engineer.ipynb).
//
// Pipeline (binary output, used to LOCATE the Braille dots so cells
// can be segmented — NOT fed to the model directly):
//   1. Gaussian blur (3x3)
//   2. Adaptive threshold (local mean, BINARY_INV → dots become white)
//   3. Morphology: erode then dilate (2x2) to clean noise
//
// NOTE: The classifier itself is fed the *grayscale* crop (to match
// how the model was trained — see BrailleClassifier), while this
// binary map is only used by BrailleSegmenter to find cell bounds.
// ============================================================

import 'dart:typed_data';
import '../../../core/constants/app_constants.dart';
import 'gray_image.dart';

class BraillePreprocessor {
  BraillePreprocessor._();

  /// Produces a binary image (0 = paper, 255 = Braille dot) used for
  /// projection-profile segmentation.
  ///
  /// Polarity-aware: works whether the source has DARK dots on a light
  /// paper or LIGHT dots on a dark card. Braille dots are always the
  /// minority of the area, so if the thresholded foreground ends up
  /// being the majority we invert it — guaranteeing dots = 255.
  static GrayImage forSegmentation(GrayImage gray) {
    final blurred = _blur3x3(gray);
    final binary = _adaptiveThreshold(
      blurred,
      blockSize: AppConstants.threshBlockSize,
      c: AppConstants.threshC,
    );
    final eroded = _erode(binary, AppConstants.morphKernelSize);
    final dilated = _dilate(eroded, AppConstants.morphKernelSize);
    return _ensureDotsAreForeground(dilated);
  }

  /// Counts white pixels; if they exceed half the image, the dots are
  /// actually the dark class, so invert so dots = 255 (minority).
  static GrayImage _ensureDotsAreForeground(GrayImage binary) {
    var white = 0;
    for (var i = 0; i < binary.pixels.length; i++) {
      if (binary.pixels[i] > 127) white++;
    }
    if (white * 2 > binary.pixels.length) {
      return binary.inverted();
    }
    return binary;
  }

  // ─── Gaussian blur 3x3 (separable [1 2 1]/4) ──────────────
  static GrayImage _blur3x3(GrayImage img) {
    final w = img.width, h = img.height;
    final src = img.pixels;
    final tmp = Uint8List(w * h);
    final out = Uint8List(w * h);

    // Horizontal pass
    for (int y = 0; y < h; y++) {
      final row = y * w;
      for (int x = 0; x < w; x++) {
        final l = src[row + (x > 0 ? x - 1 : 0)];
        final c = src[row + x];
        final r = src[row + (x < w - 1 ? x + 1 : w - 1)];
        tmp[row + x] = (l + 2 * c + r) >> 2;
      }
    }
    // Vertical pass
    for (int y = 0; y < h; y++) {
      final up = (y > 0 ? y - 1 : 0) * w;
      final cu = y * w;
      final dn = (y < h - 1 ? y + 1 : h - 1) * w;
      for (int x = 0; x < w; x++) {
        out[cu + x] = (tmp[up + x] + 2 * tmp[cu + x] + tmp[dn + x]) >> 2;
      }
    }
    return GrayImage(w, h, out);
  }

  // ─── Adaptive threshold (local mean via integral image) ───
  // OpenCV equivalent: adaptiveThreshold(MEAN_C, THRESH_BINARY_INV).
  // dst = (src > localMean - C) ? 0 : 255  → darker-than-neighbours = dot.
  static GrayImage _adaptiveThreshold(
    GrayImage img, {
    required int blockSize,
    required int c,
  }) {
    final w = img.width, h = img.height;
    final src = img.pixels;
    final out = Uint8List(w * h);
    final radius = blockSize ~/ 2;

    // Integral image (w+1) x (h+1).
    final integral = Int32List((w + 1) * (h + 1));
    for (int y = 0; y < h; y++) {
      int rowSum = 0;
      final iRow = (y + 1) * (w + 1);
      final iPrev = y * (w + 1);
      final sRow = y * w;
      for (int x = 0; x < w; x++) {
        rowSum += src[sRow + x];
        integral[iRow + x + 1] = integral[iPrev + x + 1] + rowSum;
      }
    }

    for (int y = 0; y < h; y++) {
      final y0 = (y - radius).clamp(0, h - 1);
      final y1 = (y + radius).clamp(0, h - 1);
      final sRow = y * w;
      for (int x = 0; x < w; x++) {
        final x0 = (x - radius).clamp(0, w - 1);
        final x1 = (x + radius).clamp(0, w - 1);
        final area = (x1 - x0 + 1) * (y1 - y0 + 1);
        final sum = integral[(y1 + 1) * (w + 1) + (x1 + 1)] -
            integral[y0 * (w + 1) + (x1 + 1)] -
            integral[(y1 + 1) * (w + 1) + x0] +
            integral[y0 * (w + 1) + x0];
        final mean = sum / area;
        out[sRow + x] = (src[sRow + x] > mean - c) ? 0 : 255;
      }
    }
    return GrayImage(w, h, out);
  }

  // ─── Morphology (binary, square kernel of size k) ─────────
  static GrayImage _erode(GrayImage img, int k) =>
      _morph(img, k, erode: true);

  static GrayImage _dilate(GrayImage img, int k) =>
      _morph(img, k, erode: false);

  static GrayImage _morph(GrayImage img, int k, {required bool erode}) {
    final w = img.width, h = img.height;
    final src = img.pixels;
    final out = Uint8List(w * h);
    final r = k ~/ 2;
    // Even kernel sizes (e.g. 2) extend one extra pixel forward.
    final fwd = k - r - 1;

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        bool hit = erode; // erode: assume foreground until a 0 found
        for (int dy = -r; dy <= fwd && hit == erode; dy++) {
          final yy = y + dy;
          if (yy < 0 || yy >= h) continue;
          for (int dx = -r; dx <= fwd; dx++) {
            final xx = x + dx;
            if (xx < 0 || xx >= w) continue;
            final v = src[yy * w + xx] > 127;
            if (erode && !v) {
              hit = false;
              break;
            }
            if (!erode && v) {
              hit = true;
              break;
            }
          }
        }
        out[y * w + x] = hit ? 255 : 0;
      }
    }
    return GrayImage(w, h, out);
  }
}
