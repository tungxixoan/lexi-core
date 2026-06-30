import '../repositories/vocab_repository.dart';

class DeleteTopicUseCase {
  const DeleteTopicUseCase(this._repo);
  final VocabRepository _repo;

  Future<void> execute(String topicId, {required bool isPredefined}) {
    if (isPredefined) {
      throw const VocabException('Predefined topics cannot be deleted.');
    }
    return _repo.deleteTopic(topicId);
  }
}
