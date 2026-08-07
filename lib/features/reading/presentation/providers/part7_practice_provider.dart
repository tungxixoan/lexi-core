import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/di/app_providers.dart';
import '../../../dictionary/domain/entities/app_context.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../../domain/entities/economy_volume.dart';
import '../../domain/entities/part7_passage.dart';

part 'part7_practice_provider.g.dart';

final class Part7SessionResult {
  const Part7SessionResult({required this.set, required this.selectedAnswers});

  final Part7Set set;
  final List<int?> selectedAnswers; // flat, group-major order (see Part7SessionState.flatIndex)

  int get correctCount {
    int count = 0;
    for (var g = 0; g < set.passageGroups.length; g++) {
      final questions = set.passageGroups[g].questions;
      for (var q = 0; q < questions.length; q++) {
        final flat = Part7SessionState.flatIndex(set.passageGroups, g, q);
        if (selectedAnswers[flat] == questions[q].correctIndex) count++;
      }
    }
    return count;
  }
}

final class Part7SessionState {
  const Part7SessionState({
    required this.set,
    required this.selectedAnswers,
    required this.isSubmitted,
  });

  final Part7Set set;
  final List<int?> selectedAnswers;
  final bool isSubmitted;

  bool get canSubmit => selectedAnswers.every((a) => a != null);

  /// Flat index for the [questionIndex]-th question of [groupIndex], summed
  /// from each preceding group's ACTUAL question count. Single-passage
  /// groups may have 3 or 4 questions — never hardcode a per-group count
  /// here (that was the Part 6 bug this design deliberately avoids).
  static int flatIndex(List<Part7PassageGroup> groups, int groupIndex, int questionIndex) {
    var offset = 0;
    for (var g = 0; g < groupIndex; g++) {
      offset += groups[g].questions.length;
    }
    return offset + questionIndex;
  }

  Part7SessionState copyWith({List<int?>? selectedAnswers, bool? isSubmitted}) =>
      Part7SessionState(
        set: set,
        selectedAnswers: selectedAnswers ?? this.selectedAnswers,
        isSubmitted: isSubmitted ?? this.isSubmitted,
      );
}

@riverpod
class Part7PracticeNotifier extends _$Part7PracticeNotifier {
  @override
  AsyncValue<Part7SessionState?> build() => const AsyncData(null);

  Future<void> generate({
    required AppContext context,
    required Language targetLanguage,
    required Set<EconomyVolume> volumes,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final set = await ref.read(generatePart7SetUseCaseProvider).execute(
            context: context,
            targetLanguage: targetLanguage,
            volumes: volumes,
          );
      final totalQuestions = set.passageGroups.fold(0, (sum, g) => sum + g.questions.length);
      return Part7SessionState(
        set: set,
        selectedAnswers: List<int?>.filled(totalQuestions, null),
        isSubmitted: false,
      );
    });
  }

  void selectAnswer(int groupIndex, int questionIndex, int optionIndex) {
    final current = state.valueOrNull;
    if (current == null || current.isSubmitted) return;
    final updated = List<int?>.from(current.selectedAnswers);
    final flat = Part7SessionState.flatIndex(current.set.passageGroups, groupIndex, questionIndex);
    updated[flat] = optionIndex;
    state = AsyncData(current.copyWith(selectedAnswers: updated));
  }

  void submit() {
    final current = state.valueOrNull;
    if (current == null || current.isSubmitted || !current.canSubmit) return;
    state = AsyncData(current.copyWith(isSubmitted: true));
  }

  void reset() => state = const AsyncData(null);
}
