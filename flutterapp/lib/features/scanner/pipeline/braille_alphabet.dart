// lib/features/scanner/pipeline/braille_alphabet.dart
//
// ============================================================
// INTEGRATION ENGINEER — Braille pattern table.
// Source of truth = ml_pipeline/notebooks/synthetic_data_generation.ipynb
// (the exact map the model was trained against).
//
// Dot numbering within a cell (2 columns × 3 rows):
//     1 4
//     2 5
//     3 6
// A pattern is the 6-bit list [d1, d2, d3, d4, d5, d6].
// Index mapping used across the pipeline: position = col*3 + row,
// i.e. left column = {1,2,3}, right column = {4,5,6}.
// ============================================================

class BrailleAlphabet {
  BrailleAlphabet._();

  /// letter → 6-dot pattern [d1..d6].
  static const Map<String, List<int>> patterns = {
    'A': [1, 0, 0, 0, 0, 0],
    'B': [1, 1, 0, 0, 0, 0],
    'C': [1, 0, 0, 1, 0, 0],
    'D': [1, 0, 0, 1, 1, 0],
    'E': [1, 0, 0, 0, 1, 0],
    'F': [1, 1, 0, 1, 0, 0],
    'G': [1, 1, 0, 1, 1, 0],
    'H': [1, 1, 0, 0, 1, 0],
    'I': [0, 1, 0, 1, 0, 0],
    'J': [0, 1, 0, 1, 1, 0],
    'K': [1, 0, 1, 0, 0, 0],
    'L': [1, 1, 1, 0, 0, 0],
    'M': [1, 0, 1, 1, 0, 0],
    'N': [1, 0, 1, 1, 1, 0],
    'O': [1, 0, 1, 0, 1, 0],
    'P': [1, 1, 1, 1, 0, 0],
    'Q': [1, 1, 1, 1, 1, 0],
    'R': [1, 1, 1, 0, 1, 0],
    'S': [0, 1, 1, 1, 0, 0],
    'T': [0, 1, 1, 1, 1, 0],
    'U': [1, 0, 1, 0, 0, 1],
    'V': [1, 1, 1, 0, 0, 1],
    'W': [0, 1, 0, 1, 1, 1],
    'X': [1, 0, 1, 1, 0, 1],
    'Y': [1, 0, 1, 1, 1, 1],
    'Z': [1, 0, 1, 0, 1, 1],
  };

  /// "d1d2d3d4d5d6" key → letter, built once.
  static final Map<String, String> _decode = {
    for (final e in patterns.entries) e.value.join(): e.key,
  };

  /// Decodes a 6-bit pattern into a letter, or '' if it matches nothing.
  static String decode(List<int> pattern) => _decode[pattern.join()] ?? '';
}
