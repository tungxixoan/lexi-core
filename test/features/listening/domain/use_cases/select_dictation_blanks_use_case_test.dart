import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/listening/domain/entities/dictation_difficulty.dart';
import 'package:lexi_core/features/listening/domain/use_cases/select_dictation_blanks_use_case.dart';

String _sentence(int wordCount) =>
    List.generate(wordCount, (i) => 'w$i').join(' ');

void main() {
  final useCase = SelectDictationBlanksUseCase();

  group('hard difficulty', () {
    test('returns no blanks', () {
      final blanks = useCase.execute(_sentence(12), DictationDifficulty.hard);
      expect(blanks, isEmpty);
    });
  });

  group('easy difficulty', () {
    test('returns exactly 2 single-word blanks', () {
      final blanks = useCase.execute(
        _sentence(12),
        DictationDifficulty.easy,
        random: Random(1),
      );
      expect(blanks.length, 2);
      for (final b in blanks) {
        expect(b.wordCount, 1);
      }
    });

    test(
        'blanks are distinct, non-adjacent, and avoid the first/last word '
        'for a 12-word sentence, across many random seeds', () {
      for (var seed = 0; seed < 100; seed++) {
        final blanks = useCase.execute(
          _sentence(12),
          DictationDifficulty.easy,
          random: Random(seed),
        );
        expect(blanks.length, 2, reason: 'seed=$seed');
        final indices = blanks.map((b) => b.startWordIndex).toList()..sort();
        expect(indices[0], isNot(indices[1]), reason: 'seed=$seed');
        expect(indices[1] - indices[0], greaterThanOrEqualTo(2),
            reason: 'seed=$seed');
        expect(indices[0], greaterThanOrEqualTo(1), reason: 'seed=$seed');
        expect(indices[1], lessThanOrEqualTo(10), reason: 'seed=$seed');
      }
    });

    test(
        'still returns 2 distinct blanks for a short (3-word) sentence, '
        'across many random seeds', () {
      for (var seed = 0; seed < 50; seed++) {
        final blanks = useCase.execute(
          _sentence(3),
          DictationDifficulty.easy,
          random: Random(seed),
        );
        expect(blanks.length, 2, reason: 'seed=$seed');
        final indices = blanks.map((b) => b.startWordIndex).toSet();
        expect(indices.length, 2, reason: 'seed=$seed');
        for (final b in blanks) {
          expect(b.startWordIndex, inInclusiveRange(0, 2),
              reason: 'seed=$seed');
        }
      }
    });

    test(
        'adjacency is not avoided for short (3-5 word) sentences: at least '
        'one seed out of many produces an adjacent pair for a 4-word '
        'sentence', () {
      var sawAdjacentPair = false;
      for (var seed = 0; seed < 50; seed++) {
        final blanks = useCase.execute(
          _sentence(4),
          DictationDifficulty.easy,
          random: Random(seed),
        );
        expect(blanks.length, 2, reason: 'seed=$seed');
        final indices = blanks.map((b) => b.startWordIndex).toList()..sort();
        if (indices[1] - indices[0] == 1) {
          sawAdjacentPair = true;
          break;
        }
      }
      expect(sawAdjacentPair, isTrue,
          reason:
              'expected at least one seed to produce an adjacent pair for a '
              '4-word sentence, since non-adjacency should only be enforced '
              'when wordCount >= 6');
    });

    test(
        'does not crash for a 0-word sentence and returns a single blank '
        'at index 0', () {
      final blanks = useCase.execute(
        _sentence(0),
        DictationDifficulty.easy,
        random: Random(1),
      );
      expect(blanks.length, 1);
      expect(blanks.single.startWordIndex, 0);
    });

    test(
        'does not crash for a 1-word sentence and returns a single blank '
        'at index 0', () {
      final blanks = useCase.execute(
        _sentence(1),
        DictationDifficulty.easy,
        random: Random(1),
      );
      expect(blanks.length, 1);
      expect(blanks.single.startWordIndex, 0);
    });
  });

  group('medium difficulty', () {
    test(
        'returns exactly 1 multi-word blank spanning ~35% of a 12-word sentence',
        () {
      final blanks = useCase.execute(
        _sentence(12),
        DictationDifficulty.medium,
        random: Random(1),
      );
      expect(blanks.length, 1);
      expect(blanks.single.wordCount, 4); // round(12 * 0.35) == 4
    });

    test(
        'span always leaves at least 1 word of context on each side, '
        'across many random seeds', () {
      for (var seed = 0; seed < 100; seed++) {
        final blanks = useCase.execute(
          _sentence(12),
          DictationDifficulty.medium,
          random: Random(seed),
        );
        expect(blanks.length, 1, reason: 'seed=$seed');
        final span = blanks.single;
        expect(span.startWordIndex, greaterThanOrEqualTo(1),
            reason: 'seed=$seed');
        expect(span.startWordIndex + span.wordCount, lessThanOrEqualTo(11),
            reason: 'seed=$seed');
      }
    });

    test(
        'falls back to a single blank covering the whole sentence for '
        'wordCount 1, 2, and 3 (the wordCount <= 3 early-return path)', () {
      for (final wordCount in [1, 2, 3]) {
        final blanks = useCase.execute(
          _sentence(wordCount),
          DictationDifficulty.medium,
          random: Random(1),
        );
        expect(blanks.length, 1, reason: 'wordCount=$wordCount');
        expect(blanks.single.wordCount, wordCount,
            reason: 'wordCount=$wordCount');
        expect(blanks.single.startWordIndex, 0, reason: 'wordCount=$wordCount');
      }
    });

    test(
        'span length is clamped between 2 and wordCount-2 for a range of sentence lengths',
        () {
      for (final wordCount in [4, 5, 6, 10, 18]) {
        for (var seed = 0; seed < 20; seed++) {
          final blanks = useCase.execute(
            _sentence(wordCount),
            DictationDifficulty.medium,
            random: Random(seed),
          );
          expect(blanks.length, 1, reason: 'wordCount=$wordCount seed=$seed');
          expect(blanks.single.wordCount, greaterThanOrEqualTo(2),
              reason: 'wordCount=$wordCount seed=$seed');
          expect(blanks.single.wordCount, lessThanOrEqualTo(wordCount - 2),
              reason: 'wordCount=$wordCount seed=$seed');
        }
      }
    });
  });
}
