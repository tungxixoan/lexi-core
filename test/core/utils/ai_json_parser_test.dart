import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/utils/ai_json_parser.dart';

void main() {
  test('parses plain valid JSON', () {
    final result = parseAiJsonObject('{"a": 1, "b": "two"}');
    expect(result, {'a': 1, 'b': 'two'});
  });

  test('strips ```json ... ``` markdown code fences', () {
    final result = parseAiJsonObject('```json\n{"a": 1}\n```');
    expect(result, {'a': 1});
  });

  test('strips bare ``` ... ``` code fences without a language tag', () {
    final result = parseAiJsonObject('```\n{"a": 1}\n```');
    expect(result, {'a': 1});
  });

  test('extracts the JSON object when trailing prose follows it', () {
    final result = parseAiJsonObject('{"a": 1}\nNote: this is a great answer!');
    expect(result, {'a': 1});
  });

  test('does not get confused by braces inside string values', () {
    final result =
        parseAiJsonObject('{"meaning": "a symbol like { or }"}\nExtra trailing text');
    expect(result, {'meaning': 'a symbol like { or }'});
  });

  test('throws FormatException when no JSON object can be found at all', () {
    expect(() => parseAiJsonObject('not json at all'), throwsFormatException);
  });
}
