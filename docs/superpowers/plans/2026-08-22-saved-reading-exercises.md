# Saved Reading Exercises (Đọc & gõ pilot) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users on the `/reading/bilingual` (Đọc & gõ) screen reuse a previously AI-generated passage instead of always waiting on a fresh AI call — via a new "Lấy bài có sẵn" button on setup, loose topic/level/word-count matching against saved exercises, a "Lưu bài" button on the result screen for freshly-generated sessions, and word-priority so AI generation favors vocab not yet covered by any saved exercise.

**Architecture:** New Firestore subcollection `users/{uid}/reading_exercises`, accessed through a new `apps/web/src/lib/savedReadingExercises.ts` (mirrors the existing `vocabRecords.ts`/`topics.ts` access pattern — flat functions over a `collection()`/`doc()` ref, no class/service object). All matching (topic/level/word-count) happens client-side in JS over a single `targetLanguage`-filtered Firestore query, the same "fetch broad, filter/shuffle in JS" pattern `selectSessionWords`/`getVocabRecords` already use elsewhere in this codebase — no composite index needed. `apps/web/src/app/(app)/reading/bilingual/page.tsx` gains a `sessionMode: "generated" | "reused"` state threaded through setup → session → result, which both the new "Lưu bài" button's visibility and "Sinh bài mới"'s replay behavior key off.

**Tech Stack:** Next.js 16 (App Router) on `apps/web/`, React 19, Firebase JS SDK v12 (`firebase/firestore`), Vitest + React Testing Library + jsdom.

## Global Constraints

- All user-facing text is Vietnamese, matching every existing screen.
- Import alias `@/` maps to `apps/web/src/`.
- Every new/changed file gets a colocated Vitest test, following the existing mock style (`vi.mock("firebase/firestore", ...)`, `vi.mock("./firebase", () => ({ getFirebaseDb: vi.fn(() => "mock-db") }))`).
- Word identity (`vocabIds`) is **never** a matching or eligibility criterion for "Lấy bài có sẵn" — only `{topicIds, maxCefr, wordCount}` are compared. See the spec's "Matching semantics" section for the exact loose-match rules.
- "Lấy bài có sẵn" is never gated by the "≥5 matching words" rule — that rule only applies to paths that actually call the AI (the existing "Tạo bài luyện" button, and "Lấy bài có sẵn"'s own AI-fallback when nothing matches).
- No cap or cleanup on saved-exercise count per user in this plan (YAGNI, per spec).
- `selectSessionWords` (`apps/web/src/lib/practiceSession.ts`) is **not modified** in behavior — Ôn tập/Practice must be unaffected. Only its `CEFR_ORDER` constant becomes exported.
- Verify each task with `npm --prefix apps/web test` (full suite) and finish the plan with `npx tsc --noEmit -p apps/web/tsconfig.json` and `npm --prefix apps/web run build`.
- Spec: `docs/superpowers/specs/2026-08-22-saved-reading-exercises-design.md` — read it before starting if anything below is ambiguous, it is the source of truth for intent.

---

## Task 1: `savedReadingExercises.ts` — data layer

**Files:**
- Modify: `apps/web/src/lib/practiceSession.ts` (export `CEFR_ORDER`)
- Modify: `apps/web/src/lib/practiceSession.test.ts` (one new test for the export)
- Create: `apps/web/src/lib/savedReadingExercises.ts`
- Create: `apps/web/src/lib/savedReadingExercises.test.ts`

**Interfaces:**
- Consumes: `ReadingPassage` (`@/lib/readingPassage`, already exists — `{ sentences: BilingualSentence[], vocabIds: string[] }`), `VocabRecord` (`@/lib/vocabRecords`, only `id`/`cefrLevel` fields read), `TargetLanguage` (`@/lib/languages`), `getFirebaseDb` (`@/lib/firebase`).
- Produces (used by Tasks 2-5):
  - `interface SavedExerciseFilters { topicIds: string[]; maxCefr: VocabRecord["cefrLevel"] | null; wordCount: number | null }`
  - `interface SavedReadingExercise { id: string; type: "bilingual"; passage: ReadingPassage; generationFilters: SavedExerciseFilters; targetLanguage: TargetLanguage; createdAt: string }`
  - `saveReadingExercise(uid: string, passage: ReadingPassage, generationFilters: SavedExerciseFilters, targetLanguage: TargetLanguage): Promise<string>`
  - `getRandomSavedExercise(uid: string, targetLanguage: TargetLanguage, filters: SavedExerciseFilters, excludeId?: string): Promise<SavedReadingExercise | null>`
  - `getAllUsedVocabIds(uid: string): Promise<Set<string>>`
  - `prioritizeUnusedWords(words: VocabRecord[], usedVocabIds: Set<string>): VocabRecord[]`
  - `CEFR_ORDER` now exported from `@/lib/practiceSession`.

- [ ] **Step 1: Export `CEFR_ORDER` from `practiceSession.ts`**

In `apps/web/src/lib/practiceSession.ts`, change:

```ts
const CEFR_ORDER: readonly VocabRecord["cefrLevel"][] = ["a1", "a2", "b1", "b2", "c1", "c2"];
```

to:

```ts
export const CEFR_ORDER: readonly VocabRecord["cefrLevel"][] = ["a1", "a2", "b1", "b2", "c1", "c2"];
```

No other change to this file. Add this test to `apps/web/src/lib/practiceSession.test.ts` (add the import alongside the existing one, add the new `describe` block after the existing `selectSessionWords` one):

```ts
import { CEFR_ORDER, selectSessionWords } from "./practiceSession";
```

```ts
describe("CEFR_ORDER", () => {
  it("is exported in ascending difficulty order", () => {
    expect(CEFR_ORDER).toEqual(["a1", "a2", "b1", "b2", "c1", "c2"]);
  });
});
```

- [ ] **Step 2: Run the practiceSession test to confirm it still passes**

Run: `npx vitest run --run apps/web/src/lib/practiceSession.test.ts` (from repo root) or `cd apps/web && npx vitest run --run src/lib/practiceSession.test.ts`
Expected: all tests pass, including the new `CEFR_ORDER` one.

- [ ] **Step 3: Commit**

```bash
git add apps/web/src/lib/practiceSession.ts apps/web/src/lib/practiceSession.test.ts
git commit -m "refactor(web): export CEFR_ORDER from practiceSession.ts"
```

- [ ] **Step 4: Write the failing tests for `savedReadingExercises.ts`**

Create `apps/web/src/lib/savedReadingExercises.test.ts`:

```ts
import { describe, expect, it, vi } from "vitest";
import { collection, doc, getDocs, query, setDoc, where } from "firebase/firestore";
import {
  saveReadingExercise,
  getRandomSavedExercise,
  getAllUsedVocabIds,
  prioritizeUnusedWords,
  type SavedExerciseFilters,
  type SavedReadingExercise,
} from "./savedReadingExercises";
import type { ReadingPassage } from "./readingPassage";
import type { VocabRecord } from "./vocabRecords";

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

const PASSAGE: ReadingPassage = {
  sentences: [{ target: "Hi.", vietnamese: "Chào.", vocabWords: ["hi"] }],
  vocabIds: ["v1", "v2"],
};

function makeSavedExercise(overrides: Partial<SavedReadingExercise> = {}): SavedReadingExercise {
  return {
    id: "ex-1",
    type: "bilingual",
    passage: PASSAGE,
    generationFilters: { topicIds: ["biz"], maxCefr: "b1", wordCount: 10 },
    targetLanguage: "english",
    createdAt: "2026-01-01T00:00:00.000Z",
    ...overrides,
  };
}

describe("saveReadingExercise", () => {
  it("creates a new document carrying its own id field, and returns that id", async () => {
    vi.mocked(doc).mockReturnValue({ id: "new-doc-id" } as never);
    const filters: SavedExerciseFilters = { topicIds: ["biz"], maxCefr: "b1", wordCount: 10 };

    const newId = await saveReadingExercise("user-123", PASSAGE, filters, "english");

    expect(collection).toHaveBeenCalledWith("mock-db", "users", "user-123", "reading_exercises");
    expect(doc).toHaveBeenCalledWith("mock-collection-ref");
    expect(setDoc).toHaveBeenCalledWith(
      { id: "new-doc-id" },
      expect.objectContaining({
        id: "new-doc-id",
        type: "bilingual",
        passage: PASSAGE,
        generationFilters: filters,
        targetLanguage: "english",
        createdAt: expect.any(String),
      })
    );
    expect(newId).toBe("new-doc-id");
  });
});

describe("getRandomSavedExercise", () => {
  it("queries only by targetLanguage, filters everything else client-side", async () => {
    vi.mocked(getDocs).mockResolvedValue({ docs: [] } as never);

    await getRandomSavedExercise("user-123", "english", { topicIds: [], maxCefr: null, wordCount: null });

    expect(where).toHaveBeenCalledWith("targetLanguage", "==", "english");
    expect(query).toHaveBeenCalledWith("mock-collection-ref", "mock-where");
    expect(getDocs).toHaveBeenCalledWith("mock-query");
  });

  it("returns null when there are no candidates", async () => {
    vi.mocked(getDocs).mockResolvedValue({ docs: [] } as never);

    const result = await getRandomSavedExercise("user-123", "english", {
      topicIds: [],
      maxCefr: null,
      wordCount: null,
    });

    expect(result).toBeNull();
  });

  it("matches on topic overlap (at least one shared id), not equality", async () => {
    const ex = makeSavedExercise({ generationFilters: { topicIds: ["biz", "travel"], maxCefr: null, wordCount: null } });
    vi.mocked(getDocs).mockResolvedValue({ docs: [{ id: ex.id, data: () => ex }] } as never);

    const result = await getRandomSavedExercise("user-123", "english", {
      topicIds: ["travel", "food"],
      maxCefr: null,
      wordCount: null,
    });

    expect(result?.id).toBe(ex.id);
  });

  it("does not match when there is no topic overlap", async () => {
    const ex = makeSavedExercise({ generationFilters: { topicIds: ["biz"], maxCefr: null, wordCount: null } });
    vi.mocked(getDocs).mockResolvedValue({ docs: [{ id: ex.id, data: () => ex }] } as never);

    const result = await getRandomSavedExercise("user-123", "english", {
      topicIds: ["travel"],
      maxCefr: null,
      wordCount: null,
    });

    expect(result).toBeNull();
  });

  it("matches anything when the requested topicIds filter is empty", async () => {
    const ex = makeSavedExercise({ generationFilters: { topicIds: ["biz"], maxCefr: null, wordCount: null } });
    vi.mocked(getDocs).mockResolvedValue({ docs: [{ id: ex.id, data: () => ex }] } as never);

    const result = await getRandomSavedExercise("user-123", "english", {
      topicIds: [],
      maxCefr: null,
      wordCount: null,
    });

    expect(result?.id).toBe(ex.id);
  });

  it("matches when the saved exercise's level is at or below the requested max", async () => {
    const ex = makeSavedExercise({ generationFilters: { topicIds: [], maxCefr: "a2", wordCount: null } });
    vi.mocked(getDocs).mockResolvedValue({ docs: [{ id: ex.id, data: () => ex }] } as never);

    const result = await getRandomSavedExercise("user-123", "english", {
      topicIds: [],
      maxCefr: "b1",
      wordCount: null,
    });

    expect(result?.id).toBe(ex.id);
  });

  it("does not match when the saved exercise's level is above the requested max", async () => {
    const ex = makeSavedExercise({ generationFilters: { topicIds: [], maxCefr: "c1", wordCount: null } });
    vi.mocked(getDocs).mockResolvedValue({ docs: [{ id: ex.id, data: () => ex }] } as never);

    const result = await getRandomSavedExercise("user-123", "english", {
      topicIds: [],
      maxCefr: "b1",
      wordCount: null,
    });

    expect(result).toBeNull();
  });

  it("does not match a saved exercise with no level cap when the request has a level cap", async () => {
    const ex = makeSavedExercise({ generationFilters: { topicIds: [], maxCefr: null, wordCount: null } });
    vi.mocked(getDocs).mockResolvedValue({ docs: [{ id: ex.id, data: () => ex }] } as never);

    const result = await getRandomSavedExercise("user-123", "english", {
      topicIds: [],
      maxCefr: "b1",
      wordCount: null,
    });

    expect(result).toBeNull();
  });

  it("matches anything when the requested maxCefr is null, regardless of the saved level", async () => {
    const ex = makeSavedExercise({ generationFilters: { topicIds: [], maxCefr: "c2", wordCount: null } });
    vi.mocked(getDocs).mockResolvedValue({ docs: [{ id: ex.id, data: () => ex }] } as never);

    const result = await getRandomSavedExercise("user-123", "english", {
      topicIds: [],
      maxCefr: null,
      wordCount: null,
    });

    expect(result?.id).toBe(ex.id);
  });

  it("requires exact word count equality, including null-matches-null", async () => {
    const ex10 = makeSavedExercise({ id: "ex-10", generationFilters: { topicIds: [], maxCefr: null, wordCount: 10 } });
    const exAll = makeSavedExercise({ id: "ex-all", generationFilters: { topicIds: [], maxCefr: null, wordCount: null } });
    vi.mocked(getDocs).mockResolvedValue({
      docs: [
        { id: ex10.id, data: () => ex10 },
        { id: exAll.id, data: () => exAll },
      ],
    } as never);

    const result = await getRandomSavedExercise("user-123", "english", { topicIds: [], maxCefr: null, wordCount: null });

    expect(result?.id).toBe("ex-all");
  });

  it("excludes the given excludeId even if it would otherwise match", async () => {
    const ex = makeSavedExercise({ generationFilters: { topicIds: [], maxCefr: null, wordCount: null } });
    vi.mocked(getDocs).mockResolvedValue({ docs: [{ id: ex.id, data: () => ex }] } as never);

    const result = await getRandomSavedExercise(
      "user-123",
      "english",
      { topicIds: [], maxCefr: null, wordCount: null },
      ex.id
    );

    expect(result).toBeNull();
  });

  it("picks randomly among multiple matching candidates", async () => {
    const exA = makeSavedExercise({ id: "ex-a", generationFilters: { topicIds: [], maxCefr: null, wordCount: null } });
    const exB = makeSavedExercise({ id: "ex-b", generationFilters: { topicIds: [], maxCefr: null, wordCount: null } });
    vi.mocked(getDocs).mockResolvedValue({
      docs: [
        { id: exA.id, data: () => exA },
        { id: exB.id, data: () => exB },
      ],
    } as never);
    const randomSpy = vi.spyOn(Math, "random").mockReturnValue(0.99);

    try {
      const result = await getRandomSavedExercise("user-123", "english", {
        topicIds: [],
        maxCefr: null,
        wordCount: null,
      });
      // Math.floor(0.99 * 2) === 1 -> second candidate
      expect(result?.id).toBe("ex-b");
    } finally {
      randomSpy.mockRestore();
    }
  });

  it("uses the real Firestore document id, not any id field inside the document data", async () => {
    const ex = makeSavedExercise({ generationFilters: { topicIds: [], maxCefr: null, wordCount: null } });
    vi.mocked(getDocs).mockResolvedValue({
      docs: [{ id: "real-doc-id", data: () => ({ ...ex, id: "stale-field-id" }) }],
    } as never);

    const result = await getRandomSavedExercise("user-123", "english", {
      topicIds: [],
      maxCefr: null,
      wordCount: null,
    });

    expect(result?.id).toBe("real-doc-id");
  });
});

describe("getAllUsedVocabIds", () => {
  it("unions vocabIds across every saved exercise", async () => {
    const exA = makeSavedExercise({ id: "a", passage: { sentences: [], vocabIds: ["v1", "v2"] } });
    const exB = makeSavedExercise({ id: "b", passage: { sentences: [], vocabIds: ["v2", "v3"] } });
    vi.mocked(getDocs).mockResolvedValue({
      docs: [
        { id: exA.id, data: () => exA },
        { id: exB.id, data: () => exB },
      ],
    } as never);

    const result = await getAllUsedVocabIds("user-123");

    expect(result).toEqual(new Set(["v1", "v2", "v3"]));
  });

  it("returns an empty set when there are no saved exercises", async () => {
    vi.mocked(getDocs).mockResolvedValue({ docs: [] } as never);
    const result = await getAllUsedVocabIds("user-123");
    expect(result).toEqual(new Set());
  });
});

describe("prioritizeUnusedWords", () => {
  it("puts words not in usedVocabIds ahead of words that are, preserving relative order within each group", () => {
    const w1 = makeRecord({ id: "w1" });
    const w2 = makeRecord({ id: "w2" });
    const w3 = makeRecord({ id: "w3" });

    const result = prioritizeUnusedWords([w1, w2, w3], new Set(["w1"]));

    expect(result.map((w) => w.id)).toEqual(["w2", "w3", "w1"]);
  });

  it("returns the same order when nothing has been used", () => {
    const w1 = makeRecord({ id: "w1" });
    const w2 = makeRecord({ id: "w2" });
    const result = prioritizeUnusedWords([w1, w2], new Set());
    expect(result.map((w) => w.id)).toEqual(["w1", "w2"]);
  });
});
```

- [ ] **Step 5: Run the tests to verify they fail**

Run: `cd apps/web && npx vitest run --run src/lib/savedReadingExercises.test.ts`
Expected: FAIL — `savedReadingExercises.ts` does not exist yet.

- [ ] **Step 6: Implement `savedReadingExercises.ts`**

Create `apps/web/src/lib/savedReadingExercises.ts`:

```ts
import { collection, doc, getDocs, query, setDoc, where } from "firebase/firestore";
import { getFirebaseDb } from "./firebase";
import { CEFR_ORDER } from "./practiceSession";
import type { ReadingPassage } from "./readingPassage";
import type { VocabRecord } from "./vocabRecords";
import type { TargetLanguage } from "./languages";

export interface SavedExerciseFilters {
  topicIds: string[];
  maxCefr: VocabRecord["cefrLevel"] | null;
  wordCount: number | null; // null = "Tất cả" was selected at generation time
}

export interface SavedReadingExercise {
  id: string;
  type: "bilingual"; // discriminant for future Part5/6/7/Nghe types
  passage: ReadingPassage;
  generationFilters: SavedExerciseFilters;
  targetLanguage: TargetLanguage;
  createdAt: string;
}

function readingExercisesCol(uid: string) {
  return collection(getFirebaseDb(), "users", uid, "reading_exercises");
}

export async function saveReadingExercise(
  uid: string,
  passage: ReadingPassage,
  generationFilters: SavedExerciseFilters,
  targetLanguage: TargetLanguage
): Promise<string> {
  const ref = doc(readingExercisesCol(uid));
  // Carries its own id field, matching vocabRecords.ts's saveVocabRecord —
  // a doc that only relies on the caller reading ref.id separately breaks
  // any future Flutter Hive-cache sync that reads json['id'] directly.
  const record: Omit<SavedReadingExercise, "id"> = {
    type: "bilingual",
    passage,
    generationFilters,
    targetLanguage,
    createdAt: new Date().toISOString(),
  };
  await setDoc(ref, { ...record, id: ref.id });
  return ref.id;
}

function matchesFilters(exercise: SavedReadingExercise, filters: SavedExerciseFilters): boolean {
  if (filters.topicIds.length > 0) {
    const overlaps = exercise.generationFilters.topicIds.some((id) => filters.topicIds.includes(id));
    if (!overlaps) return false;
  }
  if (filters.maxCefr !== null) {
    if (exercise.generationFilters.maxCefr === null) return false;
    const savedIndex = CEFR_ORDER.indexOf(exercise.generationFilters.maxCefr);
    const maxIndex = CEFR_ORDER.indexOf(filters.maxCefr);
    if (savedIndex > maxIndex) return false;
  }
  if (exercise.generationFilters.wordCount !== filters.wordCount) return false;
  return true;
}

export async function getRandomSavedExercise(
  uid: string,
  targetLanguage: TargetLanguage,
  filters: SavedExerciseFilters,
  excludeId?: string
): Promise<SavedReadingExercise | null> {
  const q = query(readingExercisesCol(uid), where("targetLanguage", "==", targetLanguage));
  const snapshot = await getDocs(q);
  const candidates = snapshot.docs
    .map((d) => ({ ...(d.data() as SavedReadingExercise), id: d.id }))
    .filter((ex) => ex.id !== excludeId && matchesFilters(ex, filters));
  if (candidates.length === 0) return null;
  return candidates[Math.floor(Math.random() * candidates.length)];
}

export async function getAllUsedVocabIds(uid: string): Promise<Set<string>> {
  const snapshot = await getDocs(readingExercisesCol(uid));
  const ids = new Set<string>();
  for (const d of snapshot.docs) {
    const data = d.data() as SavedReadingExercise;
    for (const id of data.passage.vocabIds) ids.add(id);
  }
  return ids;
}

// AI-generation preference, not saved-exercise matching: words never used in
// any saved exercise are preferred over words that have been, so repeated
// generation doesn't keep reusing the same easy-to-match words.
export function prioritizeUnusedWords(words: VocabRecord[], usedVocabIds: Set<string>): VocabRecord[] {
  const unused = words.filter((w) => !usedVocabIds.has(w.id));
  const used = words.filter((w) => usedVocabIds.has(w.id));
  return [...unused, ...used];
}
```

- [ ] **Step 7: Run the tests to verify they pass**

Run: `cd apps/web && npx vitest run --run src/lib/savedReadingExercises.test.ts`
Expected: PASS, all tests green.

- [ ] **Step 8: Typecheck**

Run: `cd apps/web && npx tsc --noEmit`
Expected: no errors.

- [ ] **Step 9: Commit**

```bash
git add apps/web/src/lib/savedReadingExercises.ts apps/web/src/lib/savedReadingExercises.test.ts
git commit -m "feat(web): add savedReadingExercises data layer (save/random-pick/word-priority)"
```

---

## Task 2: Word-priority wiring into AI generation

**Files:**
- Modify: `apps/web/src/app/(app)/reading/bilingual/page.tsx`
- Modify: `apps/web/src/app/(app)/reading/bilingual/page.test.tsx`

**Interfaces:**
- Consumes (from Task 1): `getAllUsedVocabIds(uid): Promise<Set<string>>`, `prioritizeUnusedWords(words, usedVocabIds): VocabRecord[]`, both from `@/lib/savedReadingExercises`.
- Produces: the page's `vi.mock("@/lib/savedReadingExercises", ...)` block in `page.test.tsx`, which Tasks 3-5 extend (do not replace it — add to it).

This task only changes `handleGenerate()`'s word-selection step and adds the corresponding mock/test scaffolding. It does **not** add any new UI, state, or buttons — that starts in Task 3.

- [ ] **Step 1: Add the mock and a safe default to `page.test.tsx`**

In `apps/web/src/app/(app)/reading/bilingual/page.test.tsx`, add this import alongside the existing ones (after the `generateContent` import):

```ts
import { getAllUsedVocabIds } from "@/lib/savedReadingExercises";
```

Add this mock after the existing `vi.mock("@/lib/generateContent", ...)` line:

```ts
vi.mock("@/lib/savedReadingExercises", () => ({
  getAllUsedVocabIds: vi.fn(),
}));
```

Change the existing `beforeEach` block from:

```ts
beforeEach(() => {
  vi.clearAllMocks();
});
```

to:

```ts
beforeEach(() => {
  vi.clearAllMocks();
  vi.mocked(getAllUsedVocabIds).mockResolvedValue(new Set());
});
```

This default (no words used yet) keeps every existing test passing unchanged, since `prioritizeUnusedWords` is a no-op when the used set is empty.

- [ ] **Step 2: Write the new failing test**

Add this test inside the existing `describe("BilingualReadingPage (setup phase)", ...)` block in `page.test.tsx`, after the `"generates a passage from the due-prioritized word list..."` test:

```ts
it("excludes words already used in saved exercises when the word list must be truncated", async () => {
  mockSignedIn();
  const freshRecords = Array.from({ length: 10 }, (_, i) =>
    makeRecord({ id: `fresh-${i}`, headword: `freshword${i}` })
  );
  const usedRecord = makeRecord({ id: "used-1", headword: "usedword" });
  vi.mocked(getVocabRecords).mockResolvedValue([...freshRecords, usedRecord]);
  vi.mocked(getTopics).mockResolvedValue([]);
  vi.mocked(getAllUsedVocabIds).mockResolvedValue(new Set(["used-1"]));
  vi.mocked(generateContent).mockResolvedValue({
    text: JSON.stringify({ sentences: [{ target: "A.", vietnamese: "B.", vocabWords: [] }] }),
  });

  render(<BilingualReadingPage />);
  fireEvent.click(await screen.findByRole("button", { name: "Tạo bài luyện" }));

  await waitFor(() => expect(generateContent).toHaveBeenCalled());
  expect(getAllUsedVocabIds).toHaveBeenCalledWith("u1");
  const promptArg = vi.mocked(generateContent).mock.calls[0][0].prompt;
  // Default word count (10) truncates 11 matching words down to 10 — the
  // 1 used word must be the one dropped, since all 10 fresh ones are
  // prioritized ahead of it.
  expect(promptArg).not.toContain("usedword");
  expect(promptArg).toContain("freshword0");
});
```

- [ ] **Step 3: Run the tests to verify the new one fails**

Run: `cd apps/web && npx vitest run --run "src/app/(app)/reading/bilingual/page.test.tsx"`
Expected: FAIL on the new test — `getAllUsedVocabIds` isn't called yet, so the used word is still present in the prompt (all 11 words currently get truncated to 10 by shuffle order alone, not by usage).

- [ ] **Step 4: Update `handleGenerate()`**

In `apps/web/src/app/(app)/reading/bilingual/page.tsx`, add this import alongside the existing `readingScoring` import:

```ts
import { getAllUsedVocabIds, prioritizeUnusedWords } from "@/lib/savedReadingExercises";
```

Replace the current `handleGenerate` function body with:

```ts
  async function handleGenerate() {
    if (!records || !user || !settings) return;
    const filters: SessionWordFilters = { topicIds: selectedTopicIds, maxCefr, count: null };
    const pool = selectSessionWords(records, filters);
    if (pool.length === 0) return;

    const activeConfig = settings.providers[settings.activeProvider];
    if (!activeConfig.apiKeyCiphertext) {
      setGenerateError("Chưa có API key cho nhà cung cấp AI đang chọn — vào Cài đặt để thêm.");
      return;
    }

    setGenerating(true);
    setGenerateError(null);
    try {
      const usedVocabIds = await getAllUsedVocabIds(user.uid);
      const prioritized = prioritizeUnusedWords(pool, usedVocabIds);
      const words = wordCount === null ? prioritized : prioritized.slice(0, wordCount);
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
      setCurrentIndex(0);
      setTyped("");
      setDeletedChars(0);
      setPeakMistakes(0);
      setSentenceStartedAt(Date.now());
      setCompletedStats([]);
      setPhase("session");
    } catch (err) {
      setGenerateError(err instanceof Error ? err.message : String(err));
    } finally {
      setGenerating(false);
    }
  }
```

Note: `pool.length === 0` replaces the old `words.length === 0` early-return check — same semantics, just checked before truncation now instead of after (the pool being non-empty is equivalent to the old `words` being non-empty, since neither `selectSessionWords` with `count: null` nor `prioritizeUnusedWords`/truncation can turn a non-empty pool into an empty word list).

- [ ] **Step 5: Run the tests to verify they pass**

Run: `cd apps/web && npx vitest run --run "src/app/(app)/reading/bilingual/page.test.tsx"`
Expected: PASS, including the new test.

- [ ] **Step 6: Run the full suite**

Run: `cd apps/web && npm test -- --run`
Expected: all tests pass (some pre-existing vocab-bank pagination tests may show as flaky under full-suite CPU contention — verified pre-existing and unrelated if so; re-run just that file in isolation to confirm).

- [ ] **Step 7: Typecheck**

Run: `cd apps/web && npx tsc --noEmit`
Expected: no errors.

- [ ] **Step 8: Commit**

```bash
git add apps/web/src/app/\(app\)/reading/bilingual/page.tsx apps/web/src/app/\(app\)/reading/bilingual/page.test.tsx
git commit -m "feat(web): prioritize AI-generated word selection toward vocab unused in saved exercises"
```

---

## Task 3: Setup screen — "Lấy bài có sẵn" button

**Files:**
- Modify: `apps/web/src/app/(app)/reading/bilingual/page.tsx`
- Modify: `apps/web/src/app/(app)/reading/bilingual/page.test.tsx`
- Modify: `apps/web/src/styles/bloom.css`

**Interfaces:**
- Consumes (from Task 1): `getRandomSavedExercise`, `SavedExerciseFilters`, `SavedReadingExercise`, all from `@/lib/savedReadingExercises`.
- Produces (used by Tasks 4-5):
  - New page state: `sessionMode: "generated" | "reused"` (default `"generated"`), `justSavedId: string | null` (default `null`), `fetchingSaved: boolean`, `savedNotice: string | null`.
  - New function `fetchSavedExercise(excludeId?: string): Promise<boolean>` — returns `true` if a session was started (either a saved match, or a successful AI fallback) or an error was surfaced; `false` only when nothing matched **and** there weren't enough live words to even attempt the AI fallback. Task 5's "Sinh bài mới" reuses this function directly — do not duplicate its logic.
  - `handleGenerate()` (from Task 2) gains two more lines in its success path: `setSessionMode("generated")` and `setJustSavedId(null)`.

- [ ] **Step 1: Extend the mock in `page.test.tsx`**

Change the `vi.mock("@/lib/savedReadingExercises", ...)` block (added in Task 2) to:

```ts
vi.mock("@/lib/savedReadingExercises", () => ({
  getAllUsedVocabIds: vi.fn(),
  getRandomSavedExercise: vi.fn(),
}));
```

Update the import line to:

```ts
import { getAllUsedVocabIds, getRandomSavedExercise } from "@/lib/savedReadingExercises";
```

Update `beforeEach` to also default `getRandomSavedExercise` to "nothing found" (existing tests never call the new button, but this keeps every mock in a safe default state):

```ts
beforeEach(() => {
  vi.clearAllMocks();
  vi.mocked(getAllUsedVocabIds).mockResolvedValue(new Set());
  vi.mocked(getRandomSavedExercise).mockResolvedValue(null);
});
```

- [ ] **Step 2: Write the failing tests**

Add this fixture near the top of `page.test.tsx`, after the `makeRecord` function:

```ts
import type { SavedReadingExercise } from "@/lib/savedReadingExercises";

const SAVED_EXERCISE: SavedReadingExercise = {
  id: "saved-1",
  type: "bilingual",
  passage: {
    sentences: [{ target: "Saved sentence.", vietnamese: "Câu đã lưu.", vocabWords: [] }],
    vocabIds: [],
  },
  generationFilters: { topicIds: [], maxCefr: null, wordCount: null },
  targetLanguage: "english",
  createdAt: "2026-01-01T00:00:00.000Z",
};
```

Add these tests inside `describe("BilingualReadingPage (setup phase)", ...)`, after the existing "shows an error and stays on setup when the AI returns no usable sentences" test:

```ts
it('"Lấy bài có sẵn" starts a session directly from a matching saved exercise, without calling the AI', async () => {
  mockSignedIn();
  vi.mocked(getVocabRecords).mockResolvedValue(
    Array.from({ length: 5 }, (_, i) => makeRecord({ id: `w${i}`, headword: `word${i}` }))
  );
  vi.mocked(getTopics).mockResolvedValue([]);
  vi.mocked(getRandomSavedExercise).mockResolvedValue(SAVED_EXERCISE);

  render(<BilingualReadingPage />);
  fireEvent.click(await screen.findByRole("button", { name: "🔀 Lấy bài có sẵn" }));

  expect(await screen.findByText("Câu 1 / 1")).toBeInTheDocument();
  expect(screen.getByText("Câu đã lưu.")).toBeInTheDocument();
  expect(generateContent).not.toHaveBeenCalled();
});

it('"Lấy bài có sẵn" shows an inline notice and falls back to AI generation when nothing matches', async () => {
  mockSignedIn();
  vi.mocked(getVocabRecords).mockResolvedValue(
    Array.from({ length: 5 }, (_, i) => makeRecord({ id: `w${i}`, headword: `word${i}` }))
  );
  vi.mocked(getTopics).mockResolvedValue([]);
  vi.mocked(getRandomSavedExercise).mockResolvedValue(null);
  vi.mocked(generateContent).mockResolvedValue({
    text: JSON.stringify({ sentences: [{ target: "A.", vietnamese: "B.", vocabWords: [] }] }),
  });

  render(<BilingualReadingPage />);
  fireEvent.click(await screen.findByRole("button", { name: "🔀 Lấy bài có sẵn" }));

  expect(
    await screen.findByText("Chưa có bài đã lưu khớp bộ lọc này — đang tạo bài mới bằng AI…")
  ).toBeInTheDocument();
  await waitFor(() => expect(generateContent).toHaveBeenCalled());
});

it('"Lấy bài có sẵn" does not attempt an AI fallback when there are not enough live words', async () => {
  mockSignedIn();
  vi.mocked(getVocabRecords).mockResolvedValue([makeRecord({ id: "1" }), makeRecord({ id: "2" })]);
  vi.mocked(getTopics).mockResolvedValue([]);
  vi.mocked(getRandomSavedExercise).mockResolvedValue(null);

  render(<BilingualReadingPage />);
  fireEvent.click(await screen.findByRole("button", { name: "🔀 Lấy bài có sẵn" }));

  await waitFor(() => expect(getRandomSavedExercise).toHaveBeenCalled());
  expect(generateContent).not.toHaveBeenCalled();
  expect(
    screen.queryByText("Chưa có bài đã lưu khớp bộ lọc này — đang tạo bài mới bằng AI…")
  ).not.toBeInTheDocument();
});

it('"Lấy bài có sẵn" is enabled even when fewer than 5 words match (unlike "Tạo bài luyện")', async () => {
  mockSignedIn();
  vi.mocked(getVocabRecords).mockResolvedValue([makeRecord({ id: "1" }), makeRecord({ id: "2" })]);
  vi.mocked(getTopics).mockResolvedValue([]);

  render(<BilingualReadingPage />);

  expect(await screen.findByRole("button", { name: "🔀 Lấy bài có sẵn" })).not.toBeDisabled();
  expect(screen.queryByRole("button", { name: "Tạo bài luyện" })).not.toBeInTheDocument();
});
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `cd apps/web && npx vitest run --run "src/app/(app)/reading/bilingual/page.test.tsx"`
Expected: FAIL — the "🔀 Lấy bài có sẵn" button doesn't exist yet.

- [ ] **Step 4: Add the new state, import, and `fetchSavedExercise`/`handleGetSaved` functions**

In `apps/web/src/app/(app)/reading/bilingual/page.tsx`, update the import from Task 2:

```ts
import {
  getAllUsedVocabIds,
  getRandomSavedExercise,
  prioritizeUnusedWords,
  type SavedExerciseFilters,
} from "@/lib/savedReadingExercises";
```

Add these state declarations right after the existing `completedStats` one:

```ts
  const [sessionMode, setSessionMode] = useState<"generated" | "reused">("generated");
  const [justSavedId, setJustSavedId] = useState<string | null>(null);
  const [fetchingSaved, setFetchingSaved] = useState(false);
  const [savedNotice, setSavedNotice] = useState<string | null>(null);
```

Replace `handleGenerate` (from Task 2) with this version — identical except for the two new lines marked below:

```ts
  async function handleGenerate() {
    if (!records || !user || !settings) return;
    const filters: SessionWordFilters = { topicIds: selectedTopicIds, maxCefr, count: null };
    const pool = selectSessionWords(records, filters);
    if (pool.length === 0) return;

    const activeConfig = settings.providers[settings.activeProvider];
    if (!activeConfig.apiKeyCiphertext) {
      setGenerateError("Chưa có API key cho nhà cung cấp AI đang chọn — vào Cài đặt để thêm.");
      return;
    }

    setGenerating(true);
    setGenerateError(null);
    try {
      const usedVocabIds = await getAllUsedVocabIds(user.uid);
      const prioritized = prioritizeUnusedWords(pool, usedVocabIds);
      const words = wordCount === null ? prioritized : prioritized.slice(0, wordCount);
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
      setSessionMode("generated"); // new
      setJustSavedId(null); // new
      setPassage(generated);
      setCurrentIndex(0);
      setTyped("");
      setDeletedChars(0);
      setPeakMistakes(0);
      setSentenceStartedAt(Date.now());
      setCompletedStats([]);
      setPhase("session");
    } catch (err) {
      setGenerateError(err instanceof Error ? err.message : String(err));
    } finally {
      setGenerating(false);
    }
  }
```

Add these two new functions right after `handleGenerate`:

```ts
  // Returns true if a session was started (saved match, or a successful AI
  // fallback) or an error was surfaced to the user; false only when nothing
  // matched AND there weren't even enough live words to attempt the AI
  // fallback — the caller decides what "false" means for it (Task 5 resets
  // to setup in that case; Task 3's own handleGetSaved has nothing further
  // to do, the existing min-words hint is already visible on this screen).
  async function fetchSavedExercise(excludeId?: string): Promise<boolean> {
    if (!records || !user || !settings) return false;
    const matchingCount = selectSessionWords(records, {
      topicIds: selectedTopicIds,
      maxCefr,
      count: null,
    }).length;
    setGenerateError(null);
    setSavedNotice(null);
    setFetchingSaved(true);
    let found = false;
    try {
      const filters: SavedExerciseFilters = { topicIds: [...selectedTopicIds], maxCefr, wordCount };
      const saved = await getRandomSavedExercise(user.uid, settings.targetLanguage, filters, excludeId);
      if (saved) {
        found = true;
        setSessionMode("reused");
        setJustSavedId(null);
        setPassage(saved.passage);
        setCurrentIndex(0);
        setTyped("");
        setDeletedChars(0);
        setPeakMistakes(0);
        setSentenceStartedAt(Date.now());
        setCompletedStats([]);
        setPhase("session");
      } else if (matchingCount >= MIN_VOCAB_WORDS) {
        setSavedNotice("Chưa có bài đã lưu khớp bộ lọc này — đang tạo bài mới bằng AI…");
      }
    } catch (err) {
      setGenerateError(err instanceof Error ? err.message : String(err));
      return true;
    } finally {
      setFetchingSaved(false);
    }
    if (!found && matchingCount >= MIN_VOCAB_WORDS) {
      await handleGenerate();
      return true;
    }
    return found;
  }

  async function handleGetSaved() {
    await fetchSavedExercise();
  }
```

- [ ] **Step 5: Update the setup-phase JSX**

Replace the setup-phase `return (...)` block (inside `if (phase === "setup") { ... }`) with:

```tsx
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
        <div className="reading-setup-actions">
          {canGenerate ? (
            <button
              className="btn-primary"
              onClick={() => void handleGenerate()}
              disabled={generating || fetchingSaved}
            >
              {generating ? "Đang tạo bài…" : "Tạo bài luyện"}
            </button>
          ) : (
            <p className="reading-min-words-hint">
              Hãy lưu ít nhất {MIN_VOCAB_WORDS} từ khớp với bộ lọc trên vào Ngân hàng từ vựng. Hiện có{" "}
              {matchingCount} từ.
            </p>
          )}
          <button
            type="button"
            className="btn-secondary"
            onClick={() => void handleGetSaved()}
            disabled={generating || fetchingSaved}
          >
            {fetchingSaved ? "Đang tìm bài…" : "🔀 Lấy bài có sẵn"}
          </button>
        </div>
        {savedNotice && <p className="reading-saved-notice">{savedNotice}</p>}
        {generateError && <p role="alert">{generateError}</p>}
      </div>
    );
```

(The `matchingCount`/`canGenerate` `const`s right above this block, at the top of `if (phase === "setup") { ... }`, are unchanged from before this task.)

- [ ] **Step 6: Add CSS for the new elements**

In `apps/web/src/styles/bloom.css`, find `.reading-min-words-hint` and add these two new rules right after it:

```css
.reading-setup-actions {
  display: flex;
  align-items: center;
  gap: 12px;
  flex-wrap: wrap;
}

.reading-saved-notice {
  color: var(--ink-soft);
  font-size: 17px;
  margin: 10px 0 0;
}
```

- [ ] **Step 7: Run the tests to verify they pass**

Run: `cd apps/web && npx vitest run --run "src/app/(app)/reading/bilingual/page.test.tsx"`
Expected: PASS, including all 4 new tests.

- [ ] **Step 8: Run the full suite**

Run: `cd apps/web && npm test -- --run`
Expected: all tests pass.

- [ ] **Step 9: Typecheck**

Run: `cd apps/web && npx tsc --noEmit`
Expected: no errors.

- [ ] **Step 10: Commit**

```bash
git add apps/web/src/app/\(app\)/reading/bilingual/page.tsx apps/web/src/app/\(app\)/reading/bilingual/page.test.tsx apps/web/src/styles/bloom.css
git commit -m "feat(web): add \"Lấy bài có sẵn\" button for reusing a saved reading exercise"
```

---

## Task 4: Result screen — "Lưu bài" button and conditional vocab suggestions

**Files:**
- Modify: `apps/web/src/app/(app)/reading/bilingual/page.tsx`
- Modify: `apps/web/src/app/(app)/reading/bilingual/page.test.tsx`
- Modify: `apps/web/src/styles/bloom.css`

**Interfaces:**
- Consumes (from Task 1): `saveReadingExercise` from `@/lib/savedReadingExercises`.
- Consumes (from Task 3): `sessionMode`, `justSavedId`/`setJustSavedId`, `selectedTopicIds`, `maxCefr`, `wordCount` page state.
- Produces (used by Task 5): the result screen's `.reading-result-actions` row now conditionally includes the save control — Task 5 only touches the "Sinh bài mới" button within that same row, not the save control.

- [ ] **Step 1: Extend the mock in `page.test.tsx`**

Change the `vi.mock("@/lib/savedReadingExercises", ...)` block to:

```ts
vi.mock("@/lib/savedReadingExercises", () => ({
  getAllUsedVocabIds: vi.fn(),
  getRandomSavedExercise: vi.fn(),
  saveReadingExercise: vi.fn(),
}));
```

Update the import line to:

```ts
import { getAllUsedVocabIds, getRandomSavedExercise, saveReadingExercise } from "@/lib/savedReadingExercises";
```

- [ ] **Step 2: Write the failing tests**

Add these tests inside `describe("BilingualReadingPage (result phase)", ...)`, after the existing `"shows 4 stat cards, the vocab words used, and the suggestions section"` test:

```ts
it('shows a "Lưu bài" button for a freshly AI-generated session, and hides it once saved', async () => {
  mockSignedIn();
  vi.mocked(getVocabRecords).mockResolvedValue(
    Array.from({ length: 5 }, (_, i) => makeRecord({ id: `w${i}`, headword: `word${i}` }))
  );
  vi.mocked(getTopics).mockResolvedValue([]);
  vi.mocked(saveReadingExercise).mockResolvedValue("new-saved-id");

  await completeASession();

  const saveButton = screen.getByRole("button", { name: "Lưu bài" });
  fireEvent.click(saveButton);

  expect(await screen.findByText("Đã lưu ✔")).toBeInTheDocument();
  expect(screen.queryByRole("button", { name: "Lưu bài" })).not.toBeInTheDocument();
  expect(saveReadingExercise).toHaveBeenCalledWith(
    "u1",
    expect.objectContaining({ sentences: expect.any(Array) }),
    expect.objectContaining({ topicIds: [], maxCefr: null, wordCount: 10 }),
    "english"
  );
});

it('surfaces a save error via role="alert" and keeps the "Lưu bài" button available to retry', async () => {
  mockSignedIn();
  vi.mocked(getVocabRecords).mockResolvedValue(
    Array.from({ length: 5 }, (_, i) => makeRecord({ id: `w${i}`, headword: `word${i}` }))
  );
  vi.mocked(getTopics).mockResolvedValue([]);
  vi.mocked(saveReadingExercise).mockRejectedValue(new Error("network down"));

  await completeASession();
  fireEvent.click(screen.getByRole("button", { name: "Lưu bài" }));

  expect(await screen.findByText("network down")).toBeInTheDocument();
  expect(screen.getByRole("button", { name: "Lưu bài" })).toBeInTheDocument();
});

it('hides both "Lưu bài" and the vocab-suggestions section for a reused session', async () => {
  mockSignedIn();
  vi.mocked(getVocabRecords).mockResolvedValue(
    Array.from({ length: 5 }, (_, i) => makeRecord({ id: `w${i}`, headword: `word${i}` }))
  );
  vi.mocked(getTopics).mockResolvedValue([]);
  vi.mocked(getRandomSavedExercise).mockResolvedValue({
    id: "saved-1",
    type: "bilingual",
    passage: { sentences: [{ target: "Hi.", vietnamese: "Chào.", vocabWords: [] }], vocabIds: [] },
    generationFilters: { topicIds: [], maxCefr: null, wordCount: null },
    targetLanguage: "english",
    createdAt: "2026-01-01T00:00:00.000Z",
  });

  render(<BilingualReadingPage />);
  fireEvent.click(await screen.findByRole("button", { name: "🔀 Lấy bài có sẵn" }));
  await screen.findByText("Câu 1 / 1");
  fireEvent.change(screen.getByTestId("reading-type-input"), { target: { value: "Hi." } });
  await waitFor(() => expect(screen.queryByTestId("reading-type-input")).not.toBeInTheDocument());

  expect(screen.queryByRole("button", { name: "Lưu bài" })).not.toBeInTheDocument();
  expect(screen.queryByTestId("vocab-suggestions")).not.toBeInTheDocument();
});
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `cd apps/web && npx vitest run --run "src/app/(app)/reading/bilingual/page.test.tsx"`
Expected: FAIL — no "Lưu bài" button exists yet, and `VocabSuggestionsSection` always renders regardless of `sessionMode`.

- [ ] **Step 4: Add save state, `handleSaveExercise`, and the CSS**

In `apps/web/src/app/(app)/reading/bilingual/page.tsx`, update the Task 3 import to add `saveReadingExercise`:

```ts
import {
  getAllUsedVocabIds,
  getRandomSavedExercise,
  saveReadingExercise,
  prioritizeUnusedWords,
  type SavedExerciseFilters,
} from "@/lib/savedReadingExercises";
```

Add these two state declarations right after `savedNotice` (from Task 3):

```ts
  const [saving, setSaving] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);
```

Add this function right after `handleGetSaved` (from Task 3):

```ts
  async function handleSaveExercise() {
    if (saving || !user || !settings || !passage) return;
    setSaving(true);
    setSaveError(null);
    try {
      const generationFilters: SavedExerciseFilters = {
        topicIds: [...selectedTopicIds],
        maxCefr,
        wordCount,
      };
      const newId = await saveReadingExercise(user.uid, passage, generationFilters, settings.targetLanguage);
      setJustSavedId(newId);
    } catch (err) {
      setSaveError(err instanceof Error ? err.message : String(err));
    } finally {
      setSaving(false);
    }
  }
```

In `apps/web/src/styles/bloom.css`, add this rule right after `.reading-saved-notice` (from Task 3):

```css
.reading-saved-mark {
  color: var(--success);
  font-weight: 700;
  align-self: center;
}
```

- [ ] **Step 5: Update the result-phase JSX**

Replace the current result-phase `return (...)` block with:

```tsx
  return (
    <div>
      <h2 className="scr-title">Kết quả</h2>
      <div className="reading-result-row">
        <div className="reading-result-left">
          <div className="reading-result-stats">
            <div className="reading-stat-card">
              <span className="reading-stat-label">Độ chính xác</span>
              <span className="reading-stat-value">{Math.round(stats.typingAccuracy * 100)}%</span>
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
        </div>
        <PassageReview sentences={passage?.sentences ?? []} />
      </div>
      {sessionMode === "generated" && (
        <VocabSuggestionsSection text={fullText} existingRecords={records ?? []} topics={topics} />
      )}
      <div className="reading-result-actions">
        {sessionMode === "generated" &&
          (justSavedId ? (
            <span className="reading-saved-mark">Đã lưu ✔</span>
          ) : (
            <button
              type="button"
              className="btn-secondary"
              onClick={() => void handleSaveExercise()}
              disabled={saving}
            >
              {saving ? "Đang lưu…" : "Lưu bài"}
            </button>
          ))}
        <button type="button" className="btn-secondary" onClick={() => router.push("/reading")}>
          Về trang chính
        </button>
        <button type="button" className="btn-primary" onClick={handleNewPassage}>
          Sinh bài mới
        </button>
      </div>
      {saveError && <p role="alert">{saveError}</p>}
    </div>
  );
```

`handleNewPassage` is unchanged in this task — Task 5 replaces it.

- [ ] **Step 6: Run the tests to verify they pass**

Run: `cd apps/web && npx vitest run --run "src/app/(app)/reading/bilingual/page.test.tsx"`
Expected: PASS, including all 3 new tests.

- [ ] **Step 7: Run the full suite**

Run: `cd apps/web && npm test -- --run`
Expected: all tests pass.

- [ ] **Step 8: Typecheck**

Run: `cd apps/web && npx tsc --noEmit`
Expected: no errors.

- [ ] **Step 9: Commit**

```bash
git add apps/web/src/app/\(app\)/reading/bilingual/page.tsx apps/web/src/app/\(app\)/reading/bilingual/page.test.tsx apps/web/src/styles/bloom.css
git commit -m "feat(web): add \"Lưu bài\" save button, hide vocab suggestions for reused sessions"
```

---

## Task 5: "Sinh bài mới" replays the session's original mode

**Files:**
- Modify: `apps/web/src/app/(app)/reading/bilingual/page.tsx`
- Modify: `apps/web/src/app/(app)/reading/bilingual/page.test.tsx`

**Interfaces:**
- Consumes (from Task 3): `fetchSavedExercise(excludeId?: string): Promise<boolean>`, `sessionMode`, `justSavedId`, `handleGenerate()`.
- Produces: `handleNewSession()` replaces `handleNewPassage()` as the result screen's "Sinh bài mới" `onClick` handler. `resetToSetup()` is the new name for what `handleNewPassage`'s body used to do unconditionally — now only called as a fallback when neither a saved match nor an AI attempt was possible.

This is a deliberate **behavior change** from what's currently shipped: today "Sinh bài mới" always returns to the setup phase. Per the spec, it must instead replay whichever mode (`"generated"` vs `"reused"`) the finished session started in, without returning to setup — see `docs/superpowers/specs/2026-08-22-saved-reading-exercises-design.md`'s "UI — result screen" section for the full rationale. This is intentional, not a regression of the prior plan's own reviewed behavior.

- [ ] **Step 1: Update the existing "Sinh bài mới" test**

The current test `'"Sinh bài mới" resets and returns to the setup phase with filters still selected'` in `page.test.tsx` (inside `describe("BilingualReadingPage (result phase)", ...)`) asserts the *old* behavior. Replace it with:

```ts
it('"Sinh bài mới" replays AI-generation directly (no return to setup) for a "generated" session', async () => {
  mockSignedIn();
  vi.mocked(getVocabRecords).mockResolvedValue(
    Array.from({ length: 5 }, (_, i) => makeRecord({ id: `w${i}`, headword: `word${i}` }))
  );
  vi.mocked(getTopics).mockResolvedValue([]);

  await completeASession();
  vi.mocked(generateContent).mockResolvedValue({
    text: JSON.stringify({ sentences: [{ target: "New one.", vietnamese: "Bài mới.", vocabWords: [] }] }),
  });

  fireEvent.click(screen.getByRole("button", { name: "Sinh bài mới" }));

  expect(await screen.findByText("Câu 1 / 1")).toBeInTheDocument();
  expect(screen.queryByRole("button", { name: "Tạo bài luyện" })).not.toBeInTheDocument();
});

it('"Sinh bài mới" falls back to the setup phase for a "reused" session when nothing else matches and there are not enough live words for an AI attempt either', async () => {
  // Note: this exercises the "reused" branch, not "generated" — unlike
  // "Tạo bài luyện", "Lấy bài có sẵn" is never gated by the 5-word rule
  // (Task 3), so a session can legitimately start in "reused" mode with
  // fewer than 5 live matching words. There's no equivalent test for a
  // "generated" session running low on words mid-visit: `records` is
  // fetched once on mount and never refetched by this page, so a
  // "generated" session's own word count can't actually change between
  // finishing the session and clicking "Sinh bài mới" within one visit —
  // handleNewSession's `else { resetToSetup(); }` branch for the
  // "generated" case is intentionally defensive/currently-unreachable
  // code, not something to force a test around.
  mockSignedIn();
  vi.mocked(getVocabRecords).mockResolvedValue([makeRecord({ id: "1" }), makeRecord({ id: "2" })]);
  vi.mocked(getTopics).mockResolvedValue([]);
  vi.mocked(getRandomSavedExercise).mockResolvedValue({
    id: "saved-1",
    type: "bilingual",
    passage: { sentences: [{ target: "Hi.", vietnamese: "Chào.", vocabWords: [] }], vocabIds: [] },
    generationFilters: { topicIds: [], maxCefr: null, wordCount: null },
    targetLanguage: "english",
    createdAt: "2026-01-01T00:00:00.000Z",
  });

  render(<BilingualReadingPage />);
  fireEvent.click(await screen.findByRole("button", { name: "🔀 Lấy bài có sẵn" }));
  await screen.findByText("Câu 1 / 1");
  fireEvent.change(screen.getByTestId("reading-type-input"), { target: { value: "Hi." } });
  await waitFor(() => expect(screen.queryByTestId("reading-type-input")).not.toBeInTheDocument());

  vi.mocked(getRandomSavedExercise).mockResolvedValue(null);

  fireEvent.click(screen.getByRole("button", { name: "Sinh bài mới" }));

  expect(await screen.findByRole("button", { name: "🔀 Lấy bài có sẵn" })).toBeInTheDocument();
  expect(screen.queryByRole("button", { name: "Tạo bài luyện" })).not.toBeInTheDocument();
  expect(generateContent).not.toHaveBeenCalled();
});
```

Add these new tests after them, in the same `describe` block:

```ts
it('"Sinh bài mới" fetches another saved exercise directly for a "reused" session (no exclusion, since reused sessions have no "Lưu bài" button to set justSavedId)', async () => {
  // The spec's "exclude the just-saved exercise from the next random pick"
  // requirement is implemented in fetchSavedExercise's excludeId param
  // (unit-tested directly in Task 1's getRandomSavedExercise tests) and
  // wired here as `justSavedId ?? undefined`. In practice `justSavedId` can
  // only become non-null via "Lưu bài" (Task 4), which only renders for
  // `sessionMode === "generated"` — and a "generated" session's own "Sinh
  // bài mới" always re-runs handleGenerate() directly, never a random pick
  // (see the note on the "generated"-insufficient-words test above). So
  // this exact exclusion never actually fires within a single page visit
  // under the current design; this test documents that reality rather than
  // asserting a false claim about it triggering.
  mockSignedIn();
  vi.mocked(getVocabRecords).mockResolvedValue(
    Array.from({ length: 5 }, (_, i) => makeRecord({ id: `w${i}`, headword: `word${i}` }))
  );
  vi.mocked(getTopics).mockResolvedValue([]);
  const FIRST_SAVED = {
    id: "saved-1",
    type: "bilingual" as const,
    passage: { sentences: [{ target: "First.", vietnamese: "Đầu.", vocabWords: [] }], vocabIds: [] },
    generationFilters: { topicIds: [], maxCefr: null, wordCount: null },
    targetLanguage: "english" as const,
    createdAt: "2026-01-01T00:00:00.000Z",
  };
  vi.mocked(getRandomSavedExercise).mockResolvedValue(FIRST_SAVED);

  render(<BilingualReadingPage />);
  fireEvent.click(await screen.findByRole("button", { name: "🔀 Lấy bài có sẵn" }));
  await screen.findByText("Câu 1 / 1");
  fireEvent.change(screen.getByTestId("reading-type-input"), { target: { value: "First." } });
  await waitFor(() => expect(screen.queryByTestId("reading-type-input")).not.toBeInTheDocument());

  expect(screen.queryByRole("button", { name: "Lưu bài" })).not.toBeInTheDocument();

  const SECOND_SAVED = {
    ...FIRST_SAVED,
    id: "saved-2",
    passage: { sentences: [{ target: "Second.", vietnamese: "Hai.", vocabWords: [] }], vocabIds: [] },
  };
  vi.mocked(getRandomSavedExercise).mockResolvedValue(SECOND_SAVED);

  fireEvent.click(screen.getByRole("button", { name: "Sinh bài mới" }));

  expect(await screen.findByText("Câu 1 / 1")).toBeInTheDocument();
  expect(screen.getByText("Second.")).toBeInTheDocument();
  expect(vi.mocked(getRandomSavedExercise).mock.calls[1][3]).toBeUndefined();
});

it('"Sinh bài mới" falls back to AI with the inline notice when a "reused" session finds no other saved match', async () => {
  mockSignedIn();
  vi.mocked(getVocabRecords).mockResolvedValue(
    Array.from({ length: 5 }, (_, i) => makeRecord({ id: `w${i}`, headword: `word${i}` }))
  );
  vi.mocked(getTopics).mockResolvedValue([]);
  vi.mocked(getRandomSavedExercise).mockResolvedValue({
    id: "saved-1",
    type: "bilingual",
    passage: { sentences: [{ target: "First.", vietnamese: "Đầu.", vocabWords: [] }], vocabIds: [] },
    generationFilters: { topicIds: [], maxCefr: null, wordCount: null },
    targetLanguage: "english",
    createdAt: "2026-01-01T00:00:00.000Z",
  });

  render(<BilingualReadingPage />);
  fireEvent.click(await screen.findByRole("button", { name: "🔀 Lấy bài có sẵn" }));
  await screen.findByText("Câu 1 / 1");
  fireEvent.change(screen.getByTestId("reading-type-input"), { target: { value: "First." } });
  await waitFor(() => expect(screen.queryByTestId("reading-type-input")).not.toBeInTheDocument());

  vi.mocked(getRandomSavedExercise).mockResolvedValue(null);
  vi.mocked(generateContent).mockResolvedValue({
    text: JSON.stringify({ sentences: [{ target: "AI made.", vietnamese: "AI tạo.", vocabWords: [] }] }),
  });

  fireEvent.click(screen.getByRole("button", { name: "Sinh bài mới" }));

  expect(
    await screen.findByText("Chưa có bài đã lưu khớp bộ lọc này — đang tạo bài mới bằng AI…")
  ).toBeInTheDocument();
  await waitFor(() => expect(screen.getByText("AI tạo.")).toBeInTheDocument());
});
```

- [ ] **Step 2: Run the tests to verify the new/changed ones fail**

Run: `cd apps/web && npx vitest run --run "src/app/(app)/reading/bilingual/page.test.tsx"`
Expected: FAIL — "Sinh bài mới" still calls the old `handleNewPassage`, which always resets to setup regardless of `sessionMode`.

- [ ] **Step 3: Replace `handleNewPassage` with `handleNewSession` and `resetToSetup`**

In `apps/web/src/app/(app)/reading/bilingual/page.tsx`, replace the existing `handleNewPassage` function with:

```ts
  function resetToSetup() {
    setPassage(null);
    setCurrentIndex(0);
    setTyped("");
    setDeletedChars(0);
    setPeakMistakes(0);
    setCompletedStats([]);
    setGenerateError(null);
    setSavedNotice(null);
    setJustSavedId(null);
    setPhase("setup");
  }

  async function handleNewSession() {
    if (sessionMode === "reused") {
      const handled = await fetchSavedExercise(justSavedId ?? undefined);
      if (!handled) resetToSetup();
      return;
    }
    const matchingCount = records
      ? selectSessionWords(records, { topicIds: selectedTopicIds, maxCefr, count: null }).length
      : 0;
    if (matchingCount >= MIN_VOCAB_WORDS) {
      await handleGenerate();
    } else {
      resetToSetup();
    }
  }
```

- [ ] **Step 4: Update the "Sinh bài mới" button's `onClick`**

In the result-phase JSX (inside `.reading-result-actions`), change:

```tsx
        <button type="button" className="btn-primary" onClick={handleNewPassage}>
          Sinh bài mới
        </button>
```

to:

```tsx
        <button type="button" className="btn-primary" onClick={() => void handleNewSession()}>
          Sinh bài mới
        </button>
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `cd apps/web && npx vitest run --run "src/app/(app)/reading/bilingual/page.test.tsx"`
Expected: PASS, including all updated/new tests.

- [ ] **Step 6: Run the full suite**

Run: `cd apps/web && npm test -- --run`
Expected: all tests pass.

- [ ] **Step 7: Typecheck and build**

Run: `cd apps/web && npx tsc --noEmit && npm run build`
Expected: no errors, build succeeds.

- [ ] **Step 8: Verify Firestore security rules cover the new subcollection**

Sign in as the test user in a local/dev environment, save a reading exercise via the UI, and confirm the write succeeds and a subsequent "Lấy bài có sẵn" read succeeds (per the spec's note: rules are Console-managed, not in this repo — `vocab_records`/`topics` already work as sibling `users/{uid}` subcollections, `reading_exercises` is expected to inherit the same per-owner rule automatically, but this should be confirmed manually rather than assumed).

- [ ] **Step 9: Commit**

```bash
git add apps/web/src/app/\(app\)/reading/bilingual/page.tsx apps/web/src/app/\(app\)/reading/bilingual/page.test.tsx
git commit -m "feat(web): \"Sinh bài mới\" replays the session's original mode instead of resetting to setup"
```

---

## Final verification (after all 5 tasks)

- [ ] Run the full suite once more: `cd apps/web && npm test -- --run` — expect all tests green.
- [ ] `cd apps/web && npx tsc --noEmit` — expect no errors.
- [ ] `cd apps/web && npm run build` — expect a clean production build.
- [ ] Manually walk through both flows in a browser: generate + save an exercise, then use "Lấy bài có sẵn" to fetch it back; confirm the "Gợi ý từ mới" section and "Lưu bài" button are absent on the reused result screen; confirm "Sinh bài mới" replays the correct mode in both directions.
