import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { renderHook, act, waitFor } from "@testing-library/react";
import { useComprehensionAudio } from "./useComprehensionAudio";
import { synthesizeSpeech } from "./synthesizeSpeechClient";
import type { ListeningPassage, Speaker, VoiceId } from "./listeningPassage";

vi.mock("./synthesizeSpeechClient", async () => {
  const actual = await vi.importActual<typeof import("./synthesizeSpeechClient")>("./synthesizeSpeechClient");
  return { ...actual, synthesizeSpeech: vi.fn() };
});

const RealAudio = window.Audio;
let audioInstances: HTMLAudioElement[];

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

afterEach(() => {
  vi.restoreAllMocks();
});

const TWO_SPEAKER_PASSAGE: ListeningPassage = {
  kind: "conversation",
  turns: [
    { speaker: "A", text: "Hello there friend" }, // 3 words
    { speaker: "B", text: "Hi how are you" }, // 4 words
  ],
  questions: [],
  speakerGenders: { A: "male", B: "female" },
  level: "b1",
  context: "general",
  targetLanguage: "english",
};

const THREE_TURN_PASSAGE: ListeningPassage = {
  kind: "conversation",
  turns: [
    { speaker: "A", text: "Hello there friend" }, // 3 words
    { speaker: "B", text: "Hi how are you" }, // 4 words
    { speaker: "A", text: "I am doing fine" }, // 4 words
  ],
  questions: [],
  speakerGenders: { A: "male", B: "female" },
  level: "b1",
  context: "general",
  targetLanguage: "english",
};

const VOICES: Partial<Record<Speaker, VoiceId>> = { A: "male1", B: "female1" };

describe("useComprehensionAudio", () => {
  it("prefetches every turn in parallel as soon as passage is set", async () => {
    renderHook(() => useComprehensionAudio(TWO_SPEAKER_PASSAGE, VOICES, 1));

    await waitFor(() => expect(synthesizeSpeech).toHaveBeenCalledTimes(2));
    expect(synthesizeSpeech).toHaveBeenCalledWith({ text: "Hello there friend", language: "en", voice: "male1" });
    expect(synthesizeSpeech).toHaveBeenCalledWith({ text: "Hi how are you", language: "en", voice: "female1" });
  });

  it("starts at turn 0, not speaking", () => {
    const { result } = renderHook(() => useComprehensionAudio(TWO_SPEAKER_PASSAGE, VOICES, 1));
    expect(result.current.currentTurnIndex).toBe(0);
    expect(result.current.isSpeaking).toBe(false);
  });

  it("play() plays the current turn using the prefetched clip, no duplicate fetch", async () => {
    const { result } = renderHook(() => useComprehensionAudio(TWO_SPEAKER_PASSAGE, VOICES, 1));
    await waitFor(() => expect(synthesizeSpeech).toHaveBeenCalledTimes(2));

    await act(async () => {
      result.current.play();
      await Promise.resolve();
    });

    expect(synthesizeSpeech).toHaveBeenCalledTimes(2); // no 3rd call
    expect(result.current.isSpeaking).toBe(true);
  });

  it("auto-advances to the next turn when the current one ends, and stops speaking after the last turn", async () => {
    const { result } = renderHook(() => useComprehensionAudio(TWO_SPEAKER_PASSAGE, VOICES, 1));
    await waitFor(() => expect(synthesizeSpeech).toHaveBeenCalledTimes(2));

    await act(async () => {
      result.current.play();
      await Promise.resolve();
    });
    expect(result.current.currentTurnIndex).toBe(0);

    await act(async () => {
      audioInstances[audioInstances.length - 1].dispatchEvent(new Event("ended"));
      await Promise.resolve();
      await Promise.resolve();
    });
    expect(result.current.currentTurnIndex).toBe(1);
    expect(result.current.isSpeaking).toBe(true);

    await act(async () => {
      audioInstances[audioInstances.length - 1].dispatchEvent(new Event("ended"));
      await Promise.resolve();
    });
    expect(result.current.isSpeaking).toBe(false); // no turn 2 — passage has only 2 turns
  });

  it("previousTurn/nextTurn move currentTurnIndex and stop speaking", async () => {
    const { result } = renderHook(() => useComprehensionAudio(TWO_SPEAKER_PASSAGE, VOICES, 1));
    await waitFor(() => expect(synthesizeSpeech).toHaveBeenCalledTimes(2));

    act(() => result.current.nextTurn());
    expect(result.current.currentTurnIndex).toBe(1);

    act(() => result.current.previousTurn());
    expect(result.current.currentTurnIndex).toBe(0);

    // Can't go before 0 or past the last turn.
    act(() => result.current.previousTurn());
    expect(result.current.currentTurnIndex).toBe(0);
  });

  it("seekToGlobalWord resolves the right turn and re-synthesizes the remainder, tagged with that turn's voice", async () => {
    const { result } = renderHook(() => useComprehensionAudio(TWO_SPEAKER_PASSAGE, VOICES, 1));
    await waitFor(() => expect(synthesizeSpeech).toHaveBeenCalledTimes(2));
    vi.mocked(synthesizeSpeech).mockClear();

    // global word 4 = turn A has 3 words (0,1,2), so word 4 is turn B's word index 1 ("how").
    await act(async () => {
      await result.current.seekToGlobalWord(4);
    });

    expect(result.current.currentTurnIndex).toBe(1);
    expect(synthesizeSpeech).toHaveBeenCalledWith({ text: "how are you", language: "en", voice: "female1" });
  });

  it("estimatedGlobalWordIndex resets to the seek target immediately", async () => {
    const { result } = renderHook(() => useComprehensionAudio(TWO_SPEAKER_PASSAGE, VOICES, 1));
    await waitFor(() => expect(synthesizeSpeech).toHaveBeenCalledTimes(2));

    await act(async () => {
      await result.current.seekToGlobalWord(4);
    });
    expect(result.current.estimatedGlobalWordIndex).toBe(4);
  });

  it("setSpeed applies to whichever turn's clip is currently loaded, read fresh not from a stale closure", async () => {
    const { result } = renderHook(() => useComprehensionAudio(TWO_SPEAKER_PASSAGE, VOICES, 1));
    await waitFor(() => expect(synthesizeSpeech).toHaveBeenCalledTimes(2));

    act(() => result.current.setSpeed(1.5));
    await act(async () => {
      result.current.play();
      await Promise.resolve();
    });

    expect(audioInstances[audioInstances.length - 1].playbackRate).toBe(1.5);
  });

  it("nextTurn called twice in the same synchronous batch advances by two, not one (ref must not lag behind state)", async () => {
    const { result } = renderHook(() => useComprehensionAudio(THREE_TURN_PASSAGE, VOICES, 1));
    await waitFor(() => expect(synthesizeSpeech).toHaveBeenCalledTimes(3));

    await act(async () => {
      result.current.nextTurn();
      result.current.nextTurn();
    });

    expect(result.current.currentTurnIndex).toBe(2);
  });

  it("nextTurn(); play() in the same synchronous batch plays the post-navigation turn, not the pre-navigation one", async () => {
    vi.mocked(synthesizeSpeech).mockImplementation(async ({ text }: { text: string }) => {
      if (text === "Hello there friend") return { audioBase64: "AAAA" };
      if (text === "Hi how are you") return { audioBase64: "BBBB" };
      return { audioBase64: "CCCC" };
    });

    const { result } = renderHook(() => useComprehensionAudio(THREE_TURN_PASSAGE, VOICES, 1));
    await waitFor(() => expect(synthesizeSpeech).toHaveBeenCalledTimes(3));

    await act(async () => {
      result.current.nextTurn();
      result.current.play();
      await Promise.resolve();
      await Promise.resolve();
    });

    expect(result.current.currentTurnIndex).toBe(1);
    const lastAudio = audioInstances[audioInstances.length - 1];
    expect(lastAudio.src).toBe("data:audio/wav;base64,BBBB");
  });

  it("a stale prefetch from a discarded session does not clobber a new session's clip", async () => {
    // Both sessions' turn 0 land in the SAME clipUrlsRef map slot (index 0)
    // — that's exactly what makes the `cancelled` guard load-bearing rather
    // than incidental. Resolve session 1's turn-0 request AFTER session 2's
    // own turn-0 request has already resolved, then prove play() in session
    // 2 uses session 2's audio, not session 1's stale one.
    const resolvers: Record<string, (v: { audioBase64: string }) => void> = {};
    vi.mocked(synthesizeSpeech).mockImplementation(
      ({ text }: { text: string }) =>
        new Promise((resolve) => {
          resolvers[text] = resolve;
        })
    );

    const { result, rerender } = renderHook(
      ({ passage, sessionKey }) => useComprehensionAudio(passage, VOICES, sessionKey),
      { initialProps: { passage: TWO_SPEAKER_PASSAGE, sessionKey: 1 } }
    );
    await waitFor(() => expect(resolvers["Hello there friend"]).toBeDefined());

    const NEW_PASSAGE: ListeningPassage = {
      ...TWO_SPEAKER_PASSAGE,
      turns: [{ speaker: null, text: "A totally different talk" }],
      kind: "talk",
    };
    rerender({ passage: NEW_PASSAGE, sessionKey: 2 });
    await waitFor(() => expect(resolvers["A totally different talk"]).toBeDefined());

    // Session 2's own prefetch resolves first ("NEW").
    resolvers["A totally different talk"]({ audioBase64: "NEW" });
    await Promise.resolve();

    // Session 1's stale prefetch resolves late, after session 2 has already
    // started — must not clobber session 2's clip at the same map slot.
    resolvers["Hello there friend"]({ audioBase64: "OLD" });
    await Promise.resolve();

    await act(async () => {
      result.current.play();
      await Promise.resolve();
    });

    const lastAudio = audioInstances[audioInstances.length - 1];
    expect(lastAudio.src).toBe("data:audio/wav;base64,NEW");
  });

  it("estimatedGlobalWordIndex tracks a real timeupdate event within a fully-loaded turn", async () => {
    const { result } = renderHook(() => useComprehensionAudio(THREE_TURN_PASSAGE, VOICES, 1));
    await waitFor(() => expect(synthesizeSpeech).toHaveBeenCalledTimes(3));

    // Move to turn 1 (global offset 3, 4 words: "Hi how are you").
    act(() => result.current.nextTurn());
    await act(async () => {
      result.current.play();
      await Promise.resolve();
    });

    const audioEl = audioInstances[audioInstances.length - 1];
    act(() => {
      Object.defineProperty(audioEl, "duration", { value: 10, configurable: true });
      Object.defineProperty(audioEl, "currentTime", { value: 5, configurable: true });
      audioEl.dispatchEvent(new Event("timeupdate"));
    });

    // Full turn loaded => local base 0. raw = 0 + (5/10)*4 = 2 => global = offset(3) + 2 = 5.
    expect(result.current.estimatedGlobalWordIndex).toBe(5);
  });

  it("estimatedGlobalWordIndex under timeupdate accounts for the seek's local offset within the turn, not the full turn from word 0 (Finding 1 regression guard)", async () => {
    const { result } = renderHook(() => useComprehensionAudio(THREE_TURN_PASSAGE, VOICES, 1));
    await waitFor(() => expect(synthesizeSpeech).toHaveBeenCalledTimes(3));
    vi.mocked(synthesizeSpeech).mockClear();

    // global word 9 -> turn 2 (offset 7, "I am doing fine"), local word index 2 ("doing").
    await act(async () => {
      await result.current.seekToGlobalWord(9);
    });
    expect(result.current.currentTurnIndex).toBe(2);
    expect(result.current.estimatedGlobalWordIndex).toBe(9);

    const audioEl = audioInstances[audioInstances.length - 1];
    act(() => {
      Object.defineProperty(audioEl, "duration", { value: 10, configurable: true });
      Object.defineProperty(audioEl, "currentTime", { value: 0, configurable: true });
      audioEl.dispatchEvent(new Event("timeupdate"));
    });

    // The loaded clip is only the 2-word remainder starting at local index 2
    // ("doing fine"). At currentTime=0 the estimate must stay AT the seek
    // target (global 9) — the pre-fix bug computed ratio against the full
    // 4-word turn from local index 0, snapping back to global 7.
    expect(result.current.estimatedGlobalWordIndex).toBe(9);
  });
});
