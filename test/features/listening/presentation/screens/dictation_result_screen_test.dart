import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lexi_core/core/di/app_providers.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/topic.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/vocab_record.dart';
import 'package:lexi_core/features/vocabulary/domain/repositories/vocab_repository.dart';
import 'package:lexi_core/features/listening/domain/entities/dictation_item.dart';
import 'package:lexi_core/features/listening/presentation/providers/dictation_practice_provider.dart';
import 'package:lexi_core/features/listening/presentation/screens/dictation_result_screen.dart';

VocabRecord _record(String id) => VocabRecord(
      id: id,
      headword: id,
      inputType: InputType.word,
      ipa: '',
      meaning: 'meaning of $id',
      examples: const [],
      personalNotes: '',
      topicIds: const [],
      targetLanguage: Language.english,
      cefrLevel: CEFRLevel.b1,
      activeContext: AppContext.general,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

class _CapturingVocabRepository implements VocabRepository {
  _CapturingVocabRepository(this.records);
  final List<VocabRecord> records;
  final List<VocabRecord> updated = [];

  @override
  Future<List<VocabRecord>> getAll({
    String? topicId,
    InputType? inputType,
    Language? language,
    CEFRLevel? maxCefrLevel,
    bool dueOnly = false,
  }) async =>
      records;

  @override
  Future<List<Topic>> getTopics() async => const [];

  @override
  Future<void> save(VocabRecord record) async {}

  @override
  Future<VocabRecord?> getById(String id) async => null;

  @override
  Future<void> update(VocabRecord record) async {
    updated.add(record);
  }

  @override
  Future<void> delete(String id) async {}

  @override
  Future<bool> existsByHeadword(String headword, Language language) async =>
      false;

  @override
  Future<VocabRecord?> getByHeadword(String headword, Language language) async =>
      null;

  @override
  Future<void> addTopic(Topic topic) async {}

  @override
  Future<void> deleteTopic(String id) async {}
}

final _testItem = DictationItem(
  id: 'item-1',
  target: 'Hello world.',
  vietnamese: 'Xin chào thế giới.',
  vocabIds: const ['id1', 'id2'],
  level: CEFRLevel.b1,
  context: AppContext.general,
  targetLanguage: Language.english,
  generatedAt: DateTime(2026),
);

final _perfectResult = DictationSessionResult(
  item: _testItem,
  typed: 'Hello world.',
  replayCount: 0,
  duration: const Duration(seconds: 5),
);

Widget _buildResult(
  DictationSessionResult result,
  _CapturingVocabRepository repo,
) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, state) => DictationResultScreen(result: result),
      ),
      GoRoute(
        path: '/listening/dictation',
        builder: (ctx, state) => const Scaffold(body: Text('Dictation home')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      vocabRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('shows the final score percentage', (tester) async {
    final repo = _CapturingVocabRepository([_record('id1'), _record('id2')]);
    await tester.pumpWidget(_buildResult(_perfectResult, repo));
    await tester.pumpAndSettle();
    expect(find.textContaining('100'), findsWidgets); // 100% score
  });

  testWidgets('shows the target sentence and Vietnamese translation', (tester) async {
    final repo = _CapturingVocabRepository([_record('id1'), _record('id2')]);
    await tester.pumpWidget(_buildResult(_perfectResult, repo));
    await tester.pumpAndSettle();
    expect(find.textContaining('Hello world.'), findsWidgets);
    expect(find.text('Xin chào thế giới.'), findsOneWidget);
  });

  testWidgets('shows Câu khác and Về trang chính buttons', (tester) async {
    final repo = _CapturingVocabRepository([_record('id1'), _record('id2')]);
    await tester.pumpWidget(_buildResult(_perfectResult, repo));
    await tester.pumpAndSettle();
    expect(find.text('Câu khác'), findsOneWidget);
    expect(find.text('Về trang chính'), findsOneWidget);
  });

  testWidgets('updates SM-2 for every vocab word used in the sentence', (tester) async {
    final repo = _CapturingVocabRepository([_record('id1'), _record('id2')]);
    await tester.pumpWidget(_buildResult(_perfectResult, repo));
    await tester.pumpAndSettle();

    expect(repo.updated.length, 2);
    expect(repo.updated.map((r) => r.id), containsAll(['id1', 'id2']));
    // finalScore is 1.0 -> quality 5 -> quality >= 3 branch -> repetitions 0 -> 1
    for (final r in repo.updated) {
      expect(r.sm2Repetitions, 1);
      expect(r.nextReviewAt, isNotNull);
    }
  });
}
