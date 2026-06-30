// lib/core/di/app_providers.dart
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../features/dictionary/data/repositories/dictionary_repository_impl.dart';
import '../../features/dictionary/data/sources/free_dictionary_source.dart';
import '../../features/dictionary/data/sources/gemini_dictionary_source.dart';
import '../../features/dictionary/domain/repositories/dictionary_repository.dart';
import '../../features/dictionary/domain/use_cases/lookup_use_case.dart';
import '../../features/dictionary/presentation/providers/user_settings_provider.dart';
import '../../services/tts_service.dart';

part 'app_providers.g.dart';

@riverpod
http.Client httpClient(HttpClientRef ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
}

@riverpod
FlutterTts flutterTts(FlutterTtsRef ref) => FlutterTts();

@riverpod
TtsService ttsService(TtsServiceRef ref) =>
    FlutterTtsService(ref.watch(flutterTtsProvider));

@riverpod
FreeDictionarySource freeDictionarySource(FreeDictionarySourceRef ref) =>
    FreeDictionarySource(ref.watch(httpClientProvider));

@riverpod
GeminiDictionarySource geminiDictionarySource(
    GeminiDictionarySourceRef ref) {
  final apiKey = ref.watch(
    userSettingsNotifierProvider.select((s) => s.geminiApiKey),
  );
  return GeminiDictionarySource(apiKey: apiKey);
}

@riverpod
DictionaryRepository dictionaryRepository(DictionaryRepositoryRef ref) =>
    DictionaryRepositoryImpl(
      geminiSource: ref.watch(geminiDictionarySourceProvider),
      freeDictionarySource: ref.watch(freeDictionarySourceProvider),
    );

@riverpod
LookupUseCase lookupUseCase(LookupUseCaseRef ref) =>
    LookupUseCase(ref.watch(dictionaryRepositoryProvider));
