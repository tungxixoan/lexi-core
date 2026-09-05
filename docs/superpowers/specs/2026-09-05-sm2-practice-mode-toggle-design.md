# SM-2 practice: Flashcard-only vs Trộn AI mode toggle

**Date:** 2026-09-05
**Status:** approved

## Problem

The SM-2 practice session (Flutter `lib/features/practice/`, web `/practice`)
mixes four exercise types per word — flashcard, multiple_choice,
fill_in_blank, translation (the last three AI-generated, ported to web in
SP-7). The mix is decided per word by a hardcoded rule
(`_pickExercise`/`shouldUseFlashcard`): a never-reviewed word or no AI key
always gets flashcard; otherwise 30% flashcard / 70% AI, both platforms.

The user finds unpredictably mixed exercise types cognitively harder — not
knowing whether the next word will be "look and recall" or "recognize/produce
an answer" adds friction they'd rather control. They want the ability to opt
out of the mix entirely (pure flashcard) or opt into it, without the ratio
itself being a fixed, hardcoded 70%.

## Decisions (from brainstorming)

- **Two modes, chosen at the practice setup screen, every session:**
  **Flashcard** (default) and **Trộn AI** (mixed). No third "AI-only" mode.
- **Not persisted.** The setup screen always opens on Flashcard; picking
  Trộn AI only applies to the session about to start.
- **The mix ratio is not user-facing.** When Trộn AI is chosen, the app
  draws **one random ratio in [0.20, 0.80] once per session** (not exposed in
  the UI, not re-drawn mid-session) and uses it for every word's per-word
  coin flip. Flashcard mode is equivalent to ratio `0`.
- **The `sm2Repetitions == 0` / no-AI-key override is unchanged** — a
  never-reviewed word or a session with no AI key available always gets
  flashcard, regardless of mode or ratio.
- **Both platforms** — Flutter (`practice_home_screen.dart` +
  `practice_session_provider.dart`) and web (`practice/page.tsx` +
  `pickExercise.ts`), since SP-7 made the two mixing logics equivalent and
  this should stay true.
- **AI exercise TYPE selection (MC/fill/translation) and the CEFR-based
  prompt hints are unchanged** — only whether AI is consulted at all for a
  given word changes; which type comes back is still the AI's/prompt's call.

## Design

### Shared concept: `aiRatio`

Replace the hardcoded `0.30`/`0.70` literals in both `_pickExercise`
(Flutter) and `shouldUseFlashcard` (web) with an explicit `aiRatio` parameter
— the probability [0.0, 1.0] that an eligible word (rep > 0, AI available)
gets an AI-generated exercise instead of a flashcard:

```
eligible = sm2Repetitions > 0 && aiAvailable
useAi = eligible && rng() < aiRatio    // rng() ∈ [0, 1)
```

- **Flashcard mode**: `aiRatio = 0` (or skip the AI branch entirely — same
  observable effect: `useAi` is always false).
- **Trộn AI mode**: at session start, draw `aiRatio = 0.20 + rng() * 0.60`
  once; store it on the session state; every word in that session reuses the
  same value.

### Flutter

- `lib/features/practice/domain/entities/exercise_result.dart` —
  `SessionConfig` gains `final double aiRatio;` (required, since every call
  site must now decide it explicitly — no default that could silently mean
  "old 70%").
- `lib/features/practice/presentation/providers/practice_session_provider.dart`
  — `PracticeSessionState` gains `final double aiRatio;` (copied from
  `config.aiRatio` when `startSession` builds the initial state — needed
  because `recordAndAdvance`'s later `_generateAt` calls only have `current`
  state in scope, not the original `SessionConfig`). `_pickExercise(VocabRecord
  word, bool aiAvailable, double aiRatio)` reads it from `current.aiRatio`
  wherever it's called, replacing the literal `0.30`.
- `lib/features/practice/presentation/screens/practice_home_screen.dart` —
  add `enum _PracticeMode { flashcard, mixed }`, a state field defaulting to
  `_PracticeMode.flashcard`, and a `BloomSegmented<_PracticeMode>` control
  (labels "Flashcard" / "Trộn AI") placed above the existing filters (or
  alongside "Số từ mỗi session" — exact placement decided in the plan).
  `_start()` and `_startDueSession()` compute
  `final aiRatio = _mode == _PracticeMode.flashcard ? 0.0 : 0.20 + Random().nextDouble() * 0.60;`
  and pass it into `SessionConfig(words: ..., aiRatio: aiRatio)`.

### Web

- `apps/web/src/lib/pickExercise.ts` — `shouldUseFlashcard` gains a required
  `aiRatio: number` parameter (after `aiAvailable`, before the optional
  `rng`): `shouldUseFlashcard(record, aiAvailable, aiRatio, rng = Math.random)`.
  Logic: `if (rep === 0 || !aiAvailable) return true; return rng() >= aiRatio;`
- `apps/web/src/app/(app)/practice/page.tsx` — setup phase gains a mode
  toggle (two buttons/segmented control, same default Flashcard, not
  persisted — plain `useState`). `handleStart` and the `action === "start"`
  auto-start effect both compute `aiRatio` the same way as Flutter (`0` or a
  single `0.20 + Math.random() * 0.60` draw) and store it in a ref/state
  alongside `sessionWords`/`exercises`, threaded into every `generateAt(...)`
  call for that session (replacing the implicit default).

## Non-goals

- No third "AI-only" mode.
- No user-visible/adjustable ratio slider.
- No persistence of the last-chosen mode (Settings or local storage).
- No change to which AI exercise TYPE is generated (still AI's choice via the
  CEFR-hinted prompt) or to the SM-2 scoring/grading pipeline.
- No change to the `sm2Repetitions == 0` / no-AI-key hard override.

## Testing

- Flutter: `_pickExercise` (or its extracted ratio-decision helper) — rep=0
  → flashcard regardless of `aiRatio`; `aiRatio: 0` → always flashcard;
  `aiRatio: 1` → always AI (for eligible words); a mid-range ratio with a
  seeded/injected RNG hits both branches. `SessionConfig` requires
  `aiRatio` — update all existing test call sites. Widget test: the setup
  screen defaults to "Flashcard" selected; switching to "Trộn AI" and
  starting produces a `SessionConfig.aiRatio` in `[0.20, 0.80]` (mock the
  RNG or assert the range across repeated runs).
- Web: `shouldUseFlashcard` — same four cases as Flutter, with `aiRatio` as
  an explicit param now (existing tests updated to pass it). Page test: the
  setup phase defaults to Flashcard; picking Trộn AI and starting yields an
  `aiRatio` in range (assert via a mocked `Math.random` or by checking
  `generateExercise` call patterns over many words).
- Both: full suite green, `flutter analyze` 0, `npm run typecheck` clean.
