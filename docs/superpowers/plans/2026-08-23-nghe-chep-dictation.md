# Nghe chép (Dictation) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring Flutter's "Nghe chép" (Dictation) exercise to the web app: AI generates one sentence from 2 due-priority Vocab Bank words, the user listens (via a new TTS client wrapper around the already-live `synthesizeSpeech` Cloud Function) and types back what they hear at one of three difficulty levels, with save/reuse support from day one.

**Architecture:** A new `apps/web/src/lib/synthesizeSpeechClient.ts` wraps the existing `synthesizeSpeech` Cloud Function (the first audio-producing client wrapper in this codebase). `apps/web/src/lib/dictation.ts` holds every pure domain function ported from Flutter's `DictationSource`/`SelectDictationBlanksUseCase`/`DictationSessionResult` (prompt building, parsing, blank selection, scoring — all exact ports of the algorithms in `lib/features/listening/`, verified against that source during brainstorming). A new `apps/web/src/lib/savedListeningExercises.ts` is a parallel, independent save/reuse module (not a `SavedReadingExercise` union member — a dictation item's shape has nothing in common with a reading passage). A new `useDictationAudio` hook encapsulates all `<audio>` element state (play/replay/speed/seek), calling `synthesizeSpeech` fresh for the initial clip and for each seek (Piper's WAV response carries no word-timing metadata, so seeking is reimplemented as "re-synthesize from word N onward," not true in-clip scrubbing). `/listening` is a new hub (single dictation card for now); `/listening/dictation` is the session/result page, following the same `useSearchParams()`+`Suspense` auto-trigger pattern every reading page already uses.

**Tech Stack:** Next.js 16 (App Router) on `apps/web/`, React 19, Firebase JS SDK v12 (Auth/Firestore/Functions), Vitest + React Testing Library + jsdom.

## Global Constraints

- All user-facing text is Vietnamese, matching every existing screen.
- Import alias `@/` maps to `apps/web/src/`.
- Every new/changed file's tests are updated/added to match.
- Nghe chép only works when `settings.targetLanguage === "english"` — `synthesizeSpeech`'s backend (self-hosted Piper) only supports `"vi" | "en"`, and Vietnamese is never the *learned* language in this app. When the target language isn't English, the hub page shows a blocking Vietnamese message and renders neither action button — no generation is attempted.
- `synthesizeSpeech`'s Cloud Function request shape is `{ text: string (≤500 chars, enforced server-side), language: "vi" | "en" }`, response `{ audioBase64: string }`. Its Cloud Run backend responds with `Content-Type: audio/wav` (confirmed by reading `functions/src/services/cloudRunClient.ts` during brainstorming) — client code must build `data:audio/wav;base64,...` URLs, not assume another format.
- No audio is ever persisted to Firestore/Storage for this feature — "Lấy bài có sẵn" re-fetches the saved `{target, vietnamese, vocabIds}` and calls `synthesizeSpeech` fresh, identical to a freshly-generated item's own first playback.
- The scoring formulas in this plan (char/block accuracy, seek penalty, final score, SM-2 quality mapping) are exact ports of `lib/features/listening/presentation/providers/dictation_practice_provider.dart`, verified against that file during brainstorming — do not "simplify" or "improve" them; use the exact constants given.
- Verify each task with `npm --prefix apps/web test` (full suite) and finish the plan with `npx tsc --noEmit -p apps/web/tsconfig.json` and `npm --prefix apps/web run build`.
- One pre-existing, unrelated test failure is expected in `src/styles/bloom.test.ts` (an `.app-frame` CSS-lock assertion) — not something any task here should fix. An occasional flaky test timeout under full-suite load on Windows is also known and unrelated — re-run any timing-out file alone before concluding anything is wrong.
- Spec: `docs/superpowers/specs/2026-08-23-nghe-chep-dictation-design.md` — read it if anything below is ambiguous.

---

## Task 1: `synthesizeSpeechClient.ts` — TTS Cloud Function client wrapper

**Files:**
- Create: `apps/web/src/lib/synthesizeSpeechClient.ts`
- Create: `apps/web/src/lib/synthesizeSpeechClient.test.ts`

**Interfaces:**
- Produces (used by Task 4): `function synthesizeSpeech(request: { text: string; language: "vi" | "en" }): Promise<{ audioBase64: string }>`, `function toAudioDataUrl(audioBase64: string): string`.

- [ ] **Step 1: Write the failing tests**

Create `apps/web/src/lib/synthesizeSpeechClient.test.ts`:

```ts
import { describe, expect, it, vi } from "vitest";
import { httpsCallable } from "firebase/functions";
import { synthesizeSpeech, toAudioDataUrl } from "./synthesizeSpeechClient";

vi.mock("firebase/functions", () => ({
  httpsCallable: vi.fn(),
}));
vi.mock("./firebase", () => ({
  getFirebaseFunctions: vi.fn(() => "mock-functions"),
}));

describe("synthesizeSpeech", () => {
  it("calls the synthesizeSpeech callable with the given text and language, and returns its data", async () => {
    const callable = vi.fn().mockResolvedValue({ data: { audioBase64: "AAAA" } });
    vi.mocked(httpsCallable).mockReturnValue(callable as never);

    const result = await synthesizeSpeech({ text: "Hello world.", language: "en" });

    expect(httpsCallable).toHaveBeenCalledWith("mock-functions", "synthesizeSpeech");
    expect(callable).toHaveBeenCalledWith({ text: "Hello world.", language: "en" });
    expect(result).toEqual({ audioBase64: "AAAA" });
  });
});

describe("toAudioDataUrl", () => {
  it("wraps a base64 string as a playable audio/wav data URL", () => {
    expect(toAudioDataUrl("AAAA")).toBe("data:audio/wav;base64,AAAA");
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd apps/web && npx vitest run --run src/lib/synthesizeSpeechClient.test.ts`
Expected: FAIL — `./synthesizeSpeechClient` doesn't exist yet.

- [ ] **Step 3: Implement `synthesizeSpeechClient.ts`**

Create `apps/web/src/lib/synthesizeSpeechClient.ts`:

```ts
import { httpsCallable } from "firebase/functions";
import { getFirebaseFunctions } from "./firebase";

// Keep this in sync with the server-side type of the same name in
// functions/src/synthesizeSpeech.ts (no shared-types package yet — same
// convention as generateContent.ts).
export interface SynthesizeSpeechRequest {
  text: string;
  language: "vi" | "en";
}

export interface SynthesizeSpeechResult {
  audioBase64: string;
}

export async function synthesizeSpeech(
  request: SynthesizeSpeechRequest
): Promise<SynthesizeSpeechResult> {
  const callable = httpsCallable<SynthesizeSpeechRequest, SynthesizeSpeechResult>(
    getFirebaseFunctions(),
    "synthesizeSpeech"
  );
  const response = await callable(request);
  return response.data;
}

// Piper's Cloud Run response is served with Content-Type: audio/wav
// (functions/src/services/cloudRunClient.ts) — every caller in this app
// builds its playable URL through this one helper so that format is never
// duplicated/guessed at call sites.
export function toAudioDataUrl(audioBase64: string): string {
  return `data:audio/wav;base64,${audioBase64}`;
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd apps/web && npx vitest run --run src/lib/synthesizeSpeechClient.test.ts`
Expected: PASS, both tests green.

- [ ] **Step 5: Typecheck**

Run: `cd apps/web && npx tsc --noEmit`
Expected: no errors.

- [ ] **Step 6: Commit**

```bash
git add apps/web/src/lib/synthesizeSpeechClient.ts apps/web/src/lib/synthesizeSpeechClient.test.ts
git commit -m "feat(web): add synthesizeSpeech Cloud Function client wrapper"
```

---

## Task 2: `dictation.ts` — generation prompt/parser, blank selection, and scoring

**Files:**
- Create: `apps/web/src/lib/dictation.ts`
- Create: `apps/web/src/lib/dictation.test.ts`

**Interfaces:**
- Consumes: `TargetLanguage` (`@/lib/languages`), `VocabRecord` (`@/lib/vocabRecords`).
- Produces (used by Tasks 3, 5, 7):
  - `type DictationDifficulty = "easy" | "medium" | "hard"`
  - `interface BlankSpan { startWordIndex: number; wordCount: number }`
  - `interface DictationItem { target: string; vietnamese: string; vocabIds: string[] }`
  - `function buildDictationPrompt(headwords: string[], targetLanguage: TargetLanguage): string`
  - `function parseDictationItem(json: Record<string, unknown>, wordMap: Record<string, string>): DictationItem`
  - `function selectDictationBlanks(sentence: string, difficulty: DictationDifficulty, random?: () => number): BlankSpan[]`
  - `function prioritizeDueWords(records: VocabRecord[], now?: Date): VocabRecord[]`
  - `function targetWords(sentence: string): string[]`
  - `function targetTextForBlank(sentence: string, blank: BlankSpan): string`
  - `function normalizeForComparison(text: string): string`
  - `function isBlankCorrect(sentence: string, blank: BlankSpan, answer: string): boolean`
  - `function charAccuracy(target: string, typed: string): number`
  - `function blockAccuracy(sentence: string, blanks: BlankSpan[], blankAnswers: string[]): number`
  - `function seekPenaltyFraction(wordIndex: number, totalWords: number): number`
  - `interface DictationScoreInput { difficulty: DictationDifficulty; target: string; typed: string; blanks: BlankSpan[]; blankAnswers: string[]; replayCount: number; seekPenaltyTotal: number }`
  - `function computeDictationScore(input: DictationScoreInput): number`
  - `function sm2QualityFromScore(score: number): number`

- [ ] **Step 1: Write the failing tests**

Create `apps/web/src/lib/dictation.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import {
  buildDictationPrompt,
  parseDictationItem,
  selectDictationBlanks,
  prioritizeDueWords,
  targetWords,
  targetTextForBlank,
  normalizeForComparison,
  isBlankCorrect,
  charAccuracy,
  blockAccuracy,
  seekPenaltyFraction,
  computeDictationScore,
  sm2QualityFromScore,
  type BlankSpan,
} from "./dictation";
import type { VocabRecord } from "./vocabRecords";

describe("buildDictationPrompt", () => {
  it("includes the target language label, the word list, and asks for one 10-18-word sentence in JSON", () => {
    const prompt = buildDictationPrompt(["apple", "run"], "english");
    expect(prompt).toContain("English");
    expect(prompt).toContain("apple, run");
    expect(prompt).toContain("10 to 18 words");
    expect(prompt).toContain("JSON only");
    expect(prompt).toContain('"target"');
    expect(prompt).toContain('"vocabWords"');
  });

  it("requires Vietnamese-script-only translations", () => {
    const prompt = buildDictationPrompt(["apple"], "english");
    expect(prompt).toContain("Vietnamese script");
  });
});

describe("parseDictationItem", () => {
  it("parses a full response and resolves vocabWords to vocabIds via the word map", () => {
    const json = { target: "I ate an apple.", vietnamese: "Tôi đã ăn một quả táo.", vocabWords: ["apple"] };
    const wordMap = { apple: "id-1", run: "id-2" };

    const result = parseDictationItem(json, wordMap);

    expect(result).toEqual({ target: "I ate an apple.", vietnamese: "Tôi đã ăn một quả táo.", vocabIds: ["id-1"] });
  });

  it("falls back to empty fields when the response is missing data", () => {
    expect(parseDictationItem({}, {})).toEqual({ target: "", vietnamese: "", vocabIds: [] });
  });

  it("drops any vocabWords entry that isn't in the word map", () => {
    const json = { target: "T", vietnamese: "V", vocabWords: ["apple", "unknown"] };
    expect(parseDictationItem(json, { apple: "id-1" }).vocabIds).toEqual(["id-1"]);
  });
});

describe("selectDictationBlanks", () => {
  it("hard difficulty returns no blanks", () => {
    expect(selectDictationBlanks("The quick brown fox jumps.", "hard")).toEqual([]);
  });

  it("easy difficulty on a single-word sentence returns one 1-word blank at index 0", () => {
    expect(selectDictationBlanks("Hello", "easy")).toEqual([{ startWordIndex: 0, wordCount: 1 }]);
  });

  it("easy difficulty returns exactly 2 single-word blanks", () => {
    const blanks = selectDictationBlanks("The quick brown fox jumps over the lazy dog", "easy", () => 0.5);
    expect(blanks).toHaveLength(2);
    for (const b of blanks) expect(b.wordCount).toBe(1);
  });

  it("easy difficulty enforces non-adjacent blanks once the sentence has 6+ words", () => {
    // 9 words -> enforceNonAdjacent, minIndex=1, maxIndex=7, range=7.
    // A deterministic random sequence that would naturally pick the same
    // index twice in a row exercises the retry loop.
    let call = 0;
    const sequence = [0, 0, 0.5];
    const random = () => sequence[Math.min(call++, sequence.length - 1)];
    const blanks = selectDictationBlanks("The quick brown fox jumps over the lazy dog", "easy", random);
    expect(blanks).toHaveLength(2);
    expect(Math.abs(blanks[1].startWordIndex - blanks[0].startWordIndex)).toBeGreaterThanOrEqual(2);
  });

  it("medium difficulty on a 3-or-fewer-word sentence blanks the whole sentence", () => {
    expect(selectDictationBlanks("Hi there", "medium")).toEqual([{ startWordIndex: 0, wordCount: 2 }]);
  });

  it("medium difficulty returns one span covering roughly 35% of the words, clamped to [2, wordCount-2]", () => {
    // 10 words -> spanLength = round(10*0.35) = 4 (already within [2, 8]).
    const blanks = selectDictationBlanks("one two three four five six seven eight nine ten", "medium", () => 0.5);
    expect(blanks).toHaveLength(1);
    expect(blanks[0].wordCount).toBe(4);
    expect(blanks[0].startWordIndex).toBeGreaterThanOrEqual(1);
    expect(blanks[0].startWordIndex + blanks[0].wordCount).toBeLessThanOrEqual(10);
  });
});

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

describe("prioritizeDueWords", () => {
  it("puts every due word ahead of every not-due word", () => {
    const now = new Date("2026-06-01T00:00:00.000Z");
    const due = makeRecord({ id: "due-1", nextReviewAt: null });
    const notDue = makeRecord({ id: "notdue-1", nextReviewAt: "2027-01-01T00:00:00.000Z" });
    const result = prioritizeDueWords([notDue, due], now);
    expect(result.map((r) => r.id)).toEqual(["due-1", "notdue-1"]);
  });

  it("keeps all records when everything is due, and all when nothing is due", () => {
    const now = new Date("2026-06-01T00:00:00.000Z");
    const allDue = [makeRecord({ id: "a", nextReviewAt: null }), makeRecord({ id: "b", nextReviewAt: null })];
    expect(prioritizeDueWords(allDue, now).map((r) => r.id).sort()).toEqual(["a", "b"]);
  });
});

describe("targetWords / targetTextForBlank", () => {
  it("splits on whitespace, dropping empty tokens", () => {
    expect(targetWords("The  quick brown")).toEqual(["The", "quick", "brown"]);
  });

  it("joins the words covered by a blank span with a single space", () => {
    const blank: BlankSpan = { startWordIndex: 1, wordCount: 2 };
    expect(targetTextForBlank("The quick brown fox", blank)).toBe("quick brown");
  });
});

describe("normalizeForComparison / isBlankCorrect", () => {
  it("lowercases, trims, collapses whitespace, and strips edge punctuation per word", () => {
    expect(normalizeForComparison("  Hello,   World!  ")).toBe("hello world");
  });

  it("treats an answer as correct when normalized forms match, ignoring case/punctuation/spacing", () => {
    const blank: BlankSpan = { startWordIndex: 0, wordCount: 1 };
    expect(isBlankCorrect("Apple is red.", blank, "  APPLE,  ")).toBe(true);
    expect(isBlankCorrect("Apple is red.", blank, "banana")).toBe(false);
  });
});

describe("charAccuracy", () => {
  it("is 1.0 for an exact match", () => {
    expect(charAccuracy("Hello.", "Hello.")).toBe(1);
  });

  it("counts only matching characters at the same index, over the target's full length", () => {
    // "Hxllo." vs "Hello." -> 5/6 correct.
    expect(charAccuracy("Hello.", "Hxllo.")).toBeCloseTo(5 / 6);
  });

  it("is 1.0 for an empty target (avoids division by zero)", () => {
    expect(charAccuracy("", "")).toBe(1);
  });
});

describe("blockAccuracy", () => {
  it("is 1.0 when there are no blanks", () => {
    expect(blockAccuracy("Hello world", [], [])).toBe(1);
  });

  it("is the fraction of blanks answered correctly", () => {
    const blanks: BlankSpan[] = [
      { startWordIndex: 0, wordCount: 1 },
      { startWordIndex: 1, wordCount: 1 },
    ];
    expect(blockAccuracy("Apple is red", blanks, ["apple", "wrong"])).toBe(0.5);
  });
});

describe("seekPenaltyFraction", () => {
  it("returns the minimum 0.01 when 20% or less of the sentence would be re-heard", () => {
    // 10 words, seeking to word 8 -> 2 words re-heard -> ratio 0.2.
    expect(seekPenaltyFraction(8, 10)).toBeCloseTo(0.01);
  });

  it("scales up to the maximum 0.05 when seeking back to the very start", () => {
    expect(seekPenaltyFraction(0, 10)).toBeCloseTo(0.05);
  });

  it("is 0 for a non-positive total word count", () => {
    expect(seekPenaltyFraction(0, 0)).toBe(0);
  });
});

describe("computeDictationScore", () => {
  it("hard difficulty uses charAccuracy as the raw score", () => {
    const score = computeDictationScore({
      difficulty: "hard",
      target: "Hello.",
      typed: "Hello.",
      blanks: [],
      blankAnswers: [],
      replayCount: 0,
      seekPenaltyTotal: 0,
    });
    expect(score).toBe(1);
  });

  it("non-hard difficulty uses blockAccuracy as the raw score, ignoring typed text", () => {
    const blanks: BlankSpan[] = [{ startWordIndex: 0, wordCount: 1 }];
    const score = computeDictationScore({
      difficulty: "easy",
      target: "Apple is red",
      typed: "",
      blanks,
      blankAnswers: ["apple"],
      replayCount: 0,
      seekPenaltyTotal: 0,
    });
    expect(score).toBe(1);
  });

  it("deducts 0.05 per replay and the full seekPenaltyTotal, clamped to [0, 1]", () => {
    const score = computeDictationScore({
      difficulty: "hard",
      target: "Hello.",
      typed: "Hello.",
      blanks: [],
      blankAnswers: [],
      replayCount: 3,
      seekPenaltyTotal: 0.06,
    });
    // 1.0 - 0.05*3 - 0.06 = 0.79
    expect(score).toBeCloseTo(0.79);
  });

  it("never goes below 0", () => {
    const score = computeDictationScore({
      difficulty: "hard",
      target: "Hello.",
      typed: "",
      blanks: [],
      blankAnswers: [],
      replayCount: 20,
      seekPenaltyTotal: 0,
    });
    expect(score).toBe(0);
  });
});

describe("sm2QualityFromScore", () => {
  it("maps score thresholds to the exact quality tiers Flutter uses (note: no tier '1' — jumps from 2 to 0)", () => {
    expect(sm2QualityFromScore(1.0)).toBe(5);
    expect(sm2QualityFromScore(0.95)).toBe(5);
    expect(sm2QualityFromScore(0.94)).toBe(4);
    expect(sm2QualityFromScore(0.80)).toBe(4);
    expect(sm2QualityFromScore(0.79)).toBe(3);
    expect(sm2QualityFromScore(0.60)).toBe(3);
    expect(sm2QualityFromScore(0.59)).toBe(2);
    expect(sm2QualityFromScore(0.40)).toBe(2);
    expect(sm2QualityFromScore(0.39)).toBe(0);
    expect(sm2QualityFromScore(0)).toBe(0);
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd apps/web && npx vitest run --run src/lib/dictation.test.ts`
Expected: FAIL — `./dictation` doesn't exist yet.

- [ ] **Step 3: Implement `dictation.ts`**

Create `apps/web/src/lib/dictation.ts`:

```ts
import { LANGUAGE_LABELS, type TargetLanguage } from "./languages";
import type { VocabRecord } from "./vocabRecords";

export type DictationDifficulty = "easy" | "medium" | "hard";

// Describes one blank as a range in the sentence's whitespace-tokenized word
// list: words at indices [startWordIndex, startWordIndex + wordCount) are
// hidden and must be filled in. Ports lib/features/listening/domain/entities/blank_span.dart.
export interface BlankSpan {
  startWordIndex: number;
  wordCount: number;
}

export interface DictationItem {
  target: string;
  vietnamese: string;
  vocabIds: string[];
}

// Ports lib/features/listening/data/sources/dictation_source.dart's prompt.
// Unlike the reading Parts, this feature has no topic/context filter at
// all (Nghe chép only ever generates from the user's own selected vocab
// words) and no per-request register/setting clause.
export function buildDictationPrompt(headwords: string[], targetLanguage: TargetLanguage): string {
  const languageLabel = LANGUAGE_LABELS[targetLanguage];
  const wordList = headwords.join(", ");
  return (
    `You are a language learning assistant helping a Vietnamese speaker learn ${languageLabel}. ` +
    `Write exactly one natural sentence of medium length (10 to 18 words) in ${languageLabel}. ` +
    `Naturally use these vocabulary words in the sentence: ${wordList}. ` +
    `Provide the sentence's Vietnamese translation and list which vocabulary words from the ` +
    `input actually appear in it. ` +
    `The Vietnamese translation must use only Vietnamese script — never Chinese, Japanese, or ` +
    `other non-Vietnamese characters. ` +
    `Respond with JSON only (no markdown, no code fences): ` +
    `{"target": "the sentence in ${languageLabel}", "vietnamese": "Vietnamese translation", ` +
    `"vocabWords": ["only words from the provided list that appear in this sentence"]}`
  );
}

export function parseDictationItem(json: Record<string, unknown>, wordMap: Record<string, string>): DictationItem {
  const vocabWords = Array.isArray(json.vocabWords) ? json.vocabWords.map(String) : [];
  const vocabIds = vocabWords.map((w) => wordMap[w]).filter((id): id is string => id !== undefined);
  return {
    target: typeof json.target === "string" ? json.target : "",
    vietnamese: typeof json.vietnamese === "string" ? json.vietnamese : "",
    vocabIds,
  };
}

export function targetWords(sentence: string): string[] {
  return sentence.split(/\s+/).filter((w) => w.length > 0);
}

export function targetTextForBlank(sentence: string, blank: BlankSpan): string {
  return targetWords(sentence)
    .slice(blank.startWordIndex, blank.startWordIndex + blank.wordCount)
    .join(" ");
}

// Ports lib/features/listening/domain/use_cases/select_dictation_blanks_use_case.dart
// exactly, including its non-adjacency rule for "easy" (only enforced once
// the sentence has 6+ words) and its clamped span-length formula for
// "medium". `random` defaults to Math.random and exists purely so tests can
// inject a deterministic sequence — mirrors Dart's optional Random param.
export function selectDictationBlanks(
  sentence: string,
  difficulty: DictationDifficulty,
  random: () => number = Math.random
): BlankSpan[] {
  const wordCount = targetWords(sentence).length;

  if (difficulty === "hard") return [];
  if (difficulty === "easy") return selectEasyBlanks(wordCount, random);
  return selectMediumBlanks(wordCount, random);
}

function randInt(random: () => number, max: number): number {
  return Math.floor(random() * max);
}

function selectEasyBlanks(wordCount: number, random: () => number): BlankSpan[] {
  if (wordCount <= 1) return [{ startWordIndex: 0, wordCount: 1 }];

  const enforceNonAdjacent = wordCount >= 6;
  const minIndex = enforceNonAdjacent ? 1 : 0;
  const maxIndex = enforceNonAdjacent ? wordCount - 2 : wordCount - 1;
  const range = maxIndex - minIndex + 1;

  let first = minIndex + randInt(random, range);
  let second = minIndex + randInt(random, range);

  let attempts = 0;
  while ((second === first || (enforceNonAdjacent && Math.abs(second - first) < 2)) && attempts < 30) {
    second = minIndex + randInt(random, range);
    attempts++;
  }
  if (second === first) {
    second = first === maxIndex ? first - 1 : first + 1;
  }

  const indices = Array.from(new Set([first, second])).sort((a, b) => a - b);
  return indices.map((i) => ({ startWordIndex: i, wordCount: 1 }));
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(Math.max(value, min), max);
}

function selectMediumBlanks(wordCount: number, random: () => number): BlankSpan[] {
  if (wordCount <= 3) return [{ startWordIndex: 0, wordCount }];

  const spanLength = clamp(Math.round(wordCount * 0.35), 2, wordCount - 2);
  const maxStartIndexInclusive = wordCount - spanLength - 1;
  const startIndex = maxStartIndexInclusive > 1 ? 1 + randInt(random, maxStartIndexInclusive) : 1;
  return [{ startWordIndex: startIndex, wordCount: spanLength }];
}

function isDue(record: VocabRecord, now: Date): boolean {
  return record.nextReviewAt === null || new Date(record.nextReviewAt).getTime() <= now.getTime();
}

function shuffle<T>(items: T[]): T[] {
  const result = [...items];
  for (let i = result.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [result[i], result[j]] = [result[j], result[i]];
  }
  return result;
}

// Ports DictationHomeScreen._generate's exact word-prioritization: due words
// shuffled first, not-due words shuffled second, concatenated — unlike
// selectSessionWords (used elsewhere), this always returns every eligible
// word, guaranteeing the caller can still take() a full count even when
// fewer than that many words are due.
export function prioritizeDueWords(records: VocabRecord[], now: Date = new Date()): VocabRecord[] {
  const due = shuffle(records.filter((r) => isDue(r, now)));
  const notDue = shuffle(records.filter((r) => !isDue(r, now)));
  return [...due, ...notDue];
}

const EDGE_PUNCTUATION = /^[^\p{L}\p{N}]+|[^\p{L}\p{N}]+$/gu;

// Ports DictationSessionResult._normalize exactly (lowercase, trim, collapse
// whitespace, strip leading/trailing punctuation per word) — Unicode-aware
// so accented Vietnamese/English text strips correctly.
export function normalizeForComparison(text: string): string {
  return text
    .trim()
    .toLowerCase()
    .replace(/\s+/g, " ")
    .split(" ")
    .map((word) => word.replace(EDGE_PUNCTUATION, ""))
    .join(" ");
}

export function isBlankCorrect(sentence: string, blank: BlankSpan, answer: string): boolean {
  return normalizeForComparison(answer) === normalizeForComparison(targetTextForBlank(sentence, blank));
}

// Ports DictationSessionResult.charAccuracy exactly: only characters at the
// same index count, over the target's full length (not the typed length) —
// so a too-short answer is scored down by the missing trailing characters.
export function charAccuracy(target: string, typed: string): number {
  if (target.length === 0) return 1;
  const limit = Math.min(typed.length, target.length);
  let correct = 0;
  for (let i = 0; i < limit; i++) {
    if (typed[i] === target[i]) correct++;
  }
  return correct / target.length;
}

export function blockAccuracy(sentence: string, blanks: BlankSpan[], blankAnswers: string[]): number {
  if (blanks.length === 0) return 1;
  const correctCount = blanks.filter((b, i) => isBlankCorrect(sentence, b, blankAnswers[i] ?? "")).length;
  return correctCount / blanks.length;
}

// Ports seekPenaltyFraction from dictation_practice_provider.dart exactly:
// TTS always speaks from the seek point to the end of the sentence, so
// seeking near the start re-hears almost the whole sentence (expensive,
// 0.05) while seeking near the end re-hears almost nothing (cheap, 0.01).
export function seekPenaltyFraction(wordIndex: number, totalWords: number): number {
  if (totalWords <= 0) return 0;
  const wordsReheard = totalWords - wordIndex;
  const reheardRatio = wordsReheard / totalWords;
  if (reheardRatio <= 0.2) return 0.01;
  return clamp(0.01 + (0.04 * (reheardRatio - 0.2)) / 0.8, 0.01, 0.05);
}

export interface DictationScoreInput {
  difficulty: DictationDifficulty;
  target: string;
  typed: string;
  blanks: BlankSpan[];
  blankAnswers: string[];
  replayCount: number;
  seekPenaltyTotal: number;
}

// Ports DictationSessionResult.finalScore exactly.
export function computeDictationScore(input: DictationScoreInput): number {
  const rawAccuracy =
    input.difficulty === "hard"
      ? charAccuracy(input.target, input.typed)
      : blockAccuracy(input.target, input.blanks, input.blankAnswers);
  return clamp(rawAccuracy - 0.05 * input.replayCount - input.seekPenaltyTotal, 0, 1);
}

// Ports DictationSessionResult.sm2Quality exactly — note there is
// deliberately no "1" tier (jumps from 2 straight to 0); this is a Flutter
// quirk to preserve, not a bug to fix.
export function sm2QualityFromScore(score: number): number {
  if (score >= 0.95) return 5;
  if (score >= 0.8) return 4;
  if (score >= 0.6) return 3;
  if (score >= 0.4) return 2;
  return 0;
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd apps/web && npx vitest run --run src/lib/dictation.test.ts`
Expected: PASS, all tests green.

- [ ] **Step 5: Typecheck**

Run: `cd apps/web && npx tsc --noEmit`
Expected: no errors.

- [ ] **Step 6: Commit**

```bash
git add apps/web/src/lib/dictation.ts apps/web/src/lib/dictation.test.ts
git commit -m "feat(web): add dictation generation, blank-selection, and scoring logic"
```

---

## Task 3: `savedListeningExercises.ts` — save/reuse for dictation items

**Files:**
- Create: `apps/web/src/lib/savedListeningExercises.ts`
- Create: `apps/web/src/lib/savedListeningExercises.test.ts`

**Interfaces:**
- Consumes: `DictationItem`, `DictationDifficulty` (`@/lib/dictation`, Task 2), `TargetLanguage` (`@/lib/languages`).
- Produces (used by Task 7):
  - `interface DictationFilters { difficulty: DictationDifficulty }`
  - `interface SavedListeningExercise { id: string; type: "dictation"; item: DictationItem; generationFilters: DictationFilters; targetLanguage: TargetLanguage; createdAt: string }`
  - `function saveListeningExercise(uid: string, item: DictationItem, generationFilters: DictationFilters, targetLanguage: TargetLanguage): Promise<string>`
  - `function getRandomSavedListeningExercise(uid: string, targetLanguage: TargetLanguage, filters: DictationFilters, excludeId?: string): Promise<SavedListeningExercise | null>`

This is a standalone module (not a member of `SavedReadingExercise`'s union) — a dictation item's shape (`{target, vietnamese, vocabIds}`) has nothing structurally in common with a reading passage, and forcing it into that union would mean a hollow `generationFilters`/`passage` split that doesn't fit. It's backed by its own Firestore collection, `users/{uid}/listening_exercises`, and matches by **exact** `difficulty` equality (not overlap — there's only one difficulty per session, unlike topic/volume multi-select).

- [ ] **Step 1: Write the failing tests**

Create `apps/web/src/lib/savedListeningExercises.test.ts`:

```ts
import { describe, expect, it, vi } from "vitest";
import { collection, doc, getDocs, query, setDoc, where } from "firebase/firestore";
import { saveListeningExercise, getRandomSavedListeningExercise } from "./savedListeningExercises";
import type { DictationItem } from "./dictation";

vi.mock("firebase/firestore", () => ({
  collection: vi.fn(() => "mock-collection-ref"),
  doc: vi.fn(() => "mock-doc-ref"),
  getDocs: vi.fn(),
  query: vi.fn(() => "mock-query"),
  setDoc: vi.fn(),
  where: vi.fn(() => "mock-where"),
}));

vi.mock("./firebase", () => ({
  getFirebaseDb: vi.fn(() => "mock-db"),
}));

const ITEM: DictationItem = {
  target: "I ate an apple today.",
  vietnamese: "Hôm nay tôi đã ăn một quả táo.",
  vocabIds: ["v1"],
};

function makeExercise(overrides: Partial<{ id: string; difficulty: "easy" | "medium" | "hard" }> = {}) {
  return {
    id: overrides.id ?? "ex-1",
    type: "dictation" as const,
    item: ITEM,
    generationFilters: { difficulty: overrides.difficulty ?? "hard" },
    targetLanguage: "english" as const,
    createdAt: "2026-01-01T00:00:00.000Z",
  };
}

describe("saveListeningExercise", () => {
  it("creates a document carrying its own id field, and returns that id", async () => {
    vi.mocked(doc).mockReturnValue({ id: "new-id" } as never);

    const newId = await saveListeningExercise("user-123", ITEM, { difficulty: "medium" }, "english");

    expect(setDoc).toHaveBeenCalledWith(
      { id: "new-id" },
      expect.objectContaining({
        id: "new-id",
        type: "dictation",
        item: ITEM,
        generationFilters: { difficulty: "medium" },
        targetLanguage: "english",
      })
    );
    expect(newId).toBe("new-id");
  });
});

describe("getRandomSavedListeningExercise", () => {
  it("returns a saved exercise whose difficulty exactly matches the requested filter", async () => {
    const ex = makeExercise({ difficulty: "easy" });
    vi.mocked(getDocs).mockResolvedValue({ docs: [{ id: ex.id, data: () => ex }] } as never);

    const result = await getRandomSavedListeningExercise("user-123", "english", { difficulty: "easy" });

    expect(result?.id).toBe(ex.id);
  });

  it("does not match a saved exercise with a different difficulty", async () => {
    const ex = makeExercise({ difficulty: "hard" });
    vi.mocked(getDocs).mockResolvedValue({ docs: [{ id: ex.id, data: () => ex }] } as never);

    const result = await getRandomSavedListeningExercise("user-123", "english", { difficulty: "easy" });

    expect(result).toBeNull();
  });

  it("returns null when nothing matches", async () => {
    vi.mocked(getDocs).mockResolvedValue({ docs: [] } as never);

    const result = await getRandomSavedListeningExercise("user-123", "english", { difficulty: "hard" });

    expect(result).toBeNull();
  });

  it("excludes the given id from candidates", async () => {
    const ex = makeExercise({ id: "just-saved", difficulty: "hard" });
    vi.mocked(getDocs).mockResolvedValue({ docs: [{ id: ex.id, data: () => ex }] } as never);

    const result = await getRandomSavedListeningExercise("user-123", "english", { difficulty: "hard" }, "just-saved");

    expect(result).toBeNull();
  });

  it("queries only documents matching the requested target language", async () => {
    vi.mocked(getDocs).mockResolvedValue({ docs: [] } as never);

    await getRandomSavedListeningExercise("user-123", "english", { difficulty: "hard" });

    expect(where).toHaveBeenCalledWith("targetLanguage", "==", "english");
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd apps/web && npx vitest run --run src/lib/savedListeningExercises.test.ts`
Expected: FAIL — `./savedListeningExercises` doesn't exist yet.

- [ ] **Step 3: Implement `savedListeningExercises.ts`**

Create `apps/web/src/lib/savedListeningExercises.ts`:

```ts
import { collection, doc, getDocs, query, setDoc, where } from "firebase/firestore";
import { getFirebaseDb } from "./firebase";
import type { DictationItem, DictationDifficulty } from "./dictation";
import type { TargetLanguage } from "./languages";

export interface DictationFilters {
  difficulty: DictationDifficulty;
}

// A parallel, independent module to savedReadingExercises.ts — deliberately
// not a member of that file's SavedReadingExercise union, since a dictation
// item's shape has nothing structurally in common with a reading passage
// (no topic/volume filter, no "passage" to speak of, just one sentence).
export interface SavedListeningExercise {
  id: string;
  type: "dictation";
  item: DictationItem;
  generationFilters: DictationFilters;
  targetLanguage: TargetLanguage;
  createdAt: string;
}

function listeningExercisesCol(uid: string) {
  return collection(getFirebaseDb(), "users", uid, "listening_exercises");
}

export async function saveListeningExercise(
  uid: string,
  item: DictationItem,
  generationFilters: DictationFilters,
  targetLanguage: TargetLanguage
): Promise<string> {
  const ref = doc(listeningExercisesCol(uid));
  // Carries its own id field, matching every other save*Exercise function in
  // this app — see savedReadingExercises.ts's saveReadingExercise for why.
  const record = {
    type: "dictation" as const,
    item,
    generationFilters,
    targetLanguage,
    createdAt: new Date().toISOString(),
  };
  await setDoc(ref, { ...record, id: ref.id });
  return ref.id;
}

export async function getRandomSavedListeningExercise(
  uid: string,
  targetLanguage: TargetLanguage,
  filters: DictationFilters,
  excludeId?: string
): Promise<SavedListeningExercise | null> {
  const q = query(listeningExercisesCol(uid), where("targetLanguage", "==", targetLanguage));
  const snapshot = await getDocs(q);
  const candidates: SavedListeningExercise[] = [];
  for (const d of snapshot.docs) {
    const ex = { ...(d.data() as SavedListeningExercise), id: d.id };
    if (ex.id === excludeId) continue;
    if (ex.generationFilters.difficulty !== filters.difficulty) continue;
    candidates.push(ex);
  }
  if (candidates.length === 0) return null;
  return candidates[Math.floor(Math.random() * candidates.length)];
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd apps/web && npx vitest run --run src/lib/savedListeningExercises.test.ts`
Expected: PASS, all tests green.

- [ ] **Step 5: Run the full suite and typecheck**

Run: `cd apps/web && npm test -- --run && npx tsc --noEmit`
Expected: all tests pass (aside from the known pre-existing `bloom.test.ts` failure); no type errors.

- [ ] **Step 6: Commit**

```bash
git add apps/web/src/lib/savedListeningExercises.ts apps/web/src/lib/savedListeningExercises.test.ts
git commit -m "feat(web): add save/reuse for dictation exercises"
```

---

## Task 4: `useDictationAudio` — playback hook (play/replay/speed/seek)

**Files:**
- Create: `apps/web/src/lib/useDictationAudio.ts`
- Create: `apps/web/src/lib/useDictationAudio.test.ts`

**Interfaces:**
- Consumes: `synthesizeSpeech`, `toAudioDataUrl` (`@/lib/synthesizeSpeechClient`, Task 1), `seekPenaltyFraction`, `targetWords` (`@/lib/dictation`, Task 2).
- Produces (used by Task 7):
  ```ts
  interface UseDictationAudioResult {
    isLoading: boolean;
    hasPlayedOnce: boolean;
    replayCount: number;
    seekCount: number;
    seekPenaltyTotal: number;
    speed: number;
    error: string | null;
    play: () => Promise<void>;
    setSpeed: (speed: number) => void;
    seekTo: (wordIndex: number) => Promise<void>;
  }
  function useDictationAudio(sentence: string): UseDictationAudioResult
  ```

This is a web reimplementation of `DictationPracticeNotifier`'s `play`/`seekTo`/`setSpeed` methods and the score-relevant fields of `DictationSessionState` (`hasPlayedOnce`, `replayCount`, `seekCount`, `seekPenaltyTotal`, `speedMultiplier`) — **not** a literal port, since Flutter speaks live via an on-device TTS engine on every call while this hook caches one fetched clip and replays it, only re-fetching for seeks (see the plan's Architecture section). The state-transition *rules* (when `hasPlayedOnce` flips, when `replayCount`/`seekCount`/`seekPenaltyTotal` increment) are preserved exactly, since those directly feed `computeDictationScore`.

- [ ] **Step 1: Write the failing tests**

Create `apps/web/src/lib/useDictationAudio.test.ts`:

```ts
import { beforeEach, describe, expect, it, vi } from "vitest";
import { renderHook, act, waitFor } from "@testing-library/react";
import { useDictationAudio } from "./useDictationAudio";
import { synthesizeSpeech } from "./synthesizeSpeechClient";

vi.mock("./synthesizeSpeechClient", async () => {
  const actual = await vi.importActual<typeof import("./synthesizeSpeechClient")>("./synthesizeSpeechClient");
  return { ...actual, synthesizeSpeech: vi.fn() };
});

const SENTENCE = "The quick brown fox jumps over the lazy dog"; // 9 words

beforeEach(() => {
  vi.clearAllMocks();
  vi.mocked(synthesizeSpeech).mockResolvedValue({ audioBase64: "AAAA" });
});

describe("useDictationAudio", () => {
  it("starts with hasPlayedOnce false and every counter at 0", () => {
    const { result } = renderHook(() => useDictationAudio(SENTENCE));
    expect(result.current.hasPlayedOnce).toBe(false);
    expect(result.current.replayCount).toBe(0);
    expect(result.current.seekCount).toBe(0);
    expect(result.current.seekPenaltyTotal).toBe(0);
    expect(result.current.speed).toBe(1);
  });

  it("the first play() fetches audio for the full sentence and sets hasPlayedOnce, without incrementing replayCount", async () => {
    const { result } = renderHook(() => useDictationAudio(SENTENCE));

    await act(async () => {
      await result.current.play();
    });

    expect(synthesizeSpeech).toHaveBeenCalledWith({ text: SENTENCE, language: "en" });
    expect(result.current.hasPlayedOnce).toBe(true);
    expect(result.current.replayCount).toBe(0);
  });

  it("every play() after the first increments replayCount and does not re-fetch audio", async () => {
    const { result } = renderHook(() => useDictationAudio(SENTENCE));
    await act(async () => {
      await result.current.play();
    });

    await act(async () => {
      await result.current.play();
    });
    await act(async () => {
      await result.current.play();
    });

    expect(result.current.replayCount).toBe(2);
    expect(synthesizeSpeech).toHaveBeenCalledTimes(1);
  });

  it("setSpeed updates the reported speed without calling synthesizeSpeech or touching hasPlayedOnce/replayCount", () => {
    const { result } = renderHook(() => useDictationAudio(SENTENCE));

    act(() => {
      result.current.setSpeed(1.25);
    });

    expect(result.current.speed).toBe(1.25);
    expect(synthesizeSpeech).not.toHaveBeenCalled();
    expect(result.current.hasPlayedOnce).toBe(false);
  });

  it("seekTo before any play sets hasPlayedOnce and increments seekCount, but adds no penalty", async () => {
    const { result } = renderHook(() => useDictationAudio(SENTENCE));

    await act(async () => {
      await result.current.seekTo(3);
    });

    expect(synthesizeSpeech).toHaveBeenCalledWith({ text: "fox jumps over the lazy dog", language: "en" });
    expect(result.current.hasPlayedOnce).toBe(true);
    expect(result.current.seekCount).toBe(1);
    expect(result.current.seekPenaltyTotal).toBe(0);
  });

  it("seekTo after already having played adds the seekPenaltyFraction for that word index", async () => {
    const { result } = renderHook(() => useDictationAudio(SENTENCE));
    await act(async () => {
      await result.current.play();
    });

    await act(async () => {
      await result.current.seekTo(0); // seeking to the very start of a 9-word sentence -> max penalty 0.05
    });

    expect(result.current.seekCount).toBe(1);
    expect(result.current.seekPenaltyTotal).toBeCloseTo(0.05);
  });

  it("accumulates seekPenaltyTotal across multiple seeks", async () => {
    const { result } = renderHook(() => useDictationAudio(SENTENCE));
    await act(async () => {
      await result.current.play();
    });
    await act(async () => {
      await result.current.seekTo(0); // +0.05
    });
    await act(async () => {
      await result.current.seekTo(8); // 1 word re-heard of 9 -> ratio ~0.11 -> min 0.01
    });

    expect(result.current.seekCount).toBe(2);
    expect(result.current.seekPenaltyTotal).toBeCloseTo(0.06);
  });

  it("surfaces a Vietnamese error and stops loading when synthesizeSpeech rejects", async () => {
    vi.mocked(synthesizeSpeech).mockRejectedValue(new Error("network down"));
    const { result } = renderHook(() => useDictationAudio(SENTENCE));

    await act(async () => {
      await result.current.play();
    });

    expect(result.current.error).toBe("network down");
    expect(result.current.isLoading).toBe(false);
    expect(result.current.hasPlayedOnce).toBe(false);
  });

  it("clears a prior error on the next successful play", async () => {
    vi.mocked(synthesizeSpeech).mockRejectedValueOnce(new Error("network down"));
    const { result } = renderHook(() => useDictationAudio(SENTENCE));
    await act(async () => {
      await result.current.play();
    });
    expect(result.current.error).toBe("network down");

    vi.mocked(synthesizeSpeech).mockResolvedValue({ audioBase64: "AAAA" });
    await act(async () => {
      await result.current.play();
    });

    await waitFor(() => expect(result.current.error).toBeNull());
    expect(result.current.hasPlayedOnce).toBe(true);
  });

  it("isLoading is true while a synthesizeSpeech call is in flight", async () => {
    let resolveCall!: (value: { audioBase64: string }) => void;
    vi.mocked(synthesizeSpeech).mockReturnValue(
      new Promise((resolve) => {
        resolveCall = resolve;
      })
    );
    const { result } = renderHook(() => useDictationAudio(SENTENCE));

    let playPromise!: Promise<void>;
    act(() => {
      playPromise = result.current.play();
    });
    expect(result.current.isLoading).toBe(true);

    await act(async () => {
      resolveCall({ audioBase64: "AAAA" });
      await playPromise;
    });
    expect(result.current.isLoading).toBe(false);
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd apps/web && npx vitest run --run src/lib/useDictationAudio.test.ts`
Expected: FAIL — `./useDictationAudio` doesn't exist yet.

- [ ] **Step 3: Implement `useDictationAudio.ts`**

Create `apps/web/src/lib/useDictationAudio.ts`:

```ts
import { useCallback, useRef, useState } from "react";
import { synthesizeSpeech, toAudioDataUrl } from "./synthesizeSpeechClient";
import { seekPenaltyFraction, targetWords } from "./dictation";

export interface UseDictationAudioResult {
  isLoading: boolean;
  hasPlayedOnce: boolean;
  replayCount: number;
  seekCount: number;
  seekPenaltyTotal: number;
  speed: number;
  error: string | null;
  play: () => Promise<void>;
  setSpeed: (speed: number) => void;
  seekTo: (wordIndex: number) => Promise<void>;
}

// Web reimplementation of DictationPracticeNotifier's play/seekTo/setSpeed —
// not a literal port (Flutter speaks live on-device every call; this caches
// one fetched clip and only re-fetches for seeks). The state-transition
// rules that feed computeDictationScore are preserved exactly.
export function useDictationAudio(sentence: string): UseDictationAudioResult {
  const [isLoading, setIsLoading] = useState(false);
  const [hasPlayedOnce, setHasPlayedOnce] = useState(false);
  const [replayCount, setReplayCount] = useState(0);
  const [seekCount, setSeekCount] = useState(0);
  const [seekPenaltyTotal, setSeekPenaltyTotal] = useState(0);
  const [speed, setSpeedState] = useState(1);
  const [error, setError] = useState<string | null>(null);

  const audioRef = useRef<HTMLAudioElement | null>(null);
  const fullClipUrlRef = useRef<string | null>(null);

  function playUrl(url: string) {
    if (!audioRef.current) {
      audioRef.current = new Audio();
    }
    const audioEl = audioRef.current;
    audioEl.src = url;
    audioEl.playbackRate = speed;
    audioEl.currentTime = 0;
    // Playback can fail silently (autoplay policy, no audio device, a jsdom
    // stub in tests) — this must never block hasPlayedOnce/replayCount/seek
    // state, since scoring only cares about user intent (did they click
    // play), not whether audio literally rendered.
    const playResult = audioEl.play();
    if (playResult && typeof playResult.catch === "function") {
      playResult.catch(() => {});
    }
  }

  const play = useCallback(async () => {
    setError(null);
    if (hasPlayedOnce && fullClipUrlRef.current) {
      setReplayCount((c) => c + 1);
      playUrl(fullClipUrlRef.current);
      return;
    }
    setIsLoading(true);
    try {
      const { audioBase64 } = await synthesizeSpeech({ text: sentence, language: "en" });
      const url = toAudioDataUrl(audioBase64);
      fullClipUrlRef.current = url;
      setHasPlayedOnce(true);
      playUrl(url);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setIsLoading(false);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [sentence, hasPlayedOnce]);

  const setSpeed = useCallback((next: number) => {
    setSpeedState(next);
    if (audioRef.current) {
      audioRef.current.playbackRate = next;
    }
  }, []);

  const seekTo = useCallback(
    async (wordIndex: number) => {
      const words = targetWords(sentence);
      if (wordIndex < 0 || wordIndex >= words.length) return;

      setError(null);
      setIsLoading(true);
      try {
        const remainder = words.slice(wordIndex).join(" ");
        const { audioBase64 } = await synthesizeSpeech({ text: remainder, language: "en" });
        const url = toAudioDataUrl(audioBase64);
        if (hasPlayedOnce) {
          setSeekPenaltyTotal((total) => total + seekPenaltyFraction(wordIndex, words.length));
        } else {
          setHasPlayedOnce(true);
        }
        setSeekCount((c) => c + 1);
        playUrl(url);
      } catch (err) {
        setError(err instanceof Error ? err.message : String(err));
      } finally {
        setIsLoading(false);
      }
      // eslint-disable-next-line react-hooks/exhaustive-deps
    },
    [sentence, hasPlayedOnce]
  );

  return {
    isLoading,
    hasPlayedOnce,
    replayCount,
    seekCount,
    seekPenaltyTotal,
    speed,
    error,
    play,
    setSpeed,
    seekTo,
  };
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd apps/web && npx vitest run --run src/lib/useDictationAudio.test.ts`
Expected: PASS, all tests green.

- [ ] **Step 5: Run the full suite and typecheck**

Run: `cd apps/web && npm test -- --run && npx tsc --noEmit`
Expected: all tests pass (aside from the known pre-existing `bloom.test.ts` failure); no type errors.

- [ ] **Step 6: Commit**

```bash
git add apps/web/src/lib/useDictationAudio.ts apps/web/src/lib/useDictationAudio.test.ts
git commit -m "feat(web): add useDictationAudio playback hook (play/replay/speed/seek)"
```

---

## Task 5: Shared listening UI components — `ClozeInput`, `ClozeResult`, `DiffText`

**Files:**
- Create: `apps/web/src/components/listening/ClozeInput.tsx`
- Create: `apps/web/src/components/listening/ClozeInput.test.tsx`
- Create: `apps/web/src/components/listening/ClozeResult.tsx`
- Create: `apps/web/src/components/listening/ClozeResult.test.tsx`
- Create: `apps/web/src/components/listening/DiffText.tsx`
- Create: `apps/web/src/components/listening/DiffText.test.tsx`
- Modify: `apps/web/src/styles/bloom.css`

**Interfaces:**
- Consumes: `BlankSpan`, `targetWords`, `targetTextForBlank`, `isBlankCorrect` (`@/lib/dictation`, Task 2).
- Produces (used by Task 7): `<ClozeInput target options={blanks} answers onAnswerChange />` (session mode, editable), `<ClozeResult target blanks answers />` (result mode, read-only), `<DiffText typed target />` (Khó-mode result, character diff).

- [ ] **Step 1: Write the failing tests**

Create `apps/web/src/components/listening/ClozeInput.test.tsx`:

```tsx
import { describe, expect, it, vi } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import { ClozeInput } from "./ClozeInput";

describe("ClozeInput", () => {
  it("renders visible words as plain text and blanks as labeled inputs, in order", () => {
    render(
      <ClozeInput
        target="The quick brown fox jumps"
        blanks={[{ startWordIndex: 1, wordCount: 1 }]}
        answers={[""]}
        onAnswerChange={vi.fn()}
      />
    );

    expect(screen.getByText(/^The/)).toBeInTheDocument();
    expect(screen.getByLabelText("Chỗ trống 1")).toBeInTheDocument();
    expect(screen.getByText(/brown fox jumps/)).toBeInTheDocument();
  });

  it("shows the current answer value in the blank's input", () => {
    render(
      <ClozeInput
        target="The quick brown fox"
        blanks={[{ startWordIndex: 1, wordCount: 1 }]}
        answers={["slow"]}
        onAnswerChange={vi.fn()}
      />
    );

    expect(screen.getByLabelText("Chỗ trống 1")).toHaveValue("slow");
  });

  it("calls onAnswerChange with the blank's index when its input changes", () => {
    const onAnswerChange = vi.fn();
    render(
      <ClozeInput
        target="The quick brown fox"
        blanks={[
          { startWordIndex: 0, wordCount: 1 },
          { startWordIndex: 2, wordCount: 1 },
        ]}
        answers={["", ""]}
        onAnswerChange={onAnswerChange}
      />
    );

    fireEvent.change(screen.getByLabelText("Chỗ trống 2"), { target: { value: "brown" } });

    expect(onAnswerChange).toHaveBeenCalledWith(1, "brown");
  });

  it("renders a blank at the very start of the sentence with no leading text", () => {
    render(
      <ClozeInput
        target="Hello world"
        blanks={[{ startWordIndex: 0, wordCount: 1 }]}
        answers={[""]}
        onAnswerChange={vi.fn()}
      />
    );

    expect(screen.getByLabelText("Chỗ trống 1")).toBeInTheDocument();
    expect(screen.getByText("world")).toBeInTheDocument();
  });
});
```

Create `apps/web/src/components/listening/ClozeResult.test.tsx`:

```tsx
import { describe, expect, it } from "vitest";
import { render, screen } from "@testing-library/react";
import { ClozeResult } from "./ClozeResult";

describe("ClozeResult", () => {
  it("shows a correct answer styled correct, with no hint", () => {
    render(
      <ClozeResult
        target="Apple is red"
        blanks={[{ startWordIndex: 0, wordCount: 1 }]}
        answers={["apple"]}
      />
    );

    const answer = screen.getByText("apple");
    expect(answer).toHaveClass("cloze-answer-correct");
    expect(screen.queryByText(/đúng:/)).not.toBeInTheDocument();
  });

  it("shows a wrong answer styled wrong, with the correct text as a hint", () => {
    render(
      <ClozeResult
        target="Apple is red"
        blanks={[{ startWordIndex: 0, wordCount: 1 }]}
        answers={["banana"]}
      />
    );

    expect(screen.getByText("banana")).toHaveClass("cloze-answer-wrong");
    expect(screen.getByText(/đúng: apple/)).toBeInTheDocument();
  });

  it("shows a placeholder for an empty answer, treated as wrong", () => {
    render(
      <ClozeResult target="Apple is red" blanks={[{ startWordIndex: 0, wordCount: 1 }]} answers={[""]} />
    );

    expect(screen.getByText("___")).toHaveClass("cloze-answer-wrong");
  });

  it("renders every surrounding word alongside multiple blanks", () => {
    render(
      <ClozeResult
        target="The quick brown fox jumps"
        blanks={[
          { startWordIndex: 1, wordCount: 1 },
          { startWordIndex: 3, wordCount: 1 },
        ]}
        answers={["quick", "wrong"]}
      />
    );

    expect(screen.getByText(/^The/)).toBeInTheDocument();
    expect(screen.getByText("quick")).toHaveClass("cloze-answer-correct");
    expect(screen.getByText(/jumps/)).toBeInTheDocument();
  });
});
```

Create `apps/web/src/components/listening/DiffText.test.tsx`:

```tsx
import { describe, expect, it } from "vitest";
import { render, screen } from "@testing-library/react";
import { DiffText } from "./DiffText";

describe("DiffText", () => {
  it("renders every typed character, marking each correct/wrong against the target at the same index", () => {
    render(<DiffText typed="Hxllo" target="Hello" />);

    const container = screen.getByTestId("diff-text");
    const spans = container.querySelectorAll("span");
    expect(spans).toHaveLength(5);
    expect(spans[0]).toHaveClass("diff-char-correct"); // H
    expect(spans[1]).toHaveClass("diff-char-wrong"); // x vs e
    expect(spans[2]).toHaveClass("diff-char-correct"); // l
    expect(container).toHaveTextContent("Hxllo");
  });

  it("marks a typed character beyond the target's length as wrong", () => {
    render(<DiffText typed="Hello!" target="Hello" />);

    const spans = screen.getByTestId("diff-text").querySelectorAll("span");
    expect(spans[5]).toHaveClass("diff-char-wrong"); // "!" has no counterpart in target
  });

  it("renders nothing extra when typed is shorter than target", () => {
    render(<DiffText typed="He" target="Hello" />);

    const spans = screen.getByTestId("diff-text").querySelectorAll("span");
    expect(spans).toHaveLength(2);
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd apps/web && npx vitest run --run "src/components/listening/*.test.tsx"`
Expected: FAIL — none of the three components exist yet.

- [ ] **Step 3: Add CSS for the cloze/diff text**

In `apps/web/src/styles/bloom.css`, add this block right after the `.reading-session-body` rule:

```css
.cloze-text {
  font-size: 18px;
  line-height: 2.1;
  color: var(--ink);
}

.cloze-blank-input {
  display: inline-block;
  min-width: 70px;
  width: auto;
  padding: 2px 8px;
  border: none;
  border-bottom: 2px solid var(--accent);
  background: transparent;
  font: inherit;
  color: var(--ink);
  text-align: center;
}

.cloze-answer-correct {
  color: var(--success);
  font-weight: 700;
  text-decoration: underline;
}

.cloze-answer-wrong {
  color: var(--danger);
  font-weight: 700;
  text-decoration: underline;
}

.cloze-answer-hint {
  color: var(--danger);
  font-style: italic;
  font-size: 16px;
}

.diff-text {
  font-size: 18px;
  line-height: 1.8;
  font-family: ui-monospace, monospace;
}

.diff-char-correct {
  color: var(--success);
}

.diff-char-wrong {
  color: var(--danger);
  background: var(--danger-bg);
}
```

- [ ] **Step 4: Implement `ClozeInput.tsx`**

Create `apps/web/src/components/listening/ClozeInput.tsx`:

```tsx
import type { ReactNode } from "react";
import { targetWords, type BlankSpan } from "@/lib/dictation";

interface ClozeInputProps {
  target: string;
  blanks: BlankSpan[];
  answers: string[];
  onAnswerChange: (blankIndex: number, text: string) => void;
}

export function ClozeInput({ target, blanks, answers, onAnswerChange }: ClozeInputProps) {
  const words = targetWords(target);
  const segments: ReactNode[] = [];
  let wordIndex = 0;

  blanks.forEach((blank, blankIdx) => {
    if (blank.startWordIndex > wordIndex) {
      segments.push(<span key={`text-${blankIdx}`}>{words.slice(wordIndex, blank.startWordIndex).join(" ")} </span>);
    }
    segments.push(
      <input
        key={`blank-${blankIdx}`}
        type="text"
        className="cloze-blank-input"
        value={answers[blankIdx] ?? ""}
        onChange={(e) => onAnswerChange(blankIdx, e.target.value)}
        aria-label={`Chỗ trống ${blankIdx + 1}`}
      />
    );
    segments.push(" ");
    wordIndex = blank.startWordIndex + blank.wordCount;
  });

  if (wordIndex < words.length) {
    segments.push(<span key="text-end">{words.slice(wordIndex).join(" ")}</span>);
  }

  return <div className="cloze-text">{segments}</div>;
}
```

- [ ] **Step 5: Implement `ClozeResult.tsx`**

Create `apps/web/src/components/listening/ClozeResult.tsx`:

```tsx
import type { ReactNode } from "react";
import { isBlankCorrect, targetTextForBlank, targetWords, type BlankSpan } from "@/lib/dictation";

interface ClozeResultProps {
  target: string;
  blanks: BlankSpan[];
  answers: string[];
}

export function ClozeResult({ target, blanks, answers }: ClozeResultProps) {
  const words = targetWords(target);
  const segments: ReactNode[] = [];
  let wordIndex = 0;

  blanks.forEach((blank, blankIdx) => {
    if (blank.startWordIndex > wordIndex) {
      segments.push(<span key={`text-${blankIdx}`}>{words.slice(wordIndex, blank.startWordIndex).join(" ")} </span>);
    }
    const answer = answers[blankIdx] ?? "";
    const correct = isBlankCorrect(target, blank, answer);
    segments.push(
      <span key={`blank-${blankIdx}`} className={correct ? "cloze-answer-correct" : "cloze-answer-wrong"}>
        {answer.length > 0 ? answer : "___"}
      </span>
    );
    if (!correct) {
      segments.push(
        <span key={`hint-${blankIdx}`} className="cloze-answer-hint">
          {" "}
          (đúng: {targetTextForBlank(target, blank)})
        </span>
      );
    }
    segments.push(" ");
    wordIndex = blank.startWordIndex + blank.wordCount;
  });

  if (wordIndex < words.length) {
    segments.push(<span key="text-end">{words.slice(wordIndex).join(" ")}</span>);
  }

  return <p className="cloze-text">{segments}</p>;
}
```

- [ ] **Step 6: Implement `DiffText.tsx`**

Create `apps/web/src/components/listening/DiffText.tsx`:

```tsx
interface DiffTextProps {
  typed: string;
  target: string;
}

export function DiffText({ typed, target }: DiffTextProps) {
  return (
    <p className="diff-text" data-testid="diff-text">
      {typed.split("").map((ch, i) => {
        const correct = i < target.length && ch === target[i];
        return (
          <span key={i} className={correct ? "diff-char-correct" : "diff-char-wrong"}>
            {ch}
          </span>
        );
      })}
    </p>
  );
}
```

- [ ] **Step 7: Run the tests to verify they pass**

Run: `cd apps/web && npx vitest run --run "src/components/listening/*.test.tsx"`
Expected: PASS, all tests green.

- [ ] **Step 8: Run the full suite and typecheck**

Run: `cd apps/web && npm test -- --run && npx tsc --noEmit`
Expected: all tests pass (aside from the known pre-existing `bloom.test.ts` failure); no type errors.

- [ ] **Step 9: Commit**

```bash
git add apps/web/src/components/listening/ apps/web/src/styles/bloom.css
git commit -m "feat(web): add ClozeInput, ClozeResult, and DiffText components for dictation"
```

---

## Task 6: `/listening` hub — language gate, difficulty picker, and navigation

**Files:**
- Create: `apps/web/src/app/(app)/listening/page.tsx`
- Create: `apps/web/src/app/(app)/listening/page.test.tsx`

**Interfaces:**
- Consumes: `DictationDifficulty` (`@/lib/dictation`, Task 2), `getVocabRecords`/`VocabRecord` (`@/lib/vocabRecords`, already exists), `useSettingsContext` (`@/lib/SettingsContext`, already exists).
- Produces (used by Task 7, as the URL shape it must read): `/listening/dictation?difficulty=easy|medium|hard&action=generate|existing`.

The sidebar already links to `/listening` (`apps/web/src/components/shell/Sidebar.tsx`'s existing `"🎧 Nghe — tổng quan"` entry) — no sidebar change needed, this task just fills in the page that route was already pointing at.

- [ ] **Step 1: Write the failing tests**

Create `apps/web/src/app/(app)/listening/page.test.tsx`:

```tsx
import { beforeEach, describe, expect, it, vi } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import ListeningHubPage from "./page";
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

const pushMock = vi.fn();
vi.mock("next/navigation", () => ({ useRouter: () => ({ push: pushMock }) }));

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

function mockSignedIn(settings: UserSettings = DEFAULT_SETTINGS) {
  vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" }, loading: false } as never);
  vi.mocked(useSettingsContext).mockReturnValue({ settings, loading: false, error: null, save: vi.fn() });
}

beforeEach(() => {
  vi.clearAllMocks();
});

describe("ListeningHubPage (auth)", () => {
  it("prompts sign-in when logged out", () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: null, loading: false } as never);
    render(<ListeningHubPage />);
    expect(screen.getByText("Đăng nhập với Google")).toBeInTheDocument();
  });
});

describe("ListeningHubPage (language gate)", () => {
  it("shows a blocking message and no action buttons when the target language isn't English", async () => {
    mockSignedIn({ ...DEFAULT_SETTINGS, targetLanguage: "korean" });
    vi.mocked(getVocabRecords).mockResolvedValue([]);

    render(<ListeningHubPage />);

    expect(
      await screen.findByText("Nghe chép hiện chỉ hỗ trợ khi Ngôn ngữ mục tiêu là Tiếng Anh — đổi trong Cài đặt để dùng.")
    ).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Tạo bài luyện" })).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "🔀 Lấy bài có sẵn" })).not.toBeInTheDocument();
  });
});

describe("ListeningHubPage (word gating)", () => {
  it("shows the min-words hint instead of Tạo bài luyện when fewer than 2 eligible words exist", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([makeRecord({ id: "1" })]);

    render(<ListeningHubPage />);

    expect(
      await screen.findByText("Hãy lưu ít nhất 2 từ tiếng Anh vào Ngân hàng từ vựng. Hiện có 1 từ.")
    ).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Tạo bài luyện" })).not.toBeInTheDocument();
  });

  it("only counts words whose targetLanguage is english toward the minimum", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([
      makeRecord({ id: "1", targetLanguage: "english" }),
      makeRecord({ id: "2", targetLanguage: "korean" }),
    ]);

    render(<ListeningHubPage />);

    expect(await screen.findByText(/Hiện có 1 từ\./)).toBeInTheDocument();
  });

  it("shows Tạo bài luyện once at least 2 eligible words exist", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([makeRecord({ id: "1" }), makeRecord({ id: "2" })]);

    render(<ListeningHubPage />);

    expect(await screen.findByRole("button", { name: "Tạo bài luyện" })).not.toBeDisabled();
  });

  it("'Lấy bài có sẵn' is never gated by word count, even with 0 eligible words", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([]);

    render(<ListeningHubPage />);

    expect(await screen.findByRole("button", { name: "🔀 Lấy bài có sẵn" })).not.toBeDisabled();
  });
});

describe("ListeningHubPage (navigation)", () => {
  it("defaults to difficulty=hard and navigates with action=generate", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([makeRecord({ id: "1" }), makeRecord({ id: "2" })]);

    render(<ListeningHubPage />);
    fireEvent.click(await screen.findByRole("button", { name: "Tạo bài luyện" }));

    expect(pushMock).toHaveBeenCalledWith("/listening/dictation?difficulty=hard&action=generate");
  });

  it("navigates with the selected difficulty and action=existing", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([]);

    render(<ListeningHubPage />);
    fireEvent.click(await screen.findByRole("button", { name: "Dễ" }));
    fireEvent.click(screen.getByRole("button", { name: "🔀 Lấy bài có sẵn" }));

    expect(pushMock).toHaveBeenCalledWith("/listening/dictation?difficulty=easy&action=existing");
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd apps/web && npx vitest run --run "src/app/(app)/listening/page.test.tsx"`
Expected: FAIL — the page doesn't exist yet.

- [ ] **Step 3: Implement the hub page**

Create `apps/web/src/app/(app)/listening/page.tsx`:

```tsx
"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettingsContext } from "@/lib/SettingsContext";
import { SignInButton } from "@/components/SignInButton";
import { getVocabRecords, type VocabRecord } from "@/lib/vocabRecords";
import type { DictationDifficulty } from "@/lib/dictation";

const MIN_VOCAB_WORDS = 2;

const DIFFICULTY_OPTIONS: { value: DictationDifficulty; label: string }[] = [
  { value: "easy", label: "Dễ" },
  { value: "medium", label: "Trung bình" },
  { value: "hard", label: "Khó" },
];

export default function ListeningHubPage() {
  const { user, loading: authLoading } = useAuthUser();
  const { settings, loading: settingsLoading } = useSettingsContext();
  const router = useRouter();

  const [records, setRecords] = useState<VocabRecord[]>([]);
  const [difficulty, setDifficulty] = useState<DictationDifficulty>("hard");

  useEffect(() => {
    if (!user) return;
    getVocabRecords(user.uid)
      .then(setRecords)
      .catch(() => {});
  }, [user]);

  if (authLoading) return <p>Đang tải…</p>;

  if (!user) {
    return (
      <div>
        <h2 className="scr-title">Nghe</h2>
        <p className="scr-sub">Đăng nhập để luyện nghe.</p>
        <SignInButton />
      </div>
    );
  }

  if (settingsLoading || !settings) return <p>Đang tải…</p>;

  if (settings.targetLanguage !== "english") {
    return (
      <div>
        <h2 className="scr-title">Nghe</h2>
        <p className="reading-min-words-hint">
          Nghe chép hiện chỉ hỗ trợ khi Ngôn ngữ mục tiêu là Tiếng Anh — đổi trong Cài đặt để dùng.
        </p>
      </div>
    );
  }

  const eligibleCount = records.filter((r) => r.targetLanguage === "english").length;
  const canGenerate = eligibleCount >= MIN_VOCAB_WORDS;

  function buildQuery(action: "generate" | "existing"): string {
    const params = new URLSearchParams();
    params.set("difficulty", difficulty);
    params.set("action", action);
    return params.toString();
  }

  function navigate(action: "generate" | "existing") {
    router.push(`/listening/dictation?${buildQuery(action)}`);
  }

  return (
    <div>
      <h2 className="scr-title">Nghe</h2>
      <p className="scr-sub">AI tạo 1 câu từ Vocab Bank của bạn. Nghe và gõ lại chính xác những gì bạn nghe được.</p>

      <div className="practice-filters">
        {DIFFICULTY_OPTIONS.map((opt) => (
          <button
            key={opt.value}
            type="button"
            className={`vb-chip${difficulty === opt.value ? " active" : ""}`}
            onClick={() => setDifficulty(opt.value)}
          >
            {opt.label}
          </button>
        ))}
      </div>

      <div className="reading-setup-actions">
        {canGenerate ? (
          <button type="button" className="btn-primary" onClick={() => navigate("generate")}>
            Tạo bài luyện
          </button>
        ) : (
          <p className="reading-min-words-hint">
            Hãy lưu ít nhất {MIN_VOCAB_WORDS} từ tiếng Anh vào Ngân hàng từ vựng. Hiện có {eligibleCount} từ.
          </p>
        )}
        <button type="button" className="btn-secondary" onClick={() => navigate("existing")}>
          🔀 Lấy bài có sẵn
        </button>
      </div>
    </div>
  );
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd apps/web && npx vitest run --run "src/app/(app)/listening/page.test.tsx"`
Expected: PASS, all tests green.

- [ ] **Step 5: Run the full suite and typecheck**

Run: `cd apps/web && npm test -- --run && npx tsc --noEmit`
Expected: all tests pass (aside from the known pre-existing `bloom.test.ts` failure); no type errors.

- [ ] **Step 6: Commit**

```bash
git add "apps/web/src/app/(app)/listening/page.tsx" "apps/web/src/app/(app)/listening/page.test.tsx"
git commit -m "feat(web): add the /listening hub with language gate and difficulty picker"
```

---

## Task 7: `/listening/dictation` — session and result screens

**Files:**
- Create: `apps/web/src/app/(app)/listening/dictation/page.tsx`
- Create: `apps/web/src/app/(app)/listening/dictation/page.test.tsx`
- Modify: `apps/web/src/styles/bloom.css`

**Interfaces:**
- Consumes: everything from Tasks 1-6 — `synthesizeSpeech`-backed `useDictationAudio` (Task 4), `buildDictationPrompt`/`parseDictationItem`/`selectDictationBlanks`/`prioritizeDueWords`/`targetWords`/`computeDictationScore`/`sm2QualityFromScore` (`@/lib/dictation`, Task 2), `saveListeningExercise`/`getRandomSavedListeningExercise` (`@/lib/savedListeningExercises`, Task 3), `ClozeInput`/`ClozeResult`/`DiffText` (`@/components/listening/`, Task 5), `computeSm2` (`@/lib/sm2`, already exists), `updateVocabRecordSm2` (`@/lib/vocabRecords`, already exists), `generateContent`/`parseAiJsonObject` (already exist). Reads the `difficulty`/`action` URL shape Task 6's hub produces.

- [ ] **Step 1: Add CSS for the playback controls**

In `apps/web/src/styles/bloom.css`, add this block right after the `.diff-char-wrong` rule added in Task 5:

```css
.dictation-controls {
  display: flex;
  align-items: center;
  gap: 16px;
  margin-bottom: 12px;
}

.dictation-speed-selector {
  display: flex;
  gap: 8px;
}

.dictation-seek-slider {
  width: 100%;
  margin-bottom: 20px;
}

.dictation-free-input {
  width: 100%;
  min-height: 120px;
  padding: 14px 16px;
  border: 1px solid var(--border);
  border-radius: 12px;
  background: var(--surface);
  color: var(--ink);
  font-size: 18px;
  font-family: inherit;
  resize: vertical;
}
```

- [ ] **Step 2: Write the failing tests**

Create `apps/web/src/app/(app)/listening/dictation/page.test.tsx`:

```tsx
import { beforeEach, describe, expect, it, vi } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import DictationPage from "./page";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettingsContext } from "@/lib/SettingsContext";
import { getVocabRecords, updateVocabRecordSm2, type VocabRecord } from "@/lib/vocabRecords";
import { generateContent } from "@/lib/generateContent";
import { synthesizeSpeech } from "@/lib/synthesizeSpeechClient";
import { getRandomSavedListeningExercise, saveListeningExercise } from "@/lib/savedListeningExercises";
import { DEFAULT_SETTINGS, type UserSettings } from "@/lib/settings";

vi.mock("@/lib/useAuthUser", () => ({ useAuthUser: vi.fn() }));
vi.mock("@/lib/SettingsContext", () => ({ useSettingsContext: vi.fn() }));
vi.mock("@/lib/vocabRecords", () => ({ getVocabRecords: vi.fn(), updateVocabRecordSm2: vi.fn() }));
vi.mock("@/lib/generateContent", () => ({ generateContent: vi.fn() }));
vi.mock("@/lib/synthesizeSpeechClient", async () => {
  const actual = await vi.importActual<typeof import("@/lib/synthesizeSpeechClient")>("@/lib/synthesizeSpeechClient");
  return { ...actual, synthesizeSpeech: vi.fn() };
});
vi.mock("@/lib/savedListeningExercises", () => ({
  getRandomSavedListeningExercise: vi.fn(),
  saveListeningExercise: vi.fn(),
}));
vi.mock("@/components/SignInButton", () => ({
  SignInButton: () => <button>Đăng nhập với Google</button>,
}));

const pushMock = vi.fn();
const replaceMock = vi.fn();
let mockSearchParams = new URLSearchParams();
vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: pushMock, replace: replaceMock }),
  useSearchParams: () => mockSearchParams,
}));

function setSearchParams(params: Record<string, string>) {
  mockSearchParams = new URLSearchParams(params);
}

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

const SETTINGS_WITH_KEY: UserSettings = {
  ...DEFAULT_SETTINGS,
  activeProvider: "gemini",
  providers: { ...DEFAULT_SETTINGS.providers, gemini: { model: "gemini-2.5-flash", apiKeyCiphertext: "cipher-abc" } },
};

function mockSignedIn(settings: UserSettings = SETTINGS_WITH_KEY) {
  vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" }, loading: false } as never);
  vi.mocked(useSettingsContext).mockReturnValue({ settings, loading: false, error: null, save: vi.fn() });
}

const TWO_WORDS = [
  makeRecord({ id: "v1", headword: "apple" }),
  makeRecord({ id: "v2", headword: "run" }),
];

beforeEach(() => {
  vi.clearAllMocks();
  setSearchParams({ difficulty: "hard", action: "generate" });
  vi.mocked(getVocabRecords).mockResolvedValue(TWO_WORDS);
  vi.mocked(synthesizeSpeech).mockResolvedValue({ audioBase64: "AAAA" });
  vi.mocked(getRandomSavedListeningExercise).mockResolvedValue(null);
});

describe("DictationPage (loading phase)", () => {
  it("prompts sign-in when logged out", () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: null, loading: false } as never);
    vi.mocked(useSettingsContext).mockReturnValue({ settings: null, loading: false, error: null, save: vi.fn() });
    render(<DictationPage />);
    expect(screen.getByText("Đăng nhập với Google")).toBeInTheDocument();
  });

  it("redirects to /listening when the action param is missing", async () => {
    setSearchParams({ difficulty: "hard" });
    mockSignedIn();

    render(<DictationPage />);

    await waitFor(() => expect(replaceMock).toHaveBeenCalledWith("/listening"));
  });

  it("redirects to /listening when the action param is invalid", async () => {
    setSearchParams({ difficulty: "hard", action: "bogus" });
    mockSignedIn();

    render(<DictationPage />);

    await waitFor(() => expect(replaceMock).toHaveBeenCalledWith("/listening"));
  });

  it("auto-generates a sentence from the 2 due-prioritized words on mount", async () => {
    mockSignedIn();
    vi.mocked(generateContent).mockResolvedValue({
      text: JSON.stringify({ target: "I ate an apple.", vietnamese: "Tôi đã ăn một quả táo.", vocabWords: ["apple"] }),
    });

    render(<DictationPage />);

    expect(await screen.findByRole("button", { name: "▶ Phát" })).toBeInTheDocument();
    // Both fixture words have nextReviewAt: null (both "due"), so
    // prioritizeDueWords' internal shuffle can place them in either order —
    // assert both are present rather than asserting one exact order.
    const promptArg = vi.mocked(generateContent).mock.calls[0][0].prompt;
    expect(promptArg).toContain("apple");
    expect(promptArg).toContain("run");
  });

  it("shows an error with retry/back-to-hub actions when the active provider has no API key", async () => {
    mockSignedIn({ ...DEFAULT_SETTINGS, activeProvider: "gemini", providers: { ...DEFAULT_SETTINGS.providers, gemini: { model: "gemini-2.5-flash", apiKeyCiphertext: null } } });

    render(<DictationPage />);

    expect(await screen.findByText("Chưa có API key cho nhà cung cấp AI đang chọn — vào Cài đặt để thêm.")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Thử lại" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Về trang chính" })).toBeInTheDocument();
    expect(generateContent).not.toHaveBeenCalled();
  });

  it("shows an explanatory error when fewer than 2 eligible words exist", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([makeRecord({ id: "v1" })]);

    render(<DictationPage />);

    expect(
      await screen.findByText("Hãy lưu ít nhất 2 từ tiếng Anh vào Ngân hàng từ vựng. Hiện có 1 từ.")
    ).toBeInTheDocument();
    expect(generateContent).not.toHaveBeenCalled();
  });

  it("shows an error when the AI returns an empty sentence, and 'Thử lại' retries the same action", async () => {
    mockSignedIn();
    vi.mocked(generateContent).mockResolvedValueOnce({ text: JSON.stringify({}) });

    render(<DictationPage />);
    await screen.findByText("AI không trả về câu luyện hợp lệ.");

    vi.mocked(generateContent).mockResolvedValue({
      text: JSON.stringify({ target: "I ate an apple.", vietnamese: "V.", vocabWords: ["apple"] }),
    });
    fireEvent.click(screen.getByRole("button", { name: "Thử lại" }));

    await waitFor(() => expect(screen.getByRole("button", { name: "▶ Phát" })).toBeInTheDocument());
  });

  it("action=existing starts a session directly from a matching saved exercise, without calling the AI", async () => {
    setSearchParams({ difficulty: "hard", action: "existing" });
    mockSignedIn();
    vi.mocked(getRandomSavedListeningExercise).mockResolvedValue({
      id: "saved-1",
      type: "dictation",
      item: { target: "I ate an apple.", vietnamese: "V.", vocabIds: ["v1"] },
      generationFilters: { difficulty: "hard" },
      targetLanguage: "english",
      createdAt: "2026-01-01T00:00:00.000Z",
    });

    render(<DictationPage />);

    expect(await screen.findByRole("button", { name: "▶ Phát" })).toBeInTheDocument();
    expect(generateContent).not.toHaveBeenCalled();
  });

  it("action=existing falls back to AI generation with an inline notice when nothing matches", async () => {
    setSearchParams({ difficulty: "hard", action: "existing" });
    mockSignedIn();
    let resolveGenerate!: (value: { text: string }) => void;
    vi.mocked(generateContent).mockReturnValue(
      new Promise((resolve) => {
        resolveGenerate = resolve;
      })
    );

    render(<DictationPage />);

    expect(
      await screen.findByText("Chưa có bài đã lưu khớp bộ lọc này — đang tạo bài mới bằng AI…")
    ).toBeInTheDocument();

    resolveGenerate({ text: JSON.stringify({ target: "I ate an apple.", vietnamese: "V.", vocabWords: ["apple"] }) });
    await waitFor(() => expect(screen.getByRole("button", { name: "▶ Phát" })).toBeInTheDocument());
  });
});

describe("DictationPage (session phase — Khó / free text)", () => {
  async function generateSession() {
    setSearchParams({ difficulty: "hard", action: "generate" });
    vi.mocked(generateContent).mockResolvedValue({
      text: JSON.stringify({ target: "I ate an apple today.", vietnamese: "Tôi đã ăn một quả táo hôm nay.", vocabWords: ["apple"] }),
    });
    render(<DictationPage />);
    await screen.findByRole("button", { name: "▶ Phát" });
  }

  it("keeps Nộp bài disabled until the sentence has been played at least once", async () => {
    mockSignedIn();
    await generateSession();

    expect(screen.getByRole("button", { name: "Nộp bài" })).toBeDisabled();
    fireEvent.click(screen.getByRole("button", { name: "▶ Phát" }));
    await waitFor(() => expect(synthesizeSpeech).toHaveBeenCalledWith({ text: "I ate an apple today.", language: "en" }));
  });

  it("still keeps Nộp bài disabled after playing once, until the textarea has text", async () => {
    mockSignedIn();
    await generateSession();
    fireEvent.click(screen.getByRole("button", { name: "▶ Phát" }));
    await waitFor(() => expect(screen.getByRole("button", { name: "▶ Nghe lại (0)" })).toBeInTheDocument());

    expect(screen.getByRole("button", { name: "Nộp bài" })).toBeDisabled();

    fireEvent.change(screen.getByPlaceholderText("Gõ lại những gì bạn nghe được..."), {
      target: { value: "I ate an apple today." },
    });

    expect(screen.getByRole("button", { name: "Nộp bài" })).not.toBeDisabled();
  });
});

describe("DictationPage (session phase — Dễ/Trung bình / cloze)", () => {
  it("renders inline blank inputs instead of a free-text box for non-hard difficulty", async () => {
    mockSignedIn();
    setSearchParams({ difficulty: "easy", action: "generate" });
    vi.mocked(generateContent).mockResolvedValue({
      text: JSON.stringify({ target: "I ate an apple today.", vietnamese: "V.", vocabWords: ["apple"] }),
    });

    render(<DictationPage />);
    await screen.findByRole("button", { name: "▶ Phát" });

    expect(screen.getByLabelText("Chỗ trống 1")).toBeInTheDocument();
    expect(screen.queryByPlaceholderText("Gõ lại những gì bạn nghe được...")).not.toBeInTheDocument();
  });
});

describe("DictationPage (result phase)", () => {
  async function completeHardSession() {
    setSearchParams({ difficulty: "hard", action: "generate" });
    vi.mocked(generateContent).mockResolvedValue({
      text: JSON.stringify({
        target: "I ate an apple today.",
        vietnamese: "Tôi đã ăn một quả táo hôm nay.",
        vocabWords: ["apple", "run"],
      }),
    });
    render(<DictationPage />);
    await screen.findByRole("button", { name: "▶ Phát" });
    fireEvent.click(screen.getByRole("button", { name: "▶ Phát" }));
    await waitFor(() => expect(screen.getByRole("button", { name: "▶ Nghe lại (0)" })).toBeInTheDocument());
    fireEvent.change(screen.getByPlaceholderText("Gõ lại những gì bạn nghe được..."), {
      target: { value: "I ate an apple today." },
    });
    fireEvent.click(screen.getByRole("button", { name: "Nộp bài" }));
    await screen.findByText("100%");
  }

  it("shows the score, correct sentence, meaning, and character diff for a Khó session", async () => {
    mockSignedIn();
    await completeHardSession();

    expect(screen.getByText("100%")).toBeInTheDocument();
    expect(screen.getByText("I ate an apple today.")).toBeInTheDocument();
    expect(screen.getByText("Tôi đã ăn một quả táo hôm nay.")).toBeInTheDocument();
    expect(screen.getByTestId("diff-text")).toBeInTheDocument();
  });

  it("updates SM-2 for both vocab words used, best-effort", async () => {
    mockSignedIn();
    await completeHardSession();

    await waitFor(() => expect(updateVocabRecordSm2).toHaveBeenCalledWith("u1", "v2", expect.any(Object)));
  });

  it('shows "Lưu bài" for a generated session and saves with type "dictation"', async () => {
    mockSignedIn();
    vi.mocked(saveListeningExercise).mockResolvedValue("new-id");
    await completeHardSession();

    fireEvent.click(screen.getByRole("button", { name: "Lưu bài" }));

    expect(await screen.findByText("Đã lưu ✔")).toBeInTheDocument();
    expect(saveListeningExercise).toHaveBeenCalledWith(
      "u1",
      expect.objectContaining({ target: "I ate an apple today." }),
      { difficulty: "hard" },
      "english"
    );
  });

  it('"Về trang chính" navigates back to the listening hub', async () => {
    mockSignedIn();
    await completeHardSession();

    fireEvent.click(screen.getByRole("button", { name: "Về trang chính" }));

    expect(pushMock).toHaveBeenCalledWith("/listening");
  });

  it("hides the Lưu bài button for a reused session's result screen", async () => {
    mockSignedIn();
    setSearchParams({ difficulty: "hard", action: "existing" });
    vi.mocked(getRandomSavedListeningExercise).mockResolvedValue({
      id: "saved-1",
      type: "dictation",
      item: { target: "I ate an apple today.", vietnamese: "V.", vocabIds: ["v1"] },
      generationFilters: { difficulty: "hard" },
      targetLanguage: "english",
      createdAt: "2026-01-01T00:00:00.000Z",
    });
    render(<DictationPage />);
    await screen.findByRole("button", { name: "▶ Phát" });
    fireEvent.click(screen.getByRole("button", { name: "▶ Phát" }));
    await waitFor(() => expect(screen.getByRole("button", { name: "▶ Nghe lại (0)" })).toBeInTheDocument());
    fireEvent.change(screen.getByPlaceholderText("Gõ lại những gì bạn nghe được..."), {
      target: { value: "I ate an apple today." },
    });
    fireEvent.click(screen.getByRole("button", { name: "Nộp bài" }));
    await screen.findByText("100%");

    expect(screen.queryByRole("button", { name: "Lưu bài" })).not.toBeInTheDocument();
  });
});
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `cd apps/web && npx vitest run --run "src/app/(app)/listening/dictation/page.test.tsx"`
Expected: FAIL — the page doesn't exist yet.

- [ ] **Step 4: Implement the page**

Create `apps/web/src/app/(app)/listening/dictation/page.tsx`:

```tsx
"use client";

import { Suspense, useEffect, useRef, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettingsContext } from "@/lib/SettingsContext";
import { SignInButton } from "@/components/SignInButton";
import { getVocabRecords, updateVocabRecordSm2, type VocabRecord } from "@/lib/vocabRecords";
import { computeSm2 } from "@/lib/sm2";
import { generateContent } from "@/lib/generateContent";
import { parseAiJsonObject } from "@/lib/parseAiJson";
import {
  buildDictationPrompt,
  parseDictationItem,
  selectDictationBlanks,
  prioritizeDueWords,
  targetWords,
  computeDictationScore,
  sm2QualityFromScore,
  type DictationItem,
  type DictationDifficulty,
  type BlankSpan,
} from "@/lib/dictation";
import { saveListeningExercise, getRandomSavedListeningExercise } from "@/lib/savedListeningExercises";
import { useDictationAudio } from "@/lib/useDictationAudio";
import { ClozeInput } from "@/components/listening/ClozeInput";
import { ClozeResult } from "@/components/listening/ClozeResult";
import { DiffText } from "@/components/listening/DiffText";

type Phase = "loading" | "session" | "result";
const MIN_VOCAB_WORDS = 2;
const SPEEDS = [0.75, 1, 1.25] as const;

function isDifficulty(value: string | null): value is DictationDifficulty {
  return value === "easy" || value === "medium" || value === "hard";
}

function formatDuration(ms: number): string {
  const totalSeconds = Math.round(ms / 1000);
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  return minutes > 0 ? `${minutes}m ${seconds}s` : `${seconds}s`;
}

function DictationPageContent() {
  const { user, loading: authLoading } = useAuthUser();
  const { settings, loading: settingsLoading } = useSettingsContext();
  const router = useRouter();
  const searchParams = useSearchParams();

  const difficultyParam = searchParams.get("difficulty");
  const difficulty: DictationDifficulty = isDifficulty(difficultyParam) ? difficultyParam : "hard";
  const action = searchParams.get("action");

  const [records, setRecords] = useState<VocabRecord[] | null>(null);

  const [phase, setPhase] = useState<Phase>("loading");
  const [generating, setGenerating] = useState(false);
  const [fetchingSaved, setFetchingSaved] = useState(false);
  const [generateError, setGenerateError] = useState<string | null>(null);
  const [savedNotice, setSavedNotice] = useState<string | null>(null);
  const [item, setItem] = useState<DictationItem | null>(null);
  const [blanks, setBlanks] = useState<BlankSpan[]>([]);
  const [typed, setTyped] = useState("");
  const [blankAnswers, setBlankAnswers] = useState<string[]>([]);
  const [sessionMode, setSessionMode] = useState<"generated" | "reused">("generated");
  const [justSavedId, setJustSavedId] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [sessionStartedAt, setSessionStartedAt] = useState(0);
  const [durationMs, setDurationMs] = useState(0);
  const [finalScore, setFinalScore] = useState(0);

  const audio = useDictationAudio(item?.target ?? "");

  useEffect(() => {
    if (!user) return;
    getVocabRecords(user.uid)
      .then(setRecords)
      .catch(() => setRecords([]));
  }, [user]);

  function startSession(newItem: DictationItem, mode: "generated" | "reused") {
    const computedBlanks = selectDictationBlanks(newItem.target, difficulty);
    setSessionMode(mode);
    setJustSavedId(null);
    setSaveError(null);
    setItem(newItem);
    setBlanks(computedBlanks);
    setTyped("");
    setBlankAnswers(new Array(computedBlanks.length).fill(""));
    setSessionStartedAt(Date.now());
    setPhase("session");
  }

  async function handleGenerate() {
    if (!user || !settings || records === null) return;
    const activeConfig = settings.providers[settings.activeProvider];
    if (!activeConfig.apiKeyCiphertext) {
      setGenerateError("Chưa có API key cho nhà cung cấp AI đang chọn — vào Cài đặt để thêm.");
      return;
    }
    const eligible = records.filter((r) => r.targetLanguage === "english");
    const words = prioritizeDueWords(eligible).slice(0, MIN_VOCAB_WORDS);
    if (words.length < MIN_VOCAB_WORDS) {
      setGenerateError(`Hãy lưu ít nhất ${MIN_VOCAB_WORDS} từ tiếng Anh vào Ngân hàng từ vựng. Hiện có ${eligible.length} từ.`);
      return;
    }
    setGenerating(true);
    setGenerateError(null);
    try {
      const wordMap: Record<string, string> = {};
      for (const w of words) wordMap[w.headword] = w.id;
      const prompt = buildDictationPrompt(words.map((w) => w.headword), "english");
      const response = await generateContent({
        provider: settings.activeProvider,
        model: activeConfig.model,
        apiKeyCiphertext: activeConfig.apiKeyCiphertext,
        prompt,
      });
      const json = parseAiJsonObject(response.text);
      const generated = parseDictationItem(json, wordMap);
      if (generated.target.length === 0) {
        throw new Error("AI không trả về câu luyện hợp lệ.");
      }
      startSession(generated, "generated");
    } catch (err) {
      setGenerateError(err instanceof Error ? err.message : String(err));
    } finally {
      setGenerating(false);
      setSavedNotice(null);
    }
  }

  async function fetchSavedExercise(excludeId?: string): Promise<boolean> {
    if (!user || !settings) return false;
    setGenerateError(null);
    setSavedNotice(null);
    setFetchingSaved(true);
    let found = false;
    try {
      const saved = await getRandomSavedListeningExercise(user.uid, "english", { difficulty }, excludeId);
      if (saved) {
        found = true;
        startSession(saved.item, "reused");
      } else {
        setSavedNotice("Chưa có bài đã lưu khớp bộ lọc này — đang tạo bài mới bằng AI…");
      }
    } catch (err) {
      setGenerateError(err instanceof Error ? err.message : String(err));
      return true;
    } finally {
      setFetchingSaved(false);
    }
    if (!found) {
      await handleGenerate();
      return true;
    }
    return found;
  }

  async function runAction() {
    if (action === "generate") {
      await handleGenerate();
    } else if (action === "existing") {
      await fetchSavedExercise();
    }
  }

  const triggeredRef = useRef(false);
  useEffect(() => {
    if (!user || !settings || records === null) return;
    if (action !== "generate" && action !== "existing") {
      router.replace("/listening");
      return;
    }
    if (triggeredRef.current) return;
    triggeredRef.current = true;
    void runAction();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [user, settings, records, action]);

  async function handleSubmit() {
    if (!item) return;
    const duration = Date.now() - sessionStartedAt;
    const score = computeDictationScore({
      difficulty,
      target: item.target,
      typed,
      blanks,
      blankAnswers,
      replayCount: audio.replayCount,
      seekPenaltyTotal: audio.seekPenaltyTotal,
    });
    setDurationMs(duration);
    setFinalScore(score);
    setPhase("result");

    if (!user) return;
    const quality = sm2QualityFromScore(score);
    for (const vocabId of item.vocabIds) {
      try {
        const record = (records ?? []).find((r) => r.id === vocabId);
        if (!record) continue;
        await updateVocabRecordSm2(user.uid, vocabId, computeSm2(record, quality));
      } catch {
        // best-effort — one record's failure shouldn't block the others
      }
    }
  }

  async function handleSaveExercise() {
    if (saving || !user || !item) return;
    setSaving(true);
    setSaveError(null);
    try {
      const newId = await saveListeningExercise(user.uid, item, { difficulty }, "english");
      setJustSavedId(newId);
    } catch (err) {
      setSaveError(err instanceof Error ? err.message : String(err));
    } finally {
      setSaving(false);
    }
  }

  async function handleNewSession() {
    if (sessionMode === "reused") {
      await fetchSavedExercise(justSavedId ?? undefined);
      return;
    }
    await handleGenerate();
  }

  function handleBlankChange(blankIndex: number, text: string) {
    setBlankAnswers((prev) => {
      const next = [...prev];
      next[blankIndex] = text;
      return next;
    });
  }

  if (authLoading) return <p>Đang tải…</p>;

  if (!user) {
    return (
      <div>
        <h2 className="scr-title">Nghe chép</h2>
        <p className="scr-sub">Đăng nhập để luyện tập.</p>
        <SignInButton />
      </div>
    );
  }

  if (settingsLoading || !settings) return <p>Đang tải…</p>;

  if (phase === "loading") {
    return (
      <div>
        <h2 className="scr-title">Nghe chép</h2>
        {(generating || fetchingSaved) && <p>{generating ? "Đang tạo bài…" : "Đang tìm bài…"}</p>}
        {savedNotice && <p className="reading-saved-notice">{savedNotice}</p>}
        {generateError && (
          <>
            <p role="alert">{generateError}</p>
            <div className="reading-result-actions">
              <button type="button" className="btn-secondary" onClick={() => router.push("/listening")}>
                Về trang chính
              </button>
              <button type="button" className="btn-primary" onClick={() => void runAction()}>
                Thử lại
              </button>
            </div>
          </>
        )}
      </div>
    );
  }

  if (phase === "session" && item) {
    const isCloze = difficulty !== "hard";
    const canSubmit =
      audio.hasPlayedOnce && (isCloze ? blankAnswers.every((a) => a.trim().length > 0) : typed.trim().length > 0);
    const words = targetWords(item.target);

    return (
      <div>
        <h2 className="scr-title">Nghe chép</h2>
        <div className="reading-submit-bar">
          <span className="reading-progress-label">
            {audio.hasPlayedOnce ? "Đã nghe — điền đầy đủ để nộp bài" : "Hãy nghe ít nhất 1 lần trước khi nộp"}
          </span>
          <button type="button" className="btn-primary" onClick={() => void handleSubmit()} disabled={!canSubmit}>
            Nộp bài
          </button>
        </div>
        {audio.error && <p role="alert">{audio.error}</p>}
        <div className="dictation-controls">
          <button type="button" className="btn-primary" onClick={() => void audio.play()} disabled={audio.isLoading}>
            {audio.hasPlayedOnce ? `▶ Nghe lại (${audio.replayCount})` : "▶ Phát"}
          </button>
          <div className="dictation-speed-selector">
            {SPEEDS.map((s) => (
              <button
                key={s}
                type="button"
                className={`vb-chip${audio.speed === s ? " active" : ""}`}
                onClick={() => audio.setSpeed(s)}
              >
                {s}x
              </button>
            ))}
          </div>
        </div>
        {words.length > 1 && (
          <input
            type="range"
            min={0}
            max={words.length - 1}
            step={1}
            className="dictation-seek-slider"
            aria-label="Tua theo từ"
            onChange={(e) => void audio.seekTo(Number(e.target.value))}
          />
        )}
        <div className="reading-session-body">
          {isCloze ? (
            <ClozeInput target={item.target} blanks={blanks} answers={blankAnswers} onAnswerChange={handleBlankChange} />
          ) : (
            <textarea
              className="dictation-free-input"
              value={typed}
              onChange={(e) => setTyped(e.target.value)}
              placeholder="Gõ lại những gì bạn nghe được..."
            />
          )}
        </div>
      </div>
    );
  }

  const scorePct = Math.round(finalScore * 100);
  const seekPenaltyPct = Math.round(audio.seekPenaltyTotal * 100);

  return (
    <div>
      <h2 className="scr-title">Kết quả</h2>
      <div className="reading-result-stats">
        <div className="reading-stat-card">
          <span className="reading-stat-label">Điểm</span>
          <span className="reading-stat-value">{scorePct}%</span>
        </div>
        <div className="reading-stat-card">
          <span className="reading-stat-label">Nghe lại</span>
          <span className="reading-stat-value">{audio.replayCount}</span>
        </div>
        <div className="reading-stat-card">
          <span className="reading-stat-label">Số lần tua</span>
          <span className="reading-stat-value">
            {audio.seekCount} (−{seekPenaltyPct}%)
          </span>
        </div>
        <div className="reading-stat-card">
          <span className="reading-stat-label">Thời gian</span>
          <span className="reading-stat-value">{formatDuration(durationMs)}</span>
        </div>
      </div>
      <h3>Bạn đã gõ</h3>
      {difficulty === "hard" ? (
        <DiffText typed={typed} target={item?.target ?? ""} />
      ) : (
        <ClozeResult target={item?.target ?? ""} blanks={blanks} answers={blankAnswers} />
      )}
      <h3>Câu đúng</h3>
      <p>{item?.target}</p>
      <h3>Nghĩa</h3>
      <p>{item?.vietnamese}</p>
      <div className="reading-result-actions">
        {sessionMode === "generated" &&
          (justSavedId ? (
            <span className="reading-saved-mark">Đã lưu ✔</span>
          ) : (
            <button type="button" className="btn-secondary" onClick={() => void handleSaveExercise()} disabled={saving}>
              {saving ? "Đang lưu…" : "Lưu bài"}
            </button>
          ))}
        <button type="button" className="btn-secondary" onClick={() => router.push("/listening")}>
          Về trang chính
        </button>
        <button type="button" className="btn-primary" onClick={() => void handleNewSession()}>
          Câu khác
        </button>
      </div>
      {saveError && <p role="alert">{saveError}</p>}
      {savedNotice && <p className="reading-saved-notice">{savedNotice}</p>}
      {generateError && <p role="alert">{generateError}</p>}
    </div>
  );
}

export default function DictationPage() {
  return (
    <Suspense fallback={<p>Đang tải…</p>}>
      <DictationPageContent />
    </Suspense>
  );
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `cd apps/web && npx vitest run --run "src/app/(app)/listening/dictation/page.test.tsx"`
Expected: PASS, all tests green.

- [ ] **Step 6: Run the full suite, typecheck, and build**

Run: `cd apps/web && npm test -- --run && npx tsc --noEmit && npm run build`
Expected: all tests pass (aside from the known pre-existing `bloom.test.ts` failure); no type errors; build succeeds with `/listening` and `/listening/dictation` prerendered as static pages (confirms the `Suspense` boundary correctly wraps the `useSearchParams()`-consuming component).

- [ ] **Step 7: Commit**

```bash
git add "apps/web/src/app/(app)/listening/dictation/page.tsx" "apps/web/src/app/(app)/listening/dictation/page.test.tsx" apps/web/src/styles/bloom.css
git commit -m "feat(web): add /listening/dictation — Nghe chép practice with save/reuse"
```

---

## Final verification (after all 7 tasks)

- [ ] Run the full suite once more: `cd apps/web && npm test -- --run` — expect all tests green apart from the known pre-existing, unrelated `bloom.test.ts` failure.
- [ ] `cd apps/web && npx tsc --noEmit` — expect no errors.
- [ ] `cd apps/web && npm run build` — expect a clean production build with `/listening` and `/listening/dictation` statically prerendered.
- [ ] Manually walk through the flow in a browser (target language must be English in Cài đặt first): from `/listening`, pick a difficulty, generate — confirm audio actually plays through browser speakers, the speed buttons audibly change pitch/rate, the seek slider re-fetches and plays from the chosen word, and submit is blocked until you've played at least once. Try all 3 difficulties (Khó = free-text box; Dễ/Trung bình = inline blanks). Confirm the result screen's score, diff/cloze view, SM-2 update (check the 2 used words' next-review date changed in Ngân hàng từ vựng), "Lưu bài", "Câu khác", and "🔀 Lấy bài có sẵn" all work. Try switching target language away from English in Cài đặt and confirm `/listening` shows the blocking message instead of the setup UI.
