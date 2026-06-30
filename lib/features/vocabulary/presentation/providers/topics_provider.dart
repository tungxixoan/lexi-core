// lib/features/vocabulary/presentation/providers/topics_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/di/app_providers.dart';
import '../../domain/entities/topic.dart';
import 'vocab_bank_provider.dart';

part 'topics_provider.g.dart';

@riverpod
class TopicsNotifier extends _$TopicsNotifier {
  @override
  Future<List<Topic>> build() =>
      ref.read(getTopicsUseCaseProvider).execute();

  Future<void> addTopic(String name, String emoji) async {
    await ref.read(addTopicUseCaseProvider).execute(name: name, emoji: emoji);
    ref.invalidateSelf();
  }

  Future<void> deleteTopic(String id, {required bool isPredefined}) async {
    await ref.read(deleteTopicUseCaseProvider).execute(id, isPredefined: isPredefined);
    ref.invalidateSelf();
    // Invalidate vocab list since words may have been reassigned
    ref.invalidate(vocabBankNotifierProvider);
  }
}
