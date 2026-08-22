# Reading Hub / Setup Merge Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Collapse `/reading`'s hub and each mode's separate setup screen into one screen: pick "Chủ đề" (topic, from the Vocab Bank, shared by every mode) once, pick which mode to practice, adjust that mode's own secondary filter, then generate or reuse — no navigation until the session actually starts.

**Architecture:** Part 5's "Chủ đề" filter changes from a fixed 8-value enum to real Vocab Bank topics (Task 1) so it's genuinely the same filter Đọc & gõ already uses — this is a breaking-signature migration of already-shipped, reviewed code, done first and in isolation. The hub (`/reading`) becomes the single setup surface (Task 2): a shared `TopicFilterPopover`, a mode picker, each mode's own secondary filter revealed once picked, and two action buttons that navigate to `/reading/bilingual` or `/reading/part5` with the chosen filters and action encoded as query params. Both destination pages (Tasks 3-4) lose their own setup phase, read query params via `useSearchParams()` on mount (wrapped in `<Suspense>`, required by this Next.js version for a static page using that hook), and immediately run the requested action.

**Tech Stack:** Next.js 16 (App Router) on `apps/web/`, React 19, Firebase JS SDK v12, Vitest + React Testing Library + jsdom.

## Global Constraints

- All user-facing text is Vietnamese, matching every existing screen.
- Import alias `@/` maps to `apps/web/src/`.
- Every changed file's tests are updated to match; every new file gets a colocated Vitest test.
- Neither "Tạo bài luyện" nor Part 5's "🔀 Lấy bài có sẵn" gains a word-count gate it didn't already have; Đọc & gõ's existing ≥5-word gate on "Tạo bài luyện" (never on "Lấy bài có sẵn") moves to the hub unchanged in behavior.
- No mode is selected by default when the hub loads.
- Removing a page's setup phase must not remove its only path to user-visible feedback on failure — every task that removes a setup screen adds an explicit retry/back-to-hub affordance for the states that used to be visible on that now-removed screen (see Task 3/4's "loading phase" JSX).
- A static page calling `useSearchParams()` must be wrapped in `<Suspense>` in this Next.js version, or `npm run build` fails with a missing-Suspense-boundary error — confirmed against `node_modules/next/dist/docs/01-app/03-api-reference/04-functions/use-search-params.md`. Keep the wrapped/inner-component split inside the same file (matches this codebase's one-file-per-page convention) rather than splitting into a separate file.
- Verify each task with `npm --prefix apps/web test` (full suite) and finish the plan with `npx tsc --noEmit -p apps/web/tsconfig.json` and `npm --prefix apps/web run build`.
- Spec: `docs/superpowers/specs/2026-08-22-reading-hub-setup-merge-design.md` — read it if anything below is ambiguous.

---

## Task 1: Migrate Part 5's "Chủ đề" from a fixed enum to real Vocab Bank topics

**Files:**
- Modify: `apps/web/src/lib/savedReadingExercises.ts`
- Modify: `apps/web/src/lib/savedReadingExercises.test.ts`
- Modify: `apps/web/src/lib/part5.ts`
- Modify: `apps/web/src/lib/part5.test.ts`
- Modify: `apps/web/src/lib/toeicFilters.ts`
- Modify: `apps/web/src/app/(app)/reading/part5/page.tsx`
- Modify: `apps/web/src/app/(app)/reading/part5/page.test.tsx`

**Interfaces:**
- Consumes: `TopicFilterPopover` (`@/components/vocab-bank/TopicFilterPopover`, already exists, props `{ topics: Topic[]; selectedTopicIds: Set<string>; onApply: (ids: Set<string>) => void }`), `Topic` (`@/lib/topics`).
- Produces (used by Task 4):
  - `ToeicFilters` changes shape to `{ topicIds: string[]; volumes: string[] }`.
  - `buildPart5Prompt(topicNames: string[], targetLanguage: TargetLanguage, volumes: EconomyVolume[]): string` — **signature changed**, first parameter is now resolved topic name strings, not a `ToeicContext` value.
  - `toeicFilters.ts` no longer exports `ToeicContext`, `TOEIC_CONTEXTS`, or `CONTEXT_LABELS` (deleted, unused after this task).
  - `part5/page.tsx`'s setup phase still exists after this task (Task 4 removes it) but now uses `TopicFilterPopover` + `selectedTopicIds` instead of the old `SimpleDropdown` + `appContext`.

This task's own full test suite (`savedReadingExercises.test.ts`, `part5.test.ts`, `part5/page.test.tsx`) must pass before any hub-page work begins — this is the same "migrate first, in isolation" sequencing the Part 5 plan itself used for its own Task 1.

- [ ] **Step 1: Update `savedReadingExercises.ts`'s `ToeicFilters` and `matchesToeic`**

In `apps/web/src/lib/savedReadingExercises.ts`, replace:

```ts
export interface ToeicFilters {
  appContext: string;
  volumes: string[]; // empty = "all volumes" — mirrors Flutter's own default
}
```

with:

```ts
export interface ToeicFilters {
  topicIds: string[]; // empty = matches anything, same convention as BilingualFilters
  volumes: string[]; // empty = "all volumes" — mirrors Flutter's own default
}
```

Replace:

```ts
function matchesToeic(exercise: { generationFilters: ToeicFilters }, filters: ToeicFilters): boolean {
  if (exercise.generationFilters.appContext !== filters.appContext) return false;
  if (filters.volumes.length > 0 && exercise.generationFilters.volumes.length > 0) {
    const overlaps = exercise.generationFilters.volumes.some((v) => filters.volumes.includes(v));
    if (!overlaps) return false;
  }
  return true;
}
```

with (topic matching now mirrors `matchesBilingual`'s topic-overlap logic exactly):

```ts
function matchesToeic(exercise: { generationFilters: ToeicFilters }, filters: ToeicFilters): boolean {
  if (filters.topicIds.length > 0) {
    const overlaps = exercise.generationFilters.topicIds.some((id) => filters.topicIds.includes(id));
    if (!overlaps) return false;
  }
  if (filters.volumes.length > 0 && exercise.generationFilters.volumes.length > 0) {
    const overlaps = exercise.generationFilters.volumes.some((v) => filters.volumes.includes(v));
    if (!overlaps) return false;
  }
  return true;
}
```

No other line in this file changes.

- [ ] **Step 2: Update `savedReadingExercises.test.ts`'s part5 fixtures and matching tests**

In `apps/web/src/lib/savedReadingExercises.test.ts`:

Change the `FakeToeicFilters` interface and `makePart5Exercise`'s default:

```ts
interface FakeToeicFilters {
  topicIds: string[];
  volumes: string[];
}
```

```ts
function makePart5Exercise(overrides: Partial<{ id: string; generationFilters: FakeToeicFilters }> = {}) {
  return {
    id: "p5-1",
    type: "part5" as const,
    passage: PART5_PASSAGE,
    generationFilters: { topicIds: ["biz-1"], volumes: ["vol3"] },
    targetLanguage: "english" as const,
    createdAt: "2026-01-01T00:00:00.000Z",
    ...overrides,
  };
}
```

In the `describe("saveReadingExercise", ...)` block, find the "creates a part5 document" test and change:

```ts
    const filters = { appContext: "business", volumes: ["vol3"] };
```

to:

```ts
    const filters = { topicIds: ["biz-1"], volumes: ["vol3"] };
```

(the rest of that test — the `saveReadingExercise("user-123", "part5", PART5_PASSAGE, filters, "english")` call and its assertions — is unchanged; only the `filters` fixture's shape changes.)

In the `describe("getRandomSavedExercise", ...)` block, replace these three tests:

```ts
  it("matches part5 exercises by exact appContext and volume overlap", async () => {
    const p5 = makePart5Exercise({ generationFilters: { appContext: "business", volumes: ["vol2", "vol3"] } });
    vi.mocked(getDocs).mockResolvedValue({ docs: [{ id: p5.id, data: () => p5 }] } as never);

    const result = await getRandomSavedExercise("user-123", "english", "part5", {
      appContext: "business",
      volumes: ["vol3", "vol4"],
    } as never);

    expect(result?.id).toBe(p5.id);
  });

  it("does not match a part5 exercise with a different appContext", async () => {
    const p5 = makePart5Exercise({ generationFilters: { appContext: "travel", volumes: [] } });
    vi.mocked(getDocs).mockResolvedValue({ docs: [{ id: p5.id, data: () => p5 }] } as never);

    const result = await getRandomSavedExercise("user-123", "english", "part5", {
      appContext: "business",
      volumes: [],
    } as never);

    expect(result).toBeNull();
  });

  it("matches a part5 exercise on appContext when either side's volumes list is empty", async () => {
    const p5 = makePart5Exercise({ generationFilters: { appContext: "business", volumes: [] } });
    vi.mocked(getDocs).mockResolvedValue({ docs: [{ id: p5.id, data: () => p5 }] } as never);

    const result = await getRandomSavedExercise("user-123", "english", "part5", {
      appContext: "business",
      volumes: ["vol4"],
    } as never);

    expect(result?.id).toBe(p5.id);
  });
```

with:

```ts
  it("matches part5 exercises by topic overlap and volume overlap", async () => {
    const p5 = makePart5Exercise({ generationFilters: { topicIds: ["biz-1", "travel-1"], volumes: ["vol2", "vol3"] } });
    vi.mocked(getDocs).mockResolvedValue({ docs: [{ id: p5.id, data: () => p5 }] } as never);

    const result = await getRandomSavedExercise("user-123", "english", "part5", {
      topicIds: ["travel-1", "food-1"],
      volumes: ["vol3", "vol4"],
    } as never);

    expect(result?.id).toBe(p5.id);
  });

  it("does not match a part5 exercise when there is no topic overlap", async () => {
    const p5 = makePart5Exercise({ generationFilters: { topicIds: ["biz-1"], volumes: [] } });
    vi.mocked(getDocs).mockResolvedValue({ docs: [{ id: p5.id, data: () => p5 }] } as never);

    const result = await getRandomSavedExercise("user-123", "english", "part5", {
      topicIds: ["travel-1"],
      volumes: [],
    } as never);

    expect(result).toBeNull();
  });

  it("matches a part5 exercise on any topic when the requested topicIds filter is empty", async () => {
    const p5 = makePart5Exercise({ generationFilters: { topicIds: ["biz-1"], volumes: [] } });
    vi.mocked(getDocs).mockResolvedValue({ docs: [{ id: p5.id, data: () => p5 }] } as never);

    const result = await getRandomSavedExercise("user-123", "english", "part5", {
      topicIds: [],
      volumes: ["vol4"],
    } as never);

    expect(result?.id).toBe(p5.id);
  });
```

No other test in this file changes.

- [ ] **Step 3: Run `savedReadingExercises.test.ts` to verify it passes**

Run: `cd apps/web && npx vitest run --run src/lib/savedReadingExercises.test.ts`
Expected: PASS, all tests green.

- [ ] **Step 4: Update `part5.ts`'s `buildPart5Prompt`**

In `apps/web/src/lib/part5.ts`, change the import line:

```ts
import { ECONOMY_VOLUMES, VOLUME_PROMPT_HINTS, type EconomyVolume } from "./toeicFilters";
```

Replace `buildPart5Prompt` with:

```ts
// Ports lib/features/reading/data/sources/part5_source.dart's prompt. Takes
// resolved topic *names* (e.g. "Business", "Travel" — resolved by the caller
// from the user's selected Vocab Bank Topic documents), not a fixed enum —
// this is the same shared "Chủ đề" filter Đọc & gõ already uses, per the
// hub/setup-merge spec. An empty topic list omits the register clause
// entirely rather than defaulting to a fake "general" register.
export function buildPart5Prompt(topicNames: string[], targetLanguage: TargetLanguage, volumes: EconomyVolume[]): string {
  const languageLabel = LANGUAGE_LABELS[targetLanguage];
  const contextClause = topicNames.length > 0 ? `, in a ${topicNames.join("/")} register/setting` : "";
  const effectiveVolumes = volumes.length === 0 ? ECONOMY_VOLUMES : volumes;
  const volumeHints = effectiveVolumes.map((v) => `${v}: ${VOLUME_PROMPT_HINTS[v]}`).join("; ");
  return (
    `You are creating a TOEIC Part 5 (Incomplete Sentences) practice set for a Vietnamese speaker ` +
    `learning ${languageLabel}${contextClause}, calibrated to the TOEIC ` +
    `difficulty levels below (mix questions across them roughly evenly and randomly): ${volumeHints}. ` +
    `Write exactly ${QUESTION_COUNT} independent sentences, each with exactly one blank marked "___", ` +
    `testing grammar (word form, verb tense/agreement, prepositions, conjunctions) or ` +
    `vocabulary-in-context, with exactly 4 answer options in ${languageLabel} and a brief explanation ` +
    `(in Vietnamese) of why the correct option is right and, briefly, why the others are wrong. ` +
    `The explanation must use only Vietnamese script — never Chinese, Japanese, or other ` +
    `non-Vietnamese characters. ` +
    `Respond with JSON only (no markdown, no code fences): ` +
    `{"questions": [{"sentenceWithBlank": "...", "options": ["...", "...", "...", "..."], ` +
    `"correctIndex": 0, "explanation": "..."}]}`
  );
}
```

`parsePart5Set` is unchanged.

- [ ] **Step 5: Replace `part5.test.ts`'s `buildPart5Prompt` tests**

In `apps/web/src/lib/part5.test.ts`, replace the entire `describe("buildPart5Prompt", ...)` block with:

```ts
describe("buildPart5Prompt", () => {
  it("includes topic names, target language label, and asks for exactly 15 questions in JSON", () => {
    const prompt = buildPart5Prompt(["Business"], "english", ["vol3"]);
    expect(prompt).toContain("Business");
    expect(prompt).toContain("English");
    expect(prompt).toContain("exactly 15");
    expect(prompt).toContain("JSON only");
    expect(prompt).toContain('"questions"');
  });

  it("joins multiple topic names with a slash", () => {
    const prompt = buildPart5Prompt(["Business", "Travel"], "english", ["vol3"]);
    expect(prompt).toContain("Business/Travel");
  });

  it("omits the register clause entirely when no topics are selected", () => {
    const prompt = buildPart5Prompt([], "english", ["vol2"]);
    expect(prompt).not.toContain("register/setting");
  });

  it("includes the prompt hint for every requested volume", () => {
    const prompt = buildPart5Prompt([], "english", ["vol2", "vol4"]);
    expect(prompt).toContain("easy-medium difficulty");
    expect(prompt).toContain("unusual grammar/vocabulary traps");
  });

  it("uses every volume's hint when the volumes list is empty (matches Flutter's 'empty = all' default)", () => {
    const prompt = buildPart5Prompt([], "english", []);
    expect(prompt).toContain("easy-medium difficulty");
    expect(prompt).toContain("medium-high difficulty");
    expect(prompt).toContain("equal to or harder than the real exam");
    expect(prompt).toContain("deepest grammar traps");
  });

  it("uses the target language's own label, not always English", () => {
    const prompt = buildPart5Prompt([], "korean", ["vol2"]);
    expect(prompt).toContain("한국어");
  });

  it("requires Vietnamese-script-only explanations", () => {
    const prompt = buildPart5Prompt([], "english", ["vol2"]);
    expect(prompt).toContain("Vietnamese script");
  });
});
```

The `describe("parsePart5Set", ...)` block is unchanged.

- [ ] **Step 6: Run `part5.test.ts` to verify it passes**

Run: `cd apps/web && npx vitest run --run src/lib/part5.test.ts`
Expected: PASS, all tests green.

- [ ] **Step 7: Delete `ToeicContext`/`TOEIC_CONTEXTS`/`CONTEXT_LABELS` from `toeicFilters.ts`**

In `apps/web/src/lib/toeicFilters.ts`, delete these three exports entirely:

```ts
export type ToeicContext = ...
export const TOEIC_CONTEXTS: ToeicContext[] = [...]
export const CONTEXT_LABELS: Record<ToeicContext, string> = {...}
```

Keep `EconomyVolume`, `ECONOMY_VOLUMES`, `VOLUME_LABELS`, `VOLUME_PROMPT_HINTS` exactly as they are. Before deleting, grep the whole `apps/web/src` tree for `ToeicContext`, `TOEIC_CONTEXTS`, and `CONTEXT_LABELS` to confirm nothing outside `part5/page.tsx` (which Step 8 below fixes in this same task) still references them.

- [ ] **Step 8: Update `part5/page.tsx`'s setup phase to use `TopicFilterPopover`**

In `apps/web/src/app/(app)/reading/part5/page.tsx`:

Change the imports — remove `TOEIC_CONTEXTS, CONTEXT_LABELS, ..., type ToeicContext` from the `toeicFilters` import, and add `TopicFilterPopover`:

```ts
import { TopicFilterPopover } from "@/components/vocab-bank/TopicFilterPopover";
import { ECONOMY_VOLUMES, VOLUME_LABELS, type EconomyVolume } from "@/lib/toeicFilters";
import { buildPart5Prompt, parsePart5Set, type Part5Set } from "@/lib/part5";
import { generateContent } from "@/lib/generateContent";
import { parseAiJsonObject } from "@/lib/parseAiJson";
import { getRandomSavedExercise, saveReadingExercise, type ToeicFilters } from "@/lib/savedReadingExercises";
import { McQuestionCard } from "@/components/reading/McQuestionCard";
import { VocabSuggestionsSection } from "@/components/shared/VocabSuggestionsSection";
```

(The old `SimpleDropdown, type SimpleDropdownOption` import from `@/components/shared/SimpleDropdown` is deleted entirely — `SimpleDropdown` in this file was only ever used for the Chủ đề dropdown, which this step replaces with `TopicFilterPopover`, so nothing in this file references it anymore.)

Delete the `CONTEXT_DROPDOWN_OPTIONS` constant entirely (no longer needed).

Change the state declaration:

```ts
  const [appContext, setAppContext] = useState<ToeicContext>("general");
```

to:

```ts
  const [selectedTopicIds, setSelectedTopicIds] = useState<Set<string>>(new Set());
```

Add a helper right after `toggleVolume`:

```ts
  function resolvedTopicNames(): string[] {
    return topics.filter((t) => selectedTopicIds.has(t.id)).map((t) => t.name);
  }
```

Change `currentFilters`:

```ts
  function currentFilters(): ToeicFilters {
    return { topicIds: [...selectedTopicIds], volumes: [...selectedVolumes] };
  }
```

In `handleGenerate`, change:

```ts
      const prompt = buildPart5Prompt(appContext, settings.targetLanguage, [...selectedVolumes]);
```

to:

```ts
      const prompt = buildPart5Prompt(resolvedTopicNames(), settings.targetLanguage, [...selectedVolumes]);
```

In the setup-phase JSX, replace:

```tsx
          <SimpleDropdown
            triggerLabel={CONTEXT_LABELS[appContext]}
            ariaLabel="Chọn chủ đề"
            options={CONTEXT_DROPDOWN_OPTIONS}
            value={appContext}
            onChange={setAppContext}
            active={appContext !== "general"}
          />
```

with:

```tsx
          <TopicFilterPopover topics={topics} selectedTopicIds={selectedTopicIds} onApply={setSelectedTopicIds} />
```

No other line in this file changes — the setup phase itself (its buttons, gating, error/notice rendering) still exists after this task; Task 4 removes it.

- [ ] **Step 9: Update `part5/page.test.tsx`'s fixtures**

In `apps/web/src/app/(app)/reading/part5/page.test.tsx`, find every occurrence of `{ appContext: "general", volumes: [] }` (there are 5, in various saved-exercise fixtures and one assertion) and change each to `{ topicIds: [], volumes: [] }`. Do not change anything else in the file — the default state (no topic selected, matching this file's existing `getTopics` mock defaulting to `[]`) already produces `topicIds: []` via `currentFilters()`/`resolvedTopicNames()`, so no test's setup/act steps need to change, only these fixture literals.

- [ ] **Step 10: Run the full suite**

Run: `cd apps/web && npm test -- --run`
Expected: all tests pass (the one pre-existing, unrelated `src/styles/bloom.test.ts` `.app-frame` failure may still show — not something to fix here).

- [ ] **Step 11: Typecheck**

Run: `cd apps/web && npx tsc --noEmit`
Expected: no errors.

- [ ] **Step 12: Commit**

```bash
git add apps/web/src/lib/savedReadingExercises.ts apps/web/src/lib/savedReadingExercises.test.ts apps/web/src/lib/part5.ts apps/web/src/lib/part5.test.ts apps/web/src/lib/toeicFilters.ts "apps/web/src/app/(app)/reading/part5/page.tsx" "apps/web/src/app/(app)/reading/part5/page.test.tsx"
git commit -m "refactor(web): migrate Part 5's Chủ đề filter from a fixed enum to real Vocab Bank topics"
```

---

## Task 2: Redesign the hub to be the single setup surface

**Files:**
- Modify: `apps/web/src/app/(app)/reading/page.tsx`
- Modify: `apps/web/src/app/(app)/reading/page.test.tsx`
- Modify: `apps/web/src/styles/bloom.css`

**Interfaces:**
- Consumes: `getVocabRecords`, `getTopics`, `TopicFilterPopover`, `SimpleDropdown`, `selectSessionWords`/`SessionWordFilters` (`@/lib/practiceSession`), `ECONOMY_VOLUMES`/`VOLUME_LABELS`/`type EconomyVolume` (`@/lib/toeicFilters`) — all already exist.
- Produces (used by Tasks 3-4, as the URL shape they must read):
  - Navigating to Đọc & gõ: `/reading/bilingual?topicIds=<comma-separated ids>&maxCefr=<level|omitted>&wordCount=<number|all>&action=<generate|existing>`.
  - Navigating to Part 5: `/reading/part5?topicIds=<comma-separated ids>&volumes=<comma-separated volume keys|omitted>&action=<generate|existing>`.
  - `topicIds` is omitted from the URL entirely when empty (not an empty-string param) — same for `volumes`.

This task does **not** touch `bilingual/page.tsx` or `part5/page.tsx` beyond what Task 1 already did — those pages still have their own (now topic-based, per Task 1) setup phases at the end of this task. That's fine: the hub linking to them with query params they don't yet read is a normal, safe intermediate state (the params are simply ignored until Tasks 3-4 land), verified by this task's own tests mocking `useRouter` and asserting the constructed URL, not by an end-to-end navigation.

- [ ] **Step 1: Write the failing tests**

Replace the entire content of `apps/web/src/app/(app)/reading/page.test.tsx` with:

```tsx
import { beforeEach, describe, expect, it, vi } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import ReadingHubPage from "./page";
import { useAuthUser } from "@/lib/useAuthUser";
import { getVocabRecords, type VocabRecord } from "@/lib/vocabRecords";
import { getTopics, type Topic } from "@/lib/topics";

vi.mock("@/lib/useAuthUser", () => ({ useAuthUser: vi.fn() }));
vi.mock("@/lib/vocabRecords", () => ({ getVocabRecords: vi.fn() }));
vi.mock("@/lib/topics", () => ({ getTopics: vi.fn() }));
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

function mockSignedIn() {
  vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" }, loading: false } as never);
}

beforeEach(() => {
  vi.clearAllMocks();
  vi.mocked(getTopics).mockResolvedValue([]);
});

describe("ReadingHubPage (auth)", () => {
  it("prompts sign-in when logged out", () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: null, loading: false } as never);
    render(<ReadingHubPage />);
    expect(screen.getByText("Đăng nhập với Google")).toBeInTheDocument();
  });
});

describe("ReadingHubPage (mode picker)", () => {
  it("hides the secondary filter and action buttons until a mode is picked", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([]);

    render(<ReadingHubPage />);
    await screen.findByRole("button", { name: /Đọc & gõ/ });

    expect(screen.queryByRole("button", { name: "Tạo bài luyện" })).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "🔀 Lấy bài có sẵn" })).not.toBeInTheDocument();
  });

  it("shows Đọc & gõ's own secondary filters (Trình độ, Số từ) once that mode is picked", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue(
      Array.from({ length: 5 }, (_, i) => makeRecord({ id: `w${i}` }))
    );

    render(<ReadingHubPage />);
    fireEvent.click(await screen.findByRole("button", { name: /Đọc & gõ/ }));

    expect(await screen.findByRole("button", { name: "🔀 Lấy bài có sẵn" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Tạo bài luyện" })).not.toBeDisabled();
    expect(screen.getByRole("button", { name: "Mọi trình độ ▾" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "10 từ ▾" })).toBeInTheDocument();
  });

  it("shows Part 5's own secondary filter (Độ khó chips) once that mode is picked", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([]);

    render(<ReadingHubPage />);
    fireEvent.click(await screen.findByRole("button", { name: /Part 5/ }));

    expect(await screen.findByRole("button", { name: "🔀 Lấy bài có sẵn" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Tạo bài luyện" })).not.toBeDisabled();
    expect(screen.getByRole("button", { name: VOLUME_LABEL_VOL2 })).toBeInTheDocument();
  });

  it("shows the min-words hint instead of the generate button for Đọc & gõ when fewer than 5 words match", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([makeRecord({ id: "1" }), makeRecord({ id: "2" })]);

    render(<ReadingHubPage />);
    fireEvent.click(await screen.findByRole("button", { name: /Đọc & gõ/ }));

    expect(
      await screen.findByText("Hãy lưu ít nhất 5 từ khớp với bộ lọc trên vào Ngân hàng từ vựng. Hiện có 2 từ.")
    ).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Tạo bài luyện" })).not.toBeInTheDocument();
  });

  it("Part 5's 'Lấy bài có sẵn' is never gated by word count, even with 0 matching words", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([]);

    render(<ReadingHubPage />);
    fireEvent.click(await screen.findByRole("button", { name: /Part 5/ }));

    expect(await screen.findByRole("button", { name: "🔀 Lấy bài có sẵn" })).not.toBeDisabled();
  });
});

describe("ReadingHubPage (navigation)", () => {
  it("navigates to /reading/bilingual with the selected filters and action=generate", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue(
      Array.from({ length: 5 }, (_, i) => makeRecord({ id: `w${i}` }))
    );

    render(<ReadingHubPage />);
    fireEvent.click(await screen.findByRole("button", { name: /Đọc & gõ/ }));
    fireEvent.click(await screen.findByRole("button", { name: "Tạo bài luyện" }));

    expect(pushMock).toHaveBeenCalledWith("/reading/bilingual?wordCount=10&action=generate");
  });

  it("navigates to /reading/bilingual with action=existing for 'Lấy bài có sẵn'", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([]);

    render(<ReadingHubPage />);
    fireEvent.click(await screen.findByRole("button", { name: /Đọc & gõ/ }));
    fireEvent.click(await screen.findByRole("button", { name: "🔀 Lấy bài có sẵn" }));

    expect(pushMock).toHaveBeenCalledWith("/reading/bilingual?wordCount=10&action=existing");
  });

  it("includes selected topicIds and maxCefr in the query string when set", async () => {
    mockSignedIn();
    const topics: Topic[] = [{ id: "biz-1", name: "Business", emoji: "💼", isPredefined: true, createdAt: "2026-01-01" }];
    vi.mocked(getTopics).mockResolvedValue(topics);
    vi.mocked(getVocabRecords).mockResolvedValue(
      Array.from({ length: 5 }, (_, i) => makeRecord({ id: `w${i}`, topicIds: ["biz-1"] }))
    );

    render(<ReadingHubPage />);
    fireEvent.click(await screen.findByRole("button", { name: "💼 Business" }));
    fireEvent.click(screen.getByRole("button", { name: "Áp dụng" }));
    fireEvent.click(await screen.findByRole("button", { name: /Đọc & gõ/ }));
    fireEvent.click(screen.getByRole("button", { name: "Mọi trình độ ▾" }));
    fireEvent.click(screen.getByRole("option", { name: "Tối đa B1" }));
    fireEvent.click(screen.getByRole("button", { name: "Tạo bài luyện" }));

    const url = pushMock.mock.calls[0][0] as string;
    expect(url).toContain("topicIds=biz-1");
    expect(url).toContain("maxCefr=b1");
  });

  it("navigates to /reading/part5 with selected volumes and action=generate", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([]);

    render(<ReadingHubPage />);
    fireEvent.click(await screen.findByRole("button", { name: /Part 5/ }));
    fireEvent.click(screen.getByRole("button", { name: VOLUME_LABEL_VOL2 }));
    fireEvent.click(screen.getByRole("button", { name: "Tạo bài luyện" }));

    expect(pushMock).toHaveBeenCalledWith("/reading/part5?volumes=vol2&action=generate");
  });
});
```

Add this constant near the top of the file, right after the imports (the volume chip label text comes from `VOLUME_LABELS`, imported for exactly this reason so the test doesn't hardcode a string that could drift from the real label):

```ts
import { VOLUME_LABELS } from "@/lib/toeicFilters";
const VOLUME_LABEL_VOL2 = VOLUME_LABELS.vol2;
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd apps/web && npx vitest run --run "src/app/(app)/reading/page.test.tsx"`
Expected: FAIL — the hub currently has none of this UI.

- [ ] **Step 3: Implement the new hub page**

Replace the entire content of `apps/web/src/app/(app)/reading/page.tsx` with:

```tsx
"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { useAuthUser } from "@/lib/useAuthUser";
import { SignInButton } from "@/components/SignInButton";
import { getVocabRecords, type VocabRecord } from "@/lib/vocabRecords";
import { getTopics, type Topic } from "@/lib/topics";
import { TopicFilterPopover } from "@/components/vocab-bank/TopicFilterPopover";
import { SimpleDropdown, type SimpleDropdownOption } from "@/components/shared/SimpleDropdown";
import { selectSessionWords, type SessionWordFilters } from "@/lib/practiceSession";
import { ECONOMY_VOLUMES, VOLUME_LABELS, type EconomyVolume } from "@/lib/toeicFilters";

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

type Mode = "bilingual" | "part5";

export default function ReadingHubPage() {
  const { user, loading: authLoading } = useAuthUser();
  const router = useRouter();

  const [records, setRecords] = useState<VocabRecord[]>([]);
  const [topics, setTopics] = useState<Topic[]>([]);
  const [selectedTopicIds, setSelectedTopicIds] = useState<Set<string>>(new Set());
  const [mode, setMode] = useState<Mode | null>(null);
  const [maxCefr, setMaxCefr] = useState<CefrLevel | null>(null);
  const [wordCount, setWordCount] = useState<number | null>(DEFAULT_WORD_COUNT);
  const [selectedVolumes, setSelectedVolumes] = useState<Set<EconomyVolume>>(new Set());

  useEffect(() => {
    if (!user) return;
    Promise.all([getVocabRecords(user.uid), getTopics(user.uid)])
      .then(([r, t]) => {
        setRecords(r);
        setTopics(t);
      })
      .catch(() => {});
  }, [user]);

  function toggleVolume(v: EconomyVolume) {
    setSelectedVolumes((prev) => {
      const next = new Set(prev);
      if (next.has(v)) next.delete(v);
      else next.add(v);
      return next;
    });
  }

  function buildQuery(action: "generate" | "existing"): string {
    const params = new URLSearchParams();
    if (selectedTopicIds.size > 0) params.set("topicIds", [...selectedTopicIds].join(","));
    if (mode === "bilingual") {
      if (maxCefr) params.set("maxCefr", maxCefr);
      params.set("wordCount", wordCount === null ? "all" : String(wordCount));
    } else if (mode === "part5") {
      if (selectedVolumes.size > 0) params.set("volumes", [...selectedVolumes].join(","));
    }
    params.set("action", action);
    return params.toString();
  }

  function navigate(action: "generate" | "existing") {
    if (!mode) return;
    const path = mode === "bilingual" ? "/reading/bilingual" : "/reading/part5";
    router.push(`${path}?${buildQuery(action)}`);
  }

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

  const matchingCount = selectSessionWords(records, {
    topicIds: selectedTopicIds,
    maxCefr,
    count: null,
  } satisfies SessionWordFilters).length;
  const canGenerateBilingual = matchingCount >= MIN_VOCAB_WORDS;

  return (
    <div>
      <h2 className="scr-title">Đọc</h2>
      <p className="scr-sub">Chọn chủ đề, chọn chế độ luyện, rồi tạo bài hoặc lấy bài có sẵn.</p>

      <TopicFilterPopover topics={topics} selectedTopicIds={selectedTopicIds} onApply={setSelectedTopicIds} />

      <div className="reading-hub-cards">
        <button
          type="button"
          className={`reading-hub-card reading-hub-card-toggle${mode === "bilingual" ? " active" : ""}`}
          onClick={() => setMode("bilingual")}
        >
          <span className="reading-hub-card-title">✍️ Đọc &amp; gõ</span>
          <span className="reading-hub-card-desc">
            Gõ lại đoạn văn song ngữ được tạo từ từ vựng của bạn.
          </span>
        </button>
        <button
          type="button"
          className={`reading-hub-card reading-hub-card-toggle${mode === "part5" ? " active" : ""}`}
          onClick={() => setMode("part5")}
        >
          <span className="reading-hub-card-title">📝 Part 5 — Điền câu</span>
          <span className="reading-hub-card-desc">
            15 câu điền từ/ngữ pháp kiểu TOEIC, AI tạo theo chủ đề và độ khó bạn chọn.
          </span>
        </button>
      </div>

      {mode === "bilingual" && (
        <div className="practice-filters">
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
      )}

      {mode === "part5" && (
        <div className="practice-filters">
          {ECONOMY_VOLUMES.map((v) => (
            <button
              key={v}
              type="button"
              className={`vb-chip${selectedVolumes.has(v) ? " active" : ""}`}
              onClick={() => toggleVolume(v)}
            >
              {VOLUME_LABELS[v]}
            </button>
          ))}
        </div>
      )}

      {mode && (
        <div className="reading-setup-actions">
          {mode === "part5" || canGenerateBilingual ? (
            <button type="button" className="btn-primary" onClick={() => navigate("generate")}>
              Tạo bài luyện
            </button>
          ) : (
            <p className="reading-min-words-hint">
              Hãy lưu ít nhất {MIN_VOCAB_WORDS} từ khớp với bộ lọc trên vào Ngân hàng từ vựng. Hiện có{" "}
              {matchingCount} từ.
            </p>
          )}
          <button type="button" className="btn-secondary" onClick={() => navigate("existing")}>
            🔀 Lấy bài có sẵn
          </button>
        </div>
      )}
    </div>
  );
}
```

- [ ] **Step 4: Add CSS for the toggle-style mode cards**

In `apps/web/src/styles/bloom.css`, add this rule right after the existing `.reading-hub-card` rule:

```css
.reading-hub-card-toggle {
  border: 2px solid transparent;
  cursor: pointer;
  font-family: inherit;
  text-align: left;
}

.reading-hub-card-toggle.active {
  border-color: var(--accent);
  background: var(--surface-3);
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `cd apps/web && npx vitest run --run "src/app/(app)/reading/page.test.tsx"`
Expected: PASS, all tests green.

- [ ] **Step 6: Run the full suite**

Run: `cd apps/web && npm test -- --run`
Expected: all tests pass (aside from the known pre-existing `bloom.test.ts` failure).

- [ ] **Step 7: Typecheck**

Run: `cd apps/web && npx tsc --noEmit`
Expected: no errors.

- [ ] **Step 8: Commit**

```bash
git add "apps/web/src/app/(app)/reading/page.tsx" "apps/web/src/app/(app)/reading/page.test.tsx" apps/web/src/styles/bloom.css
git commit -m "feat(web): merge setup filters and actions into the reading hub"
```

---

## Task 3: `bilingual/page.tsx` reads filters from the URL and drops its setup phase

**Files:**
- Modify: `apps/web/src/app/(app)/reading/bilingual/page.tsx`
- Modify: `apps/web/src/app/(app)/reading/bilingual/page.test.tsx`

**Interfaces:**
- Consumes: `useSearchParams` (`next/navigation`), `Suspense` (`react`) — both new to this file. Everything else (Task 1/2 exports) unchanged.
- Produces: nothing further tasks in this plan consume — Task 4 makes the equivalent change to `part5/page.tsx` independently.

This task removes the `"setup"` phase entirely. `Phase` becomes `"loading" | "session" | "result"`. The filters (`topicIds`, `maxCefr`, `wordCount`) are no longer mutable UI state — they're derived once from the URL's query string. An effect on mount reads the `action` param and immediately calls `handleGenerate()` or `fetchSavedExercise()`; missing/invalid `action` redirects to `/reading`.

- [ ] **Step 1: Write the failing tests**

Replace the entire content of `apps/web/src/app/(app)/reading/bilingual/page.test.tsx` with:

```tsx
import { beforeEach, describe, expect, it, vi } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import BilingualReadingPage from "./page";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettingsContext } from "@/lib/SettingsContext";
import { getVocabRecords, type VocabRecord } from "@/lib/vocabRecords";
import { getTopics } from "@/lib/topics";
import { generateContent } from "@/lib/generateContent";
import { getAllUsedVocabIds, getRandomSavedExercise, saveReadingExercise } from "@/lib/savedReadingExercises";
import type { SavedReadingExercise } from "@/lib/savedReadingExercises";
import { DEFAULT_SETTINGS, type UserSettings } from "@/lib/settings";

vi.mock("@/lib/useAuthUser", () => ({ useAuthUser: vi.fn() }));
vi.mock("@/lib/SettingsContext", () => ({ useSettingsContext: vi.fn() }));
vi.mock("@/lib/vocabRecords", () => ({ getVocabRecords: vi.fn() }));
vi.mock("@/lib/topics", () => ({ getTopics: vi.fn() }));
vi.mock("@/lib/generateContent", () => ({ generateContent: vi.fn() }));
vi.mock("@/lib/savedReadingExercises", async () => {
  const actual = await vi.importActual<typeof import("@/lib/savedReadingExercises")>(
    "@/lib/savedReadingExercises"
  );
  return {
    ...actual,
    getAllUsedVocabIds: vi.fn(),
    getRandomSavedExercise: vi.fn(),
    saveReadingExercise: vi.fn(),
  };
});
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
vi.mock("@/components/shared/VocabSuggestionsSection", () => ({
  VocabSuggestionsSection: ({ text }: { text: string }) => (
    <div data-testid="vocab-suggestions" data-text={text} />
  ),
}));

function setSearchParams(params: Record<string, string>) {
  mockSearchParams = new URLSearchParams(params);
}

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
  setSearchParams({ wordCount: "10", action: "generate" });
  vi.mocked(getAllUsedVocabIds).mockResolvedValue(new Set());
  vi.mocked(getRandomSavedExercise).mockResolvedValue(null);
});

describe("BilingualReadingPage (loading phase)", () => {
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

  it("redirects to /reading when the action param is missing", async () => {
    setSearchParams({});
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([]);
    vi.mocked(getTopics).mockResolvedValue([]);

    render(<BilingualReadingPage />);

    await waitFor(() => expect(replaceMock).toHaveBeenCalledWith("/reading"));
  });

  it("redirects to /reading when the action param is invalid", async () => {
    setSearchParams({ action: "bogus" });
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([]);
    vi.mocked(getTopics).mockResolvedValue([]);

    render(<BilingualReadingPage />);

    await waitFor(() => expect(replaceMock).toHaveBeenCalledWith("/reading"));
  });

  it("auto-generates a passage from the due-prioritized word list on mount", async () => {
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

    await waitFor(() => expect(screen.getByText("Câu 1 / 1")).toBeInTheDocument());
    const promptArg = vi.mocked(generateContent).mock.calls[0][0].prompt;
    expect(promptArg).toContain("word0");
  });

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

    await waitFor(() => expect(generateContent).toHaveBeenCalled());
    expect(getAllUsedVocabIds).toHaveBeenCalledWith("u1");
    const promptArg = vi.mocked(generateContent).mock.calls[0][0].prompt;
    // Default word count (10) truncates 11 matching words down to 10 — the
    // 1 used word must be the one dropped, since all 10 fresh ones are
    // prioritized ahead of it.
    expect(promptArg).not.toContain("usedword");
    expect(promptArg).toContain("freshword0");
  });

  it("shows an error with retry/back-to-hub actions when the active provider has no API key", async () => {
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

    expect(
      await screen.findByText("Chưa có API key cho nhà cung cấp AI đang chọn — vào Cài đặt để thêm.")
    ).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Thử lại" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Về trang chính" })).toBeInTheDocument();
    expect(generateContent).not.toHaveBeenCalled();
  });

  it("shows an error when the AI returns no usable sentences, and 'Thử lại' retries the same action", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue(
      Array.from({ length: 5 }, (_, i) => makeRecord({ id: `w${i}`, headword: `word${i}` }))
    );
    vi.mocked(getTopics).mockResolvedValue([]);
    vi.mocked(generateContent).mockResolvedValueOnce({ text: JSON.stringify({}) });

    render(<BilingualReadingPage />);
    await screen.findByText("AI không trả về đoạn văn hợp lệ.");

    vi.mocked(generateContent).mockResolvedValue({
      text: JSON.stringify({ sentences: [{ target: "Hi.", vietnamese: "Chào.", vocabWords: [] }] }),
    });
    fireEvent.click(screen.getByRole("button", { name: "Thử lại" }));

    await waitFor(() => expect(screen.getByText("Câu 1 / 1")).toBeInTheDocument());
  });

  it('"Về trang chính" on the loading-error state navigates back to the hub', async () => {
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
    await screen.findByRole("button", { name: "Về trang chính" });
    fireEvent.click(screen.getByRole("button", { name: "Về trang chính" }));

    expect(pushMock).toHaveBeenCalledWith("/reading");
  });

  it('action=existing starts a session directly from a matching saved exercise, without calling the AI', async () => {
    setSearchParams({ wordCount: "10", action: "existing" });
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue(
      Array.from({ length: 5 }, (_, i) => makeRecord({ id: `w${i}`, headword: `word${i}` }))
    );
    vi.mocked(getTopics).mockResolvedValue([]);
    vi.mocked(getRandomSavedExercise).mockResolvedValue(SAVED_EXERCISE);

    render(<BilingualReadingPage />);

    await waitFor(() => expect(screen.getByText("Câu 1 / 1")).toBeInTheDocument());
    expect(screen.getByText("Câu đã lưu.")).toBeInTheDocument();
    expect(generateContent).not.toHaveBeenCalled();
  });

  it("action=existing falls back to AI generation with an inline notice when nothing matches", async () => {
    setSearchParams({ wordCount: "10", action: "existing" });
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue(
      Array.from({ length: 5 }, (_, i) => makeRecord({ id: `w${i}`, headword: `word${i}` }))
    );
    vi.mocked(getTopics).mockResolvedValue([]);
    vi.mocked(getRandomSavedExercise).mockResolvedValue(null);
    // generateContent's mock resolution is held open deliberately (instead of
    // mockResolvedValue, which settles within the same microtask burst as
    // everything upstream of it) so the notice's render commit is
    // observable before the AI fallback completes and the screen moves on
    // to the session phase — otherwise this races and the notice's visible
    // window can close before screen.findByText ever gets to see it.
    let resolveGenerate!: (value: { text: string }) => void;
    vi.mocked(generateContent).mockReturnValue(
      new Promise((resolve) => {
        resolveGenerate = resolve;
      })
    );

    render(<BilingualReadingPage />);

    expect(
      await screen.findByText("Chưa có bài đã lưu khớp bộ lọc này — đang tạo bài mới bằng AI…")
    ).toBeInTheDocument();
    expect(generateContent).toHaveBeenCalled();

    resolveGenerate({
      text: JSON.stringify({ sentences: [{ target: "A.", vietnamese: "B.", vocabWords: [] }] }),
    });
    await waitFor(() => expect(screen.getByText("Câu 1 / 1")).toBeInTheDocument());
  });

  it("action=existing shows an explanatory error (not a blank screen) when nothing matches and there aren't enough live words for the AI fallback", async () => {
    setSearchParams({ wordCount: "10", action: "existing" });
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([makeRecord({ id: "1" }), makeRecord({ id: "2" })]);
    vi.mocked(getTopics).mockResolvedValue([]);
    vi.mocked(getRandomSavedExercise).mockResolvedValue(null);

    render(<BilingualReadingPage />);

    expect(
      await screen.findByText("Hãy lưu ít nhất 5 từ khớp với bộ lọc đã chọn vào Ngân hàng từ vựng. Hiện có 2 từ.")
    ).toBeInTheDocument();
    expect(generateContent).not.toHaveBeenCalled();
  });
});

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
    await screen.findByText("Câu 1 / 2");

    fireEvent.change(screen.getByTestId("reading-type-input"), { target: { value: "Hi " } });

    expect(screen.getByText("Câu 1 / 2")).toBeInTheDocument();
  });
});

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
    expect(screen.getAllByText("100%")).toHaveLength(2); // accuracy AND score, both 100%

    expect(screen.getByText(/word0/)).toBeInTheDocument();

    const suggestions = screen.getByTestId("vocab-suggestions");
    expect(suggestions).toHaveAttribute("data-text", "Hi there. Bye now.");
  });

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
      "bilingual",
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
    setSearchParams({ wordCount: "10", action: "existing" });
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
    await screen.findByText("Câu 1 / 1");
    fireEvent.change(screen.getByTestId("reading-type-input"), { target: { value: "Hi." } });
    await waitFor(() => expect(screen.queryByTestId("reading-type-input")).not.toBeInTheDocument());

    expect(screen.queryByRole("button", { name: "Lưu bài" })).not.toBeInTheDocument();
    expect(screen.queryByTestId("vocab-suggestions")).not.toBeInTheDocument();
  });

  it("shows the full passage and its Vietnamese translation, highlighting the vocab words used", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue(
      Array.from({ length: 5 }, (_, i) => makeRecord({ id: `w${i}`, headword: `word${i}` }))
    );
    vi.mocked(getTopics).mockResolvedValue([]);
    vi.mocked(generateContent).mockResolvedValue({
      text: JSON.stringify({
        sentences: [
          { target: "I saw a cat today.", vietnamese: "Tôi thấy một con mèo hôm nay.", vocabWords: ["cat"] },
          { target: "It was calm.", vietnamese: "Nó rất bình tĩnh.", vocabWords: [] },
        ],
      }),
    });

    render(<BilingualReadingPage />);
    await screen.findByText("Câu 1 / 2");
    fireEvent.change(screen.getByTestId("reading-type-input"), { target: { value: "I saw a cat today." } });
    await screen.findByText("Câu 2 / 2");
    fireEvent.change(screen.getByTestId("reading-type-input"), { target: { value: "It was calm." } });
    await waitFor(() => expect(screen.queryByTestId("reading-type-input")).not.toBeInTheDocument());

    expect(screen.getByText(/I saw a/)).toBeInTheDocument();
    expect(screen.getByText(/It was calm\./)).toBeInTheDocument();
    expect(
      screen.getByText("Tôi thấy một con mèo hôm nay. Nó rất bình tĩnh.")
    ).toBeInTheDocument();

    const highlighted = screen.getByText("cat");
    expect(highlighted.tagName).toBe("MARK");
    expect(highlighted).toHaveClass("reading-vocab-highlight");
  });

  it("reflects an in-progress typo (typed wrong, then corrected) in the accuracy card, not just the deletion penalty", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue(
      Array.from({ length: 5 }, (_, i) => makeRecord({ id: `w${i}`, headword: `word${i}` }))
    );
    vi.mocked(getTopics).mockResolvedValue([]);
    vi.mocked(generateContent).mockResolvedValue({
      text: JSON.stringify({
        sentences: [{ target: "Hi.", vietnamese: "Chào.", vocabWords: [] }],
      }),
    });

    render(<BilingualReadingPage />);
    await screen.findByText("Câu 1 / 1");

    const input = screen.getByTestId("reading-type-input");
    // Type "Hx." (mismatch at index 1), then correct it to "Hi." without ever
    // deleting — mistakeChars should still capture the wrong keystroke that
    // was overwritten in place (length stayed the same, so deletedChars is 0).
    fireEvent.change(input, { target: { value: "Hx." } });
    fireEvent.change(input, { target: { value: "Hi." } });
    await waitFor(() => expect(screen.queryByTestId("reading-type-input")).not.toBeInTheDocument());

    // 1 mistakeChar out of 3 totalChars -> 1 - 1/3 = 67% (rounded), not 100%.
    expect(screen.getByText("67%")).toBeInTheDocument();
  });

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
  });

  it('shows a generateError alert on the result phase when "Sinh bài mới" fails to regenerate a "generated" session', async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue(
      Array.from({ length: 5 }, (_, i) => makeRecord({ id: `w${i}`, headword: `word${i}` }))
    );
    vi.mocked(getTopics).mockResolvedValue([]);

    await completeASession();
    vi.mocked(generateContent).mockRejectedValue(new Error("AI unavailable"));

    fireEvent.click(screen.getByRole("button", { name: "Sinh bài mới" }));

    expect(await screen.findByText("AI unavailable")).toBeInTheDocument();
    expect(screen.getByRole("alert")).toHaveTextContent("AI unavailable");
    // Stayed on the result phase — the stat cards are still visible and no
    // typing session started, so the error must be visible right here, not
    // silently swallowed by a screen that never renders generateError.
    expect(screen.getByText("Độ chính xác")).toBeInTheDocument();
    expect(screen.queryByTestId("reading-type-input")).not.toBeInTheDocument();
  });

  it('"Sinh bài mới" shows an explanatory error in place (does not navigate away) for a "reused" session when nothing else matches and there aren\'t enough live words for an AI attempt either', async () => {
    // This exercises the "reused" branch, not "generated" — unlike "Tạo bài
    // luyện", "Lấy bài có sẵn" is never gated by the 5-word rule, so a
    // session can legitimately start in "reused" mode with fewer than 5 live
    // matching words. With the setup phase gone, there is no screen left to
    // "fall back to" — fetchSavedExercise's own generateError branch is the
    // only feedback the user gets, rendered right here on the result phase.
    setSearchParams({ wordCount: "10", action: "existing" });
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
    await screen.findByText("Câu 1 / 1");
    fireEvent.change(screen.getByTestId("reading-type-input"), { target: { value: "Hi." } });
    await waitFor(() => expect(screen.queryByTestId("reading-type-input")).not.toBeInTheDocument());

    vi.mocked(getRandomSavedExercise).mockResolvedValue(null);

    fireEvent.click(screen.getByRole("button", { name: "Sinh bài mới" }));

    expect(
      await screen.findByText("Hãy lưu ít nhất 5 từ khớp với bộ lọc đã chọn vào Ngân hàng từ vựng. Hiện có 2 từ.")
    ).toBeInTheDocument();
    expect(generateContent).not.toHaveBeenCalled();
    expect(pushMock).not.toHaveBeenCalledWith("/reading");
  });

  it('"Sinh bài mới" fetches another saved exercise directly for a "reused" session (no exclusion, since reused sessions have no "Lưu bài" button to set justSavedId)', async () => {
    // The spec's "exclude the just-saved exercise from the next random pick"
    // requirement is implemented in fetchSavedExercise's excludeId param
    // (unit-tested directly in Task 1's getRandomSavedExercise tests) and
    // wired here as `justSavedId ?? undefined`. In practice `justSavedId` can
    // only become non-null via "Lưu bài", which only renders for
    // `sessionMode === "generated"` — and a "generated" session's own "Sinh
    // bài mới" always re-runs handleGenerate() directly, never a random pick.
    // So this exact exclusion never actually fires within a single page visit
    // under the current design; this test documents that reality rather than
    // asserting a false claim about it triggering.
    setSearchParams({ wordCount: "10", action: "existing" });
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
    expect(vi.mocked(getRandomSavedExercise).mock.calls[1][4]).toBeUndefined();
  });

  it('"Sinh bài mới" falls back to AI with the inline notice when a "reused" session finds no other saved match', async () => {
    setSearchParams({ wordCount: "10", action: "existing" });
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
    await screen.findByText("Câu 1 / 1");
    fireEvent.change(screen.getByTestId("reading-type-input"), { target: { value: "First." } });
    await waitFor(() => expect(screen.queryByTestId("reading-type-input")).not.toBeInTheDocument());

    vi.mocked(getRandomSavedExercise).mockResolvedValue(null);
    // generateContent's mock resolution is held open deliberately (instead of
    // mockResolvedValue, which settles within the same microtask burst as
    // everything upstream of it) so the notice's render commit is
    // observable before the AI fallback completes and the screen moves on
    // to the session phase — otherwise this races and the notice's visible
    // window can close before screen.findByText ever gets to see it (same
    // pattern as the loading-phase "falls back to AI generation" test above).
    let resolveGenerate!: (value: { text: string }) => void;
    vi.mocked(generateContent).mockReturnValue(
      new Promise((resolve) => {
        resolveGenerate = resolve;
      })
    );

    fireEvent.click(screen.getByRole("button", { name: "Sinh bài mới" }));

    expect(
      await screen.findByText("Chưa có bài đã lưu khớp bộ lọc này — đang tạo bài mới bằng AI…")
    ).toBeInTheDocument();

    resolveGenerate({
      text: JSON.stringify({ sentences: [{ target: "AI made.", vietnamese: "AI tạo.", vocabWords: [] }] }),
    });
    await waitFor(() => expect(screen.getByText("AI tạo.")).toBeInTheDocument());
  });

  it("clears the stale save error and saved-notice from a prior session once a fresh session's result screen renders", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue(
      Array.from({ length: 5 }, (_, i) => makeRecord({ id: `w${i}`, headword: `word${i}` }))
    );
    vi.mocked(getTopics).mockResolvedValue([]);
    vi.mocked(saveReadingExercise).mockRejectedValue(new Error("network down"));

    await completeASession();
    fireEvent.click(screen.getByRole("button", { name: "Lưu bài" }));
    expect(await screen.findByRole("alert")).toHaveTextContent("network down");

    vi.mocked(generateContent).mockResolvedValue({
      text: JSON.stringify({ sentences: [{ target: "New one.", vietnamese: "Bài mới.", vocabWords: [] }] }),
    });
    fireEvent.click(screen.getByRole("button", { name: "Sinh bài mới" }));

    await screen.findByText("Câu 1 / 1");
    fireEvent.change(screen.getByTestId("reading-type-input"), { target: { value: "New one." } });
    await waitFor(() => expect(screen.queryByTestId("reading-type-input")).not.toBeInTheDocument());

    expect(screen.queryByRole("alert")).not.toBeInTheDocument();
    expect(screen.queryByText(/đang tạo bài mới bằng AI/)).not.toBeInTheDocument();
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

Compared to the previously shipped file, this deletes two tests whose entire premise was setup-phase-only UI that no longer exists on this page (`"shows the minimum-words hint instead of the generate button..."` and `"shows the generate button once at least 5 words match"` — that gating now lives entirely in the hub's own Task 2 tests) and one more (`'"Lấy bài có sẵn" is enabled even when fewer than 5 words match...'`, same reason). It replaces `'"Lấy bài có sẵn" does not attempt an AI fallback when there are not enough live words'` and `'"Sinh bài mới" falls back to the setup phase for a "reused" session when nothing else matches...'` with versions matching the new behavior: an explicit `generateError` message instead of silence, since there is no more setup screen for either path to silently fall back to.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd apps/web && npx vitest run --run "src/app/(app)/reading/bilingual/page.test.tsx"`
Expected: FAIL — the page still has its old setup-phase/button-driven flow.

- [ ] **Step 3: Rewrite the page**

In `apps/web/src/app/(app)/reading/bilingual/page.tsx`:

Add to the imports:

```ts
import { Suspense, useEffect, useRef, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
```

(replacing the current `import { useEffect, useState } from "react";` and `import { useRouter } from "next/navigation";` lines.)

Delete these two now-unused imports entirely — neither `TopicFilterPopover` nor `SimpleDropdown` is rendered anywhere on this page once its setup phase is gone:

```ts
import { TopicFilterPopover } from "@/components/vocab-bank/TopicFilterPopover";
import { SimpleDropdown, type SimpleDropdownOption } from "@/components/shared/SimpleDropdown";
```

Delete these now-unused module-level constants (each existed only to feed the removed setup phase's dropdowns):

```ts
const CEFR_LEVELS: CefrLevel[] = ["a1", "a2", "b1", "b2", "c1", "c2"];
const WORD_COUNT_OPTIONS = [5, 10, 20, null] as const;
const DEFAULT_WORD_COUNT = 10;
```

```ts
const CEFR_DROPDOWN_OPTIONS: SimpleDropdownOption<string>[] = [
  { value: "", label: "Mọi trình độ" },
  ...CEFR_LEVELS.map((level) => ({ value: level as string, label: `Tối đa ${level.toUpperCase()}` })),
];

const WORD_COUNT_DROPDOWN_OPTIONS: SimpleDropdownOption<string>[] = WORD_COUNT_OPTIONS.map((count) => ({
  value: count === null ? "all" : String(count),
  label: count === null ? "Tất cả" : `${count} từ`,
}));
```

Keep `type CefrLevel = VocabRecord["cefrLevel"];` (still used below), `const MIN_VOCAB_WORDS = 5;` (still used below), and the exported `ReadingSessionResult` interface (unrelated to this task — leave it exactly as it is).

Rename the component and change its internals. Replace the whole `export default function BilingualReadingPage() { ... }` function (everything from that line to the file's closing `}`) with:

```tsx
function BilingualReadingPageContent() {
  const { user, loading: authLoading } = useAuthUser();
  const { settings, loading: settingsLoading } = useSettingsContext();
  const router = useRouter();
  const searchParams = useSearchParams();

  const topicIds = new Set((searchParams.get("topicIds") ?? "").split(",").filter(Boolean));
  const maxCefr = (searchParams.get("maxCefr") as CefrLevel | null) ?? null;
  const wordCountRaw = searchParams.get("wordCount");
  const wordCount = wordCountRaw === null || wordCountRaw === "all" ? null : Number(wordCountRaw);
  const action = searchParams.get("action");

  const [records, setRecords] = useState<VocabRecord[] | null>(null);
  const [topics, setTopics] = useState<Topic[]>([]);
  const [loadError, setLoadError] = useState<string | null>(null);

  const [phase, setPhase] = useState<"loading" | "session" | "result">("loading");
  const [generating, setGenerating] = useState(false);
  const [generateError, setGenerateError] = useState<string | null>(null);
  const [passage, setPassage] = useState<ReadingPassage | null>(null);
  const [currentIndex, setCurrentIndex] = useState(0);
  const [typed, setTyped] = useState("");
  const [deletedChars, setDeletedChars] = useState(0);
  const [peakMistakes, setPeakMistakes] = useState(0);
  const [sentenceStartedAt, setSentenceStartedAt] = useState(0);
  const [completedStats, setCompletedStats] = useState<SentenceStats[]>([]);
  const [sessionMode, setSessionMode] = useState<"generated" | "reused">("generated");
  const [justSavedId, setJustSavedId] = useState<string | null>(null);
  const [fetchingSaved, setFetchingSaved] = useState(false);
  const [savedNotice, setSavedNotice] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);

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
    const filters: SessionWordFilters = { topicIds, maxCefr, count: null };
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
      const usedVocabIds = await getAllUsedVocabIds(user.uid).catch(() => new Set<string>());
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
      setSessionMode("generated");
      setJustSavedId(null);
      setSaveError(null);
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
      setSavedNotice(null);
    }
  }

  async function fetchSavedExercise(excludeId?: string): Promise<boolean> {
    if (!records || !user || !settings) return false;
    const matchingCount = selectSessionWords(records, { topicIds, maxCefr, count: null }).length;
    setGenerateError(null);
    setSavedNotice(null);
    setFetchingSaved(true);
    let found = false;
    try {
      const filters: BilingualFilters = { topicIds: [...topicIds], maxCefr, wordCount };
      const saved = await getRandomSavedExercise(user.uid, settings.targetLanguage, "bilingual", filters, excludeId);
      if (saved) {
        found = true;
        setSessionMode("reused");
        setJustSavedId(null);
        setSaveError(null);
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
      } else {
        setGenerateError(
          `Hãy lưu ít nhất ${MIN_VOCAB_WORDS} từ khớp với bộ lọc đã chọn vào Ngân hàng từ vựng. Hiện có ${matchingCount} từ.`
        );
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
      router.replace("/reading");
      return;
    }
    if (triggeredRef.current) return;
    triggeredRef.current = true;
    void runAction();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [user, settings, records, action]);

  async function handleSaveExercise() {
    if (saving || !user || !settings || !passage) return;
    setSaving(true);
    setSaveError(null);
    try {
      const generationFilters: BilingualFilters = { topicIds: [...topicIds], maxCefr, wordCount };
      const newId = await saveReadingExercise(user.uid, "bilingual", passage, generationFilters, settings.targetLanguage);
      setJustSavedId(newId);
    } catch (err) {
      setSaveError(err instanceof Error ? err.message : String(err));
    } finally {
      setSaving(false);
    }
  }

  function handleTypedChange(value: string) {
    const newDeletedChars =
      value.length < typed.length ? deletedChars + (typed.length - value.length) : deletedChars;
    setTyped(value);
    setDeletedChars(newDeletedChars);

    if (!passage) return;
    const target = passage.sentences[currentIndex].target;
    const newPeakMistakes = Math.max(peakMistakes, countMismatches(target, value));
    setPeakMistakes(newPeakMistakes);

    if (value !== target) return;

    const durationMs = Date.now() - sentenceStartedAt;
    const stats = computeSentenceStats(target, value, newDeletedChars, newPeakMistakes, durationMs);
    setCompletedStats((prev) => [...prev, stats]);

    if (currentIndex + 1 < passage.sentences.length) {
      setCurrentIndex(currentIndex + 1);
      setTyped("");
      setDeletedChars(0);
      setPeakMistakes(0);
      setSentenceStartedAt(Date.now());
    } else {
      setPhase("result");
    }
  }

  function formatDuration(ms: number): string {
    const totalSeconds = Math.round(ms / 1000);
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;
    return `${minutes}:${String(seconds).padStart(2, "0")}`;
  }

  async function handleNewSession() {
    if (sessionMode === "reused") {
      // fetchSavedExercise always leaves user-visible feedback on this same
      // "result" phase now — either a new session, an AI-fallback notice, or
      // generateError — so there is no "silently did nothing" case left to
      // redirect away from, unlike the removed setup-phase fallback this
      // replaces.
      await fetchSavedExercise(justSavedId ?? undefined);
      return;
    }
    await handleGenerate();
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

  if (phase === "loading") {
    return (
      <div>
        <h2 className="scr-title">Đọc &amp; gõ</h2>
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

  const stats = aggregateSentenceStats(completedStats);
  const totalDurationMs = completedStats.reduce((sum, s) => sum + s.durationMs, 0);
  const usedRecords = (records ?? []).filter((r) => passage?.vocabIds.includes(r.id));
  const fullText = (passage?.sentences ?? []).map((s) => s.target).join(" ");

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
        <button type="button" className="btn-primary" onClick={() => void handleNewSession()}>
          Sinh bài mới
        </button>
      </div>
      {saveError && <p role="alert">{saveError}</p>}
      {savedNotice && <p className="reading-saved-notice">{savedNotice}</p>}
      {generateError && <p role="alert">{generateError}</p>}
    </div>
  );
}

export default function BilingualReadingPage() {
  return (
    <Suspense fallback={<p>Đang tải…</p>}>
      <BilingualReadingPageContent />
    </Suspense>
  );
}
```

`MIN_VOCAB_WORDS` (used in the new `fetchSavedExercise` error branch) is the existing module-level `const MIN_VOCAB_WORDS = 5;` declaration — keep it as-is; it moves from being read only by the deleted setup-phase JSX to being read here instead.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd apps/web && npx vitest run --run "src/app/(app)/reading/bilingual/page.test.tsx"`
Expected: PASS, all tests green.

- [ ] **Step 5: Run the full suite**

Run: `cd apps/web && npm test -- --run`
Expected: all tests pass (aside from the known pre-existing `bloom.test.ts` failure).

- [ ] **Step 6: Typecheck and build**

Run: `cd apps/web && npx tsc --noEmit && npm run build`
Expected: no errors, build succeeds — this specifically confirms the `<Suspense>` wrapper actually satisfies Next.js's static-generation requirement for `useSearchParams`. If the build fails with a missing-Suspense-boundary error, the wrapper is misplaced — verify `BilingualReadingPageContent` (the component actually calling `useSearchParams`) is the one wrapped, not an ancestor that doesn't call the hook.

- [ ] **Step 7: Commit**

```bash
git add "apps/web/src/app/(app)/reading/bilingual/page.tsx" "apps/web/src/app/(app)/reading/bilingual/page.test.tsx"
git commit -m "feat(web): Đọc & gõ reads filters from the URL and drops its own setup phase"
```

---

## Task 4: `part5/page.tsx` reads filters from the URL and drops its setup phase

**Files:**
- Modify: `apps/web/src/app/(app)/reading/part5/page.tsx`
- Modify: `apps/web/src/app/(app)/reading/part5/page.test.tsx`

**Interfaces:**
- Consumes: `useSearchParams` (`next/navigation`), `Suspense` (`react`) — same pattern as Task 3. Everything else (Task 1 exports) unchanged.
- Produces: nothing further — this is the plan's terminal task.

Same shape of change as Task 3, applied to Part 5: `Phase` becomes `"loading" | "session" | "result"`, `selectedTopicIds`/`selectedVolumes` are derived from `useSearchParams()` instead of mutable UI state, an effect on mount reads `action` and runs the right function, missing/invalid `action` redirects to `/reading`, and `fetchSavedExercise`'s "not found + not enough content to fall back on" path (Part 5 has no live-word concept, so this specifically means "not found and nothing else to try") now surfaces an explanatory message with retry/back-to-hub actions instead of leaving the user on a blank loading screen.

- [ ] **Step 1: Write the failing tests**

Replace the entire content of `apps/web/src/app/(app)/reading/part5/page.test.tsx` with:

```tsx
import { beforeEach, describe, expect, it, vi } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import Part5Page from "./page";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettingsContext } from "@/lib/SettingsContext";
import { getVocabRecords } from "@/lib/vocabRecords";
import { getTopics, type Topic } from "@/lib/topics";
import { generateContent } from "@/lib/generateContent";
import { getRandomSavedExercise, saveReadingExercise } from "@/lib/savedReadingExercises";
import { DEFAULT_SETTINGS, type UserSettings } from "@/lib/settings";
import type { Part5Set } from "@/lib/part5";

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

const ONE_QUESTION_SET: Part5Set = {
  questions: [{ sentenceWithBlank: "She ___ to work.", options: ["go", "goes", "going", "gone"], correctIndex: 1, explanation: "Ngôi thứ ba số ít." }],
};

beforeEach(() => {
  vi.clearAllMocks();
  setSearchParams({ action: "generate" });
  vi.mocked(getVocabRecords).mockResolvedValue([]);
  vi.mocked(getTopics).mockResolvedValue([]);
  vi.mocked(getRandomSavedExercise).mockResolvedValue(null);
});

describe("Part5Page (loading phase)", () => {
  it("prompts sign-in when logged out", () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: null, loading: false } as never);
    vi.mocked(useSettingsContext).mockReturnValue({ settings: null, loading: false, error: null, save: vi.fn() });
    render(<Part5Page />);
    expect(screen.getByText("Đăng nhập với Google")).toBeInTheDocument();
  });

  it("redirects to /reading when the action param is missing", async () => {
    setSearchParams({});
    mockSignedIn();

    render(<Part5Page />);

    await waitFor(() => expect(replaceMock).toHaveBeenCalledWith("/reading"));
  });

  it("redirects to /reading when the action param is invalid", async () => {
    setSearchParams({ action: "bogus" });
    mockSignedIn();

    render(<Part5Page />);

    await waitFor(() => expect(replaceMock).toHaveBeenCalledWith("/reading"));
  });

  it("auto-generates a set on mount, resolving topicIds to topic names in the prompt", async () => {
    setSearchParams({ topicIds: "biz-1", action: "generate" });
    mockSignedIn();
    const topics: Topic[] = [{ id: "biz-1", name: "Business", emoji: "💼", isPredefined: true, createdAt: "2026-01-01" }];
    vi.mocked(getTopics).mockResolvedValue(topics);
    vi.mocked(generateContent).mockResolvedValue({ text: JSON.stringify(ONE_QUESTION_SET) });

    render(<Part5Page />);

    expect(await screen.findByText("1. She ___ to work.")).toBeInTheDocument();
    const promptArg = vi.mocked(generateContent).mock.calls[0][0].prompt;
    expect(promptArg).toContain("exactly 15");
    expect(promptArg).toContain("Business");
  });

  it("shows an error with retry/back-to-hub actions when the active provider has no API key", async () => {
    setSearchParams({ action: "generate" });
    mockSignedIn({ ...DEFAULT_SETTINGS, activeProvider: "gemini", providers: { ...DEFAULT_SETTINGS.providers, gemini: { model: "gemini-2.5-flash", apiKeyCiphertext: null } } });

    render(<Part5Page />);

    expect(await screen.findByText("Chưa có API key cho nhà cung cấp AI đang chọn — vào Cài đặt để thêm.")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Thử lại" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Về trang chính" })).toBeInTheDocument();
    expect(generateContent).not.toHaveBeenCalled();
  });

  it("shows an error when the AI returns no usable questions, and 'Thử lại' retries the same action", async () => {
    setSearchParams({ action: "generate" });
    mockSignedIn();
    vi.mocked(generateContent).mockResolvedValueOnce({ text: JSON.stringify({}) });

    render(<Part5Page />);
    await screen.findByText("AI không trả về bài luyện hợp lệ.");

    vi.mocked(generateContent).mockResolvedValue({ text: JSON.stringify(ONE_QUESTION_SET) });
    fireEvent.click(screen.getByRole("button", { name: "Thử lại" }));

    await waitFor(() => expect(screen.getByText("1. She ___ to work.")).toBeInTheDocument());
  });

  it('"Về trang chính" on the loading-error state navigates back to the hub', async () => {
    setSearchParams({ action: "generate" });
    mockSignedIn({ ...DEFAULT_SETTINGS, activeProvider: "gemini", providers: { ...DEFAULT_SETTINGS.providers, gemini: { model: "gemini-2.5-flash", apiKeyCiphertext: null } } });

    render(<Part5Page />);
    fireEvent.click(await screen.findByRole("button", { name: "Về trang chính" }));

    expect(pushMock).toHaveBeenCalledWith("/reading");
  });

  it('action=existing starts a session directly from a matching saved exercise, without calling the AI', async () => {
    setSearchParams({ action: "existing" });
    mockSignedIn();
    vi.mocked(getRandomSavedExercise).mockResolvedValue({
      id: "saved-1",
      type: "part5",
      passage: ONE_QUESTION_SET,
      generationFilters: { topicIds: [], volumes: [] },
      targetLanguage: "english",
      createdAt: "2026-01-01T00:00:00.000Z",
    } as never);

    render(<Part5Page />);

    expect(await screen.findByText("1. She ___ to work.")).toBeInTheDocument();
    expect(generateContent).not.toHaveBeenCalled();
  });

  it("action=existing shows an inline notice and falls back to AI generation when nothing matches", async () => {
    setSearchParams({ action: "existing" });
    mockSignedIn();
    // generateContent's mock resolution is held open deliberately (instead of
    // mockResolvedValue, which settles within the same microtask burst as
    // everything upstream of it) so the notice's render commit is
    // observable before the AI fallback completes and the screen moves on
    // to the session phase — otherwise this races and the notice's visible
    // window can close before screen.findByText ever gets to see it (same
    // pattern as bilingual/page.test.tsx).
    let resolveGenerate!: (value: { text: string }) => void;
    vi.mocked(generateContent).mockReturnValue(
      new Promise((resolve) => {
        resolveGenerate = resolve;
      })
    );

    render(<Part5Page />);

    expect(await screen.findByText("Chưa có bài đã lưu khớp bộ lọc này — đang tạo bài mới bằng AI…")).toBeInTheDocument();
    expect(generateContent).toHaveBeenCalled();

    resolveGenerate({ text: JSON.stringify(ONE_QUESTION_SET) });
    await waitFor(() => expect(screen.getByText("1. She ___ to work.")).toBeInTheDocument());
  });
});

describe("Part5Page (session phase)", () => {
  async function generateSession() {
    setSearchParams({ action: "generate" });
    vi.mocked(generateContent).mockResolvedValue({
      text: JSON.stringify({
        questions: [
          { sentenceWithBlank: "She ___ to work.", options: ["go", "goes", "going", "gone"], correctIndex: 1, explanation: "A." },
          { sentenceWithBlank: "They ___ happy.", options: ["is", "am", "are", "be"], correctIndex: 2, explanation: "B." },
        ],
      }),
    });
    render(<Part5Page />);
    await screen.findByText("1. She ___ to work.");
  }

  it("keeps Nộp bài disabled until every question has an answer, then submits into the result phase", async () => {
    mockSignedIn();
    await generateSession();

    expect(screen.getByRole("button", { name: "Nộp bài" })).toBeDisabled();
    fireEvent.click(screen.getByRole("button", { name: "goes" }));
    expect(screen.getByRole("button", { name: "Nộp bài" })).toBeDisabled();
    fireEvent.click(screen.getByRole("button", { name: "are" }));
    expect(screen.getByRole("button", { name: "Nộp bài" })).not.toBeDisabled();

    fireEvent.click(screen.getByRole("button", { name: "Nộp bài" }));

    expect(await screen.findByText("2/2")).toBeInTheDocument();
  });
});

describe("Part5Page (result phase)", () => {
  async function completeSession(answers: number[]) {
    setSearchParams({ action: "generate" });
    vi.mocked(generateContent).mockResolvedValue({
      text: JSON.stringify({
        questions: [
          { sentenceWithBlank: "She ___ to work.", options: ["go", "goes", "going", "gone"], correctIndex: 1, explanation: "Giải thích A." },
        ],
      }),
    });
    render(<Part5Page />);
    await screen.findByText("1. She ___ to work.");
    fireEvent.click(screen.getByRole("button", { name: ["go", "goes", "going", "gone"][answers[0]] }));
    fireEvent.click(screen.getByRole("button", { name: "Nộp bài" }));
    await screen.findByText(/\d\/\d/);
  }

  it("shows the score, per-question breakdown with explanation, and the suggestions section", async () => {
    mockSignedIn();
    await completeSession([1]);

    expect(screen.getByText("1/1")).toBeInTheDocument();
    expect(screen.getByText("Giải thích: Giải thích A.")).toBeInTheDocument();
    const suggestions = screen.getByTestId("vocab-suggestions");
    expect(suggestions).toHaveAttribute("data-text", "She ___ to work.");
  });

  it('shows "Lưu bài" for a generated session and saves with the type "part5"', async () => {
    mockSignedIn();
    vi.mocked(saveReadingExercise).mockResolvedValue("new-id");
    await completeSession([1]);

    fireEvent.click(screen.getByRole("button", { name: "Lưu bài" }));

    expect(await screen.findByText("Đã lưu ✔")).toBeInTheDocument();
    expect(saveReadingExercise).toHaveBeenCalledWith(
      "u1",
      "part5",
      expect.objectContaining({ questions: expect.any(Array) }),
      expect.objectContaining({ topicIds: [], volumes: [] }),
      "english"
    );
  });

  it('"Bài khác" replays AI-generation directly for a generated session', async () => {
    mockSignedIn();
    await completeSession([1]);
    vi.mocked(generateContent).mockResolvedValue({
      text: JSON.stringify({ questions: [{ sentenceWithBlank: "New one.", options: ["a", "b", "c", "d"], correctIndex: 0, explanation: "E." }] }),
    });

    fireEvent.click(screen.getByRole("button", { name: "Bài khác" }));

    expect(await screen.findByText("1. New one.")).toBeInTheDocument();
  });

  it('"Về trang chính" navigates back to the reading hub', async () => {
    mockSignedIn();
    await completeSession([1]);

    fireEvent.click(screen.getByRole("button", { name: "Về trang chính" }));

    expect(pushMock).toHaveBeenCalledWith("/reading");
  });

  it('surfaces a save error via role="alert" when saveReadingExercise rejects', async () => {
    mockSignedIn();
    vi.mocked(saveReadingExercise).mockRejectedValue(new Error("network down"));
    await completeSession([1]);

    fireEvent.click(screen.getByRole("button", { name: "Lưu bài" }));

    expect(await screen.findByText("network down")).toBeInTheDocument();
    expect(screen.getByRole("alert")).toHaveTextContent("network down");
  });

  async function completeReusedSession() {
    setSearchParams({ action: "existing" });
    vi.mocked(getRandomSavedExercise).mockResolvedValue({
      id: "saved-1",
      type: "part5",
      passage: ONE_QUESTION_SET,
      generationFilters: { topicIds: [], volumes: [] },
      targetLanguage: "english",
      createdAt: "2026-01-01T00:00:00.000Z",
    } as never);
    render(<Part5Page />);
    await screen.findByText("1. She ___ to work.");
    fireEvent.click(screen.getByRole("button", { name: "goes" }));
    fireEvent.click(screen.getByRole("button", { name: "Nộp bài" }));
    await screen.findByText("1/1");
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
      type: "part5",
      passage: ONE_QUESTION_SET,
      generationFilters: { topicIds: [], volumes: [] },
      targetLanguage: "english",
      createdAt: "2026-01-01T00:00:00.000Z",
    } as never);
    render(<Part5Page />);
    await screen.findByText("1. She ___ to work.");
    fireEvent.click(screen.getByRole("button", { name: "goes" }));
    fireEvent.click(screen.getByRole("button", { name: "Nộp bài" }));
    await screen.findByText("1/1");

    vi.mocked(getRandomSavedExercise).mockResolvedValueOnce({
      id: "saved-2",
      type: "part5",
      passage: {
        questions: [{ sentenceWithBlank: "New saved one.", options: ["a", "b", "c", "d"], correctIndex: 0, explanation: "E." }],
      },
      generationFilters: { topicIds: [], volumes: [] },
      targetLanguage: "english",
      createdAt: "2026-01-01T00:00:00.000Z",
    } as never);

    fireEvent.click(screen.getByRole("button", { name: "Bài khác" }));

    expect(await screen.findByText("1. New saved one.")).toBeInTheDocument();
    expect(getRandomSavedExercise).toHaveBeenCalledTimes(2);
    expect(generateContent).not.toHaveBeenCalled();
  });
});
```

Part 5 has no live-word gate, so there is no equivalent to Task 3's "not enough live words" test — its `fetchSavedExercise` always falls through to `handleGenerate()` when nothing matches (no `else` branch blocking it), which the "shows an inline notice and falls back to AI generation" test above already covers.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd apps/web && npx vitest run --run "src/app/(app)/reading/part5/page.test.tsx"`
Expected: FAIL — the page still has its old setup-phase/button-driven flow.

- [ ] **Step 3: Rewrite the page**

Replace the entire content of `apps/web/src/app/(app)/reading/part5/page.tsx` with:

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
import { buildPart5Prompt, parsePart5Set, type Part5Set } from "@/lib/part5";
import { generateContent } from "@/lib/generateContent";
import { parseAiJsonObject } from "@/lib/parseAiJson";
import { getRandomSavedExercise, saveReadingExercise, type ToeicFilters } from "@/lib/savedReadingExercises";
import { McQuestionCard } from "@/components/reading/McQuestionCard";
import { VocabSuggestionsSection } from "@/components/shared/VocabSuggestionsSection";

type Phase = "loading" | "session" | "result";

function Part5PageContent() {
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
  const [set, setSet] = useState<Part5Set | null>(null);
  const [answers, setAnswers] = useState<(number | null)[]>([]);
  const [sessionMode, setSessionMode] = useState<"generated" | "reused">("generated");
  const [justSavedId, setJustSavedId] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);

  useEffect(() => {
    if (!user) return;
    // Best-effort: these only feed VocabSuggestionsSection on the result
    // screen, unlike Đọc & gõ they are never a hard requirement for this
    // page to function, so a failure here doesn't block anything.
    Promise.all([getVocabRecords(user.uid), getTopics(user.uid)])
      .then(([r, t]) => {
        setRecords(r);
        setTopics(t);
      })
      .catch(() => {});
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
      const prompt = buildPart5Prompt(resolvedTopicNames(), settings.targetLanguage, volumes);
      const response = await generateContent({
        provider: settings.activeProvider,
        model: activeConfig.model,
        apiKeyCiphertext: activeConfig.apiKeyCiphertext,
        prompt,
      });
      const json = parseAiJsonObject(response.text);
      const generated = parsePart5Set(json);
      if (generated.questions.length === 0) {
        throw new Error("AI không trả về bài luyện hợp lệ.");
      }
      setSessionMode("generated");
      setJustSavedId(null);
      setSaveError(null);
      setSet(generated);
      setAnswers(new Array(generated.questions.length).fill(null));
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
      const saved = await getRandomSavedExercise(user.uid, settings.targetLanguage, "part5", currentFilters(), excludeId);
      if (saved) {
        found = true;
        setSessionMode("reused");
        setJustSavedId(null);
        setSaveError(null);
        setSet(saved.passage);
        setAnswers(new Array(saved.passage.questions.length).fill(null));
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
    if (!user || !settings) return;
    if (action !== "generate" && action !== "existing") {
      router.replace("/reading");
      return;
    }
    if (triggeredRef.current) return;
    triggeredRef.current = true;
    void runAction();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [user, settings, action]);

  async function handleSaveExercise() {
    if (saving || !user || !settings || !set) return;
    setSaving(true);
    setSaveError(null);
    try {
      const newId = await saveReadingExercise(user.uid, "part5", set, currentFilters(), settings.targetLanguage);
      setJustSavedId(newId);
    } catch (err) {
      setSaveError(err instanceof Error ? err.message : String(err));
    } finally {
      setSaving(false);
    }
  }

  function handleSelectAnswer(questionIndex: number, optionIndex: number) {
    setAnswers((prev) => {
      const next = [...prev];
      next[questionIndex] = optionIndex;
      return next;
    });
  }

  async function handleNewSession() {
    if (sessionMode === "reused") {
      // fetchSavedExercise's "not found" path always falls through to
      // handleGenerate() here (Part 5 has no minimum-words precondition
      // gating it), so it always leaves the "result" phase with either a new
      // session or a generateError visible — no redirect needed.
      await fetchSavedExercise(justSavedId ?? undefined);
      return;
    }
    await handleGenerate();
  }

  if (authLoading) return <p>Đang tải…</p>;

  if (!user) {
    return (
      <div>
        <h2 className="scr-title">Part 5 — Điền câu</h2>
        <p className="scr-sub">Đăng nhập để luyện tập.</p>
        <SignInButton />
      </div>
    );
  }

  if (settingsLoading || !settings) return <p>Đang tải…</p>;

  if (phase === "loading") {
    return (
      <div>
        <h2 className="scr-title">Part 5 — Điền câu</h2>
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
        <h2 className="scr-title">Part 5 — Điền câu</h2>
        {set.questions.map((q, i) => (
          <McQuestionCard
            key={i}
            label={`${i + 1}. ${q.sentenceWithBlank}`}
            options={q.options}
            selected={answers[i]}
            onSelect={(optionIndex) => handleSelectAnswer(i, optionIndex)}
          />
        ))}
        <button className="btn-primary" onClick={() => setPhase("result")} disabled={!canSubmit}>
          Nộp bài
        </button>
      </div>
    );
  }

  const total = set?.questions.length ?? 0;
  const correctCount = (set?.questions ?? []).filter((q, i) => answers[i] === q.correctIndex).length;
  const questionsText = (set?.questions ?? []).map((q) => q.sentenceWithBlank).join(" ");

  return (
    <div>
      <h2 className="scr-title">Kết quả</h2>
      <p className="mc-score">
        {correctCount}/{total}
      </p>
      {(set?.questions ?? []).map((q, i) => (
        <McQuestionCard
          key={i}
          label={`${i + 1}. ${q.sentenceWithBlank}`}
          options={q.options}
          selected={answers[i]}
          correctIndex={q.correctIndex}
          explanation={q.explanation}
        />
      ))}
      {sessionMode === "generated" && <VocabSuggestionsSection text={questionsText} existingRecords={records} topics={topics} />}
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

export default function Part5Page() {
  return (
    <Suspense fallback={<p>Đang tải…</p>}>
      <Part5PageContent />
    </Suspense>
  );
}
```

This deletes the `SimpleDropdown`/`TopicFilterPopover` imports (no longer rendered on this page), the `[selectedTopicIds, setSelectedTopicIds]`/`[selectedVolumes, setSelectedVolumes]` state and `toggleVolume` function Task 1 introduced/kept (topics and volumes are now read-only, derived from the URL), the entire `"setup"` phase JSX block, and `resetToSetup()` (its one caller, `handleNewSession`'s `"reused"` branch on `!handled`, now calls `router.push("/reading")` directly).

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd apps/web && npx vitest run --run "src/app/(app)/reading/part5/page.test.tsx"`
Expected: PASS, all tests green.

- [ ] **Step 5: Run the full suite**

Run: `cd apps/web && npm test -- --run`
Expected: all tests pass (aside from the known pre-existing `bloom.test.ts` failure).

- [ ] **Step 6: Typecheck and build**

Run: `cd apps/web && npx tsc --noEmit && npm run build`
Expected: no errors, build succeeds.

- [ ] **Step 7: Commit**

```bash
git add "apps/web/src/app/(app)/reading/part5/page.tsx" "apps/web/src/app/(app)/reading/part5/page.test.tsx"
git commit -m "feat(web): Part 5 reads filters from the URL and drops its own setup phase"
```

---

## Final verification (after all 4 tasks)

- [ ] Run the full suite once more: `cd apps/web && npm test -- --run` — expect all tests green apart from the known pre-existing, unrelated `bloom.test.ts` failure.
- [ ] `cd apps/web && npx tsc --noEmit` — expect no errors.
- [ ] `cd apps/web && npm run build` — expect a clean production build with no missing-Suspense-boundary errors.
- [ ] Manually walk through both flows in a browser end-to-end: from `/reading`, pick a topic, pick Đọc & gõ, adjust Trình độ/Số từ, generate — confirm it lands in a typing session immediately with no intermediate setup screen. Repeat for Part 5 with Độ khó chips. Try "🔀 Lấy bài có sẵn" for both. Try navigating directly to `/reading/bilingual` and `/reading/part5` with no query string and confirm both redirect to `/reading`. Try both "Thử lại" and "Về trang chính" from a forced error state (e.g. temporarily clear the API key in Cài đặt).
