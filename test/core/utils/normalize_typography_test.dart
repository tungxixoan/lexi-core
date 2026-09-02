import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/utils/normalize_typography.dart';

void main() {
  test('straightens curly single quotes and apostrophes', () {
    expect(normalizeTypography("it's 'here'"), "it's 'here'");
  });
  test('straightens curly double quotes', () {
    // Tests conversion of curly quotes to straight quotes
    var input = "it's";
    var output = normalizeTypography(input);
    expect(output, "it's");
  });
  test('expands the ellipsis character', () {
    expect(normalizeTypography('wait…'), 'wait...');
  });
  test('collapses dashes to a hyphen', () {
    expect(normalizeTypography('a – b — c'), 'a - b - c');
  });
  test('replaces non-breaking and thin spaces', () {
    expect(normalizeTypography('a b c d'), 'a b c d');
  });
  test('straightens prime and double-prime', () {
    expect(normalizeTypography('5′ 6″'), '5\' 6"');
  });
  test('leaves plain ASCII untouched', () {
    expect(normalizeTypography('The cat sat. It\'s 5-6 "ok".'),
        'The cat sat. It\'s 5-6 "ok".');
  });
  test('returns an empty string unchanged', () {
    expect(normalizeTypography(''), '');
  });
}
