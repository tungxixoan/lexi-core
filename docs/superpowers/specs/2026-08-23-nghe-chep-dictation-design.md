# Nghe chép (Dictation) — Design

## Goal

Bring Flutter's "Nghe chép" (Dictation) exercise to the React web app: the first Nghe (Listening) feature on web, and the first web feature to use real synthesized audio playback. AI generates one sentence from 2 due-priority Vocab Bank words; the user listens and types back what they hear, at one of three difficulty levels; save/reuse works the same way it already does for every reading mode.

## Background

Flutter's `lib/features/listening/{data/sources,domain/entities,presentation}/dictation_*` is a complete, working implementation, read in full during brainstorming. `DictationSource.generate()` builds one sentence (10-18 words) from up to 2 headwords, at a given CEFR level/context/target language. `SelectDictationBlanksUseCase` (pure, no AI) then picks which words are hidden, based on `DictationDifficulty`:
- **Khó (Hard)** — no blanks; the user types the entire sentence from scratch into one free-text box.
- **Dễ (Easy)** — exactly 2 single-word blanks (non-adjacent when the sentence has ≥6 words).
- **Trung bình (Medium)** — one contiguous blank span covering ~35% of the sentence's words.

Session mechanics: a Phát/Nghe lại (n) button plays the sentence; "Nộp bài" stays disabled until the user has played at least once; a 0.75x/1x/1.25x speed selector; a seek slider lets the user jump playback to a specific word. Both replay count and seek count reduce the final score. Result screen shows a score percentage, a diff (Khó: character-level red/green; Dễ/Trung bình: per-blank correct/incorrect with the right answer shown inline), the full correct sentence, its Vietnamese meaning, and updates SM-2 for the 2 vocab words used.

Two backend pieces this feature depends on already exist and are live in production, built ahead of this feature during React Web Plan 2: `synthesizeSpeech` (Cloud Functions onCall → self-hosted Piper TTS on Cloud Run, returns `{ audioBase64 }`, request shape `{ text: string (≤500 chars), language: "vi" | "en" }`) and `transcribeAudio` (STT — **not needed by this feature**; dictation is listen-and-type, no voice input from the user). Neither has a web client wrapper yet — this spec's first task builds one.

**Hard constraint discovered during brainstorming**: `synthesizeSpeech`'s `language` param only accepts `"vi" | "en"`, while the web app's `TargetLanguage` supports 5 languages (`vietnamese | english | chinese | korean | japanese`). Since Vietnamese is the user's native/explanation language (never the language being *learned*), this means Nghe chép only works when `settings.targetLanguage === "english"`. Confirmed with the user: **English-only for now** — no attempt to work around this (e.g., falling back to a different voice) is in scope.

## Architecture

**`apps/web/src/lib/synthesizeSpeechClient.ts`** (new — named to avoid colliding with the Cloud Function's own name, following no existing convention since this is the first Cloud-Function-with-audio client wrapper in this codebase):

```ts
export interface SynthesizeSpeechRequest {
  text: string;
  language: "vi" | "en";
}

export interface SynthesizeSpeechResult {
  audioBase64: string;
}

export async function synthesizeSpeech(request: SynthesizeSpeechRequest): Promise<SynthesizeSpeechResult>;
```

Mirrors `generateContent.ts`'s exact shape (`httpsCallable` + a thin async wrapper). Callers convert the returned base64 into a playable `data:audio/wav;base64,...` URL — confirmed WAV by reading `functions/src/services/cloudRunClient.ts` during brainstorming, which sets `Content-Type: audio/wav` on the TTS request to Cloud Run.

**`apps/web/src/lib/dictation.ts`** (new):

```ts
export type DictationDifficulty = "easy" | "medium" | "hard";

export interface BlankSpan {
  startWordIndex: number;
  wordCount: number;
}

export interface DictationItem {
  target: string;
  vietnamese: string;
  vocabIds: string[];
}

export function buildDictationPrompt(headwords: string[], targetLanguage: TargetLanguage): string;
export function parseDictationItem(json: Record<string, unknown>, wordMap: Record<string, string>): DictationItem;
export function selectDictationBlanks(sentence: string, difficulty: DictationDifficulty, random?: () => number): BlankSpan[];
```

`buildDictationPrompt` ports `DictationSource._buildPrompt` verbatim (one 10-18-word sentence, Vietnamese-script-only translation, `vocabWords` list of which input headwords actually appear) — target language is always `"english"` per the language constraint above, so the prompt doesn't need the `contextClause`/topic-name machinery Part5/6/7 use; this feature has no topic filter at all (Flutter's dictation setup has no topic filter either — just language, level, and difficulty). `parseDictationItem` ports `DictationSource._parse`'s tolerant field-mapping, resolving `vocabWords` back to `vocabIds` via the same headword→id map the caller already has from its selected words. `selectDictationBlanks` ports `SelectDictationBlanksUseCase.execute` exactly, including its non-adjacency rule for Dễ (`wordCount >= 6` triggers non-adjacent selection) and its clamped span-length formula for Trung bình (`round(wordCount * 0.35).clamp(2, wordCount - 2)`) — the optional `random` param defaults to `Math.random` and exists purely so tests can inject a deterministic sequence, mirroring Dart's `Random?` parameter.

**Word selection**: reuses the existing `getVocabRecords`/`selectSessionWords`-adjacent machinery already in `apps/web/src/lib/practiceSession.ts` — no new word-selection logic. Mirrors Flutter's `_generate`: due words shuffled first, not-due words shuffled second, take 2 from the concatenated, prioritized list. No language/topic/CEFR filter UI on this feature's own setup screen (Flutter's dictation home screen has Ngôn ngữ/Chủ đề/Cấp độ/Mức độ filters, but Ngôn ngữ is now fixed to English and Chủ đề has no equivalent in the web Vocab Bank's per-word model beyond what `selectSessionWords` already offers elsewhere) — the only new user-facing control this feature adds is **Mức độ** (difficulty).

**`savedReadingExercises.ts`-equivalent, but a new file** (`apps/web/src/lib/savedListeningExercises.ts`), since a dictation item's shape (`{ target, vietnamese, vocabIds }`) has nothing structurally in common with `SavedReadingExercise`'s `passage`/`generationFilters` split — forcing it into the same discriminated union would mean a hollow `generationFilters` (there's no topic/volume filter to persist) and a `passage` field that's really just "the item itself." A parallel, independent module firestore-backed at `users/{uid}/listening_exercises` is cleaner:

```ts
export interface DictationFilters {
  difficulty: DictationDifficulty;
}

export interface SavedListeningExercise {
  id: string;
  type: "dictation"; // matches the union-of-one-so-far pattern used elsewhere before a 2nd type existed
  item: DictationItem;
  generationFilters: DictationFilters;
  targetLanguage: TargetLanguage;
  createdAt: string;
}

export async function saveListeningExercise(uid: string, item: DictationItem, filters: DictationFilters, targetLanguage: TargetLanguage): Promise<string>;
export async function getRandomSavedListeningExercise(uid: string, targetLanguage: TargetLanguage, filters: DictationFilters, excludeId?: string): Promise<SavedListeningExercise | null>;
```

Matching (`getRandomSavedListeningExercise`'s internal filter) is exact-`difficulty`-equality, not overlap — there's only one difficulty per session, unlike topic/volume multi-select. **No audio is ever stored** — "Lấy bài có sẵn" re-fetches the saved `{target, vietnamese, vocabIds}` and calls `synthesizeSpeech` fresh, exactly the same as a newly-generated item's own first playback. This keeps Firestore writes tiny and sidesteps any need for Storage/CDN for this feature (unlike the *cached, shared* pronunciation-TTS system elsewhere in this app, this is deliberately *not* shared/cached — CLAUDE.md already documents "Nghe audio is never cached... always calls Cloud Run live," and that stays true for reused items too, just triggered by "Lấy bài có sẵn" instead of "Tạo bài luyện").

## Playback mechanics (web reimplementation, not a direct port — Flutter's native audio player has no web equivalent)

- **Play/replay**: `<audio>` element, `src` set to the `data:audio/wav;base64,...` URL built from `synthesizeSpeech`'s response. The full sentence's audio is fetched once per generation and cached in component state — replaying just re-plays the same clip (`audio.currentTime = 0; audio.play()`), no repeated backend calls. Replay count increments every replay.
- **Speed**: `audio.playbackRate = 0.75 | 1 | 1.25` — pure client-side, `synthesizeSpeech` is never called again for a speed change.
- **Seek ("nghe lại từ vị trí N")**: Piper's WAV response carries no word-level timing metadata, so there's no real seek-within-clip possible client-side (unlike Flutter's native player, which may support arbitrary time-based seeking on-device — irrelevant here since the constraint is the *audio format*, not the player). Reimplemented as: slice `target` to the words from index N onward, call `synthesizeSpeech` again with just that substring, and play the new (shorter) clip. This matches the *scoring intent* Flutter already established — seeking is a costed "give me a second run at just the end" shortcut, not free scrubbing — and the existing `seekCount`/penalty formula ports unchanged since it only cares about *how many times* seek was used, not the underlying mechanism.

## Session/result UI

**Setup** (own page, not folded into the reading hub — Nghe's own hub, `/listening`, gets a single "🎤 Nghe chép" card for now; a second "🎧 Nghe hiểu" card is explicitly deferred): Mức độ selector (Dễ/Trung bình/Khó, single-select, defaults to Khó matching Flutter's own default) is the only filter. If `settings.targetLanguage !== "english"`, the whole setup surface is replaced with a blocking Vietnamese message ("Nghe chép hiện chỉ hỗ trợ khi Ngôn ngữ mục tiêu là Tiếng Anh — đổi trong Cài đặt để dùng.") and neither action button renders. Otherwise: same due-word auto-selection as Flutter (no manual word picking), "Tạo bài luyện"/"🔀 Lấy bài có sẵn", gated only on having ≥2 eligible words (mirrors Flutter's `_minVocabWords = 2`) — matches this app's established "hide the generate button, not disable-with-tooltip" pattern for insufficient-data states.

**Session**: Phát/Nghe lại (n) button, speed selector, seek slider (visible only when the sentence has >1 word, matching Flutter). Below: cloze inline text fields (Dễ/Trung bình) built the same way `_ClozeInput` does — split `target` into words, render visible words as plain text and each `BlankSpan` as an inline `<input>` sized to its content — or one multi-line `<textarea>` (Khó). "Nộp bài" enabled only once the user has played at least once AND (cloze: every blank non-empty; free-text: non-empty).

**Result**: stat row (Điểm %, Nghe lại count, Số lần tua + penalty %, Thời gian), the diff/cloze-correctness view matching Flutter's `_DiffText`/`_ClozeResult` exactly (character-level red/green for Khó; per-blank correct/incorrect with the right answer shown inline for Dễ/Trung bình), the full correct sentence, its Vietnamese meaning, SM-2 update for both vocab words (reusing this app's existing SM-2 compute/update functions — not reinventing scheduling logic), "Lưu bài" (generated sessions only, hidden once saved — same `justSavedId` pattern as reading), "Câu khác" (replays generate-or-refetch depending on session origin, identical mechanism to reading's `handleNewSession`), "Về trang chính".

## Error handling

- `targetLanguage !== "english"`: blocking message, no generation attempted (see above) — not an error state, a permanent gate until the user changes Cài đặt.
- Missing API key (for the LLM sentence-generation call, not TTS): same inline Vietnamese message every other AI feature already shows.
- `synthesizeSpeech` failure (network, Cloud Run cold-start timeout, etc.): a Vietnamese error with a "Thử lại" affordance on the play button itself — this is a *playback*-time failure, distinct from generation failure, so it doesn't re-run the whole "Tạo bài luyện" flow, just retries the TTS call for the already-generated sentence.
- AI returns an unusable sentence (empty `target`): Vietnamese error "AI không trả về câu luyện hợp lệ.", same loading-phase error UI (role="alert", Thử lại/Về trang chính) as every reading mode.
- "Lấy bài có sẵn" finds no match: same inline-notice-then-AI-fallback as reading, gated the same way (falls back only when ≥2 eligible words exist, mirroring the generate button's own gate).
- Save failure: `role="alert"`, save button stays available to retry.

## Deferred (explicitly out of scope for this spec)

- **Nghe hiểu** (Listening Comprehension) — its own future spec, once Nghe chép ships and the audio-playback groundwork (client wrapper, `<audio>`-based playback pattern) this spec builds is proven.
- Any target language other than English — revisit if/when the TTS backend gains more voices.
- A shared session hook across reading's 3 near-identical pages and this new listening page — not attempted; this is a genuinely different exercise shape (audio, not text/MC), so there's little to share beyond what's already common (Suspense/useSearchParams pattern, save/reuse conventions).
- Any change to the existing cached pronunciation-TTS system (dictionary/vocab-example audio) — entirely separate, untouched.
