// lib/features/scanner/pipeline/gray_image.dart
//
// ============================================================
// INTEGRATION ENGINEER — DIP support type.
// A lightweight single-channel (8-bit grayscale) image with the
// handful of operations the Braille pipeline needs: rotate, crop,
// resize. Hand-rolled (no external image package) so we keep full
// control over per-frame cost in the live-stream loop.
// Pixels are row-major: index = y * width + x.
// ============================================================

import 'dart:typed_data';

class GrayImage {
  GrayImage(this.width, this.height, this.pixels)
      : assert(pixels.length == width * height);

  final int width;
  final int height;
  final Uint8List pixels;

  factory GrayImage.empty(int width, int height) =>
      GrayImage(width, height, Uint8List(width * height));

  int at(int x, int y) => pixels[y * width + x];

  /// Mean pixel value (0..255) — used to detect background polarity.
  double get mean {
    var sum = 0;
    for (var i = 0; i < pixels.length; i++) {
      sum += pixels[i];
    }
    return sum / pixels.length;
  }

  /// Returns a photometric negative (255 - v) of this image.
  GrayImage inverted() {
    final out = Uint8List(pixels.length);
    for (var i = 0; i < pixels.length; i++) {
      out[i] = 255 - pixels[i];
    }
    return GrayImage(width, height, out);
  }

  /// Places this image onto a square [side]×[side] canvas filled with
  /// [background], scaled to fit within a centered box that leaves
  /// [marginFraction] of the side as border on each edge. Preserves
  /// aspect ratio (letterboxed) — used to frame a cell like the
  /// model's training images instead of stretching it.
  GrayImage framedSquare(int side, double marginFraction, int background) {
    final out = Uint8List(side * side);
    if (background != 0) {
      out.fillRange(0, out.length, background);
    }
    final box = (side * (1 - 2 * marginFraction)).round().clamp(1, side);
    // Fit within the box, preserving aspect ratio (smaller scale wins).
    final scale = box / (width > height ? width : height);
    final newW = (width * scale).round().clamp(1, side);
    final newH = (height * scale).round().clamp(1, side);
    final resized = resize(newW, newH);
    final x0 = (side - newW) ~/ 2;
    final y0 = (side - newH) ~/ 2;
    for (var y = 0; y < newH; y++) {
      final dst = (y0 + y) * side + x0;
      out.setRange(dst, dst + newW, resized.pixels, y * newW);
    }
    return GrayImage(side, side, out);
  }

  /// Rotates the image clockwise by [quarterTurns] * 90°.
  /// Used to bring the sensor-orientation Y plane upright before
  /// segmentation (so a line of Braille reads left-to-right).
  GrayImage rotate(int quarterTurns) {
    final turns = ((quarterTurns % 4) + 4) % 4;
    if (turns == 0) return this;

    if (turns == 2) {
      final out = Uint8List(width * height);
      final n = width * height;
      for (int i = 0; i < n; i++) {
        out[i] = pixels[n - 1 - i];
      }
      return GrayImage(width, height, out);
    }

    // 90° (turns==1) or 270° (turns==3): dimensions swap.
    final dw = height;
    final dh = width;
    final out = Uint8List(dw * dh);
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final v = pixels[y * width + x];
        final int dx, dy;
        if (turns == 1) {
          // 90° CW
          dx = height - 1 - y;
          dy = x;
        } else {
          // 270° CW (== 90° CCW)
          dx = y;
          dy = width - 1 - x;
        }
        out[dy * dw + dx] = v;
      }
    }
    return GrayImage(dw, dh, out);
  }

  /// Center crop using fractions of width/height (0..1).
  GrayImage cropCenter(double widthFactor, double heightFactor) {
    final cw = (width * widthFactor).round().clamp(1, width);
    final ch = (height * heightFactor).round().clamp(1, height);
    final x0 = ((width - cw) / 2).round();
    final y0 = ((height - ch) / 2).round();
    return crop(x0, y0, cw, ch);
  }

  /// Crop a rectangular sub-region (clamped to bounds).
  GrayImage crop(int x0, int y0, int w, int h) {
    final cx0 = x0.clamp(0, width - 1);
    final cy0 = y0.clamp(0, height - 1);
    final cw = w.clamp(1, width - cx0);
    final ch = h.clamp(1, height - cy0);
    final out = Uint8List(cw * ch);
    for (int y = 0; y < ch; y++) {
      final srcRow = (cy0 + y) * width + cx0;
      out.setRange(y * cw, y * cw + cw, pixels, srcRow);
    }
    return GrayImage(cw, ch, out);
  }

  /// Bilinear resize to an arbitrary size.
  GrayImage resize(int newWidth, int newHeight) {
    if (newWidth == width && newHeight == height) return this;
    final out = Uint8List(newWidth * newHeight);
    final sx = width / newWidth;
    final sy = height / newHeight;
    for (int dy = 0; dy < newHeight; dy++) {
      final fy = (dy + 0.5) * sy - 0.5;
      final y0 = fy.floor().clamp(0, height - 1);
      final y1 = (y0 + 1).clamp(0, height - 1);
      final wy = (fy - y0).clamp(0.0, 1.0);
      for (int dx = 0; dx < newWidth; dx++) {
        final fx = (dx + 0.5) * sx - 0.5;
        final x0 = fx.floor().clamp(0, width - 1);
        final x1 = (x0 + 1).clamp(0, width - 1);
        final wx = (fx - x0).clamp(0.0, 1.0);

        final p00 = pixels[y0 * width + x0];
        final p01 = pixels[y0 * width + x1];
        final p10 = pixels[y1 * width + x0];
        final p11 = pixels[y1 * width + x1];

        final top = p00 + (p01 - p00) * wx;
        final bot = p10 + (p11 - p10) * wx;
        out[dy * newWidth + dx] = (top + (bot - top) * wy).round().clamp(0, 255);
      }
    }
    return GrayImage(newWidth, newHeight, out);
  }

  /// Scales so the height becomes [targetHeight], preserving aspect ratio.
  GrayImage scaledToHeight(int targetHeight) {
    if (height == targetHeight) return this;
    final targetWidth = (width * targetHeight / height).round().clamp(1, 1 << 20);
    return resize(targetWidth, targetHeight);
  }
}
