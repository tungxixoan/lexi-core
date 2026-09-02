import '../../../dictionary/domain/entities/input_type.dart';
import '../entities/vocab_record.dart';
import '../headword_casing.dart';
import '../repositories/vocab_repository.dart';

class SaveVocabUseCase {
  const SaveVocabUseCase(this._repo);
  final VocabRepository _repo;

  Future<void> execute(VocabRecord record) async {
    final normalized = record.copyWith(headword: capitalizeHeadword(record.headword));
    if (normalized.inputType == InputType.sentence) {
      throw const VocabException('Sentences cannot be saved to Vocabulary Bank.');
    }
    if (normalized.topicIds.length > 2) {
      throw const VocabException('A word can have at most 2 topic tags.');
    }
    final exists = await _repo.existsByHeadword(normalized.headword, normalized.targetLanguage);
    if (exists) {
      throw VocabException('"${normalized.headword}" is already in your Vocabulary Bank.');
    }
    return _repo.save(normalized);
  }
}
