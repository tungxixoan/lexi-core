/// Describes one blank as a range in a sentence's whitespace-tokenized word
/// list: words at indices [startWordIndex, startWordIndex + wordCount) are
/// hidden and must be filled in.
final class BlankSpan {
  const BlankSpan({required this.startWordIndex, required this.wordCount});

  final int startWordIndex;
  final int wordCount;
}
