import '../../../dictionary/domain/entities/input_type.dart';
import '../entities/vocab_record.dart';
import '../repositories/vocab_repository.dart';

class SaveVocabUseCase {
  const SaveVocabUseCase(this._repo);
  final VocabRepository _repo;

  Future<void> execute(VocabRecord record) {
    if (record.inputType == InputType.sentence) {
      throw const VocabException('Sentences cannot be saved to Vocabulary Bank.');
    }
    if (record.topicIds.length > 2) {
      throw const VocabException('A word can have at most 2 topic tags.');
    }
    return _repo.save(record);
  }
}
