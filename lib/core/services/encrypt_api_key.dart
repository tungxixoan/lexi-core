import 'cloud_function_caller.dart';

/// Thrown when the `encryptApiKey` Cloud Function call fails — carries a
/// user-facing Vietnamese message shown directly in the Settings API-key
/// dialog (mirrors apps/web/src/components/settings/AiProviderSection.tsx's
/// handleUpdateKey error handling).
class EncryptApiKeyException implements Exception {
  const EncryptApiKeyException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Wraps the `encryptApiKey` Cloud Function (functions/src/encryptApiKey.ts)
/// — turns a raw, user-entered API key into a Cloud KMS ciphertext that's
/// safe to store in Firestore/SharedPreferences. The raw key itself is never
/// persisted anywhere, per this project's BYOK policy (see CLAUDE.md).
class ApiKeyEncryptor {
  ApiKeyEncryptor({CloudFunctionCaller? caller})
      : _caller = caller ?? FirebaseCloudFunctionCaller();

  final CloudFunctionCaller _caller;

  static const _genericError = 'Không thể mã hoá API key. Vui lòng thử lại.';

  Future<String> encrypt(String rawApiKey) async {
    try {
      final result = await _caller.call('encryptApiKey', {'apiKey': rawApiKey});
      final ciphertext = result['ciphertext'] as String?;
      if (ciphertext == null || ciphertext.isEmpty) {
        throw const EncryptApiKeyException(_genericError);
      }
      return ciphertext;
    } on EncryptApiKeyException {
      rethrow;
    } catch (_) {
      throw const EncryptApiKeyException(_genericError);
    }
  }
}
