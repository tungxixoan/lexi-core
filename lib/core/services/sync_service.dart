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

  // Keys being written from Firestore → Hive — prevents echo back to Firestore
  final _firestoreUpdatingVocab = <String>{};
  final _firestoreUpdatingTopic = <String>{};

  StreamSubscription? _vocabHiveSub;
  StreamSubscription? _topicHiveSub;
  StreamSubscription? _firestoreVocabSub;
  StreamSubscription? _firestoreTopicSub;

  Future<void> startSync(
    String uid,
    UserSettingsState settings,
    void Function(SyncStatus) onStatus,
  ) async {
    final db = FirebaseFirestore.instance;
    final vocabCol = db.collection('users').doc(uid).collection('vocab_records');
    final topicsCol = db.collection('users').doc(uid).collection('topics');
    final userDoc = db.collection('users').doc(uid);

    onStatus(SyncStatus.syncing);

    try {
      // Batch-push all local vocab to Firestore (local is authoritative at sign-in)
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

      // Batch-push all local topics
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

      // Push settings doc (NEVER include geminiApiKey)
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

    // Subscribe: Firestore vocab → Hive (remote updates local if newer)
    _firestoreVocabSub = vocabCol.snapshots().listen(
      (snapshot) {
        for (final change in snapshot.docChanges) {
          final id = change.doc.id;
          if (change.type == DocumentChangeType.removed) {
            _firestoreUpdatingVocab.add(id);
            vocabBox.delete(id).then((_) => _firestoreUpdatingVocab.remove(id));
          } else {
            final remoteMap = change.doc.data()!;
            final localRaw = vocabBox.get(id);
            bool shouldUpdate;
            if (localRaw == null) {
              shouldUpdate = true;
            } else {
              final localMap = jsonDecode(localRaw) as Map<String, dynamic>;
              final remoteUpdatedAt =
                  DateTime.parse(remoteMap['updatedAt'] as String);
              final localUpdatedAt =
                  DateTime.parse(localMap['updatedAt'] as String);
              shouldUpdate = remoteUpdatedAt.isAfter(localUpdatedAt);
            }
            if (shouldUpdate) {
              _firestoreUpdatingVocab.add(id);
              vocabBox.put(id, jsonEncode(remoteMap)).then((_) {
                _firestoreUpdatingVocab.remove(id);
              }).catchError((e) {
                _firestoreUpdatingVocab.remove(id);
                dev.log('SyncService: Hive vocab write failed: $e');
              });
            }
          }
        }
      },
      onError: (e) => dev.log('SyncService: Firestore vocab stream error: $e'),
    );

    // Subscribe: Hive vocab → Firestore (skip keys being written from Firestore)
    _vocabHiveSub = vocabBox.watch().listen((event) {
      final key = event.key as String;
      if (_firestoreUpdatingVocab.contains(key)) return;
      if (event.deleted) {
        vocabCol.doc(key).delete().catchError(
            (e) => dev.log('SyncService: Firestore vocab delete failed: $e'));
      } else {
        final map =
            jsonDecode(event.value as String) as Map<String, dynamic>;
        vocabCol.doc(key).set(map).catchError(
            (e) => dev.log('SyncService: Firestore vocab write failed: $e'));
      }
    });

    // Subscribe: Firestore topics → Hive (remote wins if not in local)
    _firestoreTopicSub = topicsCol.snapshots().listen(
      (snapshot) {
        for (final change in snapshot.docChanges) {
          final id = change.doc.id;
          if (change.type == DocumentChangeType.removed) {
            _firestoreUpdatingTopic.add(id);
            topicsBox.delete(id).then((_) => _firestoreUpdatingTopic.remove(id));
          } else {
            final localRaw = topicsBox.get(id);
            if (localRaw == null) {
              // Only add topics that don't exist locally (topics have no updatedAt)
              _firestoreUpdatingTopic.add(id);
              topicsBox
                  .put(id, jsonEncode(change.doc.data()))
                  .then((_) => _firestoreUpdatingTopic.remove(id))
                  .catchError((e) => _firestoreUpdatingTopic.remove(id));
            }
          }
        }
      },
      onError: (e) => dev.log('SyncService: Firestore topics stream error: $e'),
    );

    // Subscribe: Hive topics → Firestore
    _topicHiveSub = topicsBox.watch().listen((event) {
      final key = event.key as String;
      if (_firestoreUpdatingTopic.contains(key)) return;
      if (event.deleted) {
        topicsCol.doc(key).delete().catchError(
            (e) => dev.log('SyncService: Firestore topic delete failed: $e'));
      } else {
        final map =
            jsonDecode(event.value as String) as Map<String, dynamic>;
        topicsCol.doc(key).set(map).catchError(
            (e) => dev.log('SyncService: Firestore topic write failed: $e'));
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
  }
}
