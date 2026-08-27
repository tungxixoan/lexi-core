// lib/features/vocabulary/data/repositories/vocab_repository_impl.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/cefr_level.dart';
import '../../domain/entities/topic.dart';
import '../../domain/entities/vocab_record.dart';
import '../../domain/repositories/vocab_repository.dart';
import '../../../../features/dictionary/domain/entities/input_type.dart';
import '../../../../features/dictionary/domain/entities/language.dart';

class VocabRepositoryImpl implements VocabRepository {
  VocabRepositoryImpl({required this.uid, FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final String uid;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _vocabCol =>
      _firestore.collection('users').doc(uid).collection('vocab_records');
  CollectionReference<Map<String, dynamic>> get _topicsCol =>
      _firestore.collection('users').doc(uid).collection('topics');

  @override
  Future<void> save(VocabRecord record) async {
    await _vocabCol.doc(record.id).set(record.toJson());
  }

  @override
  Future<List<VocabRecord>> getAll({
    String? topicId,
    InputType? inputType,
    Language? language,
    CEFRLevel? maxCefrLevel,
    bool dueOnly = false,
  }) async {
    final snapshot = await _vocabCol.get();
    var records =
        snapshot.docs.map((d) => VocabRecord.fromJson(d.data())).toList();
    if (topicId != null) {
      records = records.where((r) => r.topicIds.contains(topicId)).toList();
    }
    if (inputType != null) {
      records = records.where((r) => r.inputType == inputType).toList();
    }
    if (language != null) {
      records = records.where((r) => r.targetLanguage == language).toList();
    }
    if (maxCefrLevel != null) {
      records = records
          .where((r) => r.cefrLevel.index <= maxCefrLevel.index)
          .toList();
    }
    if (dueOnly) {
      final now = DateTime.now();
      records = records
          .where((r) => r.nextReviewAt == null || r.nextReviewAt!.isBefore(now))
          .toList();
    }
    records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return records;
  }

  @override
  Future<VocabRecord?> getById(String id) async {
    final doc = await _vocabCol.doc(id).get();
    if (!doc.exists) return null;
    return VocabRecord.fromJson(doc.data()!);
  }

  @override
  Future<void> update(VocabRecord record) async {
    await _vocabCol.doc(record.id).set(record.toJson());
  }

  @override
  Future<void> delete(String id) async {
    await _vocabCol.doc(id).delete();
  }

  @override
  Future<bool> existsByHeadword(String headword, Language language) async {
    return await getByHeadword(headword, language) != null;
  }

  @override
  Future<VocabRecord?> getByHeadword(String headword, Language language) async {
    final lc = headword.toLowerCase();
    final snapshot =
        await _vocabCol.where('targetLanguage', isEqualTo: language.name).get();
    for (final doc in snapshot.docs) {
      final data = doc.data();
      if ((data['headword'] as String).toLowerCase() == lc) {
        return VocabRecord.fromJson(data);
      }
    }
    return null;
  }

  @override
  Future<List<Topic>> getTopics() async {
    var snapshot = await _topicsCol.get();
    if (snapshot.docs.isEmpty) {
      await _seedTopics();
      snapshot = await _topicsCol.get();
    }
    final topics = snapshot.docs.map((d) => Topic.fromJson(d.data())).toList();
    topics.sort((a, b) {
      if (a.isPredefined && !b.isPredefined) return -1;
      if (!a.isPredefined && b.isPredefined) return 1;
      return a.name.compareTo(b.name);
    });
    return topics;
  }

  @override
  Future<void> addTopic(Topic topic) async {
    await _topicsCol.doc(topic.id).set(topic.toJson());
  }

  @override
  Future<void> deleteTopic(String id) async {
    final all = await getAll();
    for (final record in all) {
      if (record.topicIds.contains(id)) {
        final newTopicIds = record.topicIds.where((t) => t != id).toList();
        if (newTopicIds.isEmpty) newTopicIds.add('other');
        await update(record.copyWith(
          topicIds: newTopicIds,
          updatedAt: DateTime.now(),
        ));
      }
    }
    await _topicsCol.doc(id).delete();
  }

  Future<void> _seedTopics() async {
    final batch = _firestore.batch();
    for (final topic in Topic.predefined) {
      batch.set(_topicsCol.doc(topic.id), topic.toJson());
    }
    await batch.commit();
  }
}
