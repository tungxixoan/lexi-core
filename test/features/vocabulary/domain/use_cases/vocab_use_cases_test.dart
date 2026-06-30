import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/topic.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/vocab_record.dart';
import 'package:lexi_core/features/vocabulary/domain/repositories/vocab_repository.dart';
import 'package:lexi_core/features/vocabulary/domain/use_cases/add_topic_use_case.dart';
import 'package:lexi_core/features/vocabulary/domain/use_cases/delete_topic_use_case.dart';
import 'package:lexi_core/features/vocabulary/domain/use_cases/delete_vocab_use_case.dart';
import 'package:lexi_core/features/vocabulary/domain/use_cases/get_vocab_list_use_case.dart';
import 'package:lexi_core/features/vocabulary/domain/use_cases/get_topics_use_case.dart';
import 'package:lexi_core/features/vocabulary/domain/use_cases/save_vocab_use_case.dart';
import 'package:lexi_core/features/vocabulary/domain/use_cases/update_vocab_use_case.dart';

import 'vocab_use_cases_test.mocks.dart';

@GenerateMocks([VocabRepository])
void main() {
  late MockVocabRepository mockRepo;
  final now = DateTime(2026, 6, 30);

  VocabRecord makeRecord({
    List<String> topicIds = const ['daily-life'],
    InputType type = InputType.word,
  }) =>
      VocabRecord(
        id: 'abc-123',
        headword: 'allow',
        inputType: type,
        ipa: '/əˈlaʊ/',
        meaning: 'cho phép',
        examples: const ['She allowed him to go.'],
        personalNotes: '',
        topicIds: topicIds,
        targetLanguage: Language.english,
        cefrLevel: CEFRLevel.b1,
        activeContext: AppContext.general,
        createdAt: now,
        updatedAt: now,
      );

  setUp(() {
    mockRepo = MockVocabRepository();
    when(mockRepo.save(any)).thenAnswer((_) async {});
    when(mockRepo.update(any)).thenAnswer((_) async {});
    when(mockRepo.delete(any)).thenAnswer((_) async {});
    when(mockRepo.deleteTopic(any)).thenAnswer((_) async {});
    when(mockRepo.addTopic(any)).thenAnswer((_) async {});
    when(mockRepo.getAll()).thenAnswer((_) async => []);
    when(mockRepo.getTopics()).thenAnswer((_) async => []);
  });

  group('SaveVocabUseCase', () {
    test('saves valid word record', () async {
      await SaveVocabUseCase(mockRepo).execute(makeRecord());
      verify(mockRepo.save(any)).called(1);
    });

    test('saves valid phrase record', () async {
      await SaveVocabUseCase(mockRepo).execute(makeRecord(type: InputType.phrase));
      verify(mockRepo.save(any)).called(1);
    });

    test('throws VocabException for sentence inputType', () {
      expect(
        () => SaveVocabUseCase(mockRepo).execute(makeRecord(type: InputType.sentence)),
        throwsA(isA<VocabException>()),
      );
      verifyNever(mockRepo.save(any));
    });

    test('throws VocabException when topicIds.length > 2', () {
      expect(
        () => SaveVocabUseCase(mockRepo).execute(makeRecord(topicIds: ['a', 'b', 'c'])),
        throwsA(isA<VocabException>()),
      );
      verifyNever(mockRepo.save(any));
    });

    test('allows exactly 2 topic ids', () async {
      await SaveVocabUseCase(mockRepo).execute(makeRecord(topicIds: ['a', 'b']));
      verify(mockRepo.save(any)).called(1);
    });
  });

  group('UpdateVocabUseCase', () {
    test('throws VocabException when topicIds.length > 2', () {
      expect(
        () => UpdateVocabUseCase(mockRepo).execute(makeRecord(topicIds: ['a', 'b', 'c'])),
        throwsA(isA<VocabException>()),
      );
      verifyNever(mockRepo.update(any));
    });

    test('updates updatedAt to now (not older than record)', () async {
      final before = DateTime.now();
      await UpdateVocabUseCase(mockRepo).execute(makeRecord());
      final after = DateTime.now();
      final captured = verify(mockRepo.update(captureAny)).captured.first as VocabRecord;
      expect(
        captured.updatedAt.isAfter(before.subtract(const Duration(seconds: 1))) &&
            captured.updatedAt.isBefore(after.add(const Duration(seconds: 1))),
        isTrue,
      );
    });
  });

  group('DeleteVocabUseCase', () {
    test('calls repo.delete with given id', () async {
      await DeleteVocabUseCase(mockRepo).execute('my-id');
      verify(mockRepo.delete('my-id')).called(1);
    });
  });

  group('GetVocabListUseCase', () {
    test('delegates to repo with no filters', () async {
      when(mockRepo.getAll()).thenAnswer((_) async => [makeRecord()]);
      final result = await GetVocabListUseCase(mockRepo).execute();
      expect(result.length, 1);
    });

    test('passes topicId filter to repo', () async {
      when(mockRepo.getAll(topicId: 'business')).thenAnswer((_) async => []);
      await GetVocabListUseCase(mockRepo).execute(topicId: 'business');
      verify(mockRepo.getAll(topicId: 'business')).called(1);
    });
  });

  group('GetTopicsUseCase', () {
    test('delegates to repo.getTopics', () async {
      final topic = Topic(
        id: 'daily-life',
        name: 'Daily Life',
        emoji: '🏠',
        isPredefined: true,
        createdAt: now,
      );
      when(mockRepo.getTopics()).thenAnswer((_) async => [topic]);
      final result = await GetTopicsUseCase(mockRepo).execute();
      expect(result.length, 1);
      expect(result[0].name, 'Daily Life');
    });
  });

  group('DeleteTopicUseCase', () {
    test('throws VocabException for predefined topic', () {
      expect(
        () => DeleteTopicUseCase(mockRepo).execute('daily-life', isPredefined: true),
        throwsA(isA<VocabException>()),
      );
      verifyNever(mockRepo.deleteTopic(any));
    });

    test('allows deleting custom topic', () async {
      await DeleteTopicUseCase(mockRepo).execute('my-custom-id', isPredefined: false);
      verify(mockRepo.deleteTopic('my-custom-id')).called(1);
    });
  });

  group('AddTopicUseCase', () {
    test('throws VocabException for empty name', () {
      expect(
        () => AddTopicUseCase(mockRepo).execute(name: '   ', emoji: '⭐'),
        throwsA(isA<VocabException>()),
      );
      verifyNever(mockRepo.addTopic(any));
    });

    test('creates topic with non-empty UUID and trimmed name', () async {
      final topic = await AddTopicUseCase(mockRepo).execute(name: '  My Topic  ', emoji: '⭐');
      expect(topic.id, isNotEmpty);
      expect(topic.id.length, greaterThan(4)); // UUID v4 is 36 chars
      expect(topic.name, 'My Topic');
      expect(topic.emoji, '⭐');
      expect(topic.isPredefined, isFalse);
      verify(mockRepo.addTopic(any)).called(1);
    });

    test('uses default emoji when empty', () async {
      final topic = await AddTopicUseCase(mockRepo).execute(name: 'Test', emoji: '');
      expect(topic.emoji, '📌');
    });
  });
}
