import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/services/cloud_function_caller.dart';
import 'package:lexi_core/core/services/encrypt_api_key.dart';

class _FakeCaller implements CloudFunctionCaller {
  _FakeCaller({this.response, this.error});
  Map<String, dynamic>? response;
  Object? error;
  String? capturedName;
  Map<String, dynamic>? capturedData;

  @override
  Future<Map<String, dynamic>> call(
      String name, Map<String, dynamic> data) async {
    capturedName = name;
    capturedData = data;
    if (error != null) throw error!;
    return response!;
  }
}

void main() {
  group('ApiKeyEncryptor.encrypt', () {
    test('returns the ciphertext from a successful call', () async {
      final fake = _FakeCaller(response: {'ciphertext': 'cipher-abc'});
      final encryptor = ApiKeyEncryptor(caller: fake);

      final result = await encryptor.encrypt('raw-key-123');

      expect(result, 'cipher-abc');
      expect(fake.capturedName, 'encryptApiKey');
      expect(fake.capturedData, {'apiKey': 'raw-key-123'});
    });

    test('throws EncryptApiKeyException when the response has no ciphertext',
        () async {
      final fake = _FakeCaller(response: {});
      final encryptor = ApiKeyEncryptor(caller: fake);

      await expectLater(
        () => encryptor.encrypt('raw-key'),
        throwsA(isA<EncryptApiKeyException>()),
      );
    });

    test(
        'throws EncryptApiKeyException when the response has an empty ciphertext',
        () async {
      final fake = _FakeCaller(response: {'ciphertext': ''});
      final encryptor = ApiKeyEncryptor(caller: fake);

      await expectLater(
        () => encryptor.encrypt('raw-key'),
        throwsA(isA<EncryptApiKeyException>()),
      );
    });

    test('wraps an underlying Cloud Function error as EncryptApiKeyException',
        () async {
      final fake = _FakeCaller(error: Exception('permission-denied'));
      final encryptor = ApiKeyEncryptor(caller: fake);

      await expectLater(
        () => encryptor.encrypt('raw-key'),
        throwsA(isA<EncryptApiKeyException>()),
      );
    });
  });
}
