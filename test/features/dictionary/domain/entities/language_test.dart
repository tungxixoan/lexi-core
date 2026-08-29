import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';

void main() {
  group('Language.ttsCloudCode', () {
    test('vietnamese -> "vi"', () {
      expect(Language.vietnamese.ttsCloudCode, 'vi');
    });
    test('english -> "en"', () {
      expect(Language.english.ttsCloudCode, 'en');
    });
    test('chinese, korean, japanese all -> null (no Piper voice)', () {
      expect(Language.chinese.ttsCloudCode, isNull);
      expect(Language.korean.ttsCloudCode, isNull);
      expect(Language.japanese.ttsCloudCode, isNull);
    });
  });
}
