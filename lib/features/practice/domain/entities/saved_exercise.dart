/// The six kinds of AI exercise that can be saved to Firestore and re-drawn
/// later ("Lưu bài / Lấy bài có sẵn"). Mirrors the union member `type` strings
/// used by the React web app:
///   - `bilingual` / `part5` / `part6` / `part7` live in
///     `users/{uid}/reading_exercises`
///     (apps/web/src/lib/savedReadingExercises.ts)
///   - `dictation` / `comprehension` live in
///     `users/{uid}/listening_exercises`
///     (apps/web/src/lib/savedListeningExercises.ts)
///
/// `name` is the wire value stored in the doc's `type` field — keep it in sync
/// with the web strings above.
enum SavedExerciseType {
  bilingual,
  part5,
  part6,
  part7,
  dictation,
  comprehension;

  bool get _isListening =>
      this == SavedExerciseType.dictation ||
      this == SavedExerciseType.comprehension;

  /// `bilingual|part5|part6|part7` → `reading_exercises`;
  /// `dictation|comprehension` → `listening_exercises`.
  String get collection =>
      _isListening ? 'listening_exercises' : 'reading_exercises';

  /// The doc field holding the serialized exercise body. Web
  /// `savedReadingExercises.ts` names it `passage`; `savedListeningExercises.ts`
  /// names it `item` — must match per-collection or a cross-platform doc fails
  /// to load.
  String get bodyKey => _isListening ? 'item' : 'passage';
}
