import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../dictionary/domain/entities/language.dart';
import '../domain/entities/knowledge_note.dart';
import 'knowledge_starter_library.dart';

/// Reads/writes `users/{uid}/knowledge_notes` directly (no Hive, no
/// SyncService) — same shape/trust model as SavedExercisesService. The
/// per-language "already seeded" flag lives in
/// `users/{uid}/knowledge_meta/seed` (one bool field per [Language.name]).
///
/// All methods no-op / return a safe default when signed out, and every
/// Firestore read is wrapped in try/catch so an offline failure degrades to
/// an empty result rather than throwing.
class KnowledgeNotesService {
  KnowledgeNotesService({
    FirebaseFirestore? firestore,
    String? Function()? currentUid,
    KnowledgeStarterLibrary? starterLibrary,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _currentUid =
            currentUid ?? (() => FirebaseAuth.instance.currentUser?.uid),
        _starter = starterLibrary ?? KnowledgeStarterLibrary();

  final FirebaseFirestore _firestore;
  final String? Function() _currentUid;
  final KnowledgeStarterLibrary _starter;

  CollectionReference<Map<String, dynamic>>? _notes() {
    final uid = _currentUid();
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).collection('knowledge_notes');
  }

  DocumentReference<Map<String, dynamic>>? _seedDoc() {
    final uid = _currentUid();
    if (uid == null) return null;
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('knowledge_meta')
        .doc('seed');
  }

  /// Every note whose `targetLanguage` matches [language], newest first.
  Future<List<KnowledgeNote>> all(Language language) async {
    final col = _notes();
    if (col == null) return const [];
    try {
      final snap = await col.get();
      final notes = snap.docs
          .map((d) => d.data())
          .where((m) => m['targetLanguage'] == language.name)
          .map(KnowledgeNote.fromJson)
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return notes;
    } catch (_) {
      return const [];
    }
  }

  /// Creates or replaces the note at `knowledge_notes/{note.id}`.
  Future<void> upsert(KnowledgeNote note) async {
    final col = _notes();
    if (col == null) return;
    try {
      await col.doc(note.id).set(note.toJson());
    } catch (_) {/* best-effort */}
  }

  Future<void> delete(String id) async {
    final col = _notes();
    if (col == null) return;
    try {
      await col.doc(id).delete();
    } catch (_) {/* best-effort */}
  }

  /// First-run seeding for [language]: if the seed flag is not `true` and the
  /// language has no notes yet, writes every starter note and sets the flag.
  /// Returns the notes it wrote (`[]` if nothing was seeded). Best-effort.
  Future<List<KnowledgeNote>> seedIfNeeded(Language language) async {
    final col = _notes();
    final seedDoc = _seedDoc();
    if (col == null || seedDoc == null) return const [];
    try {
      final flag = (await seedDoc.get()).data()?[language.name] == true;
      if (flag) return const [];

      final existing = await col.get();
      final hasNotesForLanguage = existing.docs
          .any((d) => d.data()['targetLanguage'] == language.name);
      if (hasNotesForLanguage) {
        // Language already has notes — mark seeded, write nothing.
        await seedDoc.set({language.name: true}, SetOptions(merge: true));
        return const [];
      }

      final written = await _writeMissing(col, language);
      await seedDoc.set({language.name: true}, SetOptions(merge: true));
      return written;
    } catch (_) {
      return const [];
    }
  }

  /// Re-adds any starter note for [language] whose id is missing from the
  /// collection; never overwrites an existing (possibly user-edited) note.
  /// Returns what it wrote.
  Future<List<KnowledgeNote>> restoreStarters(Language language) async {
    final col = _notes();
    if (col == null) return const [];
    try {
      return await _writeMissing(col, language);
    } catch (_) {
      return const [];
    }
  }

  Future<List<KnowledgeNote>> _writeMissing(
    CollectionReference<Map<String, dynamic>> col,
    Language language,
  ) async {
    final starters = await _starter.notesFor(language);
    if (starters.isEmpty) return const [];
    final existingIds = (await col.get()).docs.map((d) => d.id).toSet();
    final toWrite =
        starters.where((n) => !existingIds.contains(n.id)).toList();
    for (final n in toWrite) {
      await col.doc(n.id).set(n.toJson());
    }
    return toWrite;
  }
}
