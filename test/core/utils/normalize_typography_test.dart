import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/utils/normalize_typography.dart';

void main() {
  test('straightens curly single quotes and apostrophes', () {
    expect(normalizeTypography('it\u2019s \u2018here\u2019'), "it's 'here'");
  });
  test('straightens curly double quotes and guillemets', () {
    expect(normalizeTypography('\u201Cquote\u201D \u00ABx\u00BB'), '"quote" "x"');
  });
  test('expands the ellipsis character', () {
    expect(normalizeTypography('wait\u2026'), 'wait...');
  });
  test('collapses dashes to a hyphen', () {
    expect(normalizeTypography('a \u2013 b \u2014 c'), 'a - b - c');
  });
  test('replaces non-breaking, thin, and narrow spaces', () {
    expect(normalizeTypography('a\u00A0b\u2009c\u202Fd'), 'a b c d');
  });
  test('straightens prime and double-prime', () {
    expect(normalizeTypography('5\u2032 6\u2033'), '5\' 6"');
  });
  test('leaves plain ASCII untouched', () {
    expect(normalizeTypography('The cat sat. It\'s 5-6 "ok".'),
        'The cat sat. It\'s 5-6 "ok".');
  });
  test('returns an empty string unchanged', () {
    expect(normalizeTypography(''), '');
  });
}
