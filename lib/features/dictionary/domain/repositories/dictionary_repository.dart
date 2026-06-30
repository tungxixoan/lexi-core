// lib/features/dictionary/domain/repositories/dictionary_repository.dart
import '../entities/app_context.dart';
import '../entities/language.dart';
import '../entities/lookup_result.dart';

class DictionaryException implements Exception {
  const DictionaryException(this.message);
  final String message;

  @override
  String toString() => 'DictionaryException: $message';
}

abstract interface class DictionaryRepository {
  Future<LookupResult> lookup({
    required String query,
    required Language targetLanguage,
    required AppContext context,
    required bool aiEnabled,
  });
}
