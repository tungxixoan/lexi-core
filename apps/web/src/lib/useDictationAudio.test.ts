import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { renderHook, act, waitFor } from "@testing-library/react";
import { useDictationAudio } from "./useDictationAudio";
import { synthesizeSpeech } from "./synthesizeSpeechClient";

vi.mock("./synthesizeSpeechClient", async () => {
  const actual = await vi.importActual<typeof import("./synthesizeSpeechClient")>("./synthesizeSpeechClient");
  return { ...actual, synthesizeSpeech: vi.fn() };
});

const RealAudio = window.Audio;
let audioInstances: HTMLAudioElement[];

const SENTENCE = "The quick brown fox jumps over the lazy dog"; // 9 words

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

describe("useDictationAudio", () => {
  it("starts with hasPlayedOnce false and every counter at 0", () => {
    const { result } = renderHook(() => useDictationAudio(SENTENCE, 1));
    expect(result.current.hasPlayedOnce).toBe(false);
    expect(result.current.replayCount).toBe(0);
    expect(result.current.seekCount).toBe(0);
    expect(result.current.seekPenaltyTotal).toBe(0);
    expect(result.current.speed).toBe(1);
  });

  it("the first play() fetches audio for the full sentence and sets hasPlayedOnce, without incrementing replayCount", async () => {
    const { result } = renderHook(() => useDictationAudio(SENTENCE, 1));

    await act(async () => {
      await result.current.play();
    });

    expect(synthesizeSpeech).toHaveBeenCalledWith({ text: SENTENCE, language: "en" });
    expect(result.current.hasPlayedOnce).toBe(true);
    expect(result.current.replayCount).toBe(0);
  });

  it("every play() after the first increments replayCount and does not re-fetch audio", async () => {
    const { result } = renderHook(() => useDictationAudio(SENTENCE, 1));
    await act(async () => {
      await result.current.play();
    });

    await act(async () => {
      await result.current.play();
    });
    await act(async () => {
      await result.current.play();
    });

    expect(result.current.replayCount).toBe(2);
    expect(synthesizeSpeech).toHaveBeenCalledTimes(1);
  });

  it("setSpeed updates the reported speed without calling synthesizeSpeech or touching hasPlayedOnce/replayCount", () => {
    const { result } = renderHook(() => useDictationAudio(SENTENCE, 1));
    // Mount already triggered the background prefetch's own synthesizeSpeech
    // call; what this test checks is that setSpeed() doesn't add another one.
    const callsBeforeSetSpeed = vi.mocked(synthesizeSpeech).mock.calls.length;

    act(() => {
      result.current.setSpeed(1.25);
    });

    expect(result.current.speed).toBe(1.25);
    expect(synthesizeSpeech).toHaveBeenCalledTimes(callsBeforeSetSpeed);
    expect(result.current.hasPlayedOnce).toBe(false);
  });

  it("seekTo before any play sets hasPlayedOnce and increments seekCount, but adds no penalty", async () => {
    const { result } = renderHook(() => useDictationAudio(SENTENCE, 1));

    await act(async () => {
      await result.current.seekTo(3);
    });

    expect(synthesizeSpeech).toHaveBeenCalledWith({ text: "fox jumps over the lazy dog", language: "en" });
    expect(result.current.hasPlayedOnce).toBe(true);
    expect(result.current.seekCount).toBe(1);
    expect(result.current.seekPenaltyTotal).toBe(0);
  });

  it("seekTo after already having played adds the seekPenaltyFraction for that word index", async () => {
    const { result } = renderHook(() => useDictationAudio(SENTENCE, 1));
    await act(async () => {
      await result.current.play();
    });

    await act(async () => {
      await result.current.seekTo(0); // seeking to the very start of a 9-word sentence -> max penalty 0.05
    });

    expect(result.current.seekCount).toBe(1);
    expect(result.current.seekPenaltyTotal).toBeCloseTo(0.05);
  });

  it("accumulates seekPenaltyTotal across multiple seeks", async () => {
    const { result } = renderHook(() => useDictationAudio(SENTENCE, 1));
    await act(async () => {
      await result.current.play();
    });
    await act(async () => {
      await result.current.seekTo(0); // +0.05
    });
    await act(async () => {
      await result.current.seekTo(8); // 1 word re-heard of 9 -> ratio ~0.11 -> min 0.01
    });

    expect(result.current.seekCount).toBe(2);
    expect(result.current.seekPenaltyTotal).toBeCloseTo(0.06);
  });

  it("surfaces a Vietnamese error and stops loading when synthesizeSpeech rejects", async () => {
    vi.mocked(synthesizeSpeech).mockRejectedValue(new Error("network down"));
    const { result } = renderHook(() => useDictationAudio(SENTENCE, 1));

    await act(async () => {
      await result.current.play();
    });

    expect(result.current.error).toBe("network down");
    expect(result.current.isLoading).toBe(false);
    expect(result.current.hasPlayedOnce).toBe(false);
  });

  it("clears a prior error on the next successful play", async () => {
    // Rejects persistently (not just once): the background prefetch fires
    // first and consumes one rejection silently (swallowed, never surfaced
    // as `error`), so play()'s own on-demand fetch needs a second rejection
    // to actually populate `error`.
    vi.mocked(synthesizeSpeech).mockRejectedValue(new Error("network down"));
    const { result } = renderHook(() => useDictationAudio(SENTENCE, 1));
    await waitFor(() => expect(synthesizeSpeech).toHaveBeenCalledTimes(1)); // let the prefetch fail first

    await act(async () => {
      await result.current.play();
    });
    expect(result.current.error).toBe("network down");

    vi.mocked(synthesizeSpeech).mockResolvedValue({ audioBase64: "AAAA" });
    await act(async () => {
      await result.current.play();
    });

    await waitFor(() => expect(result.current.error).toBeNull());
    expect(result.current.hasPlayedOnce).toBe(true);
  });

  it("resets playback state and drops the cached clip when the sentence argument changes on the same hook instance", async () => {
    const NEW_SENTENCE = "Pack my box with five dozen liquor jugs"; // different sentence, same instance

    const { result, rerender } = renderHook(({ sentence, sessionKey }) => useDictationAudio(sentence, sessionKey), {
      initialProps: { sentence: SENTENCE, sessionKey: 1 },
    });

    await act(async () => {
      await result.current.play();
    });
    expect(result.current.hasPlayedOnce).toBe(true);

    await act(async () => {
      await result.current.seekTo(0); // bump replayCount-adjacent counters too
    });
    expect(result.current.seekCount).toBe(1);
    expect(result.current.seekPenaltyTotal).toBeGreaterThan(0);

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

  it("resets playback state and drops the cached clip when sessionKey changes even though the sentence text is identical (same reused saved exercise)", async () => {
    const { result, rerender } = renderHook(({ sentence, sessionKey }) => useDictationAudio(sentence, sessionKey), {
      initialProps: { sentence: SENTENCE, sessionKey: 1 },
    });

    await act(async () => {
      await result.current.play();
    });
    expect(result.current.hasPlayedOnce).toBe(true);

    await act(async () => {
      await result.current.seekTo(0); // bump replayCount-adjacent counters too
    });
    expect(result.current.seekCount).toBe(1);
    expect(result.current.seekPenaltyTotal).toBeGreaterThan(0);

    // Same sentence text (e.g. only one saved exercise exists, so "Câu khác"
    // re-picks the identical document), but a new session was started —
    // sessionKey changes. All playback state must still reset.
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

  it("isLoading is true while a synthesizeSpeech call is in flight", async () => {
    let resolveCall!: (value: { audioBase64: string }) => void;
    vi.mocked(synthesizeSpeech).mockReturnValue(
      new Promise((resolve) => {
        resolveCall = resolve;
      })
    );
    const { result } = renderHook(() => useDictationAudio(SENTENCE, 1));

    let playPromise!: Promise<void>;
    act(() => {
      playPromise = result.current.play();
    });
    expect(result.current.isLoading).toBe(true);

    await act(async () => {
      resolveCall({ audioBase64: "AAAA" });
      await playPromise;
    });
    expect(result.current.isLoading).toBe(false);
  });

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
});
