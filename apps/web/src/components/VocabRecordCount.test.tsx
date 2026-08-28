import { beforeEach, describe, expect, it, vi } from "vitest";
import { render, screen, waitFor } from "@testing-library/react";
import { VocabRecordCount } from "./VocabRecordCount";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettingsContext } from "@/lib/SettingsContext";
import { countVocabRecords } from "@/lib/vocabRecords";
import { DEFAULT_SETTINGS } from "@/lib/settings";

vi.mock("@/lib/useAuthUser", () => ({ useAuthUser: vi.fn() }));
vi.mock("@/lib/SettingsContext", () => ({ useSettingsContext: vi.fn() }));
vi.mock("@/lib/vocabRecords", () => ({ countVocabRecords: vi.fn() }));

beforeEach(() => {
  vi.mocked(useSettingsContext).mockReturnValue({
    settings: DEFAULT_SETTINGS,
    loading: false,
    error: null,
    save: vi.fn(),
  } as never);
});

describe("VocabRecordCount", () => {
  it("renders nothing when signed out", () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: null, loading: false });
    const { container } = render(<VocabRecordCount />);
    expect(container).toBeEmptyDOMElement();
  });

  it("shows the vocab count once loaded for a signed-in user", async () => {
    vi.mocked(useAuthUser).mockReturnValue({
      user: { uid: "user-123" } as never,
      loading: false,
    });
    vi.mocked(countVocabRecords).mockResolvedValue(7);
    render(<VocabRecordCount />);
    await waitFor(() =>
      expect(
        screen.getByText("Bạn có 7 từ trong Ngân hàng từ vựng.")
      ).toBeInTheDocument()
    );
    expect(countVocabRecords).toHaveBeenCalledWith("user-123", "english");
  });

  it("shows an error message if the Firestore read fails", async () => {
    vi.mocked(useAuthUser).mockReturnValue({
      user: { uid: "user-123" } as never,
      loading: false,
    });
    vi.mocked(countVocabRecords).mockRejectedValue(new Error("permission-denied"));
    render(<VocabRecordCount />);
    await waitFor(() =>
      expect(screen.getByRole("alert")).toHaveTextContent("permission-denied")
    );
  });
});
