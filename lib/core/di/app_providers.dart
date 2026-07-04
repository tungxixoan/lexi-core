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
// --- Vocabulary DI (Plan 2) ---
import '../../features/vocabulary/data/repositories/vocab_repository_impl.dart';
import '../../features/vocabulary/domain/repositories/vocab_repository.dart';
import '../../features/vocabulary/domain/use_cases/add_topic_use_case.dart';
import '../../features/vocabulary/domain/use_cases/delete_topic_use_case.dart';
import '../../features/vocabulary/domain/use_cases/delete_vocab_use_case.dart';
import '../../features/vocabulary/domain/use_cases/get_topics_use_case.dart';
import '../../features/vocabulary/domain/use_cases/get_vocab_list_use_case.dart';
import '../../features/vocabulary/domain/use_cases/save_vocab_use_case.dart';
import '../../features/vocabulary/domain/use_cases/update_vocab_use_case.dart';
// --- Practice DI (Plan 3) ---
import '../../features/practice/data/sources/exercise_generator_source.dart';
import '../../features/practice/domain/use_cases/compute_sm2_use_case.dart';
import '../../features/practice/domain/use_cases/generate_exercise_use_case.dart';
// --- Stats DI (Plan 5) ---
import 'package:hive/hive.dart';
import '../services/stats_service.dart';
import '../../features/practice/domain/entities/learning_stats.dart';
import '../../features/practice/domain/use_cases/get_learning_stats_use_case.dart';

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

@riverpod
VocabRepository vocabRepository(VocabRepositoryRef ref) =>
    const VocabRepositoryImpl();

@riverpod
SaveVocabUseCase saveVocabUseCase(SaveVocabUseCaseRef ref) =>
    SaveVocabUseCase(ref.watch(vocabRepositoryProvider));

@riverpod
GetVocabListUseCase getVocabListUseCase(GetVocabListUseCaseRef ref) =>
    GetVocabListUseCase(ref.watch(vocabRepositoryProvider));

@riverpod
UpdateVocabUseCase updateVocabUseCase(UpdateVocabUseCaseRef ref) =>
    UpdateVocabUseCase(ref.watch(vocabRepositoryProvider));

@riverpod
DeleteVocabUseCase deleteVocabUseCase(DeleteVocabUseCaseRef ref) =>
    DeleteVocabUseCase(ref.watch(vocabRepositoryProvider));

@riverpod
GetTopicsUseCase getTopicsUseCase(GetTopicsUseCaseRef ref) =>
    GetTopicsUseCase(ref.watch(vocabRepositoryProvider));

@riverpod
AddTopicUseCase addTopicUseCase(AddTopicUseCaseRef ref) =>
    AddTopicUseCase(ref.watch(vocabRepositoryProvider));

@riverpod
DeleteTopicUseCase deleteTopicUseCase(DeleteTopicUseCaseRef ref) =>
    DeleteTopicUseCase(ref.watch(vocabRepositoryProvider));

@riverpod
ExerciseGeneratorSource exerciseGeneratorSource(ExerciseGeneratorSourceRef ref) {
  final apiKey = ref.watch(
    userSettingsNotifierProvider.select((s) => s.geminiApiKey),
  );
  return ExerciseGeneratorSource(apiKey: apiKey);
}

@riverpod
GenerateExerciseUseCase generateExerciseUseCase(GenerateExerciseUseCaseRef ref) =>
    GenerateExerciseUseCase(ref.watch(exerciseGeneratorSourceProvider));

@riverpod
ComputeSm2UseCase computeSm2UseCase(ComputeSm2UseCaseRef ref) =>
    const ComputeSm2UseCase();

@riverpod
StatsService statsService(StatsServiceRef ref) => StatsService(
      vocabBox: Hive.box<String>('vocab_records'),
      prefs: ref.read(sharedPreferencesProvider),
    );

@riverpod
GetLearningStatsUseCase getLearningStatsUseCase(
        GetLearningStatsUseCaseRef ref) =>
    GetLearningStatsUseCase(ref.read(statsServiceProvider));

@riverpod
LearningStats learningStats(LearningStatsRef ref) =>
    ref.watch(statsServiceProvider).computeStats();
