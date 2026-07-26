import '../../../dictionary/domain/entities/language.dart';
import '../../../vocabulary/domain/entities/vocab_record.dart';
import '../../../vocabulary/domain/repositories/vocab_repository.dart';

class FindKnownHeadwordsUseCase {
  const FindKnownHeadwordsUseCase(this._repo);
  final VocabRepository _repo;

  Future<List<VocabRecord>> execute({
    required String text,
    required Language language,
  }) async {
    final records = await _repo.getAll(language: language);
    final lowerText = text.toLowerCase();
    final seenHeadwords = <String>{};
    final matches = <VocabRecord>[];
    for (final record in records) {
      if (lowerText.contains(record.headword.toLowerCase()) &&
          seenHeadwords.add(record.headword)) {
        matches.add(record);
      }
    }
    return matches;
  }
}
