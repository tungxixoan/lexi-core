import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/bloom/bloom.dart';

void main() {
  test('barrel exposes the core Bloom symbols', () {
    expect(BloomButtonVariant.values.length, 5);
    expect(BloomChipStyle.values.length, 4);
  });
}
