import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

/// One-time push of any pre-existing local Hive vocab/topics data into a
/// newly-authenticated user's Firestore collections. Only relevant for a
/// user who used the app before sign-in became mandatory and never signed
/// in (so their data lived only in Hive, never reached Firestore via the
/// old SyncService). A user who already signed in at least once already
/// has this data on Firestore via that prior sync — this is a safety net,
/// not the primary data path going forward.
class HiveMigrationService {
  HiveMigrationService({
    required this.vocabBox,
    required this.topicsBox,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final Box<String> vocabBox;
  final Box<String> topicsBox;
  final FirebaseFirestore _firestore;

  /// Returns true if a migration actually happened (either box had data).
  Future<bool> migrateIfNeeded(String uid) async {
    if (vocabBox.isEmpty && topicsBox.isEmpty) return false;

    final vocabCol = _firestore.collection('users').doc(uid).collection('vocab_records');
    final topicsCol = _firestore.collection('users').doc(uid).collection('topics');

    var batch = _firestore.batch();
    var count = 0;

    for (final raw in vocabBox.values) {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      batch.set(vocabCol.doc(map['id'] as String), map);
      count++;
      if (count == 500) {
        await batch.commit();
        batch = _firestore.batch();
        count = 0;
      }
    }

    for (final raw in topicsBox.values) {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      batch.set(topicsCol.doc(map['id'] as String), map);
      count++;
      if (count == 500) {
        await batch.commit();
        batch = _firestore.batch();
        count = 0;
      }
    }

    if (count > 0) await batch.commit();

    await vocabBox.clear();
    await topicsBox.clear();
    return true;
  }
}
