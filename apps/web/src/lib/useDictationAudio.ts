import { useCallback, useRef, useState } from "react";
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
export function useDictationAudio(sentence: string): UseDictationAudioResult {
  const [isLoading, setIsLoading] = useState(false);
  const [hasPlayedOnce, setHasPlayedOnce] = useState(false);
  const [replayCount, setReplayCount] = useState(0);
  const [seekCount, setSeekCount] = useState(0);
  const [seekPenaltyTotal, setSeekPenaltyTotal] = useState(0);
  const [speed, setSpeedState] = useState(1);
  const [error, setError] = useState<string | null>(null);

  const audioRef = useRef<HTMLAudioElement | null>(null);
  const fullClipUrlRef = useRef<string | null>(null);

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
