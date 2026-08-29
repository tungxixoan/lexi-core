# Chuyển Flutter TTS sang Cloud Function (Piper) — Design

## Context

Item #3 of the cleanup backlog (item #2, AI settings Firestore sync, shipped earlier today). Flutter currently plays pronunciation/listening audio via on-device `flutter_tts` (`lib/services/tts_service.dart`'s `FlutterTtsService`, wired through `lib/core/di/app_providers.dart`'s `ttsServiceProvider`), at 5 real call sites: word/example pronunciation in Tra từ (`word_result_widget.dart`, `sentence_result_widget.dart`), word/example pronunciation in vocab detail (`vocab_detail_screen.dart`), and full-sentence/turn playback in Nghe chép (`dictation_practice_provider.dart`) and Nghe hiểu (`listening_comprehension_provider.dart`). `apps/web/` already plays audio through two Cloud Functions backed by a self-hosted Piper TTS service on Cloud Run: `getPronunciation` (cached by `sha256(text+lang+voice)` in Firebase Storage, for dictionary/vocab word-and-sentence pronunciation) and `synthesizeSpeech` (uncached, for freshly AI-generated dictation sentences and listening-comprehension turns). Both are `onCall` functions in `asia-southeast1` (CLAUDE.md).

**Key constraint discovered during brainstorming**: Piper's self-hosted voices only cover Vietnamese and English (`functions/src/getPronunciation.ts`'s `VOICE_IDS: Record<"vi"|"en", string>`; `synthesizeSpeech`'s `language: "vi"|"en"`) — there is no Chinese/Korean/Japanese voice. Flutter's on-device `flutter_tts` currently covers all 5 target languages via `Language.ttsLocale`. Web already hits this same ceiling and copes by hiding its pronunciation button when `ttsLanguageCode(targetLanguage)` returns `null` (`apps/web/src/lib/pronunciation.ts`); it also hardcodes `language: "en"` in its own dictation/listening-comprehension audio hooks today, i.e. those two features are implicitly English-only on web already.

**Decision (user, when presented this fork): no pronunciation for zh/ko/ja for now, matched identically on both platforms** — not a Flutter-only regression accepted quietly, but the explicit, intended state of both apps until Piper ever gets more voices. This is a real, deliberate feature reduction on Flutter (which could previously pronounce zh/ko/ja via the on-device engine) in exchange for architectural unification with web and removal of a redundant on-device TTS engine.

**Second constraint discovered during brainstorming**: Nghe hiểu (Listening Comprehension) differentiates its two conversation speakers ("A"/"B") by pitch-shifting the on-device engine (`listening_comprehension_provider.dart`'s `_pitchFor(speaker)`, 1.3 for B, 1.0 otherwise) — a technique with no equivalent on pre-rendered audio from a stateless Cloud Function. Web solves this properly: it added a `gender` field to the listening-passage AI prompt and entity (`apps/web/src/lib/listeningPassage.ts`), and picks one of Piper's 4 real voices (`male1`/`male2`/`female1`/`female2`) per speaker via `assignVoices()`. **Decision (user): port this properly to Flutter** (prompt + entity + parser + voice assignment), not drop speaker differentiation.

## Decisions made during brainstorming

- **Pronunciation (Tra từ, chi tiết từ vựng) and Nghe chép/Nghe hiểu both route through Cloud Functions now** — no flutter_tts fallback for any language, including vi/en/zh/ko/ja. `flutter_tts` is removed from the project entirely (dependency + provider).
- **zh/ko/ja get no audio anywhere**, matching web exactly:
  - Pronunciation buttons (word/sentence in Tra từ, word/example in vocab detail) are hidden when the target language has no Piper voice — mirrors `apps/web/`'s `PronunciationButton`'s `if (!language) return null`.
  - Nghe chép and Nghe hiểu home screens block session creation entirely (an inline blocking message, matching this codebase's existing `AiDisabledCard`-style gating already used in both home screens for "AI disabled"/"not enough vocab words") when the selected target language has no Piper voice.
- **Nghe hiểu's two-speaker voice differentiation is ported in full**: `ListeningPassageSource`'s prompt gains a per-turn `"gender": "male"|"female"` field (word-for-word matching `apps/web/src/lib/listeningPassage.ts`'s prompt addition); `ListeningTurn`/`ListeningPassage` gain `gender`/`speakerGenders` fields; a new `assignVoices()` ported to Dart picks real Piper voices per speaker, replacing the pitch hack.
- **Playback speed control (0.75x/1x/1.25x, already shipped on Nghe chép/Nghe hiểu) is preserved**, but its `_rateFor()` mapping must change: the current formula (`(0.5 * speedMultiplier).clamp(0.0, 1.0)`) is a `flutter_tts`-specific speech-rate scale and would silently play audio at the wrong speed under the new player (whose "rate" is a natural multiplier, 1.0 = normal — matching `apps/web/`'s `audioEl.playbackRate = speed`). `_rateFor` becomes a direct pass-through of the multiplier.
- **Error handling for playback failures stays as simple as today**: catch and no-op (log only) on a failed `pronounce`/`synthesize` call. None of the 5 call sites has an existing error-display affordance for TTS failures (unlike web's `PronunciationButton`, which shows a "⚠️" state) — adding one is out of scope for a backend swap; this can be a future polish item.

## Architecture

### `Language.ttsCloudCode` (`lib/features/dictionary/domain/entities/language.dart`) — new extension getter

```dart
/// Matches apps/web/src/lib/pronunciation.ts's ttsLanguageCode() — the
/// self-hosted Piper TTS service only has voices deployed for Vietnamese
/// and English; null means no server-side pronunciation/audio is available
/// for this target language.
String? get ttsCloudCode => switch (this) {
      Language.vietnamese => 'vi',
      Language.english => 'en',
      _ => null,
    };
```

Every gating decision (pronunciation buttons, Nghe chép/Nghe hiểu availability) reads this one getter — no duplicated vi/en checks.

### `TtsService` (`lib/services/tts_service.dart`) — split into two methods, Cloud-Function-backed

```dart
enum PronunciationTier { word, sentence }

abstract class TtsService {
  /// Cached word/sentence pronunciation (dictionary/vocab lookups) —
  /// calls the `getPronunciation` Cloud Function, which caches by
  /// sha256(text+lang+voice) in Firebase Storage and is shared across all
  /// users. No-ops silently if [language].ttsCloudCode is null.
  Future<void> pronounce(String text, Language language, {required PronunciationTier tier});

  /// Uncached synthesis for freshly AI-generated text (Nghe chép sentences,
  /// Nghe hiểu turns) — calls `synthesizeSpeech`, never cached. [voice]
  /// picks one of Piper's 4 voices ('male1'/'male2'/'female1'/'female2');
  /// [rate] is a post-synthesis playback-speed multiplier (1.0 = normal).
  /// No-ops silently if [language].ttsCloudCode is null.
  Future<void> synthesize(String text, Language language, {String? voice, double? rate});

  Future<void> stop();
}
```

This replaces the old single `speak(text, language, {pitch, rate})` — the two Cloud Functions have genuinely different contracts (cached-by-tier vs. uncached-with-voice), so two explicit methods are clearer than one method silently branching on an inferred tier.

`CloudTtsService implements TtsService` is the new implementation: uses the existing `CloudFunctionCaller` (from item #2, `lib/core/services/cloud_function_caller.dart` — same `asia-southeast1` region, same test-injection pattern) to call `getPronunciation`/`synthesizeSpeech`, and a new `audioplayers` package dependency to actually play the result — `getPronunciation` returns `{url: string}` (played via `UrlSource`), `synthesizeSpeech` returns `{audioBase64: string}` (base64-decoded and played via `BytesSource`).

Both methods must **block until playback finishes**, matching `flutter_tts`'s `awaitSpeakCompletion(true)` — `dictation_practice_provider.dart`/`listening_comprehension_provider.dart` both `await` a speak call and only then flip `isSpeaking: false`. `audioplayers`' `.play()` only awaits playback *starting*, not finishing, so `CloudTtsService` listens for `AudioPlayer.onPlayerStateChanged` and resolves on either `PlayerState.completed` (natural end) or `PlayerState.stopped` (an explicit `stop()` call elsewhere interrupting it) — the latter is essential, since several call sites do `await tts.stop(); await tts.speak(...)` in quick succession (e.g. seeking), and a pending `pronounce`/`synthesize` call must not hang forever waiting for a completion event that a `.stop()` preempts.

### `app_providers.dart` — wiring

`ttsServiceProvider` now builds `CloudTtsService()` instead of `FlutterTtsService(ref.watch(flutterTtsProvider))`; the `flutterTtsProvider` and its import are removed. `flutter_tts` is removed from `pubspec.yaml`; `audioplayers` is added.

### Pronunciation call sites — hide the button for unsupported languages

`word_result_widget.dart`, `sentence_result_widget.dart`, `vocab_detail_screen.dart`: each `IconButton` that calls `tts.pronounce(...)` is wrapped so it renders nothing (`SizedBox.shrink()`) when `targetLanguage.ttsCloudCode == null` — mirrors `PronunciationButton`'s `if (!language) return null`. The tier passed is `PronunciationTier.word` for a headword, `PronunciationTier.sentence` for an example/full sentence.

### Nghe chép / Nghe hiểu home screens — block session creation for unsupported languages

`dictation_home_screen.dart` and `comprehension_home_screen.dart` (mirroring `dictation_home_screen.dart`'s structure) each gain one more gate in their existing `if/else if` chain (alongside the current `!aiEnabled`/`words.length < min` checks), using the same block-message widget already used there, shown when the screen's selected `_language.ttsCloudCode == null`: "Tính năng này chưa hỗ trợ [ngôn ngữ]. Hãy chọn Tiếng Việt hoặc English." This sits before the "Tạo bài luyện"/generate button, so a session can never be generated for an unsupported language — no changes needed to the session/practice provider's own generate() validation, since the button to reach it is gone.

### Nghe hiểu — real two-speaker voices

`lib/features/listening/domain/entities/listening_passage.dart`: `ListeningTurn` gains `final String? gender;` ('male'/'female'/null); `ListeningPassage` gains `final Map<String, String> speakerGenders;` (keyed by speaker key: 'A', 'B', or 'solo' — ported from web's `Speaker` union and `speakerKey()` helper).

`lib/features/listening/data/sources/listening_passage_source.dart`: `_buildPrompt` gains the same `"gender"` instruction web's prompt has, word-for-word translated; the requested JSON shape gains `"gender": "male" or "female"` per turn. `_parse` derives `speakerGenders` from each speaker's first-seen turn (first-seen wins, exactly like `apps/web/src/lib/listeningPassage.ts`'s `parseListeningPassage` — an AI response that's inconsistent about a speaker's gender on a later turn must not change which voice gets used mid-passage).

New top-level function (same file or a small new `lib/features/listening/domain/entities/voice_assignment.dart`, decided at plan time): `Map<String, String> assignVoices(ListeningPassage passage)` — ports `apps/web/src/lib/listeningPassage.ts`'s `assignVoices()` exactly: walks distinct speakers in order of first appearance, assigns the next unused voice slot (1 or 2) of that speaker's declared gender, defaulting to 'female' when a speaker's gender is missing (an arbitrary but harmless choice — the alternative of throwing would break an otherwise-usable passage over a cosmetic voice-picking detail).

`listening_comprehension_provider.dart`: `_pitchFor(speaker)` is deleted; a `Map<String, String> _voiceAssignment` is computed once per generated passage (via `assignVoices(passage)`) and stored in `ListeningSessionState`; every `tts.synthesize(...)` call passes `voice: _voiceAssignment[speakerKey]` instead of `pitch: _pitchFor(...)`.

### Playback speed fix

In both `dictation_practice_provider.dart` and `listening_comprehension_provider.dart`, `double _rateFor(double speedMultiplier) => (0.5 * speedMultiplier).clamp(0.0, 1.0);` becomes `double _rateFor(double speedMultiplier) => speedMultiplier;` — the multiplier (0.75/1.0/1.25) now passes straight through to `CloudTtsService.synthesize`'s `rate`, matching `audioplayers`' natural playback-rate scale (and `apps/web/`'s identical `audioEl.playbackRate = speed`).

## Error Handling

- `pronounce`/`synthesize` catch any exception from the Cloud Function call or from playback and no-op (log only) — matches the current lack of any error-display UI at these 5 call sites. Not a new best-effort convention invented for this plan; simply not regressing past the (also silent) failure behavior `flutter_tts` had.
- A language with no Piper voice never reaches `pronounce`/`synthesize` at all in the common case (buttons hidden, sessions blocked) — the methods' own internal `ttsCloudCode == null` no-op is a defensive second layer, not the primary gate.

## Testing

- `Language.ttsCloudCode`: unit test all 5 languages, confirming only vietnamese/english return non-null.
- `CloudTtsService`: unit tests via an injected fake `CloudFunctionCaller` (matching this codebase's established seam pattern from item #2) — `pronounce` sends the correct `{text, language, tier}` payload and plays the returned `url`; `synthesize` sends the correct `{text, language, voice?}` payload and plays the decoded `audioBase64`; both no-op for an unsupported language without calling the Cloud Function at all; `stop()` unblocks a pending `pronounce`/`synthesize` call (this needs an injectable/fakeable `AudioPlayer` seam — decided at plan time whether to fake the whole player or just assert on the completion-await logic in isolation).
- `assignVoices()`: unit tests porting web's own test cases — deterministic ordering by first appearance, wraps back to slot 1 after 2 speakers of the same gender, defaults to 'female' for a missing gender.
- `ListeningPassageSource`: existing tests extended to assert the prompt includes the gender instruction and that `_parse` correctly derives `speakerGenders` (including the first-seen-wins case).
- `dictation_practice_provider_test.dart` / `listening_comprehension_provider_test.dart`: every existing `mockTts.speak(...)` mock/verification updated to `mockTts.synthesize(...)`, with `rate` expectations updated from the old `0.5 * m` values to direct multipliers (e.g. `rate: 0.5` → `rate: 1.0`), and `pitch:` expectations replaced by `voice:` expectations reflecting the new `assignVoices()`-driven values.
- Widget-level: the 3 pronunciation-button call sites get a check that the button renders nothing for an unsupported language (if a widget-test seam already exists for that screen — decided at plan time per file, matching this codebase's existing precedent of not retrofitting widget tests onto screens that never had them).
