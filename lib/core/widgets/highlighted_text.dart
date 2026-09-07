import 'package:flutter/material.dart';
import '../theme/bloom/bloom.dart';
import '../utils/text_normalize.dart';

/// Highlights each of [highlights] wherever it appears in [text], matching
/// case- and accent-insensitively (via [normalizeForSearch]) but slicing the
/// original [text] so the display keeps its diacritics.
class HighlightedText extends StatelessWidget {
  const HighlightedText({
    super.key,
    required this.text,
    required this.highlights,
    this.style,
    this.highlightStyle,
  });

  final String text;
  final List<String> highlights;
  final TextStyle? style;
  final TextStyle? highlightStyle;

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    final hi = highlightStyle ??
        base.copyWith(
          fontWeight: FontWeight.w700,
          color: context.bloom.accent,
        );

    final terms = highlights
        .map(normalizeForSearch)
        .where((t) => t.isNotEmpty)
        .toList();
    if (terms.isEmpty) return Text(text, style: base);

    // Fold the text the same way, keeping a char-index map back to the
    // original. normalizeForSearch trims/collapses whitespace, so folding a
    // lone separator char yields '' — map that back to a single space so word
    // boundaries survive and multi-word terms still match. Every original char
    // maps to exactly one folded char (letter/digit or space).
    final folded = StringBuffer();
    final map = <int>[]; // folded index -> original index
    for (var i = 0; i < text.length; i++) {
      final f = normalizeForSearch(text[i]);
      final ch = f.isEmpty ? ' ' : f;
      for (var k = 0; k < ch.length; k++) {
        folded.write(ch[k]);
        map.add(i);
      }
    }
    final foldedStr = folded.toString();

    final spans = <TextSpan>[];
    var origCursor = 0;
    var foldedCursor = 0;
    while (foldedCursor < foldedStr.length) {
      int? bestStart;
      int? bestEnd;
      for (final term in terms) {
        final idx = foldedStr.indexOf(term, foldedCursor);
        if (idx >= 0 && (bestStart == null || idx < bestStart)) {
          bestStart = idx;
          bestEnd = idx + term.length;
        }
      }
      if (bestStart == null || bestEnd == null) break;
      final origStart = map[bestStart];
      final origEnd = bestEnd < map.length ? map[bestEnd] : text.length;
      if (origStart > origCursor) {
        spans.add(
          TextSpan(text: text.substring(origCursor, origStart), style: base),
        );
      }
      spans.add(TextSpan(text: text.substring(origStart, origEnd), style: hi));
      origCursor = origEnd;
      foldedCursor = bestEnd;
    }
    if (origCursor < text.length) {
      spans.add(TextSpan(text: text.substring(origCursor), style: base));
    }
    return RichText(
      textScaler: MediaQuery.textScalerOf(context),
      text: TextSpan(children: spans),
    );
  }
}
