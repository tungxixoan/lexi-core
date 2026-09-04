import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../features/dictionary/domain/entities/language.dart';
import '../../features/practice/domain/entities/saved_exercise.dart';
import '../../features/vocabulary/domain/entities/cefr_level.dart';

/// Reads/writes the SAME Firestore collections the React web app uses, so a
/// saved AI exercise is shared across platforms:
///   - `users/{uid}/reading_exercises` — `bilingual` / `part5` / `part6` /
///     `part7` (apps/web/src/lib/savedReadingExercises.ts)
///   - `users/{uid}/listening_exercises` — `dictation` / `comprehension`
///     (apps/web/src/lib/savedListeningExercises.ts)
///
/// Doc body matches web exactly: `{type, body, generationFilters,
/// targetLanguage, createdAt, id}` where the body field is `passage` for
/// reading docs and `item` for listening docs (see [SavedExerciseType.bodyKey]
/// — web uses different keys per collection), and `id` is duplicated into the
/// body (web does the same via `setDoc(ref, {...record, id: ref.id})` — needed
/// for the Flutter Hive-cache sync that reads `json['id']` directly).
///
/// The body map is returned raw from [getRandom]; the caller decodes it with
/// the matching entity's `fromJson`.
class SavedExercisesService {
  SavedExercisesService({
    FirebaseFirestore? firestore,
    String? Function()? currentUid,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _currentUid =
            currentUid ?? (() => FirebaseAuth.instance.currentUser?.uid);

  final FirebaseFirestore _firestore;
  final String? Function() _currentUid;

  CollectionReference<Map<String, dynamic>> _collection(
    String uid,
    String name,
  ) =>
      _firestore.collection('users').doc(uid).collection(name);

  /// Writes a new saved-exercise doc; returns its id, or null if signed out.
  Future<String?> save({
    required SavedExerciseType type,
    required Map<String, dynamic> passageJson,
    required Map<String, dynamic> generationFilters,
    required Language targetLanguage,
  }) async {
    final uid = _currentUid();
    if (uid == null) return null;

    final ref = _collection(uid, type.collection).doc();
    await ref.set({
      'type': type.name,
      type.bodyKey: passageJson,
      'generationFilters': generationFilters,
      'targetLanguage': targetLanguage.name,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'id': ref.id,
    });
    return ref.id;
  }

  /// A random saved exercise of [type] whose stored `generationFilters` match
  /// [filters], excluding [excludeId]; null if none / signed out / offline.
  Future<({String id, Map<String, dynamic> passageJson})?> getRandom({
    required SavedExerciseType type,
    required Language targetLanguage,
    required Map<String, dynamic> filters,
    String? excludeId,
  }) async {
    final uid = _currentUid();
    if (uid == null) return null;

    try {
      final snap = await _collection(uid, type.collection)
          .where('targetLanguage', isEqualTo: targetLanguage.name)
          .get();

      final candidates = <({String id, Map<String, dynamic> passageJson})>[];
      for (final doc in snap.docs) {
        final data = doc.data();
        if (data['type'] != type.name) continue;

        final id = (data['id'] as String?) ?? doc.id;
        if (excludeId != null && id == excludeId) continue;

        final savedFilters = _asMap(data['generationFilters']);
        if (!_matches(type, savedFilters, filters)) continue;

        candidates.add((id: id, passageJson: _asMap(data[type.bodyKey])));
      }

      if (candidates.isEmpty) return null;
      candidates.shuffle();
      return candidates.first;
    } catch (_) {
      return null;
    }
  }

  /// Union of `passage.vocabIds` across every saved `bilingual` exercise —
  /// feeds `prioritizeUnusedWords` (web: `getAllUsedVocabIds`). Reads the whole
  /// `reading_exercises` collection, ignoring `part5|6|7` docs. `{}` if signed
  /// out / offline.
  Future<Set<String>> usedBilingualVocabIds() async {
    final uid = _currentUid();
    if (uid == null) return {};

    try {
      final snap = await _collection(uid, 'reading_exercises').get();
      final ids = <String>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        if (data['type'] != SavedExerciseType.bilingual.name) continue;
        final vocabIds =
            _asMap(data[SavedExerciseType.bilingual.bodyKey])['vocabIds'];
        if (vocabIds is List) {
          ids.addAll(vocabIds.map((e) => e.toString()));
        }
      }
      return ids;
    } catch (_) {
      return {};
    }
  }

  // --- Matching predicates — ported from web ---------------------------------

  bool _matches(
    SavedExerciseType type,
    Map<String, dynamic> saved,
    Map<String, dynamic> filters,
  ) {
    switch (type) {
      case SavedExerciseType.bilingual:
        return _matchesBilingual(saved, filters);
      case SavedExerciseType.part5:
      case SavedExerciseType.part6:
      case SavedExerciseType.part7:
        return _matchesToeic(saved, filters);
      case SavedExerciseType.dictation:
        return _matchesDictation(saved, filters);
      case SavedExerciseType.comprehension:
        return _matchesComprehension(saved, filters);
    }
  }

  /// web: `matchesBilingual` — topic overlap (enforced only when the filter
  /// lists topics), `maxCefr` ceiling by CEFR order (saved must be non-null and
  /// no higher than the filter), `wordCount` exact equality (both null counts
  /// as equal).
  bool _matchesBilingual(
    Map<String, dynamic> saved,
    Map<String, dynamic> filters,
  ) {
    final filterTopics = _stringList(filters['topicIds']);
    if (filterTopics.isNotEmpty) {
      final savedTopics = _stringList(saved['topicIds']);
      if (!savedTopics.any(filterTopics.contains)) return false;
    }

    final filterMaxCefr = filters['maxCefr'] as String?;
    if (filterMaxCefr != null) {
      final savedMaxCefr = saved['maxCefr'] as String?;
      if (savedMaxCefr == null) return false;
      if (_cefrIndex(savedMaxCefr) > _cefrIndex(filterMaxCefr)) return false;
    }

    if (saved['wordCount'] != filters['wordCount']) return false;
    return true;
  }

  /// web: `matchesToeic` — topic overlap (old docs lack `topicIds`, default to
  /// `[]`); `volumes` overlap enforced only when BOTH sides list volumes.
  bool _matchesToeic(
    Map<String, dynamic> saved,
    Map<String, dynamic> filters,
  ) {
    final filterTopics = _stringList(filters['topicIds']);
    if (filterTopics.isNotEmpty) {
      final savedTopics = _stringList(saved['topicIds']); // defaults to []
      if (!savedTopics.any(filterTopics.contains)) return false;
    }

    final filterVolumes = _stringList(filters['volumes']);
    final savedVolumes = _stringList(saved['volumes']);
    if (filterVolumes.isNotEmpty && savedVolumes.isNotEmpty) {
      if (!savedVolumes.any(filterVolumes.contains)) return false;
    }
    return true;
  }

  /// web: `matchesDictation` — `difficulty` exact equality.
  bool _matchesDictation(
    Map<String, dynamic> saved,
    Map<String, dynamic> filters,
  ) =>
      saved['difficulty'] == filters['difficulty'];

  /// `context` equal; `level` — null filter matches any, otherwise the saved
  /// `level` must be non-null and no higher than the filter by CEFR order.
  bool _matchesComprehension(
    Map<String, dynamic> saved,
    Map<String, dynamic> filters,
  ) {
    if (saved['context'] != filters['context']) return false;
    final filterLevel = filters['level'] as String?;
    if (filterLevel != null) {
      final savedLevel = saved['level'] as String?;
      if (savedLevel == null) return false;
      if (_cefrIndex(savedLevel) > _cefrIndex(filterLevel)) return false;
    }
    return true;
  }

  /// Web's `CEFR_ORDER.indexOf(...)` — position of a level name (`'a1'`..`'c2'`)
  /// in `CEFRLevel.values`; -1 for an unknown string (matches `indexOf`).
  int _cefrIndex(String name) =>
      CEFRLevel.values.indexWhere((l) => l.name == name);

  Map<String, dynamic> _asMap(Object? raw) =>
      raw is Map ? raw.cast<String, dynamic>() : <String, dynamic>{};

  List<String> _stringList(Object? raw) =>
      raw is List ? raw.map((e) => e.toString()).toList() : const <String>[];
}
