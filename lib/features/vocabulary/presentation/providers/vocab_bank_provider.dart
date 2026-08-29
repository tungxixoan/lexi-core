// lib/features/vocabulary/presentation/providers/vocab_bank_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/di/app_providers.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../../../dictionary/presentation/providers/user_settings_provider.dart';
import '../../domain/entities/vocab_record.dart';

part 'vocab_bank_provider.g.dart';

@riverpod
class VocabBankNotifier extends _$VocabBankNotifier {
  @override
  Future<List<VocabRecord>> build() {
    final language = ref.watch(userSettingsNotifierProvider).targetLanguage;
    return ref.read(getVocabListUseCaseProvider).execute(language: language);
  }

  Future<void> save(VocabRecord record) async {
    await ref.read(saveVocabUseCaseProvider).execute(record);
    ref.invalidateSelf();
  }

  Future<void> updateRecord(VocabRecord record) async {
    await ref.read(updateVocabUseCaseProvider).execute(record);
    ref.invalidateSelf();
  }

  Future<void> delete(String id) async {
    final language = ref.read(userSettingsNotifierProvider).targetLanguage;
    await ref.read(deleteVocabUseCaseProvider).execute(id, language: language);
    ref.invalidateSelf();
  }
}

/// Simple provider that returns the vocab list data synchronously.
/// Returns an empty list when loading or on error.
@riverpod
List<VocabRecord> vocabBank(Ref ref) {
  final asyncValue = ref.watch(vocabBankNotifierProvider);
  return asyncValue.when(
    data: (data) => data,
    loading: () => <VocabRecord>[],
    error: (_, __) => <VocabRecord>[],
  );
}

/// Fetches vocab records scoped to an explicit [language], independent of
/// the globally-scoped `userSettingsNotifierProvider.targetLanguage` that
/// [vocabBankProvider]/[vocabBankNotifierProvider] follow.
///
/// Session-driven screens (dictation, reading) have their own in-screen
/// language picker, so a practice session can run in a language that
/// differs from the app's current global target-language setting.
/// Resolving that session's vocab records must use the session's own known
/// language — not the global one — or lookups can silently miss every
/// record (see the dictation/reading result-screen SM-2 fix).
final vocabListForLanguageProvider =
    FutureProvider.family<List<VocabRecord>, Language>((ref, language) {
  return ref.read(getVocabListUseCaseProvider).execute(language: language);
});
