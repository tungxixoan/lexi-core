# Đọc & gõ · Vocab casing · Listening speakers — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship three independent user-reported fixes: (A) Đọc & gõ advances a typing sentence on length instead of an exact match, normalizes "smart" typography in generated passages, and prompts natural word casing; (B) every vocab headword's first letter is capitalized — a one-off Firestore migration plus on every new save; (C) the listening prompt stops the internal "A"/"B" speaker labels leaking into the dialogue and the questions.

**Architecture:** Two clients — the React web app (`apps/web/`) and the Flutter app (repo root `lib/`) — each build their AI prompts client-side against thin BYOK proxies, and the two prompt sources are kept word-for-word aligned by convention. Every change here lands on both. Two tiny pure helpers are added per platform (`normalizeTypography`, `capitalizeHeadword`). The migration is a standalone `node` script under `scripts/` following the existing `migrate-vocab-records-per-language.js` pattern.

**Tech Stack:** React 19 / Next.js (breaking-changes fork — read `apps/web/AGENTS.md` + `node_modules/next/dist/docs/` before touching web code), vitest 4 + @testing-library/react; Flutter 3.41 / Dart ≥3.4, `flutter_riverpod`, `flutter_test`; Node.js + `firebase-admin` + Firestore emulator for the script.

## Global Constraints

- **Spec:** `docs/superpowers/specs/2026-09-02-reading-typing-vocab-casing-listening-speakers-design.md`. Every task's requirements implicitly include the spec's "Out of scope / not doing" list.
- **Both platforms, in lockstep.** Any prompt or typing-logic change to `apps/web/` gets the identical semantic change in the Flutter source, and vice versa. The two listening prompt builders (`buildListeningPassagePrompt` / `ListeningPassageSource._buildPrompt`) and the two reading prompt builders must stay word-for-word aligned — if you change one, change the other in the same task.
- **Web:** `apps/web/` is a modified Next.js. Read `apps/web/AGENTS.md` first. Run from `apps/web/`: `npm test` (vitest), `npm run typecheck` (`tsc --noEmit`), `npm run build` (`next build`). `apps/web/` auto-deploys to Firebase App Hosting on push to `master` — these changes WILL go live.
- **Flutter:** `flutter analyze` currently reports **12 pre-existing infos** (all `Radio`/`RadioListTile` deprecations in `settings_screen.dart` / `comprehension_session_screen.dart` / `selection_sheets.dart`). After every task it must still report **≤ 12** — zero new. Never use `withOpacity` (use `.withValues(alpha:)`); colors via `context.bloom` on any Bloom screen.
- **Tests only go up.** Web suite ~695 at start; Flutter suite 695 at start. A widget/logic change that breaks an assertion means fix the assertion's finder or update it to the new correct behavior — never weaken or delete a behavior check.
- **Vietnamese copy is fixed.** Every user-facing string that exists today stays byte-identical unless a task explicitly changes it (only Part C changes any — and only inside prompt strings, not UI).
- **Adding a test to an existing file:** copy that file's existing harness — its mocks, fakes, fixture builders, `_buildX` helpers, provider overrides — verbatim; do not invent a new setup. Where a step says "reuse this file's pattern", that means read the file, find the pattern, copy it.
- **No provider / route / entity / schema changes** except: Part B4 adds one optional named parameter (`headword`) to `VocabRecord.copyWith`. Nothing else in `lib/` domain or `apps/web/src/lib/` types changes shape.
- **Migration script safety:** dry-run is the default; writes happen only with an explicit `--apply` flag; the script prints the resolved Firebase project id and `FIRESTORE_EMULATOR_HOST` state before doing anything; it is idempotent.
- Package name: `lexi_core` (Flutter), `lexicore-web` (web), `lexicore-scripts` (`scripts/`).

---

## File Structure

**Created**
- `apps/web/src/lib/normalizeTypography.ts` + `.test.ts`
- `lib/core/utils/normalize_typography.dart` + `test/core/utils/normalize_typography_test.dart`
- `lib/features/vocabulary/domain/headword_casing.dart` + `test/features/vocabulary/domain/headword_casing_test.dart`
- `scripts/capitalize-vocab-headwords.js` + `scripts/capitalize-vocab-headwords.test.js`

**Modified**
- `apps/web/src/lib/readingPassage.ts` (+ `.test.ts`) — normalize in parse; prompt casing wording
- `apps/web/src/app/(app)/reading/bilingual/page.tsx` (+ `page.test.tsx`) — advance on length
- `apps/web/src/components/reading/TypingSentence.tsx` (+ `.test.tsx`) — `maxLength`
- `apps/web/src/lib/listeningPassage.ts` (+ `.test.ts`) — speaker-reference prompt rewrite
- `apps/web/src/lib/vocabDisplay.ts` (+ `.test.ts`) — `capitalizeHeadword`
- `apps/web/src/lib/vocabDraft.ts` (+ `.test.ts`) — capitalize on draft
- `lib/features/reading/data/sources/reading_passage_source.dart` (+ test) — normalize in `_parse`; case-insensitive `wordMap`; prompt casing wording
- `lib/features/reading/presentation/providers/reading_practice_provider.dart` (+ test) — advance on length
- `lib/features/reading/presentation/screens/reading_session_screen.dart` (+ test if present) — `maxLength` + `buildCounter`
- `lib/features/listening/data/sources/listening_passage_source.dart` (+ test) — speaker-reference prompt rewrite
- `lib/features/vocabulary/domain/entities/vocab_record.dart` — add `headword` to `copyWith`
- `lib/features/vocabulary/domain/use_cases/save_vocab_use_case.dart` (+ `test/features/vocabulary/domain/use_cases/vocab_use_cases_test.dart`) — capitalize in `execute`

**Not touched:** listening/dictation parsers (no typography normalize), the `speaker`/`gender`/`speakerGenders` schema, `app_router.dart`, the deprecated flat `vocab_records` collection's app-side code.

---

## Task 1: `normalizeTypography` helper (web + Flutter)

**Files:**
- Create: `apps/web/src/lib/normalizeTypography.ts`, `apps/web/src/lib/normalizeTypography.test.ts`
- Create: `lib/core/utils/normalize_typography.dart`, `test/core/utils/normalize_typography_test.dart`

**Interfaces:**
- Produces (web): `export function normalizeTypography(s: string): string`
- Produces (Flutter): `String normalizeTypography(String s)`

- [ ] **Step 1: Write the failing web test** — `apps/web/src/lib/normalizeTypography.test.ts`

```ts
import { describe, expect, it } from "vitest";
import { normalizeTypography } from "./normalizeTypography";

describe("normalizeTypography", () => {
  it("straightens curly single quotes and apostrophes", () => {
    expect(normalizeTypography("it’s ‘here’")).toBe("it's 'here'");
  });
  it("straightens curly double quotes and guillemets", () => {
    expect(normalizeTypography("“quote” «x»")).toBe('"quote" "x"');
  });
  it("expands the ellipsis character to three dots", () => {
    expect(normalizeTypography("wait…")).toBe("wait...");
  });
  it("collapses en/em/other dashes to a hyphen", () => {
    expect(normalizeTypography("a – b — c")).toBe("a - b - c");
  });
  it("replaces non-breaking and thin spaces with a regular space", () => {
    expect(normalizeTypography("a b c d")).toBe("a b c d");
  });
  it("straightens prime and double-prime", () => {
    expect(normalizeTypography("5′ 6″")).toBe("5' 6\"");
  });
  it("leaves plain ASCII untouched", () => {
    expect(normalizeTypography("The cat sat. It's 5-6 \"ok\".")).toBe('The cat sat. It\'s 5-6 "ok".');
  });
  it("returns an empty string unchanged", () => {
    expect(normalizeTypography("")).toBe("");
  });
});
```

- [ ] **Step 2: Run it, expect failure**

Run: `cd apps/web && npx vitest run src/lib/normalizeTypography.test.ts`
Expected: FAIL — module not found.

- [ ] **Step 3: Implement `apps/web/src/lib/normalizeTypography.ts`**

```ts
// Generated passage text sometimes comes back with "smart" punctuation
// (curly quotes, ellipsis, en/em dashes, non-breaking spaces). The Đọc & gõ
// typing flow compares what the user types against this text, and a normal
// keyboard produces the ASCII forms — so the raw smart characters are
// un-typable. Normalize them to ASCII before the text is ever shown.
const REPLACEMENTS: readonly [RegExp, string][] = [
  [/[‘’‚‛′]/g, "'"],
  [/[“”„‟«»″]/g, '"'],
  [/…/g, "..."],
  [/[–—‒―]/g, "-"],
  [/[    ]/g, " "],
];

export function normalizeTypography(s: string): string {
  let out = s;
  for (const [pattern, replacement] of REPLACEMENTS) out = out.replace(pattern, replacement);
  return out;
}
```

- [ ] **Step 4: Run web test, expect pass**

Run: `cd apps/web && npx vitest run src/lib/normalizeTypography.test.ts`
Expected: PASS (8 tests).

- [ ] **Step 5: Write the failing Flutter test** — `test/core/utils/normalize_typography_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/utils/normalize_typography.dart';

void main() {
  test('straightens curly single quotes and apostrophes', () {
    expect(normalizeTypography('it’s ‘here’'), "it's 'here'");
  });
  test('straightens curly double quotes and guillemets', () {
    expect(normalizeTypography('“quote” «x»'), '"quote" "x"');
  });
  test('expands the ellipsis character', () {
    expect(normalizeTypography('wait…'), 'wait...');
  });
  test('collapses dashes to a hyphen', () {
    expect(normalizeTypography('a – b — c'), 'a - b - c');
  });
  test('replaces non-breaking and thin spaces', () {
    expect(normalizeTypography('a b c d'), 'a b c d');
  });
  test('straightens prime and double-prime', () {
    expect(normalizeTypography('5′ 6″'), '5\' 6"');
  });
  test('leaves plain ASCII untouched', () {
    expect(normalizeTypography('The cat sat. It\'s 5-6 "ok".'),
        'The cat sat. It\'s 5-6 "ok".');
  });
  test('returns an empty string unchanged', () {
    expect(normalizeTypography(''), '');
  });
}
```

- [ ] **Step 6: Run it, expect failure**

Run: `flutter test test/core/utils/normalize_typography_test.dart`
Expected: FAIL — `normalize_typography.dart` does not exist.

- [ ] **Step 7: Implement `lib/core/utils/normalize_typography.dart`**

```dart
// Generated passage text sometimes comes back with "smart" punctuation
// (curly quotes, ellipsis, en/em dashes, non-breaking spaces). The Đọc & gõ
// typing flow compares what the user types against this text, and a normal
// keyboard produces the ASCII forms — so the raw smart characters are
// un-typable. Normalize them to ASCII before the text is ever shown.
String normalizeTypography(String s) {
  return s
      .replaceAll(RegExp('[‘’‚‛′]'), "'")
      .replaceAll(RegExp('[“”„‟«»″]'), '"')
      .replaceAll('…', '...')
      .replaceAll(RegExp('[–—‒―]'), '-')
      .replaceAll(RegExp('[    ]'), ' ');
}
```

- [ ] **Step 8: Run Flutter test + analyze, expect pass**

Run: `flutter test test/core/utils/normalize_typography_test.dart` → PASS (8 tests).
Run: `flutter analyze lib/core/utils/normalize_typography.dart test/core/utils/normalize_typography_test.dart` → No issues.

- [ ] **Step 9: Commit**

```bash
git add apps/web/src/lib/normalizeTypography.ts apps/web/src/lib/normalizeTypography.test.ts lib/core/utils/normalize_typography.dart test/core/utils/normalize_typography_test.dart
git commit -m "feat: normalizeTypography helper (curly quotes/ellipsis/dashes -> ASCII)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 2: Đọc & gõ — advance on length (web)

**Files:**
- Modify: `apps/web/src/app/(app)/reading/bilingual/page.tsx`
- Modify: `apps/web/src/components/reading/TypingSentence.tsx`
- Modify: `apps/web/src/app/(app)/reading/bilingual/page.test.tsx`
- Modify: `apps/web/src/components/reading/TypingSentence.test.tsx`

**Interfaces:**
- Consumes: `computeSentenceStats` / `countMismatches` from `@/lib/readingScoring` (unchanged), `BilingualSentence` from `@/lib/readingPassage`.

- [ ] **Step 1: Add the failing behavior test** to `apps/web/src/app/(app)/reading/bilingual/page.test.tsx`

Find the existing test that drives a full typing session (it types each `target` exactly and asserts progression to "Kết quả"). Add a sibling test:

```tsx
it("advances to the next sentence once the typed text reaches full length, even with wrong characters", async () => {
  // ...existing harness setup that lands the page in phase "session" with a
  // 2-sentence passage whose first target is a known string, e.g. "Hello world."
  const input = screen.getByTestId("reading-type-input");
  const firstTarget = "Hello world."; // from the mocked passage
  // one wrong char in the middle, typed to the exact target length
  const wrong = "Hello worlx." ;
  fireEvent.change(input, { target: { value: wrong } });
  // it advanced: the progress counter now shows sentence 2
  expect(await screen.findByText(/Câu 2 \//)).toBeInTheDocument();
});
```

(Match the harness the file already uses — mocked `generateContent`, `getVocabRecords`, `useAuthUser`, etc. Reuse the existing passage fixture; if it has only one sentence, extend the fixture to two so "advanced" is observable.)

- [ ] **Step 2: Run it, expect failure**

Run: `cd apps/web && npx vitest run "src/app/(app)/reading/bilingual/page.test.tsx"`
Expected: FAIL — stays on "Câu 1 /" because `value !== target`.

- [ ] **Step 3: Change the advance condition** in `bilingual/page.tsx` `handleTypedChange`

Replace this line:
```tsx
    if (value !== target) return;
```
with:
```tsx
    if (value.length < target.length) return;
```
Everything below it (the `computeSentenceStats` call, `setCompletedStats`, the `currentIndex + 1 < …` branch, `setPhase("result")`) is unchanged — `computeSentenceStats(target, value, …)` already scores per character and tolerates a `value` with wrong characters.

- [ ] **Step 4: Cap the input** in `TypingSentence.tsx`

Add `maxLength={target.length}` to the `<input className="reading-type-input" …>` (a `const target = currentSentence.target;` already exists at the top of the component).

- [ ] **Step 5: Update `TypingSentence.test.tsx`**

Add:
```tsx
it("caps the input at the target sentence length", () => {
  render(
    <TypingSentence
      completedSentences={[]}
      currentSentence={{ target: "Hi there.", vietnamese: "Chào.", vocabWords: [] }}
      typed=""
      onTypedChange={() => {}}
    />
  );
  expect(screen.getByTestId("reading-type-input")).toHaveAttribute("maxLength", "9");
});
```

- [ ] **Step 6: Run the affected tests, expect pass**

Run: `cd apps/web && npx vitest run "src/app/(app)/reading/bilingual/page.test.tsx" src/components/reading/TypingSentence.test.tsx`
Expected: PASS. Fix any existing assertion that assumed exact-match gating (there should be none — the existing full-session test types exact text, which still satisfies `value.length >= target.length`).

- [ ] **Step 7: typecheck + build**

Run: `cd apps/web && npm run typecheck && npm run build`
Expected: both succeed.

- [ ] **Step 8: Commit**

```bash
git add "apps/web/src/app/(app)/reading/bilingual/page.tsx" apps/web/src/components/reading/TypingSentence.tsx "apps/web/src/app/(app)/reading/bilingual/page.test.tsx" apps/web/src/components/reading/TypingSentence.test.tsx
git commit -m "feat(web): Đọc & gõ advances a sentence on full length, not an exact match

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 3: Đọc & gõ — advance on length + typography + casing bug (Flutter)

**Files:**
- Modify: `lib/features/reading/presentation/providers/reading_practice_provider.dart`
- Modify: `lib/features/reading/presentation/screens/reading_session_screen.dart`
- Modify: `lib/features/reading/data/sources/reading_passage_source.dart`
- Modify: `test/features/reading/presentation/providers/reading_practice_provider_test.dart`
- Modify: `test/features/reading/data/sources/reading_passage_source_test.dart`
- Modify (if it exists): `test/features/reading/presentation/screens/reading_session_screen_test.dart`

**Interfaces:**
- Consumes: `normalizeTypography` from `package:lexi_core/core/utils/normalize_typography.dart` (Task 1).

- [ ] **Step 1: Failing test — advance on length** in `reading_practice_provider_test.dart`

```dart
test('advances to the next sentence when typed length reaches the target, '
    'recording a SentenceResult with correctChars < totalChars for a wrong char', () {
  // build a notifier whose state has a 2-sentence passage; first target = 'Hello world.'
  // (reuse this file's existing fixture builder / _FakeUseCase pattern)
  notifier.updateTypedText('Hello worlx.'); // full length, one wrong char
  final state = container.read(readingPracticeNotifierProvider).value!;
  expect(state.currentSentenceIndex, 1);
  expect(state.completedSentences.single.correctChars, lessThan(state.completedSentences.single.totalChars));
});
```

- [ ] **Step 2: Run it, expect failure** — `flutter test test/features/reading/presentation/providers/reading_practice_provider_test.dart` — FAIL (index stays 0).

- [ ] **Step 3: Change the advance condition** in `updateTypedText`

Replace:
```dart
    if (text == current.currentSentence.target) {
```
with:
```dart
    if (text.length >= current.currentSentence.target.length) {
```
`_advance` is unchanged — its `for (i < typed.length && i < target.length) if (typed[i] == target[i]) correctChars++` already handles a wrong-character `typed`.

- [ ] **Step 4: Cap the field** in `reading_session_screen.dart` `_TypingArea`'s `TextField` (around line 410)

The component already receives `target` (`_TypingArea({required this.target, …})`). Cap the input with an `inputFormatter` (not `maxLength` — that renders a character-counter row the Bloom design doesn't want):
```dart
            inputFormatters: [LengthLimitingTextInputFormatter(target.length)],
```
`LengthLimitingTextInputFormatter` is from `package:flutter/services.dart` — verify the import is already present (the file imports `services.dart` for `Clipboard`); add it if not.

- [ ] **Step 5: Normalize typography + fix the case-sensitive `wordMap`** in `reading_passage_source.dart`

Add the import: `import '../../../../core/utils/normalize_typography.dart';`

In `_parse`, change the `BilingualSentence` construction:
```dart
      return BilingualSentence(
        target: normalizeTypography(sm['target'] as String),
        vietnamese: normalizeTypography(sm['vietnamese'] as String),
        vocabIds: vocabIds,
      );
```

In `generate`, change the word map to lowercase keys:
```dart
    final wordMap = {for (final w in words) w.headword.toLowerCase(): w.id};
```
and in `_parse` change the lookup:
```dart
      final vocabIds =
          vocabWords.map((w) => wordMap[w.toLowerCase()]).whereType<String>().toList();
```

- [ ] **Step 6: Test the passage-source changes** in `reading_passage_source_test.dart`

Add two cases (reuse the file's `GenerativeModelClient` fake — it returns a canned JSON string):
```dart
test('normalizes smart quotes in target and vietnamese', () async {
  // fake returns: {"sentences":[{"target":"It’s “ok”.","vietnamese":"“Tốt”…","vocabWords":[]}]}
  final passage = await source.generate(words: [], level: CEFRLevel.b1,
      context: AppContext.general, targetLanguage: Language.english);
  expect(passage.sentences.single.target, 'It\'s "ok".');
  expect(passage.sentences.single.vietnamese, '"Tốt"...');
});

test('resolves a vocabId when the AI returns a differently-cased word', () async {
  final record = /* a VocabRecord with headword 'Report' */;
  // fake returns: {"sentences":[{"target":"He sent the report.","vietnamese":"...","vocabWords":["report"]}]}
  final passage = await source.generate(words: [record], level: CEFRLevel.b1,
      context: AppContext.general, targetLanguage: Language.english);
  expect(passage.sentences.single.vocabIds, [record.id]);
});
```

- [ ] **Step 7: Run the reading tests + analyze**

Run: `flutter test test/features/reading/` → all pass.
Run: `flutter analyze` → ≤ 12 infos, zero new.

- [ ] **Step 8: Commit**

```bash
git add lib/features/reading/presentation/providers/reading_practice_provider.dart lib/features/reading/presentation/screens/reading_session_screen.dart lib/features/reading/data/sources/reading_passage_source.dart test/features/reading/
git commit -m "feat(reading): Đọc & gõ advances on length; normalize passage typography; case-insensitive vocab match

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 4: Reading passage — normalize typography + casing prompt (web)

**Files:**
- Modify: `apps/web/src/lib/readingPassage.ts`
- Modify: `apps/web/src/lib/readingPassage.test.ts`

**Interfaces:**
- Consumes: `normalizeTypography` from `@/lib/normalizeTypography` (Task 1).

- [ ] **Step 1: Failing test** in `readingPassage.test.ts`

```ts
it("normalizes smart typography in target and vietnamese", () => {
  const passage = parseReadingPassage(
    { sentences: [{ target: "It’s “ok”.", vietnamese: "“Tốt”…", vocabWords: [] }] },
    []
  );
  expect(passage.sentences[0].target).toBe('It\'s "ok".');
  expect(passage.sentences[0].vietnamese).toBe('"Tốt"...');
});

it("prompt tells the model to use natural sentence-position capitalization", () => {
  const prompt = buildReadingPassagePrompt(["Report", "Follow up"], "english", null);
  expect(prompt).toMatch(/natural .*capitali[sz]ation/i);
  expect(prompt).not.toMatch(/exactly as given/);
});
```

- [ ] **Step 2: Run it, expect failure**

Run: `cd apps/web && npx vitest run src/lib/readingPassage.test.ts`
Expected: FAIL both new cases.

- [ ] **Step 3: Normalize in `parseReadingPassage`**

Add `import { normalizeTypography } from "./normalizeTypography";` and change the `sentences` map:
```ts
  const sentences: BilingualSentence[] = rawSentences.map((raw) => ({
    target: normalizeTypography(typeof raw.target === "string" ? raw.target : ""),
    vietnamese: normalizeTypography(typeof raw.vietnamese === "string" ? raw.vietnamese : ""),
    vocabWords: Array.isArray(raw.vocabWords) ? raw.vocabWords.map(String) : [],
  }));
```

- [ ] **Step 4: Casing instruction in `buildReadingPassagePrompt`**

Insert, right after the `using as many of these words as possible, naturally: …` clause and before `${levelClause}`:
```ts
    `Use natural ${languageLabel} capitalization based on each word's position in the sentence — ` +
    `lowercase mid-sentence unless the word is a proper noun; do not copy the capitalization of the word list. ` +
```
And change the `vocabWords` JSON-shape clause from:
```ts
    `"vocabWords":["which of the given words appear in this sentence, exactly as given"]}]} ` +
```
to:
```ts
    `"vocabWords":["which of the given words appear in this sentence (any capitalization is fine)"]}]} ` +
```

- [ ] **Step 5: Run + typecheck + build**

Run: `cd apps/web && npx vitest run src/lib/readingPassage.test.ts && npm run typecheck && npm run build`
Expected: all pass. `highlightVocabWords` (regex `i` flag) and `parseReadingPassage`'s `headwordToId` (`.toLowerCase()`) are already case-insensitive — no other change needed.

- [ ] **Step 6: Commit**

```bash
git add apps/web/src/lib/readingPassage.ts apps/web/src/lib/readingPassage.test.ts
git commit -m "feat(web): normalize reading passage typography; prompt natural word casing

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 5: Reading passage — casing prompt (Flutter)

**Files:**
- Modify: `lib/features/reading/data/sources/reading_passage_source.dart`
- Modify: `test/features/reading/data/sources/reading_passage_source_test.dart`

- [ ] **Step 1: Failing prompt test** in `reading_passage_source_test.dart` — assert `_buildPrompt` output. If the test file has no prompt-string test yet, add one that generates a passage and captures the prompt via the fake client (or expose `_buildPrompt` for test as the file's style allows — check how `part5_source_test.dart` etc. assert prompts). The assertion:

```dart
// prompt contains a natural-capitalization instruction and no "exactly as given"
expect(capturedPrompt, contains('natural'));
expect(capturedPrompt.toLowerCase(), contains('capitaliz'));
expect(capturedPrompt, isNot(contains('only words from the provided list that appear in this sentence')));
```

- [ ] **Step 2: Run, expect failure.**

- [ ] **Step 3: Edit `_buildPrompt`** in `reading_passage_source.dart`

After the `'Naturally use as many of these vocabulary words as possible: $wordList. '` line, add:
```dart
        'Use natural ${targetLanguage.label} capitalization based on each word\'s position in the sentence — '
        'lowercase mid-sentence unless the word is a proper noun; do not copy the capitalization of the word list. '
```
Change the `vocabWords` list-instruction clause from:
```dart
        'For each sentence, provide its Vietnamese translation and list which vocabulary words '
        'from the input list appear in that sentence (only words from the input list, not the extra ones). '
```
to:
```dart
        'For each sentence, provide its Vietnamese translation and list which vocabulary words '
        'from the input list appear in that sentence, matched case-insensitively (only words from the input list, not the extra ones). '
```
and the JSON-shape clause from:
```dart
        '"vocabWords": ["only words from the provided list that appear in this sentence"]}]}';
```
to:
```dart
        '"vocabWords": ["words from the provided list that appear in this sentence (any capitalization)"]}]}';
```

Keep this wording semantically aligned with Task 4's web wording.

- [ ] **Step 4: Run + analyze**

Run: `flutter test test/features/reading/data/sources/reading_passage_source_test.dart` → pass.
Run: `flutter analyze` → ≤ 12, zero new.

- [ ] **Step 5: Commit**

```bash
git add lib/features/reading/data/sources/reading_passage_source.dart test/features/reading/data/sources/reading_passage_source_test.dart
git commit -m "feat(reading): prompt natural word casing in the Đọc & gõ passage (Flutter)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 6: `capitalizeHeadword` helper (web + Flutter)

**Files:**
- Modify: `apps/web/src/lib/vocabDisplay.ts`, `apps/web/src/lib/vocabDisplay.test.ts`
- Create: `lib/features/vocabulary/domain/headword_casing.dart`, `test/features/vocabulary/domain/headword_casing_test.dart`

**Interfaces:**
- Produces (web): `export function capitalizeHeadword(s: string): string`
- Produces (Flutter): `String capitalizeHeadword(String s)`

- [ ] **Step 1: Failing web test** — add to `apps/web/src/lib/vocabDisplay.test.ts`

```ts
import { capitalizeHeadword } from "./vocabDisplay";
describe("capitalizeHeadword", () => {
  it.each([
    ["follow up", "Follow up"],
    ["Follow up", "Follow up"],
    ["TOEIC", "TOEIC"],
    ["iPhone", "IPhone"],
    ["3D printing", "3D printing"],
    ["đẹp", "Đẹp"], // "đẹp" -> "Đẹp"
    ["", ""],
  ])("capitalizeHeadword(%j) === %j", (input, expected) => {
    expect(capitalizeHeadword(input)).toBe(expected);
  });
});
```

- [ ] **Step 2: Run, expect failure** — `cd apps/web && npx vitest run src/lib/vocabDisplay.test.ts`.

- [ ] **Step 3: Implement in `apps/web/src/lib/vocabDisplay.ts`**

```ts
// Vocab bank headwords are stored with a capital first letter ("Follow up",
// not "follow up") for consistent display. Applied on every new save and by
// the one-off `scripts/capitalize-vocab-headwords.js` migration. Idempotent;
// leaves already-capitalized, acronym, and non-letter-initial words alone.
export function capitalizeHeadword(s: string): string {
  const first = s[0];
  if (first && first.toLowerCase() === first && first.toUpperCase() !== first) {
    return first.toUpperCase() + s.slice(1);
  }
  return s;
}
```

- [ ] **Step 4: Run web test, expect pass.**

- [ ] **Step 5: Failing Flutter test** — `test/features/vocabulary/domain/headword_casing_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/vocabulary/domain/headword_casing.dart';

void main() {
  const cases = {
    'follow up': 'Follow up',
    'Follow up': 'Follow up',
    'TOEIC': 'TOEIC',
    'iPhone': 'IPhone',
    '3D printing': '3D printing',
    'đẹp': 'Đẹp',
    '': '',
  };
  cases.forEach((input, expected) {
    test('capitalizeHeadword("$input") == "$expected"', () {
      expect(capitalizeHeadword(input), expected);
    });
  });
}
```

- [ ] **Step 6: Run, expect failure.**

- [ ] **Step 7: Implement `lib/features/vocabulary/domain/headword_casing.dart`**

```dart
// Vocab bank headwords are stored with a capital first letter ("Follow up",
// not "follow up") for consistent display. Applied on every new save and by
// the one-off scripts/capitalize-vocab-headwords.js migration. Idempotent;
// leaves already-capitalized, acronym, and non-letter-initial words alone.
String capitalizeHeadword(String s) {
  if (s.isEmpty) return s;
  final first = s[0];
  if (first.toLowerCase() == first && first.toUpperCase() != first) {
    return first.toUpperCase() + s.substring(1);
  }
  return s;
}
```

- [ ] **Step 8: Run Flutter test + analyze, expect pass** — `flutter test test/features/vocabulary/domain/headword_casing_test.dart`; `flutter analyze lib/features/vocabulary/domain/headword_casing.dart` → No issues.

- [ ] **Step 9: Commit**

```bash
git add apps/web/src/lib/vocabDisplay.ts apps/web/src/lib/vocabDisplay.test.ts lib/features/vocabulary/domain/headword_casing.dart test/features/vocabulary/domain/headword_casing_test.dart
git commit -m "feat: capitalizeHeadword helper (idempotent first-letter capitalization)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 7: Capitalize headword on new-vocab save (web + Flutter)

**Files:**
- Modify: `apps/web/src/lib/vocabDraft.ts`, `apps/web/src/lib/vocabDraft.test.ts`
- Modify: `lib/features/vocabulary/domain/entities/vocab_record.dart`
- Modify: `lib/features/vocabulary/domain/use_cases/save_vocab_use_case.dart`
- Modify: `test/features/vocabulary/domain/use_cases/vocab_use_cases_test.dart`

**Interfaces:**
- Consumes: `capitalizeHeadword` (Task 6) — web from `./vocabDisplay`, Flutter from `package:lexi_core/features/vocabulary/domain/headword_casing.dart`.
- Produces: `VocabRecord.copyWith` gains `String? headword`.

- [ ] **Step 1: Failing web test** in `vocabDraft.test.ts`

```ts
it("capitalizes the first letter of the headword", () => {
  const draft = buildVocabRecordDraft(
    { headword: "follow up", /* …rest of a minimal WordPhraseResult… */ } as WordPhraseResult,
    [],
    "english"
  );
  expect(draft.headword).toBe("Follow up");
});
```

- [ ] **Step 2: Run, expect failure.**

- [ ] **Step 3: Edit `vocabDraft.ts`**

Add `import { capitalizeHeadword } from "./vocabDisplay";` and change `headword: result.headword,` to `headword: capitalizeHeadword(result.headword),`.

- [ ] **Step 4: Run web test + typecheck, expect pass.**

- [ ] **Step 5: Add `headword` to `VocabRecord.copyWith`** in `vocab_record.dart`

Add `String? headword,` to the parameter list and `headword: headword ?? this.headword,` in the returned `VocabRecord(...)` (it currently hard-passes `headword: headword` — change to the null-coalescing form; verify no other field is being shadowed).

- [ ] **Step 6: Failing Flutter test** in `vocab_use_cases_test.dart` (the `SaveVocabUseCase` group)

```dart
test('capitalizes the headword before checking for duplicates and saving', () async {
  final repo = _FakeVocabRepository(); // reuse the file's existing fake
  final useCase = SaveVocabUseCase(repo);
  await useCase.execute(_record(headword: 'follow up')); // reuse the file's record builder
  expect(repo.saved.single.headword, 'Follow up');
});
```

- [ ] **Step 7: Run, expect failure.**

- [ ] **Step 8: Edit `save_vocab_use_case.dart`**

```dart
import '../headword_casing.dart';
// ...
  Future<void> execute(VocabRecord record) async {
    final normalized = record.copyWith(headword: capitalizeHeadword(record.headword));
    if (normalized.inputType == InputType.sentence) {
      throw const VocabException('Sentences cannot be saved to Vocabulary Bank.');
    }
    if (normalized.topicIds.length > 2) {
      throw const VocabException('A word can have at most 2 topic tags.');
    }
    final exists = await _repo.existsByHeadword(normalized.headword, normalized.targetLanguage);
    if (exists) {
      throw VocabException('"${normalized.headword}" is already in your Vocabulary Bank.');
    }
    return _repo.save(normalized);
  }
```
(`getByHeadword` — which `existsByHeadword` delegates to — already lower-cases both sides, so capitalizing does not create false negatives.)

- [ ] **Step 9: Run + analyze**

Run: `flutter test test/features/vocabulary/` → all pass. Update any existing `SaveVocabUseCase` test that asserted a lowercase headword round-tripped verbatim.
Run: `flutter analyze` → ≤ 12, zero new.

- [ ] **Step 10: Commit**

```bash
git add apps/web/src/lib/vocabDraft.ts apps/web/src/lib/vocabDraft.test.ts lib/features/vocabulary/domain/entities/vocab_record.dart lib/features/vocabulary/domain/use_cases/save_vocab_use_case.dart test/features/vocabulary/domain/use_cases/vocab_use_cases_test.dart
git commit -m "feat(vocab): capitalize the headword first letter on every new save

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 8: Firestore migration script — `capitalize-vocab-headwords.js`

**Files:**
- Create: `scripts/capitalize-vocab-headwords.js`
- Create: `scripts/capitalize-vocab-headwords.test.js`

**Interfaces:**
- Produces: `module.exports = { capitalizeHeadword, capitalizeVocabHeadwords }` where `capitalizeVocabHeadwords(db, { apply }) => Promise<{ scanned, toChange, changed, skipped }>`.

- [ ] **Step 1: Write the failing test** — `scripts/capitalize-vocab-headwords.test.js` (Node built-in test runner, Firestore emulator — mirror `migrate-vocab-records-per-language.test.js`'s setup: `@firebase/rules-unit-testing` or a direct `firebase-admin` pointed at `FIRESTORE_EMULATOR_HOST`, whichever the sibling test uses).

```js
const { test } = require("node:test");
const assert = require("node:assert/strict");
const { capitalizeHeadword, capitalizeVocabHeadwords } = require("./capitalize-vocab-headwords");

test("capitalizeHeadword rules", () => {
  assert.equal(capitalizeHeadword("follow up"), "Follow up");
  assert.equal(capitalizeHeadword("Follow up"), "Follow up");
  assert.equal(capitalizeHeadword("TOEIC"), "TOEIC");
  assert.equal(capitalizeHeadword("3D printing"), "3D printing");
});

test("dry run reports changes without writing; --apply writes; re-run is a no-op", async () => {
  const db = /* emulator Firestore handle, per the sibling test */;
  // seed: users/u1/vocab_records_english/{a:{headword:"apple"}, b:{headword:"Banana"}}
  //       users/u2/vocab_records_vietnamese/{c:{headword:"cam"}}
  //       users/u1/vocab_records/{d:{headword:"date"}}   (flat backup)
  const dry = await capitalizeVocabHeadwords(db, { apply: false });
  assert.equal(dry.toChange, 3);           // apple, cam, date
  assert.equal(dry.changed, 0);
  // store unchanged
  assert.equal((await db.doc("users/u1/vocab_records_english/a").get()).data().headword, "apple");

  const applied = await capitalizeVocabHeadwords(db, { apply: true });
  assert.equal(applied.changed, 3);
  assert.equal((await db.doc("users/u1/vocab_records_english/a").get()).data().headword, "Apple");
  assert.equal((await db.doc("users/u2/vocab_records_vietnamese/c").get()).data().headword, "Cam");
  assert.equal((await db.doc("users/u1/vocab_records/d").get()).data().headword, "Date");

  const again = await capitalizeVocabHeadwords(db, { apply: true });
  assert.equal(again.toChange, 0);
  assert.equal(again.changed, 0);
});

test("a missing or non-string headword is skipped, not thrown", async () => {
  const db = /* emulator */;
  // seed users/u1/vocab_records_english/{x:{}, y:{headword: 42}}
  const r = await capitalizeVocabHeadwords(db, { apply: true });
  assert.equal(r.skipped >= 2, true);
});
```

- [ ] **Step 2: Run it, expect failure** — `cd scripts && node --test capitalize-vocab-headwords.test.js` — module not found.

- [ ] **Step 3: Implement `scripts/capitalize-vocab-headwords.js`**

```js
// scripts/capitalize-vocab-headwords.js
//
// One-time, idempotent migration: capitalize the first letter of every vocab
// `headword` across all users. Runs against:
//   - users/{uid}/vocab_records_{lang}  for lang in the 5 supported languages
//   - users/{uid}/vocab_records         (the deprecated flat backup collection)
//
// DRY RUN BY DEFAULT: prints "from -> to" for every change and the totals,
// writes nothing. Pass --apply to actually write (batched, updatedAt bumped).
// No backup collection is taken — the transform (lowercase first letter ->
// uppercase) is trivially inspectable and reversible, and the dry run is the
// safety net. Discovers docs via collectionGroup (see the sibling
// migrate-vocab-records-per-language.js for why users/ is not listable).

const LANGUAGES = ["vietnamese", "english", "chinese", "korean", "japanese"];
const COLLECTION_IDS = [...LANGUAGES.map((l) => `vocab_records_${l}`), "vocab_records"];

function capitalizeHeadword(s) {
  if (typeof s !== "string" || s.length === 0) return s;
  const first = s[0];
  if (first.toLowerCase() === first && first.toUpperCase() !== first) {
    return first.toUpperCase() + s.slice(1);
  }
  return s;
}

async function capitalizeVocabHeadwords(db, { apply } = { apply: false }) {
  let scanned = 0;
  let skipped = 0;
  const changes = []; // { ref, from, to }

  for (const collectionId of COLLECTION_IDS) {
    const snap = await db.collectionGroup(collectionId).get();
    for (const doc of snap.docs) {
      scanned++;
      const from = doc.get("headword");
      if (typeof from !== "string" || from.length === 0) {
        skipped++;
        continue;
      }
      const to = capitalizeHeadword(from);
      if (to === from) {
        skipped++;
        continue;
      }
      changes.push({ ref: doc.ref, from, to });
    }
  }

  for (const c of changes) console.log(`${apply ? "CHANGE" : "would change"}  ${c.ref.path}  ${JSON.stringify(c.from)} -> ${JSON.stringify(c.to)}`);

  let changed = 0;
  if (apply) {
    for (let i = 0; i < changes.length; i += 400) {
      const batch = db.batch();
      for (const c of changes.slice(i, i + 400)) {
        batch.update(c.ref, { headword: c.to, updatedAt: new Date().toISOString() });
      }
      await batch.commit();
      changed += Math.min(400, changes.length - i);
    }
  }

  console.log(`\n${apply ? "Applied" : "Dry run"}: scanned ${scanned}, ${apply ? "changed" : "would change"} ${changes.length}, skipped ${skipped}.`);
  return { scanned, toChange: changes.length, changed, skipped };
}

module.exports = { capitalizeHeadword, capitalizeVocabHeadwords };

// Run directly against real Firestore:
//   node scripts/capitalize-vocab-headwords.js            (dry run)
//   node scripts/capitalize-vocab-headwords.js --apply    (write)
// Requires GOOGLE_APPLICATION_CREDENTIALS or `gcloud auth application-default login`.
if (require.main === module) {
  const { initializeApp } = require("firebase-admin/app");
  const { getFirestore } = require("firebase-admin/firestore");
  const app = initializeApp();
  const db = getFirestore(app);
  const apply = process.argv.includes("--apply");

  console.log(`Resolved Firebase project id: ${app.options.projectId}`);
  console.log(
    `FIRESTORE_EMULATOR_HOST: ${
      process.env.FIRESTORE_EMULATOR_HOST
        ? `${process.env.FIRESTORE_EMULATOR_HOST} (EMULATOR — not production!)`
        : "(not set — targeting real Firestore)"
    }`
  );
  console.log(apply ? "MODE: --apply (writing)\n" : "MODE: dry run (no writes) — pass --apply to write\n");

  capitalizeVocabHeadwords(db, { apply })
    .then((r) => {
      if (r.scanned === 0) {
        console.error("WARNING: 0 documents scanned — wrong project/environment? No changes made.");
        process.exit(1);
      }
      process.exit(0);
    })
    .catch((err) => {
      console.error("Failed:", err);
      process.exit(1);
    });
}
```

- [ ] **Step 4: Run the test, expect pass** — `cd scripts && node --test capitalize-vocab-headwords.test.js` (start the Firestore emulator first if the sibling test requires it — mirror its npm script / setup exactly).

- [ ] **Step 5: Commit**

```bash
git add scripts/capitalize-vocab-headwords.js scripts/capitalize-vocab-headwords.test.js
git commit -m "feat(scripts): capitalize-vocab-headwords migration (dry-run default, idempotent)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 9: Listening prompt — speaker references (web + Flutter)

**Files:**
- Modify: `apps/web/src/lib/listeningPassage.ts`, `apps/web/src/lib/listeningPassage.test.ts`
- Modify: `lib/features/listening/data/sources/listening_passage_source.dart`, its test file

**Interfaces:** none change — `buildListeningPassagePrompt` / `_buildPrompt` signatures, the returned JSON shape line, and `parseListeningPassage` / `_parse` are all unchanged.

- [ ] **Step 1: Update the failing web prompt test** in `listeningPassage.test.ts`

Find the assertions on the current wording (`labeled "A" and "B"`, `alternating between "A" and "B"`) and replace with:
```ts
it("keeps A/B as structural speaker labels but forbids them in the dialogue and questions", () => {
  const prompt = buildListeningPassagePrompt("b1", "general", "english");
  // still asks for the structural label in the JSON shape
  expect(prompt).toContain('"speaker": "A" or "B" or null');
  // dialogue rule
  expect(prompt).toMatch(/never appear .*in any turn|must not use the letters "A"\/"B"|address each other by name/i);
  // question-reference rule
  expect(prompt).toMatch(/người đàn ông.*người phụ nữ/i);
  expect(prompt).toMatch(/role in the situation|khách hàng|nhân viên/i);
});
```
(Adjust the exact regexes to the wording you write in Step 3 — the point is: label kept in JSON shape, letters banned from text, gender/role/name rules for questions present.)

- [ ] **Step 2: Run, expect failure.**

- [ ] **Step 3: Rewrite the conversation + question clauses** in `buildListeningPassagePrompt` (`listeningPassage.ts`)

Replace the format-(1) clause and add the reference rules. The new relevant middle of the prompt (keep the outer sentences — "You are creating a TOEIC-style…", the gender clause, the "exactly 3 multiple-choice questions" clause, the JSON shape — as they are today):

```ts
    `(1) a CONVERSATION between exactly two speakers. In the JSON, label them "A" and "B" ` +
    `(these are internal labels for voice selection only). The letters "A" and "B" must NEVER ` +
    `appear in any turn's spoken text or in any question — the speakers address each other by ` +
    `first name or by pronoun, never as "A" or "B". Use 3 to 6 turns alternating between the two speakers ` +
    `(e.g. at an office, store, or while traveling); or ` +
```

And insert, right before the `Respond with JSON only` clause:

```ts
    `In the questions, refer to a speaker as follows and never as "A" or "B": ` +
    `if the two speakers are one male and one female, call them "người đàn ông" and "người phụ nữ"; ` +
    `if the two speakers are the same gender, refer to them by their role in the situation when there is ` +
    `a clear one ("khách hàng", "nhân viên", "quản lý", "lễ tân", ...), otherwise by the first name used ` +
    `in the dialogue; for a talk with one speaker, call them "người nói". ` +
```

- [ ] **Step 4: Apply the identical change to Flutter** `ListeningPassageSource._buildPrompt` (`listening_passage_source.dart`) — same wording, Dart string concatenation, `${targetLanguage.label}` where the web uses `${languageLabel}`. Keep the `{"speaker": "A" or "B" or null, "gender": …}` JSON-shape line unchanged.

- [ ] **Step 5: Update the Flutter prompt test** to the new wording (match how the file currently asserts — likely `expect(prompt, contains('...'))`).

- [ ] **Step 6: Run everything**

Run: `cd apps/web && npx vitest run src/lib/listeningPassage.test.ts && npm run typecheck && npm run build`
Run: `flutter test test/features/listening/ && flutter analyze`
Expected: all pass; analyze ≤ 12.

- [ ] **Step 7: Commit**

```bash
git add apps/web/src/lib/listeningPassage.ts apps/web/src/lib/listeningPassage.test.ts lib/features/listening/data/sources/listening_passage_source.dart test/features/listening/data/sources/listening_passage_source_test.dart
git commit -m "feat(listening): keep A/B as internal speaker labels; stop them leaking into dialogue and questions

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 10: Full-suite verification + docs

**Files:**
- Modify: `README.md` (only if it documents the exact-match typing rule or the headword casing — check; likely no change)

- [ ] **Step 1: Web full suite** — `cd apps/web && npm test` — report exact count; must be ≥ the start-of-plan count (~695) plus the new tests, zero failures. `npm run typecheck` clean. `npm run build` succeeds.
- [ ] **Step 2: Flutter full suite** — `flutter test` — ≥ 695 + new tests, zero failures. `flutter analyze` — ≤ 12 infos, zero new.
- [ ] **Step 3: `scripts` tests** — `cd scripts && npm test` — all pass.
- [ ] **Step 4:** grep `README.md` for "exact"/"100%"/typing and for headword casing wording; if a sentence describes the old behavior, update it. Commit only if changed.
- [ ] **Step 5:** No commit unless Step 4 changed something. This task is a gate, not a deliverable.

---

## Self-Review

**Spec coverage:**
- A1 (advance on length) → Tasks 2 (web) + 3 (Flutter). ✓ incl. `maxLength`.
- A2 (normalize typography) → Task 1 (helper) + Task 4 (web wire-in) + Task 3 (Flutter wire-in). ✓
- A3 (casing prompt) → Task 4 (web) + Task 5 (Flutter); the Flutter case-sensitive `wordMap` bug → Task 3. ✓
- B0 helper → Task 6. B1 migration → Task 8. B2 save paths → Task 7 (web `buildVocabRecordDraft` + Flutter `SaveVocabUseCase` + `copyWith` param). ✓
- C1 listening prompt → Task 9 (both platforms, JSON shape untouched, tests updated). ✓
- Out-of-scope list respected: no listening/dictation typography normalize, no listening schema change, no flat-collection deletion, no counter UI.

**Placeholder scan:** Tasks 2, 3, 5, 8, 9 contain a few `/* … */` markers where the exact fixture/harness shape must be read from the existing test file at implement time (e.g. "reuse this file's `_FakeUseCase` pattern", the emulator handle in the script test). These are deliberate — the surrounding real code isn't in the plan author's hands and the sibling test file is the source of truth — but each is bounded by an explicit instruction naming the file and the pattern to copy. Every actual code change (the one-line advance condition, the prompt clauses, the helper bodies, the script) is given in full.

**Type consistency:**
- `normalizeTypography(string): string` / `String` — same name both platforms, consumed in Tasks 3 & 4.
- `capitalizeHeadword(string): string` / `String` — same name both platforms + re-implemented verbatim in the script (Task 8) so the script has no cross-package import; the three copies are checked against the same test table.
- `VocabRecord.copyWith({… String? headword})` — added in Task 7, used only there.
- `capitalizeVocabHeadwords(db, {apply}) => {scanned, toChange, changed, skipped}` — Task 8, consumed only by its own test + CLI block.
- Listening prompt: `buildListeningPassagePrompt(level, context, targetLanguage)` and `_buildPrompt({level, context, targetLanguage})` unchanged; the `{"speaker": "A" or "B" or null, …}` JSON-shape substring is explicitly preserved so `parseListeningPassage` / `_parse` keep working.

**Ordering:** Task 1 before 3 & 4 (helper). Task 6 before 7 (helper). Task 8 is independent (re-implements the helper). 2/5/9/10 independent. Any order that respects 1→{3,4} and 6→7 works.

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-09-02-reading-typing-vocab-casing-listening-speakers.md`. Two execution options:**

**1. Subagent-Driven (recommended)** — a fresh subagent per task, two-stage review between tasks, fast iteration.

**2. Inline Execution** — execute tasks in this session with `executing-plans`, batched with checkpoints.

**Which approach?**
