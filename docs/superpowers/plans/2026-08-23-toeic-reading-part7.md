# TOEIC Reading Part 7 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add TOEIC Reading Part 7 ("Đọc hiểu" / Reading Comprehension) to the web app's `/reading` hub as a fourth mode, reusing the already-shipped Part 5/Part 6/hub-merge architecture end to end (topic-based shared filter, hub-driven navigation, save/reuse via `savedReadingExercises.ts`, `McQuestionCard` for every question).

**Architecture:** `apps/web/src/lib/part7.ts` ports Flutter's `part7_source.dart` prompt/parser plus a new `hasValidPart7Shape` predicate (Part 7's AI response must be rejected as invalid if it doesn't match the exact 3-group/1-doc+1-doc+2-doc/3-4+3-4+5-question shape, not just checked for emptiness). `savedReadingExercises.ts` gains one new `"part7"` union member reusing the existing `ToeicFilters` shape unchanged. The hub gains a fourth mode. `/reading/part7/page.tsx` is structurally identical to `/reading/part6/page.tsx`, differing in its prompt/parse/validity-check calls and in using a running-sum `flatIndex` (groups have variable question counts — 3, 4, or 5 — unlike Part 6's fixed 4-per-passage) and a variable `total` (9-13, not a fixed 12 or 15).

**Tech Stack:** Next.js 16 (App Router) on `apps/web/`, React 19, Firebase JS SDK v12, Vitest + React Testing Library + jsdom.

## Global Constraints

- All user-facing text is Vietnamese, matching every existing screen.
- Import alias `@/` maps to `apps/web/src/`.
- Every changed/new file's tests are updated/added to match.
- Part 7's "Tạo bài luyện" is never gated by word count (same as Part 5/6).
- Part 7 introduces no new query parameter — it reuses `topicIds`, `volumes`, and `action` exactly as Part 5/6 already encode them.
- `parsePart7Set` never throws (tolerant/defensive, consistent with `parsePart5Set`/`parsePart6Set`). The stricter "is this a valid Part 7 shape" check is a separate, independently-testable pure function (`hasValidPart7Shape`) that the *page* calls and throws on — keeping the "reject this response" decision in the same place it already lives for Part 5/6.
- In test fixtures spanning multiple questions/groups, every answer-option string across the whole fixture must be textually unique — React Testing Library's `getByRole("button", { name })` matches by exact accessible name with no container scoping, so any repeated option text anywhere in a fixture makes a later `getByRole` call ambiguous. (This was a real gap caught in Part 6's own whole-branch review — this plan's Task 4 fixture is built to avoid it from the start.)
- Verify each task with `npm --prefix apps/web test` (full suite) and finish the plan with `npx tsc --noEmit -p apps/web/tsconfig.json` and `npm --prefix apps/web run build`.
- One pre-existing, unrelated test failure is expected in `src/styles/bloom.test.ts` (an `.app-frame` CSS-lock assertion) — not something any task here should fix. An occasional flaky "Failed to start forks worker" / timeout under full-suite load on Windows can silently drop a few files from one run's count without indicating a real failure — if a run's total looks low, re-run once before concluding anything is wrong.
- Spec: `docs/superpowers/specs/2026-08-23-toeic-reading-part7-design.md` — read it if anything below is ambiguous.

---

## Task 1: `part7.ts` — prompt builder, response parser, and shape validator

**Files:**
- Create: `apps/web/src/lib/part7.ts`
- Create: `apps/web/src/lib/part7.test.ts`

**Interfaces:**
- Produces (used by Tasks 2 and 4):
  - `interface Part7Question { question: string; options: string[]; correctIndex: number; explanation: string }`
  - `interface Part7PassageGroup { documents: string[]; questions: Part7Question[] }`
  - `interface Part7Set { passageGroups: Part7PassageGroup[] }`
  - `function buildPart7Prompt(topicNames: string[], targetLanguage: TargetLanguage, volumes: EconomyVolume[]): string`
  - `function parsePart7Set(json: Record<string, unknown>): Part7Set`
  - `function hasValidPart7Shape(set: Part7Set): boolean`

- [ ] **Step 1: Write the failing tests**

Create `apps/web/src/lib/part7.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import { buildPart7Prompt, parsePart7Set, hasValidPart7Shape, type Part7Set } from "./part7";

describe("buildPart7Prompt", () => {
  it("includes topic names, target language label, and asks for exactly 3 passage groups in JSON", () => {
    const prompt = buildPart7Prompt(["Business"], "english", ["vol3"]);
    expect(prompt).toContain("Business");
    expect(prompt).toContain("English");
    expect(prompt).toContain("exactly 3 passage groups");
    expect(prompt).toContain("JSON only");
    expect(prompt).toContain('"passageGroups"');
  });

  it("joins multiple topic names with a slash", () => {
    const prompt = buildPart7Prompt(["Business", "Travel"], "english", ["vol3"]);
    expect(prompt).toContain("Business/Travel");
  });

  it("omits the register clause entirely when no topics are selected", () => {
    const prompt = buildPart7Prompt([], "english", ["vol2"]);
    expect(prompt).not.toContain("register/setting");
  });

  it("requires the double-passage group to have exactly 5 questions and require both documents", () => {
    const prompt = buildPart7Prompt([], "english", ["vol2"]);
    expect(prompt).toContain("exactly 5 multiple-choice questions");
    expect(prompt).toContain("requires information from both");
  });

  it("requires the two single-passage groups to use different document types", () => {
    const prompt = buildPart7Prompt([], "english", ["vol2"]);
    expect(prompt).toContain("different document type than");
  });

  it("includes the prompt hint for every requested volume", () => {
    const prompt = buildPart7Prompt([], "english", ["vol2", "vol4"]);
    expect(prompt).toContain("easy-medium difficulty");
    expect(prompt).toContain("unusual grammar/vocabulary traps");
  });

  it("uses every volume's hint when the volumes list is empty (matches Flutter's 'empty = all' default)", () => {
    const prompt = buildPart7Prompt([], "english", []);
    expect(prompt).toContain("easy-medium difficulty");
    expect(prompt).toContain("medium-high difficulty");
    expect(prompt).toContain("equal to or harder than the real exam");
    expect(prompt).toContain("deepest grammar traps");
  });

  it("uses the target language's own label, not always English", () => {
    const prompt = buildPart7Prompt([], "korean", ["vol2"]);
    expect(prompt).toContain("한국어");
  });

  it("requires Vietnamese-script-only explanations", () => {
    const prompt = buildPart7Prompt([], "english", ["vol2"]);
    expect(prompt).toContain("Vietnamese script");
  });
});

describe("parsePart7Set", () => {
  it("parses a full set of passage groups", () => {
    const json = {
      passageGroups: [
        {
          documents: ["Doc A"],
          questions: [{ question: "Q1?", options: ["a", "b", "c", "d"], correctIndex: 0, explanation: "A." }],
        },
      ],
    };

    const result = parsePart7Set(json);

    expect(result.passageGroups).toHaveLength(1);
    expect(result.passageGroups[0].documents).toEqual(["Doc A"]);
    expect(result.passageGroups[0].questions).toEqual([
      { question: "Q1?", options: ["a", "b", "c", "d"], correctIndex: 0, explanation: "A." },
    ]);
  });

  it("falls back to empty passageGroups when the response is missing fields", () => {
    const result = parsePart7Set({});
    expect(result).toEqual({ passageGroups: [] });
  });

  it("tolerates malformed question entries by defaulting their fields", () => {
    const result = parsePart7Set({ passageGroups: [{ documents: ["D"], questions: [{}] }] });
    expect(result.passageGroups[0].questions).toEqual([{ question: "", options: [], correctIndex: 0, explanation: "" }]);
  });

  it("defaults documents to an empty array when missing", () => {
    const result = parsePart7Set({ passageGroups: [{ questions: [] }] });
    expect(result.passageGroups[0].documents).toEqual([]);
  });

  it("ignores non-object entries in passageGroups and in a group's questions", () => {
    const result = parsePart7Set({
      passageGroups: ["not an object", { documents: ["D"], questions: ["also not an object", null] }],
    });
    expect(result.passageGroups).toEqual([{ documents: ["D"], questions: [] }]);
  });
});

describe("hasValidPart7Shape", () => {
  function makeQuestion(): Part7Set["passageGroups"][number]["questions"][number] {
    return { question: "Q", options: ["a", "b", "c", "d"], correctIndex: 0, explanation: "E" };
  }

  function validSet(): Part7Set {
    return {
      passageGroups: [
        { documents: ["D1"], questions: [makeQuestion(), makeQuestion(), makeQuestion()] },
        { documents: ["D2"], questions: [makeQuestion(), makeQuestion(), makeQuestion(), makeQuestion()] },
        { documents: ["D3a", "D3b"], questions: Array.from({ length: 5 }, makeQuestion) },
      ],
    };
  }

  it("accepts a valid shape: 2 single-document groups (3-4 questions each) + 1 double-document group (5 questions)", () => {
    expect(hasValidPart7Shape(validSet())).toBe(true);
  });

  it("accepts 3 questions in a single-document group", () => {
    const set = validSet();
    set.passageGroups[1].questions = [makeQuestion(), makeQuestion(), makeQuestion()];
    expect(hasValidPart7Shape(set)).toBe(true);
  });

  it("rejects a set with fewer than 3 groups", () => {
    const set = validSet();
    set.passageGroups.pop();
    expect(hasValidPart7Shape(set)).toBe(false);
  });

  it("rejects a set with more than 3 groups", () => {
    const set = validSet();
    set.passageGroups.push(set.passageGroups[2]);
    expect(hasValidPart7Shape(set)).toBe(false);
  });

  it("rejects when a single-document group actually has 2 documents", () => {
    const set = validSet();
    set.passageGroups[0].documents = ["D1", "D1b"];
    expect(hasValidPart7Shape(set)).toBe(false);
  });

  it("rejects when a single-document group has only 2 questions", () => {
    const set = validSet();
    set.passageGroups[0].questions = set.passageGroups[0].questions.slice(0, 2);
    expect(hasValidPart7Shape(set)).toBe(false);
  });

  it("rejects when a single-document group has 5 questions", () => {
    const set = validSet();
    set.passageGroups[0].questions = Array.from({ length: 5 }, makeQuestion);
    expect(hasValidPart7Shape(set)).toBe(false);
  });

  it("rejects when the double-document group only has 1 document", () => {
    const set = validSet();
    set.passageGroups[2].documents = ["D3a"];
    expect(hasValidPart7Shape(set)).toBe(false);
  });

  it("rejects when the double-document group doesn't have exactly 5 questions", () => {
    const set = validSet();
    set.passageGroups[2].questions = set.passageGroups[2].questions.slice(0, 4);
    expect(hasValidPart7Shape(set)).toBe(false);
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd apps/web && npx vitest run --run src/lib/part7.test.ts`
Expected: FAIL — `./part7` doesn't exist yet.

- [ ] **Step 3: Implement `part7.ts`**

Create `apps/web/src/lib/part7.ts`:

```ts
import { LANGUAGE_LABELS, type TargetLanguage } from "./languages";
import { ECONOMY_VOLUMES, VOLUME_PROMPT_HINTS, type EconomyVolume } from "./toeicFilters";

export interface Part7Question {
  question: string;
  options: string[]; // always 4
  correctIndex: number;
  explanation: string; // Vietnamese
}

export interface Part7PassageGroup {
  documents: string[]; // 1 (single-passage) or 2 (double-passage)
  questions: Part7Question[]; // 3-4 for single-passage groups, 5 for the double-passage group
}

export interface Part7Set {
  passageGroups: Part7PassageGroup[]; // always 3: [single, single, double]
}

const SINGLE_QUESTION_COUNTS = [3, 4];
const DOUBLE_QUESTION_COUNT = 5;

// Ports lib/features/reading/data/sources/part7_source.dart's prompt. Takes
// resolved topic *names*, not a fixed enum — same shared "Chủ đề" filter
// every reading mode uses, per the hub/setup-merge spec. An empty topic list
// omits the register clause entirely rather than defaulting to a fake
// "general" register.
export function buildPart7Prompt(topicNames: string[], targetLanguage: TargetLanguage, volumes: EconomyVolume[]): string {
  const languageLabel = LANGUAGE_LABELS[targetLanguage];
  const contextClause = topicNames.length > 0 ? `, in a ${topicNames.join("/")} register/setting` : "";
  const effectiveVolumes = volumes.length === 0 ? ECONOMY_VOLUMES : volumes;
  const volumeHints = effectiveVolumes.map((v) => `${v}: ${VOLUME_PROMPT_HINTS[v]}`).join("; ");
  return (
    `You are creating a TOEIC Part 7 (Reading Comprehension) practice set for a Vietnamese speaker ` +
    `learning ${languageLabel}${contextClause}, calibrated to the Economy TOEIC difficulty ` +
    `volumes below (mix questions across them roughly evenly and randomly): ${volumeHints}. ` +
    `Write exactly 3 passage groups in this exact order: ` +
    `(1) a single-passage group: one realistic business document (email, letter, memo, ` +
    `notice, advertisement, article, or a short text-message exchange), with 3 or 4 ` +
    `multiple-choice questions; ` +
    `(2) another single-passage group, same rules, using a different document type than ` +
    `group 1; ` +
    `(3) a double-passage group: two genuinely related documents (e.g. a job ad and an ` +
    `application email, an announcement and a reply, an invoice and a follow-up letter) ` +
    `where the second document cannot be fully understood without the first, with exactly ` +
    `5 multiple-choice questions, at least one of which requires information from both ` +
    `documents to answer. ` +
    `Every question has exactly 4 answer options in ${languageLabel}, testing main ` +
    `idea, a specific detail, an inference, or vocabulary-in-context, plus a brief ` +
    `explanation (in Vietnamese) of why the correct option is right. The explanation must ` +
    `use only Vietnamese script — never Chinese, Japanese, or other non-Vietnamese ` +
    `characters. ` +
    `Respond with JSON only (no markdown, no code fences): ` +
    `{"passageGroups": [{"documents": ["..."], "questions": [{"question": "...", ` +
    `"options": ["...", "...", "...", "..."], "correctIndex": 0, "explanation": "..."}]}]}`
  );
}

export function parsePart7Set(json: Record<string, unknown>): Part7Set {
  const rawGroups = Array.isArray(json.passageGroups) ? json.passageGroups : [];
  const passageGroups: Part7PassageGroup[] = [];
  for (const raw of rawGroups) {
    if (typeof raw !== "object" || raw === null) continue;
    const g = raw as Record<string, unknown>;
    const rawQuestions = Array.isArray(g.questions) ? g.questions : [];
    const questions: Part7Question[] = [];
    for (const rq of rawQuestions) {
      if (typeof rq !== "object" || rq === null) continue;
      const q = rq as Record<string, unknown>;
      questions.push({
        question: typeof q.question === "string" ? q.question : "",
        options: Array.isArray(q.options) ? q.options.map(String) : [],
        correctIndex: typeof q.correctIndex === "number" ? q.correctIndex : 0,
        explanation: typeof q.explanation === "string" ? q.explanation : "",
      });
    }
    passageGroups.push({
      documents: Array.isArray(g.documents) ? g.documents.map(String) : [],
      questions,
    });
  }
  return { passageGroups };
}

// Ports Part7Source's private _hasValidShape check — a stricter structural
// check than "is it empty", since a malformed group count or a wrong
// single/double-document split can't be rendered as a valid Part 7 set at
// all. Deliberately separate from parsePart7Set (which stays non-throwing,
// like its Part5/Part6 siblings) — the page decides whether to reject a
// parsed-but-invalid-shape result, exactly as Part5/Part6's pages already
// decide "is this empty" themselves.
export function hasValidPart7Shape(set: Part7Set): boolean {
  if (set.passageGroups.length !== 3) return false;
  for (let i = 0; i < 2; i++) {
    const group = set.passageGroups[i];
    if (group.documents.length !== 1) return false;
    if (!SINGLE_QUESTION_COUNTS.includes(group.questions.length)) return false;
  }
  const doubleGroup = set.passageGroups[2];
  if (doubleGroup.documents.length !== 2) return false;
  if (doubleGroup.questions.length !== DOUBLE_QUESTION_COUNT) return false;
  return true;
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd apps/web && npx vitest run --run src/lib/part7.test.ts`
Expected: PASS, all tests green.

- [ ] **Step 5: Typecheck**

Run: `cd apps/web && npx tsc --noEmit`
Expected: no errors.

- [ ] **Step 6: Commit**

```bash
git add apps/web/src/lib/part7.ts apps/web/src/lib/part7.test.ts
git commit -m "feat(web): add Part 7 prompt builder, response parser, and shape validator"
```

---

## Task 2: `savedReadingExercises.ts` — add the `"part7"` variant

**Files:**
- Modify: `apps/web/src/lib/savedReadingExercises.ts`
- Modify: `apps/web/src/lib/savedReadingExercises.test.ts`

**Interfaces:**
- Consumes: `Part7Set` (`@/lib/part7`, from Task 1).
- Produces (used by Task 4): `SavedReadingExercise` gains a `{ id: string; type: "part7"; passage: Part7Set; generationFilters: ToeicFilters; targetLanguage: TargetLanguage; createdAt: string }` member. `saveReadingExercise`/`getRandomSavedExercise` accept `"part7"` as their `type` argument with no signature change.

- [ ] **Step 1: Write the failing tests**

In `apps/web/src/lib/savedReadingExercises.test.ts`, add this import:

```ts
import type { Part7Set } from "./part7";
```

Add this fixture right after `PART6_PASSAGE`'s declaration (reusing the existing `FakeToeicFilters` interface — Part 7 shares the identical filter shape with Part 5/Part 6):

```ts
const PART7_PASSAGE: Part7Set = {
  passageGroups: [
    {
      documents: ["Doc A"],
      questions: [{ question: "Q1?", options: ["a", "b", "c", "d"], correctIndex: 0, explanation: "A." }],
    },
  ],
};
```

Add this factory right after `makePart6Exercise`:

```ts
function makePart7Exercise(overrides: Partial<{ id: string; generationFilters: FakeToeicFilters }> = {}) {
  return {
    id: "p7-1",
    type: "part7" as const,
    passage: PART7_PASSAGE,
    generationFilters: { topicIds: ["biz-1"], volumes: ["vol3"] },
    targetLanguage: "english" as const,
    createdAt: "2026-01-01T00:00:00.000Z",
    ...overrides,
  };
}
```

Add this test inside the existing `describe("saveReadingExercise", ...)` block, after the "creates a part6 document..." test:

```ts
  it("creates a part7 document carrying its own id field, and returns that id", async () => {
    vi.mocked(doc).mockReturnValue({ id: "new-p7-id" } as never);
    const filters = { topicIds: ["biz-1"], volumes: ["vol3"] };

    const newId = await saveReadingExercise("user-123", "part7", PART7_PASSAGE, filters, "english");

    expect(setDoc).toHaveBeenCalledWith(
      { id: "new-p7-id" },
      expect.objectContaining({
        id: "new-p7-id",
        type: "part7",
        passage: PART7_PASSAGE,
        generationFilters: filters,
        targetLanguage: "english",
      })
    );
    expect(newId).toBe("new-p7-id");
  });
```

Add these tests inside the existing `describe("getRandomSavedExercise", ...)` block, after the part6 matching tests:

```ts
  it("matches part7 exercises by topic overlap and volume overlap, mirroring part5/part6's matching", async () => {
    const p7 = makePart7Exercise({ generationFilters: { topicIds: ["biz-1", "travel-1"], volumes: ["vol2", "vol3"] } });
    vi.mocked(getDocs).mockResolvedValue({ docs: [{ id: p7.id, data: () => p7 }] } as never);

    const result = await getRandomSavedExercise("user-123", "english", "part7", {
      topicIds: ["travel-1", "food-1"],
      volumes: ["vol3", "vol4"],
    } as never);

    expect(result?.id).toBe(p7.id);
  });

  it("does not match a part7 exercise when there is no topic overlap", async () => {
    const p7 = makePart7Exercise({ generationFilters: { topicIds: ["biz-1"], volumes: [] } });
    vi.mocked(getDocs).mockResolvedValue({ docs: [{ id: p7.id, data: () => p7 }] } as never);

    const result = await getRandomSavedExercise("user-123", "english", "part7", {
      topicIds: ["travel-1"],
      volumes: [],
    } as never);

    expect(result).toBeNull();
  });

  it("does not return a part6 exercise when requesting type part7, even though both share the same ToeicFilters shape", async () => {
    const p6 = makePart6Exercise({ generationFilters: { topicIds: ["biz-1"], volumes: ["vol3"] } });
    const p7 = makePart7Exercise({ generationFilters: { topicIds: ["biz-1"], volumes: ["vol3"] } });
    vi.mocked(getDocs).mockResolvedValue({
      docs: [
        { id: p6.id, data: () => p6 },
        { id: p7.id, data: () => p7 },
      ],
    } as never);

    const result = await getRandomSavedExercise("user-123", "english", "part7", {
      topicIds: ["biz-1"],
      volumes: ["vol3"],
    } as never);

    expect(result?.type).toBe("part7");
    expect(result?.id).toBe(p7.id);
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd apps/web && npx vitest run --run src/lib/savedReadingExercises.test.ts`
Expected: FAIL — `"part7"` isn't a valid `type` yet.

- [ ] **Step 3: Add the `"part7"` union member**

In `apps/web/src/lib/savedReadingExercises.ts`, add this import:

```ts
import type { Part7Set } from "./part7";
```

Add a new member to the `SavedReadingExercise` union, after the `"part6"` member — move the trailing `;` from the old last member (`"part6"`, whose closing brace should now end in `,` instead) onto this new one, since it's now the last member of the union:

```ts
  | {
      id: string;
      type: "part7";
      passage: Part7Set;
      generationFilters: ToeicFilters;
      targetLanguage: TargetLanguage;
      createdAt: string;
    };
```

No other line in this file changes.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd apps/web && npx vitest run --run src/lib/savedReadingExercises.test.ts`
Expected: PASS, all tests green.

- [ ] **Step 5: Run the full suite and typecheck**

Run: `cd apps/web && npm test -- --run && npx tsc --noEmit`
Expected: all tests pass (aside from the known pre-existing `bloom.test.ts` failure); no type errors.

- [ ] **Step 6: Commit**

```bash
git add apps/web/src/lib/savedReadingExercises.ts apps/web/src/lib/savedReadingExercises.test.ts
git commit -m "feat(web): add the part7 variant to SavedReadingExercise"
```

---

## Task 3: Add Part 7 to the reading hub

**Files:**
- Modify: `apps/web/src/app/(app)/reading/page.tsx`
- Modify: `apps/web/src/app/(app)/reading/page.test.tsx`

**Interfaces:**
- Produces (used by Task 4, as the URL shape it must read): navigating to Part 7 emits `/reading/part7?topicIds=<...>&volumes=<...>&action=<generate|existing>` — identical encoding to Part 5/6, no new param.

- [ ] **Step 1: Write the failing tests**

In `apps/web/src/app/(app)/reading/page.test.tsx`, add these tests to the `describe("ReadingHubPage (mode picker)", ...)` block, after the existing Part 6 tests:

```ts
  it("shows Part 7's own secondary filter (Độ khó chips) once that mode is picked", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([]);

    render(<ReadingHubPage />);
    fireEvent.click(await screen.findByRole("button", { name: /Part 7/ }));

    expect(await screen.findByRole("button", { name: "🔀 Lấy bài có sẵn" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Tạo bài luyện" })).not.toBeDisabled();
    expect(screen.getByRole("button", { name: VOLUME_LABEL_VOL2 })).toBeInTheDocument();
  });

  it("Part 7's 'Lấy bài có sẵn' is never gated by word count, even with 0 matching words", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([]);

    render(<ReadingHubPage />);
    fireEvent.click(await screen.findByRole("button", { name: /Part 7/ }));

    expect(await screen.findByRole("button", { name: "🔀 Lấy bài có sẵn" })).not.toBeDisabled();
  });
```

Add this test to the `describe("ReadingHubPage (navigation)", ...)` block, after the existing Part 6 navigation test:

```ts
  it("navigates to /reading/part7 with selected volumes and action=generate", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([]);

    render(<ReadingHubPage />);
    fireEvent.click(await screen.findByRole("button", { name: /Part 7/ }));
    fireEvent.click(screen.getByRole("button", { name: VOLUME_LABEL_VOL2 }));
    fireEvent.click(screen.getByRole("button", { name: "Tạo bài luyện" }));

    expect(pushMock).toHaveBeenCalledWith("/reading/part7?volumes=vol2&action=generate");
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd apps/web && npx vitest run --run "src/app/(app)/reading/page.test.tsx"`
Expected: FAIL — the hub has no Part 7 mode yet.

- [ ] **Step 3: Add Part 7 to the hub**

In `apps/web/src/app/(app)/reading/page.tsx`:

Change the `Mode` type:

```ts
type Mode = "bilingual" | "part5" | "part6" | "part7";
```

In `buildQuery`, change:

```ts
    } else if (mode === "part5" || mode === "part6") {
      if (selectedVolumes.size > 0) params.set("volumes", [...selectedVolumes].join(","));
    }
```

to:

```ts
    } else if (mode === "part5" || mode === "part6" || mode === "part7") {
      if (selectedVolumes.size > 0) params.set("volumes", [...selectedVolumes].join(","));
    }
```

In `navigate`, change:

```ts
    const path = mode === "bilingual" ? "/reading/bilingual" : mode === "part5" ? "/reading/part5" : "/reading/part6";
```

to:

```ts
    const path =
      mode === "bilingual"
        ? "/reading/bilingual"
        : mode === "part5"
          ? "/reading/part5"
          : mode === "part6"
            ? "/reading/part6"
            : "/reading/part7";
```

Change the volume-chip secondary filter's guard:

```tsx
      {(mode === "part5" || mode === "part6") && (
```

to (equivalent to adding `|| mode === "part7"`, but matches the "Tạo bài luyện" gate's own existing `mode !== "bilingual"` phrasing just below it):

```tsx
      {mode !== "bilingual" && mode !== null && (
```

Add a fourth mode card, right after the Part 6 card inside `.reading-hub-cards`:

```tsx
        <button
          type="button"
          className={`reading-hub-card reading-hub-card-toggle${mode === "part7" ? " active" : ""}`}
          onClick={() => setMode("part7")}
        >
          <span className="reading-hub-card-title">📖 Part 7 — Đọc hiểu</span>
          <span className="reading-hub-card-desc">
            3 nhóm văn bản, 9-13 câu hỏi đọc hiểu kiểu TOEIC.
          </span>
        </button>
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
git commit -m "feat(web): add Part 7 to the reading hub"
```

---

## Task 4: `/reading/part7/page.tsx` — session and result screens

**Files:**
- Create: `apps/web/src/app/(app)/reading/part7/page.tsx`
- Create: `apps/web/src/app/(app)/reading/part7/page.test.tsx`

**Interfaces:**
- Consumes: `buildPart7Prompt`/`parsePart7Set`/`hasValidPart7Shape`/`Part7Set`/`Part7PassageGroup` (`@/lib/part7`, Task 1), the `"part7"` `SavedReadingExercise` variant (`@/lib/savedReadingExercises`, Task 2), `McQuestionCard` (`@/components/reading/McQuestionCard`, unchanged), `VocabSuggestionsSection` (`@/components/shared/VocabSuggestionsSection`, unchanged), `.reading-passage-group`/`.reading-passage-group-title`/`.reading-passage-text` CSS classes (`apps/web/src/styles/bloom.css`, already added by the Part 6 feature — no new CSS needed). Reads the same `topicIds`/`volumes`/`action` URL shape Task 3's hub produces.

- [ ] **Step 1: Write the failing tests**

Create `apps/web/src/app/(app)/reading/part7/page.test.tsx`:

```tsx
import { beforeEach, describe, expect, it, vi } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import Part7Page from "./page";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettingsContext } from "@/lib/SettingsContext";
import { getVocabRecords } from "@/lib/vocabRecords";
import { getTopics, type Topic } from "@/lib/topics";
import { generateContent } from "@/lib/generateContent";
import { getRandomSavedExercise, saveReadingExercise } from "@/lib/savedReadingExercises";
import { DEFAULT_SETTINGS, type UserSettings } from "@/lib/settings";
import type { Part7Set } from "@/lib/part7";

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

// A genuine 3-group / 12-question set: group 0 has 3 questions, group 1 has
// 4, group 2 (double-document) has 5 — deliberately UNEQUAL group sizes so
// the running-sum flatIndex offsets (0, 3, 7) are non-uniform, which a fixed
// multiplier or an off-by-one would fail to reproduce. Every one of the 48
// option strings across the whole fixture is textually unique so every
// getByRole("button", { name }) call below stays unambiguous.
const THREE_GROUP_SET: Part7Set = {
  passageGroups: [
    {
      documents: ["A memo about the new parking policy."],
      questions: [
        {
          question: "What is the memo about?",
          options: ["Parking policy", "Lunch menu", "Holiday schedule", "IT outage"],
          correctIndex: 0,
          explanation: "Nói về chính sách đỗ xe.",
        },
        {
          question: "When does the policy take effect?",
          options: ["Immediately", "Next month", "Next year", "Unknown"],
          correctIndex: 1,
          explanation: "Có hiệu lực tháng sau.",
        },
        {
          question: "Who should employees contact?",
          options: ["Human Resources", "Facilities", "IT Support", "Security Team"],
          correctIndex: 1,
          explanation: "Liên hệ bộ phận Facilities.",
        },
      ],
    },
    {
      documents: ["An email announcing a new product launch."],
      questions: [
        {
          question: "What product is being launched?",
          options: ["A software tool", "A phone", "A chair", "A car"],
          correctIndex: 0,
          explanation: "Ra mắt một công cụ phần mềm.",
        },
        {
          question: "When is the launch date?",
          options: ["Monday", "Tuesday", "Wednesday", "Thursday"],
          correctIndex: 2,
          explanation: "Ra mắt vào thứ Tư.",
        },
        {
          question: "Who is the email from?",
          options: ["CEO", "Marketing Team", "IT Department", "People Ops"],
          correctIndex: 1,
          explanation: "Từ bộ phận Marketing.",
        },
        {
          question: "What is requested of the reader?",
          options: ["Attend a demo", "Buy now", "Ignore it", "Forward it"],
          correctIndex: 0,
          explanation: "Yêu cầu tham dự buổi demo.",
        },
      ],
    },
    {
      documents: [
        "A job advertisement for a marketing manager.",
        "An application email from a candidate.",
      ],
      questions: [
        {
          question: "What position is advertised?",
          options: ["Marketing Manager", "Sales Rep", "Engineer", "Designer"],
          correctIndex: 0,
          explanation: "Vị trí Marketing Manager.",
        },
        {
          question: "What does the candidate attach?",
          options: ["A resume", "A photo", "A video", "Nothing"],
          correctIndex: 0,
          explanation: "Đính kèm sơ yếu lý lịch.",
        },
        {
          question: "How many years of experience does the ad require?",
          options: ["One year", "Three years", "Five years", "Ten years"],
          correctIndex: 2,
          explanation: "Yêu cầu 5 năm kinh nghiệm.",
        },
        {
          question: "What must be true for the candidate to qualify, based on both documents?",
          options: ["Five years experience match", "Wrong location", "No degree", "Too young"],
          correctIndex: 0,
          explanation: "Cần đối chiếu cả 2 văn bản.",
        },
        {
          question: "When does the candidate want to start?",
          options: ["Right away", "In a year", "Never", "Unclear"],
          correctIndex: 0,
          explanation: "Muốn bắt đầu ngay.",
        },
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

describe("Part7Page (loading phase)", () => {
  it("prompts sign-in when logged out", () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: null, loading: false } as never);
    vi.mocked(useSettingsContext).mockReturnValue({ settings: null, loading: false, error: null, save: vi.fn() });
    render(<Part7Page />);
    expect(screen.getByText("Đăng nhập với Google")).toBeInTheDocument();
  });

  it("redirects to /reading when the action param is missing", async () => {
    setSearchParams({});
    mockSignedIn();

    render(<Part7Page />);

    await waitFor(() => expect(replaceMock).toHaveBeenCalledWith("/reading"));
  });

  it("redirects to /reading when the action param is invalid", async () => {
    setSearchParams({ action: "bogus" });
    mockSignedIn();

    render(<Part7Page />);

    await waitFor(() => expect(replaceMock).toHaveBeenCalledWith("/reading"));
  });

  it("auto-generates a set on mount, resolving topicIds to topic names in the prompt", async () => {
    setSearchParams({ topicIds: "biz-1", action: "generate" });
    mockSignedIn();
    const topics: Topic[] = [{ id: "biz-1", name: "Business", emoji: "💼", isPredefined: true, createdAt: "2026-01-01" }];
    vi.mocked(getTopics).mockResolvedValue(topics);
    vi.mocked(generateContent).mockResolvedValue({ text: JSON.stringify(THREE_GROUP_SET) });

    render(<Part7Page />);

    expect(await screen.findByText("Đoạn 1")).toBeInTheDocument();
    const promptArg = vi.mocked(generateContent).mock.calls[0][0].prompt;
    expect(promptArg).toContain("exactly 3 passage groups");
    expect(promptArg).toContain("Business");
  });

  it("shows an error with retry/back-to-hub actions when the active provider has no API key", async () => {
    setSearchParams({ action: "generate" });
    mockSignedIn({ ...DEFAULT_SETTINGS, activeProvider: "gemini", providers: { ...DEFAULT_SETTINGS.providers, gemini: { model: "gemini-2.5-flash", apiKeyCiphertext: null } } });

    render(<Part7Page />);

    expect(await screen.findByText("Chưa có API key cho nhà cung cấp AI đang chọn — vào Cài đặt để thêm.")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Thử lại" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Về trang chính" })).toBeInTheDocument();
    expect(generateContent).not.toHaveBeenCalled();
  });

  it("shows an error when the AI response has an invalid shape, and 'Thử lại' retries the same action", async () => {
    setSearchParams({ action: "generate" });
    mockSignedIn();
    vi.mocked(generateContent).mockResolvedValueOnce({ text: JSON.stringify({}) });

    render(<Part7Page />);
    await screen.findByText("AI không trả về bài luyện hợp lệ.");

    vi.mocked(generateContent).mockResolvedValue({ text: JSON.stringify(THREE_GROUP_SET) });
    fireEvent.click(screen.getByRole("button", { name: "Thử lại" }));

    await waitFor(() => expect(screen.getByText("Đoạn 1")).toBeInTheDocument());
  });

  it('"Về trang chính" on the loading-error state navigates back to the hub', async () => {
    setSearchParams({ action: "generate" });
    mockSignedIn({ ...DEFAULT_SETTINGS, activeProvider: "gemini", providers: { ...DEFAULT_SETTINGS.providers, gemini: { model: "gemini-2.5-flash", apiKeyCiphertext: null } } });

    render(<Part7Page />);
    fireEvent.click(await screen.findByRole("button", { name: "Về trang chính" }));

    expect(pushMock).toHaveBeenCalledWith("/reading");
  });

  it('action=existing starts a session directly from a matching saved exercise, without calling the AI', async () => {
    setSearchParams({ action: "existing" });
    mockSignedIn();
    vi.mocked(getRandomSavedExercise).mockResolvedValue({
      id: "saved-1",
      type: "part7",
      passage: THREE_GROUP_SET,
      generationFilters: { topicIds: [], volumes: [] },
      targetLanguage: "english",
      createdAt: "2026-01-01T00:00:00.000Z",
    } as never);

    render(<Part7Page />);

    expect(await screen.findByText("Đoạn 1")).toBeInTheDocument();
    expect(generateContent).not.toHaveBeenCalled();
  });

  it("action=existing shows an inline notice and falls back to AI generation when nothing matches", async () => {
    setSearchParams({ action: "existing" });
    mockSignedIn();
    let resolveGenerate!: (value: { text: string }) => void;
    vi.mocked(generateContent).mockReturnValue(
      new Promise((resolve) => {
        resolveGenerate = resolve;
      })
    );

    render(<Part7Page />);

    expect(await screen.findByText("Chưa có bài đã lưu khớp bộ lọc này — đang tạo bài mới bằng AI…")).toBeInTheDocument();
    expect(generateContent).toHaveBeenCalled();

    resolveGenerate({ text: JSON.stringify(THREE_GROUP_SET) });
    await waitFor(() => expect(screen.getByText("Đoạn 1")).toBeInTheDocument());
  });
});

describe("Part7Page (session phase)", () => {
  async function generateSession() {
    setSearchParams({ action: "generate" });
    vi.mocked(generateContent).mockResolvedValue({ text: JSON.stringify(THREE_GROUP_SET) });
    render(<Part7Page />);
    await screen.findByText("Đoạn 1");
  }

  it("renders all 3 groups with their documents, the double-document group labeled distinctly, and questions numbered per group", async () => {
    mockSignedIn();
    await generateSession();

    expect(screen.getByText("Đoạn 1")).toBeInTheDocument();
    expect(screen.getByText("Đoạn 2")).toBeInTheDocument();
    expect(screen.getByText("Đoạn 3 (2 văn bản liên quan)")).toBeInTheDocument();
    expect(screen.getByText("A memo about the new parking policy.")).toBeInTheDocument();
    expect(screen.getByText("A job advertisement for a marketing manager.")).toBeInTheDocument();
    expect(screen.getByText("An application email from a candidate.")).toBeInTheDocument();
    expect(screen.getByText("1. What is the memo about?")).toBeInTheDocument();
    // Question numbering resets per group — group 2's first question is
    // "1. ...", not a running total like "8. ...".
    expect(screen.getByText("1. What position is advertised?")).toBeInTheDocument();
  });

  it("maps cross-group selections to independent slots via the running-sum flatIndex", async () => {
    mockSignedIn();
    await generateSession();

    // flatIndex(0,2) = 2, flatIndex(2,0) = 3+4+0 = 7 — chosen because the
    // group sizes are unequal (3, 4, 5), so a wrong formula (a fixed
    // multiplier, or summing indices instead of prior group lengths) would
    // misalign these two selections onto the same or a different slot than
    // the correct one.
    fireEvent.click(screen.getByRole("button", { name: "Human Resources" })); // group 0, question index 2
    fireEvent.click(screen.getByRole("button", { name: "Marketing Manager" })); // group 2, question index 0

    expect(screen.getByRole("button", { name: "Human Resources" })).toHaveAttribute("aria-pressed", "true");
    expect(screen.getByRole("button", { name: "Marketing Manager" })).toHaveAttribute("aria-pressed", "true");
    // Sibling options in those same two questions must stay unselected.
    expect(screen.getByRole("button", { name: "Facilities" })).toHaveAttribute("aria-pressed", "false");
    expect(screen.getByRole("button", { name: "Sales Rep" })).toHaveAttribute("aria-pressed", "false");
    // Every other question's options must be untouched by these two clicks.
    expect(screen.getByRole("button", { name: "Parking policy" })).toHaveAttribute("aria-pressed", "false");
    expect(screen.getByRole("button", { name: "Right away" })).toHaveAttribute("aria-pressed", "false");
  });

  it("keeps Nộp bài disabled until all 12 questions across all 3 groups are answered", async () => {
    mockSignedIn();
    await generateSession();

    // Answer 11 of 12, spread across all 3 groups (not clustered in one).
    fireEvent.click(screen.getByRole("button", { name: "Parking policy" }));
    fireEvent.click(screen.getByRole("button", { name: "Next month" }));
    fireEvent.click(screen.getByRole("button", { name: "Facilities" }));
    fireEvent.click(screen.getByRole("button", { name: "A software tool" }));
    fireEvent.click(screen.getByRole("button", { name: "Wednesday" }));
    fireEvent.click(screen.getByRole("button", { name: "Marketing Team" }));
    fireEvent.click(screen.getByRole("button", { name: "Attend a demo" }));
    fireEvent.click(screen.getByRole("button", { name: "Marketing Manager" }));
    fireEvent.click(screen.getByRole("button", { name: "A resume" }));
    fireEvent.click(screen.getByRole("button", { name: "Five years" }));
    fireEvent.click(screen.getByRole("button", { name: "Five years experience match" }));
    expect(screen.getByRole("button", { name: "Nộp bài" })).toBeDisabled();

    fireEvent.click(screen.getByRole("button", { name: "Right away" })); // the 12th, final answer
    expect(screen.getByRole("button", { name: "Nộp bài" })).not.toBeDisabled();
  });
});

describe("Part7Page (result phase)", () => {
  async function completeSession() {
    setSearchParams({ action: "generate" });
    vi.mocked(generateContent).mockResolvedValue({ text: JSON.stringify(THREE_GROUP_SET) });
    render(<Part7Page />);
    await screen.findByText("Đoạn 1");
    // Group 0: all 3 correct.
    fireEvent.click(screen.getByRole("button", { name: "Parking policy" }));
    fireEvent.click(screen.getByRole("button", { name: "Next month" }));
    fireEvent.click(screen.getByRole("button", { name: "Facilities" }));
    // Group 1: 2 correct, 2 wrong.
    fireEvent.click(screen.getByRole("button", { name: "A software tool" })); // correct
    fireEvent.click(screen.getByRole("button", { name: "Wednesday" })); // correct
    fireEvent.click(screen.getByRole("button", { name: "CEO" })); // wrong (correct is Marketing Team)
    fireEvent.click(screen.getByRole("button", { name: "Buy now" })); // wrong (correct is Attend a demo)
    // Group 2: 3 correct, 2 wrong.
    fireEvent.click(screen.getByRole("button", { name: "Marketing Manager" })); // correct
    fireEvent.click(screen.getByRole("button", { name: "A resume" })); // correct
    fireEvent.click(screen.getByRole("button", { name: "Five years" })); // correct
    fireEvent.click(screen.getByRole("button", { name: "Wrong location" })); // wrong
    fireEvent.click(screen.getByRole("button", { name: "Never" })); // wrong
    fireEvent.click(screen.getByRole("button", { name: "Nộp bài" }));
    await screen.findByText(/\d+\/12/);
  }

  it("scores 8/12 from a deliberate correct/incorrect mix spread across all 3 groups, with explanations", async () => {
    mockSignedIn();
    await completeSession();

    expect(screen.getByText("8/12")).toBeInTheDocument();
    expect(screen.getByText("Giải thích: Nói về chính sách đỗ xe.")).toBeInTheDocument();
    expect(screen.getByText("Giải thích: Cần đối chiếu cả 2 văn bản.")).toBeInTheDocument();
    const suggestions = screen.getByTestId("vocab-suggestions");
    expect(suggestions).toHaveAttribute(
      "data-text",
      "A memo about the new parking policy. An email announcing a new product launch. A job advertisement for a marketing manager. An application email from a candidate."
    );
  });

  it('shows "Lưu bài" for a generated session and saves with the type "part7"', async () => {
    mockSignedIn();
    vi.mocked(saveReadingExercise).mockResolvedValue("new-id");
    await completeSession();

    fireEvent.click(screen.getByRole("button", { name: "Lưu bài" }));

    expect(await screen.findByText("Đã lưu ✔")).toBeInTheDocument();
    expect(saveReadingExercise).toHaveBeenCalledWith(
      "u1",
      "part7",
      expect.objectContaining({ passageGroups: expect.any(Array) }),
      expect.objectContaining({ topicIds: [], volumes: [] }),
      "english"
    );
  });

  it('"Bài khác" replays AI-generation directly for a generated session', async () => {
    mockSignedIn();
    await completeSession();
    vi.mocked(generateContent).mockResolvedValue({
      text: JSON.stringify({
        passageGroups: [
          {
            documents: ["New group document."],
            questions: [
              { question: "New question?", options: ["w", "x", "y", "z"], correctIndex: 0, explanation: "E." },
              { question: "New question 2?", options: ["w2", "x2", "y2", "z2"], correctIndex: 0, explanation: "E." },
              { question: "New question 3?", options: ["w3", "x3", "y3", "z3"], correctIndex: 0, explanation: "E." },
            ],
          },
          {
            documents: ["Second new document."],
            questions: [
              { question: "Q4?", options: ["a4", "b4", "c4", "d4"], correctIndex: 0, explanation: "E." },
              { question: "Q5?", options: ["a5", "b5", "c5", "d5"], correctIndex: 0, explanation: "E." },
              { question: "Q6?", options: ["a6", "b6", "c6", "d6"], correctIndex: 0, explanation: "E." },
            ],
          },
          {
            documents: ["Third doc A.", "Third doc B."],
            questions: Array.from({ length: 5 }, (_, i) => ({
              question: `DQ${i}?`,
              options: [`da${i}`, `db${i}`, `dc${i}`, `dd${i}`],
              correctIndex: 0,
              explanation: "E.",
            })),
          },
        ],
      }),
    });

    fireEvent.click(screen.getByRole("button", { name: "Bài khác" }));

    expect(await screen.findByText("New group document.")).toBeInTheDocument();
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

  it("hides the vocab-suggestions section and the Lưu bài button for a reused session's result screen", async () => {
    mockSignedIn();
    setSearchParams({ action: "existing" });
    vi.mocked(getRandomSavedExercise).mockResolvedValue({
      id: "saved-1",
      type: "part7",
      passage: THREE_GROUP_SET,
      generationFilters: { topicIds: [], volumes: [] },
      targetLanguage: "english",
      createdAt: "2026-01-01T00:00:00.000Z",
    } as never);
    render(<Part7Page />);
    await screen.findByText("Đoạn 1");
    fireEvent.click(screen.getByRole("button", { name: "Parking policy" }));
    fireEvent.click(screen.getByRole("button", { name: "Next month" }));
    fireEvent.click(screen.getByRole("button", { name: "Facilities" }));
    fireEvent.click(screen.getByRole("button", { name: "A software tool" }));
    fireEvent.click(screen.getByRole("button", { name: "Wednesday" }));
    fireEvent.click(screen.getByRole("button", { name: "Marketing Team" }));
    fireEvent.click(screen.getByRole("button", { name: "Attend a demo" }));
    fireEvent.click(screen.getByRole("button", { name: "Marketing Manager" }));
    fireEvent.click(screen.getByRole("button", { name: "A resume" }));
    fireEvent.click(screen.getByRole("button", { name: "Five years" }));
    fireEvent.click(screen.getByRole("button", { name: "Five years experience match" }));
    fireEvent.click(screen.getByRole("button", { name: "Right away" }));
    fireEvent.click(screen.getByRole("button", { name: "Nộp bài" }));
    await screen.findByText("12/12");

    expect(screen.queryByTestId("vocab-suggestions")).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Lưu bài" })).not.toBeInTheDocument();
  });

  it('"Bài khác" fetches another saved exercise directly for a reused session, not the AI', async () => {
    mockSignedIn();
    setSearchParams({ action: "existing" });
    vi.mocked(getRandomSavedExercise).mockResolvedValueOnce({
      id: "saved-1",
      type: "part7",
      passage: THREE_GROUP_SET,
      generationFilters: { topicIds: [], volumes: [] },
      targetLanguage: "english",
      createdAt: "2026-01-01T00:00:00.000Z",
    } as never);
    render(<Part7Page />);
    await screen.findByText("Đoạn 1");
    fireEvent.click(screen.getByRole("button", { name: "Parking policy" }));
    fireEvent.click(screen.getByRole("button", { name: "Next month" }));
    fireEvent.click(screen.getByRole("button", { name: "Facilities" }));
    fireEvent.click(screen.getByRole("button", { name: "A software tool" }));
    fireEvent.click(screen.getByRole("button", { name: "Wednesday" }));
    fireEvent.click(screen.getByRole("button", { name: "Marketing Team" }));
    fireEvent.click(screen.getByRole("button", { name: "Attend a demo" }));
    fireEvent.click(screen.getByRole("button", { name: "Marketing Manager" }));
    fireEvent.click(screen.getByRole("button", { name: "A resume" }));
    fireEvent.click(screen.getByRole("button", { name: "Five years" }));
    fireEvent.click(screen.getByRole("button", { name: "Five years experience match" }));
    fireEvent.click(screen.getByRole("button", { name: "Right away" }));
    fireEvent.click(screen.getByRole("button", { name: "Nộp bài" }));
    await screen.findByText("12/12");

    vi.mocked(getRandomSavedExercise).mockResolvedValueOnce({
      id: "saved-2",
      type: "part7",
      passage: {
        passageGroups: [
          {
            documents: ["Another group document."],
            questions: [
              { question: "Another Q?", options: ["p", "q", "r", "s"], correctIndex: 0, explanation: "E." },
              { question: "Another Q2?", options: ["p2", "q2", "r2", "s2"], correctIndex: 0, explanation: "E." },
              { question: "Another Q3?", options: ["p3", "q3", "r3", "s3"], correctIndex: 0, explanation: "E." },
            ],
          },
          {
            documents: ["Second another document."],
            questions: [
              { question: "AQ4?", options: ["p4", "q4", "r4", "s4"], correctIndex: 0, explanation: "E." },
              { question: "AQ5?", options: ["p5", "q5", "r5", "s5"], correctIndex: 0, explanation: "E." },
              { question: "AQ6?", options: ["p6", "q6", "r6", "s6"], correctIndex: 0, explanation: "E." },
            ],
          },
          {
            documents: ["Third another A.", "Third another B."],
            questions: Array.from({ length: 5 }, (_, i) => ({
              question: `ADQ${i}?`,
              options: [`ada${i}`, `adb${i}`, `adc${i}`, `add${i}`],
              correctIndex: 0,
              explanation: "E.",
            })),
          },
        ],
      },
      generationFilters: { topicIds: [], volumes: [] },
      targetLanguage: "english",
      createdAt: "2026-01-01T00:00:00.000Z",
    } as never);

    fireEvent.click(screen.getByRole("button", { name: "Bài khác" }));

    expect(await screen.findByText("Another group document.")).toBeInTheDocument();
    expect(getRandomSavedExercise).toHaveBeenCalledTimes(2);
    expect(generateContent).not.toHaveBeenCalled();
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd apps/web && npx vitest run --run "src/app/(app)/reading/part7/page.test.tsx"`
Expected: FAIL — the page doesn't exist yet.

- [ ] **Step 3: Implement the page**

Create `apps/web/src/app/(app)/reading/part7/page.tsx`:

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
import { buildPart7Prompt, parsePart7Set, hasValidPart7Shape, type Part7Set, type Part7PassageGroup } from "@/lib/part7";
import { generateContent } from "@/lib/generateContent";
import { parseAiJsonObject } from "@/lib/parseAiJson";
import { getRandomSavedExercise, saveReadingExercise, type ToeicFilters } from "@/lib/savedReadingExercises";
import { McQuestionCard } from "@/components/reading/McQuestionCard";
import { VocabSuggestionsSection } from "@/components/shared/VocabSuggestionsSection";

type Phase = "loading" | "session" | "result";

// Unlike Part 6's fixed 4-blanks-per-passage multiplier, Part 7's groups
// have variable question counts (3, 4, or 5) — this sums every prior
// group's actual question count instead of multiplying by a constant.
function flatIndex(groups: Part7PassageGroup[], groupIndex: number, questionIndex: number): number {
  let offset = 0;
  for (let i = 0; i < groupIndex; i++) offset += groups[i].questions.length;
  return offset + questionIndex;
}

function totalQuestions(groups: Part7PassageGroup[]): number {
  return groups.reduce((sum, g) => sum + g.questions.length, 0);
}

function Part7PageContent() {
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
  const [set, setSet] = useState<Part7Set | null>(null);
  const [answers, setAnswers] = useState<(number | null)[]>([]);
  const [sessionMode, setSessionMode] = useState<"generated" | "reused">("generated");
  const [justSavedId, setJustSavedId] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [contextLoaded, setContextLoaded] = useState(false);

  useEffect(() => {
    if (!user) return;
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
      const prompt = buildPart7Prompt(resolvedTopicNames(), settings.targetLanguage, volumes);
      const response = await generateContent({
        provider: settings.activeProvider,
        model: activeConfig.model,
        apiKeyCiphertext: activeConfig.apiKeyCiphertext,
        prompt,
      });
      const json = parseAiJsonObject(response.text);
      const generated = parsePart7Set(json);
      if (!hasValidPart7Shape(generated)) {
        throw new Error("AI không trả về bài luyện hợp lệ.");
      }
      setSessionMode("generated");
      setJustSavedId(null);
      setSaveError(null);
      setSet(generated);
      setAnswers(new Array(totalQuestions(generated.passageGroups)).fill(null));
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
      const saved = await getRandomSavedExercise(user.uid, settings.targetLanguage, "part7", currentFilters(), excludeId);
      if (saved) {
        found = true;
        setSessionMode("reused");
        setJustSavedId(null);
        setSaveError(null);
        setSet(saved.passage);
        setAnswers(new Array(totalQuestions(saved.passage.passageGroups)).fill(null));
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
      const newId = await saveReadingExercise(user.uid, "part7", set, currentFilters(), settings.targetLanguage);
      setJustSavedId(newId);
    } catch (err) {
      setSaveError(err instanceof Error ? err.message : String(err));
    } finally {
      setSaving(false);
    }
  }

  function handleSelectAnswer(groups: Part7PassageGroup[], groupIndex: number, questionIndex: number, optionIndex: number) {
    setAnswers((prev) => {
      const next = [...prev];
      next[flatIndex(groups, groupIndex, questionIndex)] = optionIndex;
      return next;
    });
  }

  async function handleNewSession() {
    if (sessionMode === "reused") {
      await fetchSavedExercise(justSavedId ?? undefined);
      return;
    }
    await handleGenerate();
  }

  if (authLoading) return <p>Đang tải…</p>;

  if (!user) {
    return (
      <div>
        <h2 className="scr-title">Part 7 — Đọc hiểu</h2>
        <p className="scr-sub">Đăng nhập để luyện tập.</p>
        <SignInButton />
      </div>
    );
  }

  if (settingsLoading || !settings) return <p>Đang tải…</p>;

  if (phase === "loading") {
    return (
      <div>
        <h2 className="scr-title">Part 7 — Đọc hiểu</h2>
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
    const groups = set.passageGroups;
    const canSubmit = answers.every((a) => a !== null);
    return (
      <div>
        <h2 className="scr-title">Part 7 — Đọc hiểu</h2>
        {groups.map((group, g) => (
          <div key={g} className="reading-passage-group">
            <h3 className="reading-passage-group-title">
              {group.documents.length === 2 ? `Đoạn ${g + 1} (2 văn bản liên quan)` : `Đoạn ${g + 1}`}
            </h3>
            {group.documents.map((doc, d) => (
              <p key={d} className="reading-passage-text">
                {doc}
              </p>
            ))}
            {group.questions.map((q, qi) => (
              <McQuestionCard
                key={qi}
                label={`${qi + 1}. ${q.question}`}
                options={q.options}
                selected={answers[flatIndex(groups, g, qi)]}
                onSelect={(optionIndex) => handleSelectAnswer(groups, g, qi, optionIndex)}
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

  const groups = set?.passageGroups ?? [];
  const total = totalQuestions(groups);
  const correctCount = groups.reduce(
    (sum, group, g) =>
      sum + group.questions.filter((q, qi) => answers[flatIndex(groups, g, qi)] === q.correctIndex).length,
    0
  );
  const documentsText = groups.flatMap((g) => g.documents).join(" ");

  return (
    <div>
      <h2 className="scr-title">Kết quả</h2>
      <p className="mc-score">
        {correctCount}/{total}
      </p>
      {groups.map((group, g) => (
        <div key={g} className="reading-passage-group">
          <h3 className="reading-passage-group-title">
            {group.documents.length === 2 ? `Đoạn ${g + 1} (2 văn bản liên quan)` : `Đoạn ${g + 1}`}
          </h3>
          {group.documents.map((doc, d) => (
            <p key={d} className="reading-passage-text">
              {doc}
            </p>
          ))}
          {group.questions.map((q, qi) => (
            <McQuestionCard
              key={qi}
              label={`${qi + 1}. ${q.question}`}
              options={q.options}
              selected={answers[flatIndex(groups, g, qi)]}
              correctIndex={q.correctIndex}
              explanation={q.explanation}
            />
          ))}
        </div>
      ))}
      {sessionMode === "generated" && <VocabSuggestionsSection text={documentsText} existingRecords={records} topics={topics} />}
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

export default function Part7Page() {
  return (
    <Suspense fallback={<p>Đang tải…</p>}>
      <Part7PageContent />
    </Suspense>
  );
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd apps/web && npx vitest run --run "src/app/(app)/reading/part7/page.test.tsx"`
Expected: PASS, all tests green.

- [ ] **Step 5: Run the full suite, typecheck, and build**

Run: `cd apps/web && npm test -- --run && npx tsc --noEmit && npm run build`
Expected: all tests pass (aside from the known pre-existing `bloom.test.ts` failure); no type errors; build succeeds with `/reading/part7` prerendered as a static page.

- [ ] **Step 6: Commit**

```bash
git add "apps/web/src/app/(app)/reading/part7/page.tsx" "apps/web/src/app/(app)/reading/part7/page.test.tsx"
git commit -m "feat(web): add /reading/part7 — TOEIC Part 7 practice with save/reuse"
```

---

## Final verification (after all 4 tasks)

- [ ] Run the full suite once more: `cd apps/web && npm test -- --run` — expect all tests green apart from the known pre-existing, unrelated `bloom.test.ts` failure.
- [ ] `cd apps/web && npx tsc --noEmit` — expect no errors.
- [ ] `cd apps/web && npm run build` — expect a clean production build with `/reading/part7` statically prerendered alongside `/reading/bilingual`, `/reading/part5`, and `/reading/part6`.
- [ ] Manually walk through the flow in a browser: from `/reading`, pick a topic, pick Part 7, adjust Độ khó, generate — confirm it lands directly in a session with 2 single-document groups (3-4 questions each) then 1 double-document group ("2 văn bản liên quan", exactly 5 questions). Submit and confirm the score matches the total question count (which will vary run to run, e.g. `10/12` or `9/11`) and the per-group breakdown with explanations. Try "🔀 Lấy bài có sẵn" and "Lưu bài". Try navigating directly to `/reading/part7` with no query string and confirm it redirects to `/reading`.
