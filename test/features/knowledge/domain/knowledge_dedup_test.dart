import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/knowledge/domain/entities/knowledge_note.dart';
import 'package:lexi_core/features/knowledge/domain/knowledge_dedup.dart';

KnowledgeNote _n({
  required String id,
  required String title,
  String summary = '',
  List<String> tags = const [],
  String groupId = 'en_other',
}) {
  final t = DateTime.utc(2026, 1, 1);
  return KnowledgeNote(
    id: id, title: title, summary: summary, explanation: '',
    groupId: groupId, tags: tags, targetLanguage: Language.english,
    origin: KnowledgeNoteOrigin.manual, createdAt: t, updatedAt: t,
  );
}

void main() {
  test('matches on a repeated phrase in the title', () {
    final notes = [
      _n(id: 'a', title: 'Câu điều kiện loại 2 và 3'),
      _n(id: 'b', title: 'Mệnh đề quan hệ'),
    ];
    final hits = findRelatedNotes(
      prompt: 'giải thích câu điều kiện loại 2 khi nào dùng', notes: notes);
    expect(hits.map((n) => n.id), ['a']);
  });

  test('matches cross-diacritic (folded)', () {
    final notes = [_n(id: 'a', title: 'Câu điều kiện loại 2')];
    final hits = findRelatedNotes(prompt: 'cau dieu kien loai 2', notes: notes);
    expect(hits.single.id, 'a');
  });

  test('tag exact match scores', () {
    final notes = [_n(id: 'a', title: 'Ghi chú', tags: ['toeic'])];
    final hits = findRelatedNotes(prompt: 'ôn toeic phần này', notes: notes);
    expect(hits.single.id, 'a');
  });

  test('below threshold → no match', () {
    final notes = [_n(id: 'a', title: 'Mệnh đề quan hệ')];
    final hits = findRelatedNotes(prompt: 'thì hiện tại đơn', notes: notes);
    expect(hits, isEmpty);
  });

  test('"thì" / "thể" are content words, not stopwords', () {
    final notes = [_n(id: 'a', title: 'Thì thể')];
    // The only overlap is "thi"/"the" — if they were stopwords this scores 0.
    final hits = findRelatedNotes(prompt: 'thì thể', notes: notes);
    expect(hits.single.id, 'a');
  });

  test('caps at 3, sorted by score desc', () {
    final notes = [
      _n(id: 'a', title: 'thì hiện tại đơn'),
      _n(id: 'b', title: 'thì hiện tại tiếp diễn'),
      _n(id: 'c', title: 'thì hiện tại hoàn thành'),
      _n(id: 'd', title: 'thì quá khứ đơn'),
    ];
    final hits = findRelatedNotes(
        prompt: 'thì hiện tại đơn giải thích', notes: notes);
    expect(hits.length, 3);
    // "thi" (thì) is no longer a stopword, so note a matches the whole
    // "thi hien tai don" phrase and outscores the partial-phrase matches.
    expect(hits.first.id, 'a');
  });
}
