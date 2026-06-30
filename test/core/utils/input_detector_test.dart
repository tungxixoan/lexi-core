import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/utils/input_detector.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';

void main() {
  group('InputDetector.detect', () {
    test('single word → word', () {
      expect(InputDetector.detect('follow'), InputType.word);
      expect(InputDetector.detect('technology'), InputType.word);
    });

    test('two words → phrase', () {
      expect(InputDetector.detect('follow up'), InputType.phrase);
    });

    test('three or four words → phrase', () {
      expect(InputDetector.detect('break a leg'), InputType.phrase);
      expect(InputDetector.detect('piece of cake'), InputType.phrase);
    });

    test('five or more words → sentence', () {
      expect(
        InputDetector.detect('Can you follow up with me'),
        InputType.sentence,
      );
    });

    test('terminal period → sentence regardless of word count', () {
      expect(InputDetector.detect('Good morning.'), InputType.sentence);
    });

    test('terminal question mark → sentence', () {
      expect(InputDetector.detect('Are you ready?'), InputType.sentence);
    });

    test('terminal exclamation → sentence', () {
      expect(InputDetector.detect('Watch out!'), InputType.sentence);
    });

    test('trims whitespace before classifying', () {
      expect(InputDetector.detect('  follow  '), InputType.word);
      expect(InputDetector.detect('  follow up  '), InputType.phrase);
    });

    test('empty string → word (safe fallback)', () {
      expect(InputDetector.detect(''), InputType.word);
    });
  });
}
