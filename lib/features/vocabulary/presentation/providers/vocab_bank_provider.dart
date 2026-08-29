// lib/features/vocabulary/presentation/providers/vocab_bank_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/di/app_providers.dart';
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
