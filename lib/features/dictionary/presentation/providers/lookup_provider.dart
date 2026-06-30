// lib/features/dictionary/presentation/providers/lookup_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/di/app_providers.dart';
import '../../domain/entities/lookup_result.dart';
import 'user_settings_provider.dart';

part 'lookup_provider.g.dart';

@riverpod
class LookupNotifier extends _$LookupNotifier {
  @override
  AsyncValue<LookupResult?> build() => const AsyncValue.data(null);

  Future<void> lookup(String query) async {
    state = const AsyncValue.loading();
    final settings = ref.read(userSettingsNotifierProvider);
    final useCase = ref.read(lookupUseCaseProvider);

    state = await AsyncValue.guard(() => useCase.execute(
          query: query,
          targetLanguage: settings.targetLanguage,
          context: settings.activeContext,
          aiEnabled: settings.aiEnabled,
        ));
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
