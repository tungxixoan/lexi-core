import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/knowledge/data/knowledge_notes_service.dart';
import 'package:lexi_core/features/knowledge/data/knowledge_starter_library.dart';
import 'package:lexi_core/features/knowledge/domain/entities/knowledge_note.dart';

const _uid = 'u1';

KnowledgeNote _note(String id,
    {String lang = 'english', String group = 'en_other'}) {
  final t = DateTime.utc(2026, 1, 1);
  return KnowledgeNote(
    id: id,
    title: 'T $id',
    summary: 's',
    explanation: 'e',
    groupId: group,
    targetLanguage: Language.values.byName(lang),
    origin: KnowledgeNoteOrigin.manual,
    createdAt: t,
    updatedAt: t,
  );
}

KnowledgeNotesService _svc(
  FakeFirebaseFirestore fs, {
  String? uid = _uid,
  KnowledgeStarterLibrary? starter,
}) =>
    KnowledgeNotesService(
      firestore: fs,
      currentUid: () => uid,
      starterLibrary:
          starter ?? KnowledgeStarterLibrary(loadAsset: (_) async => '[]'),
    );

void main() {
  test('upsert then all() round-trips and filters by language', () async {
    final fs = FakeFirebaseFirestore();
    final svc = _svc(fs);
    await svc.upsert(_note('a'));
    await svc.upsert(_note('b', lang: 'chinese'));
    final en = await svc.all(Language.english);
    expect(en.map((n) => n.id), ['a']);
  });

  test('all() sorts by updatedAt desc', () async {
    final fs = FakeFirebaseFirestore();
    final svc = _svc(fs);
    await svc.upsert(_note('old').copyWith(updatedAt: DateTime.utc(2026, 1, 1)));
    await svc.upsert(_note('new').copyWith(updatedAt: DateTime.utc(2026, 6, 1)));
    final all = await svc.all(Language.english);
    expect(all.map((n) => n.id), ['new', 'old']);
  });

  test('delete removes the doc', () async {
    final fs = FakeFirebaseFirestore();
    final svc = _svc(fs);
    await svc.upsert(_note('a'));
    await svc.delete('a');
    expect(await svc.all(Language.english), isEmpty);
  });

  test('seedIfNeeded seeds once, respects the flag', () async {
    final fs = FakeFirebaseFirestore();
    final svc = KnowledgeNotesService(
      firestore: fs,
      currentUid: () => _uid,
      starterLibrary: _StubStarter([_note('starter_en_x')]),
    );
    final first = await svc.seedIfNeeded(Language.english);
    expect(first.map((n) => n.id), ['starter_en_x']);
    final second = await svc.seedIfNeeded(Language.english);
    expect(second, isEmpty); // flag set
    expect((await svc.all(Language.english)).length, 1);
  });

  test('seedIfNeeded does not seed when the collection is non-empty', () async {
    final fs = FakeFirebaseFirestore();
    final svc = KnowledgeNotesService(
      firestore: fs,
      currentUid: () => _uid,
      starterLibrary: _StubStarter([_note('starter_en_x')]),
    );
    await svc.upsert(_note('user1'));
    final seeded = await svc.seedIfNeeded(Language.english);
    expect(seeded, isEmpty);
  });

  test('restoreStarters re-adds only absent ids, keeps edited ones', () async {
    final fs = FakeFirebaseFirestore();
    final svc = KnowledgeNotesService(
      firestore: fs,
      currentUid: () => _uid,
      starterLibrary: _StubStarter([
        _note('starter_en_a'),
        _note('starter_en_b'),
      ]),
    );
    await svc.upsert(_note('starter_en_a').copyWith(title: 'MY EDIT'));
    final restored = await svc.restoreStarters(Language.english);
    expect(restored.map((n) => n.id), ['starter_en_b']);
    final a = (await svc.all(Language.english))
        .firstWhere((n) => n.id == 'starter_en_a');
    expect(a.title, 'MY EDIT'); // untouched
  });

  test('signed out: all() empty, upsert no-op', () async {
    final fs = FakeFirebaseFirestore();
    final svc = _svc(fs, uid: null);
    await svc.upsert(_note('a'));
    expect(await svc.all(Language.english), isEmpty);
  });
}

class _StubStarter implements KnowledgeStarterLibrary {
  _StubStarter(this._notes);
  final List<KnowledgeNote> _notes;
  @override
  Future<List<KnowledgeNote>> notesFor(Language language) async =>
      language == Language.english ? _notes : [];
}
