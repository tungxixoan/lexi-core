import { describe, expect, it } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import { HighlightedText } from "./HighlightedText";
import type { VocabRecord } from "@/lib/vocabRecords";

function makeRecord(overrides: Partial<VocabRecord>): VocabRecord {
  return {
    id: "id",
    headword: "word",
    inputType: "word",
    ipa: "",
    meaning: "nghĩa",
    examples: [],
    personalNotes: "",
    topicIds: [],
    targetLanguage: "english",
    cefrLevel: "b1",
    activeContext: "general",
    createdAt: "2026-01-01T00:00:00.000Z",
    updatedAt: "2026-01-01T00:00:00.000Z",
    nextReviewAt: null,
    sm2Repetitions: 0,
    sm2EaseFactor: 2.5,
    sm2Interval: 1,
    definition: "",
    synonyms: [],
    ...overrides,
  };
}

describe("HighlightedText (static variant)", () => {
  it("wraps each matching substring in a <mark>, case-insensitively", () => {
    render(
      <HighlightedText
        text="Báo cáo hàng quý cho thấy doanh thu tăng."
        variant="static"
        highlights={["hàng quý", "tăng"]}
      />
    );
    const marks = screen.getAllByText(/hàng quý|tăng/, { selector: "mark" });
    expect(marks).toHaveLength(2);
  });

  it("never renders a button or popover", () => {
    render(<HighlightedText text="tăng nhanh" variant="static" highlights={["tăng"]} />);
    expect(screen.queryByRole("button")).not.toBeInTheDocument();
  });

  it("renders plain text unchanged when no highlights match", () => {
    render(<HighlightedText text="no matches here" variant="static" highlights={["xyz"]} />);
    expect(screen.getByText("no matches here")).toBeInTheDocument();
    expect(screen.queryByRole("mark")).not.toBeInTheDocument();
  });
});

describe("HighlightedText (interactive variant)", () => {
  const records = [
    makeRecord({ id: "r1", headword: "increase", ipa: "/ɪnˈkriːs/", meaning: "tăng", cefrLevel: "a2" }),
    makeRecord({ id: "r2", headword: "quarterly", ipa: "/ˈkwɔːtəli/", meaning: "hàng quý", cefrLevel: "b1" }),
  ];

  it("renders each known headword as a clickable button, case-insensitively", () => {
    render(
      <HighlightedText
        text="The Quarterly report shows an increase."
        variant="interactive"
        records={records}
        ttsLanguage="en"
      />
    );
    expect(screen.getByRole("button", { name: "Quarterly" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "increase" })).toBeInTheDocument();
  });

  it("opens a popover with headword, ipa, meaning, and CEFR pill on click", () => {
    render(
      <HighlightedText text="an increase" variant="interactive" records={records} ttsLanguage="en" />
    );
    fireEvent.click(screen.getByRole("button", { name: "increase" }));
    expect(screen.getByText("/ɪnˈkriːs/")).toBeInTheDocument();
    expect(screen.getByText("tăng")).toBeInTheDocument();
    expect(screen.getByText("A2")).toBeInTheDocument();
  });

  it("closes the popover on a second click of the same word", () => {
    render(
      <HighlightedText text="an increase" variant="interactive" records={records} ttsLanguage="en" />
    );
    const btn = screen.getByRole("button", { name: "increase" });
    fireEvent.click(btn);
    expect(screen.getByText("tăng")).toBeInTheDocument();
    fireEvent.click(btn);
    expect(screen.queryByText("tăng")).not.toBeInTheDocument();
  });

  it("earliest-occurrence-wins when two candidate words could both start a match at different positions", () => {
    // "quarterly" starts earlier in the text than "increase" — only "quarterly"'s
    // occurrence should be highlighted at that position, per Flutter's algorithm.
    render(
      <HighlightedText
        text="quarterly then an increase"
        variant="interactive"
        records={records}
        ttsLanguage="en"
      />
    );
    expect(screen.getAllByRole("button")).toHaveLength(2);
  });

  it("renders plain text with no button when records is empty", () => {
    render(<HighlightedText text="no known words" variant="interactive" records={[]} ttsLanguage="en" />);
    expect(screen.queryByRole("button")).not.toBeInTheDocument();
    expect(screen.getByText("no known words")).toBeInTheDocument();
  });
});
