import 'dart:math';
import '../entities/blank_span.dart';
import '../entities/dictation_difficulty.dart';

/// Computes which word(s) of an already-generated dictation sentence should
/// be blanked out, based on the chosen difficulty. Pure and deterministic
/// given a [random] — no AI, no I/O, no dependency on how the sentence was
/// generated.
class SelectDictationBlanksUseCase {
  const SelectDictationBlanksUseCase();

  List<BlankSpan> execute(
    String sentence,
    DictationDifficulty difficulty, {
    Random? random,
  }) {
    final rand = random ?? Random();
    final wordCount = _wordCount(sentence);

    return switch (difficulty) {
      DictationDifficulty.hard => const [],
      DictationDifficulty.easy => _selectEasyBlanks(wordCount, rand),
      DictationDifficulty.medium => _selectMediumBlanks(wordCount, rand),
    };
  }

  int _wordCount(String sentence) =>
      sentence.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

  List<BlankSpan> _selectEasyBlanks(int wordCount, Random rand) {
    if (wordCount <= 1) {
      return [const BlankSpan(startWordIndex: 0, wordCount: 1)];
    }
    final enforceNonAdjacent = wordCount >= 6;
    final minIndex = enforceNonAdjacent ? 1 : 0;
    final maxIndex = enforceNonAdjacent ? wordCount - 2 : wordCount - 1;
    final range = maxIndex - minIndex + 1;

    int first = minIndex + rand.nextInt(range);
    int second = minIndex + rand.nextInt(range);

    var attempts = 0;
    // Non-adjacency is only required when wordCount >= 6 (see global
    // constraints doc); for shorter sentences any 2 distinct indices are
    // acceptable and adjacency is not avoided. Always avoid picking the
    // exact same index twice.
    while ((second == first ||
            (enforceNonAdjacent && (second - first).abs() < 2)) &&
        attempts < 30) {
      second = minIndex + rand.nextInt(range);
      attempts++;
    }
    if (second == first) {
      second = first == maxIndex ? first - 1 : first + 1;
    }

    final indices = <int>{first, second}.toList()..sort();
    return indices
        .map((i) => BlankSpan(startWordIndex: i, wordCount: 1))
        .toList();
  }

  List<BlankSpan> _selectMediumBlanks(int wordCount, Random rand) {
    if (wordCount <= 3) {
      return [BlankSpan(startWordIndex: 0, wordCount: wordCount)];
    }
    final spanLength = (wordCount * 0.35).round().clamp(2, wordCount - 2);
    final maxStartIndexInclusive = wordCount - spanLength - 1;
    final startIndex = maxStartIndexInclusive > 1
        ? 1 + rand.nextInt(maxStartIndexInclusive)
        : 1;
    return [BlankSpan(startWordIndex: startIndex, wordCount: spanLength)];
  }
}
