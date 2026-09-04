import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/di/app_providers.dart';
import '../../../../features/dictionary/domain/entities/app_context.dart';
import '../../../../features/dictionary/domain/entities/language.dart';
import '../../../../features/vocabulary/domain/entities/cefr_level.dart';
import '../../../../features/vocabulary/domain/entities/vocab_record.dart';
import '../../domain/entities/reading_passage.dart';

part 'reading_practice_provider.g.dart';

final class SentenceResult {
  const SentenceResult({
    required this.target,
    required this.typed,
    required this.correctChars,
    required this.totalChars,
    required this.durationMs,
    this.deletedChars = 0,
  });

  final String target;
  final String typed;
  final int correctChars;
  final int totalChars;
  final int durationMs;
  final int deletedChars;

  double get accuracy => totalChars == 0 ? 1.0 : correctChars / totalChars;
}

final class ReadingSessionResult {
  const ReadingSessionResult({
    required this.passage,
    required this.sentenceResults,
    required this.totalDuration,
    this.reusedFromId,
    this.generationFilters,
  });

  final ReadingPassage passage;
  final List<SentenceResult> sentenceResults;
  final Duration totalDuration;

  /// Non-null when this session was started from a saved exercise — the result
  /// screen uses it to hide "Lưu bài" and to exclude the passage on "Bài khác".
  final String? reusedFromId;

  /// The raw `{topicIds, maxCefr, wordCount}` filter map the session was
  /// generated with, threaded to the result screen's "Lưu bài" action.
  final Map<String, dynamic>? generationFilters;

  int get totalChars => sentenceResults.fold(0, (s, r) => s + r.totalChars);

  double get overallAccuracy {
    if (sentenceResults.isEmpty) return 1.0;
    final totalCorrect = sentenceResults.fold(0, (s, r) => s + r.correctChars);
    return totalChars == 0 ? 1.0 : totalCorrect / totalChars;
  }

  double get wpm {
    final totalTyped = sentenceResults.fold(0, (s, r) => s + r.typed.length);
    final minutes = totalDuration.inSeconds / 60.0;
    if (minutes == 0) return 0;
    return (totalTyped / 5.0) / minutes;
  }

  int get totalDeletedChars =>
      sentenceResults.fold(0, (s, r) => s + r.deletedChars);

  /// How much of the passage was deleted/retyped, relative to its length.
  double get deletionRatio =>
      totalChars == 0 ? 0.0 : totalDeletedChars / totalChars;

  /// Deleting/retyping text equal to the whole passage length costs half the
  /// score — light enough that normal typo corrections barely register, but
  /// still penalizes heavy retyping.
  static const double _deletionPenaltyWeight = 0.5;

  double get finalScore =>
      (overallAccuracy - _deletionPenaltyWeight * deletionRatio)
          .clamp(0.0, 1.0);
}

final class ReadingSessionState {
  const ReadingSessionState({
    required this.passage,
    required this.currentSentenceIndex,
    required this.typedText,
    required this.completedSentences,
    required this.sessionStartedAt,
    required this.sentenceStartedAt,
    required this.isComplete,
    this.currentDeletedChars = 0,
    this.reusedFromId,
    this.generationFilters,
  });

  final ReadingPassage passage;
  final int currentSentenceIndex;
  final String typedText;
  final List<SentenceResult> completedSentences;
  final DateTime sessionStartedAt;
  final DateTime sentenceStartedAt;
  final bool isComplete;
  final int currentDeletedChars;

  /// Non-null when this session was started from a saved exercise (via
  /// [ReadingPracticeNotifier.loadSaved]); carried onto [ReadingSessionResult].
  final String? reusedFromId;

  /// The raw `{topicIds, maxCefr, wordCount}` filter map the passage was
  /// generated with; carried onto [ReadingSessionResult] for "Lưu bài".
  final Map<String, dynamic>? generationFilters;

  BilingualSentence get currentSentence =>
      passage.sentences[currentSentenceIndex];

  ReadingSessionState copyWith({
    int? currentSentenceIndex,
    String? typedText,
    List<SentenceResult>? completedSentences,
    DateTime? sentenceStartedAt,
    bool? isComplete,
    int? currentDeletedChars,
  }) =>
      ReadingSessionState(
        passage: passage,
        currentSentenceIndex: currentSentenceIndex ?? this.currentSentenceIndex,
        typedText: typedText ?? this.typedText,
        completedSentences: completedSentences ?? this.completedSentences,
        sessionStartedAt: sessionStartedAt,
        sentenceStartedAt: sentenceStartedAt ?? this.sentenceStartedAt,
        isComplete: isComplete ?? this.isComplete,
        currentDeletedChars: currentDeletedChars ?? this.currentDeletedChars,
        reusedFromId: reusedFromId,
        generationFilters: generationFilters,
      );
}

@riverpod
class ReadingPracticeNotifier extends _$ReadingPracticeNotifier {
  @override
  AsyncValue<ReadingSessionState?> build() => const AsyncData(null);

  Future<void> generate({
    required List<VocabRecord> words,
    required CEFRLevel level,
    required AppContext context,
    required Language targetLanguage,
    Map<String, dynamic>? generationFilters,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final passage =
          await ref.read(generateReadingPassageUseCaseProvider).execute(
                words: words,
                level: level,
                context: context,
                targetLanguage: targetLanguage,
              );
      final now = DateTime.now();
      return ReadingSessionState(
        passage: passage,
        currentSentenceIndex: 0,
        typedText: '',
        completedSentences: const [],
        sessionStartedAt: now,
        sentenceStartedAt: now,
        isComplete: false,
        generationFilters: generationFilters,
      );
    });
  }

  /// Starts a session from a pre-built [passage], bypassing the AI. [savedId] is
  /// the id of the saved exercise it came from (so the result screen can hide
  /// "Lưu bài" and exclude it on "Bài khác"); [generationFilters] is the raw
  /// `{topicIds, maxCefr, wordCount}` map to thread through to "Lưu bài".
  void loadSaved(
    ReadingPassage passage, {
    String? savedId,
    Map<String, dynamic>? generationFilters,
  }) {
    final now = DateTime.now();
    state = AsyncData(ReadingSessionState(
      passage: passage,
      currentSentenceIndex: 0,
      typedText: '',
      completedSentences: const [],
      sessionStartedAt: now,
      sentenceStartedAt: now,
      isComplete: false,
      reusedFromId: savedId,
      generationFilters: generationFilters,
    ));
  }

  void updateTypedText(String text) {
    final current = state.valueOrNull;
    if (current == null || current.isComplete) return;
    final deletedChars = text.length < current.typedText.length
        ? current.currentDeletedChars + (current.typedText.length - text.length)
        : current.currentDeletedChars;
    if (text.length >= current.currentSentence.target.length) {
      _advance(current.copyWith(currentDeletedChars: deletedChars), text);
    } else {
      state = AsyncData(current.copyWith(
        typedText: text,
        currentDeletedChars: deletedChars,
      ));
    }
  }

  void _advance(ReadingSessionState current, String typed) {
    final target = current.currentSentence.target;
    int correctChars = 0;
    for (int i = 0; i < typed.length && i < target.length; i++) {
      if (typed[i] == target[i]) correctChars++;
    }
    final result = SentenceResult(
      target: target,
      typed: typed,
      correctChars: correctChars,
      totalChars: target.length,
      durationMs:
          DateTime.now().difference(current.sentenceStartedAt).inMilliseconds,
      deletedChars: current.currentDeletedChars,
    );
    final nextIndex = current.currentSentenceIndex + 1;
    final isComplete = nextIndex >= current.passage.sentences.length;
    final now = DateTime.now();
    state = AsyncData(current.copyWith(
      currentSentenceIndex: nextIndex,
      typedText: '',
      completedSentences: [...current.completedSentences, result],
      sentenceStartedAt: now,
      isComplete: isComplete,
      currentDeletedChars: 0,
    ));
  }

  void reset() => state = const AsyncData(null);
}
