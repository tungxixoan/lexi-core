# React Web Plan 3 / Phase C (Part 1) — Đọc & gõ (Reading & Typing) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the Next.js web app a real `/reading` hub and its first mode, `/reading/bilingual` — an AI-generated bilingual passage the user types out sentence-by-sentence, sourced from their own Vocab Bank, with live color-coded typing feedback and a full result screen (accuracy/speed/score, words used, AI vocab suggestions with tap-to-save).

**Architecture:** Setup screen selects a due-first word pool (reusing `selectSessionWords`) and generates a passage via one `generateContent` call. The session screen renders the passage with the current sentence's characters colored live against a plain `<input>` — no overlay, no `contentEditable` — confirmed via live visual-companion iteration to avoid two different fragility classes (Flutter's transparent-overlay approach, and a `contentEditable` caret bug reproduced during design). The result screen computes accuracy/speed/score from data already collected during the session (no extra Firestore reads) and offers AI-suggested new vocabulary — one `generateContent` call returns full dictionary entries per suggestion (not bare words needing a second lookup), reusing the existing `EditVocabModal` "create" mode save flow unchanged.

**Tech Stack:** Next.js 16 (App Router) on `apps/web/`, React 19, Firebase JS SDK v12 (`firebase/firestore`, `firebase/functions`), Vitest + React Testing Library + jsdom.

## Global Constraints

- All user-facing text is Vietnamese, matching every existing screen.
- Import alias `@/` maps to `apps/web/src/`.
- Every new/changed file gets a colocated Vitest test, following the existing mock style (`vi.mock("firebase/firestore", ...)`, `vi.mock("./firebase", () => ({ getFirebaseDb: vi.fn(() => "mock-db") }))`).
- Đọc & gõ makes **zero** writes to any `vocab_records` SM-2 field — it only *reads* headword/meaning/examples to build prompts.
- No streak/Firestore write for the session result — the result data is shaped as `{ vocabIds: string[], accuracy: number, completedAt: string }` for a future hook, per spec §3.3, but nothing is written anywhere in this plan.
- The "Tạo bài luyện" button (or equivalent) must not render at all when fewer than 5 Vocab Bank words match the current filters — ported from Flutter's `_minVocabWords = 5` exactly. Show `"Hãy lưu ít nhất 5 từ khớp với bộ lọc trên vào Ngân hàng từ vựng. Hiện có N từ."` instead.
- The vocab-suggestions AI call returns full dictionary info (`WordPhraseResult` shape) per suggested word in one call — never a bare word list needing a second lookup call per word.
- Verify each task with `npm --prefix apps/web test` (full suite) and finish the plan with `npm --prefix apps/web run typecheck` and `npm --prefix apps/web run build`.

---

## Task 1: Reading passage domain logic (prompt + parser)

**Files:**
- Create: `apps/web/src/lib/readingPassage.ts`
- Create: `apps/web/src/lib/readingPassage.test.ts`

**Interfaces:**
- Produces: `interface BilingualSentence { target: string; vietnamese: string; vocabWords: string[] }`, `interface ReadingPassage { sentences: BilingualSentence[]; vocabIds: string[] }`, `buildReadingPassagePrompt(headwords: string[], targetLanguage: TargetLanguage): string`, `parseReadingPassage(json: Record<string, unknown>, vocabRecords: VocabRecord[]): ReadingPassage`. Used by Task 8 (setup phase).
- Consumes: `TargetLanguage`, `LANGUAGE_LABELS` (`@/lib/languages`, already exists), `VocabRecord` (`@/lib/vocabRecords`, already exists — only `id`/`headword` fields are read).

Pure functions — no Firestore, no network, no React.

- [ ] **Step 1: Write the failing test**

Create `apps/web/src/lib/readingPassage.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import { buildReadingPassagePrompt, parseReadingPassage } from "./readingPassage";
import type { VocabRecord } from "./vocabRecords";

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

describe("buildReadingPassagePrompt", () => {
  it("includes every headword, the target language label, and asks for JSON only", () => {
    const prompt = buildReadingPassagePrompt(["meticulous", "ephemeral"], "english");
    expect(prompt).toContain("meticulous");
    expect(prompt).toContain("ephemeral");
    expect(prompt).toContain("English");
    expect(prompt).toContain("JSON only");
    expect(prompt).toContain('"sentences"');
  });

  it("uses the target language's own label, not always English", () => {
    const prompt = buildReadingPassagePrompt(["안녕"], "korean");
    expect(prompt).toContain("한국어");
  });

  it("requires Vietnamese-script-only translations", () => {
    const prompt = buildReadingPassagePrompt(["word"], "english");
    expect(prompt).toContain("Vietnamese script");
  });
});

describe("parseReadingPassage", () => {
  it("parses sentences and resolves vocabWords to vocab record ids via headword match", () => {
    const records = [
      makeRecord({ id: "id-1", headword: "meticulous" }),
      makeRecord({ id: "id-2", headword: "ephemeral" }),
    ];
    const json = {
      sentences: [
        { target: "She is meticulous.", vietnamese: "Cô ấy tỉ mỉ.", vocabWords: ["meticulous"] },
        {
          target: "Beauty is ephemeral.",
          vietnamese: "Vẻ đẹp phù du.",
          vocabWords: ["ephemeral"],
        },
      ],
    };

    const result = parseReadingPassage(json, records);

    expect(result.sentences).toEqual([
      { target: "She is meticulous.", vietnamese: "Cô ấy tỉ mỉ.", vocabWords: ["meticulous"] },
      { target: "Beauty is ephemeral.", vietnamese: "Vẻ đẹp phù du.", vocabWords: ["ephemeral"] },
    ]);
    expect(result.vocabIds.sort()).toEqual(["id-1", "id-2"]);
  });

  it("deduplicates vocabIds when the same word appears in multiple sentences", () => {
    const records = [makeRecord({ id: "id-1", headword: "meticulous" })];
    const json = {
      sentences: [
        { target: "She is meticulous.", vietnamese: "Cô ấy tỉ mỉ.", vocabWords: ["meticulous"] },
        {
          target: "He praised her meticulous work.",
          vietnamese: "Anh khen công việc tỉ mỉ của cô.",
          vocabWords: ["meticulous"],
        },
      ],
    };

    const result = parseReadingPassage(json, records);

    expect(result.vocabIds).toEqual(["id-1"]);
  });

  it("ignores a vocabWord that doesn't match any given record's headword (case-insensitive match)", () => {
    const records = [makeRecord({ id: "id-1", headword: "Meticulous" })];
    const json = {
      sentences: [
        {
          target: "She is meticulous but not punctual.",
          vietnamese: "Cô ấy tỉ mỉ nhưng không đúng giờ.",
          vocabWords: ["meticulous", "punctual"],
        },
      ],
    };

    const result = parseReadingPassage(json, records);

    expect(result.vocabIds).toEqual(["id-1"]);
    expect(result.sentences[0].vocabWords).toEqual(["meticulous", "punctual"]);
  });

  it("falls back to empty sentences and vocabIds when the AI response is missing fields", () => {
    const result = parseReadingPassage({}, []);
    expect(result).toEqual({ sentences: [], vocabIds: [] });
  });

  it("tolerates a sentence with missing vietnamese/vocabWords fields", () => {
    const result = parseReadingPassage(
      { sentences: [{ target: "Hello." }] },
      []
    );
    expect(result.sentences).toEqual([{ target: "Hello.", vietnamese: "", vocabWords: [] }]);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm --prefix apps/web test -- readingPassage`
Expected: FAIL — `apps/web/src/lib/readingPassage.ts` does not exist yet.

- [ ] **Step 3: Implement**

Create `apps/web/src/lib/readingPassage.ts`:

```ts
import { LANGUAGE_LABELS, type TargetLanguage } from "./languages";
import type { VocabRecord } from "./vocabRecords";

export interface BilingualSentence {
  target: string;
  vietnamese: string;
  vocabWords: string[];
}

export interface ReadingPassage {
  sentences: BilingualSentence[];
  vocabIds: string[];
}

// Ports lib/features/reading/data/sources/reading_passage_source.dart's
// prompt: ~0.75 sentences per headword, clamped 6-12, one coherent
// narrative using as many given headwords as possible.
export function buildReadingPassagePrompt(headwords: string[], targetLanguage: TargetLanguage): string {
  const languageLabel = LANGUAGE_LABELS[targetLanguage];
  const sentenceCount = Math.min(12, Math.max(6, Math.ceil(headwords.length * 0.75)));
  return (
    `You are a language learning assistant helping a Vietnamese speaker learn ${languageLabel}. ` +
    `Write one coherent short story in ${languageLabel} of about ${sentenceCount} sentences, ` +
    `using as many of these words as possible, naturally: ${headwords.join(", ")}. ` +
    `Add a few other level-appropriate words if needed to make it flow. ` +
    `Respond with JSON only (no markdown, no code fences): ` +
    `{"sentences":[{"target":"sentence in ${languageLabel}",` +
    `"vietnamese":"Vietnamese translation of that sentence",` +
    `"vocabWords":["which of the given words appear in this sentence, exactly as given"]}]} ` +
    `Every "vietnamese" field must use only Vietnamese script — ` +
    `never Chinese, Japanese, or other non-Vietnamese characters.`
  );
}

interface RawSentence {
  target?: unknown;
  vietnamese?: unknown;
  vocabWords?: unknown;
}

export function parseReadingPassage(
  json: Record<string, unknown>,
  vocabRecords: VocabRecord[]
): ReadingPassage {
  const rawSentences = Array.isArray(json.sentences) ? (json.sentences as RawSentence[]) : [];
  const headwordToId = new Map(vocabRecords.map((r) => [r.headword.toLowerCase(), r.id]));

  const sentences: BilingualSentence[] = rawSentences.map((raw) => ({
    target: typeof raw.target === "string" ? raw.target : "",
    vietnamese: typeof raw.vietnamese === "string" ? raw.vietnamese : "",
    vocabWords: Array.isArray(raw.vocabWords) ? raw.vocabWords.map(String) : [],
  }));

  const vocabIds = new Set<string>();
  for (const sentence of sentences) {
    for (const word of sentence.vocabWords) {
      const id = headwordToId.get(word.toLowerCase());
      if (id) vocabIds.add(id);
    }
  }

  return { sentences, vocabIds: [...vocabIds] };
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm --prefix apps/web test -- readingPassage`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/web/src/lib/readingPassage.ts apps/web/src/lib/readingPassage.test.ts
git commit -m "feat(web): add reading passage prompt builder + parser for Đọc & gõ"
```

---

## Task 2: Reading scoring logic

**Files:**
- Create: `apps/web/src/lib/readingScoring.ts`
- Create: `apps/web/src/lib/readingScoring.test.ts`

**Interfaces:**
- Produces: `interface SentenceStats { correctChars: number; totalChars: number; deletedChars: number; durationMs: number }`, `computeSentenceStats(target: string, typed: string, deletedChars: number, durationMs: number): SentenceStats`, `interface ReadingResultStats { overallAccuracy: number; deletionRatio: number; finalScore: number; wpm: number }`, `aggregateSentenceStats(stats: SentenceStats[]): ReadingResultStats`. Used by Task 9 (session phase, per-sentence) and Task 10 (result phase, aggregate).
- Consumes: nothing — pure functions, no imports beyond the language built-ins.

Ports `reading_practice_provider.dart`'s scoring exactly: `deletedChars` is tracked by the caller (incremented whenever the typed value gets shorter than before — this file only consumes the final count per sentence, it doesn't track keystrokes itself), `finalScore = clamp(overallAccuracy − 0.5 × deletionRatio, 0, 1)`, `wpm = (totalChars / 5) / minutes` (standard "5 chars = 1 word" convention, counting the target length actually completed, not raw keystrokes).

- [ ] **Step 1: Write the failing test**

Create `apps/web/src/lib/readingScoring.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import { computeSentenceStats, aggregateSentenceStats } from "./readingScoring";

describe("computeSentenceStats", () => {
  it("counts every character as correct when typed exactly matches target", () => {
    const stats = computeSentenceStats("Hello world.", "Hello world.", 0, 5000);
    expect(stats).toEqual({ correctChars: 12, totalChars: 12, deletedChars: 0, durationMs: 5000 });
  });

  it("counts only index-wise matching characters as correct when there's a mistake", () => {
    // "Hxllo world." vs "Hello world." — differs only at index 1
    const stats = computeSentenceStats("Hello world.", "Hxllo world.", 0, 5000);
    expect(stats.correctChars).toBe(11);
    expect(stats.totalChars).toBe(12);
  });

  it("passes through the caller-tracked deletedChars and durationMs unchanged", () => {
    const stats = computeSentenceStats("Hi.", "Hi.", 4, 9000);
    expect(stats.deletedChars).toBe(4);
    expect(stats.durationMs).toBe(9000);
  });
});

describe("aggregateSentenceStats", () => {
  it("computes 100% accuracy and finalScore for perfect typing with no deletions", () => {
    const result = aggregateSentenceStats([
      { correctChars: 12, totalChars: 12, deletedChars: 0, durationMs: 6000 },
    ]);
    expect(result.overallAccuracy).toBe(1);
    expect(result.deletionRatio).toBe(0);
    expect(result.finalScore).toBe(1);
  });

  it("computes wpm from total chars typed (5 chars = 1 word) and total duration", () => {
    // 60 chars / 5 = 12 words, over 60000ms = 1 minute -> 12 wpm
    const result = aggregateSentenceStats([
      { correctChars: 60, totalChars: 60, deletedChars: 0, durationMs: 60000 },
    ]);
    expect(result.wpm).toBe(12);
  });

  it("aggregates correctChars/totalChars/deletedChars/durationMs across multiple sentences", () => {
    const result = aggregateSentenceStats([
      { correctChars: 10, totalChars: 10, deletedChars: 0, durationMs: 5000 },
      { correctChars: 8, totalChars: 10, deletedChars: 2, durationMs: 5000 },
    ]);
    expect(result.overallAccuracy).toBe(0.9); // 18/20
  });

  it("applies the deletion penalty: finalScore = accuracy - 0.5 * deletionRatio, clamped at 0", () => {
    // accuracy = 1 (typed correctly in the end), deletionRatio = 1 (deleted chars == total chars)
    const result = aggregateSentenceStats([
      { correctChars: 10, totalChars: 10, deletedChars: 10, durationMs: 5000 },
    ]);
    expect(result.overallAccuracy).toBe(1);
    expect(result.deletionRatio).toBe(1);
    expect(result.finalScore).toBe(0.5);
  });

  it("clamps finalScore to a minimum of 0 when the deletion penalty would push it negative", () => {
    const result = aggregateSentenceStats([
      { correctChars: 2, totalChars: 10, deletedChars: 30, durationMs: 5000 },
    ]);
    expect(result.finalScore).toBe(0);
  });

  it("returns all-zero stats for an empty sentence list, with no division by zero", () => {
    const result = aggregateSentenceStats([]);
    expect(result).toEqual({ overallAccuracy: 0, deletionRatio: 0, finalScore: 0, wpm: 0 });
  });

  it("returns wpm 0 when total duration is 0, with no division by zero", () => {
    const result = aggregateSentenceStats([
      { correctChars: 10, totalChars: 10, deletedChars: 0, durationMs: 0 },
    ]);
    expect(result.wpm).toBe(0);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm --prefix apps/web test -- readingScoring`
Expected: FAIL — `apps/web/src/lib/readingScoring.ts` does not exist yet.

- [ ] **Step 3: Implement**

Create `apps/web/src/lib/readingScoring.ts`:

```ts
export interface SentenceStats {
  correctChars: number;
  totalChars: number;
  deletedChars: number;
  durationMs: number;
}

// The caller tracks deletedChars itself: increment it whenever the typed
// value's length shrinks compared to the previous value (covers both a
// single backspace and a select-all-and-retype). This function only scores
// the final state of one completed sentence.
export function computeSentenceStats(
  target: string,
  typed: string,
  deletedChars: number,
  durationMs: number
): SentenceStats {
  let correctChars = 0;
  for (let i = 0; i < typed.length; i++) {
    if (typed[i] === target[i]) correctChars++;
  }
  return { correctChars, totalChars: target.length, deletedChars, durationMs };
}

export interface ReadingResultStats {
  overallAccuracy: number;
  deletionRatio: number;
  finalScore: number;
  wpm: number;
}

const DELETION_PENALTY_WEIGHT = 0.5;

export function aggregateSentenceStats(stats: SentenceStats[]): ReadingResultStats {
  const totalCorrect = stats.reduce((sum, s) => sum + s.correctChars, 0);
  const totalChars = stats.reduce((sum, s) => sum + s.totalChars, 0);
  const totalDeleted = stats.reduce((sum, s) => sum + s.deletedChars, 0);
  const totalDurationMs = stats.reduce((sum, s) => sum + s.durationMs, 0);

  const overallAccuracy = totalChars === 0 ? 0 : totalCorrect / totalChars;
  const deletionRatio = totalChars === 0 ? 0 : totalDeleted / totalChars;
  const finalScore = Math.min(1, Math.max(0, overallAccuracy - DELETION_PENALTY_WEIGHT * deletionRatio));
  const minutes = totalDurationMs / 60000;
  const wpm = minutes === 0 ? 0 : totalChars / 5 / minutes;

  return { overallAccuracy, deletionRatio, finalScore, wpm };
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm --prefix apps/web test -- readingScoring`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/web/src/lib/readingScoring.ts apps/web/src/lib/readingScoring.test.ts
git commit -m "feat(web): add reading session scoring (accuracy, deletion penalty, wpm)"
```

---

## Task 3: Vocab suggestions domain logic

**Files:**
- Create: `apps/web/src/lib/vocabSuggestions.ts`
- Create: `apps/web/src/lib/vocabSuggestions.test.ts`

**Interfaces:**
- Produces: `findKnownHeadwords(text: string, records: VocabRecord[]): string[]`, `buildVocabSuggestionsPrompt(text: string, targetLanguage: TargetLanguage, knownHeadwords: string[]): string`, `parseVocabSuggestions(json: Record<string, unknown>): WordPhraseResult[]`. Used by Task 6 (`VocabSuggestionsSection`).
- Consumes: `TargetLanguage`, `LANGUAGE_LABELS` (`@/lib/languages`), `WordPhraseResult`, `parseLookupResult` (`@/lib/lookup`, both already exist — `parseLookupResult(json, inputType, query)` with `inputType: "word"` always returns a `WordPhraseResult`, reused here per-suggestion instead of re-declaring the same field-extraction logic), `VocabRecord` (`@/lib/vocabRecords`, only `headword` is read).

Ports `find_known_headwords_use_case.dart` (a plain client-side substring scan — no Firestore call of its own, the caller already has `records` loaded) and `word_radar_source.dart`'s suggestion prompt (this file omits the `includeTranslation` branch — the Đọc & gõ result screen has no need for a full-text translation, since every sentence already carries one from `readingPassage.ts`).

- [ ] **Step 1: Write the failing test**

Create `apps/web/src/lib/vocabSuggestions.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import {
  findKnownHeadwords,
  buildVocabSuggestionsPrompt,
  parseVocabSuggestions,
} from "./vocabSuggestions";
import type { VocabRecord } from "./vocabRecords";

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

describe("findKnownHeadwords", () => {
  it("returns headwords that appear in the text, case-insensitively", () => {
    const records = [
      makeRecord({ headword: "meticulous" }),
      makeRecord({ headword: "ephemeral" }),
    ];
    const known = findKnownHeadwords("She is very Meticulous about details.", records);
    expect(known).toEqual(["meticulous"]);
  });

  it("returns an empty array when no known headword appears in the text", () => {
    const records = [makeRecord({ headword: "meticulous" })];
    expect(findKnownHeadwords("A short unrelated sentence.", records)).toEqual([]);
  });

  it("deduplicates a headword that appears multiple times in the text", () => {
    const records = [makeRecord({ headword: "detail" })];
    const known = findKnownHeadwords("Every detail matters, down to the smallest detail.", records);
    expect(known).toEqual(["detail"]);
  });
});

describe("buildVocabSuggestionsPrompt", () => {
  it("includes the text, target language label, and asks for up to 10 suggestions in JSON", () => {
    const prompt = buildVocabSuggestionsPrompt("Some passage text.", "english", []);
    expect(prompt).toContain("Some passage text.");
    expect(prompt).toContain("English");
    expect(prompt).toContain("up to 10");
    expect(prompt).toContain("JSON only");
    expect(prompt).toContain('"suggestions"');
  });

  it("tells the AI which headwords to exclude when some are already known", () => {
    const prompt = buildVocabSuggestionsPrompt("text", "english", ["meticulous", "ephemeral"]);
    expect(prompt).toContain("Do NOT suggest any of these already-known words: meticulous, ephemeral.");
  });

  it("omits the exclusion clause entirely when nothing is already known", () => {
    const prompt = buildVocabSuggestionsPrompt("text", "english", []);
    expect(prompt).not.toContain("Do NOT suggest");
  });
});

describe("parseVocabSuggestions", () => {
  it("parses a full WordPhraseResult per suggestion", () => {
    const json = {
      suggestions: [
        {
          headword: "meticulous",
          ipa: "/məˈtɪkjələs/",
          meaning: "tỉ mỉ",
          definition: "showing great attention to detail",
          examples: ["She is meticulous."],
          synonyms: ["thorough"],
          suggestedTopics: ["Academic"],
          cefrLevel: "C1",
        },
      ],
    };

    const result = parseVocabSuggestions(json);

    expect(result).toEqual([
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
    ]);
  });

  it("skips a suggestion item with no headword instead of throwing", () => {
    const result = parseVocabSuggestions({ suggestions: [{ meaning: "no headword here" }] });
    expect(result).toEqual([]);
  });

  it("returns an empty array when suggestions is missing or not an array", () => {
    expect(parseVocabSuggestions({})).toEqual([]);
    expect(parseVocabSuggestions({ suggestions: "not an array" })).toEqual([]);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm --prefix apps/web test -- vocabSuggestions`
Expected: FAIL — `apps/web/src/lib/vocabSuggestions.ts` does not exist yet.

- [ ] **Step 3: Implement**

Create `apps/web/src/lib/vocabSuggestions.ts`:

```ts
import { LANGUAGE_LABELS, type TargetLanguage } from "./languages";
import { parseLookupResult, type WordPhraseResult } from "./lookup";
import type { VocabRecord } from "./vocabRecords";

export function findKnownHeadwords(text: string, records: VocabRecord[]): string[] {
  const lowerText = text.toLowerCase();
  const seen = new Set<string>();
  const known: string[] = [];
  for (const record of records) {
    const lowerHeadword = record.headword.toLowerCase();
    if (lowerText.includes(lowerHeadword) && !seen.has(lowerHeadword)) {
      seen.add(lowerHeadword);
      known.push(record.headword);
    }
  }
  return known;
}

// Ports word_radar_source.dart's suggestion prompt, minus the
// includeTranslation branch — the reading result screen has no need for a
// full-text translation, every sentence already has one.
export function buildVocabSuggestionsPrompt(
  text: string,
  targetLanguage: TargetLanguage,
  knownHeadwords: string[]
): string {
  const languageLabel = LANGUAGE_LABELS[targetLanguage];
  const knownClause =
    knownHeadwords.length === 0
      ? ""
      : ` Do NOT suggest any of these already-known words: ${knownHeadwords.join(", ")}.`;
  return (
    `You are a language learning assistant helping a Vietnamese speaker learn ${languageLabel}. ` +
    `Given this text: "${text}", suggest up to 10 words or short phrases from the text that are ` +
    `worth learning.${knownClause} If nothing in the text is worth learning, use an empty ` +
    `"suggestions" array. Respond with JSON only (no markdown, no code fences): ` +
    `{"suggestions":[{"headword":"exact word or phrase from the text","ipa":"IPA transcription",` +
    `"meaning":"Vietnamese definition","definition":"English definition",` +
    `"synonyms":["2-4 English synonyms, or empty array if none fit"],` +
    `"examples":["example 1","example 2"],` +
    `"suggestedTopics":["one topic from: Daily Life, Travel, Food & Drink, Business, Technology, ` +
    `Health, Education, Entertainment, Nature, Emotion, Academic, Idioms, Phrasal Verbs, Slang, ` +
    `Social/Casual, Sports, Art & Culture, Science, Law & Politics, Other"],` +
    `"cefrLevel":"a1, a2, b1, b2, c1, or c2"}]} ` +
    `Every "meaning" field must use only Vietnamese script — ` +
    `never Chinese, Japanese, or other non-Vietnamese characters.`
  );
}

export function parseVocabSuggestions(json: Record<string, unknown>): WordPhraseResult[] {
  const rawSuggestions = Array.isArray(json.suggestions) ? json.suggestions : [];
  const suggestions: WordPhraseResult[] = [];
  for (const raw of rawSuggestions) {
    if (typeof raw !== "object" || raw === null) continue;
    const item = raw as Record<string, unknown>;
    if (typeof item.headword !== "string" || item.headword.length === 0) continue;
    const parsed = parseLookupResult(item, "word", item.headword);
    if (parsed.kind === "wordPhrase") suggestions.push(parsed);
  }
  return suggestions;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm --prefix apps/web test -- vocabSuggestions`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/web/src/lib/vocabSuggestions.ts apps/web/src/lib/vocabSuggestions.test.ts
git commit -m "feat(web): add vocab-suggestions prompt/parser (full entry per suggestion, one call)"
```

---

## Task 4: Extract shared `buildVocabRecordDraft` helper (refactor, no behavior change)

**Files:**
- Create: `apps/web/src/lib/vocabDraft.ts`
- Create: `apps/web/src/lib/vocabDraft.test.ts`
- Modify: `apps/web/src/app/(app)/lookup/page.tsx`

**Interfaces:**
- Produces: `normalizeTopicName(name: string): string`, `preselectTopicIds(suggestedTopics: string[], topics: Topic[]): string[]`, `buildVocabRecordDraft(result: WordPhraseResult, topics: Topic[], targetLanguage: TargetLanguage): VocabRecord`. Used by Task 6 (`VocabSuggestionsSection`) and by the now-refactored `lookup/page.tsx`.
- Consumes: `Topic` (`@/lib/topics`), `WordPhraseResult` (`@/lib/lookup`), `VocabRecord` (`@/lib/vocabRecords`), `TargetLanguage` (`@/lib/languages`) — all already exist.

`apps/web/src/app/(app)/lookup/page.tsx` currently declares `normalizeTopicName`, `preselectTopicIds`, and `buildDraftRecord` as module-level/component-local functions with identical logic to what this task needs for the new `VocabSuggestionsSection` (Task 6). This task moves them to a shared file and makes `lookup/page.tsx` a thin caller — a pure refactor, no behavior change, existing tests must still pass unmodified.

- [ ] **Step 1: Write the failing test**

Create `apps/web/src/lib/vocabDraft.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import { normalizeTopicName, preselectTopicIds, buildVocabRecordDraft } from "./vocabDraft";
import type { Topic } from "./topics";
import type { WordPhraseResult } from "./lookup";

const TOPICS: Topic[] = [
  { id: "biz-1", name: "Business", emoji: "💼", isPredefined: true, createdAt: "2026-01-01" },
  { id: "food-1", name: "Food & Drink", emoji: "🍜", isPredefined: true, createdAt: "2026-01-01" },
];

describe("normalizeTopicName", () => {
  it("lowercases, collapses punctuation, and treats & as and", () => {
    expect(normalizeTopicName("Food & Drink")).toBe("food and drink");
    expect(normalizeTopicName("food and drink")).toBe("food and drink");
  });
});

describe("preselectTopicIds", () => {
  it("matches suggested topic names case-insensitively, capped at 2, no duplicates", () => {
    expect(preselectTopicIds(["business", "Business", "food and drink"], TOPICS)).toEqual([
      "biz-1",
      "food-1",
    ]);
  });

  it("returns an empty array when no suggestion matches an existing topic", () => {
    expect(preselectTopicIds(["Sports"], TOPICS)).toEqual([]);
  });
});

describe("buildVocabRecordDraft", () => {
  const RESULT: WordPhraseResult = {
    kind: "wordPhrase",
    headword: "meticulous",
    inputType: "word",
    ipa: "/məˈtɪkjələs/",
    meaning: "tỉ mỉ",
    examples: ["She is meticulous."],
    definition: "showing great attention to detail",
    synonyms: ["thorough"],
    suggestedTopics: ["Business"],
    cefrLevel: "c1",
  };

  it("builds a VocabRecord draft with an empty id, preselected topics, and general context", () => {
    const draft = buildVocabRecordDraft(RESULT, TOPICS, "english");

    expect(draft.id).toBe("");
    expect(draft.headword).toBe("meticulous");
    expect(draft.meaning).toBe("tỉ mỉ");
    expect(draft.examples).toEqual(["She is meticulous."]);
    expect(draft.topicIds).toEqual(["biz-1"]);
    expect(draft.targetLanguage).toBe("english");
    expect(draft.cefrLevel).toBe("c1");
    expect(draft.activeContext).toBe("general");
    expect(draft.personalNotes).toBe("");
    expect(draft.nextReviewAt).toBeNull();
    expect(draft.sm2Repetitions).toBe(0);
    expect(draft.sm2EaseFactor).toBe(2.5);
    expect(draft.sm2Interval).toBe(1);
    expect(draft.definition).toBe("showing great attention to detail");
    expect(draft.synonyms).toEqual(["thorough"]);
  });

  it("defaults cefrLevel to b1 when the AI result has none", () => {
    const draft = buildVocabRecordDraft({ ...RESULT, cefrLevel: null }, TOPICS, "english");
    expect(draft.cefrLevel).toBe("b1");
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm --prefix apps/web test -- vocabDraft`
Expected: FAIL — `apps/web/src/lib/vocabDraft.ts` does not exist yet.

- [ ] **Step 3: Implement**

Create `apps/web/src/lib/vocabDraft.ts`:

```ts
import type { Topic } from "./topics";
import type { WordPhraseResult } from "./lookup";
import type { VocabRecord } from "./vocabRecords";
import type { TargetLanguage } from "./languages";

const MAX_PRESELECTED_TOPICS = 2;

// Loose match instead of a strict case-insensitive equality: the AI is
// prompted with a fixed English topic list ("Food & Drink", "Social/Casual",
// ...) but doesn't always echo it back byte-for-byte (different punctuation,
// "and" instead of "&", extra whitespace) — collapse both sides down to
// bare alphanumerics before comparing so those variations still match.
export function normalizeTopicName(name: string): string {
  return name
    .toLowerCase()
    .replace(/&/g, "and")
    .replace(/[^a-z0-9]+/g, " ")
    .trim();
}

export function preselectTopicIds(suggestedTopics: string[], topics: Topic[]): string[] {
  const selected: string[] = [];
  for (const suggestion of suggestedTopics) {
    if (selected.length >= MAX_PRESELECTED_TOPICS) break;
    const normalizedSuggestion = normalizeTopicName(suggestion);
    const match = topics.find((t) => normalizeTopicName(t.name) === normalizedSuggestion);
    if (match && !selected.includes(match.id)) selected.push(match.id);
  }
  return selected;
}

export function buildVocabRecordDraft(
  result: WordPhraseResult,
  topics: Topic[],
  targetLanguage: TargetLanguage
): VocabRecord {
  const now = new Date().toISOString();
  return {
    id: "",
    headword: result.headword,
    inputType: result.inputType,
    ipa: result.ipa,
    meaning: result.meaning,
    examples: result.examples,
    personalNotes: "",
    topicIds: preselectTopicIds(result.suggestedTopics, topics),
    // No "ngữ cảnh" (context) setting exists in Cài đặt yet — default to
    // "general" for every web-saved record (documented gap since Task 5 of
    // the Lookup/Ôn tập plan).
    targetLanguage,
    cefrLevel: result.cefrLevel ?? "b1",
    activeContext: "general",
    createdAt: now,
    updatedAt: now,
    nextReviewAt: null,
    sm2Repetitions: 0,
    sm2EaseFactor: 2.5,
    sm2Interval: 1,
    definition: result.definition,
    synonyms: result.synonyms,
  };
}
```

Now modify `apps/web/src/app/(app)/lookup/page.tsx` to use it instead of the local copies. Replace:

```tsx
import {
  buildDiscoverPrompt,
  buildSentencePrompt,
  buildWordPhrasePrompt,
  parseLookupResult,
  splitMeaningSenses,
  type LookupResult,
  type WordPhraseResult,
} from "@/lib/lookup";
import { parseAiJsonObject } from "@/lib/parseAiJson";
import { generateContent } from "@/lib/generateContent";
import { getTopics, type Topic } from "@/lib/topics";
import { ttsLanguageCode } from "@/lib/pronunciation";
import { PronunciationButton } from "@/components/shared/PronunciationButton";
import {
  getVocabRecordByHeadword,
  saveVocabRecord,
  type NewVocabRecord,
  type VocabRecord,
  type VocabRecordUpdate,
} from "@/lib/vocabRecords";

const MAX_PRESELECTED_TOPICS = 2;

// Loose match instead of a strict case-insensitive equality: the AI is
// prompted with a fixed English topic list ("Food & Drink", "Social/Casual",
// ...) but doesn't always echo it back byte-for-byte (different punctuation,
// "and" instead of "&", extra whitespace) — collapse both sides down to
// bare alphanumerics before comparing so those variations still match.
function normalizeTopicName(name: string): string {
  return name
    .toLowerCase()
    .replace(/&/g, "and")
    .replace(/[^a-z0-9]+/g, " ")
    .trim();
}

function preselectTopicIds(suggestedTopics: string[], topics: Topic[]): string[] {
  const selected: string[] = [];
  for (const suggestion of suggestedTopics) {
    if (selected.length >= MAX_PRESELECTED_TOPICS) break;
    const normalizedSuggestion = normalizeTopicName(suggestion);
    const match = topics.find((t) => normalizeTopicName(t.name) === normalizedSuggestion);
    if (match && !selected.includes(match.id)) selected.push(match.id);
  }
  return selected;
}

function cachedRecordToResult(cached: VocabRecord): WordPhraseResult {
```

with:

```tsx
import {
  buildDiscoverPrompt,
  buildSentencePrompt,
  buildWordPhrasePrompt,
  parseLookupResult,
  splitMeaningSenses,
  type LookupResult,
  type WordPhraseResult,
} from "@/lib/lookup";
import { parseAiJsonObject } from "@/lib/parseAiJson";
import { generateContent } from "@/lib/generateContent";
import { getTopics, type Topic } from "@/lib/topics";
import { ttsLanguageCode } from "@/lib/pronunciation";
import { PronunciationButton } from "@/components/shared/PronunciationButton";
import { buildVocabRecordDraft } from "@/lib/vocabDraft";
import {
  getVocabRecordByHeadword,
  saveVocabRecord,
  type NewVocabRecord,
  type VocabRecord,
  type VocabRecordUpdate,
} from "@/lib/vocabRecords";

function cachedRecordToResult(cached: VocabRecord): WordPhraseResult {
```

Then replace the `buildDraftRecord` function body:

```tsx
  function buildDraftRecord(wordResult: WordPhraseResult): VocabRecord {
    const now = new Date().toISOString();
    return {
      id: "",
      headword: wordResult.headword,
      inputType: wordResult.inputType,
      ipa: wordResult.ipa,
      meaning: wordResult.meaning,
      examples: wordResult.examples,
      personalNotes: "",
      topicIds: preselectTopicIds(wordResult.suggestedTopics, topics),
      // No "ngữ cảnh" (context) setting exists in Cài đặt yet — default to
      // "general" for every web-saved record (see Task 5's plan note).
      targetLanguage: settings?.targetLanguage ?? "english",
      cefrLevel: wordResult.cefrLevel ?? "b1",
      activeContext: "general",
      createdAt: now,
      updatedAt: now,
      nextReviewAt: null,
      sm2Repetitions: 0,
      sm2EaseFactor: 2.5,
      sm2Interval: 1,
      definition: wordResult.definition,
      synonyms: wordResult.synonyms,
    };
  }
```

with:

```tsx
  function buildDraftRecord(wordResult: WordPhraseResult): VocabRecord {
    return buildVocabRecordDraft(wordResult, topics, settings?.targetLanguage ?? "english");
  }
```

- [ ] **Step 4: Run tests to verify everything passes**

Run: `npm --prefix apps/web test -- vocabDraft` — expect PASS (new tests).
Run: `npm --prefix apps/web test -- lookup` — expect PASS, unchanged (this is the refactor's regression check: same behavior, moved location).

- [ ] **Step 5: Commit**

```bash
git add apps/web/src/lib/vocabDraft.ts apps/web/src/lib/vocabDraft.test.ts "apps/web/src/app/(app)/lookup/page.tsx"
git commit -m "refactor(web): extract buildVocabRecordDraft into a shared lib, no behavior change"
```

---

## Task 5: `TypingSentence` component

**Files:**
- Create: `apps/web/src/components/reading/TypingSentence.tsx`
- Create: `apps/web/src/components/reading/TypingSentence.test.tsx`
- Modify: `apps/web/src/styles/bloom.css` (append `.reading-*` CSS)

**Interfaces:**
- Produces: `<TypingSentence completedSentences={string[]} currentSentence={BilingualSentence} typed={string} onTypedChange={(value: string) => void} />`. Used by Task 9 (session phase).
- Consumes: `BilingualSentence` (`@/lib/readingPassage`, Task 1).

Implements the typing-feedback design confirmed via 2 rounds of live visual-companion iteration with the user: a single plain `<input>` (browser manages its cursor natively — never restyled, never overlaid) plus a *separate* element (the passage's current-sentence span) that re-renders its color-coded characters on every keystroke. This deliberately avoids two fragility classes tried/rejected during design: Flutter's transparent-overlay-on-`RichText` approach (its own code comments flag the font-alignment risk), and a `contentEditable`-based single-element alternative (a real cursor/space-character bug was reproduced live in that variant while designing). Only completed sentences and the current sentence are shown — upcoming sentences are not revealed in advance.

- [ ] **Step 1: Write the failing test**

Create `apps/web/src/components/reading/TypingSentence.test.tsx`:

```tsx
import { describe, expect, it, vi } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import { TypingSentence } from "./TypingSentence";
import type { BilingualSentence } from "@/lib/readingPassage";

const CURRENT: BilingualSentence = {
  target: "The meeting was rescheduled.",
  vietnamese: "Cuộc họp đã được dời lại.",
  vocabWords: ["rescheduled"],
};

describe("TypingSentence", () => {
  it("shows the Vietnamese translation of the current sentence", () => {
    render(
      <TypingSentence
        completedSentences={[]}
        currentSentence={CURRENT}
        typed=""
        onTypedChange={vi.fn()}
      />
    );
    expect(screen.getByText("Cuộc họp đã được dời lại.")).toBeInTheDocument();
  });

  it("shows previously completed sentences alongside the current one", () => {
    render(
      <TypingSentence
        completedSentences={["She works at a bank."]}
        currentSentence={CURRENT}
        typed=""
        onTypedChange={vi.fn()}
      />
    );
    expect(screen.getByText(/She works at a bank\./)).toBeInTheDocument();
  });

  it("colors correctly-typed characters differently from incorrectly-typed ones", () => {
    render(
      <TypingSentence
        completedSentences={[]}
        currentSentence={CURRENT}
        typed="Thx"
        onTypedChange={vi.fn()}
      />
    );
    const input = screen.getByTestId("reading-type-input");
    const passage = input.parentElement!;
    const okChars = passage.querySelectorAll(".reading-char-ok");
    const badChars = passage.querySelectorAll(".reading-char-bad");
    expect(okChars).toHaveLength(2); // "T", "h" match
    expect(badChars).toHaveLength(1); // "x" doesn't match "e"
  });

  it("calls onTypedChange with the new input value on every keystroke", () => {
    const onTypedChange = vi.fn();
    render(
      <TypingSentence
        completedSentences={[]}
        currentSentence={CURRENT}
        typed="The"
        onTypedChange={onTypedChange}
      />
    );
    fireEvent.change(screen.getByTestId("reading-type-input"), { target: { value: "The " } });
    expect(onTypedChange).toHaveBeenCalledWith("The ");
  });

  it("does not reveal any sentence after the current one", () => {
    render(
      <TypingSentence
        completedSentences={[]}
        currentSentence={CURRENT}
        typed=""
        onTypedChange={vi.fn()}
      />
    );
    expect(screen.queryByText(/next sentence/i)).not.toBeInTheDocument();
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm --prefix apps/web test -- TypingSentence`
Expected: FAIL — `apps/web/src/components/reading/TypingSentence.tsx` does not exist yet.

- [ ] **Step 3: Implement**

Create `apps/web/src/components/reading/TypingSentence.tsx`:

```tsx
"use client";

import type { BilingualSentence } from "@/lib/readingPassage";

interface TypingSentenceProps {
  completedSentences: string[];
  currentSentence: BilingualSentence;
  typed: string;
  onTypedChange: (value: string) => void;
}

export function TypingSentence({
  completedSentences,
  currentSentence,
  typed,
  onTypedChange,
}: TypingSentenceProps) {
  const target = currentSentence.target;
  const typedChars = typed.split("").map((ch, i) => ({
    ch,
    ok: ch === target[i],
  }));
  const pending = target.slice(typed.length);

  return (
    <div className="reading-passage-wrap">
      <p className="reading-passage">
        {completedSentences.length > 0 && (
          <span className="reading-completed">{completedSentences.join(" ")} </span>
        )}
        <span className="reading-current">
          {typedChars.map((c, i) => (
            <span key={i} className={c.ok ? "reading-char-ok" : "reading-char-bad"}>
              {c.ch}
            </span>
          ))}
          <span className="reading-pending">{pending}</span>
        </span>
      </p>
      <div className="reading-vn-row">{currentSentence.vietnamese}</div>
      <input
        className="reading-type-input"
        value={typed}
        onChange={(e) => onTypedChange(e.target.value)}
        placeholder="Gõ câu tiếng Anh ở đây…"
        autoComplete="off"
        data-testid="reading-type-input"
      />
    </div>
  );
}
```

- [ ] **Step 4: Append CSS**

Modify `apps/web/src/styles/bloom.css` — append at the end:

```css

.reading-passage-wrap {
  max-width: 640px;
  margin: 0 auto;
}

.reading-passage {
  font-size: 16px;
  line-height: 1.8;
  margin: 0;
}

.reading-completed {
  color: var(--ink-faint);
}

.reading-current {
  font-weight: 700;
}

.reading-char-ok {
  color: var(--success);
}

.reading-char-bad {
  color: var(--danger);
  background: var(--danger-bg);
  border-radius: 3px;
}

.reading-pending {
  color: var(--ink);
}

.reading-vn-row {
  background: var(--surface-3);
  border-radius: 12px;
  padding: 10px 14px;
  font-size: 13px;
  color: var(--ink-soft);
  font-style: italic;
  margin: 14px 0 18px;
}

.reading-type-input {
  width: 100%;
  box-sizing: border-box;
  font-size: 16px;
  font-family: ui-monospace, monospace;
  padding: 12px 14px;
  border-radius: 12px;
  border: 1px solid var(--border);
  background: var(--surface);
  color: var(--ink);
  outline: none;
}

.reading-type-input:focus {
  border-color: var(--accent);
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `npm --prefix apps/web test -- TypingSentence`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add apps/web/src/components/reading/TypingSentence.tsx apps/web/src/components/reading/TypingSentence.test.tsx apps/web/src/styles/bloom.css
git commit -m "feat(web): add TypingSentence component for Đọc & gõ (confirmed via visual companion)"
```

---

## Task 6: `VocabSuggestionsSection` shared component

**Files:**
- Create: `apps/web/src/components/shared/VocabSuggestionsSection.tsx`
- Create: `apps/web/src/components/shared/VocabSuggestionsSection.test.tsx`
- Modify: `apps/web/src/styles/bloom.css` (append `.suggestion-*` CSS)

**Interfaces:**
- Produces: `<VocabSuggestionsSection text={string} existingRecords={VocabRecord[]} topics={Topic[]} />`. Used by Task 10 (result phase) — and, per spec §5, intended for reuse by future result screens (Part 5/6/7, Nghe hiểu), which is why it's self-contained rather than needing its language/auth/AI-config threaded through as props.
- Consumes: `findKnownHeadwords`, `buildVocabSuggestionsPrompt`, `parseVocabSuggestions` (`@/lib/vocabSuggestions`, Task 3), `buildVocabRecordDraft` (`@/lib/vocabDraft`, Task 4), `useAuthUser` (`@/lib/useAuthUser`), `useSettingsContext` (`@/lib/SettingsContext`), `generateContent` (`@/lib/generateContent`), `parseAiJsonObject` (`@/lib/parseAiJson`), `getVocabRecordByHeadword`, `saveVocabRecord` (`@/lib/vocabRecords`), `EditVocabModal` (`@/components/vocab-bank/EditVocabModal`, `mode="create"`) — all already exist, no changes needed to any of them.

Self-contained: reads the active AI provider/model/key and target language from `useSettingsContext()` itself, and the current user from `useAuthUser()` itself, rather than taking them as props — this is deliberate so a future caller only ever has to pass `text`/`existingRecords`/`topics`. Renders nothing at all if the active provider has no API key configured (no AI call attempted).

- [ ] **Step 1: Write the failing test**

Create `apps/web/src/components/shared/VocabSuggestionsSection.test.tsx`:

```tsx
import { beforeEach, describe, expect, it, vi } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import { VocabSuggestionsSection } from "./VocabSuggestionsSection";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettingsContext } from "@/lib/SettingsContext";
import { generateContent } from "@/lib/generateContent";
import { getVocabRecordByHeadword, saveVocabRecord } from "@/lib/vocabRecords";
import { DEFAULT_SETTINGS, type UserSettings } from "@/lib/settings";
import type { VocabRecord } from "@/lib/vocabRecords";

vi.mock("@/lib/useAuthUser", () => ({ useAuthUser: vi.fn() }));
vi.mock("@/lib/SettingsContext", () => ({ useSettingsContext: vi.fn() }));
vi.mock("@/lib/generateContent", () => ({ generateContent: vi.fn() }));
vi.mock("@/lib/vocabRecords", () => ({
  getVocabRecordByHeadword: vi.fn(),
  saveVocabRecord: vi.fn(),
}));

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

beforeEach(() => {
  vi.clearAllMocks();
  vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" }, loading: false } as never);
  vi.mocked(useSettingsContext).mockReturnValue({
    settings: SETTINGS_WITH_KEY,
    loading: false,
    error: null,
    save: vi.fn(),
  });
});

describe("VocabSuggestionsSection", () => {
  it("renders nothing at all when the active provider has no API key", () => {
    vi.mocked(useSettingsContext).mockReturnValue({
      settings: DEFAULT_SETTINGS, // no apiKeyCiphertext
      loading: false,
      error: null,
      save: vi.fn(),
    });
    const { container } = render(
      <VocabSuggestionsSection text="Some passage." existingRecords={[]} topics={[]} />
    );
    expect(container.firstChild).toBeNull();
    expect(generateContent).not.toHaveBeenCalled();
  });

  it("loads suggestions on mount and renders each as a card", async () => {
    vi.mocked(generateContent).mockResolvedValue({
      text: JSON.stringify({
        suggestions: [
          { headword: "meticulous", ipa: "/x/", meaning: "tỉ mỉ", cefrLevel: "c1" },
        ],
      }),
    });

    render(<VocabSuggestionsSection text="She is meticulous." existingRecords={[]} topics={[]} />);

    expect(await screen.findByText("meticulous")).toBeInTheDocument();
    expect(screen.getByText("tỉ mỉ")).toBeInTheDocument();
  });

  it("shows a 'no suggestions' message when the AI returns an empty list", async () => {
    vi.mocked(generateContent).mockResolvedValue({ text: JSON.stringify({ suggestions: [] }) });
    render(<VocabSuggestionsSection text="text" existingRecords={[]} topics={[]} />);
    expect(await screen.findByText("Không có gợi ý mới.")).toBeInTheDocument();
  });

  it("shows an error and a Thử lại button when the AI call fails, and retries on click", async () => {
    vi.mocked(generateContent).mockRejectedValueOnce(new Error("network down"));
    render(<VocabSuggestionsSection text="text" existingRecords={[]} topics={[]} />);

    expect(await screen.findByText(/network down/)).toBeInTheDocument();
    vi.mocked(generateContent).mockResolvedValueOnce({ text: JSON.stringify({ suggestions: [] }) });
    fireEvent.click(screen.getByRole("button", { name: "Thử lại" }));
    expect(await screen.findByText("Không có gợi ý mới.")).toBeInTheDocument();
  });

  it("opens EditVocabModal in create mode when a suggestion card is tapped, and saves it", async () => {
    vi.mocked(generateContent).mockResolvedValue({
      text: JSON.stringify({ suggestions: [{ headword: "meticulous", meaning: "tỉ mỉ" }] }),
    });
    vi.mocked(getVocabRecordByHeadword).mockResolvedValue(null);
    vi.mocked(saveVocabRecord).mockResolvedValue("new-id");

    render(<VocabSuggestionsSection text="text" existingRecords={[]} topics={[]} />);
    fireEvent.click(await screen.findByText("meticulous"));

    expect(screen.getByRole("dialog", { name: /Lưu từ meticulous/ })).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "Lưu" }));

    await waitFor(() => expect(saveVocabRecord).toHaveBeenCalledWith("u1", expect.any(Object)));
    expect(await screen.findByText("✔")).toBeInTheDocument();
  });

  it('"Lưu tất cả" bulk-saves every not-yet-saved suggestion, skipping duplicates', async () => {
    vi.mocked(generateContent).mockResolvedValue({
      text: JSON.stringify({
        suggestions: [
          { headword: "meticulous", meaning: "tỉ mỉ" },
          { headword: "ephemeral", meaning: "phù du" },
        ],
      }),
    });
    vi.mocked(getVocabRecordByHeadword).mockImplementation(async (_uid, headword) =>
      headword === "ephemeral"
        ? makeRecord({ id: "existing-1", headword: "ephemeral" })
        : null
    );
    vi.mocked(saveVocabRecord).mockResolvedValue("new-id");

    render(<VocabSuggestionsSection text="text" existingRecords={[]} topics={[]} />);
    await screen.findByText("meticulous");

    fireEvent.click(screen.getByRole("button", { name: "Lưu tất cả" }));

    await waitFor(() => expect(saveVocabRecord).toHaveBeenCalledTimes(1));
    expect(saveVocabRecord).toHaveBeenCalledWith(
      "u1",
      expect.objectContaining({ headword: "meticulous" })
    );
    expect(await screen.findByText("Đã lưu 1/2 từ.")).toBeInTheDocument();
  });

  it("dismisses a suggestion card without saving it, and hides it from Lưu tất cả", async () => {
    vi.mocked(generateContent).mockResolvedValue({
      text: JSON.stringify({ suggestions: [{ headword: "meticulous", meaning: "tỉ mỉ" }] }),
    });

    render(<VocabSuggestionsSection text="text" existingRecords={[]} topics={[]} />);
    await screen.findByText("meticulous");

    fireEvent.click(screen.getByRole("button", { name: "Bỏ qua gợi ý này" }));

    expect(screen.queryByText("meticulous")).not.toBeInTheDocument();
    expect(saveVocabRecord).not.toHaveBeenCalled();
  });

  it("excludes headwords already in existingRecords from the prompt", async () => {
    vi.mocked(generateContent).mockResolvedValue({ text: JSON.stringify({ suggestions: [] }) });
    const existing = [makeRecord({ headword: "meticulous" })];

    render(
      <VocabSuggestionsSection
        text="She is meticulous and diligent."
        existingRecords={existing}
        topics={[]}
      />
    );

    await waitFor(() => expect(generateContent).toHaveBeenCalled());
    const call = vi.mocked(generateContent).mock.calls[0][0];
    expect(call.prompt).toContain("Do NOT suggest any of these already-known words: meticulous.");
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm --prefix apps/web test -- VocabSuggestionsSection`
Expected: FAIL — `apps/web/src/components/shared/VocabSuggestionsSection.tsx` does not exist yet.

- [ ] **Step 3: Implement**

Create `apps/web/src/components/shared/VocabSuggestionsSection.tsx`:

```tsx
"use client";

import { useEffect, useState } from "react";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettingsContext } from "@/lib/SettingsContext";
import { generateContent } from "@/lib/generateContent";
import { parseAiJsonObject } from "@/lib/parseAiJson";
import {
  findKnownHeadwords,
  buildVocabSuggestionsPrompt,
  parseVocabSuggestions,
} from "@/lib/vocabSuggestions";
import { buildVocabRecordDraft } from "@/lib/vocabDraft";
import {
  getVocabRecordByHeadword,
  saveVocabRecord,
  type VocabRecord,
  type VocabRecordUpdate,
} from "@/lib/vocabRecords";
import { EditVocabModal } from "@/components/vocab-bank/EditVocabModal";
import type { Topic } from "@/lib/topics";
import type { WordPhraseResult } from "@/lib/lookup";

interface VocabSuggestionsSectionProps {
  text: string;
  existingRecords: VocabRecord[];
  topics: Topic[];
}

export function VocabSuggestionsSection({ text, existingRecords, topics }: VocabSuggestionsSectionProps) {
  const { user } = useAuthUser();
  const { settings } = useSettingsContext();

  const [suggestions, setSuggestions] = useState<WordPhraseResult[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [savedHeadwords, setSavedHeadwords] = useState<Set<string>>(new Set());
  const [dismissedHeadwords, setDismissedHeadwords] = useState<Set<string>>(new Set());
  const [editingSuggestion, setEditingSuggestion] = useState<WordPhraseResult | null>(null);
  const [bulkSaveMessage, setBulkSaveMessage] = useState<string | null>(null);

  const activeConfig = settings?.providers[settings.activeProvider];
  const aiEnabled = Boolean(activeConfig?.apiKeyCiphertext);

  useEffect(() => {
    if (!aiEnabled || !settings || !activeConfig?.apiKeyCiphertext) return;
    let cancelled = false;

    async function load() {
      setError(null);
      setSuggestions(null);
      try {
        const knownHeadwords = findKnownHeadwords(text, existingRecords);
        const prompt = buildVocabSuggestionsPrompt(text, settings!.targetLanguage, knownHeadwords);
        const response = await generateContent({
          provider: settings!.activeProvider,
          model: activeConfig!.model,
          apiKeyCiphertext: activeConfig!.apiKeyCiphertext!,
          prompt,
        });
        if (cancelled) return;
        const json = parseAiJsonObject(response.text);
        setSuggestions(parseVocabSuggestions(json));
      } catch (err) {
        if (!cancelled) setError(err instanceof Error ? err.message : String(err));
      }
    }

    void load();
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [aiEnabled, text]);

  if (!aiEnabled) return null;

  async function handleSaveOne(updates: VocabRecordUpdate) {
    if (!user || !editingSuggestion || !settings) return;
    const draft = buildVocabRecordDraft(editingSuggestion, topics, settings.targetLanguage);
    const merged = { ...draft, ...updates };
    const duplicate = await getVocabRecordByHeadword(user.uid, merged.headword, merged.targetLanguage);
    if (!duplicate) {
      const { id: _omit, ...newRecord } = merged;
      await saveVocabRecord(user.uid, newRecord);
    }
    setSavedHeadwords((prev) => new Set(prev).add(editingSuggestion.headword));
    setEditingSuggestion(null);
  }

  async function handleSaveAll() {
    if (!user || !settings || !suggestions) return;
    const toSave = suggestions.filter(
      (s) => !savedHeadwords.has(s.headword) && !dismissedHeadwords.has(s.headword)
    );
    let savedCount = 0;
    for (const s of toSave) {
      const draft = buildVocabRecordDraft(s, topics, settings.targetLanguage);
      const duplicate = await getVocabRecordByHeadword(user.uid, draft.headword, draft.targetLanguage);
      if (!duplicate) {
        const { id: _omit, ...newRecord } = draft;
        await saveVocabRecord(user.uid, newRecord);
        savedCount++;
        setSavedHeadwords((prev) => new Set(prev).add(s.headword));
      }
    }
    setBulkSaveMessage(`Đã lưu ${savedCount}/${toSave.length} từ.`);
  }

  const visible = (suggestions ?? []).filter((s) => !dismissedHeadwords.has(s.headword));
  const hasUnsaved = visible.some((s) => !savedHeadwords.has(s.headword));

  return (
    <div className="suggestions-section">
      <div className="suggestions-header">
        <span className="suggestions-title">Gợi ý từ mới</span>
        {hasUnsaved && suggestions && (
          <button type="button" className="link-btn" onClick={() => void handleSaveAll()}>
            Lưu tất cả
          </button>
        )}
      </div>
      {bulkSaveMessage && <p className="suggestions-bulk-message">{bulkSaveMessage}</p>}
      {error && (
        <div>
          <p role="alert">Không tải được gợi ý từ mới: {error}</p>
          <button type="button" className="link-btn" onClick={() => setError(null) || setSuggestions(undefined as never)}>
            Thử lại
          </button>
        </div>
      )}
      {!error && suggestions === null && <p>Đang tải gợi ý…</p>}
      {!error && suggestions !== null && visible.length === 0 && <p>Không có gợi ý mới.</p>}
      {!error && visible.length > 0 && (
        <div className="suggestion-cards">
          {visible.map((s) => {
            const isSaved = savedHeadwords.has(s.headword);
            return (
              <div className="suggestion-card" key={s.headword}>
                <button
                  type="button"
                  className="suggestion-card-main"
                  disabled={isSaved}
                  onClick={() => setEditingSuggestion(s)}
                >
                  <span className="suggestion-headword">{s.headword}</span>
                  <span className="suggestion-meaning">
                    {s.ipa && `${s.ipa} • `}
                    {s.meaning}
                  </span>
                  {s.cefrLevel && <span className="cefr-pill">{s.cefrLevel.toUpperCase()}</span>}
                </button>
                {isSaved ? (
                  <span className="suggestion-saved-mark">✔</span>
                ) : (
                  <button
                    type="button"
                    className="closex"
                    aria-label="Bỏ qua gợi ý này"
                    onClick={() =>
                      setDismissedHeadwords((prev) => new Set(prev).add(s.headword))
                    }
                  >
                    ✕
                  </button>
                )}
              </div>
            );
          })}
        </div>
      )}
      {editingSuggestion && settings && (
        <EditVocabModal
          record={buildVocabRecordDraft(editingSuggestion, topics, settings.targetLanguage)}
          topics={topics}
          mode="create"
          onClose={() => setEditingSuggestion(null)}
          onSave={handleSaveOne}
        />
      )}
    </div>
  );
}
```

- [ ] **Step 4: Fix the retry handler (self-review catch before running tests)**

The `Thử lại` button in Step 3's draft used an invalid expression (`setError(null) || setSuggestions(...)`, which doesn't compile — `setError` returns `void`). Replace that `onClick` with a proper retry that just clears the error and lets the existing `useEffect` re-run. Since the effect's dependency array is `[aiEnabled, text]` (neither changes on retry), add a `reloadKey` counter to force a re-run:

In the component, add a new piece of state right after the existing `useState` calls:

```tsx
  const [reloadKey, setReloadKey] = useState(0);
```

Change the effect's dependency array from `[aiEnabled, text]` to `[aiEnabled, text, reloadKey]`.

Replace the broken retry button:

```tsx
          <button type="button" className="link-btn" onClick={() => setError(null) || setSuggestions(undefined as never)}>
            Thử lại
          </button>
```

with:

```tsx
          <button type="button" className="link-btn" onClick={() => setReloadKey((k) => k + 1)}>
            Thử lại
          </button>
```

- [ ] **Step 5: Append CSS**

Modify `apps/web/src/styles/bloom.css` — append at the end:

```css

.suggestions-section {
  margin-top: 24px;
}

.suggestions-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 10px;
}

.suggestions-title {
  font-weight: 700;
  font-size: 13.5px;
}

.suggestions-bulk-message {
  color: var(--ink-soft);
  font-size: 12.5px;
  margin: 0 0 10px;
}

.suggestion-cards {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.suggestion-card {
  display: flex;
  align-items: center;
  gap: 10px;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 14px;
  padding: 10px 14px;
}

.suggestion-card-main {
  flex: 1;
  display: flex;
  align-items: center;
  gap: 10px;
  background: none;
  border: none;
  text-align: left;
  cursor: pointer;
  padding: 0;
}

.suggestion-card-main:disabled {
  cursor: default;
}

.suggestion-headword {
  font-weight: 700;
  font-size: 14px;
}

.suggestion-meaning {
  color: var(--ink-soft);
  font-size: 12.5px;
  flex: 1;
}

.suggestion-saved-mark {
  color: var(--success);
  font-weight: 700;
}
```

- [ ] **Step 6: Run test to verify it passes**

Run: `npm --prefix apps/web test -- VocabSuggestionsSection`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add apps/web/src/components/shared/VocabSuggestionsSection.tsx apps/web/src/components/shared/VocabSuggestionsSection.test.tsx apps/web/src/styles/bloom.css
git commit -m "feat(web): add shared VocabSuggestionsSection (full entry per suggestion, tap-to-save, bulk save)"
```

---

## Task 7: `/reading` hub page

**Files:**
- Create: `apps/web/src/app/(app)/reading/page.tsx`
- Create: `apps/web/src/app/(app)/reading/page.test.tsx`
- Modify: `apps/web/src/styles/bloom.css` (append `.reading-hub-*` CSS)

**Interfaces:**
- Produces: the `/reading` route. One real card today (Đọc & gõ → `/reading/bilingual`, Task 8-10); Part 5/6/7 cards are added in later sub-specs, not this one.
- Consumes: `useAuthUser` (`@/lib/useAuthUser`), `SignInButton` (`@/components/SignInButton`) — both already exist. The Sidebar's "📖 Đọc — tổng quan" link already points at `/reading` and needs no change (verified: `apps/web/src/components/shell/Sidebar.tsx` already has `{ href: "/reading", label: "📖 Đọc — tổng quan" }`).

- [ ] **Step 1: Write the failing test**

Create `apps/web/src/app/(app)/reading/page.test.tsx`:

```tsx
import { describe, expect, it, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import ReadingHubPage from "./page";
import { useAuthUser } from "@/lib/useAuthUser";

vi.mock("@/lib/useAuthUser", () => ({ useAuthUser: vi.fn() }));
vi.mock("@/components/SignInButton", () => ({
  SignInButton: () => <button>Đăng nhập với Google</button>,
}));

describe("ReadingHubPage", () => {
  it("prompts sign-in when logged out", () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: null, loading: false } as never);
    render(<ReadingHubPage />);
    expect(screen.getByText("Đăng nhập với Google")).toBeInTheDocument();
  });

  it("shows the Đọc & gõ card linking to /reading/bilingual when signed in", () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" }, loading: false } as never);
    render(<ReadingHubPage />);
    const link = screen.getByRole("link", { name: /Đọc & gõ/ });
    expect(link).toHaveAttribute("href", "/reading/bilingual");
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm --prefix apps/web test -- "app/(app)/reading/page"`
Expected: FAIL — `apps/web/src/app/(app)/reading/page.tsx` does not exist yet.

- [ ] **Step 3: Implement**

Create `apps/web/src/app/(app)/reading/page.tsx`:

```tsx
"use client";

import Link from "next/link";
import { useAuthUser } from "@/lib/useAuthUser";
import { SignInButton } from "@/components/SignInButton";

export default function ReadingHubPage() {
  const { user, loading: authLoading } = useAuthUser();

  if (authLoading) return <p>Đang tải…</p>;

  if (!user) {
    return (
      <div>
        <h2 className="scr-title">Đọc</h2>
        <p className="scr-sub">Đăng nhập để luyện đọc.</p>
        <SignInButton />
      </div>
    );
  }

  return (
    <div>
      <h2 className="scr-title">Đọc</h2>
      <p className="scr-sub">Chọn một chế độ luyện đọc.</p>
      <div className="reading-hub-cards">
        <Link href="/reading/bilingual" className="reading-hub-card">
          <span className="reading-hub-card-title">✍️ Đọc &amp; gõ</span>
          <span className="reading-hub-card-desc">
            Gõ lại đoạn văn song ngữ được tạo từ từ vựng của bạn.
          </span>
        </Link>
      </div>
    </div>
  );
}
```

- [ ] **Step 4: Append CSS**

Modify `apps/web/src/styles/bloom.css` — append at the end:

```css

.reading-hub-cards {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
  gap: 14px;
  max-width: 720px;
}

.reading-hub-card {
  display: flex;
  flex-direction: column;
  gap: 6px;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 18px;
  padding: 18px 20px;
  text-decoration: none;
  color: var(--ink);
}

.reading-hub-card-title {
  font-weight: 700;
  font-size: 15px;
}

.reading-hub-card-desc {
  color: var(--ink-soft);
  font-size: 12.5px;
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `npm --prefix apps/web test -- "app/(app)/reading/page"`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add "apps/web/src/app/(app)/reading" apps/web/src/styles/bloom.css
git commit -m "feat(web): add Đọc hub page with the Đọc & gõ card"
```

---

## Task 8: `/reading/bilingual` page — setup phase

**Files:**
- Create: `apps/web/src/app/(app)/reading/bilingual/page.tsx`
- Create: `apps/web/src/app/(app)/reading/bilingual/page.test.tsx`
- Modify: `apps/web/src/styles/bloom.css` (append `.reading-min-words-hint` CSS)

**Interfaces:**
- Produces: the `/reading/bilingual` route, with a `Phase = "setup" | "session" | "result"` state machine — this task only renders the `"setup"` phase (matching the pattern already established by `practice/page.tsx`'s own setup-phase task). `handleGenerate` already computes the real word list and calls the real AI, storing the result into `passage` state and moving `phase` to `"session"` — later tasks render that phase from real state, not re-deriving it.
- Consumes: `getVocabRecords` (`@/lib/vocabRecords`), `getTopics` (`@/lib/topics`), `TopicFilterPopover` (`@/components/vocab-bank/TopicFilterPopover`), `SimpleDropdown`/`SimpleDropdownOption` (`@/components/shared/SimpleDropdown`), `selectSessionWords`/`SessionWordFilters` (`@/lib/practiceSession`, Task 8's due-then-fallback selection, reused unchanged), `parseReadingPassage`/`ReadingPassage` (`@/lib/readingPassage`, Task 1), `generateContent` (`@/lib/generateContent`), `parseAiJsonObject` (`@/lib/parseAiJson`) — all already exist. **`buildReadingPassagePrompt`'s real shipped signature is `(headwords: string[], targetLanguage: TargetLanguage, maxCefr: CefrLevel | null): string`** — a 3rd `maxCefr` parameter was added during Task 1's review (it's threaded through as an explicit "keep difficulty at or below CEFR X" instruction, not just implied by the word list) after the rest of this plan's earlier text was written; every code block in this task already reflects that 3-arg signature — call it with `maxCefr` (this task's own state), not a 2-arg call.
- Produces (for Task 9): `interface SentenceProgress { deletedChars: number; startedAt: number }` is NOT yet introduced here — that state is added in Task 9 alongside the session phase's own rendering.

- [ ] **Step 1: Write the failing test**

Create `apps/web/src/app/(app)/reading/bilingual/page.test.tsx`:

```tsx
import { beforeEach, describe, expect, it, vi } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import BilingualReadingPage from "./page";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettingsContext } from "@/lib/SettingsContext";
import { getVocabRecords, type VocabRecord } from "@/lib/vocabRecords";
import { getTopics } from "@/lib/topics";
import { generateContent } from "@/lib/generateContent";
import { DEFAULT_SETTINGS, type UserSettings } from "@/lib/settings";

vi.mock("@/lib/useAuthUser", () => ({ useAuthUser: vi.fn() }));
vi.mock("@/lib/SettingsContext", () => ({ useSettingsContext: vi.fn() }));
vi.mock("@/lib/vocabRecords", () => ({ getVocabRecords: vi.fn() }));
vi.mock("@/lib/topics", () => ({ getTopics: vi.fn() }));
vi.mock("@/lib/generateContent", () => ({ generateContent: vi.fn() }));
vi.mock("@/components/SignInButton", () => ({
  SignInButton: () => <button>Đăng nhập với Google</button>,
}));

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
    examples: ["ví dụ"],
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

beforeEach(() => {
  vi.clearAllMocks();
});

describe("BilingualReadingPage (setup phase)", () => {
  it("prompts sign-in when logged out", () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: null, loading: false } as never);
    vi.mocked(useSettingsContext).mockReturnValue({
      settings: null,
      loading: false,
      error: null,
      save: vi.fn(),
    });
    render(<BilingualReadingPage />);
    expect(screen.getByText("Đăng nhập với Google")).toBeInTheDocument();
  });

  it("shows the minimum-words hint instead of the generate button when fewer than 5 words match", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([
      makeRecord({ id: "1" }),
      makeRecord({ id: "2" }),
    ]);
    vi.mocked(getTopics).mockResolvedValue([]);

    render(<BilingualReadingPage />);

    expect(
      await screen.findByText("Hãy lưu ít nhất 5 từ khớp với bộ lọc trên vào Ngân hàng từ vựng. Hiện có 2 từ.")
    ).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Tạo bài luyện" })).not.toBeInTheDocument();
  });

  it("shows the generate button once at least 5 words match", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue(
      Array.from({ length: 5 }, (_, i) => makeRecord({ id: `w${i}`, headword: `word${i}` }))
    );
    vi.mocked(getTopics).mockResolvedValue([]);

    render(<BilingualReadingPage />);

    expect(await screen.findByRole("button", { name: "Tạo bài luyện" })).not.toBeDisabled();
  });

  it("generates a passage from the due-prioritized word list and leaves the setup screen", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue(
      Array.from({ length: 5 }, (_, i) => makeRecord({ id: `w${i}`, headword: `word${i}` }))
    );
    vi.mocked(getTopics).mockResolvedValue([]);
    vi.mocked(generateContent).mockResolvedValue({
      text: JSON.stringify({
        sentences: [{ target: "A sentence.", vietnamese: "Một câu.", vocabWords: ["word0"] }],
      }),
    });

    render(<BilingualReadingPage />);
    fireEvent.click(await screen.findByRole("button", { name: "Tạo bài luyện" }));

    await waitFor(() =>
      expect(screen.queryByRole("button", { name: "Tạo bài luyện" })).not.toBeInTheDocument()
    );
    const promptArg = vi.mocked(generateContent).mock.calls[0][0].prompt;
    expect(promptArg).toContain("word0");
  });

  it("shows an error and stays on setup when the active provider has no API key", async () => {
    mockSignedIn({
      ...DEFAULT_SETTINGS,
      activeProvider: "gemini",
      providers: { ...DEFAULT_SETTINGS.providers, gemini: { model: "gemini-2.5-flash", apiKeyCiphertext: null } },
    });
    vi.mocked(getVocabRecords).mockResolvedValue(
      Array.from({ length: 5 }, (_, i) => makeRecord({ id: `w${i}`, headword: `word${i}` }))
    );
    vi.mocked(getTopics).mockResolvedValue([]);

    render(<BilingualReadingPage />);
    fireEvent.click(await screen.findByRole("button", { name: "Tạo bài luyện" }));

    expect(
      await screen.findByText("Chưa có API key cho nhà cung cấp AI đang chọn — vào Cài đặt để thêm.")
    ).toBeInTheDocument();
    expect(generateContent).not.toHaveBeenCalled();
  });

  it("shows an error and stays on setup when the AI returns no usable sentences", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue(
      Array.from({ length: 5 }, (_, i) => makeRecord({ id: `w${i}`, headword: `word${i}` }))
    );
    vi.mocked(getTopics).mockResolvedValue([]);
    vi.mocked(generateContent).mockResolvedValue({ text: JSON.stringify({}) });

    render(<BilingualReadingPage />);
    fireEvent.click(await screen.findByRole("button", { name: "Tạo bài luyện" }));

    expect(await screen.findByText("AI không trả về đoạn văn hợp lệ.")).toBeInTheDocument();
    expect(await screen.findByRole("button", { name: "Tạo bài luyện" })).toBeInTheDocument();
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm --prefix apps/web test -- "reading/bilingual/page"`
Expected: FAIL — `apps/web/src/app/(app)/reading/bilingual/page.tsx` does not exist yet.

- [ ] **Step 3: Implement**

Create `apps/web/src/app/(app)/reading/bilingual/page.tsx`:

```tsx
"use client";

import { useEffect, useState } from "react";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettingsContext } from "@/lib/SettingsContext";
import { SignInButton } from "@/components/SignInButton";
import { getVocabRecords, type VocabRecord } from "@/lib/vocabRecords";
import { getTopics, type Topic } from "@/lib/topics";
import { TopicFilterPopover } from "@/components/vocab-bank/TopicFilterPopover";
import { SimpleDropdown, type SimpleDropdownOption } from "@/components/shared/SimpleDropdown";
import { selectSessionWords, type SessionWordFilters } from "@/lib/practiceSession";
import {
  buildReadingPassagePrompt,
  parseReadingPassage,
  type ReadingPassage,
} from "@/lib/readingPassage";
import { generateContent } from "@/lib/generateContent";
import { parseAiJsonObject } from "@/lib/parseAiJson";

type CefrLevel = VocabRecord["cefrLevel"];
const CEFR_LEVELS: CefrLevel[] = ["a1", "a2", "b1", "b2", "c1", "c2"];
const WORD_COUNT_OPTIONS = [5, 10, 20, null] as const;
const DEFAULT_WORD_COUNT = 10;
const MIN_VOCAB_WORDS = 5;

const CEFR_DROPDOWN_OPTIONS: SimpleDropdownOption<string>[] = [
  { value: "", label: "Mọi trình độ" },
  ...CEFR_LEVELS.map((level) => ({ value: level as string, label: `Tối đa ${level.toUpperCase()}` })),
];

const WORD_COUNT_DROPDOWN_OPTIONS: SimpleDropdownOption<string>[] = WORD_COUNT_OPTIONS.map((count) => ({
  value: count === null ? "all" : String(count),
  label: count === null ? "Tất cả" : `${count} từ`,
}));

type Phase = "setup" | "session" | "result";

export default function BilingualReadingPage() {
  const { user, loading: authLoading } = useAuthUser();
  const { settings, loading: settingsLoading } = useSettingsContext();

  const [records, setRecords] = useState<VocabRecord[] | null>(null);
  const [topics, setTopics] = useState<Topic[]>([]);
  const [loadError, setLoadError] = useState<string | null>(null);

  const [selectedTopicIds, setSelectedTopicIds] = useState<Set<string>>(new Set());
  const [maxCefr, setMaxCefr] = useState<CefrLevel | null>(null);
  const [wordCount, setWordCount] = useState<number | null>(DEFAULT_WORD_COUNT);

  const [phase, setPhase] = useState<Phase>("setup");
  const [generating, setGenerating] = useState(false);
  const [generateError, setGenerateError] = useState<string | null>(null);
  const [passage, setPassage] = useState<ReadingPassage | null>(null);

  useEffect(() => {
    if (!user) return;
    setLoadError(null);
    Promise.all([getVocabRecords(user.uid), getTopics(user.uid)])
      .then(([r, t]) => {
        setRecords(r);
        setTopics(t);
      })
      .catch((err: unknown) => setLoadError(err instanceof Error ? err.message : String(err)));
  }, [user]);

  async function handleGenerate() {
    if (!records || !user || !settings) return;
    const filters: SessionWordFilters = { topicIds: selectedTopicIds, maxCefr, count: wordCount };
    const words = selectSessionWords(records, filters);
    if (words.length === 0) return;

    const activeConfig = settings.providers[settings.activeProvider];
    if (!activeConfig.apiKeyCiphertext) {
      setGenerateError("Chưa có API key cho nhà cung cấp AI đang chọn — vào Cài đặt để thêm.");
      return;
    }

    setGenerating(true);
    setGenerateError(null);
    try {
      const prompt = buildReadingPassagePrompt(
        words.map((w) => w.headword),
        settings.targetLanguage,
        maxCefr
      );
      const response = await generateContent({
        provider: settings.activeProvider,
        model: activeConfig.model,
        apiKeyCiphertext: activeConfig.apiKeyCiphertext,
        prompt,
      });
      const json = parseAiJsonObject(response.text);
      const generated = parseReadingPassage(json, words);
      if (generated.sentences.length === 0) {
        throw new Error("AI không trả về đoạn văn hợp lệ.");
      }
      setPassage(generated);
      setPhase("session");
    } catch (err) {
      setGenerateError(err instanceof Error ? err.message : String(err));
    } finally {
      setGenerating(false);
    }
  }

  if (authLoading) return <p>Đang tải…</p>;

  if (!user) {
    return (
      <div>
        <h2 className="scr-title">Đọc &amp; gõ</h2>
        <p className="scr-sub">Đăng nhập để luyện đọc.</p>
        <SignInButton />
      </div>
    );
  }

  if (settingsLoading || !settings) return <p>Đang tải…</p>;
  if (loadError) return <p role="alert">Lỗi: {loadError}</p>;
  if (records === null) return <p>Đang tải từ vựng…</p>;

  if (phase === "setup") {
    // count: null bypasses truncation so this reflects every matching word,
    // not just the ones a fixed session size would keep.
    const matchingCount = selectSessionWords(records, {
      topicIds: selectedTopicIds,
      maxCefr,
      count: null,
    }).length;
    const canGenerate = matchingCount >= MIN_VOCAB_WORDS;

    return (
      <div>
        <h2 className="scr-title">Đọc &amp; gõ</h2>
        <p className="scr-sub">Chọn bộ lọc rồi tạo bài luyện từ từ vựng của bạn.</p>
        <div className="practice-filters">
          <TopicFilterPopover
            topics={topics}
            selectedTopicIds={selectedTopicIds}
            onApply={setSelectedTopicIds}
          />
          <SimpleDropdown
            triggerLabel={maxCefr ? `Tối đa ${maxCefr.toUpperCase()}` : "Mọi trình độ"}
            ariaLabel="Chọn trình độ tối đa"
            options={CEFR_DROPDOWN_OPTIONS}
            value={maxCefr ?? ""}
            onChange={(v) => setMaxCefr((v || null) as CefrLevel | null)}
            active={maxCefr !== null}
          />
          <SimpleDropdown
            triggerLabel={wordCount === null ? "Tất cả" : `${wordCount} từ`}
            ariaLabel="Chọn số từ"
            options={WORD_COUNT_DROPDOWN_OPTIONS}
            value={wordCount === null ? "all" : String(wordCount)}
            onChange={(v) => setWordCount(v === "all" ? null : Number(v))}
            active={wordCount !== DEFAULT_WORD_COUNT}
          />
        </div>
        {canGenerate ? (
          <button className="btn-primary" onClick={() => void handleGenerate()} disabled={generating}>
            {generating ? "Đang tạo bài…" : "Tạo bài luyện"}
          </button>
        ) : (
          <p className="reading-min-words-hint">
            Hãy lưu ít nhất {MIN_VOCAB_WORDS} từ khớp với bộ lọc trên vào Ngân hàng từ vựng. Hiện có{" "}
            {matchingCount} từ.
          </p>
        )}
        {generateError && <p role="alert">{generateError}</p>}
      </div>
    );
  }

  // "session"/"result" phases wired in Tasks 9-10.
  return null;
}
```

- [ ] **Step 4: Append CSS**

Modify `apps/web/src/styles/bloom.css` — append at the end:

```css

.reading-min-words-hint {
  color: var(--ink-soft);
  font-size: 13px;
  max-width: 460px;
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `npm --prefix apps/web test -- "reading/bilingual/page"`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add "apps/web/src/app/(app)/reading/bilingual" apps/web/src/styles/bloom.css
git commit -m "feat(web): add Đọc & gõ session setup screen (filters, min-words gate, passage generation)"
```

---

## Task 9: `/reading/bilingual` page — typing session loop

**Files:**
- Modify: `apps/web/src/app/(app)/reading/bilingual/page.tsx`
- Modify: `apps/web/src/app/(app)/reading/bilingual/page.test.tsx`

**Interfaces:**
- Consumes: `TypingSentence` (`@/components/reading/TypingSentence`, Task 5, rendered without a `key` prop across sentences — same reasoning as `FlashcardCard` in the Ôn tập plan: `TypingSentence` itself holds no internal state that would break on reuse, but there is no reason to force a remount either), `computeSentenceStats`/`SentenceStats` (`@/lib/readingScoring`, Task 2).
- Produces: `completedStats: SentenceStats[]` state, populated one entry per finished sentence — Task 10 (result phase) reads this directly, no re-derivation.

Deletion tracking: whenever the typed value's length shrinks compared to the previous value, the shrink amount is added to a running `deletedChars` count for the *current sentence only* (reset to 0 when advancing to the next sentence) — this covers a single backspace and a select-all-and-retype identically, matching `reading_practice_provider.dart`'s tracking. The new deleted-char total is computed as a local variable before any state update, so the very keystroke that completes a sentence still gets its own deletion correctly counted in that sentence's final stats (state updates are async/batched — reading `deletedChars` state itself inside the same handler call would see the stale pre-keystroke value).

- [ ] **Step 1: Write the failing test**

Add these imports to the top of `apps/web/src/app/(app)/reading/bilingual/page.test.tsx` (alongside the existing ones):

```tsx
import { waitFor } from "@testing-library/react";
```

(If `waitFor` is already imported from `@testing-library/react` in this file's existing import line, add it there instead of a separate line — check the file first.)

Add this new `describe` block at the end of the file:

```tsx
describe("BilingualReadingPage (typing session)", () => {
  it("shows the current sentence's progress and Vietnamese translation, advancing on exact match", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue(
      Array.from({ length: 5 }, (_, i) => makeRecord({ id: `w${i}`, headword: `word${i}` }))
    );
    vi.mocked(getTopics).mockResolvedValue([]);
    vi.mocked(generateContent).mockResolvedValue({
      text: JSON.stringify({
        sentences: [
          { target: "Hi.", vietnamese: "Chào.", vocabWords: [] },
          { target: "Bye.", vietnamese: "Tạm biệt.", vocabWords: [] },
        ],
      }),
    });

    render(<BilingualReadingPage />);
    fireEvent.click(await screen.findByRole("button", { name: "Tạo bài luyện" }));

    expect(await screen.findByText("Câu 1 / 2")).toBeInTheDocument();
    expect(screen.getByText("Chào.")).toBeInTheDocument();

    const input = screen.getByTestId("reading-type-input");
    fireEvent.change(input, { target: { value: "Hi." } });

    expect(await screen.findByText("Câu 2 / 2")).toBeInTheDocument();
    expect(screen.getByText("Tạm biệt.")).toBeInTheDocument();
    expect(screen.getByTestId("reading-type-input")).toHaveValue("");
  });

  it("transitions past the session UI once the last sentence is typed correctly", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue(
      Array.from({ length: 5 }, (_, i) => makeRecord({ id: `w${i}`, headword: `word${i}` }))
    );
    vi.mocked(getTopics).mockResolvedValue([]);
    vi.mocked(generateContent).mockResolvedValue({
      text: JSON.stringify({ sentences: [{ target: "Hi.", vietnamese: "Chào.", vocabWords: [] }] }),
    });

    render(<BilingualReadingPage />);
    fireEvent.click(await screen.findByRole("button", { name: "Tạo bài luyện" }));
    await screen.findByText("Câu 1 / 1");

    fireEvent.change(screen.getByTestId("reading-type-input"), { target: { value: "Hi." } });

    await waitFor(() => expect(screen.queryByTestId("reading-type-input")).not.toBeInTheDocument());
  });

  it("does not advance while the typed value only partially matches the target", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue(
      Array.from({ length: 5 }, (_, i) => makeRecord({ id: `w${i}`, headword: `word${i}` }))
    );
    vi.mocked(getTopics).mockResolvedValue([]);
    vi.mocked(generateContent).mockResolvedValue({
      text: JSON.stringify({
        sentences: [
          { target: "Hi there.", vietnamese: "Chào bạn.", vocabWords: [] },
          { target: "Bye.", vietnamese: "Tạm biệt.", vocabWords: [] },
        ],
      }),
    });

    render(<BilingualReadingPage />);
    fireEvent.click(await screen.findByRole("button", { name: "Tạo bài luyện" }));
    await screen.findByText("Câu 1 / 2");

    fireEvent.change(screen.getByTestId("reading-type-input"), { target: { value: "Hi " } });

    expect(screen.getByText("Câu 1 / 2")).toBeInTheDocument();
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm --prefix apps/web test -- "reading/bilingual/page"`
Expected: FAIL — `phase === "session"` currently renders nothing (Task 8 left it as `return null`).

- [ ] **Step 3: Implement the session phase**

Modify `apps/web/src/app/(app)/reading/bilingual/page.tsx`. First, update the imports — replace:

```tsx
import { useEffect, useState } from "react";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettingsContext } from "@/lib/SettingsContext";
import { SignInButton } from "@/components/SignInButton";
import { getVocabRecords, type VocabRecord } from "@/lib/vocabRecords";
import { getTopics, type Topic } from "@/lib/topics";
import { TopicFilterPopover } from "@/components/vocab-bank/TopicFilterPopover";
import { SimpleDropdown, type SimpleDropdownOption } from "@/components/shared/SimpleDropdown";
import { selectSessionWords, type SessionWordFilters } from "@/lib/practiceSession";
import {
  buildReadingPassagePrompt,
  parseReadingPassage,
  type ReadingPassage,
} from "@/lib/readingPassage";
import { generateContent } from "@/lib/generateContent";
import { parseAiJsonObject } from "@/lib/parseAiJson";
```

with:

```tsx
import { useEffect, useState } from "react";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettingsContext } from "@/lib/SettingsContext";
import { SignInButton } from "@/components/SignInButton";
import { getVocabRecords, type VocabRecord } from "@/lib/vocabRecords";
import { getTopics, type Topic } from "@/lib/topics";
import { TopicFilterPopover } from "@/components/vocab-bank/TopicFilterPopover";
import { SimpleDropdown, type SimpleDropdownOption } from "@/components/shared/SimpleDropdown";
import { selectSessionWords, type SessionWordFilters } from "@/lib/practiceSession";
import {
  buildReadingPassagePrompt,
  parseReadingPassage,
  type ReadingPassage,
} from "@/lib/readingPassage";
import { generateContent } from "@/lib/generateContent";
import { parseAiJsonObject } from "@/lib/parseAiJson";
import { TypingSentence } from "@/components/reading/TypingSentence";
import { computeSentenceStats, type SentenceStats } from "@/lib/readingScoring";
```

Add new state (right after the existing `passage` state declaration):

```tsx
  const [passage, setPassage] = useState<ReadingPassage | null>(null);
  const [currentIndex, setCurrentIndex] = useState(0);
  const [typed, setTyped] = useState("");
  const [deletedChars, setDeletedChars] = useState(0);
  const [sentenceStartedAt, setSentenceStartedAt] = useState(0);
  const [completedStats, setCompletedStats] = useState<SentenceStats[]>([]);
```

In `handleGenerate`, reset the new session-scoped state right before entering the session phase — replace:

```tsx
      setPassage(generated);
      setPhase("session");
```

with:

```tsx
      setPassage(generated);
      setCurrentIndex(0);
      setTyped("");
      setDeletedChars(0);
      setSentenceStartedAt(Date.now());
      setCompletedStats([]);
      setPhase("session");
```

Add a new `handleTypedChange` function (right after `handleGenerate`):

```tsx
  function handleTypedChange(value: string) {
    const newDeletedChars =
      value.length < typed.length ? deletedChars + (typed.length - value.length) : deletedChars;
    setTyped(value);
    setDeletedChars(newDeletedChars);

    if (!passage) return;
    const target = passage.sentences[currentIndex].target;
    if (value !== target) return;

    const durationMs = Date.now() - sentenceStartedAt;
    const stats = computeSentenceStats(target, value, newDeletedChars, durationMs);
    setCompletedStats((prev) => [...prev, stats]);

    if (currentIndex + 1 < passage.sentences.length) {
      setCurrentIndex(currentIndex + 1);
      setTyped("");
      setDeletedChars(0);
      setSentenceStartedAt(Date.now());
    } else {
      setPhase("result");
    }
  }
```

Finally, replace the closing `// "session"/"result" phases wired in Tasks 9-10.\n  return null;` with the session-phase render:

```tsx
  if (phase === "session" && passage) {
    const currentSentence = passage.sentences[currentIndex];
    const completedSentences = passage.sentences.slice(0, currentIndex).map((s) => s.target);
    const progressPct = Math.round(((currentIndex + 1) / passage.sentences.length) * 100);

    return (
      <div>
        <div className="practice-progress-row">
          <span>
            Câu {currentIndex + 1} / {passage.sentences.length}
          </span>
          <span>Đọc &amp; gõ</span>
        </div>
        <div className="practice-progress-track">
          <div className="practice-progress-fill" style={{ width: `${progressPct}%` }} />
        </div>
        <TypingSentence
          completedSentences={completedSentences}
          currentSentence={currentSentence}
          typed={typed}
          onTypedChange={handleTypedChange}
        />
      </div>
    );
  }

  // "result" phase wired in Task 10.
  return null;
}
```

(This replaces everything from the `if (phase === "setup")` block's closing `}` through the end of the file — the `if (phase === "setup")` block itself is unchanged.)

- [ ] **Step 4: Run test to verify it passes**

Run: `npm --prefix apps/web test -- "reading/bilingual/page"`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add "apps/web/src/app/(app)/reading/bilingual"
git commit -m "feat(web): wire the Đọc & gõ typing session loop (TypingSentence, deletion tracking)"
```

---

## Task 10: `/reading/bilingual` page — result phase

**Files:**
- Modify: `apps/web/src/app/(app)/reading/bilingual/page.tsx`
- Modify: `apps/web/src/app/(app)/reading/bilingual/page.test.tsx`
- Modify: `apps/web/src/styles/bloom.css` (append `.reading-result-*`/`.reading-stat-*`/`.reading-used-words*` CSS)

**Interfaces:**
- Consumes: `aggregateSentenceStats` (`@/lib/readingScoring`, Task 2), `VocabSuggestionsSection` (`@/components/shared/VocabSuggestionsSection`, Task 6), `useRouter` (`next/navigation` — new to this codebase; no prior page uses client-side navigation via router, App Router's `<Link>` is used everywhere else, but "Về trang chính" needs a plain `<button>` here since `.btn-secondary`'s CSS selector (`button.btn-secondary`) is scoped to the `<button>` tag, not `<a>`).
- Produces: nothing further — this is the last task in the plan. **Correction from the design spec's own wording**: spec §3.3 analogized "Sinh bài mới" to Ôn tập's "Ôn tập lại ngay" (which regenerates immediately, skipping setup). Re-checking Flutter's actual `ReadingResultScreen` (research notes, §1/§4) shows "Sinh bài mới" literally "resets provider, back to home" — i.e. it returns to the **setup phase** (filters still selected, since filter state is untouched), not an instant regenerate. This task follows the verified Flutter behavior, not the spec's imprecise analogy.

- [ ] **Step 1: Write the failing test**

First, mock `next/navigation` and `VocabSuggestionsSection` at the top of `apps/web/src/app/(app)/reading/bilingual/page.test.tsx`, alongside the existing `vi.mock` calls:

```tsx
const pushMock = vi.fn();
vi.mock("next/navigation", () => ({ useRouter: () => ({ push: pushMock }) }));
vi.mock("@/components/shared/VocabSuggestionsSection", () => ({
  VocabSuggestionsSection: ({ text }: { text: string }) => (
    <div data-testid="vocab-suggestions" data-text={text} />
  ),
}));
```

Add this new `describe` block at the end of the file:

```tsx
describe("BilingualReadingPage (result phase)", () => {
  async function completeASession() {
    vi.mocked(generateContent).mockResolvedValue({
      text: JSON.stringify({
        sentences: [
          { target: "Hi there.", vietnamese: "Chào bạn.", vocabWords: ["word0"] },
          { target: "Bye now.", vietnamese: "Tạm biệt.", vocabWords: [] },
        ],
      }),
    });
    render(<BilingualReadingPage />);
    fireEvent.click(await screen.findByRole("button", { name: "Tạo bài luyện" }));
    await screen.findByText("Câu 1 / 2");
    fireEvent.change(screen.getByTestId("reading-type-input"), { target: { value: "Hi there." } });
    await screen.findByText("Câu 2 / 2");
    fireEvent.change(screen.getByTestId("reading-type-input"), { target: { value: "Bye now." } });
    await waitFor(() => expect(screen.queryByTestId("reading-type-input")).not.toBeInTheDocument());
  }

  it("shows 4 stat cards, the vocab words used, and the suggestions section", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue(
      Array.from({ length: 5 }, (_, i) => makeRecord({ id: `w${i}`, headword: `word${i}` }))
    );
    vi.mocked(getTopics).mockResolvedValue([]);

    await completeASession();

    expect(screen.getByText("Độ chính xác")).toBeInTheDocument();
    expect(screen.getByText("Tốc độ")).toBeInTheDocument();
    expect(screen.getByText("Thời gian")).toBeInTheDocument();
    expect(screen.getByText("Điểm")).toBeInTheDocument();
    expect(screen.getByText("100%")).toBeInTheDocument(); // accuracy AND score, both 100%

    expect(screen.getByText(/word0/)).toBeInTheDocument();

    const suggestions = screen.getByTestId("vocab-suggestions");
    expect(suggestions).toHaveAttribute("data-text", "Hi there. Bye now.");
  });

  it('"Sinh bài mới" resets and returns to the setup phase with filters still selected', async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue(
      Array.from({ length: 5 }, (_, i) => makeRecord({ id: `w${i}`, headword: `word${i}` }))
    );
    vi.mocked(getTopics).mockResolvedValue([]);

    await completeASession();
    fireEvent.click(screen.getByRole("button", { name: "Sinh bài mới" }));

    expect(await screen.findByRole("button", { name: "Tạo bài luyện" })).toBeInTheDocument();
  });

  it('"Về trang chính" navigates back to the reading hub', async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue(
      Array.from({ length: 5 }, (_, i) => makeRecord({ id: `w${i}`, headword: `word${i}` }))
    );
    vi.mocked(getTopics).mockResolvedValue([]);

    await completeASession();
    fireEvent.click(screen.getByRole("button", { name: "Về trang chính" }));

    expect(pushMock).toHaveBeenCalledWith("/reading");
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm --prefix apps/web test -- "reading/bilingual/page"`
Expected: FAIL — `phase === "result"` currently renders nothing (Task 9 left it as `return null`).

- [ ] **Step 3: Implement the result phase**

Modify `apps/web/src/app/(app)/reading/bilingual/page.tsx`. First, update the imports — add these two lines to the existing import block:

```tsx
import { useRouter } from "next/navigation";
import { aggregateSentenceStats } from "@/lib/readingScoring";
import { VocabSuggestionsSection } from "@/components/shared/VocabSuggestionsSection";
```

Add a new exported interface right after the existing `type Phase = "setup" | "session" | "result";` line — this documents the exact shape a future streak feature would consume (design spec §3.3), the same way `SessionGradeResult` was exported from `practice/page.tsx` for Ôn tập before anything actually read it:

```tsx
type Phase = "setup" | "session" | "result";

export interface ReadingSessionResult {
  vocabIds: string[];
  accuracy: number;
  completedAt: string;
}
```

Add `const router = useRouter();` right after the `useSettingsContext()` line:

```tsx
  const { settings, loading: settingsLoading } = useSettingsContext();
  const router = useRouter();
```

Add a `formatDuration` helper and a `handleNewPassage` function (right after `handleTypedChange`):

```tsx
  function formatDuration(ms: number): string {
    const totalSeconds = Math.round(ms / 1000);
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;
    return `${minutes}:${String(seconds).padStart(2, "0")}`;
  }

  function handleNewPassage() {
    setPassage(null);
    setCurrentIndex(0);
    setTyped("");
    setDeletedChars(0);
    setCompletedStats([]);
    setGenerateError(null);
    setPhase("setup");
  }
```

Finally, replace the closing `// "result" phase wired in Task 10.\n  return null;\n}` with:

```tsx
  const stats = aggregateSentenceStats(completedStats);
  const totalDurationMs = completedStats.reduce((sum, s) => sum + s.durationMs, 0);
  const usedRecords = (records ?? []).filter((r) => passage?.vocabIds.includes(r.id));
  const fullText = (passage?.sentences ?? []).map((s) => s.target).join(" ");
  // Streak-hook shape (design spec §3.3) — Dashboard/streak is its own
  // deferred phase and nothing writes this anywhere yet, but every piece a
  // future feature would need is right here: passage?.vocabIds (already
  // computed above as usedRecords' source), stats.overallAccuracy, and
  // `new Date().toISOString()` at this exact point in time. See
  // ReadingSessionResult below for the exact shape that data would take.

  return (
    <div>
      <h2 className="scr-title">Kết quả</h2>
      <div className="reading-result-stats">
        <div className="reading-stat-card">
          <span className="reading-stat-label">Độ chính xác</span>
          <span className="reading-stat-value">{Math.round(stats.overallAccuracy * 100)}%</span>
        </div>
        <div className="reading-stat-card">
          <span className="reading-stat-label">Tốc độ</span>
          <span className="reading-stat-value">{Math.round(stats.wpm)} wpm</span>
        </div>
        <div className="reading-stat-card">
          <span className="reading-stat-label">Thời gian</span>
          <span className="reading-stat-value">{formatDuration(totalDurationMs)}</span>
        </div>
        <div className="reading-stat-card">
          <span className="reading-stat-label">Điểm</span>
          <span className="reading-stat-value">{Math.round(stats.finalScore * 100)}%</span>
        </div>
      </div>
      {usedRecords.length > 0 && (
        <div className="reading-used-words">
          <h3>Từ vựng dùng trong bài</h3>
          {usedRecords.map((r) => (
            <p className="reading-used-word-item" key={r.id}>
              {r.headword} — {r.meaning}
            </p>
          ))}
        </div>
      )}
      <VocabSuggestionsSection text={fullText} existingRecords={records ?? []} topics={topics} />
      <div className="reading-result-actions">
        <button type="button" className="btn-secondary" onClick={() => router.push("/reading")}>
          Về trang chính
        </button>
        <button type="button" className="btn-primary" onClick={handleNewPassage}>
          Sinh bài mới
        </button>
      </div>
    </div>
  );
}
```

- [ ] **Step 4: Append CSS**

Modify `apps/web/src/styles/bloom.css` — append at the end:

```css

.reading-result-stats {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(120px, 1fr));
  gap: 10px;
  max-width: 640px;
  margin: 16px 0 24px;
}

.reading-stat-card {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 14px;
  padding: 14px 16px;
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.reading-stat-label {
  font-size: 11.5px;
  color: var(--ink-faint);
  text-transform: uppercase;
  letter-spacing: 0.04em;
  font-weight: 700;
}

.reading-stat-value {
  font-size: 20px;
  font-weight: 700;
  color: var(--ink);
}

.reading-used-words {
  max-width: 640px;
  margin-bottom: 8px;
}

.reading-used-words h3 {
  font-size: 13px;
  margin: 0 0 8px;
}

.reading-used-word-item {
  font-size: 13px;
  color: var(--ink-soft);
  margin: 0 0 4px;
}

.reading-result-actions {
  display: flex;
  gap: 10px;
  margin-top: 20px;
  max-width: 640px;
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `npm --prefix apps/web test -- "reading/bilingual/page"`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add "apps/web/src/app/(app)/reading/bilingual" apps/web/src/styles/bloom.css
git commit -m "feat(web): add Đọc & gõ result screen (stats, vocab used, suggestions)"
```

---

## Self-Review

**1. Spec coverage.**

- §3.1 screen flow (hub → setup → session → result) — Tasks 7, 8, 9, 10.
- §3.1 typing-feedback UI (passage with live color-coded current sentence, Vietnamese-of-current-sentence row, single plain input, no overlay/no `contentEditable`) — Task 5, confirmed against the visual-companion-validated design.
- §3.1 min-5-words gate, exact Flutter wording — Task 8.
- §3.1 due-word-preferred selection reusing `selectSessionWords` — Task 8, no reimplementation.
- §3.2 scoring (per-sentence correctChars/deletedChars, deletion-ratio penalty, wpm) — Task 2 (pure logic) + Task 9 (wiring deletion tracking per keystroke) + Task 10 (aggregate display).
- §3.3 result screen (4 stat cards, vocab-used list, suggestions, 2 buttons) — Task 10. **Gap found during self-review and fixed inline**: the spec's streak-hook shape (`{ vocabIds, accuracy, completedAt }`) was never actually represented anywhere in the original Task 10 draft — added as an exported `ReadingSessionResult` interface (matching the precedent `SessionGradeResult` set in the Ôn tập plan) plus a comment pointing at exactly where its three pieces of data already live in scope, rather than inventing an unused local variable that would itself be a lint problem.
- §3.3 "Sinh bài mới" behavior — **corrected during self-review**: the spec's own text analogized this button to Ôn tập's instant-regenerate "Ôn tập lại ngay", but re-checking the actual Flutter source (already gathered during research, before the spec was written) shows "Sinh bài mới" resets and returns to the **setup phase**, not an instant regenerate. Task 10 implements the verified Flutter behavior; the spec's analogy was imprecise and is superseded by this plan.
- §3.4 `VocabSuggestionsSection` (full `WordPhraseResult` per suggestion in one call, tap-to-save via `EditVocabModal`, "Lưu tất cả", dismiss, retry-on-error, hidden when AI unavailable) — Task 6, all covered including the corrected "scans the passage for up to 10 words already in it" mechanic (not "invent N words") verified against `word_radar_source.dart` during spec-writing.
- §3.5 data layer (`readingPassage.ts`, `vocabSuggestions.ts`, `readingScoring.ts`) — Tasks 1, 2, 3.
- Global Constraints (Vietnamese-only text, `@/` alias, colocated tests, zero SM-2 writes, zero streak/Firestore writes, min-5-words gate, one-call vocab suggestions) — checked against every task; none violated.

No further gaps found.

**2. Placeholder scan.** Searched all 10 tasks for "TBD"/"TODO"/"implement later"/"add appropriate error handling"/"similar to Task N"-style shortcuts. None found — every step has complete, runnable code including full test bodies and full CSS blocks. The one intentionally-incomplete-looking thing (`ReadingSessionResult` computed nowhere, only typed) is deliberate and explained inline, not a placeholder.

**3. Type consistency.** Traced identifiers across task boundaries:

- `BilingualSentence`/`ReadingPassage` (Task 1) — same field names (`target`, `vietnamese`, `vocabWords`, `sentences`, `vocabIds`) used identically in Tasks 8, 9, 10.
- `SentenceStats`/`computeSentenceStats` (Task 2) — Task 9 calls it with `(target, typed, deletedChars, durationMs)`, matching Task 2's exact signature. `aggregateSentenceStats` (Task 2) — Task 10 calls it with `completedStats: SentenceStats[]`, matching.
- `WordPhraseResult` (existing `@/lib/lookup`) — Task 3's `parseVocabSuggestions` returns `WordPhraseResult[]`, consumed identically by Task 6.
- `buildVocabRecordDraft(result, topics, targetLanguage)` (Task 4) — called identically in the refactored `lookup/page.tsx` and in Task 6's `VocabSuggestionsSection` (both single-save and bulk-save paths).
- `TypingSentence`'s props (Task 5: `completedSentences`, `currentSentence`, `typed`, `onTypedChange`) — Task 9 passes all four with matching types, no `key` prop (consistent with the established no-remount reasoning from the Ôn tập plan, restated here since `TypingSentence` has no internal state of its own that a remount would threaten — included for consistency, not because it's load-bearing here the way it was for `FlashcardCard`).
- `VocabSuggestionsSection`'s props (Task 6: `text`, `existingRecords`, `topics`) — Task 10 passes all three with matching types.
- `SimpleDropdown`/`SimpleDropdownOption` (existing, from the Cài đặt/Ôn tập plan) — Task 8's usage matches the component's actual current props exactly (`triggerLabel`, `ariaLabel`, `options`, `value`, `onChange`, `active`), verified by reading the live file before writing this plan, not from memory.
- `selectSessionWords`/`SessionWordFilters` (existing, from the Ôn tập plan) — Task 8 reuses both unchanged, verified by reading the live file.

No mismatches found.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-08-18-react-web-plan3-phase-c-reading-typing.md`. Two execution options:

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**
