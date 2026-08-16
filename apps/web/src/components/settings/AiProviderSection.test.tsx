import { describe, expect, it, vi } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import { AiProviderSection } from "./AiProviderSection";
import { encryptApiKey } from "@/lib/encryptApiKey";
import { DEFAULT_SETTINGS } from "@/lib/settings";

vi.mock("@/lib/encryptApiKey", () => ({ encryptApiKey: vi.fn() }));

describe("AiProviderSection", () => {
  it("renders all 3 providers and calls onSave with the new activeProvider when switching", () => {
    const onSave = vi.fn();
    render(<AiProviderSection settings={DEFAULT_SETTINGS} onSave={onSave} />);

    expect(screen.getByRole("option", { name: "Gemini" })).toBeInTheDocument();
    expect(screen.getByRole("option", { name: "Groq" })).toBeInTheDocument();
    expect(screen.getByRole("option", { name: "OpenRouter" })).toBeInTheDocument();

    fireEvent.change(screen.getByLabelText("Provider"), { target: { value: "groq" } });

    expect(onSave).toHaveBeenCalledWith({ ...DEFAULT_SETTINGS, activeProvider: "groq" });
  });

  it("propagates a model change through onSave for the active provider only", () => {
    const onSave = vi.fn();
    render(<AiProviderSection settings={DEFAULT_SETTINGS} onSave={onSave} />);

    fireEvent.change(screen.getByLabelText("Model"), { target: { value: "gemini-2.5-pro" } });

    expect(onSave).toHaveBeenCalledWith({
      ...DEFAULT_SETTINGS,
      providers: {
        ...DEFAULT_SETTINGS.providers,
        gemini: { ...DEFAULT_SETTINGS.providers.gemini, model: "gemini-2.5-pro" },
      },
    });
  });

  it("shows a masked placeholder when a key is already saved for the active provider", () => {
    const settings = {
      ...DEFAULT_SETTINGS,
      providers: {
        ...DEFAULT_SETTINGS.providers,
        gemini: { ...DEFAULT_SETTINGS.providers.gemini, apiKeyCiphertext: "existing-cipher" },
      },
    };
    render(<AiProviderSection settings={settings} onSave={vi.fn()} />);
    expect(screen.getByLabelText("API key")).toHaveAttribute("placeholder", "••••••••");
  });

  it("encrypts and saves a new key when Cập nhật is clicked", async () => {
    vi.mocked(encryptApiKey).mockResolvedValue({ ciphertext: "new-cipher" });
    const onSave = vi.fn();
    render(<AiProviderSection settings={DEFAULT_SETTINGS} onSave={onSave} />);

    fireEvent.change(screen.getByLabelText("API key"), { target: { value: "sk-new-key" } });
    fireEvent.click(screen.getByRole("button", { name: "Cập nhật" }));

    await waitFor(() =>
      expect(onSave).toHaveBeenCalledWith({
        ...DEFAULT_SETTINGS,
        providers: {
          ...DEFAULT_SETTINGS.providers,
          gemini: { ...DEFAULT_SETTINGS.providers.gemini, apiKeyCiphertext: "new-cipher" },
        },
      })
    );
    expect(encryptApiKey).toHaveBeenCalledWith({ apiKey: "sk-new-key" });
    expect(screen.getByLabelText("API key")).toHaveValue("");
  });

  it("shows an alert and does not call onSave when encryptApiKey fails", async () => {
    vi.mocked(encryptApiKey).mockRejectedValue(new Error("unauthenticated"));
    const onSave = vi.fn();
    render(<AiProviderSection settings={DEFAULT_SETTINGS} onSave={onSave} />);

    fireEvent.change(screen.getByLabelText("API key"), { target: { value: "sk-new-key" } });
    fireEvent.click(screen.getByRole("button", { name: "Cập nhật" }));

    await waitFor(() => expect(screen.getByRole("alert")).toHaveTextContent("unauthenticated"));
    expect(onSave).not.toHaveBeenCalled();
  });

  it("disables Cập nhật while the API key input is empty", () => {
    render(<AiProviderSection settings={DEFAULT_SETTINGS} onSave={vi.fn()} />);
    expect(screen.getByRole("button", { name: "Cập nhật" })).toBeDisabled();
  });
});
