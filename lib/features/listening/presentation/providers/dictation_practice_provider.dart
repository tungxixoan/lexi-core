import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/di/app_providers.dart';
import '../../../dictionary/domain/entities/app_context.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../../../vocabulary/domain/entities/cefr_level.dart';
import '../../../vocabulary/domain/entities/vocab_record.dart';
import '../../domain/entities/dictation_item.dart';

part 'dictation_practice_provider.g.dart';

final class DictationSessionResult {
  const DictationSessionResult({
    required this.item,
    required this.typed,
    required this.replayCount,
    required this.duration,
  });

  final DictationItem item;
  final String typed;
  final int replayCount;
  final Duration duration;

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

  double get finalScore =>
      (charAccuracy - 0.05 * replayCount).clamp(0.0, 1.0);

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
  });

  final DictationItem item;
  final String typedText;
  final int replayCount;
  final bool hasPlayedOnce;
  final DateTime startedAt;
  final bool isComplete;

  DictationSessionState copyWith({
    String? typedText,
    int? replayCount,
    bool? hasPlayedOnce,
    bool? isComplete,
  }) =>
      DictationSessionState(
        item: item,
        typedText: typedText ?? this.typedText,
        replayCount: replayCount ?? this.replayCount,
        hasPlayedOnce: hasPlayedOnce ?? this.hasPlayedOnce,
        startedAt: startedAt,
        isComplete: isComplete ?? this.isComplete,
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
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final item = await ref.read(generateDictationItemUseCaseProvider).execute(
            words: words,
            level: level,
            context: context,
            targetLanguage: targetLanguage,
          );
      return DictationSessionState(
        item: item,
        typedText: '',
        replayCount: 0,
        hasPlayedOnce: false,
        startedAt: DateTime.now(),
        isComplete: false,
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

  void submit() {
    final current = state.valueOrNull;
    if (current == null || current.isComplete) return;
    state = AsyncData(current.copyWith(isComplete: true));
  }

  void reset() => state = const AsyncData(null);
}
