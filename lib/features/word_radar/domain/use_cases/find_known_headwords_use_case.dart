import '../../../dictionary/domain/entities/language.dart';
import '../../../vocabulary/domain/repositories/vocab_repository.dart';

class FindKnownHeadwordsUseCase {
  const FindKnownHeadwordsUseCase(this._repo);
  final VocabRepository _repo;

  Future<List<String>> execute({
    required String text,
    required Language language,
  }) async {
    final records = await _repo.getAll(language: language);
    final lowerText = text.toLowerCase();
    final matches = <String>{};
    for (final record in records) {
      if (lowerText.contains(record.headword.toLowerCase())) {
        matches.add(record.headword);
      }
    }
    return matches.toList();
  }
}
