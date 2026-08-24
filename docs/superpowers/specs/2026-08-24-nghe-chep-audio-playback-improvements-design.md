# Nghe chép — Audio Playback Improvements (Prefetch, Live Seek Playhead, Continuous Speed) Design

## Context

Nghe chép (Dictation) shipped on web this session (`docs/superpowers/specs/2026-08-23-nghe-chep-dictation-design.md`, `docs/superpowers/plans/2026-08-23-nghe-chep-dictation.md`). It deliberately does **not** literally port Flutter's on-device-TTS playback model: Flutter speaks live via the phone's TTS engine on every call (weak rate control, weak seek — it's literally re-speaking from a point); web instead fetches a real audio clip from a cloud TTS backend (Piper, self-hosted on Cloud Run, proxied by the `synthesizeSpeech` Cloud Function) and plays it as an `<audio>` element.

Now that audio is a real fetched clip rather than an on-device engine call, three follow-up improvements are in scope, all scoped to `apps/web/src/lib/useDictationAudio.ts` and its one consumer, `apps/web/src/app/(app)/listening/dictation/page.tsx`:

1. **Prefetch audio as soon as the sentence is ready**, instead of waiting for the user's first Play click, so Play feels instant.
2. **A seek-slider playhead that visually tracks real playback progress**, instead of standing still until the user drags it.
3. **A continuous speed slider** (more granular than today's three fixed buttons).

None of these touch scoring (`computeDictationScore`, `seekPenaltyFraction`, `sm2QualityFromScore` in `apps/web/src/lib/dictation.ts`) or the SM-2/save-reuse/language-gate work already shipped and reviewed this session — this is playback UX only.

## Architecture

All three changes live inside the existing client-side architecture — no backend changes. This was an explicit decision: the app's Cloud Functions are deliberately thin, independent AI-proxy endpoints (see root `CLAUDE.md`: "scope limited to AI-proxy endpoints only — not a general data proxy"), and the client already orchestrates the two-step "generate sentence → synthesize audio" sequence itself. Prefetching means the client fires the second step immediately after the first completes, rather than waiting for a user click — it does not mean chaining the two Cloud Functions into a server-side pipeline, which would be a bigger, unrelated architectural change and was explicitly rejected during brainstorming (it would also add latency, since the client can no longer race/observe the two steps independently).

### 1. Prefetch on generate

`useDictationAudio(sentence, sessionKey)` gains an internal `useEffect` keyed on `[sentence, sessionKey]` — the same trigger as the existing state-reset effect. Whenever `sentence` is non-empty, it immediately calls `synthesizeSpeech({ text: sentence, language: "en" })` in the background and stores **the promise itself** (not just the eventual URL) in a new ref, `prefetchPromiseRef`.

`play()`'s branching must change, not just gain a new fallback. Today, the "use the cached clip, don't re-fetch" branch is gated on `hasPlayedOnce && fullClipUrlRef.current` — which is exactly wrong for prefetch, since `hasPlayedOnce` is still `false` on the user's very first Play click, the one case this feature most needs to speed up. The branch condition changes to key on `fullClipUrlRef.current` alone:

- If `fullClipUrlRef.current` is already set (prefetch finished, **or** this is a genuine replay) — play immediately, no fetch. Whether this increments `replayCount` or sets `hasPlayedOnce` for the first time still depends on the *current* value of `hasPlayedOnce` at call time (unchanged rule: first consumption sets the flag, every consumption after that counts as a replay) — only the gating condition for "do we already have a clip to play" changes, not the replay/first-play bookkeeping.
- Else if `prefetchPromiseRef.current` is set (prefetch in flight) — `await` that exact promise instead of calling `synthesizeSpeech` again, then proceed exactly like the existing "just fetched" path (set `fullClipUrlRef`, set `hasPlayedOnce`, play). This guarantees no duplicate Cloud Function call regardless of timing, and is what makes the first Play click fast once prefetch has had time to start.
- Else (prefetch effect hasn't fired yet, or its promise already rejected and was cleared) — falls back to today's on-demand `synthesizeSpeech` call, unchanged.

If the prefetch promise rejects, the rejection is caught inside the prefetch effect itself (never surfaced as `error` state, since the user hasn't asked for anything yet) and `prefetchPromiseRef.current` is cleared back to `null` — so a subsequent `play()` retries with a fresh on-demand call, identical to today's error-then-retry path. No loading indicator is shown during prefetch (confirmed with the user); `isLoading` only ever reflects `play()`/`seekTo()`'s own wait on a promise the user is actually blocked on.

Prefetch **never sets `hasPlayedOnce`**. That flag is the sole gate for enabling "Nộp bài" and is read directly into `computeDictationScore`'s replay/seek accounting — it must only flip on genuine user action (`play()` or `seekTo()` actually being invoked), never as a side effect of a background fetch completing.

A stale prefetch from a discarded session (e.g. a seek — which, unlike `play()`, doesn't force the prefetch to settle — followed by "Câu khác" before the previous prefetch resolved) needs explicit handling, not just the existing reset. The sessionKey-guarded reset effect clears `fullClipUrlRef` and `prefetchPromiseRef` on every genuine session change, which stops the NEW session's `play()` from *awaiting* the stale promise — but it does nothing to stop the stale promise's own `.then()`/`.catch()` callbacks from firing afterward and writing into those same refs anyway, since the promise itself keeps running regardless of what the refs point to now. A late `.then()` would silently overwrite the new session's `fullClipUrlRef` with the OLD sentence's audio; a late `.catch()` would null the new session's in-flight `prefetchPromiseRef`, forcing a wasted duplicate fetch. The prefetch effect closes over a `cancelled` flag, set to `true` in the effect's cleanup function (which React runs automatically before the next effect invocation whenever `[sentence, sessionKey]` changes), and both the `.then()` and `.catch()` bodies check `if (cancelled) return;` before touching either ref.

### 2. Live-tracking seek playhead (Approach A: time-proportional estimate)

Chosen over two rejected alternatives: real per-word timestamps from Piper (not supported by the self-hosted TTS engine — this was already confirmed a limitation when the original seek design was built) and client-side audio-analysis word-boundary detection (fragile, no more accurate than the chosen approach, more code).

The hook tracks two new pieces of internal state:

- `baseWordIndexRef` (ref): the word index the *currently loaded clip* starts speaking from. Set to `0` whenever `play()` loads the full clip (first play, or a cached replay). Set to `wordIndex` whenever `seekTo(wordIndex)` successfully loads its re-synthesized remainder clip.
- `estimatedWordIndex` (new state, exposed on `UseDictationAudioResult`): recomputed on every `timeupdate` event from the `<audio>` element via

  ```text
  estimatedWordIndex = baseWordIndexRef.current
    + (audio.currentTime / audio.duration) * (totalWords - baseWordIndexRef.current)
  ```

  clamped to `[0, totalWords - 1]` and rounded to the nearest integer. `totalWords` is `targetWords(sentence).length` (already an exported helper in `dictation.ts`). If `audio.duration` is not finite (`NaN`/`Infinity` — happens before metadata loads, and is the norm in jsdom test environments, which don't decode real audio) the formula is skipped and `estimatedWordIndex` falls back to `baseWordIndexRef.current` unchanged.

  This is an estimate, not an exact word-boundary — TTS doesn't speak every word at identical duration (punctuation pauses, word length). It's presented to the user only as a moving slider position, never fed into scoring. A real `seekTo()` (on release) always lands exactly on the requested word, since it re-synthesizes from that exact point — estimation error only affects the *visual* position while a clip plays, never the actual seek target.

  `estimatedWordIndex` resets to `0` in the existing sentence/sessionKey-change reset effect, alongside the other state already reset there.

**Page-side wiring (`dictation/page.tsx`):** the seek `<input type="range">` currently displays a local `seekPreviewIndex` state, updated on every `onChange` tick during a drag and committed to `audio.seekTo(...)` only on release (`onMouseUp`/`onTouchEnd`/`onKeyUp` — this was the fix for drag-spam from the final Nghe chép review, unaffected by this change). To let the slider also auto-advance while playing without fighting the user's own drag:

- A new `isDraggingRef` (ref, not state — no re-render needed) is set to `true` in new `onMouseDown`/`onTouchStart` handlers on the slider, and back to `false` at the end of the existing `onMouseUp`/`onTouchEnd`/`onKeyUp` handlers (after the `seekTo` call is fired).
- A new `useEffect` keyed on `[audio.estimatedWordIndex]` sets `seekPreviewIndex` to `audio.estimatedWordIndex` whenever `!isDraggingRef.current`. While the user is dragging, this effect still fires (the audio may still be playing) but is a no-op due to the guard, so the user's drag position is never overwritten mid-gesture.

### 3. Continuous speed slider

`page.tsx`'s `SPEEDS = [0.75, 1, 1.25] as const` button row is replaced with a single `<input type="range" min={0.5} max={2} step={0.05} value={audio.speed}>`. Unlike the seek slider, `onChange` calls `audio.setSpeed(Number(e.target.value))` directly and immediately on every tick — `setSpeed` is pure client-side (`audioRef.current.playbackRate = next`), there is no network call to debounce, so applying it live on every drag tick gives the user real-time audible feedback, matching the existing `setSpeed` implementation in `useDictationAudio.ts` (no change needed there). The current value is displayed as a text label (e.g. `"1.25x"`) next to the slider. `useDictationAudio`'s `speed` state and `setSpeed` method are otherwise unchanged.

## Error Handling

- Prefetch failure: silent, `prefetchPromiseRef` cleared, `play()` retries fresh — no new user-visible error path beyond what exists today.
- `estimatedWordIndex` computation: guarded against non-finite `duration`, never produces `NaN` state or an out-of-range slider value (clamped to `[0, totalWords - 1]`).
- Speed slider: bounds enforced natively by the `<input>`'s `min`/`max`, no extra validation needed.
- No change to `play()`/`seekTo()`'s existing error surfaces (`audio.error`, rendered via `role="alert"` in the session view) — this work only changes *when* synthesis is triggered and *what visual feedback* accompanies playback, not failure semantics.

## Testing

- `useDictationAudio.test.ts`: new tests for (a) prefetch firing automatically once `sentence` is set, without any `play()` call; (b) `play()` reusing the in-flight prefetch promise — assert `synthesizeSpeech` is called exactly once even when `play()` is invoked before the prefetch resolves; (c) a rejected prefetch not surfacing `error` state and `play()` still succeeding via a fresh retry call; (d) `estimatedWordIndex` recomputing correctly from simulated `timeupdate` events with controlled `currentTime`/`duration` values, including the non-finite-`duration` fallback; (e) `baseWordIndexRef`-equivalent behavior — after a `seekTo(wordIndex)`, a subsequent `timeupdate` computes `estimatedWordIndex` starting from `wordIndex`, not `0`.
- `dictation/page.tsx`'s test file: new tests for (a) the seek slider's displayed value tracking `audio.estimatedWordIndex` while not dragging; (b) the displayed value NOT being overwritten by an `estimatedWordIndex` change while `isDraggingRef` is true (simulate `mousedown` → change `estimatedWordIndex` via a rerender → assert the slider still shows the dragged value → `mouseup` commits); (c) the speed slider calling `audio.setSpeed` on every `onChange` tick (not gated to release, unlike the seek slider).
- No changes needed to `dictation.ts` or its tests — scoring is untouched.
