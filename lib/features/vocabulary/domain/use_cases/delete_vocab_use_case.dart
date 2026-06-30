import '../repositories/vocab_repository.dart';

class DeleteVocabUseCase {
  const DeleteVocabUseCase(this._repo);
  final VocabRepository _repo;

  Future<void> execute(String id) => _repo.delete(id);
}
