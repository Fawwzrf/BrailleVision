// lib/features/scanner/pipeline/braille_grid_decoder.dart
//
// ============================================================
// INTEGRATION ENGINEER — dot-blob detection + braille grid decode.
//
// Replaces the fragile projection-profile segmentation. Strategy:
//   1. Connected-component labeling on the binary (dots = 255).
//   2. Estimate the dot pitch `a` (median nearest-neighbour distance).
//   3. Split blobs into text lines by large vertical gaps.
//   4. Per line: anchor the top row, sort dots left→right, group them
//      into cells by horizontal gaps, then snap each dot to its
//      (column, row) grid slot → 6-dot pattern.
//   5. Decode the pattern via the braille table (deterministic).
//
// Key invariant (verified from the alphabet): EVERY letter A–Z has a
// dot in the left column, so a cell's left-most occupied column is
// always the left column — no single-column ambiguity.
// ============================================================

import 'dart:math' as math;
import 'dart:typed_data';
import '../../../core/constants/app_constants.dart';
import 'braille_alphabet.dart';
import 'gray_image.dart';

class _Blob {
  _Blob(this.cx, this.cy, this.area, this.minX, this.maxX, this.minY, this.maxY);
  final double cx, cy;
  final int area, minX, maxX, minY, maxY;
}

class DecodedCell {
  DecodedCell(this.letter, this.pattern);
  final String letter; // '' if pattern unknown
  final List<int> pattern; // [d1..d6]
}

class BrailleGridDecoder {
  BrailleGridDecoder._();

  /// Decodes all cells found in [binary] (dots = 255), reading order.
  static List<DecodedCell> decode(GrayImage binary) {
    final blobs = _connectedComponents(binary);
    if (blobs.length < AppConstants.gridMinDots) return const [];

    final a = _estimatePitch(blobs);
    if (a <= 0) return const [];

    final cells = <DecodedCell>[];
    for (final line in _splitLines(blobs, a)) {
      _decodeLine(line, a, cells);
    }
    return cells;
  }

  // ─── 1. Connected components (8-connectivity flood fill) ──
  static List<_Blob> _connectedComponents(GrayImage img) {
    final w = img.width, h = img.height;
    final px = img.pixels;
    final visited = Uint8List(w * h);
    final blobs = <_Blob>[];
    final stack = <int>[];

    for (int start = 0; start < px.length; start++) {
      if (px[start] <= 127 || visited[start] != 0) continue;

      stack
        ..clear()
        ..add(start);
      visited[start] = 1;
      int area = 0, sumX = 0, sumY = 0;
      int minX = w, maxX = 0, minY = h, maxY = 0;

      while (stack.isNotEmpty) {
        final p = stack.removeLast();
        final x = p % w, y = p ~/ w;
        area++;
        sumX += x;
        sumY += y;
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;

        for (int dy = -1; dy <= 1; dy++) {
          final ny = y + dy;
          if (ny < 0 || ny >= h) continue;
          for (int dx = -1; dx <= 1; dx++) {
            final nx = x + dx;
            if (nx < 0 || nx >= w) continue;
            final np = ny * w + nx;
            if (px[np] > 127 && visited[np] == 0) {
              visited[np] = 1;
              stack.add(np);
            }
          }
        }
      }

      blobs.add(_Blob(sumX / area, sumY / area, area, minX, maxX, minY, maxY));
    }

    return _filterBySize(blobs);
  }

  /// Keep dot-sized blobs: reject specks and oversized merged regions.
  static List<_Blob> _filterBySize(List<_Blob> blobs) {
    final big = blobs.where((b) => b.area >= AppConstants.gridMinDotArea).toList();
    if (big.isEmpty) return const [];

    final areas = big.map((b) => b.area).toList()..sort();
    final median = areas[areas.length ~/ 2];
    final maxArea = median * AppConstants.gridMaxDotAreaFactor;
    return big.where((b) => b.area <= maxArea).toList();
  }

  // ─── 2. Dot pitch via median nearest-neighbour distance ──
  static double _estimatePitch(List<_Blob> blobs) {
    final dists = <double>[];
    for (int i = 0; i < blobs.length; i++) {
      var best = double.infinity;
      for (int j = 0; j < blobs.length; j++) {
        if (i == j) continue;
        final dx = blobs[i].cx - blobs[j].cx;
        final dy = blobs[i].cy - blobs[j].cy;
        final d = dx * dx + dy * dy;
        if (d < best) best = d;
      }
      if (best.isFinite) dists.add(best);
    }
    if (dists.isEmpty) return 0;
    dists.sort();
    return math.sqrt(dists[dists.length ~/ 2]);
  }

  // ─── 3. Split blobs into text lines by vertical gaps ─────
  static List<List<_Blob>> _splitLines(List<_Blob> blobs, double a) {
    final sorted = [...blobs]..sort((p, q) => p.cy.compareTo(q.cy));
    final lines = <List<_Blob>>[];
    var current = <_Blob>[];
    double? prevCy;
    final gap = a * AppConstants.gridLineGapFactor;

    for (final b in sorted) {
      if (prevCy != null && b.cy - prevCy > gap && current.isNotEmpty) {
        lines.add(current);
        current = <_Blob>[];
      }
      current.add(b);
      prevCy = b.cy;
    }
    if (current.isNotEmpty) lines.add(current);
    return lines;
  }

  // ─── 4+5. Decode one text line into cells ────────────────
  static void _decodeLine(List<_Blob> line, double a, List<DecodedCell> out) {
    if (line.isEmpty) return;

    // Anchor: top row of the line (some char will own a row-0 dot).
    var lineMinCy = double.infinity;
    for (final b in line) {
      if (b.cy < lineMinCy) lineMinCy = b.cy;
    }

    final sorted = [...line]..sort((p, q) => p.cx.compareTo(q.cx));
    final cellGap = a * AppConstants.gridCellGapFactor;

    var cell = <_Blob>[];
    double? prevCx;
    for (final b in sorted) {
      if (prevCx != null && b.cx - prevCx > cellGap && cell.isNotEmpty) {
        out.add(_decodeCell(cell, a, lineMinCy));
        cell = <_Blob>[];
      }
      cell.add(b);
      prevCx = b.cx;
    }
    if (cell.isNotEmpty) out.add(_decodeCell(cell, a, lineMinCy));
  }

  static DecodedCell _decodeCell(List<_Blob> cell, double a, double lineMinCy) {
    var minCx = double.infinity;
    for (final b in cell) {
      if (b.cx < minCx) minCx = b.cx;
    }

    final pattern = List<int>.filled(6, 0);
    for (final b in cell) {
      final col = ((b.cx - minCx) / a).round().clamp(0, 1);
      final row = ((b.cy - lineMinCy) / a).round().clamp(0, 2);
      pattern[col * 3 + row] = 1;
    }
    return DecodedCell(BrailleAlphabet.decode(pattern), pattern);
  }

  // ─── Clean-cell renderer (for the ML model comparison) ───
  // Reproduces the training look (dark dots on a light 64×64 canvas,
  // standard 2×3 grid with the same margins as the synthetic data).
  static GrayImage renderCleanCell(List<int> pattern) {
    const size = 64;
    final px = Uint8List(size * size)..fillRange(0, size * size, 255);

    const marginX = size * 0.25; // 16
    const marginY = size * 0.15; // 9.6
    const spacingX = size - 2 * marginX; // 32
    const spacingY = (size - 2 * marginY) / 2; // 22.4
    const radius = 6.0;

    final centers = <List<double>>[
      [marginX, marginY], // d1
      [marginX, marginY + spacingY], // d2
      [marginX, marginY + 2 * spacingY], // d3
      [marginX + spacingX, marginY], // d4
      [marginX + spacingX, marginY + spacingY], // d5
      [marginX + spacingX, marginY + 2 * spacingY], // d6
    ];

    for (int i = 0; i < 6; i++) {
      if (pattern[i] == 0) continue;
      _fillCircle(px, size, centers[i][0], centers[i][1], radius, 60);
    }
    return GrayImage(size, size, px);
  }

  static void _fillCircle(
      Uint8List px, int size, double cx, double cy, double r, int shade) {
    final r2 = r * r;
    final x0 = (cx - r).floor().clamp(0, size - 1);
    final x1 = (cx + r).ceil().clamp(0, size - 1);
    final y0 = (cy - r).floor().clamp(0, size - 1);
    final y1 = (cy + r).ceil().clamp(0, size - 1);
    for (int y = y0; y <= y1; y++) {
      for (int x = x0; x <= x1; x++) {
        final dx = x - cx, dy = y - cy;
        if (dx * dx + dy * dy <= r2) px[y * size + x] = shade;
      }
    }
  }
}
