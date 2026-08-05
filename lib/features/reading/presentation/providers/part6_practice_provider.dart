import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/di/app_providers.dart';
import '../../../dictionary/domain/entities/app_context.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../../domain/entities/economy_volume.dart';
import '../../domain/entities/part6_passage.dart';

part 'part6_practice_provider.g.dart';

final class Part6SessionResult {
  const Part6SessionResult({required this.set, required this.selectedAnswers});

  final Part6Set set;
  final List<int?> selectedAnswers; // flat, passage-major order (see Part6SessionState.flatIndex)

  int get correctCount {
    int count = 0;
    for (var p = 0; p < set.passages.length; p++) {
      final questions = set.passages[p].questions;
      for (var q = 0; q < questions.length; q++) {
        final flat = Part6SessionState.flatIndex(p, q);
        if (selectedAnswers[flat] == questions[q].correctIndex) count++;
      }
    }
    return count;
  }
}

final class Part6SessionState {
  const Part6SessionState({
    required this.set,
    required this.selectedAnswers,
    required this.isSubmitted,
  });

  final Part6Set set;
  final List<int?> selectedAnswers;
  final bool isSubmitted;

  bool get canSubmit => selectedAnswers.every((a) => a != null);

  /// Flat index for the [questionIndex]-th blank of [passageIndex] — every
  /// passage always has exactly 4 blanks (enforced by Part6Source's prompt).
  static int flatIndex(int passageIndex, int questionIndex) =>
      passageIndex * 4 + questionIndex;

  Part6SessionState copyWith({List<int?>? selectedAnswers, bool? isSubmitted}) =>
      Part6SessionState(
        set: set,
        selectedAnswers: selectedAnswers ?? this.selectedAnswers,
        isSubmitted: isSubmitted ?? this.isSubmitted,
      );
}

@riverpod
class Part6PracticeNotifier extends _$Part6PracticeNotifier {
  @override
  AsyncValue<Part6SessionState?> build() => const AsyncData(null);

  Future<void> generate({
    required AppContext context,
    required Language targetLanguage,
    required Set<EconomyVolume> volumes,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final set = await ref.read(generatePart6SetUseCaseProvider).execute(
            context: context,
            targetLanguage: targetLanguage,
            volumes: volumes,
          );
      final totalQuestions = set.passages.fold(0, (sum, p) => sum + p.questions.length);
      return Part6SessionState(
        set: set,
        selectedAnswers: List<int?>.filled(totalQuestions, null),
        isSubmitted: false,
      );
    });
  }

  void selectAnswer(int passageIndex, int questionIndex, int optionIndex) {
    final current = state.valueOrNull;
    if (current == null || current.isSubmitted) return;
    final updated = List<int?>.from(current.selectedAnswers);
    updated[Part6SessionState.flatIndex(passageIndex, questionIndex)] = optionIndex;
    state = AsyncData(current.copyWith(selectedAnswers: updated));
  }

  void submit() {
    final current = state.valueOrNull;
    if (current == null || current.isSubmitted || !current.canSubmit) return;
    state = AsyncData(current.copyWith(isSubmitted: true));
  }

  void reset() => state = const AsyncData(null);
}
