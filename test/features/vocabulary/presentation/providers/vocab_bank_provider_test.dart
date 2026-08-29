// test/features/vocabulary/presentation/providers/vocab_bank_provider_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/di/app_providers.dart';
import 'package:lexi_core/features/dictionary/domain/entities/ai_provider.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/dictionary/domain/entities/user_settings_state.dart';
import 'package:lexi_core/features/dictionary/presentation/providers/user_settings_provider.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/topic.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/vocab_record.dart';
import 'package:lexi_core/features/vocabulary/domain/repositories/vocab_repository.dart';
import 'package:lexi_core/features/vocabulary/presentation/providers/vocab_bank_provider.dart';

class _FakeSettingsNotifier extends UserSettingsNotifier {
  _FakeSettingsNotifier(this._state);
  final UserSettingsState _state;
  @override
  UserSettingsState build() => _state;
}

UserSettingsState _settings(Language language) => UserSettingsState(
      targetLanguage: language,
      activeContext: AppContext.general,
      aiEnabled: false,
      activeProvider: AiProvider.gemini,
      providerConfigs: const {},
    );

VocabRecord _record(String id, {Language language = Language.english}) => VocabRecord(
      id: id,
      headword: id,
      inputType: InputType.word,
      ipa: '',
      meaning: 'meaning of $id',
      examples: const [],
      personalNotes: '',
      topicIds: const [],
      targetLanguage: language,
      cefrLevel: CEFRLevel.b1,
      activeContext: AppContext.general,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

/// In-memory VocabRepository that actually mutates its backing list on
/// save(), so a re-fetch after a save can observe the newly added record —
/// unlike a repository stubbed to always return the same fixed list.
class _FakeVocabRepository implements VocabRepository {
  _FakeVocabRepository(List<VocabRecord> initial) : records = List.of(initial);
  final List<VocabRecord> records;

  @override
  Future<List<VocabRecord>> getAll({
    required Language language,
    String? topicId,
    InputType? inputType,
    CEFRLevel? maxCefrLevel,
    bool dueOnly = false,
  }) async =>
      records.where((r) => r.targetLanguage == language).toList();

  @override
  Future<void> save(VocabRecord record) async {
    records.add(record);
  }

  @override
  Future<VocabRecord?> getById(String id, {required Language language}) async {
    for (final r in records) {
      if (r.id == id && r.targetLanguage == language) return r;
    }
    return null;
  }

  @override
  Future<void> update(VocabRecord record) async {
    records.removeWhere((r) => r.id == record.id);
    records.add(record);
  }

  @override
  Future<void> delete(String id, {required Language language}) async {
    records.removeWhere((r) => r.id == id && r.targetLanguage == language);
  }

  @override
  Future<bool> existsByHeadword(String headword, Language language) async =>
      records.any((r) =>
          r.targetLanguage == language &&
          r.headword.toLowerCase() == headword.toLowerCase());

  @override
  Future<VocabRecord?> getByHeadword(String headword, Language language) async {
    final lc = headword.toLowerCase();
    for (final r in records) {
      if (r.targetLanguage == language && r.headword.toLowerCase() == lc) return r;
    }
    return null;
  }

  @override
  Future<List<Topic>> getTopics() async => const [];

  @override
  Future<void> addTopic(Topic topic) async {}

  @override
  Future<void> deleteTopic(String id) async {}
}

void main() {
  test(
      'vocabListForLanguageProvider refetches after VocabBankNotifier.save so a newly'
      ' saved word appears, instead of returning a list cached from the first read',
      () async {
    final repo = _FakeVocabRepository([_record('v1')]);
    final container = ProviderContainer(overrides: [
      vocabRepositoryProvider.overrideWithValue(repo),
      userSettingsNotifierProvider
          .overrideWith(() => _FakeSettingsNotifier(_settings(Language.english))),
    ]);
    addTearDown(container.dispose);

    // Keep the family provider alive across the save via an active listener
    // (autoDispose alone — without also depending on the invalidation
    // signal — would only refetch once GC'd between reads, which wouldn't
    // prove this provider actually reacts to a save/update/delete).
    final sub =
        container.listen(vocabListForLanguageProvider(Language.english), (_, __) {});
    addTearDown(sub.close);

    final before =
        await container.read(vocabListForLanguageProvider(Language.english).future);
    expect(before.map((r) => r.id), ['v1']);

    await container.read(vocabBankNotifierProvider.notifier).save(_record('v2'));

    final after =
        await container.read(vocabListForLanguageProvider(Language.english).future);
    expect(after.map((r) => r.id).toSet(), {'v1', 'v2'});
  });
}
