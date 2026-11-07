import 'text_normalizer.dart';

/// Helper for merging transcripts across chained speech recognition sessions (VOICE.md Section 3.2).
///
/// Prevents duplicated words and lost words at session boundaries by finding
/// overlapping word prefixes/suffixes between consecutive recognition chunks.
class WordMergeHelper {
  const WordMergeHelper();

  /// Merges [newSegment] onto [accumulated] with deduplication at the boundary.
  static String merge(String accumulated, String newSegment) {
    final acc = accumulated.trim();
    final seg = newSegment.trim();

    if (acc.isEmpty) return seg;
    if (seg.isEmpty) return acc;

    // If accumulated already contains the segment at the end, return accumulated
    if (acc == seg || acc.endsWith(' $seg')) {
      return acc;
    }

    // If new segment starts with accumulated (e.g. cumulative speech result)
    if (seg.startsWith('$acc ')) {
      return seg;
    }

    final accWords = acc.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final segWords = seg.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    if (accWords.isEmpty) return seg;
    if (segWords.isEmpty) return acc;

    // Check for maximum word overlap between end of accWords and start of segWords
    final maxOverlap = accWords.length < segWords.length ? accWords.length : segWords.length;
    int bestOverlap = 0;

    for (int k = maxOverlap; k >= 1; k--) {
      bool match = true;
      for (int i = 0; i < k; i++) {
        final w1 = _cleanWord(accWords[accWords.length - k + i]);
        final w2 = _cleanWord(segWords[i]);
        if (w1 != w2) {
          match = false;
          break;
        }
      }
      if (match) {
        bestOverlap = k;
        break;
      }
    }

    if (bestOverlap > 0) {
      // Overlap found: join accumulated with the remaining words of the segment
      final remainingWords = segWords.sublist(bestOverlap);
      if (remainingWords.isEmpty) {
        return acc;
      }
      return '$acc ${remainingWords.join(' ')}';
    }

    // No overlap: simply join with space
    return '$acc $seg';
  }

  /// Cleans word for boundary comparison (removes punctuation, unifies arabic letters)
  static String _cleanWord(String word) {
    final normalized = TextNormalizer.normalize(word);
    return normalized.replaceAll(RegExp(r'[^\w\s\u0621-\u064A]'), '');
  }
}
