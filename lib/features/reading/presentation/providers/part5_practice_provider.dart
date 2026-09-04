import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/di/app_providers.dart';
import '../../../dictionary/domain/entities/app_context.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../../domain/entities/economy_volume.dart';
import '../../domain/entities/part5_question.dart';

part 'part5_practice_provider.g.dart';

final class Part5SessionResult {
  const Part5SessionResult({
    required this.set,
    required this.selectedAnswers,
    this.reusedFromId,
    this.generationFilters,
  });

  final Part5Set set;
  final List<int?> selectedAnswers; // length == set.questions.length

  /// Non-null when this session was started from a saved exercise — the result
  /// screen uses it to hide "Lưu bài" and to exclude the set on "Bài khác".
  final String? reusedFromId;

  /// The raw generation-filter map the session was generated with, threaded to
  /// the result screen's "Lưu bài" action.
  final Map<String, dynamic>? generationFilters;

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
    this.reusedFromId,
    this.generationFilters,
  });

  final Part5Set set;
  final List<int?> selectedAnswers;
  final bool isSubmitted;

  /// Non-null when this session was started from a saved exercise (via
  /// [Part5PracticeNotifier.loadSaved]); carried onto [Part5SessionResult].
  final String? reusedFromId;

  /// The raw generation-filter map the set was generated with; carried onto
  /// [Part5SessionResult] for "Lưu bài".
  final Map<String, dynamic>? generationFilters;

  bool get canSubmit => selectedAnswers.every((a) => a != null);

  Part5SessionState copyWith({List<int?>? selectedAnswers, bool? isSubmitted}) =>
      Part5SessionState(
        set: set,
        selectedAnswers: selectedAnswers ?? this.selectedAnswers,
        isSubmitted: isSubmitted ?? this.isSubmitted,
        reusedFromId: reusedFromId,
        generationFilters: generationFilters,
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
    Map<String, dynamic>? generationFilters,
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
        generationFilters: generationFilters,
      );
    });
  }

  /// Starts a session from a pre-built [set], bypassing the AI. [savedId] is the
  /// id of the saved exercise it came from (so the result screen can hide "Lưu
  /// bài" and exclude it on "Bài khác"); [generationFilters] is the raw filter
  /// map to thread through to "Lưu bài".
  void loadSaved(
    Part5Set set, {
    String? savedId,
    Map<String, dynamic>? generationFilters,
  }) {
    state = AsyncData(Part5SessionState(
      set: set,
      selectedAnswers: List<int?>.filled(set.questions.length, null),
      isSubmitted: false,
      reusedFromId: savedId,
      generationFilters: generationFilters,
    ));
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
