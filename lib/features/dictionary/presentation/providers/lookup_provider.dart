// lib/features/dictionary/presentation/providers/lookup_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/di/app_providers.dart';
import '../../../../core/utils/input_detector.dart';
import '../../domain/entities/input_type.dart';
import '../../domain/entities/lookup_result.dart';
import 'user_settings_provider.dart';

part 'lookup_provider.g.dart';

@riverpod
class LookupNotifier extends _$LookupNotifier {
  @override
  AsyncValue<LookupResult?> build() => const AsyncValue.data(null);

  Future<void> lookup(String query) async {
    state = const AsyncValue.loading();
    try {
      final settings = ref.read(userSettingsNotifierProvider);
      final inputType = InputDetector.detect(query);

      // VocabBank cache: for word/phrase only, check saved records first
      if (inputType != InputType.sentence) {
        final cached = await ref
            .read(vocabRepositoryProvider)
            .getByHeadword(query.trim(), settings.targetLanguage);
        if (cached != null) {
          state = AsyncValue.data(
            WordPhraseResult(
              headword: cached.headword,
              inputType: cached.inputType,
              ipa: cached.ipa,
              meaning: cached.meaning,
              examples: cached.examples,
              suggestedTopics: const [],
            ),
          );
          return;
        }
      }

      // Fallback: call the API as before
      final useCase = ref.read(lookupUseCaseProvider);
      state = await AsyncValue.guard(() => useCase.execute(
            query: query,
            targetLanguage: settings.targetLanguage,
            context: settings.activeContext,
            aiEnabled: settings.aiEnabled,
          ));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> discover() async {
    final settings = ref.read(userSettingsNotifierProvider);
    if (!settings.aiEnabled) return;

    state = const AsyncValue.loading();
    final gemini = ref.read(geminiDictionarySourceProvider);

    state = await AsyncValue.guard(() async {
      final word = await gemini.discoverWord(
        targetLanguage: settings.targetLanguage,
        context: settings.activeContext,
      );
      final useCase = ref.read(lookupUseCaseProvider);
      return useCase.execute(
        query: word,
        targetLanguage: settings.targetLanguage,
        context: settings.activeContext,
        aiEnabled: true,
      );
    });
  }

  void clear() => state = const AsyncValue.data(null);
}
