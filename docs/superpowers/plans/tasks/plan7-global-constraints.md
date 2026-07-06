# Plan 7 — Global Constraints

- Flutter SDK >=3.22.0, Dart >=3.4.0
- Target platforms: Android, iOS, Web (Plan 6 must be complete)
- Riverpod 2.x with `@riverpod` annotation — no StateNotifier, no ChangeNotifier
- Navigation: GoRouter only — no `Navigator.push`
- All domain entities: immutable, `const` constructors, no public setters; mutation via `copyWith`
- Gemini model: `gemini-2.5-flash`; JSON response mode (`responseMimeType: 'application/json'`)
- Minimum vocab words to start a session: **5** — show error if fewer
- Feature must check `settings.aiEnabled` — show error if AI is off (user must enable AI in Settings)
- Reading tab visibility: always visible on web (`kIsWeb == true`), hidden on mobile unless `settings.showReadingPracticeOnMobile == true`
- **No SM-2 impact** — reading sessions do NOT update `nextReviewAt`, `sm2Interval`, or any SM-2 field
- `geminiApiKey` is **NEVER** stored in Firestore — `SharedPreferences` only
- Typing comparison is character-exact: `typed[i] == target[i]` (case-sensitive; unicode exact match for CJK)
- Passage length: 4–6 sentences (enforced in the Gemini prompt, not validated post-generation)
- `SentenceResult`, `ReadingSessionState`, `ReadingSessionResult` are defined in `reading_practice_provider.dart` (presentation layer) — they are not domain entities
