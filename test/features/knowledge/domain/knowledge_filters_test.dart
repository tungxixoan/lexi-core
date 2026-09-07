import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/knowledge/domain/entities/knowledge_note.dart';
import 'package:lexi_core/features/knowledge/domain/knowledge_filters.dart';

KnowledgeNote _n(String id, {
  String title = '', String explanation = '', String group = 'en_other',
  CEFRLevel? level, List<String> tags = const [],
}) {
  final t = DateTime.utc(2026, 1, 1);
  return KnowledgeNote(
    id: id, title: title, summary: '', explanation: explanation, groupId: group,
    tags: tags, cefrLevel: level, targetLanguage: Language.english,
    origin: KnowledgeNoteOrigin.manual, createdAt: t, updatedAt: t,
  );
}

void main() {
  final notes = [
    _n('a', title: 'Câu điều kiện loại 2', group: 'en_conditionals', level: CEFRLevel.b1, tags: ['toeic']),
    _n('b', title: 'Thì hiện tại đơn', group: 'en_tenses', level: CEFRLevel.a1),
    _n('c', explanation: 'nói về **điều kiện** trong quá khứ', group: 'en_conditionals', level: CEFRLevel.b2),
  ];

  test('query matches folded across fields', () {
    final r = applyKnowledgeFilter(notes,
        const KnowledgeFilter(query: 'dieu kien'));
    expect(r.map((n) => n.id), containsAll(['a', 'c']));
  });

  test('group + level filters AND across, OR within', () {
    final r = applyKnowledgeFilter(notes, const KnowledgeFilter(
      groupIds: {'en_conditionals'}, levels: {CEFRLevel.b1},
    ));
    expect(r.map((n) => n.id), ['a']);
  });

  test('tag filter', () {
    final r = applyKnowledgeFilter(notes, const KnowledgeFilter(tags: {'toeic'}));
    expect(r.map((n) => n.id), ['a']);
  });

  test('group counts and all tags', () {
    expect(knowledgeGroupCounts(notes)['en_conditionals'], 2);
    expect(knowledgeAllTags(notes), ['toeic']);
  });
}
