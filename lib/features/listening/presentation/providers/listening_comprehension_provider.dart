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
    this.speedMultiplier = 1.0,
  });

  final ListeningPassage passage;
  final int currentTurnIndex;
  final bool isSpeaking;
  final int playToken;
  final List<int?> selectedAnswers;
  final bool isSubmitted;
  final double speedMultiplier;

  ListeningTurn get currentTurn => passage.turns[currentTurnIndex];
  bool get canSubmit => selectedAnswers.every((a) => a != null);

  ListeningSessionState copyWith({
    int? currentTurnIndex,
    bool? isSpeaking,
    int? playToken,
    List<int?>? selectedAnswers,
    bool? isSubmitted,
    double? speedMultiplier,
  }) =>
      ListeningSessionState(
        passage: passage,
        currentTurnIndex: currentTurnIndex ?? this.currentTurnIndex,
        isSpeaking: isSpeaking ?? this.isSpeaking,
        playToken: playToken ?? this.playToken,
        selectedAnswers: selectedAnswers ?? this.selectedAnswers,
        isSubmitted: isSubmitted ?? this.isSubmitted,
        speedMultiplier: speedMultiplier ?? this.speedMultiplier,
      );
}

double _rateFor(double speedMultiplier) => speedMultiplier;

List<String> _splitWords(String text) =>
    text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

/// Total word count across every turn of [passage], in order — the range
/// the Nghe hiểu seek slider spans (word positions are counted across all
/// turns, not per turn).
int totalWordsOf(ListeningPassage passage) =>
    passage.turns.fold(0, (sum, t) => sum + _splitWords(t.text).length);

/// Maps a 0-based [globalWordIndex] (counting words across all turns of
/// [passage] in order) to the turn it falls in and its word index within
/// that turn's own text.
({int turnIndex, int wordIndex}) _resolveGlobalWordIndex(
  ListeningPassage passage,
  int globalWordIndex,
) {
  var remaining = globalWordIndex;
  for (var t = 0; t < passage.turns.length; t++) {
    final wordCount = _splitWords(passage.turns[t].text).length;
    if (remaining < wordCount) {
      return (turnIndex: t, wordIndex: remaining);
    }
    remaining -= wordCount;
  }
  final lastTurn = passage.turns.length - 1;
  return (
    turnIndex: lastTurn,
    wordIndex: _splitWords(passage.turns[lastTurn].text).length - 1,
  );
}

@riverpod
class ListeningComprehensionNotifier extends _$ListeningComprehensionNotifier {
  @override
  AsyncValue<ListeningSessionState?> build() {
    final ttsService = ref.read(ttsServiceProvider);
    ref.onDispose(ttsService.stop);
    return const AsyncData(null);
  }

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

  Future<void> playCurrentTurn() async {
    final current = state.valueOrNull;
    if (current == null || current.isSubmitted) return;
    final token = current.playToken + 1;
    state = AsyncData(current.copyWith(isSpeaking: true, playToken: token));
    final turn = current.currentTurn;
    final voices = assignVoices(current.passage);
    await ref.read(ttsServiceProvider).synthesize(
          turn.text,
          current.passage.targetLanguage,
          voice: voices[speakerKey(turn.speaker)],
          rate: _rateFor(current.speedMultiplier),
        );
    final latest = state.valueOrNull;
    if (latest == null || latest.playToken != token) return; // superseded meanwhile
    if (latest.currentTurnIndex < latest.passage.turns.length - 1) {
      // Turn finished naturally (not interrupted) and it's not the last one
      // — keep going without a gap, staying "isSpeaking" the whole time.
      state = AsyncData(latest.copyWith(currentTurnIndex: latest.currentTurnIndex + 1));
      await playCurrentTurn();
      return;
    }
    state = AsyncData(latest.copyWith(isSpeaking: false));
  }

  Future<void> seekToWord(int globalWordIndex) async {
    final current = state.valueOrNull;
    if (current == null || current.isSubmitted) return;
    final total = totalWordsOf(current.passage);
    if (globalWordIndex < 0 || globalWordIndex >= total) return;

    final resolved = _resolveGlobalWordIndex(current.passage, globalWordIndex);
    final turn = current.passage.turns[resolved.turnIndex];
    final words = _splitWords(turn.text);
    final token = current.playToken + 1;
    state = AsyncData(current.copyWith(
      currentTurnIndex: resolved.turnIndex,
      isSpeaking: true,
      playToken: token,
    ));
    await ref.read(ttsServiceProvider).stop();
    final voices = assignVoices(current.passage);
    await ref.read(ttsServiceProvider).synthesize(
          words.skip(resolved.wordIndex).join(' '),
          current.passage.targetLanguage,
          voice: voices[speakerKey(turn.speaker)],
          rate: _rateFor(current.speedMultiplier),
        );
    final latest = state.valueOrNull;
    if (latest == null || latest.playToken != token) return; // superseded meanwhile
    state = AsyncData(latest.copyWith(isSpeaking: false));
  }

  Future<void> setSpeed(double multiplier) async {
    final current = state.valueOrNull;
    if (current == null || current.isSubmitted) return;
    if (!current.isSpeaking) {
      state = AsyncData(current.copyWith(speedMultiplier: multiplier));
      return;
    }
    await ref.read(ttsServiceProvider).stop();
    state = AsyncData(current.copyWith(speedMultiplier: multiplier));
    await playCurrentTurn();
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
