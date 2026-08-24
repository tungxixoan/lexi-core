# Nghe chép — Audio Playback Improvements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Nghe chép's audio playback feel faster and more responsive: prefetch the sentence's audio as soon as it's generated (not on first Play click), show a moving playhead on the seek slider that tracks real playback progress, and replace the 3 fixed speed buttons with a continuous slider.

**Architecture:** All changes are client-side, inside `apps/web/src/lib/useDictationAudio.ts` (the playback hook) and its one consumer, `apps/web/src/app/(app)/listening/dictation/page.tsx`. No backend/Cloud Function changes. No scoring changes.

**Tech Stack:** React 19 hooks (`useState`/`useRef`/`useEffect`/`useCallback`), native `HTMLAudioElement`, Vitest + Testing Library (`@testing-library/react`'s `renderHook`/`render`, `fireEvent`, `waitFor`).

## Global Constraints

- Vietnamese-first UI: all new user-facing text (aria-labels, display text) must be Vietnamese.
- No backend/Cloud Function changes — this work is 100% client-side (see design spec's Architecture section for why: Cloud Functions are deliberately thin, independent AI-proxy endpoints per root `CLAUDE.md`).
- No changes to `apps/web/src/lib/dictation.ts` (scoring: `computeDictationScore`, `seekPenaltyFraction`, `sm2QualityFromScore`) — this work is playback UX only.
- Prefetch must never set `hasPlayedOnce` — that flag is the sole gate for "Nộp bài" and feeds `computeDictationScore`'s replay/seek accounting; it must only flip on genuine user action (`play()`/`seekTo()` being called).
- `estimatedWordIndex` is a visual estimate only, never fed into scoring — a real `seekTo()` always lands exactly on the requested word regardless of estimation drift.
- Every step that changes `useDictationAudio.ts` or `dictation/page.tsx` must also fix any pre-existing tests whose assertions assumed the old (non-prefetching / static-playhead / 3-button) behavior — see each task's "Fix existing tests" step. Do not leave a task with newly-failing pre-existing tests; they must be updated in the same task, not deferred.
- `Windows/jsdom quirk`: occasional "Failed to start forks worker" resource-contention timeouts under full-suite load are unrelated to any single diff — re-run the isolated file to confirm before concluding a regression. `HTMLMediaElement.prototype.play()` is not implemented in jsdom (prints a console warning but doesn't throw synchronously) — the hook's existing `playResult && typeof playResult.catch === "function"` guard already handles this; do not remove it.

---

## Task 1: Prefetch audio as soon as the sentence is ready

**Files:**
- Modify: `apps/web/src/lib/useDictationAudio.ts`
- Modify: `apps/web/src/lib/useDictationAudio.test.ts`

**Interfaces:**
- Consumes: `synthesizeSpeech(request: {text, language}): Promise<{audioBase64: string}>` from `./synthesizeSpeechClient` (unchanged signature).
- Produces: `useDictationAudio(sentence, sessionKey)`'s public API (`UseDictationAudioResult`) is unchanged by this task — `play()`'s external behavior (what it returns, what state it sets) is unchanged; only *when* the network call happens changes. Task 2 will add a new field (`estimatedWordIndex`) to this same interface — do not add it in this task.

### Context

Today, `play()` only calls `synthesizeSpeech` the first time it's invoked (gated on `hasPlayedOnce && fullClipUrlRef.current` to decide "replay from cache" vs "fetch"). This task adds a background prefetch that starts fetching audio as soon as `sentence` is set (i.e. as soon as the AI-generated or reused item is ready), so that by the time the user clicks Play, the audio is often already cached — Play becomes instant instead of waiting for a Cloud Function round-trip.

The critical subtlety: the existing "use cached clip" branch checks `hasPlayedOnce && fullClipUrlRef.current`. On the user's *first* Play click, `hasPlayedOnce` is still `false` — so even if prefetch already finished and populated `fullClipUrlRef`, today's branch condition would ignore it and fetch again. The branch condition must change to check `fullClipUrlRef.current` alone.

- [ ] **Step 1: Read the current file to confirm line numbers haven't drifted**

Read `apps/web/src/lib/useDictationAudio.ts` in full before editing — the code blocks below assume the file as of commit `a871d3e` (documented in this plan's writing session). If it differs, locate the equivalent code by content, not by line number.

- [ ] **Step 2: Write the new/updated tests first (TDD)**

Open `apps/web/src/lib/useDictationAudio.test.ts`. Two existing tests need fixing (their assertions assumed `play()` is the *only* thing that ever calls `synthesizeSpeech`, which is no longer true once prefetch exists), and three new tests need adding.

**Fix 1 — remove the `mockClear()` calls in the two rerender/reset tests.** These tests clear the mock's call history right before their final `play()` call and then assert `toHaveBeenCalledWith(...)`. With prefetch, the relevant `synthesizeSpeech` call now happens automatically on `rerender` (before the `mockClear()` line), so clearing right before the final `play()` wipes the very call the assertion is checking for, and `play()` itself makes no *new* call (by design — it correctly reuses the prefetch). Removing the `mockClear()` line lets the assertion see the prefetch's own call in the mock's history, which is what the test should be checking:

Find this in the test `"resets playback state and drops the cached clip when the sentence argument changes on the same hook instance"`:

```ts
    rerender({ sentence: NEW_SENTENCE, sessionKey: 2 });

    expect(result.current.hasPlayedOnce).toBe(false);
    expect(result.current.replayCount).toBe(0);
    expect(result.current.seekCount).toBe(0);
    expect(result.current.seekPenaltyTotal).toBe(0);

    vi.mocked(synthesizeSpeech).mockClear();
    await act(async () => {
      await result.current.play();
    });

    expect(synthesizeSpeech).toHaveBeenCalledWith({ text: NEW_SENTENCE, language: "en" });
    expect(result.current.hasPlayedOnce).toBe(true);
    expect(result.current.replayCount).toBe(0);
  });
```

Replace with (only the `mockClear()` line removed):

```ts
    rerender({ sentence: NEW_SENTENCE, sessionKey: 2 });

    expect(result.current.hasPlayedOnce).toBe(false);
    expect(result.current.replayCount).toBe(0);
    expect(result.current.seekCount).toBe(0);
    expect(result.current.seekPenaltyTotal).toBe(0);

    await act(async () => {
      await result.current.play();
    });

    expect(synthesizeSpeech).toHaveBeenCalledWith({ text: NEW_SENTENCE, language: "en" });
    expect(result.current.hasPlayedOnce).toBe(true);
    expect(result.current.replayCount).toBe(0);
  });
```

Find this in the test `"resets playback state and drops the cached clip when sessionKey changes even though the sentence text is identical (same reused saved exercise)"`:

```ts
    rerender({ sentence: SENTENCE, sessionKey: 2 });

    expect(result.current.hasPlayedOnce).toBe(false);
    expect(result.current.replayCount).toBe(0);
    expect(result.current.seekCount).toBe(0);
    expect(result.current.seekPenaltyTotal).toBe(0);

    vi.mocked(synthesizeSpeech).mockClear();
    await act(async () => {
      await result.current.play();
    });

    // The cached clip from the previous session must not have leaked either —
    // play() should have re-fetched rather than reusing fullClipUrlRef.
    expect(synthesizeSpeech).toHaveBeenCalledWith({ text: SENTENCE, language: "en" });
    expect(result.current.hasPlayedOnce).toBe(true);
    expect(result.current.replayCount).toBe(0);
  });
```

Replace with (only the `mockClear()` line removed):

```ts
    rerender({ sentence: SENTENCE, sessionKey: 2 });

    expect(result.current.hasPlayedOnce).toBe(false);
    expect(result.current.replayCount).toBe(0);
    expect(result.current.seekCount).toBe(0);
    expect(result.current.seekPenaltyTotal).toBe(0);

    await act(async () => {
      await result.current.play();
    });

    // The cached clip from the previous session must not have leaked either —
    // play() should have re-fetched (via a fresh prefetch, or on-demand)
    // rather than reusing fullClipUrlRef from the old session.
    expect(synthesizeSpeech).toHaveBeenCalledWith({ text: SENTENCE, language: "en" });
    expect(result.current.hasPlayedOnce).toBe(true);
    expect(result.current.replayCount).toBe(0);
  });
```

**Add 3 new tests.** Insert them at the end of the `describe("useDictationAudio", ...)` block, right before the final closing `});` (after the `"isLoading is true while a synthesizeSpeech call is in flight"` test):

```ts
  it("prefetches audio automatically once sentence is set, without any play() call", async () => {
    renderHook(() => useDictationAudio(SENTENCE, 1));

    await waitFor(() => expect(synthesizeSpeech).toHaveBeenCalledWith({ text: SENTENCE, language: "en" }));
  });

  it("play() reuses the in-flight prefetch instead of firing a duplicate request", async () => {
    let resolvePrefetch!: (value: { audioBase64: string }) => void;
    vi.mocked(synthesizeSpeech).mockReturnValue(
      new Promise((resolve) => {
        resolvePrefetch = resolve;
      })
    );
    const { result } = renderHook(() => useDictationAudio(SENTENCE, 1));

    let playPromise!: Promise<void>;
    act(() => {
      playPromise = result.current.play();
    });
    expect(synthesizeSpeech).toHaveBeenCalledTimes(1);

    await act(async () => {
      resolvePrefetch({ audioBase64: "AAAA" });
      await playPromise;
    });

    expect(synthesizeSpeech).toHaveBeenCalledTimes(1);
    expect(result.current.hasPlayedOnce).toBe(true);
  });

  it("a rejected prefetch does not surface an error, and play() retries with a fresh request", async () => {
    vi.mocked(synthesizeSpeech).mockRejectedValueOnce(new Error("prefetch network error"));
    const { result } = renderHook(() => useDictationAudio(SENTENCE, 1));

    await waitFor(() => expect(synthesizeSpeech).toHaveBeenCalledTimes(1));
    expect(result.current.error).toBeNull();

    vi.mocked(synthesizeSpeech).mockResolvedValue({ audioBase64: "AAAA" });
    await act(async () => {
      await result.current.play();
    });

    expect(synthesizeSpeech).toHaveBeenCalledTimes(2);
    expect(result.current.hasPlayedOnce).toBe(true);
    expect(result.current.error).toBeNull();
  });
```

- [ ] **Step 3: Run the tests to confirm the new ones fail and the fixed ones still pass their old assertions for the right reason**

Run: `cd apps/web && npx vitest run --run src/lib/useDictationAudio.test.ts`
Expected: the 3 new tests FAIL (prefetch doesn't exist yet — `synthesizeSpeech` is never called without an explicit `play()`/`seekTo()`), all other tests still PASS (the `mockClear()` removal doesn't break anything since no prefetch exists yet to add extra calls).

- [ ] **Step 4: Implement the prefetch effect and restructure `play()`**

In `apps/web/src/lib/useDictationAudio.ts`, add a new ref right after `fullClipUrlRef`:

```ts
  const fullClipUrlRef = useRef<string | null>(null);
  const prefetchPromiseRef = useRef<Promise<void> | null>(null);
```

In the existing reset `useEffect` (the one keyed on `[sentence, sessionKey]`), add one line to also clear `prefetchPromiseRef` alongside `fullClipUrlRef`:

```ts
    setHasPlayedOnce(false);
    setReplayCount(0);
    setSeekCount(0);
    setSeekPenaltyTotal(0);
    setError(null);
    fullClipUrlRef.current = null;
    prefetchPromiseRef.current = null;
    if (audioRef.current) {
      audioRef.current.pause();
    }
  }, [sentence, sessionKey]);
```

Immediately after that reset effect (before `function playUrl(url: string) {`), add the new prefetch effect:

```ts
  // Fetch audio in the background as soon as the sentence is ready, so Play
  // is instant once the user clicks it instead of waiting for a fresh
  // Cloud Function round-trip. Stores a promise (not just the eventual URL)
  // so play() can await the exact in-flight request and never fire a
  // duplicate — see play()'s branching below. Never touches hasPlayedOnce:
  // that flag must only flip on genuine user action.
  useEffect(() => {
    if (!sentence) return;
    const promise = synthesizeSpeech({ text: sentence, language: "en" })
      .then(({ audioBase64 }) => {
        fullClipUrlRef.current = toAudioDataUrl(audioBase64);
      })
      .catch(() => {
        // Swallowed: the user hasn't asked for anything yet. play() will
        // retry with a fresh on-demand request since fullClipUrlRef and
        // prefetchPromiseRef both stay/become null on failure.
        prefetchPromiseRef.current = null;
      });
    prefetchPromiseRef.current = promise;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [sentence, sessionKey]);
```

Now replace `play()`'s body entirely. Find:

```ts
  const play = useCallback(async () => {
    setError(null);
    if (hasPlayedOnce && fullClipUrlRef.current) {
      setReplayCount((c) => c + 1);
      playUrl(fullClipUrlRef.current);
      return;
    }
    setIsLoading(true);
    try {
      const { audioBase64 } = await synthesizeSpeech({ text: sentence, language: "en" });
      const url = toAudioDataUrl(audioBase64);
      fullClipUrlRef.current = url;
      setHasPlayedOnce(true);
      playUrl(url);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setIsLoading(false);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [sentence, hasPlayedOnce]);
```

Replace with:

```ts
  const play = useCallback(async () => {
    setError(null);
    if (fullClipUrlRef.current) {
      // Already have a clip — either prefetch finished, or this is a
      // replay. Whether this is "the first real listen" or "a replay"
      // still depends on hasPlayedOnce's current value; only the "do we
      // already have something to play" check changed (used to also
      // require hasPlayedOnce, which is wrong for a prefetched clip on the
      // user's very first click).
      if (hasPlayedOnce) {
        setReplayCount((c) => c + 1);
      } else {
        setHasPlayedOnce(true);
      }
      playUrl(fullClipUrlRef.current);
      return;
    }
    setIsLoading(true);
    try {
      if (prefetchPromiseRef.current) {
        await prefetchPromiseRef.current;
      }
      if (fullClipUrlRef.current) {
        // The prefetch we just awaited succeeded.
        setHasPlayedOnce(true);
        playUrl(fullClipUrlRef.current);
        return;
      }
      // No prefetch was ever started, or it failed — fetch fresh.
      const { audioBase64 } = await synthesizeSpeech({ text: sentence, language: "en" });
      const url = toAudioDataUrl(audioBase64);
      fullClipUrlRef.current = url;
      setHasPlayedOnce(true);
      playUrl(url);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setIsLoading(false);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [sentence, hasPlayedOnce]);
```

- [ ] **Step 5: Run the tests to confirm everything passes**

Run: `cd apps/web && npx vitest run --run src/lib/useDictationAudio.test.ts`
Expected: all tests PASS (the 3 new ones, the 2 fixed ones, and every pre-existing one).

- [ ] **Step 6: Typecheck**

Run: `cd apps/web && npx tsc --noEmit`
Expected: no output (clean).

- [ ] **Step 7: Commit**

```bash
git add apps/web/src/lib/useDictationAudio.ts apps/web/src/lib/useDictationAudio.test.ts
git commit -m "feat(web): prefetch dictation audio as soon as the sentence is ready"
```

---

## Task 2: Live-tracking estimated seek playhead

**Files:**
- Modify: `apps/web/src/lib/useDictationAudio.ts`
- Modify: `apps/web/src/lib/useDictationAudio.test.ts`

**Interfaces:**
- Consumes: `targetWords(sentence): string[]` from `./dictation` (already imported in this file).
- Produces: `UseDictationAudioResult` gains a new field: `estimatedWordIndex: number` — an integer in `[0, targetWords(sentence).length - 1]` (or `0` if there are no words), updated as the currently-playing clip progresses. Task 3 (page-side wiring) consumes this field directly as `audio.estimatedWordIndex`.

### Context

Piper (the TTS backend) exposes no per-word timing metadata, so there's no way to know exactly which word is being spoken at a given moment. This task adds a *time-proportional estimate* instead: track how far through the currently-playing clip we are (`audio.currentTime / audio.duration`), and map that onto a word position, starting from whichever word index the current clip began at (`baseWordIndexRef`). This is presented to the user only as a moving slider position — it is never fed into scoring, and a real `seekTo()` always lands exactly on the requested word regardless of any estimation drift.

The `<audio>` element is created lazily (only once, inside `playUrl()`, the first time anything plays) and reused across the whole page visit. The `timeupdate` event listener must therefore also be attached only once, at that same creation point — but it must always read the *current* sentence, not the one from whatever render happened to be active when the listener was attached (otherwise, after a "Câu khác" starts a new sentence with a different word count, the listener would keep computing against the old word count). This is done via a small ref (`sentenceRef`) kept in sync with the `sentence` argument via its own tiny effect.

- [ ] **Step 1: Confirm current file state**

Read `apps/web/src/lib/useDictationAudio.ts` — Task 1 must already be committed (this task builds directly on `play()`'s new branching).

- [ ] **Step 2: Set up Audio-instance capture in the test file, then write the new tests (TDD)**

`useDictationAudio` creates its `<audio>` element via the bare global `new Audio()`. To simulate real playback progress in jsdom (which doesn't decode real audio, so `currentTime`/`duration` never change on their own), the test needs a handle to that exact element to manually set `currentTime`/`duration` and dispatch a `timeupdate` event on it. Do this by spying on the global `Audio` constructor and capturing every instance it creates, while still delegating to the real jsdom-provided `Audio` class so the element behaves like a normal DOM node (supports `addEventListener`/`dispatchEvent`).

At the top of `apps/web/src/lib/useDictationAudio.test.ts`, after the existing `vi.mock(...)` block and before the `SENTENCE` constant, add:

```ts
const RealAudio = window.Audio;
let audioInstances: HTMLAudioElement[];
```

In the existing `beforeEach`, add the spy setup (keep the two existing lines):

```ts
beforeEach(() => {
  vi.clearAllMocks();
  vi.mocked(synthesizeSpeech).mockResolvedValue({ audioBase64: "AAAA" });
  audioInstances = [];
  vi.spyOn(window, "Audio").mockImplementation(function () {
    const el = new RealAudio();
    audioInstances.push(el);
    return el as unknown as HTMLAudioElement;
  } as unknown as typeof Audio);
});
```

Add an `afterEach` right after the `beforeEach` block to restore the real constructor between tests:

```ts
afterEach(() => {
  vi.restoreAllMocks();
});
```

This requires `afterEach` in the import line at the top of the file — update it:

```ts
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
```

Now add the 3 new tests, at the end of the `describe("useDictationAudio", ...)` block (after the tests added in Task 1):

```ts
  it("estimatedWordIndex starts at 0 and tracks currentTime/duration proportionally while playing", async () => {
    const { result } = renderHook(() => useDictationAudio(SENTENCE, 1)); // 9 words
    expect(result.current.estimatedWordIndex).toBe(0);

    await act(async () => {
      await result.current.play();
    });
    expect(result.current.estimatedWordIndex).toBe(0);

    const audioEl = audioInstances[0];
    Object.defineProperty(audioEl, "duration", { value: 9, configurable: true });
    act(() => {
      Object.defineProperty(audioEl, "currentTime", { value: 4, configurable: true });
      audioEl.dispatchEvent(new Event("timeupdate"));
    });

    // base=0, totalWords=9, ratio=4/9 -> 0 + (4/9)*9 = 4
    expect(result.current.estimatedWordIndex).toBe(4);
  });

  it("estimatedWordIndex falls back to the current base when duration is not finite", async () => {
    const { result } = renderHook(() => useDictationAudio(SENTENCE, 1));
    await act(async () => {
      await result.current.play();
    });

    const audioEl = audioInstances[0];
    Object.defineProperty(audioEl, "duration", { value: NaN, configurable: true });
    act(() => {
      Object.defineProperty(audioEl, "currentTime", { value: 3, configurable: true });
      audioEl.dispatchEvent(new Event("timeupdate"));
    });

    expect(result.current.estimatedWordIndex).toBe(0);
  });

  it("estimatedWordIndex resets to the seek target immediately, then continues from there as the new clip plays", async () => {
    const { result } = renderHook(() => useDictationAudio(SENTENCE, 1)); // 9 words
    await act(async () => {
      await result.current.play();
    });

    await act(async () => {
      await result.current.seekTo(3); // remainder is 6 words: "fox jumps over the lazy dog"
    });
    expect(result.current.estimatedWordIndex).toBe(3);

    const audioEl = audioInstances[audioInstances.length - 1];
    Object.defineProperty(audioEl, "duration", { value: 6, configurable: true });
    act(() => {
      Object.defineProperty(audioEl, "currentTime", { value: 3, configurable: true });
      audioEl.dispatchEvent(new Event("timeupdate"));
    });

    // base=3, remaining words=9-3=6, ratio=3/6=0.5 -> 3 + 0.5*6 = 6
    expect(result.current.estimatedWordIndex).toBe(6);
  });
```

- [ ] **Step 3: Run the tests to confirm they fail**

Run: `cd apps/web && npx vitest run --run src/lib/useDictationAudio.test.ts`
Expected: the 3 new tests FAIL (`estimatedWordIndex` doesn't exist on the result yet — TypeScript will also flag this at the `tsc` step later, but Vitest will fail first at `result.current.estimatedWordIndex` being `undefined`).

- [ ] **Step 4: Implement `estimatedWordIndex`**

In `apps/web/src/lib/useDictationAudio.ts`, add the new state and refs. Find:

```ts
  const [speed, setSpeedState] = useState(1);
  const [error, setError] = useState<string | null>(null);

  const audioRef = useRef<HTMLAudioElement | null>(null);
  const fullClipUrlRef = useRef<string | null>(null);
  const prefetchPromiseRef = useRef<Promise<void> | null>(null);
  const previousSentenceRef = useRef(sentence);
  const previousSessionKeyRef = useRef(sessionKey);
```

Replace with:

```ts
  const [speed, setSpeedState] = useState(1);
  const [error, setError] = useState<string | null>(null);
  const [estimatedWordIndex, setEstimatedWordIndex] = useState(0);

  const audioRef = useRef<HTMLAudioElement | null>(null);
  const fullClipUrlRef = useRef<string | null>(null);
  const prefetchPromiseRef = useRef<Promise<void> | null>(null);
  const previousSentenceRef = useRef(sentence);
  const previousSessionKeyRef = useRef(sessionKey);
  const sentenceRef = useRef(sentence);
  const baseWordIndexRef = useRef(0);

  // The timeupdate listener (attached once, when the <audio> element is
  // first created — see playUrl) must always read the *current* sentence,
  // not whichever one was active when it was attached, since the element
  // is reused across sessions with different sentences/word counts.
  useEffect(() => {
    sentenceRef.current = sentence;
  }, [sentence]);
```

In the existing reset `useEffect`, add resets for the two new pieces of state. Find:

```ts
    setHasPlayedOnce(false);
    setReplayCount(0);
    setSeekCount(0);
    setSeekPenaltyTotal(0);
    setError(null);
    fullClipUrlRef.current = null;
    prefetchPromiseRef.current = null;
    if (audioRef.current) {
      audioRef.current.pause();
    }
  }, [sentence, sessionKey]);
```

Replace with:

```ts
    setHasPlayedOnce(false);
    setReplayCount(0);
    setSeekCount(0);
    setSeekPenaltyTotal(0);
    setError(null);
    setEstimatedWordIndex(0);
    fullClipUrlRef.current = null;
    prefetchPromiseRef.current = null;
    baseWordIndexRef.current = 0;
    if (audioRef.current) {
      audioRef.current.pause();
    }
  }, [sentence, sessionKey]);
```

Now update `playUrl` to attach the `timeupdate` listener on first creation. Find:

```ts
  function playUrl(url: string) {
    if (!audioRef.current) {
      audioRef.current = new Audio();
    }
    const audioEl = audioRef.current;
```

Replace with:

```ts
  function playUrl(url: string) {
    if (!audioRef.current) {
      audioRef.current = new Audio();
      audioRef.current.addEventListener("timeupdate", () => {
        const el = audioRef.current;
        if (!el || !Number.isFinite(el.duration) || el.duration <= 0) return;
        const totalWords = targetWords(sentenceRef.current).length;
        if (totalWords === 0) return;
        const base = baseWordIndexRef.current;
        const raw = base + (el.currentTime / el.duration) * (totalWords - base);
        const clamped = Math.min(Math.max(Math.round(raw), 0), totalWords - 1);
        setEstimatedWordIndex(clamped);
      });
    }
    const audioEl = audioRef.current;
```

Now update `play()` to set `baseWordIndexRef.current` (and the matching `estimatedWordIndex`) to `0` whenever it starts the full clip from the beginning — in both branches. Find:

```ts
  const play = useCallback(async () => {
    setError(null);
    if (fullClipUrlRef.current) {
      // Already have a clip — either prefetch finished, or this is a
      // replay. Whether this is "the first real listen" or "a replay"
      // still depends on hasPlayedOnce's current value; only the "do we
      // already have something to play" check changed (used to also
      // require hasPlayedOnce, which is wrong for a prefetched clip on the
      // user's very first click).
      if (hasPlayedOnce) {
        setReplayCount((c) => c + 1);
      } else {
        setHasPlayedOnce(true);
      }
      playUrl(fullClipUrlRef.current);
      return;
    }
    setIsLoading(true);
    try {
      if (prefetchPromiseRef.current) {
        await prefetchPromiseRef.current;
      }
      if (fullClipUrlRef.current) {
        // The prefetch we just awaited succeeded.
        setHasPlayedOnce(true);
        playUrl(fullClipUrlRef.current);
        return;
      }
      // No prefetch was ever started, or it failed — fetch fresh.
      const { audioBase64 } = await synthesizeSpeech({ text: sentence, language: "en" });
      const url = toAudioDataUrl(audioBase64);
      fullClipUrlRef.current = url;
      setHasPlayedOnce(true);
      playUrl(url);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setIsLoading(false);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [sentence, hasPlayedOnce]);
```

Replace with (three `baseWordIndexRef`/`setEstimatedWordIndex` lines added, one per branch that starts the full clip):

```ts
  const play = useCallback(async () => {
    setError(null);
    if (fullClipUrlRef.current) {
      // Already have a clip — either prefetch finished, or this is a
      // replay. Whether this is "the first real listen" or "a replay"
      // still depends on hasPlayedOnce's current value; only the "do we
      // already have something to play" check changed (used to also
      // require hasPlayedOnce, which is wrong for a prefetched clip on the
      // user's very first click).
      if (hasPlayedOnce) {
        setReplayCount((c) => c + 1);
      } else {
        setHasPlayedOnce(true);
      }
      baseWordIndexRef.current = 0;
      setEstimatedWordIndex(0);
      playUrl(fullClipUrlRef.current);
      return;
    }
    setIsLoading(true);
    try {
      if (prefetchPromiseRef.current) {
        await prefetchPromiseRef.current;
      }
      if (fullClipUrlRef.current) {
        // The prefetch we just awaited succeeded.
        setHasPlayedOnce(true);
        baseWordIndexRef.current = 0;
        setEstimatedWordIndex(0);
        playUrl(fullClipUrlRef.current);
        return;
      }
      // No prefetch was ever started, or it failed — fetch fresh.
      const { audioBase64 } = await synthesizeSpeech({ text: sentence, language: "en" });
      const url = toAudioDataUrl(audioBase64);
      fullClipUrlRef.current = url;
      setHasPlayedOnce(true);
      baseWordIndexRef.current = 0;
      setEstimatedWordIndex(0);
      playUrl(url);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setIsLoading(false);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [sentence, hasPlayedOnce]);
```

Now update `seekTo()` to set `baseWordIndexRef.current`/`estimatedWordIndex` to the seek target on success. Find:

```ts
        if (hasPlayedOnce) {
          setSeekPenaltyTotal((total) => total + seekPenaltyFraction(wordIndex, words.length));
        } else {
          setHasPlayedOnce(true);
        }
        setSeekCount((c) => c + 1);
        playUrl(url);
```

Replace with:

```ts
        if (hasPlayedOnce) {
          setSeekPenaltyTotal((total) => total + seekPenaltyFraction(wordIndex, words.length));
        } else {
          setHasPlayedOnce(true);
        }
        setSeekCount((c) => c + 1);
        baseWordIndexRef.current = wordIndex;
        setEstimatedWordIndex(wordIndex);
        playUrl(url);
```

Finally, add `estimatedWordIndex` to the returned object and the `UseDictationAudioResult` interface. Find:

```ts
export interface UseDictationAudioResult {
  isLoading: boolean;
  hasPlayedOnce: boolean;
  replayCount: number;
  seekCount: number;
  seekPenaltyTotal: number;
  speed: number;
  error: string | null;
  play: () => Promise<void>;
  setSpeed: (speed: number) => void;
  seekTo: (wordIndex: number) => Promise<void>;
}
```

Replace with:

```ts
export interface UseDictationAudioResult {
  isLoading: boolean;
  hasPlayedOnce: boolean;
  replayCount: number;
  seekCount: number;
  seekPenaltyTotal: number;
  speed: number;
  estimatedWordIndex: number;
  error: string | null;
  play: () => Promise<void>;
  setSpeed: (speed: number) => void;
  seekTo: (wordIndex: number) => Promise<void>;
}
```

And find the return statement:

```ts
  return {
    isLoading,
    hasPlayedOnce,
    replayCount,
    seekCount,
    seekPenaltyTotal,
    speed,
    error,
    play,
    setSpeed,
    seekTo,
  };
```

Replace with:

```ts
  return {
    isLoading,
    hasPlayedOnce,
    replayCount,
    seekCount,
    seekPenaltyTotal,
    speed,
    estimatedWordIndex,
    error,
    play,
    setSpeed,
    seekTo,
  };
```

- [ ] **Step 5: Run the tests to confirm everything passes**

Run: `cd apps/web && npx vitest run --run src/lib/useDictationAudio.test.ts`
Expected: all tests PASS.

- [ ] **Step 6: Typecheck**

Run: `cd apps/web && npx tsc --noEmit`
Expected: no output. (This will also catch it if `dictation/page.tsx`, unmodified so far, somehow already destructured `estimatedWordIndex` — it shouldn't yet, that's Task 3.)

- [ ] **Step 7: Commit**

```bash
git add apps/web/src/lib/useDictationAudio.ts apps/web/src/lib/useDictationAudio.test.ts
git commit -m "feat(web): add a time-proportional estimated playhead to useDictationAudio"
```

---

## Task 3: Wire the live playhead into the seek slider

**Files:**
- Modify: `apps/web/src/app/(app)/listening/dictation/page.tsx`
- Modify: `apps/web/src/app/(app)/listening/dictation/page.test.tsx`

**Interfaces:**
- Consumes: `audio.estimatedWordIndex: number` (from Task 2's `UseDictationAudioResult`).
- Produces: no new exports — this task only changes the seek `<input type="range">`'s wiring inside `DictationPageContent`.

### Context

The seek slider already displays a local `seekPreviewIndex` state, updated on every drag tick (`onChange`) and committed to `audio.seekTo(...)` only on release (`onMouseUp`/`onTouchEnd`/`onKeyUp`) — this was the fix for drag-spam from the final Nghe chép review and is unaffected by this task. This task makes `seekPreviewIndex` also auto-advance to follow `audio.estimatedWordIndex` while the user is *not* actively dragging, without fighting an active drag gesture.

Three pre-existing tests in `page.test.tsx` assert `synthesizeSpeech` call counts/absences around session start — with Task 1's prefetch now shipped, those assertions need adjusting (this was true the moment Task 1 landed, independent of this task, but is grouped here since it's in the same test file this task also touches).

- [ ] **Step 1: Confirm current file state**

Read `apps/web/src/app/(app)/listening/dictation/page.tsx` and `apps/web/src/app/(app)/listening/dictation/page.test.tsx` — Tasks 1 and 2 must already be committed.

- [ ] **Step 2: Fix the 3 pre-existing tests broken by Task 1's prefetch**

In `apps/web/src/app/(app)/listening/dictation/page.test.tsx`, find the test `"does not call seekTo/synthesizeSpeech while dragging the seek slider — only on release, with the last-dragged value"`:

```ts
  it("does not call seekTo/synthesizeSpeech while dragging the seek slider — only on release, with the last-dragged value", async () => {
    mockSignedIn();
    await generateSession();

    const slider = screen.getByLabelText("Tua theo từ");
    // Simulate a drag across several intermediate positions.
    fireEvent.change(slider, { target: { value: "1" } });
    fireEvent.change(slider, { target: { value: "2" } });
    fireEvent.change(slider, { target: { value: "4" } });
    expect(synthesizeSpeech).not.toHaveBeenCalled();

    fireEvent.mouseUp(slider);

    // words = ["I", "ate", "an", "apple", "today."] — index 4 -> remainder "today."
    await waitFor(() => expect(synthesizeSpeech).toHaveBeenCalledTimes(1));
    expect(synthesizeSpeech).toHaveBeenCalledWith({ text: "today.", language: "en" });
  });
```

Replace with (adds a `mockClear()` right after `generateSession()`, so the assertions below count only calls made *during the drag*, not the automatic prefetch call that already fired once the sentence was generated):

```ts
  it("does not call seekTo/synthesizeSpeech while dragging the seek slider — only on release, with the last-dragged value", async () => {
    mockSignedIn();
    await generateSession();
    vi.mocked(synthesizeSpeech).mockClear(); // drop the automatic prefetch call from generation

    const slider = screen.getByLabelText("Tua theo từ");
    // Simulate a drag across several intermediate positions.
    fireEvent.change(slider, { target: { value: "1" } });
    fireEvent.change(slider, { target: { value: "2" } });
    fireEvent.change(slider, { target: { value: "4" } });
    expect(synthesizeSpeech).not.toHaveBeenCalled();

    fireEvent.mouseUp(slider);

    // words = ["I", "ate", "an", "apple", "today."] — index 4 -> remainder "today."
    await waitFor(() => expect(synthesizeSpeech).toHaveBeenCalledTimes(1));
    expect(synthesizeSpeech).toHaveBeenCalledWith({ text: "today.", language: "en" });
  });
```

Find the test `"seeks on touch-drag release and on keyboard-arrow release, not on every intermediate onChange"`:

```ts
  it("seeks on touch-drag release and on keyboard-arrow release, not on every intermediate onChange", async () => {
    mockSignedIn();
    await generateSession();

    const slider = screen.getByLabelText("Tua theo từ");
    fireEvent.change(slider, { target: { value: "3" } });
```

Replace with (adds the same `mockClear()` right after `generateSession()`; the rest of the test, including its own later `mockClear()`, is unchanged):

```ts
  it("seeks on touch-drag release and on keyboard-arrow release, not on every intermediate onChange", async () => {
    mockSignedIn();
    await generateSession();
    vi.mocked(synthesizeSpeech).mockClear(); // drop the automatic prefetch call from generation

    const slider = screen.getByLabelText("Tua theo từ");
    fireEvent.change(slider, { target: { value: "3" } });
```

Find the test `"disables the seek slider while audio is loading"`:

```ts
  it("disables the seek slider while audio is loading", async () => {
    mockSignedIn();
    await generateSession();

    let resolveSpeech!: (value: { audioBase64: string }) => void;
    vi.mocked(synthesizeSpeech).mockReturnValue(
      new Promise((resolve) => {
        resolveSpeech = resolve;
      })
    );

    fireEvent.click(screen.getByRole("button", { name: "▶ Phát" }));
    await waitFor(() => expect(screen.getByLabelText("Tua theo từ")).toBeDisabled());

    resolveSpeech({ audioBase64: "AAAA" });
    await waitFor(() => expect(screen.getByLabelText("Tua theo từ")).not.toBeDisabled());
  });
```

Replace with (moves the hanging-promise mock setup to *before* `generateSession()`, so the prefetch itself is what's still pending when Play is clicked — with prefetch, if the clip were already cached by click time, Play would resolve synchronously and never show a loading state at all, which is the point of prefetch, but means this test must simulate "prefetch hasn't finished yet" rather than test through an already-resolved cache):

```ts
  it("disables the seek slider while audio is loading", async () => {
    mockSignedIn();
    let resolveSpeech!: (value: { audioBase64: string }) => void;
    vi.mocked(synthesizeSpeech).mockReturnValue(
      new Promise((resolve) => {
        resolveSpeech = resolve;
      })
    );
    await generateSession();

    fireEvent.click(screen.getByRole("button", { name: "▶ Phát" }));
    await waitFor(() => expect(screen.getByLabelText("Tua theo từ")).toBeDisabled());

    resolveSpeech({ audioBase64: "AAAA" });
    await waitFor(() => expect(screen.getByLabelText("Tua theo từ")).not.toBeDisabled());
  });
```

- [ ] **Step 3: Run the tests to confirm the 3 fixes work and nothing else broke**

Run: `cd apps/web && npx vitest run --run "src/app/(app)/listening/dictation/page.test.tsx"`
Expected: all tests PASS.

- [ ] **Step 4: Write the new tests for live-tracking (TDD)**

The real `useDictationAudio` hook is used in these tests (not mocked) — same as every other test in this file — so simulating playback progress requires the same Audio-instance-capturing technique as Task 2. Add this setup near the top of the file, after the existing `vi.mock("@/lib/synthesizeSpeechClient", ...)` block:

```ts
const RealAudio = window.Audio;
let audioInstances: HTMLAudioElement[];
```

In the file's `beforeEach` (the one already setting up `getVocabRecords`/`synthesizeSpeech`/`getRandomSavedListeningExercise` mocks), add:

```ts
  audioInstances = [];
  vi.spyOn(window, "Audio").mockImplementation(function () {
    const el = new RealAudio();
    audioInstances.push(el);
    return el as unknown as HTMLAudioElement;
  } as unknown as typeof Audio);
```

Add an `afterEach` after that `beforeEach` block (check the top-level `vitest` import includes `afterEach`; add it if missing):

```ts
afterEach(() => {
  vi.restoreAllMocks();
});
```

Add the 2 new tests inside `describe("DictationPage (session phase — Khó / free text)", ...)`, right after the existing `"disables the seek slider while audio is loading"` test (which Step 2 just fixed):

```ts
  it("the seek slider tracks audio.estimatedWordIndex while the user is not dragging", async () => {
    mockSignedIn();
    await generateSession();

    fireEvent.click(screen.getByRole("button", { name: "▶ Phát" }));
    await waitFor(() => expect(screen.getByRole("button", { name: "▶ Nghe lại (0)" })).toBeInTheDocument());

    const audioEl = audioInstances[audioInstances.length - 1];
    const slider = screen.getByLabelText("Tua theo từ") as HTMLInputElement;

    // words = ["I", "ate", "an", "apple", "today."] — 5 words
    Object.defineProperty(audioEl, "duration", { value: 5, configurable: true });
    Object.defineProperty(audioEl, "currentTime", { value: 2, configurable: true });
    fireEvent(audioEl, new Event("timeupdate"));

    await waitFor(() => expect(slider.value).toBe("2"));
  });

  it("does not let the live-tracking playhead overwrite the slider while the user is dragging", async () => {
    mockSignedIn();
    await generateSession();

    fireEvent.click(screen.getByRole("button", { name: "▶ Phát" }));
    await waitFor(() => expect(screen.getByRole("button", { name: "▶ Nghe lại (0)" })).toBeInTheDocument());

    const audioEl = audioInstances[audioInstances.length - 1];
    const slider = screen.getByLabelText("Tua theo từ") as HTMLInputElement;

    fireEvent.mouseDown(slider);
    fireEvent.change(slider, { target: { value: "1" } });
    expect(slider.value).toBe("1");

    // Simulate playback progress arriving mid-drag — must not fight the user.
    Object.defineProperty(audioEl, "duration", { value: 5, configurable: true });
    Object.defineProperty(audioEl, "currentTime", { value: 4, configurable: true });
    fireEvent(audioEl, new Event("timeupdate"));

    expect(slider.value).toBe("1");

    fireEvent.mouseUp(slider);
    await waitFor(() => expect(synthesizeSpeech).toHaveBeenCalledWith({ text: "ate an apple today.", language: "en" }));
  });
```

- [ ] **Step 5: Run the tests to confirm the 2 new ones fail**

Run: `cd apps/web && npx vitest run --run "src/app/(app)/listening/dictation/page.test.tsx"`
Expected: the 2 new tests FAIL (the slider never auto-advances yet — `seekPreviewIndex` is only ever set by the user's own `onChange`).

- [ ] **Step 6: Implement the wiring**

In `apps/web/src/app/(app)/listening/dictation/page.tsx`, add a new ref right after `sessionKeyRef`. Find:

```ts
  const sessionKeyRef = useRef(0);

  const audio = useDictationAudio(item?.target ?? "", sessionKeyRef.current);
```

Replace with:

```ts
  const sessionKeyRef = useRef(0);
  const isDraggingSeekRef = useRef(false);

  const audio = useDictationAudio(item?.target ?? "", sessionKeyRef.current);

  useEffect(() => {
    if (!isDraggingSeekRef.current) {
      setSeekPreviewIndex(audio.estimatedWordIndex);
    }
  }, [audio.estimatedWordIndex]);
```

Now update the seek `<input>`'s handlers. Find:

```tsx
          <input
            type="range"
            min={0}
            max={words.length - 1}
            step={1}
            value={seekPreviewIndex}
            className="dictation-seek-slider"
            aria-label="Tua theo từ"
            disabled={audio.isLoading}
            onChange={(e) => setSeekPreviewIndex(Number(e.target.value))}
            onMouseUp={(e) => void audio.seekTo(Number(e.currentTarget.value))}
            onTouchEnd={(e) => void audio.seekTo(Number(e.currentTarget.value))}
            onKeyUp={(e) => void audio.seekTo(Number(e.currentTarget.value))}
          />
```

Replace with:

```tsx
          <input
            type="range"
            min={0}
            max={words.length - 1}
            step={1}
            value={seekPreviewIndex}
            className="dictation-seek-slider"
            aria-label="Tua theo từ"
            disabled={audio.isLoading}
            onChange={(e) => setSeekPreviewIndex(Number(e.target.value))}
            onMouseDown={() => {
              isDraggingSeekRef.current = true;
            }}
            onTouchStart={() => {
              isDraggingSeekRef.current = true;
            }}
            onMouseUp={(e) => {
              isDraggingSeekRef.current = false;
              void audio.seekTo(Number(e.currentTarget.value));
            }}
            onTouchEnd={(e) => {
              isDraggingSeekRef.current = false;
              void audio.seekTo(Number(e.currentTarget.value));
            }}
            onKeyUp={(e) => {
              isDraggingSeekRef.current = false;
              void audio.seekTo(Number(e.currentTarget.value));
            }}
          />
```

- [ ] **Step 7: Run the tests to confirm everything passes**

Run: `cd apps/web && npx vitest run --run "src/app/(app)/listening/dictation/page.test.tsx"`
Expected: all tests PASS.

- [ ] **Step 8: Typecheck**

Run: `cd apps/web && npx tsc --noEmit`
Expected: no output.

- [ ] **Step 9: Commit**

```bash
git add "apps/web/src/app/(app)/listening/dictation/page.tsx" "apps/web/src/app/(app)/listening/dictation/page.test.tsx"
git commit -m "feat(web): sync the dictation seek slider to the live estimated playhead"
```

---

## Task 4: Continuous speed slider

**Files:**
- Modify: `apps/web/src/app/(app)/listening/dictation/page.tsx`
- Modify: `apps/web/src/app/(app)/listening/dictation/page.test.tsx`
- Modify: `apps/web/src/styles/bloom.css`

**Interfaces:**
- Consumes: `audio.speed: number`, `audio.setSpeed(speed: number): void` (unchanged, from `useDictationAudio` — no hook changes in this task).
- Produces: nothing new consumed by other tasks — this is the last task.

### Context

Replaces the 3 fixed speed buttons (`0.75x`/`1x`/`1.25x`) with a single continuous `<input type="range">` from `0.5` to `2`, step `0.05`. Unlike the seek slider, this applies on every `onChange` tick immediately (no release-only gating) — `setSpeed` is pure client-side (`audioRef.current.playbackRate = next`), there's no network call to debounce, so live feedback while dragging is both cheap and desirable.

- [ ] **Step 1: Confirm current file state**

Read `apps/web/src/app/(app)/listening/dictation/page.tsx` — Task 3 must already be committed.

- [ ] **Step 2: Write the new test (TDD)**

In `apps/web/src/app/(app)/listening/dictation/page.test.tsx`, add this test inside `describe("DictationPage (session phase — Khó / free text)", ...)`, after the 2 tests Task 3 added:

```ts
  it("the speed slider applies every onChange tick immediately, not gated to release", async () => {
    mockSignedIn();
    await generateSession();

    const speedSlider = screen.getByLabelText("Tốc độ phát") as HTMLInputElement;
    expect(speedSlider.value).toBe("1");
    expect(screen.getByText("1.00x")).toBeInTheDocument();

    fireEvent.change(speedSlider, { target: { value: "1.5" } });

    expect(screen.getByText("1.50x")).toBeInTheDocument();
  });
```

- [ ] **Step 3: Run the test to confirm it fails**

Run: `cd apps/web && npx vitest run --run "src/app/(app)/listening/dictation/page.test.tsx"`
Expected: FAIL — no element has the label "Tốc độ phát" yet (the current markup is 3 unlabeled buttons).

- [ ] **Step 4: Replace the speed buttons with a slider**

In `apps/web/src/app/(app)/listening/dictation/page.tsx`, remove the `SPEEDS` constant. Find:

```ts
const MIN_VOCAB_WORDS = 2;
const SPEEDS = [0.75, 1, 1.25] as const;
```

Replace with:

```ts
const MIN_VOCAB_WORDS = 2;
const MIN_SPEED = 0.5;
const MAX_SPEED = 2;
const SPEED_STEP = 0.05;
```

Find the speed button markup:

```tsx
          <div className="dictation-speed-selector">
            {SPEEDS.map((s) => (
              <button
                key={s}
                type="button"
                className={`vb-chip${audio.speed === s ? " active" : ""}`}
                onClick={() => audio.setSpeed(s)}
              >
                {s}x
              </button>
            ))}
          </div>
```

Replace with:

```tsx
          <div className="dictation-speed-selector">
            <input
              type="range"
              min={MIN_SPEED}
              max={MAX_SPEED}
              step={SPEED_STEP}
              value={audio.speed}
              className="dictation-speed-slider"
              aria-label="Tốc độ phát"
              onChange={(e) => audio.setSpeed(Number(e.target.value))}
            />
            <span className="dictation-speed-label">{audio.speed.toFixed(2)}x</span>
          </div>
```

- [ ] **Step 5: Update the CSS**

In `apps/web/src/styles/bloom.css`, find:

```css
.dictation-speed-selector {
  display: flex;
  gap: 8px;
}
```

Replace with:

```css
.dictation-speed-selector {
  display: flex;
  align-items: center;
  gap: 8px;
}

.dictation-speed-slider {
  width: 140px;
}

.dictation-speed-label {
  font-variant-numeric: tabular-nums;
  min-width: 3.5ch;
  color: var(--ink);
}
```

- [ ] **Step 6: Run the tests to confirm everything passes**

Run: `cd apps/web && npx vitest run --run "src/app/(app)/listening/dictation/page.test.tsx"`
Expected: all tests PASS.

- [ ] **Step 7: Typecheck**

Run: `cd apps/web && npx tsc --noEmit`
Expected: no output.

- [ ] **Step 8: Run the full web suite and production build**

Run: `cd apps/web && npm test -- --run`
Expected: all pass except the one known pre-existing unrelated `src/styles/bloom.test.ts` `.app-frame` border-radius failure.

Run: `cd apps/web && npm run build`
Expected: clean build; `/listening/dictation` still statically prerendered.

- [ ] **Step 9: Commit**

```bash
git add "apps/web/src/app/(app)/listening/dictation/page.tsx" "apps/web/src/app/(app)/listening/dictation/page.test.tsx" apps/web/src/styles/bloom.css
git commit -m "feat(web): replace the 3 fixed dictation speed buttons with a continuous slider"
```
