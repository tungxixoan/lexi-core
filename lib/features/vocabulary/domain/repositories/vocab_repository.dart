// lib/features/vocabulary/domain/repositories/vocab_repository.dart
import '../../../dictionary/domain/entities/input_type.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../entities/topic.dart';
import '../entities/vocab_record.dart';

class VocabException implements Exception {
  const VocabException(this.message);
  final String message;

  @override
  String toString() => 'VocabException: $message';
}

abstract interface class VocabRepository {
  /// Saves a new vocab record. Throws [VocabException] if already exists.
  Future<void> save(VocabRecord record);

  /// Returns all records, optionally filtered.
  /// Results are sorted newest-first by [createdAt].
  Future<List<VocabRecord>> getAll({
    String? topicId,
    InputType? inputType,
    Language? language,
  });

  Future<VocabRecord?> getById(String id);

  Future<void> update(VocabRecord record);

  Future<void> delete(String id);

  /// Returns true if a VocabRecord with matching headword + language exists.
  Future<bool> existsByHeadword(String headword, Language language);

  /// Returns the first VocabRecord whose headword matches (case-insensitive) for a given language.
  /// Returns null if not found. Used by LookupNotifier to serve saved records without an API call.
  Future<VocabRecord?> getByHeadword(String headword, Language language);

  /// Returns all topics: predefined first (alphabetical), then custom (alphabetical).
  /// Seeds predefined topics on first call if box is empty.
  Future<List<Topic>> getTopics();

  Future<void> addTopic(Topic topic);

  /// Deletes a custom topic and reassigns its words to topic 'other'.
  /// Caller must verify the topic is not predefined before calling.
  Future<void> deleteTopic(String id);
}
