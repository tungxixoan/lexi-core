import '../entities/language.dart';
import '../entities/lookup_result.dart';
import '../repositories/dictionary_repository.dart';

class LookupUseCase {
  const LookupUseCase(this._repository);

  final DictionaryRepository _repository;

  Future<LookupResult> execute({
    required String query,
    required Language targetLanguage,
    required bool aiEnabled,
  }) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      throw const DictionaryException('Query cannot be empty.');
    }
    return _repository.lookup(
      query: trimmed,
      targetLanguage: targetLanguage,
      aiEnabled: aiEnabled,
    );
  }
}
