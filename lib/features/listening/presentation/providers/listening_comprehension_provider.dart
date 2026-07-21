import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/di/app_providers.dart';
import '../../../dictionary/domain/entities/app_context.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../../../vocabulary/domain/entities/cefr_level.dart';
import '../../domain/entities/listening_passage.dart';

part 'listening_comprehension_provider.g.dart';

final class ComprehensionSessionResult {
  const ComprehensionSessionResult({
    required this.passage,
    required this.selectedAnswers,
  });

  final ListeningPassage passage;
  final List<int?> selectedAnswers; // length == passage.questions.length

  int get correctCount {
    int count = 0;
    for (int i = 0; i < passage.questions.length; i++) {
      if (selectedAnswers[i] == passage.questions[i].correctIndex) count++;
    }
    return count;
  }
}

final class ListeningSessionState {
  const ListeningSessionState({
    required this.passage,
    required this.currentTurnIndex,
    required this.isSpeaking,
    required this.playToken,
    required this.selectedAnswers,
    required this.isSubmitted,
  });

  final ListeningPassage passage;
  final int currentTurnIndex;
  final bool isSpeaking;
  final int playToken;
  final List<int?> selectedAnswers;
  final bool isSubmitted;

  ListeningTurn get currentTurn => passage.turns[currentTurnIndex];
  bool get canSubmit => selectedAnswers.every((a) => a != null);

  ListeningSessionState copyWith({
    int? currentTurnIndex,
    bool? isSpeaking,
    int? playToken,
    List<int?>? selectedAnswers,
    bool? isSubmitted,
  }) =>
      ListeningSessionState(
        passage: passage,
        currentTurnIndex: currentTurnIndex ?? this.currentTurnIndex,
        isSpeaking: isSpeaking ?? this.isSpeaking,
        playToken: playToken ?? this.playToken,
        selectedAnswers: selectedAnswers ?? this.selectedAnswers,
        isSubmitted: isSubmitted ?? this.isSubmitted,
      );
}

@riverpod
class ListeningComprehensionNotifier extends _$ListeningComprehensionNotifier {
  @override
  AsyncValue<ListeningSessionState?> build() => const AsyncData(null);

  Future<void> generate({
    required CEFRLevel level,
    required AppContext context,
    required Language targetLanguage,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final passage = await ref
          .read(generateListeningPassageUseCaseProvider)
          .execute(level: level, context: context, targetLanguage: targetLanguage);
      return ListeningSessionState(
        passage: passage,
        currentTurnIndex: 0,
        isSpeaking: false,
        playToken: 0,
        selectedAnswers: List<int?>.filled(passage.questions.length, null),
        isSubmitted: false,
      );
    });
  }

  double _pitchFor(String? speaker) => speaker == 'B' ? 1.3 : 1.0;

  Future<void> playCurrentTurn() async {
    final current = state.valueOrNull;
    if (current == null || current.isSubmitted) return;
    final token = current.playToken + 1;
    state = AsyncData(current.copyWith(isSpeaking: true, playToken: token));
    final turn = current.currentTurn;
    await ref.read(ttsServiceProvider).speak(
          turn.text,
          current.passage.targetLanguage,
          pitch: _pitchFor(turn.speaker),
        );
    final latest = state.valueOrNull;
    if (latest == null || latest.playToken != token) return; // superseded meanwhile
    state = AsyncData(latest.copyWith(isSpeaking: false));
  }

  Future<void> stopPlayback() async {
    final current = state.valueOrNull;
    if (current == null) return;
    await ref.read(ttsServiceProvider).stop();
    final latest = state.valueOrNull;
    if (latest == null) return;
    state = AsyncData(latest.copyWith(isSpeaking: false, playToken: latest.playToken + 1));
  }

  void previousTurn() {
    final current = state.valueOrNull;
    if (current == null || current.currentTurnIndex == 0) return;
    // Fire-and-forget: stop the audio but don't block the (synchronous)
    // navigation update on its completion.
    ref.read(ttsServiceProvider).stop();
    state = AsyncData(current.copyWith(
      currentTurnIndex: current.currentTurnIndex - 1,
      isSpeaking: false,
      playToken: current.playToken + 1,
    ));
  }

  void nextTurn() {
    final current = state.valueOrNull;
    if (current == null ||
        current.currentTurnIndex >= current.passage.turns.length - 1) {
      return;
    }
    ref.read(ttsServiceProvider).stop();
    state = AsyncData(current.copyWith(
      currentTurnIndex: current.currentTurnIndex + 1,
      isSpeaking: false,
      playToken: current.playToken + 1,
    ));
  }

  void replayFromStart() {
    final current = state.valueOrNull;
    if (current == null) return;
    ref.read(ttsServiceProvider).stop();
    state = AsyncData(current.copyWith(
      currentTurnIndex: 0,
      isSpeaking: false,
      playToken: current.playToken + 1,
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
