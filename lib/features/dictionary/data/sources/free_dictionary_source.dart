import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/utils/input_detector.dart';
import '../../domain/entities/lookup_result.dart';
import '../../domain/repositories/dictionary_repository.dart';

class FreeDictionarySource {
  FreeDictionarySource(this._client);

  final http.Client _client;
  static const _baseUrl = 'https://api.dictionaryapi.dev/api/v2/entries/en/';

  Future<WordPhraseResult> lookup(String word) async {
    final response = await _client.get(Uri.parse('$_baseUrl$word'));
    if (response.statusCode != 200) {
      throw DictionaryException('Word not found: $word');
    }
    final list = jsonDecode(response.body) as List;
    return _parse(list.first as Map<String, dynamic>, word);
  }

  WordPhraseResult _parse(Map<String, dynamic> data, String word) {
    final phonetics = (data['phonetics'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        [];
    final ipa =
        phonetics.isNotEmpty ? (phonetics.first['text'] as String?) ?? '' : '';

    final meanings =
        (data['meanings'] as List?)?.whereType<Map<String, dynamic>>() ?? [];
    String meaning = '';
    final examples = <String>[];
    final synonyms = <String>[];

    for (final m in meanings) {
      synonyms.addAll((m['synonyms'] as List?)?.cast<String>() ?? const []);
      final defs = (m['definitions'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          [];
      for (final d in defs) {
        if (meaning.isEmpty) meaning = (d['definition'] as String?) ?? '';
        final ex = d['example'] as String?;
        if (ex != null) examples.add(ex);
        synonyms.addAll((d['synonyms'] as List?)?.cast<String>() ?? const []);
      }
    }

    return WordPhraseResult(
      headword: word,
      inputType: InputDetector.detect(word),
      ipa: ipa,
      meaning: meaning,
      definition: meaning,
      synonyms: synonyms.toSet().take(4).toList(),
      examples: examples.take(3).toList(),
      suggestedTopics: const [],
    );
  }
}
