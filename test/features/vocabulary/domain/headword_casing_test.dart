import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/vocabulary/domain/headword_casing.dart';

void main() {
  const cases = {
    'follow up': 'Follow up',
    'Follow up': 'Follow up',
    'TOEIC': 'TOEIC',
    'iPhone': 'IPhone',
    '3D printing': '3D printing',
    'đẹp': 'Đẹp',
    '': '',
  };
  cases.forEach((input, expected) {
    test('capitalizeHeadword("$input") == "$expected"', () {
      expect(capitalizeHeadword(input), expected);
    });
  });
}
