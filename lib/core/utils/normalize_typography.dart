// Generated passage text sometimes comes back with "smart" punctuation
// (curly quotes, ellipsis, en/em dashes, non-breaking spaces). The Đọc & gõ
// typing flow compares what the user types against this text, and a normal
// keyboard produces the ASCII forms — so the raw smart characters are
// un-typable. Normalize them to ASCII before the text is ever shown.
String normalizeTypography(String s) {
  return s
      .replaceAll(RegExp('[''‚‛′]'), "'")
      .replaceAll(RegExp('[""„‟«»″]'), '"')
      .replaceAll('…', '...')
      .replaceAll(RegExp('[–—‒―]'), '-')
      .replaceAll(RegExp('[   ]'), ' ');
}
