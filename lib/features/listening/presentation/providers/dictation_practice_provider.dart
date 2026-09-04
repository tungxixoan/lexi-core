import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/di/app_providers.dart';
import '../../../dictionary/domain/entities/app_context.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../../../vocabulary/domain/entities/cefr_level.dart';
import '../../../vocabulary/domain/entities/vocab_record.dart';
import '../../domain/entities/blank_span.dart';
import '../../domain/entities/dictation_difficulty.dart';
import '../../domain/entities/dictation_item.dart';

part 'dictation_practice_provider.g.dart';

final class DictationSessionResult {
  const DictationSessionResult({
    required this.item,
    required this.typed,
    required this.replayCount,
    required this.duration,
    this.difficulty = DictationDifficulty.hard,
    this.blanks = const [],
    this.blankAnswers = const [],
    this.seekCount = 0,
    this.seekPenaltyTotal = 0.0,
    this.reusedFromId,
    this.generationFilters,
  });

  final DictationItem item;
  final String typed;
  final int replayCount;
  final Duration duration;
  final DictationDifficulty difficulty;
  final List<BlankSpan> blanks;
  final List<String> blankAnswers;
  final int seekCount;
  final double seekPenaltyTotal;

  /// Non-null when this session was started from a saved exercise — the result
  /// screen uses it to hide "Lưu bài" and to exclude the item on "Bài khác".
  final String? reusedFromId;

  /// The raw generation-filter map the session was generated with, threaded to
  /// the result screen's "Lưu bài" action.
  final Map<String, dynamic>? generationFilters;

  int get totalChars => item.target.length;

  int get correctChars {
    int correct = 0;
    final limit = typed.length < item.target.length
        ? typed.length
        : item.target.length;
    for (int i = 0; i < limit; i++) {
      if (typed[i] == item.target[i]) correct++;
    }
    return correct;
  }

  double get charAccuracy => totalChars == 0 ? 1.0 : correctChars / totalChars;

  List<String> get _targetWords =>
      item.target.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

  /// The correct text for [blank] — one or more words joined by a single space.
  String targetTextFor(BlankSpan blank) => _targetWords
      .skip(blank.startWordIndex)
      .take(blank.wordCount)
      .join(' ');

  static final RegExp _edgePunctuation =
      RegExp(r'^[^\p{L}\p{N}]+|[^\p{L}\p{N}]+$', unicode: true);

  String _normalize(String s) => s
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ')
      .split(' ')
      .map((word) => word.replaceAll(_edgePunctuation, ''))
      .join(' ');

  bool isBlankCorrect(int index) =>
      _normalize(blankAnswers[index]) == _normalize(targetTextFor(blanks[index]));

  double get blockAccuracy {
    if (blanks.isEmpty) return 1.0;
    final correctCount =
        List.generate(blanks.length, (i) => i).where(isBlankCorrect).length;
    return correctCount / blanks.length;
  }

  double get _rawAccuracy =>
      difficulty == DictationDifficulty.hard ? charAccuracy : blockAccuracy;

  double get finalScore =>
      (_rawAccuracy - 0.05 * replayCount - seekPenaltyTotal).clamp(0.0, 1.0);

  int get sm2Quality {
    final score = finalScore;
    if (score >= 0.95) return 5;
    if (score >= 0.80) return 4;
    if (score >= 0.60) return 3;
    if (score >= 0.40) return 2;
    return 0;
  }
}

/// Fraction (0.01–0.05) deducted for a single seek to [wordIndex] out of
/// [totalWords] words in the sentence. TTS always speaks from the seek
/// point to the end of the sentence, so seeking near the start re-hears
/// almost the whole sentence (expensive) while seeking near the end
/// re-hears almost nothing (cheap) — this scales the penalty accordingly.
double seekPenaltyFraction({required int wordIndex, required int totalWords}) {
  if (totalWords <= 0) return 0.0;
  final wordsReheard = totalWords - wordIndex;
  final reheardRatio = wordsReheard / totalWords;
  if (reheardRatio <= 0.2) return 0.01;
  return (0.01 + 0.04 * (reheardRatio - 0.2) / 0.8).clamp(0.01, 0.05);
}

final class DictationSessionState {
  const DictationSessionState({
    required this.item,
    required this.typedText,
    required this.replayCount,
    required this.hasPlayedOnce,
    required this.startedAt,
    required this.isComplete,
    this.difficulty = DictationDifficulty.hard,
    this.blanks = const [],
    this.blankAnswers = const [],
    this.seekCount = 0,
    this.seekPenaltyTotal = 0.0,
    this.speedMultiplier = 1.0,
    this.isSpeaking = false,
    this.reusedFromId,
    this.generationFilters,
  });

  final DictationItem item;
  final String typedText;
  final int replayCount;
  final bool hasPlayedOnce;
  final DateTime startedAt;
  final bool isComplete;
  final DictationDifficulty difficulty;
  final List<BlankSpan> blanks;
  final List<String> blankAnswers;
  final int seekCount;
  final double seekPenaltyTotal;
  final double speedMultiplier;
  final bool isSpeaking;

  /// Non-null when this session was started from a saved exercise (via
  /// [DictationPracticeNotifier.loadSaved]); carried onto
  /// [DictationSessionResult].
  final String? reusedFromId;

  /// The raw generation-filter map the item was generated with; carried onto
  /// [DictationSessionResult] for "Lưu bài".
  final Map<String, dynamic>? generationFilters;

  bool get isClozeMode => difficulty != DictationDifficulty.hard;

  bool get allBlanksFilled =>
      blankAnswers.isNotEmpty && blankAnswers.every((a) => a.trim().isNotEmpty);

  DictationSessionState copyWith({
    String? typedText,
    int? replayCount,
    bool? hasPlayedOnce,
    bool? isComplete,
    List<String>? blankAnswers,
    int? seekCount,
    double? seekPenaltyTotal,
    double? speedMultiplier,
    bool? isSpeaking,
  }) =>
      DictationSessionState(
        item: item,
        typedText: typedText ?? this.typedText,
        replayCount: replayCount ?? this.replayCount,
        hasPlayedOnce: hasPlayedOnce ?? this.hasPlayedOnce,
        startedAt: startedAt,
        isComplete: isComplete ?? this.isComplete,
        difficulty: difficulty,
        blanks: blanks,
        blankAnswers: blankAnswers ?? this.blankAnswers,
        seekCount: seekCount ?? this.seekCount,
        seekPenaltyTotal: seekPenaltyTotal ?? this.seekPenaltyTotal,
        speedMultiplier: speedMultiplier ?? this.speedMultiplier,
        isSpeaking: isSpeaking ?? this.isSpeaking,
        reusedFromId: reusedFromId,
        generationFilters: generationFilters,
      );
}

double _rateFor(double speedMultiplier) => speedMultiplier;

@riverpod
class DictationPracticeNotifier extends _$DictationPracticeNotifier {
  @override
  AsyncValue<DictationSessionState?> build() {
    final ttsService = ref.read(ttsServiceProvider);
    ref.onDispose(ttsService.stop);
    return const AsyncData(null);
  }

  Future<void> generate({
    required List<VocabRecord> words,
    required CEFRLevel level,
    required AppContext context,
    required Language targetLanguage,
    DictationDifficulty difficulty = DictationDifficulty.hard,
    Map<String, dynamic>? generationFilters,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final item = await ref.read(generateDictationItemUseCaseProvider).execute(
            words: words,
            level: level,
            context: context,
            targetLanguage: targetLanguage,
          );
      final blanks = ref
          .read(selectDictationBlanksUseCaseProvider)
          .execute(item.target, difficulty);
      return DictationSessionState(
        item: item,
        typedText: '',
        replayCount: 0,
        hasPlayedOnce: false,
        startedAt: DateTime.now(),
        isComplete: false,
        difficulty: difficulty,
        blanks: blanks,
        blankAnswers: List.filled(blanks.length, ''),
        generationFilters: generationFilters,
      );
    });
  }

  /// Starts a session from a pre-built [item], bypassing the AI. [savedId] is
  /// the id of the saved exercise it came from (so the result screen can hide
  /// "Lưu bài" and exclude it on "Bài khác"); [generationFilters] is the raw
  /// filter map to thread through to "Lưu bài".
  void loadSaved(
    DictationItem item, {
    String? savedId,
    Map<String, dynamic>? generationFilters,
    DictationDifficulty difficulty = DictationDifficulty.hard,
  }) {
    final blanks = ref
        .read(selectDictationBlanksUseCaseProvider)
        .execute(item.target, difficulty);
    state = AsyncData(DictationSessionState(
      item: item,
      typedText: '',
      replayCount: 0,
      hasPlayedOnce: false,
      startedAt: DateTime.now(),
      isComplete: false,
      difficulty: difficulty,
      blanks: blanks,
      blankAnswers: List.filled(blanks.length, ''),
      reusedFromId: savedId,
      generationFilters: generationFilters,
    ));
  }

  Future<void> play() async {
    final current = state.valueOrNull;
    if (current == null) return;
    final updated = current.hasPlayedOnce
        ? current.copyWith(replayCount: current.replayCount + 1, isSpeaking: true)
        : current.copyWith(hasPlayedOnce: true, isSpeaking: true);
    state = AsyncData(updated);
    await ref.read(ttsServiceProvider).synthesize(
          current.item.target,
          current.item.targetLanguage,
          rate: _rateFor(updated.speedMultiplier),
        );
    final latest = state.valueOrNull;
    if (latest == null) return;
    state = AsyncData(latest.copyWith(isSpeaking: false));
  }

  Future<void> seekTo(int wordIndex) async {
    final current = state.valueOrNull;
    if (current == null || current.isComplete) return;
    final words = current.item.target
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (wordIndex < 0 || wordIndex >= words.length) return;

    final updated = current.hasPlayedOnce
        ? current.copyWith(
            seekCount: current.seekCount + 1,
            seekPenaltyTotal: current.seekPenaltyTotal +
                seekPenaltyFraction(wordIndex: wordIndex, totalWords: words.length),
            isSpeaking: true,
          )
        : current.copyWith(
            hasPlayedOnce: true, seekCount: current.seekCount + 1, isSpeaking: true);
    state = AsyncData(updated);

    await ref.read(ttsServiceProvider).stop();
    await ref.read(ttsServiceProvider).synthesize(
          words.skip(wordIndex).join(' '),
          current.item.targetLanguage,
          rate: _rateFor(updated.speedMultiplier),
        );
    final latest = state.valueOrNull;
    if (latest == null) return;
    state = AsyncData(latest.copyWith(isSpeaking: false));
  }

  Future<void> setSpeed(double multiplier) async {
    final current = state.valueOrNull;
    if (current == null || current.isComplete) return;
    if (!current.isSpeaking) {
      state = AsyncData(current.copyWith(speedMultiplier: multiplier));
      return;
    }
    await ref.read(ttsServiceProvider).stop();
    state = AsyncData(current.copyWith(
      speedMultiplier: multiplier,
      replayCount: current.replayCount + 1,
      isSpeaking: true,
    ));
    await ref.read(ttsServiceProvider).synthesize(
          current.item.target,
          current.item.targetLanguage,
          rate: _rateFor(multiplier),
        );
    final latest = state.valueOrNull;
    if (latest == null) return;
    state = AsyncData(latest.copyWith(isSpeaking: false));
  }

  void updateTypedText(String text) {
    final current = state.valueOrNull;
    if (current == null || current.isComplete) return;
    state = AsyncData(current.copyWith(typedText: text));
  }

  void updateBlankAnswer(int blankIndex, String text) {
    final current = state.valueOrNull;
    if (current == null || current.isComplete) return;
    if (blankIndex < 0 || blankIndex >= current.blankAnswers.length) return;
    final updated = List<String>.from(current.blankAnswers);
    updated[blankIndex] = text;
    state = AsyncData(current.copyWith(blankAnswers: updated));
  }

  void submit() {
    final current = state.valueOrNull;
    if (current == null || current.isComplete) return;
    state = AsyncData(current.copyWith(isComplete: true));
  }

  void reset() => state = const AsyncData(null);
}
