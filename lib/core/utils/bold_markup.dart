/// A minimal inline-markup parser for Knowledge Note bodies.
///
/// The grammar is deliberately tiny — NOT Markdown:
/// * `\n\n` (one or more blank lines) splits paragraphs; each paragraph is
///   trimmed and empty paragraphs are dropped.
/// * `**x**` (x non-empty, no nested `**`, non-greedy) marks a bold run.
/// * Everything else is literal — a lone `**` renders as the two characters,
///   and `*` / `_` / `#` are plain text. No nesting, italics, or links.
library;

/// One styled span of text within a paragraph.
class TextRun {
  const TextRun(this.text, {this.bold = false});

  final String text;
  final bool bold;

  @override
  bool operator ==(Object other) =>
      other is TextRun && other.text == text && other.bold == bold;

  @override
  int get hashCode => Object.hash(text, bold);

  @override
  String toString() =>
      'TextRun("${text.replaceAll('\n', r'\n')}", bold: $bold)';
}

/// Parses [source] into paragraphs of [TextRun]s. See the library doc comment
/// for the grammar. Returns an empty list for blank input.
List<List<TextRun>> parseBoldMarkup(String source) {
  final paragraphs = source
      .split(RegExp(r'\n\n+'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty);

  final result = <List<TextRun>>[];
  for (final para in paragraphs) {
    result.add(_runsForParagraph(para));
  }
  return result;
}

final _boldPattern = RegExp(r'\*\*([^*]+?)\*\*');

List<TextRun> _runsForParagraph(String para) {
  final runs = <TextRun>[];
  var cursor = 0;
  for (final m in _boldPattern.allMatches(para)) {
    if (m.start > cursor) {
      runs.add(TextRun(para.substring(cursor, m.start)));
    }
    runs.add(TextRun(m.group(1)!, bold: true));
    cursor = m.end;
  }
  if (cursor < para.length) {
    runs.add(TextRun(para.substring(cursor)));
  }
  // Drop empty plain runs (e.g. the "" before a leading match).
  runs.removeWhere((r) => !r.bold && r.text.isEmpty);
  return runs.isEmpty ? [const TextRun('')] : runs;
}
