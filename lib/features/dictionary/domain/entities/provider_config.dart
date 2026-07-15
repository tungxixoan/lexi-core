import 'ai_provider.dart';

final class ProviderConfig {
  const ProviderConfig({required this.apiKey, required this.model});

  final String apiKey;
  final String model;

  bool get isConfigured => apiKey.isNotEmpty && model.isNotEmpty;

  Map<String, dynamic> toJson() => {'apiKey': apiKey, 'model': model};

  factory ProviderConfig.fromJson(Map<String, dynamic> json) => ProviderConfig(
        apiKey: json['apiKey'] as String? ?? '',
        model: json['model'] as String? ?? '',
      );

  static ProviderConfig empty(AiProvider provider) =>
      ProviderConfig(apiKey: '', model: provider.defaultModel);
}
