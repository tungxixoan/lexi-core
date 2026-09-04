/// Describes one blank as a range in a sentence's whitespace-tokenized word
/// list: words at indices [startWordIndex, startWordIndex + wordCount) are
/// hidden and must be filled in.
final class BlankSpan {
  const BlankSpan({required this.startWordIndex, required this.wordCount});

  final int startWordIndex;
  final int wordCount;

  /// Keys match apps/web/src/lib/dictation.ts's `BlankSpan`.
  Map<String, dynamic> toJson() => {
        'startWordIndex': startWordIndex,
        'wordCount': wordCount,
      };

  factory BlankSpan.fromJson(Map<String, dynamic> json) => BlankSpan(
        startWordIndex: json['startWordIndex'] as int,
        wordCount: json['wordCount'] as int,
      );
}
