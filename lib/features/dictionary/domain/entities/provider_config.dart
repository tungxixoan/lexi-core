import 'ai_provider.dart';

final class ProviderConfig {
  const ProviderConfig({required this.apiKeyCiphertext, required this.model});

  /// A Cloud KMS ciphertext produced by the `encryptApiKey` Cloud Function
  /// (see lib/core/services/encrypt_api_key.dart) — never a raw API key.
  /// `null` means this provider has no key configured yet.
  final String? apiKeyCiphertext;
  final String model;

  bool get isConfigured =>
      (apiKeyCiphertext?.isNotEmpty ?? false) && model.isNotEmpty;

  Map<String, dynamic> toJson() =>
      {'apiKeyCiphertext': apiKeyCiphertext, 'model': model};

  factory ProviderConfig.fromJson(Map<String, dynamic> json) => ProviderConfig(
        apiKeyCiphertext: json['apiKeyCiphertext'] as String?,
        model: json['model'] as String? ?? '',
      );

  static ProviderConfig empty(AiProvider provider) =>
      ProviderConfig(apiKeyCiphertext: null, model: provider.defaultModel);
}
