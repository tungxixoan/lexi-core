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

  const audioRef = useRef<HTMLAudioElement | null>(null);
  const fullClipUrlRef = useRef<string | null>(null);
  const prefetchPromiseRef = useRef<Promise<void> | null>(null);
  const previousSentenceRef = useRef(sentence);
  const previousSessionKeyRef = useRef(sessionKey);

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
    fullClipUrlRef.current = null;
    prefetchPromiseRef.current = null;
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

  function playUrl(url: string) {
    if (!audioRef.current) {
      audioRef.current = new Audio();
    }
    const audioEl = audioRef.current;
    audioEl.src = url;
    audioEl.playbackRate = speed;
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
    error,
    play,
    setSpeed,
    seekTo,
  };
}
