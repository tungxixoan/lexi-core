import '../entities/vocab_record.dart';
import '../repositories/vocab_repository.dart';

class UpdateVocabUseCase {
  const UpdateVocabUseCase(this._repo);
  final VocabRepository _repo;

  Future<void> execute(VocabRecord record) {
    if (record.topicIds.length > 2) {
      throw const VocabException('A word can have at most 2 topic tags.');
    }
    return _repo.update(record.copyWith(updatedAt: DateTime.now()));
  }
}
