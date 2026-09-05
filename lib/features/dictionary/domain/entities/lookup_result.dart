// lib/features/dictionary/domain/entities/lookup_result.dart
import '../../../vocabulary/domain/entities/cefr_level.dart';
import 'input_type.dart';

sealed class LookupResult {
  const LookupResult();
}

final class WordPhraseResult extends LookupResult {
  const WordPhraseResult({
    required this.headword,
    required this.inputType,
    required this.ipa,
    required this.meaning,
    required this.examples,
    required this.suggestedTopics,
    this.definition = '',
    this.synonyms = const [],
    this.cefrLevel,
  });

  final String headword;
  final InputType inputType; // word or phrase only — never sentence
  final String ipa;
  final String meaning;
  final List<String> examples;
  final List<String> suggestedTopics;
  final String definition; // English definition (optional)
  final List<String> synonyms;
  final CEFRLevel? cefrLevel; // AI-sourced level, when available
}

final class SentenceResult extends LookupResult {
  const SentenceResult({
    required this.original,
    required this.translation,
  });

  final String original;
  final String translation;
}
