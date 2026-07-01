// test/features/dictionary/presentation/providers/lookup_provider_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:lexi_core/core/di/app_providers.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/lookup_result.dart';
import 'package:lexi_core/features/dictionary/domain/use_cases/lookup_use_case.dart';
import 'package:lexi_core/features/dictionary/presentation/providers/lookup_provider.dart';
import 'package:lexi_core/features/vocabulary/domain/repositories/vocab_repository.dart';

import 'lookup_provider_test.mocks.dart';

@GenerateMocks([LookupUseCase, VocabRepository])
void main() {
  late MockLookupUseCase mockUseCase;
  late MockVocabRepository mockVocabRepo;

  const fakeResult = WordPhraseResult(
    headword: 'follow',
    inputType: InputType.word,
    ipa: '/ˈfɒl.oʊ/',
    meaning: 'Đi theo.',
    examples: ['She followed him.'],
    suggestedTopics: ['Daily Life'],
  );

  setUp(() {
    mockUseCase = MockLookupUseCase();
    mockVocabRepo = MockVocabRepository();
    provideDummy<LookupResult>(fakeResult);
    when(mockUseCase.execute(
      query: anyNamed('query'),
      targetLanguage: anyNamed('targetLanguage'),
      context: anyNamed('context'),
      aiEnabled: anyNamed('aiEnabled'),
    )).thenAnswer((_) async => fakeResult);
    // VocabBank always misses in these tests — force API path
    when(mockVocabRepo.getByHeadword(any, any))
        .thenAnswer((_) async => null);
  });

  ProviderContainer makeContainer() => ProviderContainer(
        overrides: [
          lookupUseCaseProvider.overrideWithValue(mockUseCase),
          vocabRepositoryProvider.overrideWith((ref) => mockVocabRepo),
        ],
      );

  test('initial state is AsyncData(null)', () {
    final c = makeContainer();
    addTearDown(c.dispose);
    expect(
      c.read(lookupNotifierProvider),
      const AsyncValue<LookupResult?>.data(null),
    );
  });

  test('lookup → loading → data', () async {
    final c = makeContainer();
    addTearDown(c.dispose);
    final notifier = c.read(lookupNotifierProvider.notifier);
    final future = notifier.lookup('follow');

    expect(c.read(lookupNotifierProvider), const AsyncValue<LookupResult?>.loading());
    await future;

    final state = c.read(lookupNotifierProvider);
    expect(state, isA<AsyncData<LookupResult?>>());
    expect((state.value as WordPhraseResult).headword, 'follow');
  });

  test('clear → AsyncData(null)', () async {
    final c = makeContainer();
    addTearDown(c.dispose);
    final notifier = c.read(lookupNotifierProvider.notifier);
    await notifier.lookup('follow');
    notifier.clear();
    expect(
      c.read(lookupNotifierProvider),
      const AsyncValue<LookupResult?>.data(null),
    );
  });
}
