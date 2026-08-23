# TOEIC Reading Part 7 — Design

## Goal

Bring Flutter's TOEIC Part 7 "Đọc hiểu" (Reading Comprehension) exercise to the React web app, as the fourth card on the `/reading` hub alongside Đọc & gõ, Part 5, and Part 6 — reusing the hub-driven, topic-filter, save/reuse architecture already shipped twice (Part 5, Part 6), not inventing anything new.

## Background

Flutter's `lib/features/reading/{data/sources,domain/entities,presentation}/part7_*` is a complete, working, ephemeral (no persistence) implementation, read in full during brainstorming. It generates exactly 3 passage groups in a fixed order: two single-document groups (1 document each, 3 or 4 multiple-choice questions each, different document types from each other), then one double-document group (2 genuinely related documents where the second can't be fully understood without the first, exactly 5 questions, at least one requiring information from both documents). Every question has 4 options, a correct index, and a Vietnamese explanation.

Two things Part 5 and Part 6 didn't need to solve, both driven by Part 7's variable-length structure (unlike Part 5's fixed 15 questions or Part 6's fixed 3×4=12 blanks):
- **Shape validation.** Flutter's `Part7Source.generate()` parses the AI response, then separately calls a private `_hasValidShape(groups)` check (exactly 3 groups; groups 0/1 have exactly 1 document and 3-4 questions; group 2 has exactly 2 documents and exactly 5 questions) and throws if it fails. This is a stricter, structural check beyond "is it empty" — Part 5's/Part 6's web ports never throw from their parser (`parsePart5Set`/`parsePart6Set` are tolerant/defensive; the *page* throws a Vietnamese error if the parsed result is empty). Part 7 needs an explicit decision on where this check lives.
- **Variable-length flat indexing.** Part 6's flat answer index is a fixed multiplier (`passageIndex * 4 + questionIndex`) because every passage has exactly 4 blanks. Part 7's groups have 3, 4, or 5 questions each, so the flat index must sum the actual question counts of every prior group before adding the current group's question index — Flutter's own `Part7SessionState.flatIndex(allGroups, groupIndex, questionIndex)` does exactly this.

## Architecture

**`apps/web/src/lib/part7.ts`** (new file, mirrors `part6.ts`'s shape with one addition):

```ts
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

export function buildPart7Prompt(topicNames: string[], targetLanguage: TargetLanguage, volumes: EconomyVolume[]): string;
export function parsePart7Set(json: Record<string, unknown>): Part7Set;
export function hasValidPart7Shape(set: Part7Set): boolean;
```

`buildPart7Prompt` is ported from `part7_source.dart`'s prompt verbatim, with the same topic-names-not-enum adaptation and Vietnamese-script-only explanations clause every prompt in this app already carries. `parsePart7Set` is tolerant like its siblings — never throws, defaults missing/malformed fields, does no shape filtering of its own (unlike `parsePart6Set`, which drops individual malformed passages; Part 7's shape is validated as a whole via the next function instead, since a *count* mismatch here is a different kind of problem than a single malformed passage).

`hasValidPart7Shape(set)` is a **new, separately exported pure function** — the direct web equivalent of Flutter's `_hasValidShape`, checking: `passageGroups.length === 3`; for indices 0 and 1, `documents.length === 1` and `questions.length` is 3 or 4; for index 2, `documents.length === 2` and `questions.length === 5`. It does not throw — it returns a boolean, same as any other pure predicate in this codebase, and is independently unit-testable against the exact shapes Flutter's own test suite would have exercised (all 3 groups missing, wrong document counts, wrong question counts, a valid shape).

**Where the throw happens**: `apps/web/src/app/(app)/reading/part7/page.tsx`'s `handleGenerate()` calls `parsePart7Set(json)`, then checks `if (!hasValidPart7Shape(generated)) throw new Error("AI không trả về bài luyện hợp lệ.");` — the identical Vietnamese error string Part 5 and Part 6 already throw for their own "nothing usable" case, landing in the same existing loading-phase error UI (`role="alert"`, "Thử lại"/"Về trang chính"). This keeps `parsePart7Set` itself non-throwing and consistent with `parsePart5Set`/`parsePart6Set`, and keeps the "the page decides what counts as a rejectable response" responsibility exactly where it already lives for the other two Parts — `hasValidPart7Shape` is just a stricter question than "is it empty".

**`savedReadingExercises.ts`** gains one new union member:

```ts
| { id: string; type: "part7"; passage: Part7Set; generationFilters: ToeicFilters; targetLanguage: TargetLanguage; createdAt: string }
```

No function bodies change — identical to how Part 6 was added.

**Hub (`apps/web/src/app/(app)/reading/page.tsx`)**:
- `Mode` becomes `"bilingual" | "part5" | "part6" | "part7"`.
- A fourth card: title `"📖 Part 7 — Đọc hiểu"`, description `"3 nhóm văn bản, 9-13 câu hỏi đọc hiểu kiểu TOEIC."` (question count varies, unlike Part 5/6's fixed counts — the description says so rather than naming a single number).
- The existing volume-chip secondary filter block (currently gated on `mode === "part5" || mode === "part6"`) becomes gated on `mode !== "bilingual"` (equivalent to adding `|| mode === "part7"`, but shorter and matches the "Tạo bài luyện" gating condition's own existing `mode !== "bilingual"` phrasing for consistency).
- `buildQuery`'s branch gains `|| mode === "part7"` alongside `mode === "part5" || mode === "part6"`.
- `navigate()`'s mode→path map gains `"part7" → "/reading/part7"`.
- No word-count gate for Part 7, same as Part 5/6.

**`apps/web/src/app/(app)/reading/part7/page.tsx`** (new file): structurally identical to `part6/page.tsx` — same `useSearchParams()`+`Suspense` split, same `contextLoaded` gate before the auto-trigger effect, same `triggeredRef`-guarded mount effect, same `handleGenerate`/`fetchSavedExercise`/`handleSaveExercise`/`handleNewSession` shape (no word-count precondition on the saved-exercise fallback, same as Part 5/6). Local differences: `handleGenerate`'s validity check calls `hasValidPart7Shape` instead of an emptiness check; a local `flatIndex(groups, groupIndex, questionIndex)` helper sums prior groups' actual `questions.length` instead of multiplying by a fixed constant; the answers array size and the result screen's `total` are both computed as `passageGroups.reduce((sum, g) => sum + g.questions.length, 0)` instead of a fixed number.

## Session/result UI

Both phases loop `set.passageGroups` (always 3, indices 0-2):
- A heading `"Đoạn {groupIndex + 1}"`, or `"Đoạn {groupIndex + 1} (2 văn bản liên quan)"` when `group.documents.length === 2` (only ever the last group) — reusing `.reading-passage-group`/`.reading-passage-group-title` from Part 6 unchanged.
- Each of the group's 1 or 2 documents rendered as its own `.reading-passage-text` paragraph (Part 6 always rendered exactly one; Part 7 maps over `documents` instead of assuming a single string).
- That group's questions via `McQuestionCard`, labeled `"{questionNumber}. {question.question}"` where `questionNumber` is 1-indexed **within its own group** (resets per group, matching Flutter) — this is the one place Part 7's card usage differs from Part 5/6: the label carries the actual question text, not a blank-in-sentence or a "Chỗ trống (N)" marker, since `McQuestionCard`'s `label` prop already accepts an arbitrary string with no change needed to the component itself.

Answers are one flat `(number | null)[]`, sized to the group-summed total (9-13 depending on how many questions the two single-document groups got), indexed via the running-sum `flatIndex` helper described above. `handleSelectAnswer(groupIndex, questionIndex, optionIndex)` computes the flat index and updates that one slot. "Nộp bài" enabled only once every slot is non-null, same pattern as Part 5/6.

Result phase: score `X/{total}` (`total` computed the same way, reusing `.mc-score`), then the same group/document/question grouping in `McQuestionCard`'s result mode. `VocabSuggestionsSection`'s `text` prop is every group's documents flattened and joined with a space (`passageGroups.flatMap((g) => g.documents).join(" ")`, matching Flutter's `_documentsText`). `"Lưu bài"`, `"Về trang chính"`, `"Bài khác"` are unchanged from the Part 5/6 pattern.

## Error handling

Identical to Part 5/6: missing API key blocks generation with the existing inline message; `hasValidPart7Shape` returning `false` after parsing throws the same "AI không trả về bài luyện hợp lệ." error, caught into `generateError`, rendered with "Thử lại"/"Về trang chính"; "Lấy bài có sẵn" finding no match shows the inline notice then falls back to AI generation; a save failure surfaces via `role="alert"` with the save button available to retry; a bare `/reading/part7` with no `action` query param redirects to `/reading`.

## Deferred (explicitly out of scope for this spec)

- Nghe (Listening) — its own future spec, adopting this same hub-integrated pattern.
- Porting Part 7 (or any of this session's already-shipped save/reuse work) to Flutter — Flutter keeps its existing ephemeral Part 7 untouched, per the standing "web trước, Flutter sau" decision.
- Extracting a shared session hook across `part5/page.tsx`/`part6/page.tsx`/`part7/page.tsx` — flagged as worth considering once this third near-identical copy exists (per the earlier Part 6 review's own forward-looking note), but that refactor is not part of this spec; each page stays a standalone, structurally-mirrored file for now.
