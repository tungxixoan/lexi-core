import '../../../vocabulary/domain/entities/vocab_record.dart';
import '../../data/sources/exercise_generator_source.dart';
import '../entities/exercise.dart';

class GenerateExerciseUseCase {
  const GenerateExerciseUseCase(this._source);
  final ExerciseGeneratorSource _source;

  Future<Exercise> execute(VocabRecord record) async {
    try {
      return await _source.generate(record);
    } catch (_) {
      return FlashcardExercise(vocabRecord: record);
    }
  }
}
