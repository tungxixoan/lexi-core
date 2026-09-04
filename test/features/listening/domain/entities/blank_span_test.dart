import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/listening/domain/entities/blank_span.dart';

void main() {
  test('holds startWordIndex and wordCount', () {
    const span = BlankSpan(startWordIndex: 3, wordCount: 2);
    expect(span.startWordIndex, 3);
    expect(span.wordCount, 2);
  });

  test('toJson / fromJson round-trips (keys match web BlankSpan)', () {
    const span = BlankSpan(startWordIndex: 3, wordCount: 2);
    final json = span.toJson();
    expect(json, {'startWordIndex': 3, 'wordCount': 2});
    final decoded = BlankSpan.fromJson(json);
    expect(decoded.startWordIndex, 3);
    expect(decoded.wordCount, 2);
  });
}
