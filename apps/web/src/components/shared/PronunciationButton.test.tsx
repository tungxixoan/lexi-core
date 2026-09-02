import { beforeEach, describe, expect, it, vi } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import { PronunciationButton } from "./PronunciationButton";
import { getPronunciationUrl } from "@/lib/pronunciation";

vi.mock("@/lib/pronunciation", async () => {
  const actual = await vi.importActual<typeof import("@/lib/pronunciation")>("@/lib/pronunciation");
  return { ...actual, getPronunciationUrl: vi.fn() };
});

beforeEach(() => {
  vi.clearAllMocks();
  window.HTMLMediaElement.prototype.play = vi.fn().mockResolvedValue(undefined);
});

describe("PronunciationButton", () => {
  it("renders nothing when language is null (unsupported target language)", () => {
    const { container } = render(<PronunciationButton text="hello" language={null} tier="word" />);
    expect(container.firstChild).toBeNull();
  });

  it("renders nothing when text is blank", () => {
    const { container } = render(<PronunciationButton text="   " language="en" tier="word" />);
    expect(container.firstChild).toBeNull();
  });

  it("fetches and plays the pronunciation audio when clicked", async () => {
    vi.mocked(getPronunciationUrl).mockResolvedValue("https://example.com/audio.wav");
    render(<PronunciationButton text="hello" language="en" tier="word" />);

    fireEvent.click(screen.getByRole("button", { name: /Nghe phát âm/ }));

    await waitFor(() => expect(window.HTMLMediaElement.prototype.play).toHaveBeenCalled());
    expect(getPronunciationUrl).toHaveBeenCalledWith({ text: "hello", language: "en", tier: "word" });
  });

  it("does not re-fetch the URL on a second click (caches within the component)", async () => {
    vi.mocked(getPronunciationUrl).mockResolvedValue("https://example.com/audio.wav");
    render(<PronunciationButton text="hello" language="en" tier="word" />);

    fireEvent.click(screen.getByRole("button", { name: /Nghe phát âm/ }));
    await waitFor(() => expect(getPronunciationUrl).toHaveBeenCalledTimes(1));

    fireEvent.click(screen.getByRole("button", { name: /Nghe phát âm/ }));
    await waitFor(() => expect(window.HTMLMediaElement.prototype.play).toHaveBeenCalledTimes(2));
    expect(getPronunciationUrl).toHaveBeenCalledTimes(1);
  });

  it("re-fetches for the new text when the same instance is pointed at a different word", async () => {
    vi.mocked(getPronunciationUrl)
      .mockResolvedValueOnce("https://example.com/collaboration.wav")
      .mockResolvedValueOnce("https://example.com/quantify.wav");
    const { rerender } = render(
      <PronunciationButton text="collaboration" language="en" tier="word" />
    );

    fireEvent.click(screen.getByRole("button", { name: /Nghe phát âm/ }));
    await waitFor(() => expect(getPronunciationUrl).toHaveBeenCalledTimes(1));

    rerender(<PronunciationButton text="quantify" language="en" tier="word" />);
    fireEvent.click(screen.getByRole("button", { name: /Nghe phát âm/ }));

    await waitFor(() => expect(getPronunciationUrl).toHaveBeenCalledTimes(2));
    expect(getPronunciationUrl).toHaveBeenLastCalledWith({
      text: "quantify",
      language: "en",
      tier: "word",
    });
  });

  it("shows a warning icon after a failed fetch, and stays clickable to retry", async () => {
    vi.mocked(getPronunciationUrl).mockRejectedValueOnce(new Error("network"));
    render(<PronunciationButton text="hello" language="en" tier="word" />);

    fireEvent.click(screen.getByRole("button", { name: /Nghe phát âm/ }));
    expect(await screen.findByText("⚠️")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /Nghe phát âm/ })).not.toBeDisabled();
  });
});
