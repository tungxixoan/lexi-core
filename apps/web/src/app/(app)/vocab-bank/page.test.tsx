import { beforeEach, describe, expect, it, vi } from "vitest";
import { render, screen, waitFor, fireEvent } from "@testing-library/react";
import VocabBankPage from "./page";
import { useAuthUser } from "@/lib/useAuthUser";
import { deleteVocabRecord, getVocabRecords } from "@/lib/vocabRecords";
import { getTopics } from "@/lib/topics";

vi.mock("@/lib/useAuthUser", () => ({ useAuthUser: vi.fn() }));
vi.mock("@/lib/vocabRecords", () => ({ getVocabRecords: vi.fn(), deleteVocabRecord: vi.fn() }));
vi.mock("@/lib/topics", () => ({ getTopics: vi.fn() }));
vi.mock("@/components/SignInButton", () => ({
  SignInButton: () => <button>Đăng nhập với Google</button>,
}));

beforeEach(() => {
  vi.clearAllMocks();
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

    await waitFor(() => expect(deleteVocabRecord).toHaveBeenCalledWith("u1", "2"));
    await waitFor(() => expect(screen.queryByText("meticulous")).not.toBeInTheDocument());
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
});
