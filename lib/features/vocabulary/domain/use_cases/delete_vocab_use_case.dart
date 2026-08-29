import '../../../dictionary/domain/entities/language.dart';
import '../repositories/vocab_repository.dart';

class DeleteVocabUseCase {
  const DeleteVocabUseCase(this._repo);
  final VocabRepository _repo;

  Future<void> execute(String id, {required Language language}) =>
      _repo.delete(id, language: language);
}
