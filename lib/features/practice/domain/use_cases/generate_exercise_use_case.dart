import '../../../vocabulary/domain/entities/vocab_record.dart';
import '../../data/sources/exercise_generator_source.dart';
import '../entities/exercise.dart';

class GenerateExerciseUseCase {
  const GenerateExerciseUseCase(this._source);
  final ExerciseGeneratorSource _source;

  Future<Exercise> execute(VocabRecord record, {required bool aiEnabled}) async {
    if (!aiEnabled) return FlashcardExercise(vocabRecord: record);
    try {
      return await _source.generate(record);
    } catch (_) {
      return FlashcardExercise(vocabRecord: record);
    }
  }
}
