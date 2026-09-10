import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import { describe, expect, it, vi, beforeEach } from "vitest";

vi.mock("@/lib/generateContent", () => ({ generateContent: vi.fn() }));
vi.mock("@/lib/useAuthUser", () => ({ useAuthUser: () => ({ user: { uid: "u" }, loading: false }) }));
vi.mock("@/lib/SettingsContext", () => ({
  useSettingsContext: vi.fn(),
}));

import { generateContent } from "@/lib/generateContent";
import { useSettingsContext } from "@/lib/SettingsContext";
import { AiComposeModal } from "./AiComposeModal";
import { noteFixture } from "./testUtils";

const WITH_KEY = {
  settings: {
    activeProvider: "gemini",
    targetLanguage: "english",
    providers: { gemini: { model: "m", apiKeyCiphertext: "ct" } },
  },
  loading: false,
  error: null,
  save: vi.fn(),
};

const WITHOUT_KEY = {
  settings: {
    activeProvider: "gemini",
    targetLanguage: "english",
    providers: { gemini: { model: "m", apiKeyCiphertext: null } },
  },
  loading: false,
  error: null,
  save: vi.fn(),
};

const okDraft = JSON.stringify({
  title: "Câu điều kiện loại 2",
  summary: "S",
  explanation: "E",
  patterns: [],
  examples: [],
  pitfalls: [],
  suggestedGroupId: "en_conditionals",
  suggestedCefr: "b1",
  suggestedTags: [],
  relatedNoteId: null,
});

describe("AiComposeModal", () => {
  beforeEach(() => {
    vi.mocked(useSettingsContext).mockReturnValue(WITH_KEY as never);
  });

  it("Layer-1 hit → shows the related banner; 'Vẫn tạo mới' generates and opens the editor", async () => {
    vi.mocked(generateContent).mockResolvedValue({ text: okDraft });
    render(
      <AiComposeModal
        existingNotes={[noteFixture({ id: "a", title: "Câu điều kiện loại 2 và 3" })]}
        targetLanguage="english"
        onClose={() => {}}
        onSaved={vi.fn()}
      />,
    );
    fireEvent.change(screen.getByRole("textbox"), { target: { value: "câu điều kiện loại 2" } });
    fireEvent.click(screen.getByRole("button", { name: "Soạn" }));
    expect(await screen.findByText(/ghi chú liên quan/)).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "Vẫn tạo mới" }));
    await waitFor(() => expect(generateContent).toHaveBeenCalled());
    expect(await screen.findByDisplayValue("Câu điều kiện loại 2")).toBeInTheDocument();
  });

  it("no API key → shows the Cài đặt hint, no Soạn button", () => {
    vi.mocked(useSettingsContext).mockReturnValue(WITHOUT_KEY as never);
    render(
      <AiComposeModal existingNotes={[]} targetLanguage="english" onClose={() => {}} onSaved={vi.fn()} />,
    );
    expect(screen.getByText(/Cài đặt/)).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Soạn" })).not.toBeInTheDocument();
  });

  it("generateContent throws → error state + Thử lại", async () => {
    vi.mocked(generateContent).mockRejectedValue(new Error("boom"));
    render(<AiComposeModal existingNotes={[]} targetLanguage="english" onClose={() => {}} onSaved={vi.fn()} />);
    fireEvent.change(screen.getByRole("textbox"), { target: { value: "chủ đề mới toanh" } });
    fireEvent.click(screen.getByRole("button", { name: "Soạn" }));
    expect(await screen.findByText(/Không tạo được/)).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Thử lại" })).toBeInTheDocument();
  });
});
