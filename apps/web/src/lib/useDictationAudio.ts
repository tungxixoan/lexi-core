import { useCallback, useEffect, useRef, useState } from "react";
import { synthesizeSpeech, toAudioDataUrl } from "./synthesizeSpeechClient";
import { seekPenaltyFraction, targetWords } from "./dictation";

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

// Web reimplementation of DictationPracticeNotifier's play/seekTo/setSpeed —
// not a literal port (Flutter speaks live on-device every call; this caches
// one fetched clip and only re-fetches for seeks). The state-transition
// rules that feed computeDictationScore are preserved exactly.
//
// `sessionKey` identifies the current session independently of the sentence
// text: a caller reusing the same saved exercise (only one saved item, so
// "Câu khác" re-picks the identical document) has `sentence` stay
// byte-identical across sessions, and keying the reset purely on `sentence`
// would then leak hasPlayedOnce/replayCount/seekCount/seekPenaltyTotal/the
// cached clip from the previous session into the new one. Callers must pass
// a value that changes on every session start (e.g. an incrementing counter)
// even when the sentence text happens to repeat.
export function useDictationAudio(sentence: string, sessionKey: string | number): UseDictationAudioResult {
  const [isLoading, setIsLoading] = useState(false);
  const [hasPlayedOnce, setHasPlayedOnce] = useState(false);
  const [replayCount, setReplayCount] = useState(0);
  const [seekCount, setSeekCount] = useState(0);
  const [seekPenaltyTotal, setSeekPenaltyTotal] = useState(0);
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
  const speedRef = useRef(speed);

  // The timeupdate listener (attached once, when the <audio> element is
  // first created — see playUrl) must always read the *current* sentence,
  // not whichever one was active when it was attached, since the element
  // is reused across sessions with different sentences/word counts.
  useEffect(() => {
    sentenceRef.current = sentence;
  }, [sentence]);

  // play/seekTo are useCallback'd on [sentence, hasPlayedOnce] — speed is
  // deliberately not in that dep array (recreating them on every speed
  // tick would be wasteful) — so playUrl must read the *current* speed via
  // a ref rather than close over whatever `speed` was current when
  // play/seekTo were last recreated, or the very first play (and every
  // replay/seek before the next dep-array-triggered recreation) would
  // silently ignore the user's chosen speed and play at whatever stale
  // value was captured.
  useEffect(() => {
    speedRef.current = speed;
  }, [speed]);

  // A persistent hook instance (e.g. the dictation page reusing one hook
  // across "Câu khác"/retry sessions) must not leak playback state from a
  // prior sentence into a new one: hasPlayedOnce gating Nộp bài, replayCount/
  // seekPenaltyTotal feeding computeDictationScore, and the cached clip URL
  // would otherwise all belong to the wrong sentence. Reset whenever either
  // the sentence text or the session identity changes, never on initial mount.
  useEffect(() => {
    const sentenceChanged = previousSentenceRef.current !== sentence;
    const sessionKeyChanged = previousSessionKeyRef.current !== sessionKey;
    if (!sentenceChanged && !sessionKeyChanged) return;
    previousSentenceRef.current = sentence;
    previousSessionKeyRef.current = sessionKey;

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

  // Fetch audio in the background as soon as the sentence is ready, so Play
  // is instant once the user clicks it instead of waiting for a fresh
  // Cloud Function round-trip. Stores a promise (not just the eventual URL)
  // so play() can await the exact in-flight request and never fire a
  // duplicate — see play()'s branching below. Never touches hasPlayedOnce:
  // that flag must only flip on genuine user action.
  useEffect(() => {
    if (!sentence) return;
    // A prefetch started for this session can still be in flight when a
    // NEWER session starts (e.g. the user seeks — which doesn't force the
    // prefetch to settle the way play() does — then starts a new session
    // before the old prefetch resolves). The sessionKey-guarded reset
    // effect nulls the refs on session change, which stops the NEW
    // session's play() from *awaiting* the stale promise, but does
    // nothing to stop this OLDER promise's own .then()/.catch() from
    // firing afterward and clobbering the new session's refs with the
    // wrong (old sentence's) audio, or nulling its in-flight
    // prefetchPromiseRef and forcing a wasted duplicate fetch. Guard both
    // branches with a `cancelled` flag flipped by the cleanup function,
    // which React runs before the next effect run whenever [sentence,
    // sessionKey] changes.
    let cancelled = false;
    const promise = synthesizeSpeech({ text: sentence, language: "en" })
      .then(({ audioBase64 }) => {
        if (cancelled) return;
        fullClipUrlRef.current = toAudioDataUrl(audioBase64);
      })
      .catch(() => {
        if (cancelled) return;
        // Swallowed: the user hasn't asked for anything yet. play() will
        // retry with a fresh on-demand request since fullClipUrlRef and
        // prefetchPromiseRef both stay/become null on failure.
        prefetchPromiseRef.current = null;
      });
    prefetchPromiseRef.current = promise;
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [sentence, sessionKey]);

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
    audioEl.src = url;
    audioEl.playbackRate = speedRef.current;
    audioEl.currentTime = 0;
    // Playback can fail silently (autoplay policy, no audio device, a jsdom
    // stub in tests) — this must never block hasPlayedOnce/replayCount/seek
    // state, since scoring only cares about user intent (did they click
    // play), not whether audio literally rendered.
    const playResult = audioEl.play();
    if (playResult && typeof playResult.catch === "function") {
      playResult.catch(() => {});
    }
  }

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

  const setSpeed = useCallback((next: number) => {
    setSpeedState(next);
    if (audioRef.current) {
      audioRef.current.playbackRate = next;
    }
  }, []);

  const seekTo = useCallback(
    async (wordIndex: number) => {
      const words = targetWords(sentence);
      if (wordIndex < 0 || wordIndex >= words.length) return;

      setError(null);
      setIsLoading(true);
      try {
        const remainder = words.slice(wordIndex).join(" ");
        const { audioBase64 } = await synthesizeSpeech({ text: remainder, language: "en" });
        const url = toAudioDataUrl(audioBase64);
        if (hasPlayedOnce) {
          setSeekPenaltyTotal((total) => total + seekPenaltyFraction(wordIndex, words.length));
        } else {
          setHasPlayedOnce(true);
        }
        setSeekCount((c) => c + 1);
        baseWordIndexRef.current = wordIndex;
        setEstimatedWordIndex(wordIndex);
        playUrl(url);
      } catch (err) {
        setError(err instanceof Error ? err.message : String(err));
      } finally {
        setIsLoading(false);
      }
      // eslint-disable-next-line react-hooks/exhaustive-deps
    },
    [sentence, hasPlayedOnce]
  );

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
}
