import { describe, expect, it, vi } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import { LanguageSection } from "./LanguageSection";
import { DEFAULT_SETTINGS } from "@/lib/settings";

describe("LanguageSection", () => {
  it("renders all 5 supported target languages with native-script labels", () => {
    render(<LanguageSection settings={DEFAULT_SETTINGS} onSave={vi.fn()} />);
    fireEvent.click(screen.getByRole("button", { name: "English ▾" }));
    expect(screen.getByRole("option", { name: "Tiếng Việt" })).toBeInTheDocument();
    expect(screen.getByRole("option", { name: "English" })).toBeInTheDocument();
    expect(screen.getByRole("option", { name: "中文" })).toBeInTheDocument();
    expect(screen.getByRole("option", { name: "한국어" })).toBeInTheDocument();
    expect(screen.getByRole("option", { name: "日本語" })).toBeInTheDocument();
  });

  it("calls onSave with the new targetLanguage when a different one is picked", () => {
    const onSave = vi.fn();
    render(<LanguageSection settings={DEFAULT_SETTINGS} onSave={onSave} />);
    fireEvent.click(screen.getByRole("button", { name: "English ▾" }));
    fireEvent.click(screen.getByRole("option", { name: "日本語" }));
    expect(onSave).toHaveBeenCalledWith({ ...DEFAULT_SETTINGS, targetLanguage: "japanese" });
  });

  it("shows the current target language on the trigger", () => {
    render(
      <LanguageSection
        settings={{ ...DEFAULT_SETTINGS, targetLanguage: "korean" }}
        onSave={vi.fn()}
      />
    );
    expect(screen.getByRole("button", { name: "한국어 ▾" })).toBeInTheDocument();
  });

  it("shows an alert when saving the target language fails", async () => {
    const onSave = vi.fn().mockRejectedValue(new Error("offline"));
    render(<LanguageSection settings={DEFAULT_SETTINGS} onSave={onSave} />);
    fireEvent.click(screen.getByRole("button", { name: "English ▾" }));
    fireEvent.click(screen.getByRole("option", { name: "日本語" }));
    await waitFor(() => expect(screen.getByRole("alert")).toHaveTextContent("offline"));
  });
});
