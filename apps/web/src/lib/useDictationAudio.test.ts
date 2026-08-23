import { beforeEach, describe, expect, it, vi } from "vitest";
import { renderHook, act, waitFor } from "@testing-library/react";
import { useDictationAudio } from "./useDictationAudio";
import { synthesizeSpeech } from "./synthesizeSpeechClient";

vi.mock("./synthesizeSpeechClient", async () => {
  const actual = await vi.importActual<typeof import("./synthesizeSpeechClient")>("./synthesizeSpeechClient");
  return { ...actual, synthesizeSpeech: vi.fn() };
});

const SENTENCE = "The quick brown fox jumps over the lazy dog"; // 9 words

beforeEach(() => {
  vi.clearAllMocks();
  vi.mocked(synthesizeSpeech).mockResolvedValue({ audioBase64: "AAAA" });
});

describe("useDictationAudio", () => {
  it("starts with hasPlayedOnce false and every counter at 0", () => {
    const { result } = renderHook(() => useDictationAudio(SENTENCE));
    expect(result.current.hasPlayedOnce).toBe(false);
    expect(result.current.replayCount).toBe(0);
    expect(result.current.seekCount).toBe(0);
    expect(result.current.seekPenaltyTotal).toBe(0);
    expect(result.current.speed).toBe(1);
  });

  it("the first play() fetches audio for the full sentence and sets hasPlayedOnce, without incrementing replayCount", async () => {
    const { result } = renderHook(() => useDictationAudio(SENTENCE));

    await act(async () => {
      await result.current.play();
    });

    expect(synthesizeSpeech).toHaveBeenCalledWith({ text: SENTENCE, language: "en" });
    expect(result.current.hasPlayedOnce).toBe(true);
    expect(result.current.replayCount).toBe(0);
  });

  it("every play() after the first increments replayCount and does not re-fetch audio", async () => {
    const { result } = renderHook(() => useDictationAudio(SENTENCE));
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
    const { result } = renderHook(() => useDictationAudio(SENTENCE));

    act(() => {
      result.current.setSpeed(1.25);
    });

    expect(result.current.speed).toBe(1.25);
    expect(synthesizeSpeech).not.toHaveBeenCalled();
    expect(result.current.hasPlayedOnce).toBe(false);
  });

  it("seekTo before any play sets hasPlayedOnce and increments seekCount, but adds no penalty", async () => {
    const { result } = renderHook(() => useDictationAudio(SENTENCE));

    await act(async () => {
      await result.current.seekTo(3);
    });

    expect(synthesizeSpeech).toHaveBeenCalledWith({ text: "fox jumps over the lazy dog", language: "en" });
    expect(result.current.hasPlayedOnce).toBe(true);
    expect(result.current.seekCount).toBe(1);
    expect(result.current.seekPenaltyTotal).toBe(0);
  });

  it("seekTo after already having played adds the seekPenaltyFraction for that word index", async () => {
    const { result } = renderHook(() => useDictationAudio(SENTENCE));
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
    const { result } = renderHook(() => useDictationAudio(SENTENCE));
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
    const { result } = renderHook(() => useDictationAudio(SENTENCE));

    await act(async () => {
      await result.current.play();
    });

    expect(result.current.error).toBe("network down");
    expect(result.current.isLoading).toBe(false);
    expect(result.current.hasPlayedOnce).toBe(false);
  });

  it("clears a prior error on the next successful play", async () => {
    vi.mocked(synthesizeSpeech).mockRejectedValueOnce(new Error("network down"));
    const { result } = renderHook(() => useDictationAudio(SENTENCE));
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

  it("isLoading is true while a synthesizeSpeech call is in flight", async () => {
    let resolveCall!: (value: { audioBase64: string }) => void;
    vi.mocked(synthesizeSpeech).mockReturnValue(
      new Promise((resolve) => {
        resolveCall = resolve;
      })
    );
    const { result } = renderHook(() => useDictationAudio(SENTENCE));

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
});
