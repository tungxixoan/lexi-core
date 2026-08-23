# TOEIC Reading Part 6 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add TOEIC Reading Part 6 ("Điền đoạn văn" / Text Completion) to the web app's `/reading` hub, reusing the already-shipped Part 5 / hub-merge architecture end to end (topic-based shared filter, hub-driven navigation, save/reuse via `savedReadingExercises.ts`, `McQuestionCard` for every blank).

**Architecture:** `apps/web/src/lib/part6.ts` ports Flutter's `part6_source.dart` prompt/parser, taking resolved topic names (not a fixed enum) exactly like `part5.ts` already does. `savedReadingExercises.ts` gains one new `"part6"` union member reusing the existing `ToeicFilters` shape unchanged — no function bodies change. The hub gains a third mode. `/reading/part6/page.tsx` is structurally identical to `/reading/part5/page.tsx` (same URL-driven auto-trigger, same phases), differing only in its prompt/parse calls and in grouping 4 `McQuestionCard`s per passage (3 passages × 4 blanks = 12 total) instead of Part 5's flat 15-question list.

**Tech Stack:** Next.js 16 (App Router) on `apps/web/`, React 19, Firebase JS SDK v12, Vitest + React Testing Library + jsdom.

## Global Constraints

- All user-facing text is Vietnamese, matching every existing screen.
- Import alias `@/` maps to `apps/web/src/`.
- Every changed/new file's tests are updated/added to match.
- Part 6's "Tạo bài luyện" is never gated by word count (same as Part 5) — the hub's min-5-word gate applies only to Đọc & gõ.
- Part 6 introduces no new query parameter — it reuses `topicIds`, `volumes`, and `action` exactly as Part 5 already encodes them.
- "Select the sentence that best fits" blanks get no special UI treatment anywhere — they render through the exact same `McQuestionCard` as word/phrase blanks, matching Flutter's own session screen.
- Verify each task with `npm --prefix apps/web test` (full suite) and finish the plan with `npx tsc --noEmit -p apps/web/tsconfig.json` and `npm --prefix apps/web run build`.
- One pre-existing, unrelated test failure is expected in `src/styles/bloom.test.ts` (an `.app-frame` CSS-lock assertion) — not something any task here should fix.
- Spec: `docs/superpowers/specs/2026-08-23-toeic-reading-part6-design.md` — read it if anything below is ambiguous.

---

## Task 1: `part6.ts` — prompt builder and response parser

**Files:**
- Create: `apps/web/src/lib/part6.ts`
- Create: `apps/web/src/lib/part6.test.ts`

**Interfaces:**
- Produces (used by Tasks 2 and 4):
  - `interface Part6Question { options: string[]; correctIndex: number; explanation: string }`
  - `interface Part6Passage { passageText: string; questions: Part6Question[] }`
  - `interface Part6Set { passages: Part6Passage[] }`
  - `function buildPart6Prompt(topicNames: string[], targetLanguage: TargetLanguage, volumes: EconomyVolume[]): string`
  - `function parsePart6Set(json: Record<string, unknown>): Part6Set`

- [ ] **Step 1: Write the failing tests**

Create `apps/web/src/lib/part6.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import { buildPart6Prompt, parsePart6Set } from "./part6";

describe("buildPart6Prompt", () => {
  it("includes topic names, target language label, and asks for exactly 3 passages of 4 blanks each in JSON", () => {
    const prompt = buildPart6Prompt(["Business"], "english", ["vol3"]);
    expect(prompt).toContain("Business");
    expect(prompt).toContain("English");
    expect(prompt).toContain("exactly 3");
    expect(prompt).toContain("exactly 4");
    expect(prompt).toContain("JSON only");
    expect(prompt).toContain('"passages"');
  });

  it("joins multiple topic names with a slash", () => {
    const prompt = buildPart6Prompt(["Business", "Travel"], "english", ["vol3"]);
    expect(prompt).toContain("Business/Travel");
  });

  it("omits the register clause entirely when no topics are selected", () => {
    const prompt = buildPart6Prompt([], "english", ["vol2"]);
    expect(prompt).not.toContain("register/setting");
  });

  it("requires at least one 'select the best sentence' blank per passage", () => {
    const prompt = buildPart6Prompt([], "english", ["vol2"]);
    expect(prompt).toContain("select the sentence that");
  });

  it("includes the prompt hint for every requested volume", () => {
    const prompt = buildPart6Prompt([], "english", ["vol2", "vol4"]);
    expect(prompt).toContain("easy-medium difficulty");
    expect(prompt).toContain("unusual grammar/vocabulary traps");
  });

  it("uses every volume's hint when the volumes list is empty (matches Flutter's 'empty = all' default)", () => {
    const prompt = buildPart6Prompt([], "english", []);
    expect(prompt).toContain("easy-medium difficulty");
    expect(prompt).toContain("medium-high difficulty");
    expect(prompt).toContain("equal to or harder than the real exam");
    expect(prompt).toContain("deepest grammar traps");
  });

  it("uses the target language's own label, not always English", () => {
    const prompt = buildPart6Prompt([], "korean", ["vol2"]);
    expect(prompt).toContain("한국어");
  });

  it("requires Vietnamese-script-only explanations", () => {
    const prompt = buildPart6Prompt([], "english", ["vol2"]);
    expect(prompt).toContain("Vietnamese script");
  });
});

describe("parsePart6Set", () => {
  it("parses a full set of passages", () => {
    const json = {
      passages: [
        {
          passageText: "... (1)___ ... (2)___ ... (3)___ ... (4)___ ...",
          questions: [
            { options: ["a", "b", "c", "d"], correctIndex: 0, explanation: "A." },
            { options: ["a", "b", "c", "d"], correctIndex: 1, explanation: "B." },
            { options: ["a", "b", "c", "d"], correctIndex: 2, explanation: "C." },
            { options: ["a", "b", "c", "d"], correctIndex: 3, explanation: "D." },
          ],
        },
      ],
    };

    const result = parsePart6Set(json);

    expect(result.passages).toHaveLength(1);
    expect(result.passages[0].passageText).toBe("... (1)___ ... (2)___ ... (3)___ ... (4)___ ...");
    expect(result.passages[0].questions).toHaveLength(4);
    expect(result.passages[0].questions[2]).toEqual({ options: ["a", "b", "c", "d"], correctIndex: 2, explanation: "C." });
  });

  it("falls back to empty passages when the response is missing fields", () => {
    const result = parsePart6Set({});
    expect(result).toEqual({ passages: [] });
  });

  it("drops a passage that doesn't have exactly 4 questions", () => {
    const json = {
      passages: [
        {
          passageText: "short one",
          questions: [{ options: ["a", "b", "c", "d"], correctIndex: 0, explanation: "A." }],
        },
      ],
    };
    const result = parsePart6Set(json);
    expect(result.passages).toEqual([]);
  });

  it("tolerates malformed question entries by defaulting their fields, keeping the passage if it still has 4", () => {
    const result = parsePart6Set({
      passages: [{ passageText: "p", questions: [{}, {}, {}, {}] }],
    });
    expect(result.passages).toHaveLength(1);
    expect(result.passages[0].questions).toEqual([
      { options: [], correctIndex: 0, explanation: "" },
      { options: [], correctIndex: 0, explanation: "" },
      { options: [], correctIndex: 0, explanation: "" },
      { options: [], correctIndex: 0, explanation: "" },
    ]);
  });

  it("ignores non-object entries in the passages array", () => {
    const result = parsePart6Set({ passages: ["not an object", null, 42] });
    expect(result.passages).toEqual([]);
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd apps/web && npx vitest run --run src/lib/part6.test.ts`
Expected: FAIL — `./part6` doesn't exist yet.

- [ ] **Step 3: Implement `part6.ts`**

Create `apps/web/src/lib/part6.ts`:

```ts
import { LANGUAGE_LABELS, type TargetLanguage } from "./languages";
import { ECONOMY_VOLUMES, VOLUME_PROMPT_HINTS, type EconomyVolume } from "./toeicFilters";

export interface Part6Question {
  options: string[]; // always 4 — words/phrases OR full candidate sentences
  correctIndex: number;
  explanation: string; // Vietnamese
}

export interface Part6Passage {
  passageText: string; // blanks inline, e.g. "... the office (1)___ Monday ..."
  questions: Part6Question[]; // always 4, ordered to match blank numbering
}

export interface Part6Set {
  passages: Part6Passage[]; // always 3
}

const PASSAGE_COUNT = 3;
const BLANKS_PER_PASSAGE = 4;

// Ports lib/features/reading/data/sources/part6_source.dart's prompt. Takes
// resolved topic *names*, not a fixed enum — same shared "Chủ đề" filter
// every reading mode uses, per the hub/setup-merge spec. An empty topic list
// omits the register clause entirely rather than defaulting to a fake
// "general" register.
export function buildPart6Prompt(topicNames: string[], targetLanguage: TargetLanguage, volumes: EconomyVolume[]): string {
  const languageLabel = LANGUAGE_LABELS[targetLanguage];
  const contextClause = topicNames.length > 0 ? `, in a ${topicNames.join("/")} register/setting` : "";
  const effectiveVolumes = volumes.length === 0 ? ECONOMY_VOLUMES : volumes;
  const volumeHints = effectiveVolumes.map((v) => `${v}: ${VOLUME_PROMPT_HINTS[v]}`).join("; ");
  return (
    `You are creating a TOEIC Part 6 (Text Completion) practice set for a Vietnamese speaker ` +
    `learning ${languageLabel}${contextClause}, calibrated to the Economy TOEIC difficulty ` +
    `volumes below (mix passages across them roughly evenly and randomly): ${volumeHints}. ` +
    `Write exactly ${PASSAGE_COUNT} short realistic business documents (choose from: email, ` +
    `memo, notice, advertisement, article), each with exactly ${BLANKS_PER_PASSAGE} numbered ` +
    `blanks marked inline as "(1)___", "(2)___", "(3)___", "(4)___" in reading order. ` +
    `For each passage, at least one of its 4 blanks must be a "select the sentence that ` +
    `best fits" item, where all 4 options are full candidate sentences instead of single ` +
    `words/phrases — the other blanks use word/phrase options (word form, verb tense, ` +
    `preposition, conjunction, transition word). Every blank has exactly 4 options and a ` +
    `brief explanation (in Vietnamese) of why the correct option is right. ` +
    `The explanation must use only Vietnamese script — never Chinese, Japanese, or other ` +
    `non-Vietnamese characters. ` +
    `Respond with JSON only (no markdown, no code fences): ` +
    `{"passages": [{"passageText": "... (1)___ ... (2)___ ... (3)___ ... (4)___ ...", ` +
    `"questions": [{"options": ["...", "...", "...", "..."], "correctIndex": 0, ` +
    `"explanation": "..."}]}]}`
  );
}

export function parsePart6Set(json: Record<string, unknown>): Part6Set {
  const rawPassages = Array.isArray(json.passages) ? json.passages : [];
  const passages: Part6Passage[] = [];
  for (const raw of rawPassages) {
    if (typeof raw !== "object" || raw === null) continue;
    const p = raw as Record<string, unknown>;
    const rawQuestions = Array.isArray(p.questions) ? p.questions : [];
    const questions: Part6Question[] = [];
    for (const rq of rawQuestions) {
      if (typeof rq !== "object" || rq === null) continue;
      const q = rq as Record<string, unknown>;
      questions.push({
        options: Array.isArray(q.options) ? q.options.map(String) : [],
        correctIndex: typeof q.correctIndex === "number" ? q.correctIndex : 0,
        explanation: typeof q.explanation === "string" ? q.explanation : "",
      });
    }
    // Mirrors Flutter's own `.where((p) => p.questions.length == _blanksPerPassage)`
    // filter — a passage with the wrong blank count can't render against the
    // fixed "(1)"-"(4)" labeling, so it's dropped rather than shown broken.
    if (questions.length !== BLANKS_PER_PASSAGE) continue;
    passages.push({
      passageText: typeof p.passageText === "string" ? p.passageText : "",
      questions,
    });
  }
  return { passages };
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd apps/web && npx vitest run --run src/lib/part6.test.ts`
Expected: PASS, all tests green.

- [ ] **Step 5: Typecheck**

Run: `cd apps/web && npx tsc --noEmit`
Expected: no errors.

- [ ] **Step 6: Commit**

```bash
git add apps/web/src/lib/part6.ts apps/web/src/lib/part6.test.ts
git commit -m "feat(web): add Part 6 prompt builder and response parser"
```

---

## Task 2: `savedReadingExercises.ts` — add the `"part6"` variant

**Files:**
- Modify: `apps/web/src/lib/savedReadingExercises.ts`
- Modify: `apps/web/src/lib/savedReadingExercises.test.ts`

**Interfaces:**
- Consumes: `Part6Set` (`@/lib/part6`, from Task 1).
- Produces (used by Task 4): `SavedReadingExercise` gains a `{ id: string; type: "part6"; passage: Part6Set; generationFilters: ToeicFilters; targetLanguage: TargetLanguage; createdAt: string }` member. `saveReadingExercise`/`getRandomSavedExercise` accept `"part6"` as their `type` argument with no signature change (already generic over the union).

- [ ] **Step 1: Write the failing tests**

In `apps/web/src/lib/savedReadingExercises.test.ts`, add this import:

```ts
import type { Part6Set } from "./part6";
```

Add this fixture right after `PART5_PASSAGE`'s declaration (reusing the existing `FakeToeicFilters` interface already defined in this file — Part 6 shares the identical filter shape with Part 5):

```ts
const PART6_PASSAGE: Part6Set = {
  passages: [
    {
      passageText: "... (1)___ ... (2)___ ... (3)___ ... (4)___ ...",
      questions: [
        { options: ["a", "b", "c", "d"], correctIndex: 0, explanation: "A." },
        { options: ["a", "b", "c", "d"], correctIndex: 1, explanation: "B." },
        { options: ["a", "b", "c", "d"], correctIndex: 2, explanation: "C." },
        { options: ["a", "b", "c", "d"], correctIndex: 3, explanation: "D." },
      ],
    },
  ],
};
```

Add this factory right after `makePart5Exercise`:

```ts
function makePart6Exercise(overrides: Partial<{ id: string; generationFilters: FakeToeicFilters }> = {}) {
  return {
    id: "p6-1",
    type: "part6" as const,
    passage: PART6_PASSAGE,
    generationFilters: { topicIds: ["biz-1"], volumes: ["vol3"] },
    targetLanguage: "english" as const,
    createdAt: "2026-01-01T00:00:00.000Z",
    ...overrides,
  };
}
```

Add this test inside the existing `describe("saveReadingExercise", ...)` block, after the "creates a part5 document..." test:

```ts
  it("creates a part6 document carrying its own id field, and returns that id", async () => {
    vi.mocked(doc).mockReturnValue({ id: "new-p6-id" } as never);
    const filters = { topicIds: ["biz-1"], volumes: ["vol3"] };

    const newId = await saveReadingExercise("user-123", "part6", PART6_PASSAGE, filters, "english");

    expect(setDoc).toHaveBeenCalledWith(
      { id: "new-p6-id" },
      expect.objectContaining({
        id: "new-p6-id",
        type: "part6",
        passage: PART6_PASSAGE,
        generationFilters: filters,
        targetLanguage: "english",
      })
    );
    expect(newId).toBe("new-p6-id");
  });
```

Add these tests inside the existing `describe("getRandomSavedExercise", ...)` block, after the part5 matching tests:

```ts
  it("matches part6 exercises by topic overlap and volume overlap, mirroring part5's matching", async () => {
    const p6 = makePart6Exercise({ generationFilters: { topicIds: ["biz-1", "travel-1"], volumes: ["vol2", "vol3"] } });
    vi.mocked(getDocs).mockResolvedValue({ docs: [{ id: p6.id, data: () => p6 }] } as never);

    const result = await getRandomSavedExercise("user-123", "english", "part6", {
      topicIds: ["travel-1", "food-1"],
      volumes: ["vol3", "vol4"],
    } as never);

    expect(result?.id).toBe(p6.id);
  });

  it("does not match a part6 exercise when there is no topic overlap", async () => {
    const p6 = makePart6Exercise({ generationFilters: { topicIds: ["biz-1"], volumes: [] } });
    vi.mocked(getDocs).mockResolvedValue({ docs: [{ id: p6.id, data: () => p6 }] } as never);

    const result = await getRandomSavedExercise("user-123", "english", "part6", {
      topicIds: ["travel-1"],
      volumes: [],
    } as never);

    expect(result).toBeNull();
  });

  it("does not return a part5 exercise when requesting type part6, even though both share the same ToeicFilters shape", async () => {
    const p5 = makePart5Exercise({ generationFilters: { topicIds: ["biz-1"], volumes: ["vol3"] } });
    const p6 = makePart6Exercise({ generationFilters: { topicIds: ["biz-1"], volumes: ["vol3"] } });
    vi.mocked(getDocs).mockResolvedValue({
      docs: [
        { id: p5.id, data: () => p5 },
        { id: p6.id, data: () => p6 },
      ],
    } as never);

    const result = await getRandomSavedExercise("user-123", "english", "part6", {
      topicIds: ["biz-1"],
      volumes: ["vol3"],
    } as never);

    expect(result?.type).toBe("part6");
    expect(result?.id).toBe(p6.id);
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd apps/web && npx vitest run --run src/lib/savedReadingExercises.test.ts`
Expected: FAIL — `"part6"` isn't a valid `type` yet (TypeScript error surfaced as a test failure/compile error).

- [ ] **Step 3: Add the `"part6"` union member**

In `apps/web/src/lib/savedReadingExercises.ts`, add this import:

```ts
import type { Part6Set } from "./part6";
```

Add a new member to the `SavedReadingExercise` union, after the `"part5"` member:

```ts
  | {
      id: string;
      type: "part6";
      passage: Part6Set;
      generationFilters: ToeicFilters;
      targetLanguage: TargetLanguage;
      createdAt: string;
    };
```

(Remember to move the trailing `;` from the old last member — `"part5"` — onto this new one, since it's now the last member of the union.)

No other line in this file changes — `matchesToeic`, `FiltersFor`/`PassageFor`, `saveReadingExercise`, and `getRandomSavedExercise`'s dispatch are all already generic over every member of `SavedReadingExercise`.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd apps/web && npx vitest run --run src/lib/savedReadingExercises.test.ts`
Expected: PASS, all tests green.

- [ ] **Step 5: Run the full suite and typecheck**

Run: `cd apps/web && npm test -- --run && npx tsc --noEmit`
Expected: all tests pass (aside from the known pre-existing `bloom.test.ts` failure); no type errors.

- [ ] **Step 6: Commit**

```bash
git add apps/web/src/lib/savedReadingExercises.ts apps/web/src/lib/savedReadingExercises.test.ts
git commit -m "feat(web): add the part6 variant to SavedReadingExercise"
```

---

## Task 3: Add Part 6 to the reading hub

**Files:**
- Modify: `apps/web/src/app/(app)/reading/page.tsx`
- Modify: `apps/web/src/app/(app)/reading/page.test.tsx`

**Interfaces:**
- Produces (used by Task 4, as the URL shape it must read): navigating to Part 6 emits `/reading/part6?topicIds=<...>&volumes=<...>&action=<generate|existing>` — identical encoding to Part 5, no new param.

- [ ] **Step 1: Write the failing tests**

In `apps/web/src/app/(app)/reading/page.test.tsx`, add these tests to the `describe("ReadingHubPage (mode picker)", ...)` block, after the existing Part 5 tests:

```ts
  it("shows Part 6's own secondary filter (Độ khó chips) once that mode is picked", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([]);

    render(<ReadingHubPage />);
    fireEvent.click(await screen.findByRole("button", { name: /Part 6/ }));

    expect(await screen.findByRole("button", { name: "🔀 Lấy bài có sẵn" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Tạo bài luyện" })).not.toBeDisabled();
    expect(screen.getByRole("button", { name: VOLUME_LABEL_VOL2 })).toBeInTheDocument();
  });

  it("Part 6's 'Lấy bài có sẵn' is never gated by word count, even with 0 matching words", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([]);

    render(<ReadingHubPage />);
    fireEvent.click(await screen.findByRole("button", { name: /Part 6/ }));

    expect(await screen.findByRole("button", { name: "🔀 Lấy bài có sẵn" })).not.toBeDisabled();
  });
```

Add this test to the `describe("ReadingHubPage (navigation)", ...)` block, after the existing Part 5 navigation test:

```ts
  it("navigates to /reading/part6 with selected volumes and action=generate", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([]);

    render(<ReadingHubPage />);
    fireEvent.click(await screen.findByRole("button", { name: /Part 6/ }));
    fireEvent.click(screen.getByRole("button", { name: VOLUME_LABEL_VOL2 }));
    fireEvent.click(screen.getByRole("button", { name: "Tạo bài luyện" }));

    expect(pushMock).toHaveBeenCalledWith("/reading/part6?volumes=vol2&action=generate");
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd apps/web && npx vitest run --run "src/app/(app)/reading/page.test.tsx"`
Expected: FAIL — the hub has no Part 6 mode yet.

- [ ] **Step 3: Add Part 6 to the hub**

In `apps/web/src/app/(app)/reading/page.tsx`:

Change the `Mode` type:

```ts
type Mode = "bilingual" | "part5" | "part6";
```

In `buildQuery`, change:

```ts
    } else if (mode === "part5") {
      if (selectedVolumes.size > 0) params.set("volumes", [...selectedVolumes].join(","));
    }
```

to:

```ts
    } else if (mode === "part5" || mode === "part6") {
      if (selectedVolumes.size > 0) params.set("volumes", [...selectedVolumes].join(","));
    }
```

In `navigate`, change:

```ts
    const path = mode === "bilingual" ? "/reading/bilingual" : "/reading/part5";
```

to:

```ts
    const path = mode === "bilingual" ? "/reading/bilingual" : mode === "part5" ? "/reading/part5" : "/reading/part6";
```

Change the "Tạo bài luyện" gating condition:

```tsx
          {mode === "part5" || canGenerateBilingual ? (
```

to:

```tsx
          {mode !== "bilingual" || canGenerateBilingual ? (
```

Add a third mode card, right after the Part 5 card inside `.reading-hub-cards`:

```tsx
        <button
          type="button"
          className={`reading-hub-card reading-hub-card-toggle${mode === "part6" ? " active" : ""}`}
          onClick={() => setMode("part6")}
        >
          <span className="reading-hub-card-title">📄 Part 6 — Điền đoạn văn</span>
          <span className="reading-hub-card-desc">
            3 đoạn văn ngắn, mỗi đoạn 4 chỗ trống kiểu TOEIC.
          </span>
        </button>
```

Change the volume-chip secondary filter's guard:

```tsx
      {mode === "part5" && (
```

to:

```tsx
      {(mode === "part5" || mode === "part6") && (
```

No other line in this file changes.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd apps/web && npx vitest run --run "src/app/(app)/reading/page.test.tsx"`
Expected: PASS, all tests green.

- [ ] **Step 5: Run the full suite and typecheck**

Run: `cd apps/web && npm test -- --run && npx tsc --noEmit`
Expected: all tests pass (aside from the known pre-existing `bloom.test.ts` failure); no type errors.

- [ ] **Step 6: Commit**

```bash
git add "apps/web/src/app/(app)/reading/page.tsx" "apps/web/src/app/(app)/reading/page.test.tsx"
git commit -m "feat(web): add Part 6 to the reading hub"
```

---

## Task 4: `/reading/part6/page.tsx` — session and result screens

**Files:**
- Create: `apps/web/src/app/(app)/reading/part6/page.tsx`
- Create: `apps/web/src/app/(app)/reading/part6/page.test.tsx`
- Modify: `apps/web/src/styles/bloom.css`

**Interfaces:**
- Consumes: `buildPart6Prompt`/`parsePart6Set`/`Part6Set` (`@/lib/part6`, Task 1), the `"part6"` `SavedReadingExercise` variant (`@/lib/savedReadingExercises`, Task 2), `McQuestionCard` (`@/components/reading/McQuestionCard`, unchanged), `VocabSuggestionsSection` (`@/components/shared/VocabSuggestionsSection`, unchanged). Reads the same `topicIds`/`volumes`/`action` URL shape Task 3's hub produces.

- [ ] **Step 1: Add CSS for the passage-group wrapper**

In `apps/web/src/styles/bloom.css`, add this block right after the `.reading-min-words-hint` rule:

```css
.reading-passage-group {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 14px;
  padding: 18px 20px;
  margin-bottom: 20px;
}

.reading-passage-group-title {
  font-weight: 700;
  font-size: 17px;
  margin-bottom: 8px;
}

.reading-passage-text {
  color: var(--ink-soft);
  line-height: 1.6;
  margin-bottom: 12px;
}
```

- [ ] **Step 2: Write the failing tests**

Create `apps/web/src/app/(app)/reading/part6/page.test.tsx`:

```tsx
import { beforeEach, describe, expect, it, vi } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import Part6Page from "./page";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettingsContext } from "@/lib/SettingsContext";
import { getVocabRecords } from "@/lib/vocabRecords";
import { getTopics, type Topic } from "@/lib/topics";
import { generateContent } from "@/lib/generateContent";
import { getRandomSavedExercise, saveReadingExercise } from "@/lib/savedReadingExercises";
import { DEFAULT_SETTINGS, type UserSettings } from "@/lib/settings";
import type { Part6Set } from "@/lib/part6";

vi.mock("@/lib/useAuthUser", () => ({ useAuthUser: vi.fn() }));
vi.mock("@/lib/SettingsContext", () => ({ useSettingsContext: vi.fn() }));
vi.mock("@/lib/vocabRecords", () => ({ getVocabRecords: vi.fn() }));
vi.mock("@/lib/topics", () => ({ getTopics: vi.fn() }));
vi.mock("@/lib/generateContent", () => ({ generateContent: vi.fn() }));
vi.mock("@/lib/savedReadingExercises", async () => {
  const actual = await vi.importActual<typeof import("@/lib/savedReadingExercises")>("@/lib/savedReadingExercises");
  return {
    ...actual,
    getRandomSavedExercise: vi.fn(),
    saveReadingExercise: vi.fn(),
  };
});
vi.mock("@/components/SignInButton", () => ({
  SignInButton: () => <button>Đăng nhập với Google</button>,
}));
vi.mock("@/components/shared/VocabSuggestionsSection", () => ({
  VocabSuggestionsSection: ({ text }: { text: string }) => <div data-testid="vocab-suggestions" data-text={text} />,
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

const SETTINGS_WITH_KEY: UserSettings = {
  ...DEFAULT_SETTINGS,
  activeProvider: "gemini",
  providers: { ...DEFAULT_SETTINGS.providers, gemini: { model: "gemini-2.5-flash", apiKeyCiphertext: "cipher-abc" } },
};

function mockSignedIn(settings: UserSettings = SETTINGS_WITH_KEY) {
  vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" }, loading: false } as never);
  vi.mocked(useSettingsContext).mockReturnValue({ settings, loading: false, error: null, save: vi.fn() });
}

const ONE_PASSAGE_SET: Part6Set = {
  passages: [
    {
      passageText: "Please arrive (1)___ 9am.",
      questions: [
        { options: ["before", "after", "during", "since"], correctIndex: 0, explanation: "Trước 9h." },
        { options: ["employee", "employees", "employee's", "employees'"], correctIndex: 0, explanation: "Danh từ ghép." },
        {
          options: [
            "Please sign in at the front desk.",
            "The weather is nice today.",
            "We sell many products.",
            "Coffee is available.",
          ],
          correctIndex: 0,
          explanation: "Câu phù hợp nhất.",
        },
        { options: ["for come", "for coming", "to coming", "come"], correctIndex: 1, explanation: "Giới từ + V-ing." },
      ],
    },
  ],
};

beforeEach(() => {
  vi.clearAllMocks();
  setSearchParams({ action: "generate" });
  vi.mocked(getVocabRecords).mockResolvedValue([]);
  vi.mocked(getTopics).mockResolvedValue([]);
  vi.mocked(getRandomSavedExercise).mockResolvedValue(null);
});

describe("Part6Page (loading phase)", () => {
  it("prompts sign-in when logged out", () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: null, loading: false } as never);
    vi.mocked(useSettingsContext).mockReturnValue({ settings: null, loading: false, error: null, save: vi.fn() });
    render(<Part6Page />);
    expect(screen.getByText("Đăng nhập với Google")).toBeInTheDocument();
  });

  it("redirects to /reading when the action param is missing", async () => {
    setSearchParams({});
    mockSignedIn();

    render(<Part6Page />);

    await waitFor(() => expect(replaceMock).toHaveBeenCalledWith("/reading"));
  });

  it("redirects to /reading when the action param is invalid", async () => {
    setSearchParams({ action: "bogus" });
    mockSignedIn();

    render(<Part6Page />);

    await waitFor(() => expect(replaceMock).toHaveBeenCalledWith("/reading"));
  });

  it("auto-generates a set on mount, resolving topicIds to topic names in the prompt", async () => {
    setSearchParams({ topicIds: "biz-1", action: "generate" });
    mockSignedIn();
    const topics: Topic[] = [{ id: "biz-1", name: "Business", emoji: "💼", isPredefined: true, createdAt: "2026-01-01" }];
    vi.mocked(getTopics).mockResolvedValue(topics);
    vi.mocked(generateContent).mockResolvedValue({ text: JSON.stringify(ONE_PASSAGE_SET) });

    render(<Part6Page />);

    expect(await screen.findByText("Đoạn 1")).toBeInTheDocument();
    const promptArg = vi.mocked(generateContent).mock.calls[0][0].prompt;
    expect(promptArg).toContain("exactly 3");
    expect(promptArg).toContain("Business");
  });

  it("shows an error with retry/back-to-hub actions when the active provider has no API key", async () => {
    setSearchParams({ action: "generate" });
    mockSignedIn({ ...DEFAULT_SETTINGS, activeProvider: "gemini", providers: { ...DEFAULT_SETTINGS.providers, gemini: { model: "gemini-2.5-flash", apiKeyCiphertext: null } } });

    render(<Part6Page />);

    expect(await screen.findByText("Chưa có API key cho nhà cung cấp AI đang chọn — vào Cài đặt để thêm.")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Thử lại" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Về trang chính" })).toBeInTheDocument();
    expect(generateContent).not.toHaveBeenCalled();
  });

  it("shows an error when the AI returns no usable passages, and 'Thử lại' retries the same action", async () => {
    setSearchParams({ action: "generate" });
    mockSignedIn();
    vi.mocked(generateContent).mockResolvedValueOnce({ text: JSON.stringify({}) });

    render(<Part6Page />);
    await screen.findByText("AI không trả về bài luyện hợp lệ.");

    vi.mocked(generateContent).mockResolvedValue({ text: JSON.stringify(ONE_PASSAGE_SET) });
    fireEvent.click(screen.getByRole("button", { name: "Thử lại" }));

    await waitFor(() => expect(screen.getByText("Đoạn 1")).toBeInTheDocument());
  });

  it('"Về trang chính" on the loading-error state navigates back to the hub', async () => {
    setSearchParams({ action: "generate" });
    mockSignedIn({ ...DEFAULT_SETTINGS, activeProvider: "gemini", providers: { ...DEFAULT_SETTINGS.providers, gemini: { model: "gemini-2.5-flash", apiKeyCiphertext: null } } });

    render(<Part6Page />);
    fireEvent.click(await screen.findByRole("button", { name: "Về trang chính" }));

    expect(pushMock).toHaveBeenCalledWith("/reading");
  });

  it('action=existing starts a session directly from a matching saved exercise, without calling the AI', async () => {
    setSearchParams({ action: "existing" });
    mockSignedIn();
    vi.mocked(getRandomSavedExercise).mockResolvedValue({
      id: "saved-1",
      type: "part6",
      passage: ONE_PASSAGE_SET,
      generationFilters: { topicIds: [], volumes: [] },
      targetLanguage: "english",
      createdAt: "2026-01-01T00:00:00.000Z",
    } as never);

    render(<Part6Page />);

    expect(await screen.findByText("Đoạn 1")).toBeInTheDocument();
    expect(generateContent).not.toHaveBeenCalled();
  });

  it("action=existing shows an inline notice and falls back to AI generation when nothing matches", async () => {
    setSearchParams({ action: "existing" });
    mockSignedIn();
    // generateContent's mock resolution is held open deliberately (instead of
    // mockResolvedValue, which settles within the same microtask burst as
    // everything upstream of it) so the notice's render commit is
    // observable before the AI fallback completes and the screen moves on
    // to the session phase — same pattern as part5/page.test.tsx.
    let resolveGenerate!: (value: { text: string }) => void;
    vi.mocked(generateContent).mockReturnValue(
      new Promise((resolve) => {
        resolveGenerate = resolve;
      })
    );

    render(<Part6Page />);

    expect(await screen.findByText("Chưa có bài đã lưu khớp bộ lọc này — đang tạo bài mới bằng AI…")).toBeInTheDocument();
    expect(generateContent).toHaveBeenCalled();

    resolveGenerate({ text: JSON.stringify(ONE_PASSAGE_SET) });
    await waitFor(() => expect(screen.getByText("Đoạn 1")).toBeInTheDocument());
  });
});

describe("Part6Page (session phase)", () => {
  async function generateSession() {
    setSearchParams({ action: "generate" });
    vi.mocked(generateContent).mockResolvedValue({ text: JSON.stringify(ONE_PASSAGE_SET) });
    render(<Part6Page />);
    await screen.findByText("Đoạn 1");
  }

  it("shows the passage text and 4 blank groups labeled Chỗ trống (1)-(4)", async () => {
    mockSignedIn();
    await generateSession();

    expect(screen.getByText("Please arrive (1)___ 9am.")).toBeInTheDocument();
    expect(screen.getByText("Chỗ trống (1)")).toBeInTheDocument();
    expect(screen.getByText("Chỗ trống (2)")).toBeInTheDocument();
    expect(screen.getByText("Chỗ trống (3)")).toBeInTheDocument();
    expect(screen.getByText("Chỗ trống (4)")).toBeInTheDocument();
  });

  it("keeps Nộp bài disabled until every blank has an answer, then submits into the result phase", async () => {
    mockSignedIn();
    await generateSession();

    expect(screen.getByRole("button", { name: "Nộp bài" })).toBeDisabled();
    fireEvent.click(screen.getByRole("button", { name: "before" }));
    fireEvent.click(screen.getByRole("button", { name: "employee" }));
    fireEvent.click(screen.getByRole("button", { name: "Please sign in at the front desk." }));
    expect(screen.getByRole("button", { name: "Nộp bài" })).toBeDisabled();
    fireEvent.click(screen.getByRole("button", { name: "for coming" }));
    expect(screen.getByRole("button", { name: "Nộp bài" })).not.toBeDisabled();

    fireEvent.click(screen.getByRole("button", { name: "Nộp bài" }));

    expect(await screen.findByText("4/4")).toBeInTheDocument();
  });
});

describe("Part6Page (result phase)", () => {
  async function completeSession() {
    setSearchParams({ action: "generate" });
    vi.mocked(generateContent).mockResolvedValue({ text: JSON.stringify(ONE_PASSAGE_SET) });
    render(<Part6Page />);
    await screen.findByText("Đoạn 1");
    fireEvent.click(screen.getByRole("button", { name: "before" }));
    fireEvent.click(screen.getByRole("button", { name: "employee" }));
    fireEvent.click(screen.getByRole("button", { name: "Please sign in at the front desk." }));
    fireEvent.click(screen.getByRole("button", { name: "for coming" }));
    fireEvent.click(screen.getByRole("button", { name: "Nộp bài" }));
    await screen.findByText(/\d\/\d/);
  }

  it("shows the score, per-blank breakdown with explanation, and the suggestions section", async () => {
    mockSignedIn();
    await completeSession();

    expect(screen.getByText("4/4")).toBeInTheDocument();
    expect(screen.getByText("Giải thích: Trước 9h.")).toBeInTheDocument();
    expect(screen.getByText("Giải thích: Giới từ + V-ing.")).toBeInTheDocument();
    const suggestions = screen.getByTestId("vocab-suggestions");
    expect(suggestions).toHaveAttribute("data-text", "Please arrive (1)___ 9am.");
  });

  it('shows "Lưu bài" for a generated session and saves with the type "part6"', async () => {
    mockSignedIn();
    vi.mocked(saveReadingExercise).mockResolvedValue("new-id");
    await completeSession();

    fireEvent.click(screen.getByRole("button", { name: "Lưu bài" }));

    expect(await screen.findByText("Đã lưu ✔")).toBeInTheDocument();
    expect(saveReadingExercise).toHaveBeenCalledWith(
      "u1",
      "part6",
      expect.objectContaining({ passages: expect.any(Array) }),
      expect.objectContaining({ topicIds: [], volumes: [] }),
      "english"
    );
  });

  it('"Bài khác" replays AI-generation directly for a generated session', async () => {
    mockSignedIn();
    await completeSession();
    vi.mocked(generateContent).mockResolvedValue({
      text: JSON.stringify({
        passages: [
          {
            passageText: "New passage.",
            questions: [
              { options: ["a", "b", "c", "d"], correctIndex: 0, explanation: "E." },
              { options: ["a", "b", "c", "d"], correctIndex: 0, explanation: "E." },
              { options: ["a", "b", "c", "d"], correctIndex: 0, explanation: "E." },
              { options: ["a", "b", "c", "d"], correctIndex: 0, explanation: "E." },
            ],
          },
        ],
      }),
    });

    fireEvent.click(screen.getByRole("button", { name: "Bài khác" }));

    expect(await screen.findByText("New passage.")).toBeInTheDocument();
  });

  it('"Về trang chính" navigates back to the reading hub', async () => {
    mockSignedIn();
    await completeSession();

    fireEvent.click(screen.getByRole("button", { name: "Về trang chính" }));

    expect(pushMock).toHaveBeenCalledWith("/reading");
  });

  it('surfaces a save error via role="alert" when saveReadingExercise rejects', async () => {
    mockSignedIn();
    vi.mocked(saveReadingExercise).mockRejectedValue(new Error("network down"));
    await completeSession();

    fireEvent.click(screen.getByRole("button", { name: "Lưu bài" }));

    expect(await screen.findByText("network down")).toBeInTheDocument();
    expect(screen.getByRole("alert")).toHaveTextContent("network down");
  });

  async function completeReusedSession() {
    setSearchParams({ action: "existing" });
    vi.mocked(getRandomSavedExercise).mockResolvedValue({
      id: "saved-1",
      type: "part6",
      passage: ONE_PASSAGE_SET,
      generationFilters: { topicIds: [], volumes: [] },
      targetLanguage: "english",
      createdAt: "2026-01-01T00:00:00.000Z",
    } as never);
    render(<Part6Page />);
    await screen.findByText("Đoạn 1");
    fireEvent.click(screen.getByRole("button", { name: "before" }));
    fireEvent.click(screen.getByRole("button", { name: "employee" }));
    fireEvent.click(screen.getByRole("button", { name: "Please sign in at the front desk." }));
    fireEvent.click(screen.getByRole("button", { name: "for coming" }));
    fireEvent.click(screen.getByRole("button", { name: "Nộp bài" }));
    await screen.findByText("4/4");
  }

  it("hides the vocab-suggestions section and the Lưu bài button for a reused session's result screen", async () => {
    mockSignedIn();
    await completeReusedSession();

    expect(screen.queryByTestId("vocab-suggestions")).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Lưu bài" })).not.toBeInTheDocument();
  });

  it('"Bài khác" fetches another saved exercise directly for a reused session, not the AI', async () => {
    mockSignedIn();
    setSearchParams({ action: "existing" });
    vi.mocked(getRandomSavedExercise).mockResolvedValueOnce({
      id: "saved-1",
      type: "part6",
      passage: ONE_PASSAGE_SET,
      generationFilters: { topicIds: [], volumes: [] },
      targetLanguage: "english",
      createdAt: "2026-01-01T00:00:00.000Z",
    } as never);
    render(<Part6Page />);
    await screen.findByText("Đoạn 1");
    fireEvent.click(screen.getByRole("button", { name: "before" }));
    fireEvent.click(screen.getByRole("button", { name: "employee" }));
    fireEvent.click(screen.getByRole("button", { name: "Please sign in at the front desk." }));
    fireEvent.click(screen.getByRole("button", { name: "for coming" }));
    fireEvent.click(screen.getByRole("button", { name: "Nộp bài" }));
    await screen.findByText("4/4");

    vi.mocked(getRandomSavedExercise).mockResolvedValueOnce({
      id: "saved-2",
      type: "part6",
      passage: {
        passages: [
          {
            passageText: "New saved one.",
            questions: [
              { options: ["a", "b", "c", "d"], correctIndex: 0, explanation: "E." },
              { options: ["a", "b", "c", "d"], correctIndex: 0, explanation: "E." },
              { options: ["a", "b", "c", "d"], correctIndex: 0, explanation: "E." },
              { options: ["a", "b", "c", "d"], correctIndex: 0, explanation: "E." },
            ],
          },
        ],
      },
      generationFilters: { topicIds: [], volumes: [] },
      targetLanguage: "english",
      createdAt: "2026-01-01T00:00:00.000Z",
    } as never);

    fireEvent.click(screen.getByRole("button", { name: "Bài khác" }));

    expect(await screen.findByText("New saved one.")).toBeInTheDocument();
    expect(getRandomSavedExercise).toHaveBeenCalledTimes(2);
    expect(generateContent).not.toHaveBeenCalled();
  });
});
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `cd apps/web && npx vitest run --run "src/app/(app)/reading/part6/page.test.tsx"`
Expected: FAIL — the page doesn't exist yet.

- [ ] **Step 4: Implement the page**

Create `apps/web/src/app/(app)/reading/part6/page.tsx`:

```tsx
"use client";

import { Suspense, useEffect, useRef, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettingsContext } from "@/lib/SettingsContext";
import { SignInButton } from "@/components/SignInButton";
import { getVocabRecords, type VocabRecord } from "@/lib/vocabRecords";
import { getTopics, type Topic } from "@/lib/topics";
import { type EconomyVolume } from "@/lib/toeicFilters";
import { buildPart6Prompt, parsePart6Set, type Part6Set } from "@/lib/part6";
import { generateContent } from "@/lib/generateContent";
import { parseAiJsonObject } from "@/lib/parseAiJson";
import { getRandomSavedExercise, saveReadingExercise, type ToeicFilters } from "@/lib/savedReadingExercises";
import { McQuestionCard } from "@/components/reading/McQuestionCard";
import { VocabSuggestionsSection } from "@/components/shared/VocabSuggestionsSection";

type Phase = "loading" | "session" | "result";
const QUESTIONS_PER_PASSAGE = 4;

function flatIndex(passageIndex: number, questionIndex: number): number {
  return passageIndex * QUESTIONS_PER_PASSAGE + questionIndex;
}

function Part6PageContent() {
  const { user, loading: authLoading } = useAuthUser();
  const { settings, loading: settingsLoading } = useSettingsContext();
  const router = useRouter();
  const searchParams = useSearchParams();

  const topicIds = (searchParams.get("topicIds") ?? "").split(",").filter(Boolean);
  const volumes = (searchParams.get("volumes") ?? "").split(",").filter(Boolean) as EconomyVolume[];
  const action = searchParams.get("action");

  const [records, setRecords] = useState<VocabRecord[]>([]);
  const [topics, setTopics] = useState<Topic[]>([]);

  const [phase, setPhase] = useState<Phase>("loading");
  const [generating, setGenerating] = useState(false);
  const [fetchingSaved, setFetchingSaved] = useState(false);
  const [generateError, setGenerateError] = useState<string | null>(null);
  const [savedNotice, setSavedNotice] = useState<string | null>(null);
  const [set, setSet] = useState<Part6Set | null>(null);
  const [answers, setAnswers] = useState<(number | null)[]>([]);
  const [sessionMode, setSessionMode] = useState<"generated" | "reused">("generated");
  const [justSavedId, setJustSavedId] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [contextLoaded, setContextLoaded] = useState(false);

  useEffect(() => {
    if (!user) return;
    // Best-effort: these only feed VocabSuggestionsSection on the result
    // screen — but the auto-trigger effect below still waits for this to
    // settle (success or failure) via contextLoaded, since resolvedTopicNames()
    // needs `topics` populated before building the generation prompt.
    Promise.all([getVocabRecords(user.uid), getTopics(user.uid)])
      .then(([r, t]) => {
        setRecords(r);
        setTopics(t);
      })
      .catch(() => {})
      .finally(() => setContextLoaded(true));
  }, [user]);

  function resolvedTopicNames(): string[] {
    return topics.filter((t) => topicIds.includes(t.id)).map((t) => t.name);
  }

  function currentFilters(): ToeicFilters {
    return { topicIds, volumes };
  }

  async function handleGenerate() {
    if (!user || !settings) return;
    const activeConfig = settings.providers[settings.activeProvider];
    if (!activeConfig.apiKeyCiphertext) {
      setGenerateError("Chưa có API key cho nhà cung cấp AI đang chọn — vào Cài đặt để thêm.");
      return;
    }
    setGenerating(true);
    setGenerateError(null);
    try {
      const prompt = buildPart6Prompt(resolvedTopicNames(), settings.targetLanguage, volumes);
      const response = await generateContent({
        provider: settings.activeProvider,
        model: activeConfig.model,
        apiKeyCiphertext: activeConfig.apiKeyCiphertext,
        prompt,
      });
      const json = parseAiJsonObject(response.text);
      const generated = parsePart6Set(json);
      if (generated.passages.length === 0) {
        throw new Error("AI không trả về bài luyện hợp lệ.");
      }
      setSessionMode("generated");
      setJustSavedId(null);
      setSaveError(null);
      setSet(generated);
      setAnswers(new Array(generated.passages.length * QUESTIONS_PER_PASSAGE).fill(null));
      setPhase("session");
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
      const saved = await getRandomSavedExercise(user.uid, settings.targetLanguage, "part6", currentFilters(), excludeId);
      if (saved) {
        found = true;
        setSessionMode("reused");
        setJustSavedId(null);
        setSaveError(null);
        setSet(saved.passage);
        setAnswers(new Array(saved.passage.passages.length * QUESTIONS_PER_PASSAGE).fill(null));
        setPhase("session");
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
    if (!user || !settings || !contextLoaded) return;
    if (action !== "generate" && action !== "existing") {
      router.replace("/reading");
      return;
    }
    if (triggeredRef.current) return;
    triggeredRef.current = true;
    void runAction();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [user, settings, contextLoaded, action]);

  async function handleSaveExercise() {
    if (saving || !user || !settings || !set) return;
    setSaving(true);
    setSaveError(null);
    try {
      const newId = await saveReadingExercise(user.uid, "part6", set, currentFilters(), settings.targetLanguage);
      setJustSavedId(newId);
    } catch (err) {
      setSaveError(err instanceof Error ? err.message : String(err));
    } finally {
      setSaving(false);
    }
  }

  function handleSelectAnswer(passageIndex: number, questionIndex: number, optionIndex: number) {
    setAnswers((prev) => {
      const next = [...prev];
      next[flatIndex(passageIndex, questionIndex)] = optionIndex;
      return next;
    });
  }

  async function handleNewSession() {
    if (sessionMode === "reused") {
      // fetchSavedExercise always leaves user-visible feedback on this same
      // "result" phase — either a new session, an AI-fallback notice, or
      // generateError — so there is nothing to redirect away from.
      await fetchSavedExercise(justSavedId ?? undefined);
      return;
    }
    await handleGenerate();
  }

  if (authLoading) return <p>Đang tải…</p>;

  if (!user) {
    return (
      <div>
        <h2 className="scr-title">Part 6 — Điền đoạn văn</h2>
        <p className="scr-sub">Đăng nhập để luyện tập.</p>
        <SignInButton />
      </div>
    );
  }

  if (settingsLoading || !settings) return <p>Đang tải…</p>;

  if (phase === "loading") {
    return (
      <div>
        <h2 className="scr-title">Part 6 — Điền đoạn văn</h2>
        {(generating || fetchingSaved) && <p>{generating ? "Đang tạo bài…" : "Đang tìm bài…"}</p>}
        {savedNotice && <p className="reading-saved-notice">{savedNotice}</p>}
        {generateError && (
          <>
            <p role="alert">{generateError}</p>
            <div className="reading-result-actions">
              <button type="button" className="btn-secondary" onClick={() => router.push("/reading")}>
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

  if (phase === "session" && set) {
    const canSubmit = answers.every((a) => a !== null);
    return (
      <div>
        <h2 className="scr-title">Part 6 — Điền đoạn văn</h2>
        {set.passages.map((passage, p) => (
          <div key={p} className="reading-passage-group">
            <h3 className="reading-passage-group-title">Đoạn {p + 1}</h3>
            <p className="reading-passage-text">{passage.passageText}</p>
            {passage.questions.map((q, qi) => (
              <McQuestionCard
                key={qi}
                label={`Chỗ trống (${qi + 1})`}
                options={q.options}
                selected={answers[flatIndex(p, qi)]}
                onSelect={(optionIndex) => handleSelectAnswer(p, qi, optionIndex)}
              />
            ))}
          </div>
        ))}
        <button className="btn-primary" onClick={() => setPhase("result")} disabled={!canSubmit}>
          Nộp bài
        </button>
      </div>
    );
  }

  const total = (set?.passages.length ?? 0) * QUESTIONS_PER_PASSAGE;
  const correctCount = (set?.passages ?? []).reduce(
    (sum, passage, p) => sum + passage.questions.filter((q, qi) => answers[flatIndex(p, qi)] === q.correctIndex).length,
    0
  );
  const passagesText = (set?.passages ?? []).map((p) => p.passageText).join(" ");

  return (
    <div>
      <h2 className="scr-title">Kết quả</h2>
      <p className="mc-score">
        {correctCount}/{total}
      </p>
      {(set?.passages ?? []).map((passage, p) => (
        <div key={p} className="reading-passage-group">
          <h3 className="reading-passage-group-title">Đoạn {p + 1}</h3>
          <p className="reading-passage-text">{passage.passageText}</p>
          {passage.questions.map((q, qi) => (
            <McQuestionCard
              key={qi}
              label={`Chỗ trống (${qi + 1})`}
              options={q.options}
              selected={answers[flatIndex(p, qi)]}
              correctIndex={q.correctIndex}
              explanation={q.explanation}
            />
          ))}
        </div>
      ))}
      {sessionMode === "generated" && <VocabSuggestionsSection text={passagesText} existingRecords={records} topics={topics} />}
      <div className="reading-result-actions">
        {sessionMode === "generated" &&
          (justSavedId ? (
            <span className="reading-saved-mark">Đã lưu ✔</span>
          ) : (
            <button type="button" className="btn-secondary" onClick={() => void handleSaveExercise()} disabled={saving}>
              {saving ? "Đang lưu…" : "Lưu bài"}
            </button>
          ))}
        <button type="button" className="btn-secondary" onClick={() => router.push("/reading")}>
          Về trang chính
        </button>
        <button type="button" className="btn-primary" onClick={() => void handleNewSession()}>
          Bài khác
        </button>
      </div>
      {saveError && <p role="alert">{saveError}</p>}
      {savedNotice && <p className="reading-saved-notice">{savedNotice}</p>}
      {generateError && <p role="alert">{generateError}</p>}
    </div>
  );
}

export default function Part6Page() {
  return (
    <Suspense fallback={<p>Đang tải…</p>}>
      <Part6PageContent />
    </Suspense>
  );
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `cd apps/web && npx vitest run --run "src/app/(app)/reading/part6/page.test.tsx"`
Expected: PASS, all tests green.

- [ ] **Step 6: Run the full suite, typecheck, and build**

Run: `cd apps/web && npm test -- --run && npx tsc --noEmit && npm run build`
Expected: all tests pass (aside from the known pre-existing `bloom.test.ts` failure); no type errors; build succeeds with `/reading/part6` prerendered as a static page (confirms the `Suspense` boundary correctly wraps the `useSearchParams()`-consuming component, same pattern already proven for `/reading/part5`).

- [ ] **Step 7: Commit**

```bash
git add "apps/web/src/app/(app)/reading/part6/page.tsx" "apps/web/src/app/(app)/reading/part6/page.test.tsx" apps/web/src/styles/bloom.css
git commit -m "feat(web): add /reading/part6 — TOEIC Part 6 practice with save/reuse"
```

---

## Final verification (after all 4 tasks)

- [ ] Run the full suite once more: `cd apps/web && npm test -- --run` — expect all tests green apart from the known pre-existing, unrelated `bloom.test.ts` failure.
- [ ] `cd apps/web && npx tsc --noEmit` — expect no errors.
- [ ] `cd apps/web && npm run build` — expect a clean production build with `/reading/part6` statically prerendered.
- [ ] Manually walk through the flow in a browser: from `/reading`, pick a topic, pick Part 6, adjust Độ khó, generate — confirm it lands directly in a session with 3 passages of 4 blanks each, "select the best sentence" blanks rendering identically to word blanks. Submit and confirm the `X/12` score and per-blank breakdown. Try "🔀 Lấy bài có sẵn" and "Lưu bài". Try navigating directly to `/reading/part6` with no query string and confirm it redirects to `/reading`.
