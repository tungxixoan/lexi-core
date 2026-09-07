import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/utils/text_normalize.dart';

void main() {
  test('folds Vietnamese diacritics and đ', () {
    expect(normalizeForSearch('Câu điều kiện'), 'cau dieu kien');
    expect(normalizeForSearch('ĐIỀU'), 'dieu');
  });

  test('lowercases and strips punctuation to spaces, collapses whitespace', () {
    expect(normalizeForSearch('Present  Perfect!!  (tense)'),
        'present perfect tense');
  });

  test('empty / punctuation-only input', () {
    expect(normalizeForSearch('   '), '');
    expect(normalizeForSearch('***'), '');
  });

  test('keeps digits', () {
    expect(normalizeForSearch('loại 2 và 3'), 'loai 2 va 3');
  });
}
