import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/widgets/vocab_filter.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/vocab_record.dart';

VocabRecord _record(
  String id, {
  String headword = 'serendipity',
  String meaning = 'sự tình cờ may mắn',
  List<String> topicIds = const [],
  CEFRLevel cefrLevel = CEFRLevel.b1,
  DateTime? nextReviewAt,
}) {
  final now = DateTime(2026, 1, 1);
  return VocabRecord(
    id: id,
    headword: headword,
    inputType: InputType.word,
    ipa: '',
    meaning: meaning,
    examples: const [],
    personalNotes: '',
    topicIds: topicIds,
    targetLanguage: Language.english,
    cefrLevel: cefrLevel,
    activeContext: AppContext.general,
    createdAt: now,
    updatedAt: now,
    nextReviewAt: nextReviewAt,
  );
}

void main() {
  final now = DateTime(2026, 6, 1, 12);

  group('vocabRecordIsDue', () {
    test('null nextReviewAt is due', () {
      expect(vocabRecordIsDue(_record('a'), now: now), isTrue);
    });

    test('nextReviewAt in the past is due', () {
      expect(
        vocabRecordIsDue(
          _record('a', nextReviewAt: DateTime(2026, 5, 1)),
          now: now,
        ),
        isTrue,
      );
    });

    test('nextReviewAt in the future is not due', () {
      expect(
        vocabRecordIsDue(
          _record('a', nextReviewAt: DateTime(2026, 7, 1)),
          now: now,
        ),
        isFalse,
      );
    });
  });

  group('matchesVocabFilters', () {
    test('dueOnly excludes a not-due record', () {
      final notDue = _record('a', nextReviewAt: DateTime(2026, 7, 1));
      expect(
        matchesVocabFilters(
          notDue,
          const VocabFilterState(dueOnly: true),
          now: now,
        ),
        isFalse,
      );
    });

    test('dueOnly keeps a due record', () {
      final due = _record('a', nextReviewAt: DateTime(2026, 5, 1));
      expect(
        matchesVocabFilters(
          due,
          const VocabFilterState(dueOnly: true),
          now: now,
        ),
        isTrue,
      );
    });

    test('topicIds requires overlap', () {
      final r = _record('a', topicIds: const ['t1', 't2']);
      expect(
        matchesVocabFilters(r, const VocabFilterState(topicIds: {'t2'})),
        isTrue,
      );
      expect(
        matchesVocabFilters(r, const VocabFilterState(topicIds: {'t9'})),
        isFalse,
      );
    });

    test('cefrLevels requires membership', () {
      final r = _record('a', cefrLevel: CEFRLevel.b2);
      expect(
        matchesVocabFilters(
          r,
          const VocabFilterState(cefrLevels: {CEFRLevel.b2}),
        ),
        isTrue,
      );
      expect(
        matchesVocabFilters(
          r,
          const VocabFilterState(cefrLevels: {CEFRLevel.a1}),
        ),
        isFalse,
      );
    });

    test('query matches the headword (case-insensitive)', () {
      final r = _record('a', headword: 'Serendipity');
      expect(
        matchesVocabFilters(r, const VocabFilterState(query: 'seren')),
        isTrue,
      );
    });

    test('query matches the meaning', () {
      final r = _record('a', meaning: 'sự tình cờ may mắn');
      expect(
        matchesVocabFilters(r, const VocabFilterState(query: 'tình cờ')),
        isTrue,
      );
    });

    test('query that matches neither headword nor meaning is excluded', () {
      final r = _record('a', headword: 'apple', meaning: 'quả táo');
      expect(
        matchesVocabFilters(r, const VocabFilterState(query: 'zzz')),
        isFalse,
      );
    });

    test('all four filters combine with AND', () {
      final match = _record(
        'a',
        headword: 'serendipity',
        topicIds: const ['t1'],
        cefrLevel: CEFRLevel.b1,
        nextReviewAt: DateTime(2026, 5, 1),
      );
      const filters = VocabFilterState(
        query: 'seren',
        topicIds: {'t1'},
        dueOnly: true,
        cefrLevels: {CEFRLevel.b1},
      );
      expect(matchesVocabFilters(match, filters, now: now), isTrue);

      // Fails the CEFR clause only.
      final wrongLevel = _record(
        'b',
        headword: 'serendipity',
        topicIds: const ['t1'],
        cefrLevel: CEFRLevel.c1,
        nextReviewAt: DateTime(2026, 5, 1),
      );
      expect(matchesVocabFilters(wrongLevel, filters, now: now), isFalse);

      // Fails the due clause only.
      final notDue = _record(
        'c',
        headword: 'serendipity',
        topicIds: const ['t1'],
        cefrLevel: CEFRLevel.b1,
        nextReviewAt: DateTime(2026, 7, 1),
      );
      expect(matchesVocabFilters(notDue, filters, now: now), isFalse);
    });
  });

  group('VocabFilterState.isActive', () {
    test('is false for the default state', () {
      expect(const VocabFilterState().isActive, isFalse);
    });

    test('is false when query is only whitespace', () {
      expect(const VocabFilterState(query: '   ').isActive, isFalse);
    });

    test('is true when any facet is set', () {
      expect(const VocabFilterState(query: 'a').isActive, isTrue);
      expect(const VocabFilterState(topicIds: {'t1'}).isActive, isTrue);
      expect(const VocabFilterState(dueOnly: true).isActive, isTrue);
      expect(
        const VocabFilterState(cefrLevels: {CEFRLevel.a1}).isActive,
        isTrue,
      );
    });
  });
}
