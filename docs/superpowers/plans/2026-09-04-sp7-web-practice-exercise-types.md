# SP-7: AI exercise types on the web Practice screen — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Steps use `- [ ]`.

**Goal:** The React web `/practice` (Ôn tập) session mixes in AI-generated multiple-choice / fill-in-blank / translation exercises, matching the Flutter SM-2 practice — same picker logic, same self-graded translation.

**Architecture:** New `lib/practiceExercise.ts` (discriminated union + prompt + parse + `generateExercise` via the existing `generateContent` BYOK proxy) and `lib/pickExercise.ts` (pure flashcard-vs-AI decider, port of Flutter `_pickExercise`). Three card components. `practice/page.tsx` gains a parallel `exercises` array with lookahead generation and a type switch in the session render. SM-2 / result / daily-activity flow is unchanged.

**Tech Stack:** Next.js / React (`apps/web/`), Vitest.

## Global Constraints

- **`apps/web/` only** — Flutter is untouched.
- Read `apps/web/AGENTS.md` — this Next.js has breaking changes vs training data; read `apps/web/node_modules/next/dist/docs/` before routing/RSC code. Run npm from `apps/web/`.
- Every task ends: `npm run typecheck` clean, `npm test` green (a known pre-existing order-dependent flake in `listening/dictation/page.test.tsx` is tolerated; add no new failures). Tests only go up (web ~757 at plan start).
- Ports must match Flutter **verbatim**: `buildExercisePrompt` ↔ `ExerciseGeneratorSource._buildPrompt`; `parseExercise` ↔ `_parseExercise` (unknown/malformed `type` → `flashcard`); `shouldUseFlashcard` ↔ `_pickExercise` (`sm2Repetitions === 0 || !aiAvailable` → flashcard; else `rng() < 0.30` → flashcard; else AI). `fill_in_blank.answer` stored lowercased+trimmed. Read `lib/features/practice/data/sources/exercise_generator_source.dart`, `lib/features/practice/domain/entities/exercise.dart`, `lib/features/practice/presentation/providers/practice_session_provider.dart`, and the 3 Flutter widgets (`multiple_choice_widget.dart` / `fill_in_blank_widget.dart` / `translation_exercise_widget.dart`) before writing each piece.
- `onGrade: (quality: 1 | 5) => void` is the single card→page contract (matches the existing `FlashcardCard`).
- CSS goes in `apps/web/src/styles/bloom.css` as `.pe-*` rules, consistent with existing `.fc-*` / `.btn-*`.
- Commit trailer: `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>`.

## File Structure

**Created:**
- `apps/web/src/lib/practiceExercise.ts` + `.test.ts`
- `apps/web/src/lib/pickExercise.ts` + `.test.ts`
- `apps/web/src/components/practice/MultipleChoiceCard.tsx` + `.test.tsx`
- `apps/web/src/components/practice/FillInBlankCard.tsx` + `.test.tsx`
- `apps/web/src/components/practice/TranslationCard.tsx` + `.test.tsx`

**Modified:**
- `apps/web/src/app/(app)/practice/page.tsx` + `page.test.tsx`
- `apps/web/src/styles/bloom.css`

---

## Task 1: `practiceExercise.ts` — union, prompt, parse, generate

**Files:** create `apps/web/src/lib/practiceExercise.ts` + `apps/web/src/lib/practiceExercise.test.ts`.

- [ ] Define `PracticeExercise` (the 4-member union from the spec) and re-export `AiProvider` type usage from `@/lib/generateContent`.
- [ ] `buildExercisePrompt(record: VocabRecord): string` — copy `ExerciseGeneratorSource._buildPrompt` line-for-line (word, meaning, `record.examples.slice(0,2).join("; ")`, CEFR label = `record.cefrLevel.toUpperCase()`, the three JSON shape examples, the Vietnamese-script guard).
- [ ] `parseExercise(json, record)` — port `_parseExercise`:
  - `type === "multiple_choice"` → `{type, record, question: String(json.question), options: (json.options as string[]), correctIndex: Number(json.correctIndex)}`
  - `"fill_in_blank"` → `{type, record, sentence: String(json.sentence), answer: String(json.answer).toLowerCase().trim()}`
  - `"translation"` → `{type, record, prompt: String(json.prompt), answer: String(json.answer)}`
  - anything else, OR a payload missing a required field (wrap the field reads and fall through on `undefined`/wrong shape) → `{type: "flashcard", record}`
- [ ] `generateExercise(record, ai)`:
  ```ts
  try {
    const { text } = await generateContent({ provider: ai.provider, model: ai.model, apiKeyCiphertext: ai.apiKeyCiphertext, prompt: buildExercisePrompt(record) });
    return parseExercise(parseAiJsonObject(text), record);
  } catch {
    return { type: "flashcard", record };
  }
  ```
- [ ] Tests (`vi.mock("@/lib/generateContent")`):
  - `buildExercisePrompt` includes headword, meaning, `A1`/`B2`/etc., "Vietnamese script".
  - `parseExercise` for each of the 4 shapes; unknown `type: "foo"` → flashcard; `{type:"multiple_choice"}` with no `options` → flashcard (no throw); `{type:"fill_in_blank", answer:"  RUN  "}` → `answer === "run"`.
  - `generateExercise` → flashcard when `generateContent` rejects; → parsed MC when it resolves with a valid MC JSON string.
- [ ] `npm run typecheck` + `npm test -- practiceExercise` green.
- [ ] Commit `feat(web): practiceExercise — AI exercise union + generator (port of Flutter)`.

## Task 2: `pickExercise.ts` — flashcard-vs-AI decider

**Files:** create `apps/web/src/lib/pickExercise.ts` + `.test.ts`.

- [ ] `export function shouldUseFlashcard(record: Pick<VocabRecord, "sm2Repetitions">, aiAvailable: boolean, rng: () => number = Math.random): boolean` — `record.sm2Repetitions === 0 || !aiAvailable` → `true`; else `rng() < 0.30`. (Confirm the web `VocabRecord` field is `sm2Repetitions` — grep `lib/vocabRecords.ts`; if it's named differently, use that and note it.)
- [ ] Tests: `sm2Repetitions: 0` → true (even `aiAvailable`, `rng` 0.9); `aiAvailable: false` → true; `sm2Repetitions: 3, aiAvailable, rng: () => 0.2` → true; `... rng: () => 0.5` → false.
- [ ] `npm test -- pickExercise` green.
- [ ] Commit `feat(web): pickExercise — flashcard-vs-AI decider (port of Flutter _pickExercise)`.

## Task 3: `MultipleChoiceCard`

**Files:** create `apps/web/src/components/practice/MultipleChoiceCard.tsx` + `.test.tsx`; add `.pe-mc-*` CSS to `bloom.css`.

- [ ] Props `{ exercise: Extract<PracticeExercise, {type:"multiple_choice"}>; onGrade: (q: 1 | 5) => void }`.
- [ ] Render `exercise.question` + `exercise.options.map` as buttons. Local `picked: number | null`. On click when `picked === null`: `setPicked(i)`; after `setTimeout(… , 800)` call `onGrade(i === exercise.correctIndex ? 5 : 1)` (clear the timer on unmount). While `picked !== null`: the correct option gets `.pe-mc-correct`, a wrong picked one `.pe-mc-wrong`, others disabled.
- [ ] Copy: no header needed (Flutter shows just the question centered). Match Flutter's `BloomMcOption` look loosely — a bordered pill list.
- [ ] Tests: renders question + 4 options; click the correct option → after advancing timers, `onGrade` called with `5`; click a wrong one → `1`; a second click is ignored.
- [ ] `npm test -- MultipleChoiceCard` green.
- [ ] Commit `feat(web): MultipleChoiceCard`.

## Task 4: `FillInBlankCard`

**Files:** create `FillInBlankCard.tsx` + `.test.tsx`; `.pe-fill-*` CSS.

- [ ] Props `{ exercise: Extract<…, {type:"fill_in_blank"}>; onGrade }`. `exercise.sentence.split("___")` → `parts[0]` + a blank slot + `parts[1] ?? ""`.
- [ ] A text `<input>` + "Kiểm tra" button; Enter submits. On submit: `const correct = input.trim().toLowerCase() === exercise.answer` (answer already normalized). Show ✓/✗ on the input; if wrong show `Đáp án: {exercise.answer}`. After `setTimeout(…, 1200)` → `onGrade(correct ? 5 : 1)`.
- [ ] Tests: renders the sentence around the blank; typing the exact answer (any case) + Kiểm tra → `onGrade(5)`; a wrong answer → shows "Đáp án:" and `onGrade(1)`; input disabled after submit.
- [ ] `npm test -- FillInBlankCard` green.
- [ ] Commit `feat(web): FillInBlankCard`.

## Task 5: `TranslationCard`

**Files:** create `TranslationCard.tsx` + `.test.tsx`; `.pe-tr-*` CSS.

- [ ] Props `{ exercise: Extract<…, {type:"translation"}>; onGrade }`. Show `exercise.prompt.replace("Translate to Vietnamese: ", "").replaceAll("'", "")` (match Flutter). A 2-row `<textarea>`. "Xem đáp án" button disabled while the textarea is empty. `revealed` state.
- [ ] After reveal: `Đáp án: {exercise.answer}` in a success box + two buttons "Sai rồi" (`onGrade(1)`) / "Đúng rồi" (`onGrade(5)`).
- [ ] Tests: "Xem đáp án" disabled until text entered; after reveal the answer + both grade buttons show; "Đúng rồi" → `onGrade(5)`, "Sai rồi" → `onGrade(1)`.
- [ ] `npm test -- TranslationCard` green.
- [ ] Commit `feat(web): TranslationCard`.

## Task 6: wire `practice/page.tsx`

**Files:** `apps/web/src/app/(app)/practice/page.tsx` + `apps/web/src/app/(app)/practice/page.test.tsx`.

- [ ] Import the 3 cards + `generateExercise`, `type PracticeExercise` + `shouldUseFlashcard`.
- [ ] `const aiAvailable = Boolean(settings?.providers?.[settings.activeProvider]?.apiKeyCiphertext);` (match the shape `reading/bilingual/page.tsx` uses — `settings.providers[settings.activeProvider].apiKeyCiphertext`).
- [ ] `const [exercises, setExercises] = useState<(PracticeExercise | null)[]>([])`. A `sessionTokenRef = useRef(0)`; bump it whenever a session starts.
- [ ] `const generateAt = useCallback(async (index: number, words: VocabRecord[], token: number) => { if (index < 0 || index >= words.length) return; setExercises(prev => { if (prev[index]) return prev; return prev; }); if (exercises[index]) return; const word = words[index]; let ex: PracticeExercise; if (shouldUseFlashcard(word, aiAvailable)) { ex = { type: "flashcard", record: word }; } else if (settings) { ex = await generateExercise(word, { provider: settings.activeProvider, model: settings.providers[settings.activeProvider].model, apiKeyCiphertext: settings.providers[settings.activeProvider].apiKeyCiphertext! }); } else { ex = { type: "flashcard", record: word }; } if (token !== sessionTokenRef.current) return; setExercises(prev => { const next = [...prev]; if (!next[index]) next[index] = ex; return next; }); }, [aiAvailable, settings, exercises]);` — adjust to avoid the stale-`exercises` closure trap (read via a functional `setExercises` check or a ref of the array; keep it correct, not clever).
- [ ] In BOTH session-start paths (`handleStart` and the `action === "start"` effect): after `setSessionWords(words)` etc., `const token = ++sessionTokenRef.current; setExercises(Array(words.length).fill(null));` then `void generateAt(0, words, token); void generateAt(1, words, token);`.
- [ ] In `handleGrade`, when NOT the last word (`currentIndex + 1 < sessionWords.length`): after `setCurrentIndex(currentIndex + 1)`, `void generateAt(currentIndex + 1, sessionWords, sessionTokenRef.current); void generateAt(currentIndex + 2, sessionWords, sessionTokenRef.current);`.
- [ ] `phase === "session"` render: replace the lone `<FlashcardCard>` with:
  ```tsx
  const ex = exercises[currentIndex];
  const word = sessionWords[currentIndex];
  // ... progress row unchanged ...
  {ex === null || ex === undefined ? (
    <p className="pe-loading">Đang tạo bài tập…</p>
  ) : ex.type === "flashcard" ? (
    <FlashcardCard key={word.id} record={word} onGrade={handleGrade} />
  ) : ex.type === "multiple_choice" ? (
    <MultipleChoiceCard key={word.id} exercise={ex} onGrade={handleGrade} />
  ) : ex.type === "fill_in_blank" ? (
    <FillInBlankCard key={word.id} exercise={ex} onGrade={handleGrade} />
  ) : (
    <TranslationCard key={word.id} exercise={ex} onGrade={handleGrade} />
  )}
  ```
- [ ] `.pe-loading` CSS (a centered muted line).
- [ ] Tests (`vi.mock("@/lib/practiceExercise")` — `generateExercise` mockable; keep `shouldUseFlashcard` real or mock `pickExercise` too):
  - existing flashcard-path tests still pass (with no AI key → every exercise is flashcard; assert `shouldUseFlashcard` short-circuits so `generateExercise` is never called).
  - with an AI key + `generateExercise` mocked to return an MC exercise for a `sm2Repetitions > 0` word → `MultipleChoiceCard` renders; grading it (click correct) advances and, at session end, the batch SM-2 write + `recordDailyActivity` fire (existing assertions).
  - `generateExercise` mocked to reject / return flashcard → `FlashcardCard` still shown, session still completes.
  - `sm2Repetitions === 0` word with a key set → `FlashcardCard` (generateExercise not called).
- [ ] `npm run typecheck` + `npm test -- practice` green.
- [ ] Commit `feat(web): AI exercise types in the Practice session`.

## Task 7: full gate + docs

- [ ] From `apps/web/`: `npm run typecheck` clean, `npm test` green (> plan-start count; ignore the known dictation flake).
- [ ] `README.md`: update the "Luyện tập cách khoảng" section — note web now mixes AI exercises like Flutter (was flashcard-only). Update any line that says the web practice is "zero-AI".
- [ ] `docs/superpowers/specs/2026-08-16-react-web-plan3-phase-b-part2-lookup-practice.md` is historical — do NOT edit. If `CLAUDE.md` or a memory-adjacent doc calls the web practice "zero-AI flashcard only", leave code docs alone (this plan file records the change).
- [ ] Commit `docs: SP-7 web practice AI exercise types`.

---

## Self-Review

- Spec §1 → Task 1; §2 → Task 2; §3 → Tasks 3–5; §4 → Task 6; §5 (no new controls) → nothing; testing → each task + Task 7.
- Risk: the `generateAt` closure over `exercises` — a classic stale-state bug. Task 6 must read the current array via functional `setExercises` or a ref, and the `sessionToken` guard prevents a previous session's slow response landing in a new one. The plan calls this out explicitly.
- Risk: `settings.providers[settings.activeProvider].apiKeyCiphertext` is `string | undefined` — `shouldUseFlashcard` gates on `aiAvailable` so the non-null assertion in `generateExercise`'s call site is only reached when it's present; still, type it safely.
- Type consistency: `onGrade: (quality: 1 | 5) => void` everywhere; `PracticeExercise` discriminant is `type`; the page switch covers all 4 members.
- `FlashcardCard` already exists and already takes `{record, onGrade}` — reused as-is, not rebuilt.

## Execution Handoff

Subagent-driven. 7 tasks.
