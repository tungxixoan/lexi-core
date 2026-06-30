import '../../../dictionary/domain/entities/input_type.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../entities/vocab_record.dart';
import '../repositories/vocab_repository.dart';

class GetVocabListUseCase {
  const GetVocabListUseCase(this._repo);
  final VocabRepository _repo;

  Future<List<VocabRecord>> execute({
    String? topicId,
    InputType? inputType,
    Language? language,
  }) =>
      _repo.getAll(topicId: topicId, inputType: inputType, language: language);
}
