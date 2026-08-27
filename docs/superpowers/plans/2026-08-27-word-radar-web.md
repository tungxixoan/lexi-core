# Quét từ vựng (Word Radar) on Web Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship `/reading/word-radar` on the web app — paste any text, instantly highlight words already in the user's Vocab Bank (tap for an inline popover with meaning + pronunciation, no navigation), and (when AI is enabled) get one AI call back with a Vietnamese translation of the whole text plus up to 10 new-word suggestions, reusing the existing save/dismiss/bulk-save flow.

**Architecture:** A new `HighlightedText` shared component covers both highlight needs (clickable known-word popovers in the pasted text, static highlighted meanings in the translation). `vocabSuggestions.ts` and `VocabSuggestionsSection.tsx` — both already built for 5 existing result screens — gain an opt-in `includeTranslation` path that restores the translation half their own code comments say was deliberately left out. A new page wires it all together; a 5th card in the Reading hub links to it.

**Tech Stack:** Next.js/React, Firestore, Vitest + Testing Library, existing `generateContent` BYOK Cloud Function (no new backend).

## Global Constraints

- Vietnamese-first UI: every new user-facing string is Vietnamese.
- No new Cloud Function — reuses the existing `generateContent` onCall exactly like every other AI call site in this app.
- Known-word matching filters to `record.targetLanguage === settings.targetLanguage` — the current target language only, matching Flutter's `getAll(language: language)`.
- Tapping a highlighted known word opens an inline popover on the same page (headword, 🔊 listen button, IPA, meaning, CEFR pill) — **no navigation**, since web's Vocab Bank has no per-record detail page.
- The listen button in the popover is the existing `PronunciationButton` component (`.pron-btn` CSS, `tier="word"`) — do not invent new listen UI.
- Highlight matching algorithm is a direct, exact port of Flutter's `word_radar_screen.dart`'s `_HighlightedText`: case-insensitive substring match, at each step the candidate whose earliest occurrence in the remaining text comes first overall wins (no length-based tie-break), continue from the end of that match, no overlapping highlights.
- Reached via a 5th card ("🔎 Quét từ vựng") in the Reading hub's card grid (`apps/web/src/app/(app)/reading/page.tsx`), navigating straight to `/reading/word-radar` — it does **not** join the other 4 cards' `mode`/filter-footer flow.
- Existing behavior of `vocabSuggestions.ts`/`VocabSuggestionsSection.tsx`'s 5 current call sites (bilingual, part5, part6, part7, comprehension result screens) must be unaffected — `includeTranslation` defaults to `false`/absent everywhere it isn't explicitly passed.
- Every task's commit must leave `npx tsc --noEmit` clean — no task may leave the repo in a non-compiling state, even temporarily between commits.

---

## Task 1: `HighlightedText` shared component

**Files:**
- Create: `apps/web/src/components/shared/HighlightedText.tsx`
- Create: `apps/web/src/components/shared/HighlightedText.test.tsx`
- Modify: `apps/web/src/styles/bloom.css` (append)

**Interfaces:**
- Consumes: `VocabRecord` from `@/lib/vocabRecords` (existing — has `headword: string`, `ipa: string`, `meaning: string`, `cefrLevel: "a1"|"a2"|"b1"|"b2"|"c1"|"c2"`); `TtsLanguage` from `@/lib/pronunciation` (existing, `"vi" | "en"`); `PronunciationButton` from `./PronunciationButton` (existing, props `{ text: string; language: TtsLanguage | null; tier: "word" | "sentence" }`).
- Produces: `HighlightedText` component, props `{ text: string; variant: "interactive" | "static"; records?: VocabRecord[]; ttsLanguage?: TtsLanguage | null; highlights?: string[] }`. Task 2 uses `variant="static"` with `highlights`; Task 3 uses `variant="interactive"` with `records`/`ttsLanguage`.

- [ ] **Step 1: Write the failing tests**

```tsx
// apps/web/src/components/shared/HighlightedText.test.tsx
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd apps/web && npx vitest run src/components/shared/HighlightedText.test.tsx`
Expected: FAIL — `Cannot find module './HighlightedText'` (file doesn't exist yet).

- [ ] **Step 3: Implement `HighlightedText`**

```tsx
// apps/web/src/components/shared/HighlightedText.tsx
"use client";

import { useState } from "react";
import type { VocabRecord } from "@/lib/vocabRecords";
import type { TtsLanguage } from "@/lib/pronunciation";
import { PronunciationButton } from "./PronunciationButton";

interface HighlightedTextProps {
  text: string;
  variant: "interactive" | "static";
  records?: VocabRecord[];
  ttsLanguage?: TtsLanguage | null;
  highlights?: string[];
}

interface Span {
  text: string;
  matchedWord: string | null;
}

// Ports word_radar_screen.dart's _HighlightedText matching algorithm exactly:
// at each step, scan every candidate word for its earliest occurrence in the
// remaining text, highlight whichever candidate's earliest occurrence comes
// first overall, then continue from the end of that match. No length-based
// tie-break, no overlapping highlights — matching Flutter's real behavior.
function splitIntoSpans(text: string, candidates: string[]): Span[] {
  const spans: Span[] = [];
  let remaining = text;
  const nonEmpty = candidates.filter((c) => c.length > 0);

  while (remaining.length > 0) {
    let earliestStart: number | null = null;
    let earliestWord: string | null = null;
    for (const word of nonEmpty) {
      const idx = remaining.toLowerCase().indexOf(word.toLowerCase());
      if (idx >= 0 && (earliestStart === null || idx < earliestStart)) {
        earliestStart = idx;
        earliestWord = word;
      }
    }
    if (earliestStart === null || earliestWord === null) {
      spans.push({ text: remaining, matchedWord: null });
      break;
    }
    if (earliestStart > 0) {
      spans.push({ text: remaining.slice(0, earliestStart), matchedWord: null });
    }
    const matchedText = remaining.slice(earliestStart, earliestStart + earliestWord.length);
    spans.push({ text: matchedText, matchedWord: earliestWord });
    remaining = remaining.slice(earliestStart + earliestWord.length);
  }
  return spans;
}

export function HighlightedText({ text, variant, records, ttsLanguage, highlights }: HighlightedTextProps) {
  const [openIndex, setOpenIndex] = useState<number | null>(null);

  const candidates = variant === "interactive" ? (records ?? []).map((r) => r.headword) : (highlights ?? []);

  if (candidates.length === 0 || text.length === 0) {
    return <p>{text}</p>;
  }

  const spans = splitIntoSpans(text, candidates);

  function findRecord(matchedWord: string): VocabRecord | undefined {
    return (records ?? []).find((r) => r.headword.toLowerCase() === matchedWord.toLowerCase());
  }

  return (
    <p>
      {spans.map((span, i) => {
        if (span.matchedWord === null) return <span key={i}>{span.text}</span>;

        if (variant === "static") {
          return (
            <mark key={i} className="known-highlight known-highlight-static">
              {span.text}
            </mark>
          );
        }

        const record = findRecord(span.matchedWord);
        const isOpen = openIndex === i;
        return (
          <span key={i} className="known-highlight-wrap">
            <button
              type="button"
              className="known-highlight known-highlight-interactive"
              onClick={() => setOpenIndex(isOpen ? null : i)}
            >
              {span.text}
            </button>
            {isOpen && record && (
              <span className="word-popover" role="tooltip">
                <span className="pop-head-row">
                  <span className="pop-headword">{record.headword}</span>
                  <PronunciationButton text={record.headword} language={ttsLanguage ?? null} tier="word" />
                </span>
                {record.ipa && <span className="pop-ipa">{record.ipa}</span>}
                <span className="pop-meaning">{record.meaning}</span>
                <span className="cefr-pill">{record.cefrLevel.toUpperCase()}</span>
              </span>
            )}
          </span>
        );
      })}
    </p>
  );
}
```

- [ ] **Step 4: Append highlight/popover CSS**

Append to `apps/web/src/styles/bloom.css`:

```css
.known-highlight {
  background: var(--sage-bg);
  color: var(--sage);
  font-weight: 700;
  border-radius: 4px;
  padding: 1px 3px;
}

.known-highlight-interactive {
  border: none;
  font: inherit;
  cursor: pointer;
  text-decoration: underline;
  text-decoration-style: dotted;
}

.known-highlight-wrap {
  position: relative;
  display: inline-block;
}

.word-popover {
  position: absolute;
  left: 50%;
  bottom: calc(100% + 8px);
  transform: translateX(-50%);
  z-index: 10;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 12px;
  padding: 12px 14px;
  width: 220px;
  display: flex;
  flex-direction: column;
  gap: 4px;
  text-align: left;
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.16);
  font-weight: 400;
}

.pop-head-row {
  display: flex;
  align-items: center;
  gap: 6px;
}

.pop-headword {
  font-weight: 700;
  font-size: 15px;
  color: var(--ink);
}

.pop-ipa {
  font-size: 12.5px;
  color: var(--ink-faint);
}

.pop-meaning {
  font-size: 13.5px;
  color: var(--ink-soft);
  line-height: 1.4;
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd apps/web && npx vitest run src/components/shared/HighlightedText.test.tsx`
Expected: PASS, 8/8.

- [ ] **Step 6: Run `tsc`**

Run: `cd apps/web && npx tsc --noEmit`
Expected: PASS, clean.

- [ ] **Step 7: Commit**

```bash
git add apps/web/src/components/shared/HighlightedText.tsx apps/web/src/components/shared/HighlightedText.test.tsx apps/web/src/styles/bloom.css
git commit -m "feat(web): add HighlightedText — clickable/static known-word highlighting"
```

---

## Task 2: `vocabSuggestions.ts` + `VocabSuggestionsSection` — optional translation

**Files:**
- Modify: `apps/web/src/lib/vocabSuggestions.ts`
- Modify: `apps/web/src/lib/vocabSuggestions.test.ts`
- Modify: `apps/web/src/components/shared/VocabSuggestionsSection.tsx`
- Modify: `apps/web/src/components/shared/VocabSuggestionsSection.test.tsx`
- Modify: `apps/web/src/styles/bloom.css` (append)

This task changes both files together, in one commit — `parseVocabSuggestions`'s return-type change and its one call site's update must land atomically so the repo compiles at every commit boundary (never split these across two tasks/commits).

**Interfaces:**
- Consumes: `parseLookupResult`, `WordPhraseResult` from `./lookup` (existing, unchanged); `HighlightedText` with `variant="static"` (Task 1).
- Produces: `buildVocabSuggestionsPrompt(text, targetLanguage, knownHeadwords, includeTranslation = false): string` (4th param **added**, existing 3-arg call sites unaffected). `VocabSuggestionsResult` interface `{ suggestions: WordPhraseResult[]; translation: string }` (**new export**). `parseVocabSuggestions(json): VocabSuggestionsResult` (**return type changed** from bare `WordPhraseResult[]` to this object). `VocabSuggestionsSection` gains `includeTranslation?: boolean` prop (default `false` — the 5 existing call sites, which don't pass it, are unaffected). Task 3 uses the component with `includeTranslation`.

### Part A — `vocabSuggestions.ts`

- [ ] **Step 1: Update the failing/changed tests**

Replace the `parseVocabSuggestions` describe block's first test in `apps/web/src/lib/vocabSuggestions.test.ts` (the `toEqual([...])` array assertion) with the new object shape:

```ts
// Replace the existing "parses a full WordPhraseResult per suggestion" test's
// assertion (same input `json`, same describe block) with:
    const result = parseVocabSuggestions(json);

    expect(result).toEqual({
      suggestions: [
        {
          kind: "wordPhrase",
          headword: "meticulous",
          inputType: "word",
          ipa: "/məˈtɪkjələs/",
          meaning: "tỉ mỉ",
          examples: ["She is meticulous."],
          definition: "showing great attention to detail",
          synonyms: ["thorough"],
          suggestedTopics: ["Academic"],
          cefrLevel: "c1",
        },
      ],
      translation: "",
    });
```

Also update every other existing `parseVocabSuggestions` assertion in that describe block (`"skips a suggestion item with no headword instead of throwing"` and any others) to wrap the expected array in `{ suggestions: [...], translation: "" }` the same way — read the file first to find every `parseVocabSuggestions(...)` call and its `.toEqual`/`.toHaveLength` assertion before editing, since the return shape change affects all of them.

Then append new test cases:

```ts
describe("buildVocabSuggestionsPrompt (includeTranslation)", () => {
  it("asks for a translation field first when includeTranslation is true", () => {
    const prompt = buildVocabSuggestionsPrompt("Some text.", "english", [], true);
    expect(prompt).toContain("translate the full text into Vietnamese");
    expect(prompt).toContain('"translation":"Vietnamese translation of the full text"');
  });

  it("omits any translation mention when includeTranslation is false or omitted", () => {
    const withoutFlag = buildVocabSuggestionsPrompt("Some text.", "english", []);
    const withFalse = buildVocabSuggestionsPrompt("Some text.", "english", [], false);
    for (const prompt of [withoutFlag, withFalse]) {
      expect(prompt).not.toContain("translate the full text");
      expect(prompt).not.toContain('"translation"');
    }
  });
});

describe("parseVocabSuggestions (translation)", () => {
  it("parses a translation field when present", () => {
    const result = parseVocabSuggestions({ translation: "Bản dịch.", suggestions: [] });
    expect(result.translation).toBe("Bản dịch.");
  });

  it("defaults translation to an empty string when absent", () => {
    const result = parseVocabSuggestions({ suggestions: [] });
    expect(result.translation).toBe("");
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd apps/web && npx vitest run src/lib/vocabSuggestions.test.ts`
Expected: FAIL — existing assertions expect a bare array, `includeTranslation`-related tests fail (prompt has no translation text yet; `result.translation` is `undefined`).

- [ ] **Step 3: Implement the changes**

In `apps/web/src/lib/vocabSuggestions.ts`, replace `buildVocabSuggestionsPrompt` and `parseVocabSuggestions` with:

```ts
export function buildVocabSuggestionsPrompt(
  text: string,
  targetLanguage: TargetLanguage,
  knownHeadwords: string[],
  includeTranslation: boolean = false
): string {
  const languageLabel = LANGUAGE_LABELS[targetLanguage];
  const knownClause =
    knownHeadwords.length === 0
      ? ""
      : ` Do NOT suggest any of these already-known words: ${knownHeadwords.join(", ")}.`;
  const task = includeTranslation
    ? "do two things. First, translate the full text into Vietnamese. Second, suggest"
    : "suggest";
  const translationField = includeTranslation
    ? '"translation":"Vietnamese translation of the full text",'
    : "";
  const translationReminder = includeTranslation
    ? ' Always provide the "translation" even when "suggestions" is empty.'
    : "";
  return (
    `You are a language learning assistant helping a Vietnamese speaker learn ${languageLabel}. ` +
    `Given this text: "${text}", ${task} up to 10 words or short phrases from the text that are ` +
    `worth learning.${knownClause} If nothing in the text is worth learning, use an empty ` +
    `"suggestions" array. Respond with JSON only (no markdown, no code fences): ` +
    `{${translationField}"suggestions":[{"headword":"exact word or phrase from the text","ipa":"IPA transcription",` +
    `"meaning":"Vietnamese definition","definition":"English definition",` +
    `"synonyms":["2-4 English synonyms, or empty array if none fit"],` +
    `"examples":["example 1","example 2"],` +
    `"suggestedTopics":["exactly one topic chosen from: Daily Life, Travel, Food & Drink, Business, ` +
    `Technology, Health, Education, Entertainment, Nature, Emotion, Academic, Idioms, Phrasal Verbs, ` +
    `Slang, Social/Casual, Sports, Art & Culture, Science, Law & Politics, Other"],` +
    `"cefrLevel":"a1, a2, b1, b2, c1, or c2"}]}.${translationReminder} ` +
    `Every suggestion's "suggestedTopics" array is REQUIRED and must contain exactly one topic from ` +
    `that list — never an empty array, even when generating many suggestions at once. ` +
    `Every "meaning" field must use only Vietnamese script — ` +
    `never Chinese, Japanese, or other non-Vietnamese characters.`
  );
}

export interface VocabSuggestionsResult {
  suggestions: WordPhraseResult[];
  translation: string;
}

export function parseVocabSuggestions(json: Record<string, unknown>): VocabSuggestionsResult {
  const rawSuggestions = Array.isArray(json.suggestions) ? json.suggestions : [];
  const suggestions: WordPhraseResult[] = [];
  for (const raw of rawSuggestions) {
    if (typeof raw !== "object" || raw === null) continue;
    const item = raw as Record<string, unknown>;
    if (typeof item.headword !== "string" || item.headword.length === 0) continue;
    const parsed = parseLookupResult(item, "word", item.headword);
    if (parsed.kind === "wordPhrase") suggestions.push(parsed);
  }
  return {
    suggestions,
    translation: typeof json.translation === "string" ? json.translation : "",
  };
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd apps/web && npx vitest run src/lib/vocabSuggestions.test.ts`
Expected: PASS, all tests green.

### Part B — `VocabSuggestionsSection.tsx`

Do not run `tsc` or commit between Part A and Part B — `VocabSuggestionsSection.tsx` still calls `parseVocabSuggestions` expecting the old array shape until Part B's Step 3 lands, so the repo does not compile in between. Continue straight on.

- [ ] **Step 5: Write the failing tests**

Append to `apps/web/src/components/shared/VocabSuggestionsSection.test.tsx`:

```tsx
describe("VocabSuggestionsSection (includeTranslation)", () => {
  it("requests and renders the translation above the suggestion list when includeTranslation is true", async () => {
    vi.mocked(generateContent).mockResolvedValue({
      text: JSON.stringify({
        translation: "Cô ấy rất tỉ mỉ.",
        suggestions: [{ headword: "meticulous", ipa: "/x/", meaning: "tỉ mỉ", cefrLevel: "c1" }],
      }),
    });

    render(
      <VocabSuggestionsSection
        text="She is meticulous."
        existingRecords={[]}
        topics={[]}
        includeTranslation
      />
    );

    expect(await screen.findByText("Cô ấy rất tỉ mỉ.")).toBeInTheDocument();
    expect(screen.getByText("meticulous")).toBeInTheDocument();
  });

  it("passes includeTranslation through to the prompt request", async () => {
    vi.mocked(generateContent).mockResolvedValue({
      text: JSON.stringify({ translation: "x", suggestions: [] }),
    });

    render(
      <VocabSuggestionsSection
        text="Some text."
        existingRecords={[]}
        topics={[]}
        includeTranslation
      />
    );

    await screen.findByText("x");
    const [[call]] = vi.mocked(generateContent).mock.calls;
    expect(call.prompt).toContain("translate the full text into Vietnamese");
  });

  it("renders no translation block when includeTranslation is false or omitted", async () => {
    vi.mocked(generateContent).mockResolvedValue({
      text: JSON.stringify({
        suggestions: [{ headword: "meticulous", ipa: "/x/", meaning: "tỉ mỉ", cefrLevel: "c1" }],
      }),
    });

    render(<VocabSuggestionsSection text="She is meticulous." existingRecords={[]} topics={[]} />);

    await screen.findByText("meticulous");
    expect(screen.queryByText(/Bản dịch/)).not.toBeInTheDocument();
  });
});
```

- [ ] **Step 6: Run tests to verify they fail**

Run: `cd apps/web && npx vitest run src/components/shared/VocabSuggestionsSection.test.tsx`
Expected: FAIL — component doesn't accept `includeTranslation` yet, and this file's existing tests also currently fail to compile against Part A's new `parseVocabSuggestions` return type (expected at this exact stage of the task, not before).

- [ ] **Step 7: Implement the changes**

In `apps/web/src/components/shared/VocabSuggestionsSection.tsx`:

```tsx
// Add to the import block:
import { HighlightedText } from "./HighlightedText";

// Change the props interface:
interface VocabSuggestionsSectionProps {
  text: string;
  existingRecords: VocabRecord[];
  topics: Topic[];
  includeTranslation?: boolean;
}

export function VocabSuggestionsSection({
  text,
  existingRecords,
  topics,
  includeTranslation = false,
}: VocabSuggestionsSectionProps) {
  // ... existing hook declarations unchanged, plus:
  const [translation, setTranslation] = useState("");

  // ... unchanged down to the load() function body, then replace:
  //   const prompt = buildVocabSuggestionsPrompt(text, settings!.targetLanguage, knownHeadwords);
  // with:
        const prompt = buildVocabSuggestionsPrompt(
          text,
          settings!.targetLanguage,
          knownHeadwords,
          includeTranslation
        );
  // ... and replace:
  //   const json = parseAiJsonObject(response.text);
  //   setSuggestions(parseVocabSuggestions(json));
  // with:
        const json = parseAiJsonObject(response.text);
        const parsed = parseVocabSuggestions(json);
        setSuggestions(parsed.suggestions);
        setTranslation(parsed.translation);
  // ... rest of load()/handleSaveOne/handleSaveAll unchanged.

  // In the JSX, immediately inside the top-level `<div className="suggestions-section">`,
  // before the existing `<div className="suggestions-header">`, add:
  return (
    <div className="suggestions-section">
      {includeTranslation && translation && (
        <div className="translation-block">
          <span className="suggestions-title">Bản dịch</span>
          <HighlightedText
            text={translation}
            variant="static"
            highlights={existingRecords.map((r) => r.meaning).filter((m) => m.length > 0)}
          />
        </div>
      )}
      <div className="suggestions-header">
        {/* ... unchanged from here down ... */}
```

The rest of the component (header, bulk-save button, error/loading states, suggestion cards, `EditVocabModal`) is unchanged — only the additions above.

- [ ] **Step 8: Append translation-block CSS**

Append to `apps/web/src/styles/bloom.css`:

```css
.translation-block {
  margin-bottom: 20px;
}

.translation-block .suggestions-title {
  display: block;
  margin-bottom: 8px;
}
```

- [ ] **Step 9: Run tests to verify they pass**

Run: `cd apps/web && npx vitest run src/lib/vocabSuggestions.test.ts src/components/shared/VocabSuggestionsSection.test.tsx`
Expected: PASS — both files, including the 5 pre-existing `VocabSuggestionsSection` describe blocks (unaffected by the new prop) and all new `includeTranslation` cases.

- [ ] **Step 10: Run `tsc` to confirm the repo compiles clean**

Run: `cd apps/web && npx tsc --noEmit`
Expected: PASS, clean.

- [ ] **Step 11: Run the 5 existing call sites' test files to confirm zero regression**

Run: `cd apps/web && npx vitest run "src/app/(app)/reading/bilingual/page.test.tsx" "src/app/(app)/reading/part5/page.test.tsx" "src/app/(app)/reading/part6/page.test.tsx" "src/app/(app)/reading/part7/page.test.tsx" "src/app/(app)/listening/comprehension/page.test.tsx"`
Expected: PASS, all unchanged.

- [ ] **Step 12: Commit**

```bash
git add apps/web/src/lib/vocabSuggestions.ts apps/web/src/lib/vocabSuggestions.test.ts apps/web/src/components/shared/VocabSuggestionsSection.tsx apps/web/src/components/shared/VocabSuggestionsSection.test.tsx apps/web/src/styles/bloom.css
git commit -m "feat(web): add includeTranslation to vocabSuggestions and VocabSuggestionsSection"
```

---

## Task 3: `/reading/word-radar` page

**Files:**
- Create: `apps/web/src/app/(app)/reading/word-radar/page.tsx`
- Create: `apps/web/src/app/(app)/reading/word-radar/page.test.tsx`
- Modify: `apps/web/src/styles/bloom.css` (append)

**Interfaces:**
- Consumes: `HighlightedText` (`variant="interactive"`, Task 1); `VocabSuggestionsSection` (`includeTranslation`, Task 2); `getVocabRecords(uid): Promise<VocabRecord[]>`, `VocabRecord` from `@/lib/vocabRecords` (existing); `useAuthUser()` from `@/lib/useAuthUser` (existing, `{ user, loading }`); `useSettingsContext()` from `@/lib/SettingsContext` (existing, `{ settings, loading }`, `settings.targetLanguage`, `settings.providers[settings.activeProvider].apiKeyCiphertext`); `ttsLanguageCode(targetLanguage)` from `@/lib/pronunciation` (existing); `SignInButton` from `@/components/SignInButton` (existing).
- Produces: the `/reading/word-radar` route. Task 4 links to it.

- [ ] **Step 1: Write the failing tests**

```tsx
// apps/web/src/app/(app)/reading/word-radar/page.test.tsx
import { beforeEach, describe, expect, it, vi } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import WordRadarPage from "./page";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettingsContext } from "@/lib/SettingsContext";
import { getVocabRecords, type VocabRecord } from "@/lib/vocabRecords";
import { DEFAULT_SETTINGS, type UserSettings } from "@/lib/settings";

vi.mock("@/lib/useAuthUser", () => ({ useAuthUser: vi.fn() }));
vi.mock("@/lib/SettingsContext", () => ({ useSettingsContext: vi.fn() }));
vi.mock("@/lib/vocabRecords", () => ({ getVocabRecords: vi.fn() }));
vi.mock("@/components/SignInButton", () => ({
  SignInButton: () => <button>Đăng nhập với Google</button>,
}));
vi.mock("@/components/shared/VocabSuggestionsSection", () => ({
  VocabSuggestionsSection: () => <div data-testid="suggestions-section" />,
}));

const SETTINGS_NO_KEY: UserSettings = DEFAULT_SETTINGS;
const SETTINGS_WITH_KEY: UserSettings = {
  ...DEFAULT_SETTINGS,
  activeProvider: "gemini",
  providers: {
    ...DEFAULT_SETTINGS.providers,
    gemini: { model: "gemini-2.5-flash", apiKeyCiphertext: "cipher-abc" },
  },
};

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

function mockSignedIn(settings: UserSettings = SETTINGS_WITH_KEY) {
  vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" }, loading: false } as never);
  vi.mocked(useSettingsContext).mockReturnValue({
    settings,
    loading: false,
    error: null,
    save: vi.fn(),
  });
}

beforeEach(() => vi.clearAllMocks());

describe("WordRadarPage (auth)", () => {
  it("prompts sign-in when logged out", () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: null, loading: false } as never);
    render(<WordRadarPage />);
    expect(screen.getByText("Đăng nhập với Google")).toBeInTheDocument();
  });
});

describe("WordRadarPage (scan)", () => {
  it("disables Quét until text is entered, and highlights known words after scanning", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([
      makeRecord({ id: "r1", headword: "increase", targetLanguage: "english" }),
    ]);

    render(<WordRadarPage />);
    const scanBtn = await screen.findByRole("button", { name: "Quét" });
    expect(scanBtn).toBeDisabled();

    const textarea = screen.getByPlaceholderText("Dán văn bản vào đây…");
    fireEvent.change(textarea, { target: { value: "A big increase happened." } });
    expect(scanBtn).not.toBeDisabled();

    fireEvent.click(scanBtn);
    expect(screen.getByRole("button", { name: "increase" })).toBeInTheDocument();
  });

  it("excludes known-word records from a different target language", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([
      makeRecord({ id: "r1", headword: "increase", targetLanguage: "chinese" }),
    ]);

    render(<WordRadarPage />);
    const textarea = await screen.findByPlaceholderText("Dán văn bản vào đây…");
    fireEvent.change(textarea, { target: { value: "A big increase happened." } });
    fireEvent.click(screen.getByRole("button", { name: "Quét" }));

    expect(screen.queryByRole("button", { name: "increase" })).not.toBeInTheDocument();
  });

  it("enforces a 3000-character max on the textarea", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([]);
    render(<WordRadarPage />);
    const textarea = await screen.findByPlaceholderText("Dán văn bản vào đây…");
    expect(textarea).toHaveAttribute("maxLength", "3000");
  });

  it("shows the suggestions section (AI on) once scanned", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([]);
    render(<WordRadarPage />);
    const textarea = await screen.findByPlaceholderText("Dán văn bản vào đây…");
    fireEvent.change(textarea, { target: { value: "Some text." } });
    fireEvent.click(screen.getByRole("button", { name: "Quét" }));
    expect(screen.getByTestId("suggestions-section")).toBeInTheDocument();
  });

  it("shows the AI-disabled hint instead of the suggestions section when AI is off", async () => {
    mockSignedIn(SETTINGS_NO_KEY);
    vi.mocked(getVocabRecords).mockResolvedValue([]);
    render(<WordRadarPage />);
    const textarea = await screen.findByPlaceholderText("Dán văn bản vào đây…");
    fireEvent.change(textarea, { target: { value: "Some text." } });
    fireEvent.click(screen.getByRole("button", { name: "Quét" }));
    expect(screen.getByText("Bật AI trong Cài đặt để nhận gợi ý từ mới.")).toBeInTheDocument();
    expect(screen.queryByTestId("suggestions-section")).not.toBeInTheDocument();
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd apps/web && npx vitest run "src/app/(app)/reading/word-radar/page.test.tsx"`
Expected: FAIL — `Cannot find module './page'` (route doesn't exist yet).

- [ ] **Step 3: Implement the page**

```tsx
// apps/web/src/app/(app)/reading/word-radar/page.tsx
"use client";

import { useEffect, useState } from "react";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettingsContext } from "@/lib/SettingsContext";
import { SignInButton } from "@/components/SignInButton";
import { HighlightedText } from "@/components/shared/HighlightedText";
import { VocabSuggestionsSection } from "@/components/shared/VocabSuggestionsSection";
import { getVocabRecords, type VocabRecord } from "@/lib/vocabRecords";
import { getTopics, type Topic } from "@/lib/topics";
import { ttsLanguageCode } from "@/lib/pronunciation";

const MAX_INPUT_LENGTH = 3000;

export default function WordRadarPage() {
  const { user, loading: authLoading } = useAuthUser();
  const { settings, loading: settingsLoading } = useSettingsContext();

  const [records, setRecords] = useState<VocabRecord[]>([]);
  const [topics, setTopics] = useState<Topic[]>([]);
  const [text, setText] = useState("");
  const [scannedText, setScannedText] = useState<string | null>(null);

  useEffect(() => {
    if (!user) return;
    Promise.all([getVocabRecords(user.uid), getTopics(user.uid)])
      .then(([r, t]) => {
        setRecords(r);
        setTopics(t);
      })
      .catch(() => {});
  }, [user]);

  if (authLoading) return <p>Đang tải…</p>;

  if (!user) {
    return (
      <div>
        <h2 className="scr-title">Quét từ vựng</h2>
        <p className="scr-sub">Đăng nhập để quét văn bản.</p>
        <SignInButton />
      </div>
    );
  }

  if (settingsLoading || !settings) return <p>Đang tải…</p>;

  const knownRecords = records.filter((r) => r.targetLanguage === settings.targetLanguage);
  const activeConfig = settings.providers[settings.activeProvider];
  const aiEnabled = Boolean(activeConfig.apiKeyCiphertext);
  const ttsLang = ttsLanguageCode(settings.targetLanguage);

  return (
    <div>
      <h2 className="scr-title">Quét từ vựng</h2>
      <p className="scr-sub">
        Dán bất kỳ văn bản nào — highlight ngay từ bạn đã học, và (nếu bật AI) nhận bản dịch cùng gợi
        ý từ mới.
      </p>

      <div className="word-radar-input-card">
        <textarea
          className="word-radar-textarea"
          value={text}
          maxLength={MAX_INPUT_LENGTH}
          placeholder="Dán văn bản vào đây…"
          onChange={(e) => setText(e.target.value)}
        />
        <div className="word-radar-input-footer">
          <span className="word-radar-char-count">
            {text.length} / {MAX_INPUT_LENGTH}
          </span>
          <button
            type="button"
            className="btn-primary"
            disabled={text.length === 0}
            onClick={() => setScannedText(text)}
          >
            Quét
          </button>
        </div>
      </div>

      {scannedText !== null && (
        <>
          <div className="word-radar-result-card">
            <p className="suggestions-title">Văn bản</p>
            <HighlightedText
              text={scannedText}
              variant="interactive"
              records={knownRecords}
              ttsLanguage={ttsLang}
            />
          </div>

          {aiEnabled ? (
            <VocabSuggestionsSection
              text={scannedText}
              existingRecords={knownRecords}
              topics={topics}
              includeTranslation
            />
          ) : (
            <p className="word-radar-ai-hint">Bật AI trong Cài đặt để nhận gợi ý từ mới.</p>
          )}
        </>
      )}
    </div>
  );
}
```

- [ ] **Step 4: Append page-specific CSS**

Append to `apps/web/src/styles/bloom.css`:

```css
.word-radar-input-card,
.word-radar-result-card {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 16px;
  padding: 20px;
  margin-bottom: 20px;
}

.word-radar-textarea {
  width: 100%;
  min-height: 140px;
  resize: vertical;
  background: var(--surface-2);
  border: 1px solid var(--border);
  border-radius: 12px;
  padding: 12px 14px;
  font-family: inherit;
  font-size: 16px;
  color: var(--ink);
  line-height: 1.55;
}

.word-radar-input-footer {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-top: 10px;
}

.word-radar-char-count {
  font-size: 13px;
  color: var(--ink-faint);
  font-variant-numeric: tabular-nums;
}

.word-radar-ai-hint {
  background: var(--amber-bg);
  color: var(--amber);
  border-radius: 12px;
  padding: 12px 14px;
  font-size: 15px;
  font-weight: 600;
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd apps/web && npx vitest run "src/app/(app)/reading/word-radar/page.test.tsx"`
Expected: PASS, 7/7.

- [ ] **Step 6: Run `tsc`**

Run: `cd apps/web && npx tsc --noEmit`
Expected: PASS, clean.

- [ ] **Step 7: Commit**

```bash
git add "apps/web/src/app/(app)/reading/word-radar/page.tsx" "apps/web/src/app/(app)/reading/word-radar/page.test.tsx" apps/web/src/styles/bloom.css
git commit -m "feat(web): add /reading/word-radar page"
```

---

## Task 4: Reading hub — 5th card

**Files:**
- Modify: `apps/web/src/app/(app)/reading/page.tsx`
- Modify: `apps/web/src/app/(app)/reading/page.test.tsx`

**Interfaces:**
- Consumes: `/reading/word-radar` route (Task 3). `useRouter` from `next/navigation` (existing, already imported in this file as `router`).
- Produces: nothing new consumed by later tasks — this is the last task in the plan.

- [ ] **Step 1: Write the failing test**

Append to `apps/web/src/app/(app)/reading/page.test.tsx`:

```tsx
describe("ReadingHubPage (Word Radar card)", () => {
  it("navigates straight to /reading/word-radar without touching the mode/filter state", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([]);

    render(<ReadingHubPage />);
    const card = await screen.findByRole("button", { name: /Quét từ vựng/ });
    fireEvent.click(card);

    expect(pushMock).toHaveBeenCalledWith("/reading/word-radar");
    expect(screen.queryByRole("button", { name: "Tạo bài luyện" })).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "🔀 Lấy bài có sẵn" })).not.toBeInTheDocument();
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/web && npx vitest run "src/app/(app)/reading/page.test.tsx"`
Expected: FAIL — no "Quét từ vựng" button exists yet.

- [ ] **Step 3: Add the card**

In `apps/web/src/app/(app)/reading/page.tsx`, inside the `<div className="reading-hub-cards">` block, immediately after the existing Part 7 card's closing `</button>`, add:

```tsx
        <button
          type="button"
          className="reading-hub-card"
          onClick={() => router.push("/reading/word-radar")}
        >
          <span className="reading-hub-card-title">🔎 Quét từ vựng</span>
          <span className="reading-hub-card-desc">
            Dán văn bản bất kỳ, tự nhận từ đã học và gợi ý từ mới.
          </span>
        </button>
```

Note the class is `reading-hub-card` (not `reading-hub-card-toggle`) — this card does not join the `mode` toggle group, so it gets no `active`-state styling and no `onClick`-driven `setMode` call.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/web && npx vitest run "src/app/(app)/reading/page.test.tsx"`
Expected: PASS, including all pre-existing tests in this file (unaffected).

- [ ] **Step 5: Run `tsc` and the full web test suite**

Run: `cd apps/web && npx tsc --noEmit && npx vitest run`
Expected: both clean — `tsc` no output, full suite all green. If any unrelated files fail, re-run just those files in isolation before concluding it's a real regression (this repo has known Windows/jsdom full-suite flakiness).

- [ ] **Step 6: Commit**

```bash
git add "apps/web/src/app/(app)/reading/page.tsx" "apps/web/src/app/(app)/reading/page.test.tsx"
git commit -m "feat(web): add Quét từ vựng card to the Reading hub"
```
