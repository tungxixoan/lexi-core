import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/di/app_providers.dart';
import '../../../dictionary/domain/entities/lookup_result.dart';
import '../../../dictionary/presentation/providers/user_settings_provider.dart';

part 'word_radar_provider.g.dart';

final class WordRadarState {
  const WordRadarState({this.knownHeadwords, this.suggestions});

  final List<String>? knownHeadwords; // null = not scanned yet
  final AsyncValue<List<WordPhraseResult>>? suggestions; // null = AI not run

  WordRadarState copyWith({
    List<String>? knownHeadwords,
    AsyncValue<List<WordPhraseResult>>? suggestions,
  }) =>
      WordRadarState(
        knownHeadwords: knownHeadwords ?? this.knownHeadwords,
        suggestions: suggestions ?? this.suggestions,
      );
}

@riverpod
class WordRadarNotifier extends _$WordRadarNotifier {
  @override
  WordRadarState build() => const WordRadarState();

  Future<void> scan(String text) async {
    final settings = ref.read(userSettingsNotifierProvider);
    final knownHeadwords = await ref
        .read(findKnownHeadwordsUseCaseProvider)
        .execute(text: text, language: settings.targetLanguage);

    if (!settings.aiEnabled) {
      state = WordRadarState(knownHeadwords: knownHeadwords, suggestions: null);
      return;
    }

    state = WordRadarState(
      knownHeadwords: knownHeadwords,
      suggestions: const AsyncLoading(),
    );
    final suggestions = await AsyncValue.guard(
      () => ref.read(generateWordSuggestionsUseCaseProvider).execute(
            text: text,
            targetLanguage: settings.targetLanguage,
            targetCefrLevel: settings.targetCefrLevel,
            knownHeadwords: knownHeadwords,
          ),
    );
    state = state.copyWith(suggestions: suggestions);
  }

  Future<void> retrySuggestions(String text) async {
    final current = state;
    if (current.knownHeadwords == null) return;
    final settings = ref.read(userSettingsNotifierProvider);
    if (!settings.aiEnabled) return;
    state = current.copyWith(suggestions: const AsyncLoading());
    final suggestions = await AsyncValue.guard(
      () => ref.read(generateWordSuggestionsUseCaseProvider).execute(
            text: text,
            targetLanguage: settings.targetLanguage,
            targetCefrLevel: settings.targetCefrLevel,
            knownHeadwords: current.knownHeadwords!,
          ),
    );
    state = state.copyWith(suggestions: suggestions);
  }

  void reset() => state = const WordRadarState();
}
