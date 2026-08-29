import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/dictionary/domain/entities/ai_provider.dart';
import 'package:lexi_core/features/dictionary/domain/entities/provider_config.dart';

void main() {
  group('ProviderConfig.isConfigured', () {
    test('false when apiKeyCiphertext is null', () {
      const c = ProviderConfig(apiKeyCiphertext: null, model: 'gemini-2.5-flash');
      expect(c.isConfigured, false);
    });
    test('false when apiKeyCiphertext is empty', () {
      const c = ProviderConfig(apiKeyCiphertext: '', model: 'gemini-2.5-flash');
      expect(c.isConfigured, false);
    });
    test('false when model is empty', () {
      const c = ProviderConfig(apiKeyCiphertext: 'cipher', model: '');
      expect(c.isConfigured, false);
    });
    test('true when both are non-empty', () {
      const c = ProviderConfig(apiKeyCiphertext: 'cipher', model: 'gemini-2.5-flash');
      expect(c.isConfigured, true);
    });
  });

  group('ProviderConfig toJson / fromJson round-trip', () {
    test('round-trip preserves apiKeyCiphertext and model', () {
      const original =
          ProviderConfig(apiKeyCiphertext: 'cipher-123', model: 'llama-3.3-70b-versatile');
      final restored = ProviderConfig.fromJson(original.toJson());
      expect(restored.apiKeyCiphertext, original.apiKeyCiphertext);
      expect(restored.model, original.model);
    });
    test('fromJson with missing keys returns null ciphertext and empty model', () {
      final c = ProviderConfig.fromJson({});
      expect(c.apiKeyCiphertext, isNull);
      expect(c.model, '');
    });
    test('fromJson ignores a legacy plaintext "apiKey" field', () {
      final c = ProviderConfig.fromJson({'apiKey': 'old-plaintext', 'model': 'gemini-2.5-flash'});
      expect(c.apiKeyCiphertext, isNull);
      expect(c.model, 'gemini-2.5-flash');
    });
  });

  group('ProviderConfig.empty', () {
    test('empty Gemini uses gemini-2.5-flash default model, null ciphertext', () {
      final c = ProviderConfig.empty(AiProvider.gemini);
      expect(c.apiKeyCiphertext, isNull);
      expect(c.model, 'gemini-2.5-flash');
    });
    test('empty Groq uses openai/gpt-oss-120b default model', () {
      final c = ProviderConfig.empty(AiProvider.groq);
      expect(c.model, 'openai/gpt-oss-120b');
    });
    test('empty OpenRouter uses meta-llama/llama-3.3-70b-instruct default model', () {
      final c = ProviderConfig.empty(AiProvider.openRouter);
      expect(c.model, 'meta-llama/llama-3.3-70b-instruct');
    });
  });
}
