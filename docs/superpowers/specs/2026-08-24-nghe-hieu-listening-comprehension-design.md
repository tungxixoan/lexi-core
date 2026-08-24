# Nghe hiểu (TOEIC-style Listening Comprehension) on Web — Design

## Context

Nghe hiểu is the second half of "Nghe" (Listening), deferred during the Nghe chép (Dictation) brainstorm. Flutter already ships it (`lib/features/listening/{domain,data,presentation}/...`, providers `listening_comprehension_provider.dart`, screens `comprehension_{home,session,result}_screen.dart`) — read in full before writing this spec, not assumed. Its actual shape, confirmed from the real source:

- AI generates a **multi-turn passage**: either a **conversation** between exactly two speakers "A"/"B" (3-6 alternating turns) or a **talk** by one speaker (2-4 turns, `speaker: null`), plus exactly **3 multiple-choice questions** (4 options each) about it.
- Generated from **CEFR level + AppContext (topic)** — 8 fixed values (general/business/technology/travel/foodAndDrink/health/academic/socialCasual), each with a Vietnamese label + emoji. **Not** tied to the user's saved vocab bank, unlike Nghe chép.
- Scoring is **`correctCount`/`total` only** — no SM-2, no replay/seek penalty, no "must listen once" gate on submit. Confirmed by reading `ComprehensionSessionResult`/`ComprehensionResultScreen` in full: nothing there touches SM-2 or any listening-behavior signal.
- Flutter has **no save/reuse** for this feature at all.
- Playback: turn-by-turn on-device TTS, auto-advancing through turns when not interrupted; a global seek slider spanning word-count across **all** turns combined (`totalWordsOf`/`_resolveGlobalWordIndex` in the real provider); prev/next-turn buttons; replay-from-start; a 3-button speed selector (0.75x/1x/1.25x).
- Flutter differentiates the two speakers' voices by **TTS pitch** (`_pitchFor`: speaker "B" gets pitch 1.3, everyone else 1.0) — a trick specific to on-device TTS engines.

## Decisions made during brainstorming (deviate from Flutter deliberately)

1. **Add save/reuse** (Lưu bài/Lấy bài có sẵn), matching Reading and Nghe chép's established pattern, despite Flutter having none — same reasoning as Nghe chép: audio is cheap to regenerate from the saved transcript, never persisted as a file.
2. **Real distinct voices for speaker A vs B**, not just a visual label. Confirmed via `services/tts-stt/app/tts.py`: the self-hosted Piper backend currently loads **exactly one English voice** (`en_US-lessac-medium.onnx`) — there is no pitch/voice parameter in the synthesis call at all. On-device pitch-shifting has no equivalent here. This requires a genuine backend change: a **4-voice registry** (2 male, 2 female) so a same-gender speaker pair (e.g. two women) still gets two audibly different voices, not just one voice reused twice.
3. **AI prompt extended** to declare each turn's speaker gender, so the client can pick appropriate voices.
4. **Continuous speed slider** (0.5x-2x), matching the improvement just shipped for Nghe chép, instead of Flutter's 3 fixed buttons.
5. Turns are synthesized as **separate clips, played back-to-back** (client chains playback on the `ended` event) rather than merged into one audio file — perceptually identical to a single recording, avoids any WAV-byte-concatenation code entirely. **All turns are prefetched in parallel** as soon as the passage is generated (extending Nghe chép's single-clip prefetch to N clips), so the turn-to-turn transition has no audible gap in the overwhelming common case; a turn that isn't ready yet when playback naturally reaches it waits briefly rather than erroring.
6. No `useDictationAudio` reuse — its state (`replayCount`/`seekPenaltyTotal`/`hasPlayedOnce`-gate) exists purely to feed Nghe chép's own scoring formula, which doesn't apply here (see Decision item above: scoring stays Flutter's simple `correctCount/total`, confirmed with the user explicitly). A new hook, `useComprehensionAudio`, is built for the multi-turn/global-seek/prefetch-all shape instead.
7. English-only gate (`settings.targetLanguage === "english"`), same as every other Nghe feature — forced by `synthesizeSpeech`'s `"vi"|"en"` backend constraint, unlike Flutter which allows any `Language` value since on-device TTS supports them all.

## Architecture

### Backend: 4-voice registry (the one genuinely new backend surface this session touches)

`services/tts-stt/app/tts.py`'s `VOICE_MODELS: dict[str, str]` (currently `{"vi": "...", "en": "..."}`) becomes nested per language, with English carrying 4 named slots:

```python
VOICE_MODELS: dict[str, dict[str, str]] = {
    "vi": {"default": "vi_VN-vais1000-medium.onnx"},
    "en": {
        "default": "en_US-lessac-medium.onnx",     # unchanged — existing default, confirmed FEMALE
        "female1": "en_US-lessac-medium.onnx",     # same file as default, no new download
        "female2": "en_US-hfc_female-medium.onnx", # explicitly named/confirmed female in Piper's own VOICES.md
        "male1":   "en_US-hfc_male-medium.onnx",   # explicitly named/confirmed male ("cleanest male voice") in Piper's own VOICES.md
        "male2":   "en_US-norman-medium.onnx",     # candidate — gender not stated in its model card; the implementation task must listen to the sample at huggingface.co/rhasspy/piper-voices (en/en_US/norman) and confirm it reads as male before downloading, substituting from {john, danny, sam, bryce, joe, ryan} if it doesn't
    },
}
```

Three of the four new/reused files are unambiguous (`lessac` confirmed female by an independent voice-ranking source, `hfc_female`/`hfc_male` self-declaring by name in Piper's own `VOICES.md`). `male2` is a reasonable candidate pending one concrete, cheap verification step (listening to the published sample) — not an open design question; the *shape* (2 male + 2 female, keyed by name) is fixed either way, and a substitution only changes which filename gets downloaded.

`_load_voice(language, voice)` gains a `voice: str = "default"` parameter, looks up `VOICE_MODELS[language][voice]`, caches per `(language, voice)` pair (not just `language`, since multiple voices per language now coexist). `synthesize(text, language, voice)` threads it through.

`POST /synthesize`'s `SynthesizeRequest` Pydantic model gains an optional `voice: str | None = None` field; the endpoint passes `request.voice or "default"` to `tts.synthesize`, so every existing caller (Nghe chép, any other TTS use) that never sends `voice` gets byte-identical behavior to today.

`functions/src/synthesizeSpeech.ts`'s `SynthesizeSpeechRequest` gains an optional field:

```ts
export interface SynthesizeSpeechRequest {
  text: string;
  language: "vi" | "en";
  voice?: "male1" | "male2" | "female1" | "female2";
}
```

`isSynthesizeSpeechRequest`'s validation allows `voice` to be `undefined` or one of the 4 literals (reject anything else — this is a closed set, not free text, since it maps directly to the backend's fixed registry). `synthesizeViaCloudRun` and `callCloudRun` thread `voice` through to the JSON body sent to `/synthesize`, defaulting to omitted (`undefined`) when not given — no behavior change for any caller that doesn't pass it. `apps/web/src/lib/synthesizeSpeechClient.ts`'s `SynthesizeSpeechRequest` type gains the same optional `voice` field, mirroring the Cloud Function's.

This is a Blaze-plan Cloud Run redeploy (`gcloud run deploy`, per root `CLAUDE.md`'s deploy gotchas — a new Docker image with the added voice model files) plus a `firebase deploy --only functions` for the Cloud Function contract change. Both are manual, explicit deploy steps, same as every other backend change in this project — not automated by this plan.

### Passage generation & voice assignment (client-side)

`apps/web/src/lib/listeningPassage.ts` (new file, mirrors `dictation.ts`'s role for Nghe chép):

- `buildListeningPassagePrompt(level: CefrLevel, context: AppContext, targetLanguage: TargetLanguage): string` — ports Flutter's `ListeningPassageSource._buildPrompt` word-for-word, with one addition: each turn's JSON object gains a `"gender": "male"|"female"` field, and the prompt instructs the AI to keep gender consistent per speaker letter across the whole passage (a conversation always has exactly one gender value per "A" and per "B", even though a re-generation might pick different values run to run).
- `parseListeningPassage(json): ListeningPassage` — ports `_parse` for `kind`/`turns`/`questions`, plus derives `speakerGenders: Record<"A" | "B" | "solo", "male" | "female">` from each speaker's **first-seen** turn (defensive against the AI being inconsistent on a later turn — the app picks once, deterministically, and never re-derives per turn).
- `assignVoices(passage): Record<"A" | "B" | "solo", VoiceId>` — deterministic, client-side, computed once when a session starts (not per Cloud Function call). Walks distinct speakers in order of first appearance; for each, takes the next unused voice slot of that speaker's declared gender (`female1` before `female2`, `male1` before `male2`; wraps back to the first slot of that gender if more than 2 same-gender speakers ever appeared, which the generation prompt's 2-speaker-conversation rule makes unreachable today, but the function doesn't assume it). A `talk` (one speaker) always resolves to exactly one voice; a `conversation` (two speakers, per Flutter's own generation rule) always resolves to exactly two — the same voice only when the two speakers happen to share a gender AND the wrap-around case is hit, which per the above is unreachable under today's generation rule.

Types (`apps/web/src/lib/listeningPassage.ts`):

```ts
export type ListeningKind = "conversation" | "talk";
export type SpeakerGender = "male" | "female";
export type VoiceId = "male1" | "male2" | "female1" | "female2";

export interface ListeningTurn {
  speaker: "A" | "B" | null; // null for a talk's single speaker
  text: string;
}

export interface ListeningQuestion {
  question: string;
  options: string[]; // always 4
  correctIndex: number; // 0-3
}

export interface ListeningPassage {
  kind: ListeningKind;
  turns: ListeningTurn[];
  questions: ListeningQuestion[]; // always 3
  level: CefrLevel;
  context: AppContext;
  targetLanguage: TargetLanguage;
}
```

`apps/web/src/lib/appContext.ts` (new, small, mirrors `languages.ts`'s `LANGUAGE_LABELS` pattern): the 8 `AppContext` values with Vietnamese labels + emoji, copied verbatim from Flutter's `app_context.dart`.

### Playback: `useComprehensionAudio`

New hook, `apps/web/src/lib/useComprehensionAudio.ts`, shaped for the multi-turn/global-seek case — not a generalization of `useDictationAudio` (their state shapes don't overlap: no `replayCount`/`seekPenaltyTotal`/`hasPlayedOnce`-gate here, since nothing in Nghe hiểu's scoring reads listening behavior).

```ts
export interface UseComprehensionAudioResult {
  isSpeaking: boolean;
  currentTurnIndex: number;
  estimatedGlobalWordIndex: number; // time-proportional estimate, same technique as Nghe chép's estimatedWordIndex, extended across turn boundaries
  speed: number;
  error: string | null;
  play: () => void;        // plays currentTurnIndex, auto-advancing through subsequent turns on natural completion
  stop: () => void;
  previousTurn: () => void;
  nextTurn: () => void;
  replayFromStart: () => void;
  seekToGlobalWord: (globalWordIndex: number) => Promise<void>;
  setSpeed: (speed: number) => void;
}

export function useComprehensionAudio(
  passage: ListeningPassage | null,
  voiceAssignment: Record<"A" | "B" | "solo", VoiceId>,
  sessionKey: string | number
): UseComprehensionAudioResult
```

Internals, building directly on the patterns proven in the Nghe chép audio-improvements plan:

- **Prefetch-all-turns**: a `useEffect` keyed on `[passage, sessionKey]` fires `synthesizeSpeech` for **every** turn in parallel the moment `passage` is set (each request tagged with that turn's speaker's assigned `voice`), storing each turn's promise (with the same `cancelled`-flag-in-cleanup guard the final Nghe chép review required, to prevent a stale prefetch from a discarded session clobbering a new one) and, on success, its resolved clip URL in a `Map<turnIndex, string>` ref.
- **Sequential auto-advance playback**: `play()` starts the current turn's clip (using the prefetched URL if ready, else awaiting that turn's in-flight prefetch promise exactly like Nghe chép's `play()` — never a duplicate fetch) and attaches a one-shot `ended` listener that advances `currentTurnIndex` and starts the next turn's clip, recursing until the last turn finishes. If the next turn's clip isn't ready when `ended` fires (prefetch still in flight), `play()`'s own "await the in-flight promise" path covers it — a brief wait, not a broken gap.
- **Global word tracking**: a precomputed `turnWordOffsets: number[]` (cumulative word count before each turn, computed once from `passage.turns`) plus the same `timeupdate`-driven time-proportional formula from Nghe chép, now producing `estimatedGlobalWordIndex = turnWordOffsets[currentTurnIndex] + (local estimate within the current turn's clip)`. The base resets — synchronously, not just via the next `timeupdate` — on every turn transition (explicit `nextTurn()`/`previousTurn()`, the auto-advance on `ended`, and `seekToGlobalWord`), mirroring exactly how `play()`/`seekTo()` reset `baseWordIndexRef` in `useDictationAudio`. Word-splitting (for both `turnWordOffsets` and the per-turn local word count) reuses `targetWords` imported from `./dictation` rather than reimplementing whitespace-splitting — it's a generic helper despite living in that file, and reusing it keeps tokenization identical everywhere in the app.
- **Global seek**: `seekToGlobalWord(globalWordIndex)` resolves which turn + local word offset that index falls in (port of Flutter's `_resolveGlobalWordIndex`), switches `currentTurnIndex` if needed, and re-synthesizes "the remainder of that turn starting from that word" via a fresh `synthesizeSpeech` call (same no-caching-for-seeks rule as Nghe chép — the substring text differs every time, so there's nothing to cache) tagged with that turn's speaker's voice.
- **Speed**: same continuous-slider pattern as Nghe chép's just-fixed `speedRef` approach (read from a ref inside the playback function, not a stale `useCallback` closure) — applies live to whichever turn's clip is currently loaded.
- Reset effect (keyed on `[passage, sessionKey]`) zeroes `currentTurnIndex`, `estimatedGlobalWordIndex`, pauses in-flight audio, and clears prefetch state — same cross-session leak class Nghe chép's Critical/Important findings were about, addressed from the start here rather than discovered after the fact.

### Scoring

`apps/web/src/lib/listeningPassage.ts` also exports `scoreComprehension(passage: ListeningPassage, selectedAnswers: (number | null)[]): number` — `correctCount / questions.length`, ported directly from Flutter's `ComprehensionSessionResult.correctCount`. No SM-2, no replay/seek penalty, no listen-gate on submit (`canSubmit` is purely `selectedAnswers.every(a => a !== null)`, confirmed matching Flutter's own rule).

### Save/reuse

`apps/web/src/lib/savedListeningExercises.ts`'s discriminated union gains a `"comprehension"` member:

```ts
export interface ComprehensionFilters {
  context: AppContext;
  level: CefrLevel;
}

// New union member alongside the existing "dictation" one:
| {
    id: string;
    type: "comprehension";
    item: { kind: ListeningKind; turns: ListeningTurn[]; questions: ListeningQuestion[] };
    generationFilters: ComprehensionFilters;
    targetLanguage: TargetLanguage;
    createdAt: string;
  }
```

No audio, no chosen voices, and no `speakerGenders` are persisted — a reused passage's voices are re-assigned fresh via `assignVoices` each time it's played (the same turns, but possibly different actual voice files than the original session — acceptable, since nothing about which specific voice was used is meaningful to remember). `getRandomSavedListeningExercise` matches on `context`+`level` exact equality (mirrors dictation's exact-`difficulty`-equality rule, not reading's overlap-based topic matching).

### UI

- **Hub** (`apps/web/src/app/(app)/listening/page.tsx`): gains a second card, "🎧 Nghe hiểu", alongside the existing Nghe chép card — same English-only gate, same generate/reuse button pair, but its own filter row (Chủ đề dropdown + Cấp độ dropdown, no difficulty picker — Nghe hiểu has no difficulty concept). Routes to `/listening/comprehension?context=X&level=Y&action=Y`.
- **Session** (`apps/web/src/app/(app)/listening/comprehension/page.tsx`, new): turn indicator ("Lượt N/M — Người nói A"), global seek slider (reusing the drag-guard + live-playhead-sync pattern from Nghe chép's just-fixed page, adapted to `estimatedGlobalWordIndex`), play/stop, prev/next-turn, replay-from-start, continuous speed slider, then all 3 `McQuestionCard`s (reused unmodified — its `explanation` prop is optional and unused here, matching Flutter's `ListeningQuestion` having no explanation field), submit button (gated only on all 3 answered, no listen-gate).
- **Result** (same page, result phase): `correctCount/3`, per-question breakdown (reusing `McQuestionCard` in result mode), full transcript with speaker labels ("A: ...", "B: ..." or unprefixed for a talk), Lưu bài/Về trang chính/Bài khác — matching the established reading/dictation result-screen button set.

## Error Handling

- Passage generation failure (empty `turns`/`questions`, malformed AI JSON): same pattern as every other AI-generated exercise this session — a Vietnamese error message with Thử lại/Về trang chính, never a silent freeze.
- A turn's prefetch failing: silent (matches Nghe chép's prefetch-failure philosophy) — `play()`/`seekToGlobalWord` retry on-demand when that turn is actually needed.
- A mid-passage synthesis failure during auto-advance (a turn errors while the previous one just finished): surfaces `error` state and stops auto-advance at that turn, rather than silently truncating the passage — the user can retry via `play()` again from the current turn.

## Testing

- `listeningPassage.ts`: prompt/parse tests mirroring `dictation.ts`'s own test style; `assignVoices` tests covering talk (1 speaker), male-female conversation, and same-gender conversation (both directions) confirming two distinct voice ids every time; `scoreComprehension` boundary tests (0/3, 1/3, 2/3, 3/3, and a `null` unanswered entry never counting as correct).
- `useComprehensionAudio.test.ts`: prefetch-all-turns-in-parallel (assert N `synthesizeSpeech` calls fire together, not sequentially, once `passage` is set); auto-advance via simulated `ended` events across all turns; global word estimate crossing a turn boundary; seek resolving to the right turn + local offset; the same `cancelled`-guard pattern from Nghe chép's final-review fix, proven the same way (a stale prefetch from a discarded session must not clobber a live one).
- `savedListeningExercises.ts`: save/round-trip and `getRandomSavedListeningExercise` matching tests mirroring the existing `"dictation"` member's test suite structure, adapted to `ComprehensionFilters`.
- Page-level tests for the hub's new card and the session/result page, following the exact structure of Nghe chép's own `page.test.tsx` (language gate, generate/reuse flows, save button, "Bài khác").
- Backend (`services/tts-stt/`, `functions/src/synthesizeSpeech.ts`): tests for the new `voice` parameter — default behavior unchanged when omitted, correct model loaded per `(language, voice)` pair, invalid `voice` value rejected.
