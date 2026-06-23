// lib/features/scanner/pipeline/braille_grid_decoder.dart
//
// ============================================================
// INTEGRATION ENGINEER — dot-blob detection + braille grid decode.
//
// Replaces the fragile projection-profile segmentation. Strategy:
//   1. Connected-component labeling on the binary (dots = 255), then
//      shape/size filtering so texture noise and edges are rejected.
//   2. Derive the grid unit `a` (dot pitch) from the spacing between
//      braille ROW clusters — stable, unlike nearest-neighbour.
//   3. Split blobs into text lines by large vertical gaps (scaled to
//      the median dot diameter).
//   4. Per line: anchor the top row, sort dots left→right, group them
//      into cells by horizontal gaps, then snap each dot to its
//      (column, row) grid slot → 6-dot pattern.
//   5. Decode the pattern via the braille table (deterministic).
//
// Key invariant (verified from the alphabet): EVERY letter A–Z has a
// dot in the left column, so a cell's left-most occupied column is
// always the left column — no single-column ambiguity.
// ============================================================

import 'dart:typed_data';
import '../../../core/constants/app_constants.dart';
import 'braille_alphabet.dart';
import 'gray_image.dart';

class _Blob {
  _Blob(this.cx, this.cy, this.area, this.minX, this.maxX, this.minY, this.maxY);
  final double cx, cy;
  final int area, minX, maxX, minY, maxY;

  /// Approximate dot diameter (mean of the two bbox sides).
  double get diameter => ((maxX - minX + 1) + (maxY - minY + 1)) / 2.0;
}

class DecodedCell {
  DecodedCell(this.letter, this.pattern, this.x0, this.y0, this.x1, this.y1);
  final String letter; // '' if pattern unknown
  final List<int> pattern; // [d1..d6]
  // Full 2×3 cell region in working-image coords (for B2: cropping the
  // REAL cell so the ML model classifies actual pixels, positions kept).
  final int x0, y0, x1, y1;
  int get width => x1 - x0;
  int get height => y1 - y0;
}

class GridDecodeResult {
  GridDecodeResult(this.cells, this.blobCount, this.diameter, this.pitch);
  final List<DecodedCell> cells;
  final int blobCount; // dots detected after filtering
  final double diameter; // median dot diameter (px)
  final double pitch; // grid unit `a` of the densest line (px)

  static final empty = GridDecodeResult(const [], 0, 0, 0);
}

class BrailleGridDecoder {
  BrailleGridDecoder._();

  /// Decodes all cells found in [binary] (dots = 255), reading order.
  static GridDecodeResult decode(GrayImage binary) {
    final blobs = _connectedComponents(binary);
    if (blobs.length < AppConstants.gridMinDots) {
      return GridDecodeResult(const [], blobs.length, 0, 0);
    }

    // Stable scale: median dot diameter. Used to separate text lines.
    final d = _medianDiameter(blobs);
    if (d <= 0) return GridDecodeResult(const [], blobs.length, 0, 0);

    final cells = <DecodedCell>[];
    var repPitch = 0.0;
    var densestLine = 0;
    for (final line in _splitLines(blobs, d)) {
      final a = _rowPitch(line, d);
      _decodeLine(line, a, cells);
      if (line.length > densestLine) {
        densestLine = line.length;
        repPitch = a;
      }
    }
    return GridDecodeResult(cells, blobs.length, d, repPitch);
  }

  static double _medianDiameter(List<_Blob> blobs) {
    final dia = blobs.map((b) => b.diameter).toList()..sort();
    return dia[dia.length ~/ 2];
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

    return _filterBlobs(blobs, w * h);
  }

  /// Keeps dot-like blobs only:
  ///   • round-ish (fill ratio, aspect) → rejects edges/streaks,
  ///   • large enough (absolute + relative to ROI) → rejects texture
  ///     specks even when they outnumber the real dots,
  ///   • size-consistent with the median → rejects outliers.
  static List<_Blob> _filterBlobs(List<_Blob> blobs, int roiArea) {
    final absMinArea = (roiArea * AppConstants.gridMinDotAreaFrac)
        .clamp(AppConstants.gridMinDotArea.toDouble(), double.infinity);

    final shaped = blobs.where((b) {
      if (b.area < absMinArea) return false;
      final bw = b.maxX - b.minX + 1;
      final bh = b.maxY - b.minY + 1;
      final aspect = bw > bh ? bw / bh : bh / bw;
      if (aspect > AppConstants.gridMaxAspect) return false;
      final fill = b.area / (bw * bh);
      if (fill < AppConstants.gridMinFillRatio) return false;
      return true;
    }).toList();
    if (shaped.isEmpty) return const [];

    final areas = shaped.map((b) => b.area).toList()..sort();
    final median = areas[areas.length ~/ 2];
    final maxArea = median * AppConstants.gridMaxDotAreaFactor;
    final minArea = median * AppConstants.gridMinDotAreaFactor;
    return shaped.where((b) => b.area <= maxArea && b.area >= minArea).toList();
  }

  // ─── 2. Split blobs into text lines by vertical gaps ─────
  // Uses the stable dot diameter `d`: row-to-row gaps are small (~1.7d
  // centre-to-centre), line-to-line gaps are much larger.
  static List<List<_Blob>> _splitLines(List<_Blob> blobs, double d) {
    final sorted = [...blobs]..sort((p, q) => p.cy.compareTo(q.cy));
    final lines = <List<_Blob>>[];
    var current = <_Blob>[];
    double? prevCy;
    final gap = d * AppConstants.gridLineGapDiamFactor;

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

  // ─── 3+4+5. Decode one text line into cells ──────────────
  // `a` is the grid unit (dot pitch), derived in [decode] from the
  // spacing between braille ROW clusters — far more stable than a
  // nearest-neighbour estimate.
  static void _decodeLine(List<_Blob> line, double a, List<DecodedCell> out) {
    if (line.isEmpty) return;

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

  /// Estimates the dot pitch from the smallest gap between adjacent
  /// row clusters (the true row pitch). Falls back to a multiple of the
  /// dot diameter when the line has only one row of dots.
  static double _rowPitch(List<_Blob> line, double d) {
    final ys = line.map((b) => b.cy).toList()..sort();
    final clusterGap = d * AppConstants.gridRowClusterDiamFactor;

    final centers = <double>[];
    var sum = ys.first;
    var count = 1;
    var prev = ys.first;
    for (var i = 1; i < ys.length; i++) {
      if (ys[i] - prev > clusterGap) {
        centers.add(sum / count);
        sum = 0;
        count = 0;
      }
      sum += ys[i];
      count++;
      prev = ys[i];
    }
    centers.add(sum / count);

    if (centers.length < 2) {
      return d * AppConstants.gridRowPitchFallbackDiam;
    }
    var minSpacing = double.infinity;
    for (var i = 1; i < centers.length; i++) {
      final s = centers[i] - centers[i - 1];
      if (s < minSpacing) minSpacing = s;
    }
    return minSpacing;
  }

  static DecodedCell _decodeCell(List<_Blob> cell, double a, double lineMinCy) {
    var minCx = double.infinity;
    // ✅ Fix Bug #2: Gunakan minCy dari TITIK-TITIK DI SEL INI SENDIRI,
    // bukan lineMinCy global. lineMinCy bisa berasal dari sel lain di baris
    // yang sama, sehingga row-offset terdistorsi dan huruf terbaca salah
    // (misal d2 dihitung sebagai row 0 → 'B' terbaca 'A').
    var cellMinCy = double.infinity;
    for (final b in cell) {
      if (b.cx < minCx) minCx = b.cx;
      if (b.cy < cellMinCy) cellMinCy = b.cy;
    }

    final pattern = List<int>.filled(6, 0);
    for (final b in cell) {
      final col = ((b.cx - minCx) / a).round().clamp(0, 1);
      // Gunakan cellMinCy sebagai referensi row (bukan lineMinCy)
      final row = ((b.cy - cellMinCy) / a).round().clamp(0, 2);
      pattern[col * 3 + row] = 1;
    }

    // Full cell extent: left col at minCx, right col at minCx+a (2 cols),
    // 3 rows anchored at cellMinCy, with a half-pitch margin all round.
    final m = a * 0.5;
    final x0 = (minCx - m).round();
    final y0 = (cellMinCy - m).round();
    final x1 = (minCx + a + m).round();
    final y1 = (cellMinCy + 2 * a + m).round();

    return DecodedCell(BrailleAlphabet.decode(pattern), pattern, x0, y0, x1, y1);
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
