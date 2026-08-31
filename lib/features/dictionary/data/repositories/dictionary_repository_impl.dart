import '../../../../core/utils/input_detector.dart';
import '../../domain/entities/input_type.dart';
import '../../domain/entities/language.dart';
import '../../domain/entities/lookup_result.dart';
import '../../domain/repositories/dictionary_repository.dart';
import '../sources/free_dictionary_source.dart';
import '../sources/gemini_dictionary_source.dart';

class DictionaryRepositoryImpl implements DictionaryRepository {
  const DictionaryRepositoryImpl({
    required this.geminiSource,
    required this.freeDictionarySource,
  });

  final GeminiDictionarySource geminiSource;
  final FreeDictionarySource freeDictionarySource;

  @override
  Future<LookupResult> lookup({
    required String query,
    required Language targetLanguage,
    required bool aiEnabled,
  }) async {
    final inputType = InputDetector.detect(query);

    if (aiEnabled) {
      return geminiSource.lookup(
        query: query,
        inputType: inputType,
        targetLanguage: targetLanguage,
      );
    }

    if (targetLanguage.requiresAi) {
      throw DictionaryException(
        'AI must be enabled for ${targetLanguage.label} lookups.',
      );
    }

    if (inputType == InputType.sentence) {
      throw const DictionaryException(
        'AI must be enabled to translate sentences.',
      );
    }

    return freeDictionarySource.lookup(query);
  }
}
