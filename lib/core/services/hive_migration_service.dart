import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/dictionary/domain/entities/language.dart';
import '../../features/vocabulary/data/repositories/vocab_repository_impl.dart';
import '../../features/vocabulary/domain/entities/vocab_record.dart';
import '../../features/vocabulary/domain/repositories/vocab_repository.dart';

/// One-time push of any pre-existing local Hive vocab/topics data into a
/// newly-authenticated user's Firestore collections. Only relevant for a
/// user who used the app before sign-in became mandatory and never signed
/// in (so their data lived only in Hive, never reached Firestore via the
/// old SyncService). A user who already signed in at least once already
/// has this data on Firestore via that prior sync — this is a safety net,
/// not the primary data path going forward.
///
/// Self-contained: opens the Hive boxes itself (idempotent — Hive.openBox
/// is a no-op returning the existing instance if already open) rather than
/// requiring the app to keep them open at startup, since normal app
/// startup no longer opens Hive at all once this migration path is the
/// only remaining Hive consumer.
///
/// Also tracks completion per-uid in SharedPreferences, so a second sign-in
/// on the same or a different device never re-pushes (and potentially
/// overwrites newer Firestore data with stale local Hive data) once a
/// migration has already succeeded for that account.
class HiveMigrationService {
  HiveMigrationService({
    FirebaseFirestore? firestore,
    SharedPreferences? prefs,
    VocabRepository Function(String uid)? vocabRepositoryBuilder,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _prefs = prefs,
        _vocabRepositoryBuilder = vocabRepositoryBuilder;

  final FirebaseFirestore _firestore;
  final SharedPreferences? _prefs;

  /// Test seam: lets tests substitute a fake/mock [VocabRepository] (e.g.
  /// one whose `save()` throws) without needing a real Firestore write
  /// failure, which `FakeFirebaseFirestore` has no way to simulate. Defaults
  /// to the real [VocabRepositoryImpl] wired to [_firestore].
  final VocabRepository Function(String uid)? _vocabRepositoryBuilder;

  static const _vocabBoxName = 'vocab_records';
  static const _topicsBoxName = 'topics';
  static String _migratedFlagKey(String uid) => 'hive_migrated_$uid';

  /// Returns true if any of the per-language `vocab_records_{language}`
  /// collections already has at least one document for this uid.
  ///
  /// Vocab records now live in per-language collections
  /// (`vocab_records_english`, `vocab_records_chinese`, ...) rather than
  /// the old flat `vocab_records` collection, so "does this user already
  /// have vocab data on Firestore" must check every per-language
  /// collection, not the now-dead flat one.
  Future<bool> _hasExistingVocabData(String uid) async {
    for (final language in Language.values) {
      final col = _firestore
          .collection('users')
          .doc(uid)
          .collection('vocab_records_${language.name}');
      final snapshot = await col.limit(1).get();
      if (snapshot.docs.isNotEmpty) return true;
    }
    return false;
  }

  /// Returns true if a migration actually happened (either box had data).
  Future<bool> migrateIfNeeded(String uid) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    if (prefs.getBool(_migratedFlagKey(uid)) ?? false) return false;

    final topicsCol =
        _firestore.collection('users').doc(uid).collection('topics');

    // Only ever migrate into a genuinely empty account — if this uid
    // already has vocab data on Firestore, this is a returning user whose
    // Hive box is a stale local mirror (from the old SyncService), not
    // their only copy. Pushing it would silently overwrite any edits made
    // elsewhere (e.g. apps/web/) since the last sync and resurrect
    // anything deleted there. Just mark it migrated and stop — the real
    // data is already safely on Firestore. Deliberately don't touch the
    // Hive boxes at all in this branch (not even to clear them) — that
    // stays safe to clean up later rather than risking data loss now.
    if (await _hasExistingVocabData(uid)) {
      await prefs.setBool(_migratedFlagKey(uid), true);
      return false;
    }

    await Hive.initFlutter();
    final vocabBox = await Hive.openBox<String>(_vocabBoxName);
    final topicsBox = await Hive.openBox<String>(_topicsBoxName);

    if (vocabBox.isEmpty && topicsBox.isEmpty) {
      await prefs.setBool(_migratedFlagKey(uid), true);
      return false;
    }

    // Vocab records are routed through VocabRepositoryImpl.save (rather than
    // raw batch.set into a flat collection) so each record lands in the
    // correct per-language collection, the same as every other vocab write
    // in the app since the per-language split.
    final vocabRepo = _vocabRepositoryBuilder != null
        ? _vocabRepositoryBuilder(uid)
        : VocabRepositoryImpl(uid: uid, firestore: _firestore);
    for (final raw in vocabBox.values) {
      VocabRecord record;
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        record = VocabRecord.fromJson(map);
      } catch (_) {
        // Skip one malformed/legacy record (bad JSON, or JSON that fails to
        // parse into a well-formed VocabRecord) rather than aborting the
        // whole migration over it.
        continue;
      }
      // Deliberately NOT inside the catch above: a Firestore write failure
      // here (permission-denied, network, resource-exhausted, ...) is a
      // real, worth-surfacing failure, not a malformed-record skip. Let it
      // propagate out of migrateIfNeeded entirely so the caller's error UI
      // (sign_in_screen.dart's try/catch + "Thử lại" retry) can show it,
      // instead of silently discarding the user's only copy of this data.
      await vocabRepo.save(record);
    }

    // Topics stay a single shared collection across all languages —
    // unaffected by the vocab-records split — so raw batch writes remain
    // fine here.
    var batch = _firestore.batch();
    var count = 0;
    for (final raw in topicsBox.values) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        batch.set(topicsCol.doc(map['id'] as String), map);
        count++;
        if (count == 500) {
          await batch.commit();
          batch = _firestore.batch();
          count = 0;
        }
      } catch (_) {
        // Skip one malformed/legacy record rather than aborting the
        // whole migration over it.
      }
    }
    if (count > 0) await batch.commit();

    await vocabBox.clear();
    await topicsBox.clear();
    await prefs.setBool(_migratedFlagKey(uid), true);
    return true;
  }
}
