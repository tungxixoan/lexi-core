// lib/features/vocabulary/presentation/providers/vocab_bank_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/di/app_providers.dart';
import '../../domain/entities/vocab_record.dart';

part 'vocab_bank_provider.g.dart';

@riverpod
class VocabBankNotifier extends _$VocabBankNotifier {
  @override
  Future<List<VocabRecord>> build() =>
      ref.read(getVocabListUseCaseProvider).execute();

  Future<void> save(VocabRecord record) async {
    await ref.read(saveVocabUseCaseProvider).execute(record);
    ref.invalidateSelf();
  }

  Future<void> updateRecord(VocabRecord record) async {
    await ref.read(updateVocabUseCaseProvider).execute(record);
    ref.invalidateSelf();
  }

  Future<void> delete(String id) async {
    await ref.read(deleteVocabUseCaseProvider).execute(id);
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
