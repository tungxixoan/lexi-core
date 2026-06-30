import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:lexi_core/features/dictionary/data/sources/free_dictionary_source.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/repositories/dictionary_repository.dart';

import 'free_dictionary_source_test.mocks.dart';

@GenerateMocks([http.Client])
void main() {
  late MockClient mockClient;
  late FreeDictionarySource source;

  setUp(() {
    mockClient = MockClient();
    source = FreeDictionarySource(mockClient);
  });

  const successJson = '''[{
    "word": "follow",
    "phonetics": [{"text": "/ˈfɒl.oʊ/"}],
    "meanings": [{
      "partOfSpeech": "verb",
      "definitions": [{
        "definition": "Go or come after.",
        "example": "She followed him into the house."
      }]
    }]
  }]''';

  test('parses word, IPA, meaning, and examples from API response', () async {
    when(mockClient.get(any)).thenAnswer(
      (_) async => http.Response.bytes(
        utf8.encode(successJson),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );

    final result = await source.lookup('follow');

    expect(result.headword, 'follow');
    expect(result.ipa, '/ˈfɒl.oʊ/');
    expect(result.meaning, 'Go or come after.');
    expect(result.examples, ['She followed him into the house.']);
    expect(result.inputType, InputType.word);
  });

  test('throws DictionaryException on non-200 response', () async {
    when(mockClient.get(any)).thenAnswer(
      (_) async => http.Response('Not Found', 404),
    );

    expect(
      () => source.lookup('xyznotaword'),
      throwsA(isA<DictionaryException>()),
    );
  });
}
