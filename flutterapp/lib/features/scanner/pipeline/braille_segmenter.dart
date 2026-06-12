// lib/features/scanner/pipeline/braille_segmenter.dart
//
// ============================================================
// INTEGRATION ENGINEER — cell segmentation (Dart port of the CV
// Engineer's Horizontal/Vertical Projection Profile method).
//
// Given a binary image (0 = paper, 255 = dot), find the bounding
// box of each Braille cell so each can be classified independently.
// Row segments split text lines; within a line, column segments
// split characters. Boxes are returned in reading order
// (top-to-bottom, then left-to-right).
// ============================================================

import 'dart:typed_data';
import '../../../core/constants/app_constants.dart';
import 'gray_image.dart';

class CellBox {
  const CellBox(this.rStart, this.rEnd, this.cStart, this.cEnd);
  final int rStart, rEnd, cStart, cEnd;

  int get width => cEnd - cStart + 1;
  int get height => rEnd - rStart + 1;
}

class BrailleSegmenter {
  BrailleSegmenter._();

  /// Segments [binary] into cell bounding boxes (reading order).
  static List<CellBox> segment(GrayImage binary) {
    final hProj = _horizontalProfile(binary); // white px per row
    final vProj = _verticalProfile(binary); // white px per col

    final rowSegs = _findSegments(hProj);
    final colSegs = _findSegments(vProj);

    final boxes = <CellBox>[];
    for (final (rStart, rEnd) in rowSegs) {
      for (final (cStart, cEnd) in colSegs) {
        if (cEnd - cStart + 1 < AppConstants.segMinCellWidth) continue;
        boxes.add(CellBox(rStart, rEnd, cStart, cEnd));
      }
    }

    boxes.sort((a, b) {
      // Group rows that overlap vertically, then order by column.
      if (a.rEnd < b.rStart) return -1;
      if (b.rEnd < a.rStart) return 1;
      return a.cStart.compareTo(b.cStart);
    });
    return boxes;
  }

  static Float64List _horizontalProfile(GrayImage img) {
    final out = Float64List(img.height);
    for (int y = 0; y < img.height; y++) {
      int count = 0;
      final row = y * img.width;
      for (int x = 0; x < img.width; x++) {
        if (img.pixels[row + x] > 127) count++;
      }
      out[y] = count.toDouble();
    }
    return out;
  }

  static Float64List _verticalProfile(GrayImage img) {
    final out = Float64List(img.width);
    for (int x = 0; x < img.width; x++) {
      int count = 0;
      for (int y = 0; y < img.height; y++) {
        if (img.pixels[y * img.width + x] > 127) count++;
      }
      out[x] = count.toDouble();
    }
    return out;
  }

  /// Finds (start, end) runs where the profile exceeds the content
  /// threshold, tolerating gaps shorter than [segMinGap].
  static List<(int, int)> _findSegments(Float64List projection) {
    const threshold = AppConstants.segProjThreshold;
    const minGap = AppConstants.segMinGap;

    final segments = <(int, int)>[];
    bool inSegment = false;
    int start = 0;
    int gap = 0;

    for (int i = 0; i < projection.length; i++) {
      final active = projection[i] > threshold;
      if (active) {
        if (!inSegment) {
          start = i;
          inSegment = true;
        }
        gap = 0;
      } else if (inSegment) {
        gap++;
        if (gap >= minGap) {
          segments.add((start, i - gap));
          inSegment = false;
          gap = 0;
        }
      }
    }
    if (inSegment) {
      segments.add((start, projection.length - 1));
    }
    return segments;
  }
}
