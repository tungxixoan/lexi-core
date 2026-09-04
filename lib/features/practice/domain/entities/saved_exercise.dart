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

  /// `bilingual|part5|part6|part7` → `reading_exercises`;
  /// `dictation|comprehension` → `listening_exercises`.
  String get collection => switch (this) {
        SavedExerciseType.bilingual ||
        SavedExerciseType.part5 ||
        SavedExerciseType.part6 ||
        SavedExerciseType.part7 =>
          'reading_exercises',
        SavedExerciseType.dictation ||
        SavedExerciseType.comprehension =>
          'listening_exercises',
      };
}
