import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  HiveMigrationService({FirebaseFirestore? firestore, SharedPreferences? prefs})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _prefs = prefs;

  final FirebaseFirestore _firestore;
  final SharedPreferences? _prefs;

  static const _vocabBoxName = 'vocab_records';
  static const _topicsBoxName = 'topics';
  static String _migratedFlagKey(String uid) => 'hive_migrated_$uid';

  /// Returns true if a migration actually happened (either box had data).
  Future<bool> migrateIfNeeded(String uid) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    if (prefs.getBool(_migratedFlagKey(uid)) ?? false) return false;

    final vocabCol = _firestore.collection('users').doc(uid).collection('vocab_records');
    final topicsCol = _firestore.collection('users').doc(uid).collection('topics');

    // Only ever migrate into a genuinely empty account — if this uid
    // already has vocab data on Firestore, this is a returning user whose
    // Hive box is a stale local mirror (from the old SyncService), not
    // their only copy. Pushing it would silently overwrite any edits made
    // elsewhere (e.g. apps/web/) since the last sync and resurrect
    // anything deleted there. Just mark it migrated and stop — the real
    // data is already safely on Firestore. Deliberately don't touch the
    // Hive boxes at all in this branch (not even to clear them) — that
    // stays safe to clean up later rather than risking data loss now.
    final existing = await vocabCol.limit(1).get();
    if (existing.docs.isNotEmpty) {
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

    var batch = _firestore.batch();
    var count = 0;

    for (final raw in vocabBox.values) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        batch.set(vocabCol.doc(map['id'] as String), map);
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
