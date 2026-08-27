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
import '../services/stats_service.dart';
import '../../features/practice/domain/entities/learning_stats.dart';
import '../../features/practice/domain/use_cases/get_learning_stats_use_case.dart';
// --- Reading DI (Plan 7) ---
import '../../features/reading/data/sources/reading_passage_source.dart';
import '../../features/reading/domain/use_cases/generate_reading_passage_use_case.dart';
import '../../features/reading/data/sources/part5_source.dart';
import '../../features/reading/domain/use_cases/generate_part5_set_use_case.dart';
import '../../features/reading/data/sources/part6_source.dart';
import '../../features/reading/domain/use_cases/generate_part6_set_use_case.dart';
import '../../features/reading/data/sources/part7_source.dart';
import '../../features/reading/domain/use_cases/generate_part7_set_use_case.dart';
// --- Listening DI (Plan 9) ---
import '../../features/listening/data/sources/dictation_source.dart';
import '../../features/listening/domain/use_cases/generate_dictation_item_use_case.dart';
import '../../features/listening/domain/use_cases/select_dictation_blanks_use_case.dart';
import '../../features/listening/data/sources/listening_passage_source.dart';
import '../../features/listening/domain/use_cases/generate_listening_passage_use_case.dart';
// --- Word Radar DI ---
import '../../features/word_radar/data/sources/word_radar_source.dart';
import '../../features/word_radar/domain/use_cases/find_known_headwords_use_case.dart';
import '../../features/word_radar/domain/use_cases/generate_word_suggestions_use_case.dart';
import '../../features/word_radar/domain/use_cases/get_vocab_suggestions_for_text_use_case.dart';

part 'app_providers.g.dart';

@Riverpod(keepAlive: true)
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
GeminiDictionarySource geminiDictionarySource(GeminiDictionarySourceRef ref) {
  final settings = ref.watch(userSettingsNotifierProvider);
  return GeminiDictionarySource(settings);
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
  final settings = ref.watch(userSettingsNotifierProvider);
  return ExerciseGeneratorSource(settings);
}

@riverpod
GenerateExerciseUseCase generateExerciseUseCase(GenerateExerciseUseCaseRef ref) =>
    GenerateExerciseUseCase(ref.watch(exerciseGeneratorSourceProvider));

@riverpod
ComputeSm2UseCase computeSm2UseCase(ComputeSm2UseCaseRef ref) =>
    const ComputeSm2UseCase();

@riverpod
StatsService statsService(StatsServiceRef ref) => StatsService(
      repository: ref.watch(vocabRepositoryProvider),
      prefs: ref.read(sharedPreferencesProvider),
    );

@riverpod
GetLearningStatsUseCase getLearningStatsUseCase(
        GetLearningStatsUseCaseRef ref) =>
    GetLearningStatsUseCase(ref.read(statsServiceProvider));

@riverpod
Future<LearningStats> learningStats(LearningStatsRef ref) =>
    ref.watch(statsServiceProvider).computeStats();

@riverpod
ReadingPassageSource readingPassageSource(ReadingPassageSourceRef ref) {
  final settings = ref.watch(userSettingsNotifierProvider);
  return ReadingPassageSource(settings);
}

@riverpod
GenerateReadingPassageUseCase generateReadingPassageUseCase(
        GenerateReadingPassageUseCaseRef ref) =>
    GenerateReadingPassageUseCase(ref.watch(readingPassageSourceProvider));

@riverpod
DictationSource dictationSource(DictationSourceRef ref) {
  final settings = ref.watch(userSettingsNotifierProvider);
  return DictationSource(settings);
}

@riverpod
GenerateDictationItemUseCase generateDictationItemUseCase(
        GenerateDictationItemUseCaseRef ref) =>
    GenerateDictationItemUseCase(ref.watch(dictationSourceProvider));

@riverpod
SelectDictationBlanksUseCase selectDictationBlanksUseCase(
        SelectDictationBlanksUseCaseRef ref) =>
    const SelectDictationBlanksUseCase();

@riverpod
ListeningPassageSource listeningPassageSource(ListeningPassageSourceRef ref) {
  final settings = ref.watch(userSettingsNotifierProvider);
  return ListeningPassageSource(settings);
}

@riverpod
GenerateListeningPassageUseCase generateListeningPassageUseCase(
        GenerateListeningPassageUseCaseRef ref) =>
    GenerateListeningPassageUseCase(ref.watch(listeningPassageSourceProvider));

@riverpod
FindKnownHeadwordsUseCase findKnownHeadwordsUseCase(
        FindKnownHeadwordsUseCaseRef ref) =>
    FindKnownHeadwordsUseCase(ref.watch(vocabRepositoryProvider));

@riverpod
WordRadarSource wordRadarSource(WordRadarSourceRef ref) {
  final settings = ref.watch(userSettingsNotifierProvider);
  return WordRadarSource(settings);
}

@riverpod
GenerateWordSuggestionsUseCase generateWordSuggestionsUseCase(
        GenerateWordSuggestionsUseCaseRef ref) =>
    GenerateWordSuggestionsUseCase(ref.watch(wordRadarSourceProvider));

@riverpod
GetVocabSuggestionsForTextUseCase getVocabSuggestionsForTextUseCase(
        GetVocabSuggestionsForTextUseCaseRef ref) =>
    GetVocabSuggestionsForTextUseCase(
      ref.watch(findKnownHeadwordsUseCaseProvider),
      ref.watch(generateWordSuggestionsUseCaseProvider),
    );

@riverpod
Part5Source part5Source(Part5SourceRef ref) {
  final settings = ref.watch(userSettingsNotifierProvider);
  return Part5Source(settings);
}

@riverpod
GeneratePart5SetUseCase generatePart5SetUseCase(GeneratePart5SetUseCaseRef ref) =>
    GeneratePart5SetUseCase(ref.watch(part5SourceProvider));

@riverpod
Part6Source part6Source(Part6SourceRef ref) {
  final settings = ref.watch(userSettingsNotifierProvider);
  return Part6Source(settings);
}

@riverpod
GeneratePart6SetUseCase generatePart6SetUseCase(GeneratePart6SetUseCaseRef ref) =>
    GeneratePart6SetUseCase(ref.watch(part6SourceProvider));

@riverpod
Part7Source part7Source(Part7SourceRef ref) {
  final settings = ref.watch(userSettingsNotifierProvider);
  return Part7Source(settings);
}

@riverpod
GeneratePart7SetUseCase generatePart7SetUseCase(GeneratePart7SetUseCaseRef ref) =>
    GeneratePart7SetUseCase(ref.watch(part7SourceProvider));
