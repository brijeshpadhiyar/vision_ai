import 'dart:math' as math;

/// Configurable string and phonetic similarity algorithms tailored for
/// multilingual English, Hindi, Gujarati, and Hinglish command & contact resolution.
abstract final class PhoneticAlgorithms {
  /// Returns Optimal String Alignment (Damerau-Levenshtein) similarity in `[0.0, 1.0]`.
  ///
  /// Handles insertions, deletions, substitutions, and adjacent character transpositions.
  static double damerauLevenshteinSimilarity(String rawA, String rawB) {
    final a = rawA.trim().toLowerCase();
    final b = rawB.trim().toLowerCase();
    if (a == b) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;

    final maxLen = math.max(a.length, b.length);
    final dist = damerauLevenshteinDistance(a, b);
    return (1.0 - (dist / maxLen)).clamp(0.0, 1.0);
  }

  /// Computes Damerau-Levenshtein edit distance between [a] and [b].
  static int damerauLevenshteinDistance(String a, String b) {
    final m = a.length;
    final n = b.length;
    if (m == 0) return n;
    if (n == 0) return m;

    final d = List<List<int>>.generate(
      m + 1,
      (_) => List<int>.filled(n + 1, 0),
      growable: false,
    );

    for (var i = 0; i <= m; i++) {
      d[i][0] = i;
    }
    for (var j = 0; j <= n; j++) {
      d[0][j] = j;
    }

    for (var i = 1; i <= m; i++) {
      for (var j = 1; j <= n; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        var val = math.min(
          math.min(d[i - 1][j] + 1, d[i][j - 1] + 1),
          d[i - 1][j - 1] + cost,
        );
        if (i > 1 &&
            j > 1 &&
            a.codeUnitAt(i - 1) == b.codeUnitAt(j - 2) &&
            a.codeUnitAt(i - 2) == b.codeUnitAt(j - 1)) {
          val = math.min(val, d[i - 2][j - 2] + cost);
        }
        d[i][j] = val;
      }
    }

    return d[m][n];
  }

  /// Returns Jaro-Winkler similarity in `[0.0, 1.0]` favoring common prefixes.
  static double jaroWinklerSimilarity(String rawA, String rawB) {
    final a = rawA.trim().toLowerCase();
    final b = rawB.trim().toLowerCase();
    if (a == b) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;

    final matchWindow = math.max(0, (math.max(a.length, b.length) ~/ 2) - 1);
    final aMatched = List<bool>.filled(a.length, false);
    final bMatched = List<bool>.filled(b.length, false);

    var matches = 0;
    for (var i = 0; i < a.length; i++) {
      final start = math.max(0, i - matchWindow);
      final end = math.min(i + matchWindow + 1, b.length);
      for (var j = start; j < end; j++) {
        if (bMatched[j] || a[i] != b[j]) continue;
        aMatched[i] = true;
        bMatched[j] = true;
        matches++;
        break;
      }
    }

    if (matches == 0) return 0.0;

    var transpositions = 0;
    var k = 0;
    for (var i = 0; i < a.length; i++) {
      if (!aMatched[i]) continue;
      while (!bMatched[k]) {
        k++;
      }
      if (a[i] != b[k]) transpositions++;
      k++;
    }

    final jaro =
        ((matches / a.length) +
            (matches / b.length) +
            ((matches - transpositions / 2.0) / matches)) /
        3.0;

    var prefix = 0;
    final maxPrefix = math.min(4, math.min(a.length, b.length));
    while (prefix < maxPrefix && a[prefix] == b[prefix]) {
      prefix++;
    }

    return (jaro + prefix * 0.1 * (1.0 - jaro)).clamp(0.0, 1.0);
  }

  /// Produces a compact English Metaphone-style consonant code for ASCII words.
  ///
  /// Should only be applied to English/Latin tokens — never blindly to Indic words.
  static String englishPhoneticCode(String input) {
    var clean = input.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    if (clean.isEmpty) return '';

    clean = clean
        .replaceAll('ph', 'f')
        .replaceAll('kn', 'n')
        .replaceAll('gn', 'n')
        .replaceAll('wr', 'r')
        .replaceAll('wh', 'w')
        .replaceAll('sh', 'S')
        .replaceAll('ch', 'X')
        .replaceAll('th', 'T')
        .replaceAll(RegExp(r'c(?=[eiy])'), 's')
        .replaceAll('c', 'k')
        .replaceAll('q', 'k')
        .replaceAll('x', 'ks')
        .replaceAll('z', 's');

    final first = clean[0];
    final rest = clean.substring(1).replaceAll(RegExp(r'[aeiouyh]'), '');
    return _dedupeAdjacent('$first$rest').toUpperCase();
  }

  /// Indic-aware phonetic skeleton for Romanized Hindi/Gujarati/Indian-English names
  /// (e.g., "Shohil" -> "sl", "Soel" -> "sl", "Khatri" -> "ktr").
  ///
  /// Normalizes aspirated consonants (`kh/k`, `sh/s`, `bh/b`, `dh/d`, `th/t`,
  /// `ph/f`, `jh/j`, `w/v`), strips non-leading vowels + breathy `h`, and keeps
  /// consonant skeleton resilient to common STT spelling divergence.
  static String indicRomanConsonantSkeleton(String input) {
    var s = input.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    if (s.isEmpty) return '';

    // Collapse double letters & Indic aspirated digraphs first
    s = _dedupeAdjacent(s)
        .replaceAll('sh', 's')
        .replaceAll('chh', 'c')
        .replaceAll('ch', 'c')
        .replaceAll('kh', 'k')
        .replaceAll('gh', 'g')
        .replaceAll('jh', 'j')
        .replaceAll('th', 't')
        .replaceAll('dh', 'd')
        .replaceAll('ph', 'f')
        .replaceAll('bh', 'b')
        .replaceAll('q', 'k')
        .replaceAll('w', 'v')
        .replaceAll('z', 'j')
        .replaceAll(RegExp(r'c(?=[eiy])'), 's')
        .replaceAll('c', 'k');

    // Remove remaining non-initial 'h' (e.g. Shohil -> Soil -> sl) and vowels
    final buffer = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final ch = s[i];
      final isVowelOrBreath =
          ch == 'a' ||
          ch == 'e' ||
          ch == 'i' ||
          ch == 'o' ||
          ch == 'u' ||
          ch == 'y' ||
          ch == 'h';
      if (isVowelOrBreath) {
        // Retain leading vowel marker only if word starts with vowel & next char isn't skipped
        if (i == 0 && ch != 'h') {
          buffer.write('a');
        }
        continue;
      }
      buffer.write(ch);
    }

    return _dedupeAdjacent(buffer.toString());
  }

  /// Vowel-softened phonetic form retaining normalized vowel classes (`a/e/i/o/u`)
  /// alongside consonant equivalences for balanced candidate ranking.
  static String indicPhoneticForm(String input) {
    var s = input.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    if (s.isEmpty) return '';

    s = s
        .replaceAll('sh', 's')
        .replaceAll('kh', 'k')
        .replaceAll('gh', 'g')
        .replaceAll('ph', 'f')
        .replaceAll('bh', 'b')
        .replaceAll('th', 't')
        .replaceAll('dh', 'd')
        .replaceAll('jh', 'j')
        .replaceAll('aa', 'a')
        .replaceAll('ee', 'i')
        .replaceAll('oo', 'u')
        .replaceAll('ai', 'e')
        .replaceAll('au', 'o')
        .replaceAll('w', 'v')
        .replaceAll('z', 'j')
        .replaceAll('q', 'k');

    // Drop intervocalic silent 'h' (e.g. shohil -> soil)
    s = s.replaceAll(RegExp(r'([aeiou])h'), r'$1');
    return _dedupeAdjacent(s);
  }

  static String _dedupeAdjacent(String input) {
    if (input.length <= 1) return input;
    final out = StringBuffer()..write(input[0]);
    for (var i = 1; i < input.length; i++) {
      if (input[i] != input[i - 1]) {
        out.write(input[i]);
      }
    }
    return out.toString();
  }
}
