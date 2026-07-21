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
  });

  final DictationItem item;
  final String typed;
  final int replayCount;
  final Duration duration;
  final DictationDifficulty difficulty;
  final List<BlankSpan> blanks;
  final List<String> blankAnswers;

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

  String _normalize(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

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

  double get finalScore => (_rawAccuracy - 0.05 * replayCount).clamp(0.0, 1.0);

  int get sm2Quality {
    final score = finalScore;
    if (score >= 0.95) return 5;
    if (score >= 0.80) return 4;
    if (score >= 0.60) return 3;
    if (score >= 0.40) return 2;
    return 0;
  }
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

  bool get isClozeMode => difficulty != DictationDifficulty.hard;

  bool get allBlanksFilled =>
      blankAnswers.isNotEmpty && blankAnswers.every((a) => a.trim().isNotEmpty);

  DictationSessionState copyWith({
    String? typedText,
    int? replayCount,
    bool? hasPlayedOnce,
    bool? isComplete,
    List<String>? blankAnswers,
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
      );
}

@riverpod
class DictationPracticeNotifier extends _$DictationPracticeNotifier {
  @override
  AsyncValue<DictationSessionState?> build() => const AsyncData(null);

  Future<void> generate({
    required List<VocabRecord> words,
    required CEFRLevel level,
    required AppContext context,
    required Language targetLanguage,
    DictationDifficulty difficulty = DictationDifficulty.hard,
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
      );
    });
  }

  Future<void> play() async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(
      current.hasPlayedOnce
          ? current.copyWith(replayCount: current.replayCount + 1)
          : current.copyWith(hasPlayedOnce: true),
    );
    await ref
        .read(ttsServiceProvider)
        .speak(current.item.target, current.item.targetLanguage);
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
