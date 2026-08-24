import { useCallback, useEffect, useRef, useState } from "react";
import { synthesizeSpeech, toAudioDataUrl } from "./synthesizeSpeechClient";
import { targetWords } from "./dictation";
import type { ListeningPassage, Speaker, VoiceId } from "./listeningPassage";

export interface UseComprehensionAudioResult {
  isSpeaking: boolean;
  isSeeking: boolean;
  currentTurnIndex: number;
  estimatedGlobalWordIndex: number;
  speed: number;
  error: string | null;
  play: () => void;
  stop: () => void;
  previousTurn: () => void;
  nextTurn: () => void;
  replayFromStart: () => void;
  seekToGlobalWord: (globalWordIndex: number) => Promise<void>;
  setSpeed: (speed: number) => void;
}

function speakerFor(passage: ListeningPassage, turnIndex: number): Speaker {
  return passage.turns[turnIndex]?.speaker ?? "solo";
}

function turnWordCounts(passage: ListeningPassage): number[] {
  return passage.turns.map((t) => targetWords(t.text).length);
}

function turnWordOffsets(passage: ListeningPassage): number[] {
  const counts = turnWordCounts(passage);
  const offsets: number[] = [];
  let sum = 0;
  for (const c of counts) {
    offsets.push(sum);
    sum += c;
  }
  return offsets;
}

function resolveGlobalWordIndex(passage: ListeningPassage, globalWordIndex: number): { turnIndex: number; wordIndex: number } {
  let remaining = globalWordIndex;
  const counts = turnWordCounts(passage);
  for (let t = 0; t < counts.length; t++) {
    if (remaining < counts[t]) return { turnIndex: t, wordIndex: remaining };
    remaining -= counts[t];
  }
  const lastTurn = counts.length - 1;
  return { turnIndex: lastTurn, wordIndex: Math.max(counts[lastTurn] - 1, 0) };
}

export function useComprehensionAudio(
  passage: ListeningPassage | null,
  voiceAssignment: Partial<Record<Speaker, VoiceId>>,
  sessionKey: string | number
): UseComprehensionAudioResult {
  const [isSpeaking, setIsSpeaking] = useState(false);
  const [isSeeking, setIsSeeking] = useState(false);
  const [currentTurnIndex, setCurrentTurnIndex] = useState(0);
  const [estimatedGlobalWordIndex, setEstimatedGlobalWordIndex] = useState(0);
  const [speed, setSpeedState] = useState(1);
  const [error, setError] = useState<string | null>(null);

  const audioRef = useRef<HTMLAudioElement | null>(null);
  const clipUrlsRef = useRef<Map<number, string>>(new Map());
  const prefetchPromisesRef = useRef<Map<number, Promise<void>>>(new Map());
  // Tracks the LOCAL word offset (within the currently-loaded turn/clip) that
  // the loaded audio clip starts at: 0 whenever a full turn is loaded
  // (playTurn/previousTurn/nextTurn/replayFromStart), or `wordIndex` whenever
  // seekToGlobalWord loads a REMAINDER clip starting partway through a turn.
  // The timeupdate handler needs this to correctly interpret currentTime/
  // duration against whatever's actually loaded — mirrors
  // useDictationAudio's own baseWordIndexRef exactly.
  const localBaseWordIndexRef = useRef(0);
  const speedRef = useRef(speed);
  const passageRef = useRef(passage);
  const voiceAssignmentRef = useRef(voiceAssignment);
  const currentTurnIndexRef = useRef(0);
  const playTokenRef = useRef(0);

  useEffect(() => {
    speedRef.current = speed;
  }, [speed]);
  useEffect(() => {
    passageRef.current = passage;
  }, [passage]);
  useEffect(() => {
    voiceAssignmentRef.current = voiceAssignment;
  }, [voiceAssignment]);

  // Reset all state on a genuine passage/session change — never on initial
  // mount. Mirrors useDictationAudio's own reset effect exactly, extended
  // to the per-turn clip cache/prefetch maps this hook adds.
  const previousPassageRef = useRef(passage);
  const previousSessionKeyRef = useRef(sessionKey);
  useEffect(() => {
    const passageChanged = previousPassageRef.current !== passage;
    const sessionKeyChanged = previousSessionKeyRef.current !== sessionKey;
    if (!passageChanged && !sessionKeyChanged) return;
    previousPassageRef.current = passage;
    previousSessionKeyRef.current = sessionKey;

    setIsSpeaking(false);
    setCurrentTurnIndex(0);
    currentTurnIndexRef.current = 0;
    setEstimatedGlobalWordIndex(0);
    setError(null);
    clipUrlsRef.current = new Map();
    prefetchPromisesRef.current = new Map();
    localBaseWordIndexRef.current = 0;
    playTokenRef.current += 1;
    if (audioRef.current) audioRef.current.pause();
  }, [passage, sessionKey]);

  // Prefetch every turn in parallel as soon as the passage is ready. Each
  // request is guarded against a stale (discarded-session) callback writing
  // into a newer session's clip map — the same `cancelled`-in-cleanup
  // pattern the final Nghe chép review required for its own single-clip
  // prefetch, extended to N turns here.
  useEffect(() => {
    if (!passage) return;
    let cancelled = false;
    for (let i = 0; i < passage.turns.length; i++) {
      const turn = passage.turns[i];
      const speaker = speakerFor(passage, i);
      const voice = voiceAssignment[speaker];
      const promise = synthesizeSpeech({ text: turn.text, language: "en", voice })
        .then(({ audioBase64 }) => {
          if (cancelled) return;
          clipUrlsRef.current.set(i, toAudioDataUrl(audioBase64));
        })
        .catch(() => {
          if (cancelled) return;
          prefetchPromisesRef.current.delete(i);
        });
      prefetchPromisesRef.current.set(i, promise);
    }
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [passage, sessionKey]);

  function ensureAudioElement(): HTMLAudioElement {
    if (!audioRef.current) {
      audioRef.current = new Audio();
      audioRef.current.addEventListener("timeupdate", () => {
        const el = audioRef.current;
        if (!el || !Number.isFinite(el.duration) || el.duration <= 0) return;
        const currentPassage = passageRef.current;
        if (!currentPassage) return;
        const turnIndex = currentTurnIndexRef.current;
        const counts = turnWordCounts(currentPassage);
        const totalWordsInTurn = counts[turnIndex] ?? 0;
        if (totalWordsInTurn === 0) return;
        // The loaded clip may be the full turn (base 0) or just the
        // remainder from a seek (base = wordIndex seeked to) — see
        // localBaseWordIndexRef's doc comment above. Mirrors
        // useDictationAudio.ts's own base + ratio*(total-base) formula.
        const base = localBaseWordIndexRef.current;
        const raw = base + (el.currentTime / el.duration) * (totalWordsInTurn - base);
        const localEstimate = Math.min(Math.max(Math.round(raw), 0), totalWordsInTurn - 1);
        const offsets = turnWordOffsets(currentPassage);
        setEstimatedGlobalWordIndex((offsets[turnIndex] ?? 0) + localEstimate);
      });
    }
    return audioRef.current;
  }

  function playUrl(url: string, onEnded: (() => void) | null) {
    const audioEl = ensureAudioElement();
    audioEl.onended = onEnded;
    audioEl.src = url;
    audioEl.playbackRate = speedRef.current;
    audioEl.currentTime = 0;
    const playResult = audioEl.play();
    if (playResult && typeof playResult.catch === "function") {
      playResult.catch(() => {});
    }
  }

  const playTurn = useCallback(
    async (turnIndex: number, token: number) => {
      const currentPassage = passageRef.current;
      if (!currentPassage || turnIndex >= currentPassage.turns.length) {
        setIsSpeaking(false);
        return;
      }
      const offsets = turnWordOffsets(currentPassage);
      localBaseWordIndexRef.current = 0;
      setEstimatedGlobalWordIndex(offsets[turnIndex] ?? 0);
      setCurrentTurnIndex(turnIndex);
      currentTurnIndexRef.current = turnIndex;
      setIsSpeaking(true);
      setError(null);

      const isLastTurn = turnIndex === currentPassage.turns.length - 1;
      const onEnded = () => {
        if (playTokenRef.current !== token) return; // superseded meanwhile
        if (isLastTurn) {
          setIsSpeaking(false);
          return;
        }
        void playTurn(turnIndex + 1, token);
      };

      const cached = clipUrlsRef.current.get(turnIndex);
      if (cached) {
        playUrl(cached, onEnded);
        return;
      }
      const prefetchPromise = prefetchPromisesRef.current.get(turnIndex);
      try {
        if (prefetchPromise) await prefetchPromise;
        if (playTokenRef.current !== token) return; // superseded while awaiting
        const cachedNow = clipUrlsRef.current.get(turnIndex);
        if (cachedNow) {
          playUrl(cachedNow, onEnded);
          return;
        }
        const turn = currentPassage.turns[turnIndex];
        const speaker = speakerFor(currentPassage, turnIndex);
        const voice = voiceAssignmentRef.current[speaker];
        const { audioBase64 } = await synthesizeSpeech({ text: turn.text, language: "en", voice });
        if (playTokenRef.current !== token) return;
        const url = toAudioDataUrl(audioBase64);
        clipUrlsRef.current.set(turnIndex, url);
        playUrl(url, onEnded);
      } catch (err) {
        if (playTokenRef.current !== token) return;
        setError(err instanceof Error ? err.message : String(err));
        setIsSpeaking(false);
      }
    },
    // eslint-disable-next-line react-hooks/exhaustive-deps
    []
  );

  const play = useCallback(() => {
    playTokenRef.current += 1;
    void playTurn(currentTurnIndexRef.current, playTokenRef.current);
  }, [playTurn]);

  const stop = useCallback(() => {
    playTokenRef.current += 1; // supersede any in-flight auto-advance
    if (audioRef.current) audioRef.current.pause();
    setIsSpeaking(false);
  }, []);

  const previousTurn = useCallback(() => {
    const currentPassage = passageRef.current;
    if (!currentPassage || currentTurnIndexRef.current === 0) return;
    playTokenRef.current += 1;
    if (audioRef.current) audioRef.current.pause();
    const newIndex = currentTurnIndexRef.current - 1;
    const offsets = turnWordOffsets(currentPassage);
    localBaseWordIndexRef.current = 0;
    setEstimatedGlobalWordIndex(offsets[newIndex] ?? 0);
    setCurrentTurnIndex(newIndex);
    currentTurnIndexRef.current = newIndex;
    setIsSpeaking(false);
  }, []);

  const nextTurn = useCallback(() => {
    const currentPassage = passageRef.current;
    if (!currentPassage || currentTurnIndexRef.current >= currentPassage.turns.length - 1) return;
    playTokenRef.current += 1;
    if (audioRef.current) audioRef.current.pause();
    const newIndex = currentTurnIndexRef.current + 1;
    const offsets = turnWordOffsets(currentPassage);
    localBaseWordIndexRef.current = 0;
    setEstimatedGlobalWordIndex(offsets[newIndex] ?? 0);
    setCurrentTurnIndex(newIndex);
    currentTurnIndexRef.current = newIndex;
    setIsSpeaking(false);
  }, []);

  const replayFromStart = useCallback(() => {
    playTokenRef.current += 1;
    if (audioRef.current) audioRef.current.pause();
    localBaseWordIndexRef.current = 0;
    setEstimatedGlobalWordIndex(0);
    setCurrentTurnIndex(0);
    currentTurnIndexRef.current = 0;
    setIsSpeaking(false);
  }, []);

  const seekToGlobalWord = useCallback(async (globalWordIndex: number) => {
    const currentPassage = passageRef.current;
    if (!currentPassage) return;
    const totalWords = turnWordCounts(currentPassage).reduce((a, b) => a + b, 0);
    if (globalWordIndex < 0 || globalWordIndex >= totalWords) return;

    const { turnIndex, wordIndex } = resolveGlobalWordIndex(currentPassage, globalWordIndex);
    const offsets = turnWordOffsets(currentPassage);
    localBaseWordIndexRef.current = wordIndex;
    setEstimatedGlobalWordIndex(offsets[turnIndex] + wordIndex);
    setCurrentTurnIndex(turnIndex);
    currentTurnIndexRef.current = turnIndex;
    setError(null);

    playTokenRef.current += 1;
    const token = playTokenRef.current;
    setIsSpeaking(true);
    setIsSeeking(true);
    try {
      const turn = currentPassage.turns[turnIndex];
      const words = targetWords(turn.text);
      const remainder = words.slice(wordIndex).join(" ");
      const speaker = speakerFor(currentPassage, turnIndex);
      const voice = voiceAssignmentRef.current[speaker];
      const { audioBase64 } = await synthesizeSpeech({ text: remainder, language: "en", voice });
      if (playTokenRef.current !== token) return;
      const url = toAudioDataUrl(audioBase64);
      const isLastTurn = turnIndex === currentPassage.turns.length - 1;
      playUrl(url, () => {
        if (playTokenRef.current !== token) return;
        if (isLastTurn) {
          setIsSpeaking(false);
          return;
        }
        void playTurn(turnIndex + 1, token);
      });
    } catch (err) {
      if (playTokenRef.current !== token) return;
      setError(err instanceof Error ? err.message : String(err));
      setIsSpeaking(false);
    } finally {
      if (playTokenRef.current === token) setIsSeeking(false);
    }
  }, [playTurn]);

  const setSpeed = useCallback((next: number) => {
    setSpeedState(next);
    if (audioRef.current) audioRef.current.playbackRate = next;
  }, []);

  return {
    isSpeaking,
    isSeeking,
    currentTurnIndex,
    estimatedGlobalWordIndex,
    speed,
    error,
    play,
    stop,
    previousTurn,
    nextTurn,
    replayFromStart,
    seekToGlobalWord,
    setSpeed,
  };
}
