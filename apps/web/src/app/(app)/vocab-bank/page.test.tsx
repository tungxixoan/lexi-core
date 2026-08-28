import { beforeEach, describe, expect, it, vi } from "vitest";
import { render, screen, waitFor, fireEvent } from "@testing-library/react";
import VocabBankPage from "./page";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettingsContext } from "@/lib/SettingsContext";
import { deleteVocabRecord, getVocabRecords, updateVocabRecord } from "@/lib/vocabRecords";
import { getTopics } from "@/lib/topics";
import { DEFAULT_SETTINGS } from "@/lib/settings";

vi.mock("@/lib/useAuthUser", () => ({ useAuthUser: vi.fn() }));
vi.mock("@/lib/SettingsContext", () => ({ useSettingsContext: vi.fn() }));
vi.mock("@/lib/vocabRecords", () => ({
  getVocabRecords: vi.fn(),
  deleteVocabRecord: vi.fn(),
  updateVocabRecord: vi.fn(),
}));
vi.mock("@/lib/topics", () => ({ getTopics: vi.fn() }));
vi.mock("@/components/SignInButton", () => ({
  SignInButton: () => <button>Đăng nhập với Google</button>,
}));

beforeEach(() => {
  vi.clearAllMocks();
  vi.mocked(useSettingsContext).mockReturnValue({
    settings: DEFAULT_SETTINGS,
    loading: false,
    error: null,
    save: vi.fn(),
  } as never);
  Element.prototype.scrollIntoView = vi.fn();
  class FakeIntersectionObserver {
    observe = vi.fn();
    disconnect = vi.fn();
    unobserve = vi.fn();
    constructor(_callback: IntersectionObserverCallback) {}
  }
  vi.stubGlobal("IntersectionObserver", FakeIntersectionObserver as never);
});

const RECORD_DUE_TODAY = {
  id: "1",
  headword: "relocate",
  inputType: "word",
  ipa: "",
  meaning: "dời đi",
  examples: [],
  personalNotes: "",
  topicIds: ["business"],
  targetLanguage: "english",
  cefrLevel: "b2",
  activeContext: "business",
  createdAt: "2026-08-01T00:00:00.000Z",
  updatedAt: "2026-08-01T00:00:00.000Z",
  nextReviewAt: "2026-01-01T00:00:00.000Z",
  sm2Repetitions: 1,
  sm2EaseFactor: 2.5,
  sm2Interval: 1,
  definition: "",
  synonyms: [],
};

const RECORD_NOT_DUE = {
  ...RECORD_DUE_TODAY,
  id: "2",
  headword: "meticulous",
  meaning: "tỉ mỉ, cẩn thận",
  cefrLevel: "c1",
  nextReviewAt: "2099-01-01T00:00:00.000Z",
};

const RECORD_TRAVEL_A1 = {
  ...RECORD_DUE_TODAY,
  id: "3",
  headword: "passport",
  meaning: "hộ chiếu",
  topicIds: ["travel"],
  cefrLevel: "a1",
  nextReviewAt: "2099-01-01T00:00:00.000Z",
};

const TOPIC_BUSINESS = {
  id: "business",
  name: "Business",
  emoji: "💼",
  isPredefined: true,
  createdAt: "2026-01-01T00:00:00.000Z",
};

const MANY_RECORDS = Array.from({ length: 15 }, (_, i) => ({
  ...RECORD_DUE_TODAY,
  id: `many-${i}`,
  headword: `word-${i}`,
  meaning: `nghĩa-${i}`,
}));

const HUGE_RECORDS = Array.from({ length: 250 }, (_, i) => ({
  ...RECORD_DUE_TODAY,
  id: `huge-${i}`,
  headword: `w${i}`,
  meaning: `m${i}`,
}));

describe("VocabBankPage", () => {
  it("prompts sign-in when logged out", () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: null, loading: false });
    render(<VocabBankPage />);
    expect(screen.getByText("Đăng nhập với Google")).toBeInTheDocument();
  });

  it("loads and lists the user's vocab records with due labels", async () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" } as never, loading: false });
    vi.mocked(getVocabRecords).mockResolvedValue([RECORD_DUE_TODAY, RECORD_NOT_DUE] as never);
    vi.mocked(getTopics).mockResolvedValue([]);

    render(<VocabBankPage />);

    expect(await screen.findByText("relocate")).toBeInTheDocument();
    expect(screen.getByText("meticulous")).toBeInTheDocument();
    expect(screen.getByText("Tất cả (2)")).toBeInTheDocument();
    expect(screen.getByText("Cần ôn hôm nay (1)")).toBeInTheDocument();
  });

  it("filters to due-today words when that chip is clicked", async () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" } as never, loading: false });
    vi.mocked(getVocabRecords).mockResolvedValue([RECORD_DUE_TODAY, RECORD_NOT_DUE] as never);
    vi.mocked(getTopics).mockResolvedValue([]);

    render(<VocabBankPage />);
    await screen.findByText("relocate");

    fireEvent.click(screen.getByText("Cần ôn hôm nay (1)"));

    expect(screen.getByText("relocate")).toBeInTheDocument();
    expect(screen.queryByText("meticulous")).not.toBeInTheDocument();
  });

  it("shows an alert on a Firestore read error", async () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" } as never, loading: false });
    vi.mocked(getVocabRecords).mockRejectedValue(new Error("boom"));
    vi.mocked(getTopics).mockResolvedValue([]);

    render(<VocabBankPage />);

    await waitFor(() => expect(screen.getByRole("alert")).toHaveTextContent("boom"));
  });

  it("opens the Side Drawer with the clicked word's detail when a row is clicked", async () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" } as never, loading: false });
    vi.mocked(getVocabRecords).mockResolvedValue([RECORD_DUE_TODAY, RECORD_NOT_DUE] as never);
    vi.mocked(getTopics).mockResolvedValue([]);

    render(<VocabBankPage />);
    await screen.findByText("relocate");

    fireEvent.click(screen.getByText("meticulous"));

    expect(screen.getByRole("heading", { name: "meticulous" })).toBeInTheDocument();
  });

  it("deletes the selected word after confirmation and closes the drawer", async () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" } as never, loading: false });
    vi.mocked(getVocabRecords).mockResolvedValue([RECORD_DUE_TODAY, RECORD_NOT_DUE] as never);
    vi.mocked(getTopics).mockResolvedValue([]);
    vi.mocked(deleteVocabRecord).mockResolvedValue(undefined);
    vi.spyOn(window, "confirm").mockReturnValue(true);

    render(<VocabBankPage />);
    await screen.findByText("relocate");
    fireEvent.click(screen.getByText("meticulous"));
    fireEvent.click(screen.getByRole("button", { name: "Xoá" }));

    await waitFor(() => expect(deleteVocabRecord).toHaveBeenCalledWith("u1", "2", "english"));
    await waitFor(() => expect(screen.queryByText("meticulous")).not.toBeInTheDocument());
  });

  it("shows an alert and keeps the word in the list when delete fails", async () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" } as never, loading: false });
    vi.mocked(getVocabRecords).mockResolvedValue([RECORD_DUE_TODAY, RECORD_NOT_DUE] as never);
    vi.mocked(getTopics).mockResolvedValue([]);
    vi.mocked(deleteVocabRecord).mockRejectedValue(new Error("permission-denied"));
    vi.spyOn(window, "confirm").mockReturnValue(true);

    render(<VocabBankPage />);
    await screen.findByText("relocate");
    fireEvent.click(screen.getByText("meticulous"));
    fireEvent.click(screen.getByRole("button", { name: "Xoá" }));

    await waitFor(() =>
      expect(screen.getByRole("alert")).toHaveTextContent("permission-denied")
    );
    const rowStillPresent = screen
      .getAllByText("meticulous")
      .some((el) => el.closest(".vrow"));
    expect(rowStillPresent).toBe(true);
  });

  it("does not delete when the confirmation is cancelled", async () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" } as never, loading: false });
    vi.mocked(getVocabRecords).mockResolvedValue([RECORD_DUE_TODAY] as never);
    vi.mocked(getTopics).mockResolvedValue([]);
    vi.spyOn(window, "confirm").mockReturnValue(false);

    render(<VocabBankPage />);
    await screen.findByText("relocate");
    fireEvent.click(screen.getByText("relocate"));
    fireEvent.click(screen.getByRole("button", { name: "Xoá" }));

    expect(deleteVocabRecord).not.toHaveBeenCalled();
  });

  it("OR-combines multiple CEFR chips within the same facet", async () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" } as never, loading: false });
    vi.mocked(getVocabRecords).mockResolvedValue(
      [RECORD_DUE_TODAY, RECORD_NOT_DUE, RECORD_TRAVEL_A1] as never
    );
    vi.mocked(getTopics).mockResolvedValue([]);

    render(<VocabBankPage />);
    await screen.findByText("relocate"); // b2
    await screen.findByText("meticulous"); // c1
    await screen.findByText("passport"); // a1

    fireEvent.click(screen.getByRole("button", { name: "B2" }));
    fireEvent.click(screen.getByRole("button", { name: "C1" }));

    expect(screen.getByText("relocate")).toBeInTheDocument();
    expect(screen.getByText("meticulous")).toBeInTheDocument();
    expect(screen.queryByText("passport")).not.toBeInTheDocument();
  });

  it("AND-combines across facets (topic AND cefr)", async () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" } as never, loading: false });
    vi.mocked(getVocabRecords).mockResolvedValue(
      [RECORD_DUE_TODAY, RECORD_NOT_DUE, RECORD_TRAVEL_A1] as never
    );
    vi.mocked(getTopics).mockResolvedValue([TOPIC_BUSINESS] as never);

    render(<VocabBankPage />);
    await screen.findByText("relocate");

    fireEvent.click(screen.getByRole("button", { name: "Chủ đề ▾" }));
    fireEvent.click(screen.getByRole("button", { name: "💼 Business" }));
    fireEvent.click(screen.getByRole("button", { name: "Áp dụng" }));
    fireEvent.click(screen.getByRole("button", { name: "C1" })); // only RECORD_NOT_DUE is c1

    expect(screen.queryByText("relocate")).not.toBeInTheDocument();
    expect(screen.getByText("meticulous")).toBeInTheDocument();
    expect(screen.queryByText("passport")).not.toBeInTheDocument();
  });

  it("shows Xoá lọc only when a filter is active, and it resets everything", async () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" } as never, loading: false });
    vi.mocked(getVocabRecords).mockResolvedValue([RECORD_DUE_TODAY, RECORD_NOT_DUE] as never);
    vi.mocked(getTopics).mockResolvedValue([]);

    render(<VocabBankPage />);
    await screen.findByText("relocate");

    expect(screen.queryByText("✕ Xoá lọc")).not.toBeInTheDocument();

    fireEvent.click(screen.getByRole("button", { name: "C1" }));
    expect(screen.getByText("✕ Xoá lọc")).toBeInTheDocument();
    expect(screen.queryByText("relocate")).not.toBeInTheDocument();

    fireEvent.click(screen.getByText("✕ Xoá lọc"));
    expect(screen.queryByText("✕ Xoá lọc")).not.toBeInTheDocument();
    expect(screen.getByText("relocate")).toBeInTheDocument();
    expect(screen.getByText("meticulous")).toBeInTheDocument();
  });

  it("only renders the first 10 rows when more than 10 records match, and shows a page bar", async () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" } as never, loading: false });
    vi.mocked(getVocabRecords).mockResolvedValue(MANY_RECORDS as never);
    vi.mocked(getTopics).mockResolvedValue([]);

    render(<VocabBankPage />);
    await screen.findByText("word-0");

    expect(screen.getByText("word-9")).toBeInTheDocument();
    expect(screen.queryByText("word-10")).not.toBeInTheDocument();
    expect(screen.getByText("2")).toBeInTheDocument(); // page bar button for page 2
  });

  it("reveals more rows when the page-2 button is clicked", async () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" } as never, loading: false });
    vi.mocked(getVocabRecords).mockResolvedValue(MANY_RECORDS as never);
    vi.mocked(getTopics).mockResolvedValue([]);

    render(<VocabBankPage />);
    await screen.findByText("word-0");

    fireEvent.click(screen.getByText("2"));

    expect(screen.getByText("word-14")).toBeInTheDocument();
  });

  it("opens the edit modal from the drawer and saves changes in place", async () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" } as never, loading: false });
    vi.mocked(getVocabRecords).mockResolvedValue([RECORD_DUE_TODAY, RECORD_NOT_DUE] as never);
    vi.mocked(getTopics).mockResolvedValue([]);
    vi.mocked(updateVocabRecord).mockResolvedValue(undefined);

    render(<VocabBankPage />);
    await screen.findByText("relocate");
    fireEvent.click(screen.getByText("meticulous"));
    fireEvent.click(screen.getByRole("button", { name: "Sửa" }));

    expect(screen.getByRole("dialog")).toBeInTheDocument();

    fireEvent.change(screen.getByDisplayValue("tỉ mỉ, cẩn thận"), {
      target: { value: "nghĩa đã sửa" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Lưu" }));

    await waitFor(() => expect(updateVocabRecord).toHaveBeenCalledWith("u1", "2", expect.any(Object), "english"));
    await waitFor(() => expect(screen.queryByRole("dialog")).not.toBeInTheDocument());
    // Both the list row and the still-open drawer reflect the update in place (no refetch).
    expect(screen.getAllByText("nghĩa đã sửa")).toHaveLength(2);
  });

  it("closes the edit modal without saving when Huỷ is clicked", async () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" } as never, loading: false });
    vi.mocked(getVocabRecords).mockResolvedValue([RECORD_DUE_TODAY, RECORD_NOT_DUE] as never);
    vi.mocked(getTopics).mockResolvedValue([]);

    render(<VocabBankPage />);
    await screen.findByText("relocate");
    fireEvent.click(screen.getByText("meticulous"));
    fireEvent.click(screen.getByRole("button", { name: "Sửa" }));
    fireEvent.click(screen.getByRole("button", { name: "Huỷ" }));

    expect(screen.queryByRole("dialog")).not.toBeInTheDocument();
    expect(updateVocabRecord).not.toHaveBeenCalled();
  });

  it("shows a windowed page bar (not all 25 buttons) for a large result set", async () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" } as never, loading: false });
    vi.mocked(getVocabRecords).mockResolvedValue(HUGE_RECORDS as never);
    vi.mocked(getTopics).mockResolvedValue([]);

    render(<VocabBankPage />);
    await screen.findByText("w0");

    // 250 records / 10 per page = 25 pages; windowed around page 1 -> 1, 2, 3, …, 25
    expect(screen.getByRole("button", { name: "1" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "2" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "3" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "25" })).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "13" })).not.toBeInTheDocument();
    expect(screen.getByText("…")).toBeInTheDocument();
  });

  it("re-centers the windowed page bar when a distant page button is clicked", async () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" } as never, loading: false });
    vi.mocked(getVocabRecords).mockResolvedValue(HUGE_RECORDS as never);
    vi.mocked(getTopics).mockResolvedValue([]);

    render(<VocabBankPage />);
    await screen.findByText("w0");

    // Window centered on page 1: 1, 2, 3, …, 25.
    expect(screen.getByRole("button", { name: "2" })).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "23" })).not.toBeInTheDocument();

    fireEvent.click(screen.getByRole("button", { name: "25" }));

    // currentPage now feeds getPageWindow as 25, re-centering the window
    // around the end: 1, …, 23, 24, 25.
    expect(await screen.findByRole("button", { name: "23" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "24" })).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "2" })).not.toBeInTheDocument();
    expect(screen.getByText("w249")).toBeInTheDocument();
  });

  it("resets pagination back to page 1 when a topic filter is applied via the popover", async () => {
    // Renders 250 rows twice (full reveal, then reset back down) — jsdom
    // needs more than the default 5s budget for that much DOM work.
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" } as never, loading: false });
    vi.mocked(getVocabRecords).mockResolvedValue(HUGE_RECORDS as never);
    vi.mocked(getTopics).mockResolvedValue([TOPIC_BUSINESS] as never);

    render(<VocabBankPage />);
    await screen.findByText("w0");

    fireEvent.click(screen.getByRole("button", { name: "25" }));
    expect(await screen.findByText("w249")).toBeInTheDocument();

    // Applying the Business filter doesn't narrow HUGE_RECORDS (every record
    // already has topicIds: ["business"]) — the point here is proving the
    // "genuine filter change" reset path fires, not that the filter narrows.
    fireEvent.click(screen.getByRole("button", { name: "Chủ đề ▾" }));
    fireEvent.click(screen.getByRole("button", { name: "💼 Business" }));
    fireEvent.click(screen.getByRole("button", { name: "Áp dụng" }));

    expect(screen.getByText("w9")).toBeInTheDocument();
    expect(screen.queryByText("w249")).not.toBeInTheDocument();
  }, 10000);

  it("does NOT reset pagination when deleting a record while deep in a paginated view (same filter, no reset)", async () => {
    // Renders 250 rows and interacts through them — jsdom needs more than
    // the default 5s budget for that much DOM work.
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" } as never, loading: false });
    vi.mocked(getVocabRecords).mockResolvedValue(HUGE_RECORDS as never);
    vi.mocked(getTopics).mockResolvedValue([]);
    vi.mocked(deleteVocabRecord).mockResolvedValue(undefined);
    vi.spyOn(window, "confirm").mockReturnValue(true);

    render(<VocabBankPage />);
    await screen.findByText("w0");

    fireEvent.click(screen.getByRole("button", { name: "3" })); // reveal through page 3
    expect(await screen.findByText("w25")).toBeInTheDocument();

    fireEvent.click(screen.getByText("w25")); // select a page-3 record
    fireEvent.click(screen.getByRole("button", { name: "Xoá" }));

    await waitFor(() => expect(deleteVocabRecord).toHaveBeenCalledWith("u1", "huge-25", "english"));
    // Deleting is a data mutation with an unchanged filter -> filterSignature
    // is unchanged -> pagination must NOT collapse back to page 1.
    expect(screen.getByText("w20")).toBeInTheDocument();
    expect(screen.queryByText("w25")).not.toBeInTheDocument();
  }, 10000);
});
