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

    var maxLen = 0;
    for (final frame in _buffer) {
      if (frame.length > maxLen) maxLen = frame.length;
    }

    final sb = StringBuffer();
    for (int pos = 0; pos < maxLen; pos++) {
      final counts = <String, int>{};
      for (final frame in _buffer) {
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
