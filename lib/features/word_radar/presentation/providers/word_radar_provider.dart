import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/di/app_providers.dart';
import '../../../dictionary/presentation/providers/user_settings_provider.dart';
import '../../../vocabulary/domain/entities/vocab_record.dart';
import '../../domain/entities/word_radar_ai_result.dart';

part 'word_radar_provider.g.dart';

final class WordRadarState {
  const WordRadarState({this.knownRecords, this.aiResult});

  final List<VocabRecord>? knownRecords; // null = not scanned yet
  final AsyncValue<WordRadarAiResult>? aiResult; // null = AI not run

  WordRadarState copyWith({
    List<VocabRecord>? knownRecords,
    AsyncValue<WordRadarAiResult>? aiResult,
  }) =>
      WordRadarState(
        knownRecords: knownRecords ?? this.knownRecords,
        aiResult: aiResult ?? this.aiResult,
      );
}

@riverpod
class WordRadarNotifier extends _$WordRadarNotifier {
  @override
  WordRadarState build() => const WordRadarState();

  Future<void> scan(String text) async {
    final settings = ref.read(userSettingsNotifierProvider);
    final knownRecords = await ref
        .read(findKnownHeadwordsUseCaseProvider)
        .execute(text: text, language: settings.targetLanguage);

    if (!settings.aiEnabled) {
      state = WordRadarState(knownRecords: knownRecords, aiResult: null);
      return;
    }

    state = WordRadarState(
      knownRecords: knownRecords,
      aiResult: const AsyncLoading(),
    );
    final headwords = knownRecords.map((r) => r.headword).toList();
    final aiResult = await AsyncValue.guard(
      () => ref.read(generateWordSuggestionsUseCaseProvider).execute(
            text: text,
            targetLanguage: settings.targetLanguage,
            targetCefrLevel: settings.targetCefrLevel,
            knownHeadwords: headwords,
          ),
    );
    state = state.copyWith(aiResult: aiResult);
  }

  Future<void> retrySuggestions(String text) async {
    final current = state;
    if (current.knownRecords == null) return;
    final settings = ref.read(userSettingsNotifierProvider);
    if (!settings.aiEnabled) return;
    state = current.copyWith(aiResult: const AsyncLoading());
    final headwords = current.knownRecords!.map((r) => r.headword).toList();
    final aiResult = await AsyncValue.guard(
      () => ref.read(generateWordSuggestionsUseCaseProvider).execute(
            text: text,
            targetLanguage: settings.targetLanguage,
            targetCefrLevel: settings.targetCefrLevel,
            knownHeadwords: headwords,
          ),
    );
    state = state.copyWith(aiResult: aiResult);
  }

  void reset() => state = const WordRadarState();
}
