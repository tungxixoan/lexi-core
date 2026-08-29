import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/dictionary/domain/entities/ai_provider.dart';

void main() {
  group('AiProviderX.cloudId', () {
    test('gemini -> "gemini"', () {
      expect(AiProvider.gemini.cloudId, 'gemini');
    });
    test('groq -> "groq"', () {
      expect(AiProvider.groq.cloudId, 'groq');
    });
    test('openRouter -> lowercase "openrouter", not .name', () {
      expect(AiProvider.openRouter.cloudId, 'openrouter');
      expect(AiProvider.openRouter.name, isNot('openrouter'));
    });
  });

  group('aiProviderFromCloudId', () {
    test('round-trips every provider through its cloudId', () {
      for (final provider in AiProvider.values) {
        expect(aiProviderFromCloudId(provider.cloudId), provider);
      }
    });
    test('returns null for an unrecognized id', () {
      expect(aiProviderFromCloudId('not-a-real-provider'), isNull);
    });
  });
}
