import '../entities/topic.dart';
import '../repositories/vocab_repository.dart';

class GetTopicsUseCase {
  const GetTopicsUseCase(this._repo);
  final VocabRepository _repo;

  Future<List<Topic>> execute() => _repo.getTopics();
}
