import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/di/app_providers.dart';
import '../../../dictionary/domain/entities/app_context.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../../domain/entities/economy_volume.dart';
import '../../domain/entities/part5_question.dart';

part 'part5_practice_provider.g.dart';

final class Part5SessionResult {
  const Part5SessionResult({required this.set, required this.selectedAnswers});

  final Part5Set set;
  final List<int?> selectedAnswers; // length == set.questions.length

  int get correctCount {
    int count = 0;
    for (int i = 0; i < set.questions.length; i++) {
      if (selectedAnswers[i] == set.questions[i].correctIndex) count++;
    }
    return count;
  }
}

final class Part5SessionState {
  const Part5SessionState({
    required this.set,
    required this.selectedAnswers,
    required this.isSubmitted,
  });

  final Part5Set set;
  final List<int?> selectedAnswers;
  final bool isSubmitted;

  bool get canSubmit => selectedAnswers.every((a) => a != null);

  Part5SessionState copyWith({List<int?>? selectedAnswers, bool? isSubmitted}) =>
      Part5SessionState(
        set: set,
        selectedAnswers: selectedAnswers ?? this.selectedAnswers,
        isSubmitted: isSubmitted ?? this.isSubmitted,
      );
}

@riverpod
class Part5PracticeNotifier extends _$Part5PracticeNotifier {
  @override
  AsyncValue<Part5SessionState?> build() => const AsyncData(null);

  Future<void> generate({
    required AppContext context,
    required Language targetLanguage,
    required Set<EconomyVolume> volumes,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final set = await ref.read(generatePart5SetUseCaseProvider).execute(
            context: context,
            targetLanguage: targetLanguage,
            volumes: volumes,
          );
      return Part5SessionState(
        set: set,
        selectedAnswers: List<int?>.filled(set.questions.length, null),
        isSubmitted: false,
      );
    });
  }

  void selectAnswer(int questionIndex, int optionIndex) {
    final current = state.valueOrNull;
    if (current == null || current.isSubmitted) return;
    final updated = List<int?>.from(current.selectedAnswers);
    updated[questionIndex] = optionIndex;
    state = AsyncData(current.copyWith(selectedAnswers: updated));
  }

  void submit() {
    final current = state.valueOrNull;
    if (current == null || current.isSubmitted || !current.canSubmit) return;
    state = AsyncData(current.copyWith(isSubmitted: true));
  }

  void reset() => state = const AsyncData(null);
}
