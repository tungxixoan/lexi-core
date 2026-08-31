// lib/features/dictionary/domain/entities/input_type.dart
enum InputType {
  word,
  phrase,
  sentence;

  /// Vietnamese label for display on Vietnamized screens.
  /// (`.name` stays the wire format used by `VocabRecord.toJson`.)
  String get label => switch (this) {
        InputType.word => 'từ',
        InputType.phrase => 'cụm từ',
        InputType.sentence => 'câu',
      };
}
