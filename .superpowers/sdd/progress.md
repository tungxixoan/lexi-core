# LexiCore Plan 1 — SDD Progress Ledger

## Status

- Task 1: ✅ complete (commit e2d26ab, review clean)
- Task 2: ✅ complete (commit 6d102ef, review clean)
- Task 3: ✅ complete (commit 95d55d3, 9/9 tests, review clean)
- Task 4: ✅ complete (commit 4859519, review clean)
- Task 5: ✅ complete (commit c463383, review clean)
- Task 6: ✅ complete (commit fe4315d, 2/2 tests, review clean)
- Task 7: ✅ complete (commit 805f10b, 2/2 tests, review clean)
  - Note: GenerativeModel is final → added GenerativeModelClient thin interface for test injection
  - .withModel() now takes GenerativeModelClient (not GenerativeModel) — Task 8/10 aware
- Task 8: ✅ complete (commit 39d2ff2, 4/4 tests, review clean)
  - Note: added provideDummy<LookupResult/WordPhraseResult> for Mockito sealed class quirk
- Task 9: ✅ complete (commit 0a71eff, 2/2 tests, full suite 20/20, review clean)
- Task 10: ✅ complete (commit 0cd7e4a, 3/3 tests, review clean)
- Task 11: ✅ complete (commit 225143d, flutter analyze clean, review clean)
- Task 12: ✅ complete (commit 2d6a1b5, 2/2 tests, review clean)
  - Minor: widget tests weaker than brief (ListView lazy loading) — findsWidgets not all-8-chips, .at(1) fragile
- Task 13: ✅ complete (commit b5c8c57, flutter analyze clean)
- Task 14: ✅ complete (commit 6341798, flutter analyze clean)
- Task 15: ✅ complete (commit 1f036a4, 24/24 tests, review clean)
  - Note: 2 pre-existing unused import warnings in lookup_provider_test.dart (not from this task)

## Minor Findings (for final review)

- Task 12: ContextSelectorWidget test coverage weak — ListView lazy loading forced workaround: `findsWidgets` instead of verifying all 8 chip labels; chip selection test uses `.at(1)` index (brittle if AppContext.values order changes). Consider using `tester.pumpWidget` with a fixed widget size to force full render, or mock the provider to inject a small list.

---

# LexiCore Plan 2 — Vocabulary Bank + Topic System

**BASE commit (Plan 2 start):** c917991
**Plan file:** docs/superpowers/plans/2026-06-30-plan2-vocabulary-bank.md
**Task files:** docs/superpowers/plans/tasks/plan2-task-{01..10}.md

## Status

- Task 01: ✅ complete (commit c442123, review clean)
- Task 02: ✅ complete (commit 8827a37, review clean)
- Task 03: ✅ complete (commit 4c166e7, review clean)
- Task 04: ✅ complete (commit aa472fd, review clean)
- Task 05: ✅ complete (commits aa472fd..9ccc664, review clean)
- Task 06: ✅ complete (commits 2102353 + c1d9519 mockito fix, review clean)
- Task 07: ✅ complete (commit 1746519, review clean)
- Task 08: ✅ complete (commit 9c80e59, review clean)
- Task 09: ✅ complete (commit 56076b9, review clean)
- Task 10: ✅ complete (commit 94551f0, review clean)
- Task 11: ✅ complete (commit 0c68971, review clean)

## Minor Findings (for final review)

---

# LexiCore Plan 3 — Spaced Repetition + Auto Exercises

**BASE commit (Plan 3 start):** d2210ca
**Plan file:** docs/superpowers/plans/2026-07-01-plan3-spaced-repetition.md
**Task files:** docs/superpowers/plans/tasks/plan3-task-{01..09}.md

## Status

- Task 01: ✅ complete (commit 1ab54d0, review clean)
- Task 02: ✅ complete (commit 7954f52, 13/13 tests, review clean)

## Minor Findings (for final review)
- Task 03: ✅ complete (commit 74a9692, 3/3 tests, review clean)
- Task 03: ✅ complete (commit 74a9692, 3/3 tests, review clean)
- Task 04: ✅ complete (commit 9990bbf, review clean)
- Task 05: complete (commit 8c74f88, review clean)
- Task 06: complete (commit 7d33f92, review clean)
- Task 07: ✅ complete (commit 220f8cd, review clean)
- Task 08: ✅ complete (commit c0be867, review clean)
- Task 09: ✅ complete (commit 4c51345, review clean)
- Final fix: ✅ complete (commit 889944a — SM-2 try/catch scope, shuffle mutation, double-shuffle)

## Minor Findings (for future reference)

- `practice_session_screen.dart`: AutoDispose notifier drops session state if user taps nav bar mid-session (by design for v1)
- `practice_session_screen.dart`: multiple `addPostFrameCallback` may accumulate on `isComplete` rebuilds — `mounted` guard handles it but a `_navigated` flag would be cleaner
- `translation_exercise_widget.dart`: fragile hardcoded string strip `"Translate to Vietnamese: "` from Gemini prompt — consider separate display/source fields in `TranslationExercise`
- `exercise_generator_source.dart`: no null-check before `json['question'] as String` — TypeError propagates to `GenerateExerciseUseCase` catch fallback (works, but cryptic stack trace)

---

# LexiCore Plan 4 — Firebase Sync + Settings Screen + Practice Level Filter

**BASE commit (Plan 4 start):** 889944a
**Spec:** docs/superpowers/specs/2026-07-02-plan4-firebase-settings-practice-filter-design.md (commit c3c1aac)
**Plan file:** docs/superpowers/plans/2026-07-02-plan4-firebase-settings-practice-filter.md

## Status

- Task 01: ✅ complete (commit e5b4a60, review clean — Firebase deferred until user runs `flutterfire configure`)
- Task 02: ✅ complete (commit cc1bcc3, 62/62 tests, review clean) + targetCefrLevel
- Task 03: ✅ complete (commit bd61de9, 64/64 tests, review clean)
- Task 04: ✅ complete (commit 165be09, 64/64 tests, review clean)
- Task 05: ✅ complete (commit 0490599, 64/64 tests, review clean)
- Task 06: ✅ complete (commit a402e34, 64/64 tests, review clean)
- Task 07: ✅ complete (commit 0f0ed1e, 66/66 tests, review clean)
  - Minor: vocab delete branch in Firestore snapshot handler missing `.catchError` — could leave stale guard key in `_firestoreUpdatingVocab` if `vocabBox.delete()` throws; topic delete branch has `.catchError` but swallows without logging. Fix in final review.
- Task 08: ✅ complete (commit 12281ba, 66/66 tests, review clean)
  - Minor: TextEditingController not disposed in `_showApiKeyDialog` (dialog-scoped, low risk)
  - Minor: RadioListTile deprecation warnings (4 info-level) — spec-mandated, still functional

---

# LexiCore Plan 5 — Daily Review + Progress Dashboard

**BASE commit (Plan 5 start):** 64a1038
**Plan file:** docs/superpowers/plans/2026-07-02-plan5-daily-review-progress-dashboard.md
**Task files:** docs/superpowers/plans/tasks/plan5-task-{01..08}.md

## Status

- Task 01: ✅ complete (commit 2ff3539, 66/66 tests, review clean)
- Task 02: ✅ complete (commit d3a49c8, 69/69 tests, review clean)
- Task 03: ✅ complete (commit 775eddb, 70/70 tests, review clean)
- Task 04: ✅ complete (commit 3aff54f, 74/74 tests, review clean)
  Minor: no same-day streak test; import order cosmetic
- Task 05: ✅ complete (commits 5c9d078..b028476, 74/74 tests, review clean after fix)
  Minor: dead getLearningStatsUseCaseProvider (0 callers); _dateKey duplicated vs StatsService; stats stale while screen open
- Task 06: ✅ complete (commit aba8258, 76/76 tests, review clean)
  Medium: initialize() fire-and-forget in build() — first-launch notifications may miss; mitigated by try/catch
  Low: _computeNextDueAt no error handling on Hive/JSON; reschedule future discarded in lifecycle
- Task 07: ✅ complete (commit 6e6380d, 76/76 tests, review clean)
  Note: button placed after Spacer (before FilledButton) not before Spacer — correct layout; plan text was ambiguous
- Task 08: ✅ complete (commit 896f021, 76/76 tests, review clean)
- Final review fixes: ✅ complete (commit ac67e78, 76/76 tests)
  Fixed: I1 ref.watch, I2 _computeNextDueAt try/catch, I3 atomic setReminderTime
  Minor (for future): getLearningStatsUseCase dead layer; _dateKey dup; setReminderMinute untested

---

# LexiCore Plan 6 — Flutter Web Enablement + Adaptive Navigation

**BASE commit (Plan 6 start):** 02cddfb
**Plan file:** docs/superpowers/plans/2026-07-06-plan6-web-platform.md
**Task files:** docs/superpowers/plans/tasks/plan6-task-{01..04}.md

## Status

- Task 01: ✅ complete (commit fb02fb5, review clean)
- Task 02: ✅ complete (commits 73de321+5ceb3cc, 78/78 tests, review clean)
- Task 03: ✅ complete (commit 1d7043a, 11/11 settings tests, review clean)

## Minor Findings (for final review)

---

# LexiCore Plan 7 — "Luyện đọc & gõ" Bilingual Reading Feature

**BASE commit (Plan 7 start):** e460799
**Plan file:** docs/superpowers/plans/2026-07-06-plan7-bilingual-reading.md
**Task files:** docs/superpowers/plans/tasks/plan7-task-{01..06}.md

## Status

- Task 01: ✅ complete (commits 381bd3b+5c7759b, 5/5 tests, review clean)
  Minor: ReadingPassage.fromJson vocabIds not null-guarded (BilingualSentence is) — low risk
- Task 02: ✅ complete (commits 295cd19+c63cf95, 8/8 tests, review clean)
  Minor: duplicate headwords silently drop IDs (low risk); import style inconsistency
- Task 03: ✅ complete (commit 37c600b, 91/91 tests, review clean)
  Important: currentSentence getter is NOT safe after isComplete=true (index=sentences.length); T04-T06 must check isComplete before accessing currentSentence
  Minor: notifier is Notifier<AsyncValue<T>> not AsyncNotifier<T> (brief label wrong, implementation correct)
- Task 04: ✅ complete (commit cfdfd53, 94/94 tests, review clean)
- Task 05: ✅ complete (commit 938d50e, 97/97 tests, review clean — 3 minor)
- Task 06: ✅ complete (commit d944321, 99/99 tests, review clean)

## Minor Findings (for final review)
- Task 01: ReadingPassage.fromJson missing null guard on vocabIds (could throw if field absent)
- Task 02: duplicate headwords in word list silently drops earlier ID (low risk in practice)
- Task 02: relative import paths with ../../../../features prefix (cosmetic)
- Task 03: currentSentence getter throws RangeError when isComplete=true — T04-T06 must gate on isComplete

---

## Final Whole-Branch Review

**Commits reviewed:** 02cddfb..9689bc3 (14 commits)
**Status:** ✅ Ready to merge

**Must-fix applied (commit 9689bc3):**
- F1: /reading/session/result redirect guard (state.extra null → /reading)
- F2: ReadingPassage.fromJson vocabIds null-safe (as List? ?? [])
- F3: _HighlightedText empty headword infinite loop guard
- F4: Dead width param removed from _buildShell test helper

**Global checks:**
- kIsWeb consistency: ✅ all 5 locations guarded
- geminiApiKey in Firestore: ✅ NEVER (excluded from sync_service.dart batch)
- Reading tab visibility: ✅ kIsWeb || showReadingPracticeOnMobile
- SM-2 impact: ✅ zero — reading sessions never touch SM-2 fields

**Remaining minors (post-merge):**
- M1: firebase_options.dart missing EOF newline
- M2: duplicate headwords in ReadingPassageSource.generate silently drops earlier ID

---

# LexiCore Plan 8 — Multi-Provider AI Settings

**BASE commit (Plan 8 start):** fb23862
**Plan file:** docs/superpowers/plans/2026-07-15-multi-provider-ai-settings.md

## Status

- Task 1: ✅ complete (commit d8dcc9d, 21/21 tests, review clean)
- Task 2: ✅ complete (commit 682e199, 17/17 tests, review clean)
  - Minor: defaults map has gemini config but fresh build() yields empty providerConfigs (harmless, activeConfig fallback handles it)
  - Minor: AiProvider.values.byName() unguarded (consistent with existing Language/AppContext pattern)
- Task 3: ✅ complete (commit 196e82b, 3/3 tests, review clean)
  - Minor: _OpenAiClient response parsing unguarded (empty choices, missing keys) — acceptable for MVP
- Task 4: ✅ complete (commit b1448d2, 129/129 tests, review clean)
- Task 5: ✅ complete (commit b96f835, 129/129 tests, review clean)
  - Minor: _ModelTile extends ConsumerWidget but ref unused (no functional impact)
- Final fixes (commit 574cb22, 133/133 tests):
  - Fixed: _OpenAiClient now sends response_format json_object + strips markdown fences
  - Fixed: AiClientFactory.buildClient exposes httpClient for injection; 4 behavioral tests added

## Minor Findings (for final review)

- Task 2: `defaults` map non-empty while fresh `build()` yields empty `providerConfigs` — harmless (activeConfig falls back via ProviderConfig.empty)
- Task 2: `AiProvider.values.byName()` unguarded — consistent with existing codebase risk tolerance

---

# LexiCore Plan 9 — "Luyện nghe" Tab + Nghe chép (Dictation)

**BASE commit (Plan 9 start):** 6a4ce274cadf7cc64a31b712bf50e2e69940fa84
**Plan file:** docs/superpowers/plans/2026-07-19-plan9-listening-dictation.md
**Task files:** docs/superpowers/plans/tasks/plan9-task-{01..08}.md

**Pre-flight note:** diff/scoring algorithm is position-by-position character compare (not edit-distance) per plan — human explicitly approved allowing a switch to edit-distance if a reviewer proposes it (not plan-mandated-immune).

## Status

- Task 01: ✅ complete (commit d95b5ff, 20/20 tests, review clean)
- Task 02: ✅ complete (commit e406f42, 2/2 tests, review clean)
- Task 03: ✅ complete (commit cc96598, 5/5 tests, review clean)
- Task 04: ✅ complete (commits b22210c+38caf21, 164/164 tests, review clean after fix)
  Fixed: added DictationPracticeNotifier lifecycle tests (play() no-autoplay semantics, generate/updateTypedText/submit/reset)
- Task 05: ✅ complete (commits b5bb5dd+1ddec2e, 170/170 tests, review clean after fix)
  Fixed: added due-priority 2-word selection tests
  Aside: ae96b51 regenerated a stale codegen hash unrelated to this task
- Task 06: ✅ complete (commits ee622d4+f3b5790, 177/177 tests, review clean after fix)
  Fixed: added replay-count-increment test + submit-to-result-navigation test
- Task 07: ✅ complete (commits 4053948+d492c36, 182/182 tests, review clean after fix)
  Note: implementer found+fixed a real race in the brief (vocabBankProvider returns [] while loading; switched to awaiting vocabBankNotifierProvider.future)
  Fixed: wrapped the awaited fetch in the same best-effort try/catch as per-record updates
- Task 08: ✅ complete (commit c115ab7, 182/182 tests, review clean)

## Final Whole-Branch Review

**Commits reviewed:** 6a4ce27..c115ab7 (13 commits)
**Status:** ✅ Ready to merge (Yes)

**Strengths:** faithful mirror of Reading feature; SM-2 asymmetry (Dictation updates it, Reading never does) confirmed real and non-leaking; no-autoplay holds end-to-end; kIsWeb->width fix applied consistently to both tabs, no stale kIsWeb visibility logic left; Task 07 race fix well-guarded; tests verify real behavior (actual SM-2 state, not just verify() calls).

**Important (flagged for human decision, not a merge blocker):**
- Positional character-diff scoring cascades badly for blind dictation specifically (unlike Reading, where the target is visible while typing) — one dropped/inserted early character collapses the rest of the score, feeding a bad SM-2 quality on words the user may actually know. Spec-sanctioned known limitation (§3.4), reviewer explicitly invited to flag it, human previously said this is not immune to being changed if a reviewer proposes edit-distance.

**Minor (not blocking):**
- GradeDictationUseCase from spec's file map folded into DictationSessionResult getters + DictationResultScreen inline instead of a standalone use case — intentional, matches Plan 3/5 SessionResultScreen convention.
- Hardcoded Colors.green in diff view (not theme-adaptive) — copied from reading_session_screen.dart, systemic not new.
- AI JSON parsing doesn't strip ```json fences — same as ReadingPassageSource, systemic not new.
- TTS not stopped on navigation away from session screen (minor UX only).
- No test asserts TTS speakCount==0 on session entry (no-autoplay is structurally solid but unguarded by a regression test).

**Remaining decision for the human:** whether to fix the positional-diff scoring now (edit-distance) or accept it as-is for this plan.

**Human decision:** keep positional-diff scoring as-is for this plan (known limitation, spec-documented); improve to edit-distance in a future task/plan if revisited.

---

# LexiCore — Nghe chép Difficulty Levels (Dễ/Trung bình/Khó)

**BASE commit:** 8f32606
**Plan file:** docs/superpowers/plans/2026-07-20-dictation-difficulty-levels.md
**Task files:** docs/superpowers/plans/tasks/dictation-difficulty-task-{01..06}.md

**Pre-flight note:** scanned for conflicts against global constraints — none found. All new fields/params are additive with defaults reproducing today's Khó-only behavior; no plan-mandated design tension flagged this round.

## Status

- Task 01: ✅ complete (commits 225e6d4+12a54f0, 195/195 tests, review clean after fix)
  Fixed: Dễ adjacency-avoidance was gated on `range` instead of `wordCount>=6`, causing short sentences to wrongly avoid adjacent blanks; added regression test + boundary-case tests
- Task 02: ✅ complete (commits b3e7c3a+0d2461b, 206/206 tests, review clean after fix)
  Fixed: bounds-checked updateBlankAnswer against out-of-range blankIndex
  Zero-behavior-change-for-Khó guarantee independently verified byte-for-byte by reviewer
- Task 03: ✅ complete (commit 95a99a6, 208/208 tests, review clean)
- Task 04: ✅ complete (commits cf6ff43+f7ef0b1, 213/213 tests, review clean after fix)
  Fixed: added visible-text interleaving test (9-word fixture) + multi-word (Trung bình) blank test
- Task 05: ✅ complete (commit ca07108, 216/216 tests, review clean)
  Note: implementer deviated RichText->Text.rich for testability (reviewer verified sound + consistent with existing _DiffText behavior)
- Task 06: ✅ complete (commit 133d985, 216/216 tests, review clean)

## Final Whole-Branch Review

**Commits reviewed:** 8f32606..133d985 (9 commits)
**Status:** ✅ Ready to merge (Yes)

**Strengths:** Khó path verified identical to pre-branch production at every hop (traced end-to-end); cross-task type consistency clean; all 4 earlier task-level fixes hold up; tests verify real behavior (seed sweeps, actual interleaving/multi-word rendering); 216/216 passing, analyzer clean.

**Important (not a merge blocker, human decision):**
- Punctuation attached to a blanked word (e.g. "fox," "world.") isn't stripped by `_normalize()`, so a user who types the word correctly without matching punctuation is marked wrong. Only affects Dễ/Trung bình block-accuracy scoring; Khó's char-scoring is untouched.

**Minor (not fixed, logged for awareness):**
- Empty cloze blank TextField has a tiny initial tap target (IntrinsicWidth collapses near-zero before typing).
- _ClozeInput (session) and _ClozeResult (result) duplicate the same "walk words against blanks" interleaving algorithm (~15 lines each) — accepted as fine for 2 call sites.
- Pre-sorted-blanks invariant assumed by both cloze widgets, undocumented/unenforced.
- Redundant double-space between a blank and following visible text (cosmetic).

**Post-review fix applied:** 5185e0b strips leading/trailing punctuation (Unicode-aware, \p{L}/\p{N}) when grading Dễ/Trung bình blanks — fixes the Important finding above. Reviewed clean (219/219 tests). Branch is now final.
