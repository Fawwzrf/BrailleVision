// lib/features/scanner/pipeline/temporal_voter.dart
//
// ============================================================
// INTEGRATION ENGINEER — Temporal Voting (PRD §6, §7.3).
//
// Stabilizes the live output against per-frame jitter caused by hand
// tremor / lighting flicker. Keeps the last N per-frame predictions
// and votes each character POSITION independently (majority/mode).
// A character is only emitted once it wins at least [minAgreement]
// votes inside the window, so a single misread frame can't change
// the on-screen text — satisfying "text stable within a 2s window".
//
// FIX v2 — Length-consensus voting:
//   The old logic used maxLen (longest frame in buffer), which meant
//   a single outlier frame with extra/missing cells would expand the
//   vote positions and dilute agreement at every real position.
//   New logic: find the most common frame length (consensus), then
//   only vote using frames within ±1 of that length. This makes the
//   result robust to frames where 1 cell is occasionally missed/split.
// ============================================================

import 'dart:collection';

class TemporalVoter {
  TemporalVoter({required this.windowSize, required this.minAgreement});

  final int windowSize;
  final int minAgreement;

  final Queue<List<String>> _buffer = Queue<List<String>>();

  /// Number of frames currently buffered.
  int get length => _buffer.length;

  /// True once the window is full (voting at full confidence).
  bool get isWarmedUp => _buffer.length >= windowSize;

  /// Pushes the latest frame's per-cell letters and returns the
  /// current stable string (may be empty while jitter/low-agreement).
  String add(List<String> frameLetters) {
    _buffer.addLast(frameLetters);
    while (_buffer.length > windowSize) {
      _buffer.removeFirst();
    }
    return _vote();
  }

  String _vote() {
    if (_buffer.isEmpty) return '';

    // ── Step 1: Find the consensus length (most common non-zero length).
    // This prevents one outlier frame from polluting positional alignment.
    final lengthCounts = <int, int>{};
    for (final frame in _buffer) {
      if (frame.isEmpty) continue;
      lengthCounts[frame.length] = (lengthCounts[frame.length] ?? 0) + 1;
    }
    if (lengthCounts.isEmpty) return '';

    int consensusLen = 0;
    int bestLenCount = 0;
    lengthCounts.forEach((len, count) {
      if (count > bestLenCount) {
        bestLenCount = count;
        consensusLen = len;
      }
    });

    // ── Step 2: Only include frames within ±1 of consensusLen.
    // This tolerates occasional detection of 1 extra / 1 missing cell
    // without breaking positional alignment for the majority of frames.
    final eligible = _buffer
        .where((f) => f.isNotEmpty && (f.length - consensusLen).abs() <= 1)
        .toList();
    if (eligible.isEmpty) return '';

    // ── Step 3: Positional voting on consensus-length positions.
    final sb = StringBuffer();
    for (int pos = 0; pos < consensusLen; pos++) {
      final counts = <String, int>{};
      for (final frame in eligible) {
        if (pos < frame.length) {
          final ch = frame[pos];
          counts[ch] = (counts[ch] ?? 0) + 1;
        }
      }
      String? winner;
      var winnerVotes = 0;
      counts.forEach((ch, votes) {
        if (votes > winnerVotes) {
          winnerVotes = votes;
          winner = ch;
        }
      });
      if (winner != null && winnerVotes >= minAgreement) {
        sb.write(winner);
      }
    }
    return sb.toString();
  }

  void reset() => _buffer.clear();
}
