import 'package:cloud_functions/cloud_functions.dart';

/// Thin seam over a Cloud Functions `onCall` invocation, injectable for
/// testing — this codebase's established pattern is to test through an
/// injected interface (e.g. VocabRepository, TtsService) rather than mock
/// the Firebase SDK's own concrete classes directly.
abstract interface class CloudFunctionCaller {
  Future<Map<String, dynamic>> call(String name, Map<String, dynamic> data);
}

/// Real implementation. Every onCall function in functions/src/ is deployed
/// to asia-southeast1 (see CLAUDE.md) — the client must request the same
/// region, or httpsCallable silently targets the wrong endpoint.
class FirebaseCloudFunctionCaller implements CloudFunctionCaller {
  FirebaseCloudFunctionCaller({FirebaseFunctions? functions})
      : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  final FirebaseFunctions _functions;

  @override
  Future<Map<String, dynamic>> call(
      String name, Map<String, dynamic> data) async {
    final callable = _functions.httpsCallable(name);
    final result = await callable.call(data);
    return Map<String, dynamic>.from(result.data as Map);
  }
}
