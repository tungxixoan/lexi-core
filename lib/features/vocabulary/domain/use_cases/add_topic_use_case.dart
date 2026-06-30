import 'package:uuid/uuid.dart';
import '../entities/topic.dart';
import '../repositories/vocab_repository.dart';

class AddTopicUseCase {
  const AddTopicUseCase(this._repo);
  final VocabRepository _repo;

  Future<Topic> execute({required String name, required String emoji}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const VocabException('Topic name cannot be empty.');
    }
    final topic = Topic(
      id: const Uuid().v4(),
      name: trimmed,
      emoji: emoji.trim().isEmpty ? '📌' : emoji.trim(),
      isPredefined: false,
      createdAt: DateTime.now(),
    );
    await _repo.addTopic(topic);
    return topic;
  }
}
