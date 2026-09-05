import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/dictionary/domain/entities/ai_provider.dart';

void main() {
  group('AiProvider labels', () {
    test('gemini label', () => expect(AiProvider.gemini.label, 'Gemini'));
    test('groq label', () => expect(AiProvider.groq.label, 'Groq'));
    test('openRouter label',
        () => expect(AiProvider.openRouter.label, 'OpenRouter'));
  });

  group('AiProvider baseUrl', () {
    test('gemini has empty baseUrl (uses SDK)',
        () => expect(AiProvider.gemini.baseUrl, ''));
    test(
        'groq baseUrl',
        () =>
            expect(AiProvider.groq.baseUrl, 'https://api.groq.com/openai/v1'));
    test(
        'openRouter baseUrl',
        () => expect(
            AiProvider.openRouter.baseUrl, 'https://openrouter.ai/api/v1'));
  });

  group('AiProvider defaultModel', () {
    test('gemini default model',
        () => expect(AiProvider.gemini.defaultModel, 'gemini-2.5-flash'));
    test('groq default model',
        () => expect(AiProvider.groq.defaultModel, 'openai/gpt-oss-120b'));
    test(
        'openRouter default model',
        () => expect(AiProvider.openRouter.defaultModel,
            'meta-llama/llama-3.3-70b-instruct'));
  });

  group('AiProvider modelPresets', () {
    test('gemini has 4 presets starting with gemini-2.5-flash', () {
      expect(AiProvider.gemini.modelPresets.first, 'gemini-2.5-flash');
      expect(AiProvider.gemini.modelPresets, hasLength(4));
    });
    test('groq has 2 presets starting with openai/gpt-oss-120b', () {
      expect(AiProvider.groq.modelPresets.first, 'openai/gpt-oss-120b');
      expect(AiProvider.groq.modelPresets, hasLength(2));
    });
    test('openRouter has 4 presets',
        () => expect(AiProvider.openRouter.modelPresets, hasLength(4)));
    test('every defaultModel is first in its modelPresets', () {
      for (final p in AiProvider.values) {
        expect(p.modelPresets.first, p.defaultModel,
            reason: '${p.name}.defaultModel should be first in modelPresets');
      }
    });
  });

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
