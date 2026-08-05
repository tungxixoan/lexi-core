import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/utils/web_text_scale.dart';

void main() {
  test('returns the style unchanged outside web (kIsWeb is false under flutter test)', () {
    const style = TextStyle(fontSize: 16);
    expect(webScaled(style), same(style));
  });
}
