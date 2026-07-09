import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import '../../features/dictionary/domain/entities/user_settings_state.dart';

enum SyncStatus { idle, syncing, error }

class SyncService {
  SyncService({required this.vocabBox, required this.topicsBox});

  final Box<String> vocabBox;
  final Box<String> topicsBox;

  final _firestoreUpdatingVocab = <String>{};
  final _firestoreUpdatingTopic = <String>{};

  // headword|language → local Hive id  (O(1) duplicate detection)
  final Map<String, String> _headwordIndex = {};
  // local Hive id → headword|language  (O(1) reverse lookup for deletes)
  final Map<String, String> _idToHeadwordKey = {};

  StreamSubscription? _vocabHiveSub;
  StreamSubscription? _topicHiveSub;
  StreamSubscription? _firestoreVocabSub;
  StreamSubscription? _firestoreTopicSub;

  void _buildHeadwordIndex() {
    _headwordIndex.clear();
    _idToHeadwordKey.clear();
    for (final raw in vocabBox.values) {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final id = m['id'] as String;
      final key = '${m['headword']}|${m['targetLanguage']}';
      _headwordIndex[key] = id;
      _idToHeadwordKey[id] = key;
    }
  }

  Future<void> startSync(
    String uid,
    UserSettingsState settings,
    void Function(SyncStatus) onStatus,
  ) async {
    final db = FirebaseFirestore.instance;
    final vocabCol =
        db.collection('users').doc(uid).collection('vocab_records');
    final topicsCol = db.collection('users').doc(uid).collection('topics');
    final userDoc = db.collection('users').doc(uid);

    onStatus(SyncStatus.syncing);

    _buildHeadwordIndex();

    try {
      var batch = db.batch();
      var count = 0;

      for (final raw in vocabBox.values) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        batch.set(vocabCol.doc(map['id'] as String), map);
        count++;
        if (count == 500) {
          await batch.commit();
          batch = db.batch();
          count = 0;
        }
      }

      for (final raw in topicsBox.values) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        batch.set(topicsCol.doc(map['id'] as String), map);
        count++;
        if (count == 500) {
          await batch.commit();
          batch = db.batch();
          count = 0;
        }
      }

      batch.set(userDoc, {
        'targetLanguage': settings.targetLanguage.name,
        'activeContext': settings.activeContext.name,
        'aiEnabled': settings.aiEnabled,
        if (settings.targetCefrLevel != null)
          'targetCefrLevel': settings.targetCefrLevel!.name,
      });
      count++;

      if (count > 0) await batch.commit();
    } catch (e) {
      dev.log('SyncService: initial push failed: $e');
      onStatus(SyncStatus.error);
      return;
    }

    // Firestore vocab → Hive
    _firestoreVocabSub = vocabCol.snapshots().listen(
      (snapshot) {
        for (final change in snapshot.docChanges) {
          final id = change.doc.id;

          if (change.type == DocumentChangeType.removed) {
            _firestoreUpdatingVocab.add(id);
            () async {
              try {
                await vocabBox.delete(id);
                final hwKey = _idToHeadwordKey.remove(id);
                if (hwKey != null) _headwordIndex.remove(hwKey);
              } catch (e) {
                dev.log('SyncService: Hive vocab delete failed: $e');
              } finally {
                _firestoreUpdatingVocab.remove(id);
              }
            }();
            continue;
          }

          final remoteMap = change.doc.data()!;
          final localRaw = vocabBox.get(id);

          if (localRaw != null) {
            // Same id — keep newer version
            final localMap = jsonDecode(localRaw) as Map<String, dynamic>;
            final remoteAt =
                DateTime.parse(remoteMap['updatedAt'] as String);
            final localAt =
                DateTime.parse(localMap['updatedAt'] as String);
            if (remoteAt.isAfter(localAt)) {
              _firestoreUpdatingVocab.add(id);
              vocabBox.put(id, jsonEncode(remoteMap)).then((_) {
                _firestoreUpdatingVocab.remove(id);
              }).catchError((e) {
                _firestoreUpdatingVocab.remove(id);
                dev.log('SyncService: Hive vocab write failed: $e');
              });
            }
            continue;
          }

          // Doc not in Hive by id — check headword collision
          final hwKey =
              '${remoteMap['headword']}|${remoteMap['targetLanguage']}';
          final existingLocalId = _headwordIndex[hwKey];

          if (existingLocalId != null) {
            // Race-condition duplicate: same headword+language, different id
            final existingRaw = vocabBox.get(existingLocalId);
            if (existingRaw != null) {
              final localMap =
                  jsonDecode(existingRaw) as Map<String, dynamic>;
              final localAt =
                  DateTime.parse(localMap['updatedAt'] as String);
              final remoteAt =
                  DateTime.parse(remoteMap['updatedAt'] as String);

              if (!remoteAt.isAfter(localAt)) {
                // Local is newer or equal — discard the Firebase duplicate
                vocabCol.doc(id).delete().catchError((e) =>
                    dev.log('SyncService: dedup Firebase delete failed: $e'));
              } else {
                // Firebase is newer — replace local with Firebase version
                _firestoreUpdatingVocab.add(id);
                _firestoreUpdatingVocab.add(existingLocalId);
                () async {
                  try {
                    // Remove old local entry from Hive + Firestore
                    await vocabBox.delete(existingLocalId);
                    _idToHeadwordKey.remove(existingLocalId);
                    _headwordIndex.remove(hwKey);
                    await vocabCol.doc(existingLocalId).delete();
                    // Write Firebase version into Hive
                    await vocabBox.put(id, jsonEncode(remoteMap));
                    _headwordIndex[hwKey] = id;
                    _idToHeadwordKey[id] = hwKey;
                  } catch (e) {
                    dev.log('SyncService: dedup replace failed: $e');
                  } finally {
                    _firestoreUpdatingVocab.remove(id);
                    _firestoreUpdatingVocab.remove(existingLocalId);
                  }
                }();
              }
            }
            continue;
          }

          // Genuinely new word from Firebase
          _firestoreUpdatingVocab.add(id);
          vocabBox.put(id, jsonEncode(remoteMap)).then((_) {
            _headwordIndex[hwKey] = id;
            _idToHeadwordKey[id] = hwKey;
            _firestoreUpdatingVocab.remove(id);
          }).catchError((e) {
            _firestoreUpdatingVocab.remove(id);
            dev.log('SyncService: Hive vocab write failed: $e');
          });
        }
      },
      onError: (e) =>
          dev.log('SyncService: Firestore vocab stream error: $e'),
    );

    // Hive vocab → Firestore
    _vocabHiveSub = vocabBox.watch().listen((event) {
      final key = event.key as String;
      if (_firestoreUpdatingVocab.contains(key)) return;
      if (event.deleted) {
        final hwKey = _idToHeadwordKey.remove(key);
        if (hwKey != null) _headwordIndex.remove(hwKey);
        vocabCol.doc(key).delete().catchError((e) =>
            dev.log('SyncService: Firestore vocab delete failed: $e'));
      } else {
        final map =
            jsonDecode(event.value as String) as Map<String, dynamic>;
        final hwKey = '${map['headword']}|${map['targetLanguage']}';
        _headwordIndex[hwKey] = key;
        _idToHeadwordKey[key] = hwKey;
        vocabCol.doc(key).set(map).catchError((e) =>
            dev.log('SyncService: Firestore vocab write failed: $e'));
      }
    });

    // Firestore topics → Hive
    _firestoreTopicSub = topicsCol.snapshots().listen(
      (snapshot) {
        for (final change in snapshot.docChanges) {
          final id = change.doc.id;
          if (change.type == DocumentChangeType.removed) {
            _firestoreUpdatingTopic.add(id);
            () async {
              try {
                await topicsBox.delete(id);
              } catch (e) {
                dev.log('SyncService: Hive topic delete failed: $e');
              } finally {
                _firestoreUpdatingTopic.remove(id);
              }
            }();
          } else {
            final localRaw = topicsBox.get(id);
            if (localRaw == null) {
              _firestoreUpdatingTopic.add(id);
              topicsBox
                  .put(id, jsonEncode(change.doc.data()))
                  .then((_) => _firestoreUpdatingTopic.remove(id))
                  .catchError((e) => _firestoreUpdatingTopic.remove(id));
            }
          }
        }
      },
      onError: (e) =>
          dev.log('SyncService: Firestore topics stream error: $e'),
    );

    // Hive topics → Firestore
    _topicHiveSub = topicsBox.watch().listen((event) {
      final key = event.key as String;
      if (_firestoreUpdatingTopic.contains(key)) return;
      if (event.deleted) {
        topicsCol.doc(key).delete().catchError((e) =>
            dev.log('SyncService: Firestore topic delete failed: $e'));
      } else {
        final map =
            jsonDecode(event.value as String) as Map<String, dynamic>;
        topicsCol.doc(key).set(map).catchError((e) =>
            dev.log('SyncService: Firestore topic write failed: $e'));
      }
    });

    onStatus(SyncStatus.idle);
  }

  void stopSync() {
    _vocabHiveSub?.cancel();
    _topicHiveSub?.cancel();
    _firestoreVocabSub?.cancel();
    _firestoreTopicSub?.cancel();
    _vocabHiveSub = null;
    _topicHiveSub = null;
    _firestoreVocabSub = null;
    _firestoreTopicSub = null;
    _firestoreUpdatingVocab.clear();
    _firestoreUpdatingTopic.clear();
    _headwordIndex.clear();
    _idToHeadwordKey.clear();
  }
}
