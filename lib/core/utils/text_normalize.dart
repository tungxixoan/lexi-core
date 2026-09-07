// Vietnamese diacritic folding: each accented form → its base ASCII letter.
const Map<String, String> _diacriticFolds = {
  'a': 'áàảãạăắằẳẵặâấầẩẫậ',
  'e': 'éèẻẽẹêếềểễệ',
  'i': 'íìỉĩị',
  'o': 'óòỏõọôốồổỗộơớờởỡợ',
  'u': 'úùủũụưứừửữự',
  'y': 'ýỳỷỹỵ',
  'd': 'đ',
};

String _foldChar(String lower) {
  for (final entry in _diacriticFolds.entries) {
    if (entry.value.contains(lower)) return entry.key;
  }
  return lower;
}

/// Lowercase, fold Vietnamese diacritics (and đ→d), turn every non
/// `[a-z0-9]` char into a space, collapse whitespace, trim. Shared by the
/// Knowledge search box and the duplicate-check tokeniser so "câu điều
/// kiện" and "cau dieu kien" match.
String normalizeForSearch(String input) {
  final folded = StringBuffer();
  for (final rune in input.toLowerCase().runes) {
    final ch = String.fromCharCode(rune);
    folded.write(_foldChar(ch));
  }
  return folded
      .toString()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();
}
