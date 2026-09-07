import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/di/app_providers.dart';
import '../../../dictionary/presentation/providers/user_settings_provider.dart';
import '../../domain/entities/knowledge_note.dart';

part 'knowledge_notes_provider.g.dart';

/// Loads the current target language's knowledge notes, seeding the starter
/// library on first access, and exposes optimistic CRUD mutations.
@riverpod
class KnowledgeNotesNotifier extends _$KnowledgeNotesNotifier {
  @override
  Future<List<KnowledgeNote>> build() async {
    final language = ref.watch(
      userSettingsNotifierProvider.select((s) => s.targetLanguage),
    );
    final service = ref.read(knowledgeNotesServiceProvider);
    await service.seedIfNeeded(language);
    return service.all(language);
  }

  Future<void> saveNote(KnowledgeNote note) async {
    await ref.read(knowledgeNotesServiceProvider).upsert(note);
    final current = [...?state.valueOrNull]
      ..removeWhere((n) => n.id == note.id)
      ..add(note)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    state = AsyncData(current);
  }

  Future<void> deleteNote(String id) async {
    await ref.read(knowledgeNotesServiceProvider).delete(id);
    final current = [...?state.valueOrNull]..removeWhere((n) => n.id == id);
    state = AsyncData(current);
  }

  Future<void> restoreStarters() async {
    final language = ref.read(
      userSettingsNotifierProvider.select((s) => s.targetLanguage),
    );
    await ref.read(knowledgeNotesServiceProvider).restoreStarters(language);
    ref.invalidateSelf();
    await future;
  }
}
