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

---

# LexiCore Plan 10 — "Nghe hiểu" (TOEIC-style Listening Comprehension)

**BASE commit:** 90c17fa
**Plan file:** docs/superpowers/plans/2026-07-19-plan10-listening-comprehension.md
**Task files:** docs/superpowers/plans/tasks/plan10-task-{01..08}.md

**Pre-flight note:** scanned for conflicts against global constraints — none found. Per-turn seek (not a continuous scrub bar) is a deliberate, already-documented spec trade-off (avoids a new audio pipeline); not flagged for pre-emptive escalation since it's an ergonomics choice, not a correctness/fairness concern like Plan 9's char-diff algorithm was. Verified shared files this plan touches (tts_service.dart, app_providers.dart, listening_home_screen.dart) were untouched by the intervening dictation-difficulty work, so the plan's "before" anchors still hold.

## Status

- Task 01: ✅ complete (commit 10be8f4, 6/6 tests, review clean)
- Task 02: ✅ complete (commit 0c7ccca, 229/229 tests, review clean)
  Note: fixed an unrelated fake TtsService override in dictation_session_screen_test.dart (created by the intervening dictation-difficulty work, not anticipated by this plan) to include the new pitch param
- Task 03: ✅ complete (commit 4efdd6b, 83/83 listening tests, review clean)
- Task 04: ✅ complete (commit 8a18b83, 243/243 tests, review clean)
  Note: implementer found brief's async previousTurn/nextTurn/replayFromStart code conflicted with its own synchronous tests; changed these 3 methods Future<void>->void (fire-and-forget stop()). Verified forward-compatible with Tasks 05-07 (only ever wired as onPressed tear-offs) and race-free (playToken guard already neutralizes timing).
- Task 05: ✅ complete (commit e64742f, 246/246 tests, review clean)
- Task 06: ✅ complete (commit ca3714a, 252/252 tests, review clean)
  Note: implementer found+fixed 3 real bugs in the brief itself (Q1? text match, IconButton finder type, ListView virtualization hiding 3rd question card under test viewport) - all independently verified by reviewer
- Task 07: ✅ complete (commit 3e49e06, 256/256 tests, review clean)
  Note: same ListView-virtualization defect class as Task 06 (transcript section never built under test viewport), fixed identically, independently re-verified
- Task 08: ✅ complete (commit 8b07309, 256/256 tests, review clean)

## Final Whole-Branch Review

**Commits reviewed:** 90c17fa..8b07309 (9 commits)
**Status:** ✅ Ready to merge (With fixes — fix applied below)

**Strengths:** both "opposite of Dictation" guarantees (no replay penalty, zero SM-2 impact) independently traced end-to-end and confirmed real; cross-task type/signature consistency clean (void-not-Future nav methods wired consistently); Task 02's fake-TtsService fix holds; pitch logic (A=1.0/B=1.3) matches spec exactly; Task 06/07 ListView->Column fixes are the right call, no shared-helper needed (different widgets); tests exercise real behavior, not mocks.

**Important (fixed before merge):**
- Null/empty AI response fell back to a passage with empty `turns`/`questions` that `generate()` did not reject, so `AsyncValue.guard` never caught anything — `ComprehensionSessionScreen` then indexed `passage.turns[0]` on an empty list, a hard `RangeError` crash bypassing the home screen's built "Lỗi tạo bài / Thử lại" retry UI. Unlike the sibling `dictation_source.dart`, which degrades an empty response to an empty string (no crash), an empty passage has no safe equivalent here.

**Post-review fix applied:** 46c19af (`listening_passage_source.dart` throws `FormatException` when parsed `turns`/`questions` are empty, caught by the existing `AsyncValue.guard`) — re-reviewed clean, 257/257 tests, ready to merge as-is.

**Minor (not fixed, logged for awareness):**
- README test count should be verified against the final 257 at merge time.
- `RadioListTile` groupValue/onChanged API is deprecated on recent Flutter in favor of `RadioGroup` — not a bug, future-proofing note only.

---

# LexiCore — Audio Seek Slider (Nghe chép & Nghe hiểu)

**BASE commit:** 80b9bed
**Plan file:** docs/superpowers/plans/2026-07-22-listening-audio-seek.md

## Status

- Task 1: ✅ complete (commit 8397c66, 264/264 tests, review clean)
- Task 2: ✅ complete (commit fb3d4ef, 268/268 tests, review clean)
  Minor: word-splitting duplicated between _SessionScaffold and _ClozeInput (cosmetic, pre-existing pattern)
- Task 3: ✅ complete (commits c0c2c7c+21ab782, 270/270 tests, review clean after fix)
  Fixed: added zero-seek-count render test (_perfectResult -> '0 (−0%)')
- Task 4: ✅ complete (commit 627eaf8, 274/274 tests, review clean)
  Minor: dead-code fallback branch in _resolveGlobalWordIndex unreachable via seekToWord; missing tests for isSubmitted guard and last-valid-index case
- Task 5: ✅ complete (commit 90bccfe, 277/277 tests, review clean)
  Minor: pre-existing RadioListTile deprecation warnings (not introduced by this task); preview-label word-split duplicates Task 4's private _splitWords (unavoidable, private to provider file)
- Task 6: ✅ complete (commit faa6b7e, 277/277 tests, review clean)

## Final Whole-Branch Review

**Commits reviewed:** 80b9bed..faa6b7e (7 commits)
**Status:** ✅ Ready to merge (Yes)

**Strengths:** seekPenaltyFraction formula matches spec exactly incl. div-by-zero guard and boundary at ratio=0.2; finalScore's 3 terms (rawAccuracy, replayCount*5%, seekPenaltyTotal) are cleanly additive/independent; free-first-listen correctly built on the single shared hasPlayedOnce gate across both Play and seek entry points; Comprehension's zero-scoring guarantee verified by direct grep (no penalty/score/sm2/replay trace anywhere in seekToWord/_resolveGlobalWordIndex/totalWordsOf/its _SeekSlider); global-word-index math traced off-by-one-clean at turn boundaries; both sliders confirmed rendering above their play controls; unit consistency (fraction*100->percent) correct on result screen; 277-test total reconciles exactly (257 baseline + 20 new); tests exercise real Slider callbacks + real ProviderContainers, not mocks.

**Minor (not blocking):**
- Comprehension screen's `_previewLabel` duplicates the provider's private turn-resolution logic (byte-identical today, latent-divergence risk if one changes without the other — no shared helper possible across the private/public file boundary).
- First-ever seek increments seekCount to 1 while showing "−0%" penalty — intentional/spec-conformant (free first listen), just a UX nuance worth being aware of.
- Confirmed harmless: _resolveGlobalWordIndex's dead fallback branch (Task 4 finding) still unreachable branch-wide.

**Ready to merge — no fixes required.**

---

# LexiCore — TTS Playback-Speed Control (Nghe chép & Nghe hiểu)

**BASE commit:** 3b0b5b0
**Plan file:** docs/superpowers/plans/2026-07-25-tts-speed-control.md

**Pre-flight note:** scanned for conflicts against global constraints — none found. Tasks 2/3 each carry a mechanical-but-large step (updating every existing `mockTts.speak(...)` when/verify call to account for the new `rate:` argument) — flagged to self during plan-writing, not a conflict, just a large Step 1 in each of those two tasks.

## Status

- Task 1: ✅ complete (commit ca20c5f, 299/299 full-repo tests, review clean)
- Task 2: ✅ complete (commit 1b82ad0, 36/36 target tests + 133/133 listening suite, review clean)
  Minor: setSpeed()'s "speaking" branch re-asserts isSpeaking:true (already true) — harmless no-op, per brief verbatim
- Task 3: ✅ complete (commit 76af30d, 19/19 target tests, 305/305 full-repo tests, review clean)
- Task 4: ✅ complete (commit 344890c, 29/29 target tests, 309/309 full-repo tests, review clean)
  Minor: _SpeedSelector duplicated byte-for-byte across both screen files — deliberate, matches existing _SeekSlider precedent, not an oversight

## Final Whole-Branch Review

**Commits reviewed:** 3b0b5b0..344890c (4 commits)
**Status:** ✅ Ready to merge (Yes)

**Strengths:** all 4 tasks faithful to spec/plan, no scope creep; `_rateFor` byte-identical in both providers (deliberate duplication per plan); scoring divergence isolated exactly where spec requires (Dictation's mid-play speed change increments replayCount, reusing existing finalScore formula with no new penalty term; Comprehension never touches ComprehensionSessionResult/SM-2) with no leakage either direction; session-scoped reset holds (speedMultiplier defaults to 1.0 on every generate()); backward compat confirmed (3 unrelated speak() callers unaffected by nullable rate); concurrency-sensitive "while speaking" tests genuinely interleave via Completer (not vacuous); 309/309 full suite independently re-confirmed.

**Minor (not blocking):**
- Dictation has no playToken-style supersede guard (unlike Comprehension), so a rapid mid-play setSpeed() race could theoretically stamp isSpeaking:false while replay audio is still playing — confirmed to fail in the safe direction (under-counts replays, not a free-listen exploit) and currently invisible since isSpeaking is never read by the Dictation UI. Worth revisiting only if isSpeaking ever drives Dictation UI (e.g. a stop button).

**Ready to merge — no fixes required.**

---

# LexiCore — Flashcard Flip-Back, Reading Backspace Penalty, Listening Auto-Continue

**BASE commit:** 3058054
**Plan file:** docs/superpowers/plans/2026-07-24-flashcard-flip-reading-backspace-listening-autoplay.md

**Pre-flight note:** scanned for conflicts against global constraints — none found. Three independent tasks (flashcard widget, reading provider+screen split into two tasks, listening provider), no shared files between them.

## Status

- Task 1: ✅ complete (commit 404f39a, 8/8 tests, review clean)
  Minor: back-face Column/Container(minHeight only) sits inside SingleChildScrollView (unbounded height) — same pre-existing pattern as the front face, not a regression from this task; resolved as non-blocking.
- Task 2: ✅ complete (commits df17db4+289e31b, 25/25 reading tests, review clean after fix)
  Fixed: implementer found the brief's own test scenario ('Hix'->'Hi.' single-call jump) didn't actually simulate a backspace keystroke; added missing intermediate step and corrected 2 expected counts (independently re-verified arithmetic by hand)
- Task 3: ✅ complete (commit 7c23e9d, review clean)
- Task 4: ✅ complete (commit 9d3f101, 297/297 full-repo tests, review clean)
  Minor: submit() firing mid-auto-continue-chain (non-last-turn) could leave isSpeaking stuck true — confirmed zero observable effect since comprehension_session_screen unmounts to SizedBox.shrink() on isSubmitted regardless
  Minor: auto-continue test doesn't use verifyInOrder for turn sequencing (per brief's own prescribed test body)

## Final Whole-Branch Review

**Commits reviewed:** 3058054..9d3f101 (5 commits)
**Status:** ✅ Ready to merge (Yes)

**Strengths:** three genuinely independent slices (practice/reading/listening, no shared state or naming collisions); reading's `finalScore` formula confirmed matching dictation's additive-penalty/clamp(0,1) pattern exactly, per spec intent; backward compatibility clean (all new fields default to 0, old test fixtures compile/pass unchanged); listening auto-continue correctly reuses the existing `playToken` supersede mechanism with no new flag; both prior per-task concerns (Task 2's fixed test scenario, Task 1's scroll-view layout pattern) independently re-verified as genuinely resolved/non-regressions; full suite re-run clean (297/297), `flutter analyze` clean on all 4 changed files.

**Minor (not blocking):**
- 4th "Điểm" stat card on reading result screen could overflow horizontally on very narrow (~320dp) devices (`_StatCard` has no `Expanded`/`Flexible` wrapping in the `Row`) — low likelihood, optional fix.
- Task 4's `isSpeaking` stuck-true edge case (submit() mid-chain) confirmed unobservable/harmless at whole-branch level too — optional defense-in-depth (`if (latest.isSubmitted) return;`) not required.
- Reading backspace count increments even on a delete-to-match final keystroke (e.g. 'Hii'→'Hi' completing the sentence) — consistent with spec's "count every length-decrease event," not a defect, just a note.

**Ready to merge — no fixes required.**

---

# LexiCore — Word Radar

**BASE commit:** 33f4cb4
**Spec:** docs/superpowers/specs/2026-07-26-word-radar-design.md (commit dd489c1)
**Plan file:** docs/superpowers/plans/2026-07-26-word-radar.md

## Status

- Task 1: complete (commit 667afc9, 5/5 target tests + 303/303 full-repo tests, review clean)
  Minor: stray blank line before WordPhraseResult's closing brace (cosmetic, from plan template); unguarded CEFRLevel.values.byName() on malformed AI cefrLevel string (consistent with existing unguarded-cast risk tolerance in this method)
- Task 2: complete (commit 7d6bb60, 6/6 target tests + 309/309 full-repo tests, review clean)
- Task 3: complete (commits 1893184+f0e79d8, 4/4 word_radar_source tests + 1/1 use case test, review clean after fix)
  Fixed: skip malformed AI suggestions (missing/empty headword) instead of discarding the whole batch on one bad item
  Minor (for final review): cefrLevel parsing (`CEFRLevel.values.byName`) still unguarded against a non-enum AI value — same failure class as the fixed headword issue, but consistent with existing GeminiDictionarySource convention; not blocking
- Task 4: complete (commits 8d3dfe9+9284043+7741a59, 9/9 word_radar_provider tests, review clean after 2 fix rounds)
  Fixed round 1: added 5 tests for the AI-enabled path (deviated from exact brief — substituted a duplicate error-path test instead of the requested Completer-gated ordering test)
  Fixed round 2: replaced the duplicate with the actual two-stage ordering test (Completer-gated fake client) + an AI-enabled success-path test; required adding container.listen() to prevent Riverpod autoDispose from wiping state during the test's Duration.zero yield (verified necessary against generated AutoDisposeNotifierProvider declaration)
- Task 5: complete (commit 5ace6fe, 25/25 word_radar tests + 328/328 full-repo tests, review clean)
  Fixed inline (implementer, pre-review): added await tester.pump() after enterText in 4 tests — brief's test code hit stale disabled button without it; verified against dictation_session_screen_test.dart precedent, no assertions changed
  Minor (for final review): _openSaveSheet missing mounted guard after async showModalBottomSheet gap (unlike sibling _openKnownWord which has one) — plan-inherited, low risk
- Task 6: complete (commit c52becc, 2/2 target tests + 330/330 full-repo tests, review clean)
  Resolved reviewer ⚠️ (not a defect): final count 330 vs. plan's predicted 323 — reconciled by controller: review-driven fix rounds added tests beyond the plan's original static prediction (Task 3 fix +1, Task 4 fixes +6 net = +7; 323+7=330, exact match). Verified test-count arithmetic step-by-step across all 6 tasks' reported deltas.

## Final Whole-Branch Review

**Commits reviewed:** 33f4cb4..c52becc (Word Radar feature: Tasks 1-6, all task-level reviews clean)

**Status:** Ready to merge (With fixes — fixes applied below)

**Strengths:** end-to-end trace verified (WordRadarScreen -> notifier -> local+AI use cases -> suggestion card -> SaveVocabSheet -> SaveVocabUseCase); cefrLevel flows correctly cross-task from Task1's schema fix through Task3's parsing into Task1's own SaveVocabSheet consumption; DI consistent, no naming collisions; folder placement correct (word_radar/ top-level, nothing leaked into practice/); duplication-is-intentional convention for _HighlightedText held; Task4's container.listen()/Completer fixes verified legitimate against real AutoDisposeNotifierProvider semantics; 330/330 test count reconciled exactly against the plan's original 323 prediction (+7 from review-driven fix rounds in Tasks 3 and 4).

**Important (fixed before merge, commit c7f84e5, 333/333 full suite):**
- I1: InputType.word hardcoded for every AI suggestion including multi-word phrases -> now uses InputDetector.detect() (sentence collapsed to phrase, since SaveVocabUseCase rejects sentence)
- I2: malformed cefrLevel string from AI could discard the whole suggestion batch (same failure class as an earlier fixed headword bug) -> CEFRLevel.values.byName() replaced with safe asNameMap() lookup; adjacent lazy .cast<String>() casts on examples/suggestedTopics/synonyms replaced with eager .whereType<String>()
- I3: AI-suggested cefrLevel parsed but never shown in UI (spec required a chip) -> added Chip to suggestion ListTile

Fix re-reviewed clean: Ready to merge: Yes.

**Minor (not fixed, logged for awareness):**
- cefrLevel non-string value (not just invalid enum name) would still throw inside _parseSuggestion's .map() — same failure class, narrower case, pre-existing before this branch too
- No test locks the InputType.word branch of the new ternary (only phrase branch tested)
- No test covers the .whereType<String>() defensive cast itself
- _openSaveSheet missing mounted guard after async gap (unlike sibling _openKnownWord) — plan-inherited, low risk
- Quét button has no in-flight guard against concurrent AI calls (no playToken-style sequencing, unlike ListeningComprehensionNotifier's existing pattern)
- Highlighted text renders from live _controller.text rather than a scanned-text snapshot — editing the box after a scan can desync highlights from the text shown
- Overlapping headwords (e.g. "cat" inside "cathedral") resolve by list order not longest-match — consistent with Reading's identical pre-existing behavior, not a regression
- Pushing /vocab/:id from /practice/radar flips the bottom-nav highlight to "Vocab Bank" — cosmetic nav artifact, AppShell._selectedIndex matches on path prefix

**Ready to merge — Word Radar feature complete (Tasks 1-6 + final review fixes).**

---

# LexiCore — Word Radar post-merge: bare-string parsing fix + translation feature

**BASE commit:** c7f84e5 (Word Radar final-review-fix, previously "Ready to merge: Yes")

## Bug found during manual testing
Crash: `Không tải được gợi ý: TypeError: "Business": type 'String' is not a subtype of type 'List<dynamic>?'`
AI sometimes returns a bare string (`"suggestedTopics": "Business"`) instead of a JSON array. The `as List?` cast threw immediately (not null-safe against wrong-type values), killing the whole suggestions batch.
**Fixed:** commit 220fd33 — added `_stringList()` helper in `WordRadarSource._parseSuggestion` that accepts a bare string as a single-item list. Applied to examples/suggestedTopics/synonyms. New regression test added. 334/334 full suite.

## Feature addition: Vietnamese translation + highlight in translation
User request: add a Vietnamese translation of the scanned text, with known-word meanings highlighted in the translation too (mirroring the existing headword highlight in the original text).
**Implemented directly (no subagent dispatch — moderate, well-understood scope, done in-session):** commit 31246e9.

- `WordRadarSource.scan()` now returns a new `WordRadarAiResult { translation, suggestions }` instead of bare `List<WordPhraseResult>` — same single AI call, prompt extended to also request `"translation"`.
- `FindKnownHeadwordsUseCase.execute()` return type changed from `List<String>` to `List<VocabRecord>` (returns full matched records, not just headword strings) — needed so both original-text (by headword) and translation (by meaning) highlighting can be driven from one local Hive query, no extra repository calls.
- `WordRadarState` fields renamed: `knownHeadwords`→`knownRecords` (List<VocabRecord>?), `suggestions`→`aiResult` (AsyncValue<WordRadarAiResult>?).
- `WordRadarScreen`: `_HighlightedText.onTapHighlight` made optional — translation highlights are read-only (no tap), avoiding the WidgetSpan baseline/wrap quirk noted in the final review's Minor #6 for spans that don't need a GestureDetector. `_openKnownWord` simplified to a synchronous lookup against `knownRecords` (no longer needs `vocabRepositoryProvider`/`userSettingsNotifierProvider` in the screen at all).
- All existing tests updated for the renamed types/fields; 4 new tests added (translation defaults to empty string, translation shown + highlighted, translation section hidden when empty, FindKnownHeadwordsUseCase returns full records with meaning).

**Verification:** `dart run build_runner build --delete-conflicting-outputs` clean; `flutter test` 338/338 passing, pristine; `flutter analyze` 12 pre-existing unrelated deprecation infos only, no new issues.
**README updated:** new "Quét từ vựng (Word Radar)" feature section, Roadmap ticked, folder tree + AI data-flow diagram + test count (300→338) refreshed (commit ce3435b).

**No task-reviewer subagent dispatched for this round** (done conversationally, outside the formal plan) — self-verified via full test suite + analyze per this project's standard bar.

## Bug found during manual testing (round 2): mouse drag-select in SaveVocabSheet selects the screen behind it

User reported (with screenshots): mouse drag-select works fine everywhere including Word Radar suggestion cards and Word Radar's own text sections (confirming the earlier ListTile/InkWell hypothesis was wrong — selection is NOT blocked there), but dragging over the SaveVocabSheet modal's own content (e.g. the "Definition" field) instead highlights the Word Radar screen behind the modal. Ctrl+A worked (selects everything in whatever SelectionArea scope is active) but mouse drag specifically targeted the wrong layer.

Root cause: the app-wide `SelectionArea` (main.dart) wraps the single Navigator; `showModalBottomSheet` content renders in a separate `OverlayEntry` stacked visually on top of the screen behind it, but both are descendants of the SAME outer `SelectionArea`. The outer SelectionArea attributes drag-select pointer events by paint/traversal order, not visual (overlay) z-order, so it kept selecting the background screen's content instead of the modal's.

**Fixed:** commit 3615081 — wrapped `SaveVocabSheet`'s returned `DraggableScrollableSheet` in its own nested `SelectionArea`, giving the modal an independent selection scope. Verified via `flutter analyze` (clean) and `flutter test` (340/340, no regressions in `save_vocab_sheet_test.dart` or elsewhere). No new automated test added for the selection-geometry behavior itself (Flutter's SelectionArea drag mechanics aren't practically assertable via widget tests without excessive complexity) — verification was manual, by the user, live in the browser.

**Diagnostic dead-end (for future reference):** attempted a headless Playwright-driven reproduction against a throwaway `flutter run -d web-server` instance (port 5050, separate from the user's own running session) to test the ListTile/InkWell hypothesis before this. Both the ListTile-card test AND a plain-AppBar-title control case failed to produce a clipboard result via synthetic mouse-drag + Ctrl+C — inconclusive, most likely because Flutter web's CanvasKit renderer draws text to canvas (not real DOM text nodes Playwright's `text=` locator or synthetic pointer events reliably interact with the same way real OS input does), not because selection was actually broken everywhere. Abandoned in favor of asking the user to verify live, which correctly pinpointed the real, narrower bug above.

---

# LexiCore — Vocab suggestions for Reading/Comprehension results

**Plan:** docs/superpowers/plans/2026-08-02-vocab-suggestions-reading-listening.md
**BASE commit:** 13cfa17 (docs: add implementation plan for reading/listening vocab suggestions)

## Status

- Task 1: ✅ complete (commit dde0ed2, 9/9 tests, review clean — Approved)
  - Minor (logged, not fixed): RED-phase evidence in report was IDE errors not an actual failing test run; one line ~81 chars (no lint enforces 80-col)
- Task 2: ✅ complete (commits 2711135, 35642c4; 40/40 word_radar tests, review clean — Approved)
  - Note: dispatched implementer stalled (infra timeout) after completing code but before commit/report; controller independently verified diff against brief + ran full test/flutter analyze, then committed directly. No re-dispatch needed.
  - Minor (logged, not fixed): reading_practice_provider.g.dart hash-only change bundled into this commit (stray build_runner regen, non-functional)
- Task 3: ✅ complete (commit 1ea7f4a, 7/7 reading_result_screen_test + 35/35 full reading suite, review clean — Approved)
  - Note: brief's import list had a naming collision (SentenceResult in both lookup_result.dart and reading_practice_provider.dart); fixed with `show WordPhraseResult` — verified genuine and necessary by reviewer
  - Minor (logged, not fixed): retry button on suggestion-load error has no debounce/disable-while-loading guard
- Task 4: ✅ complete (commit bb2e453, 6/6 focused + 145/145 full listening suite, review clean — Approved)
  - Note: import-collision question (from Task 3) independently re-checked — no collision here, unqualified `lookup_result.dart` import correct
  - Minor (logged for final review): suggestion-loading boilerplate (_suggestions field/_loadSuggestions/_buildSuggestionsSection) now duplicated near-identically between ReadingResultScreen (Task 3) and ComprehensionResultScreen (Task 4) — plan-mandated, candidate for later extraction

## All 4 tasks complete — proceeding to final whole-branch review.

**Final whole-branch review (commits 13cfa17..c5297fc):** Ready to merge: With fixes.
- Important #1: WordRadarSource always generated+discarded a full-text translation on every Reading/Comprehension session (Reading already has it per-sentence). Fixed (commit 4658667): added `includeTranslation` param (default true, Word Radar unaffected), GetVocabSuggestionsForTextUseCase passes false.
- Important #2: new suggestion-loading path had no `aiEnabled` gate, unlike Word Radar's own screen. Fixed (commit a5fca6b): early-return in both screens' `_loadSuggestions()` when settings.aiEnabled is false; section stays hidden.
- Re-review of both fixes (commits c5297fc..a5fca6b): both Resolved, no regressions, **Ready to merge: Yes**.
- Minor findings logged, not fixed (follow-up candidates): suggestion-loading boilerplate duplicated between Reading/Comprehension result screens (plan-mandated; extraction to a shared self-loading widget recommended, esp. since Dictation is a likely next consumer); retry button has no debounce guard; raw exception text shown on suggestion-load error (matches existing Word Radar style, not a regression); practiced-vocab list on Reading result screen lost lazy ListView building (shrinkWrap+NeverScrollableScrollPhysics, plan-mandated layout fix); fallback JSON string in word_radar_source.dart still mentions "translation" key even when includeTranslation:false (harmless, unused).

## Plan complete — Ready to merge: Yes (with fixes applied and re-reviewed clean).

---

# LexiCore — TOEIC Reading Part 5 + Part 6

**Plan:** docs/superpowers/plans/2026-08-03-toeic-reading-part5-part6.md
**BASE commit:** 964fd8f (docs: add implementation plan for TOEIC reading Part 5 + Part 6)

## Status

- Task 01: ✅ complete (commit f62947a, 3/3 tests, review clean — Approved)
- Task 02: ✅ complete (commit 9a1db34, 3/3 tests, review clean — Approved)
- Task 03: ✅ complete (commit cf64e03, 4/4 tests, review clean — Approved)
  - Minor (logged, not fixed): AiClientFactory re-export pattern propagated from ListeningPassageSource (pre-existing convention)
- Task 04: ✅ complete (commit f0944d7, 1/1 test, review clean — Approved)
  - Reviewer ⚠️ item resolved by controller: full-project `flutter analyze`/`flutter test` run (376/376 passing, 12 pre-existing unrelated deprecation infos) — not a gap
- Task 05: ✅ complete (commit af8f91a, 6/6 tests, review clean — Approved)
  - Minor (logged, not fixed): selectAnswer() has no bounds-check on index (mirrors pre-existing ListeningComprehensionNotifier pattern)
- Task 06: ✅ complete (commit 2ff3ca4, 3/3 tests, review clean — Approved)
- Task 07: ✅ complete (commit 4817d64, 4/4 tests, review clean — Approved)
  - Minor (logged, not fixed): RadioListTile groupValue/onChanged deprecation infos (pre-existing codebase-wide, matches comprehension_session_screen.dart exactly)
- Task 08: ✅ complete (commit c6f97d0, 5/5 new tests + 65/65 full reading suite, review clean — Approved)
  - Minor (logged, not fixed): Part5 screens near-duplicate ComprehensionResultScreen structure (plan-mandated reuse pattern); routes not wired yet (deferred to Task 16 per plan)

## Part 5 complete (Tasks 01-08) — proceeding to Part 6 (Tasks 09-15).
- Task 09: ✅ complete (commit 9094bd0, 5/5 tests, review clean — Approved)
- Task 10: ✅ complete (commit 81b9975, 4/4 tests, review clean — Approved)
- Task 11: ✅ complete (commit 4d9c4a9, 1/1 test, review clean — Approved)
  - Reviewer ⚠️ item resolved by controller: full-project `flutter test` run (404/404 passing)
- Task 12: ✅ complete (commit 2d4af6f, 7/7 tests, review clean — Approved)
  - Note: implementer subagent hit an API session-limit mid-task (after code complete, before commit/report); controller independently verified (build_runner, 7/7 tests, analyze clean) and committed directly, wrote a controller-authored report for the reviewer. No re-dispatch needed.
- Task 13: ✅ complete (commit 3b0450e, 3/3 tests, review clean — Approved)
  - Reviewer ⚠️ item resolved by controller: full-project `flutter test` run (414/414 passing)
- Task 14: ✅ complete (commits 21b4824, 237cf73; 4/4 + 1 new = 5/5 tests, review clean after fix — Approved)
  - Important finding fixed: original tests used uniform selectedAnswers values, blind to a passageIndex/questionIndex swap bug. Fix (237cf73) added a test tapping a specific RadioListTile and asserting on flatIndex(1,2) vs an untouched slot; sanity-checked by temporarily swapping the argument order in production code (test failed as expected), then reverting. Re-review confirmed the fix by hand-tracing the tile-order arithmetic.
- Task 15: ✅ complete (commit a173d0f, 5/5 new tests + 95/95 full reading suite, review clean — Approved)

## Part 6 complete (Tasks 09-15) — proceeding to Task 16 (hub restructure + DI + router + README, final integration task).
- Task 16: ✅ complete (commit ec6c1d2, 428/428 full suite, web build success, review clean — Approved)
  - Minor (logged, not fixed): README's "338 tests" line is now stale (428 actual) — pre-existing line, not in this task's specified 3 README edits

## All 16 tasks complete — proceeding to final whole-branch review.

**Final whole-branch review (commits 964fd8f..9ab5c08):** Ready to merge: With fixes.
- Critical #1: Part6Source didn't validate that every passage has exactly 4 questions, which Part6SessionState.flatIndex silently assumes — malformed AI response could RangeError-crash the session screen or permanently disable "Nộp bài" via index collision. Fixed (commit 3d8b45f): filter passages to questions.length==4 before the empty-check in Part6Source._parse(); all-malformed response still correctly throws FormatException.
- Important #2: Part6SessionResult.correctCount used its own index counter instead of the canonical Part6SessionState.flatIndex helper. Fixed (3d8b45f): rewrote to use flatIndex(p, q), single source of truth restored.
- Important #3: Part5Source/Part6Source prompts missing the "Vietnamese script only" guard every other Vietnamese-output AI prompt in this app carries (added commit 3e00740 after a real CJK-leakage bug). Fixed (3d8b45f): added guard sentence to both prompts + prompt-content test assertions.
- Also fixed: README stale test count (338 -> 432, commit 9f3c2ad).
- Re-review of fix pass (9ab5c08..9f3c2ad): all 3 findings verified resolved by direct diff inspection, no new issues, **Ready to merge: Yes**.
- Minor findings logged, not fixed (follow-up candidates): 4-way duplication of result-screen suggestion/stats scaffolding across Reading/Comprehension/Part5/Part6 (extract before Part 7 is planned); _ErrorCard duplicated privately in Part5HomeScreen/Part6HomeScreen (move to lib/core/widgets/); no test asserts "exactly one AI call per generation" for Part5/Part6 sources; element casts in Part5/Part6 sources use `as Map<String, dynamic>` instead of the newer `.whereType<Map<String, dynamic>>()` convention from word_radar_source.dart.

## Plan complete — Ready to merge: Yes (with fixes applied and re-reviewed clean).

---

# LexiCore — Dedupe result-screen suggestions & home-screen error card

**Plan:** docs/superpowers/plans/2026-08-06-dedupe-result-error-widgets.md
**BASE commit:** 2bc3ab2 (docs: add implementation plan for deduping result/error widgets)

## Status

- Task 1: ✅ complete (commit 1f622bb, 1/1 test, review clean — Approved)
- Task 2: ✅ complete (commit 65ed02d, 21/21 tests across 5 screens, review clean — Approved)
- Task 3: ✅ complete (commit 955eb24, 4/4 tests, review clean — Approved)
  - Minor (logged, not fixed): uses ref.read not ref.watch for aiEnabled, inherited unchanged from original inline code (pre-existing, not a regression)
- Task 4: ✅ complete (commit 2bf9b27, 25/25 per-screen + 438/438 full suite, web build success, review clean — Approved)

## All 4 tasks complete — proceeding to final whole-branch review.

**Final whole-branch review (commits 2bc3ab2..55b7d2f):** Ready to merge: Yes.
- All 11 argument mappings (7 AiDisabledCard call sites, 4 ResultSuggestionsSection call sites) verified identical to the code they replaced. No behavior change, no scope creep into Part5/6 feature files beyond the 4 legitimate result-screen touches. 110/110 focused tests + zero edits to any pre-existing test file.
- Minor findings logged, not fixed (recommended to bundle with Part 7 planning, when the shared widgets get their second real consumer): (1) AiDisabledCard's name doesn't fit the "not enough vocab words" call sites (2 of 7) — consider renaming to something neutral like InlineErrorCard; (2) ResultSuggestionsSection has no didUpdateWidget guard — fine today since all 4 consumers pass an immutable `text` at construction, but a future consumer swapping text in place would show stale suggestions; document the single-shot contract or add the guard; (3) ai_disabled_card_test.dart doesn't assert error-container coloring, only text+Card presence.
- Stray directory the reviewer flagged as a session artifact was not found in the actual working tree (git status clean) — no action needed.

## Plan complete — Ready to merge: Yes.

---

# LexiCore — TOEIC Reading Part 7

**Plan:** docs/superpowers/plans/2026-08-07-toeic-reading-part7.md
**BASE commit:** b8209ac (docs: add implementation plan for TOEIC reading Part 7)

## Status

- Task 01: ✅ complete (commit ea696b9, 7/7 tests, review clean — Approved)
- Task 02: ✅ complete (commits ea696b9..7d690a4, 8/8 tests, review clean after fix — Approved)
  - Important finding fixed: test 'double-passage wrong question count' originally built group[2] with wrong document count too, accidentally re-testing the document-count branch instead of the question-count branch (`_hasValidShape` in part7_source.dart short-circuits on document count first). Fix (7d690a4) corrected the test fixture to isolate the intended branch. Production code was correct from the start.
- Task 03: ✅ complete (commit d8a2741, 1/1 test, review clean — Approved)
- Task 04: ✅ complete (commit 874f00a, 7/7 tests, review clean — Approved)
  - Verified: flatIndex genuinely dynamic (not disguised fixed-multiplier), correctCount/selectAnswer route through it exclusively — the direct fix for the Part6 Critical bug, confirmed correct by review.
  - Minor (logged, not fixed): no bounds check distinguishing valid-but-wrong flat index (pre-existing pattern shared with Part6Source, out of scope)
- Task 05: ✅ complete (commit 09ab37d, 3/3 tests, review clean — Approved)
  - Minor (logged, not fixed): widget test coverage shallow (no tap/interaction assertions) — inherited verbatim from brief + Part5 precedent, not a regression
- Task 06: ✅ complete (commits 09ab37d..0f02b10, 5/5 tests, review clean after fix — Approved)
  - Important finding fixed: original 4 widget tests never tapped a RadioListTile, only pre-set state (real onSelected -> selectAnswer -> flatIndex wiring untested). Fix (0f02b10) added an interactive test targeting group 1 (non-zero offset), verified selection lands at correct flat index + sibling/other-group slots unaffected + submit flips disabled->enabled only after all 12 taps. Implementer mutation-tested (swapped groupIndex/questionIndex, confirmed new test fails, reverted) — verified clean by reviewer diff inspection.
  - Minor (logged, not fixed): null-state redirect path untested (consistent with Part6 precedent); ~80% structural duplication with Part5/Part6 session screens (each domain-typed, out of scope to unify now)
- Task 07: ✅ complete (commit 247d362, 5/5 new tests + 138/138 reading suite, review clean — Approved)
  - Verified: N dynamic (fold), X uses Part7SessionResult.correctCount (not reimplemented), ResultSuggestionsSection fed all 4 documents across all 3 groups, recordPracticeSession dynamic — all confirmed by direct code inspection.
  - Minor (logged, not fixed): tests don't assert correct/incorrect color/icon rendering (pre-existing pattern shared with Part6 result screen test)
- Task 08: ✅ complete (commits cb79fa1, 4d412de fix, 474/474 full suite, web build success, review clean — Approved)
  - Important finding fixed (4d412de): README file-tree screens/ line omitted Part7Home/Session/Result (brief's own replace-block stopped one line short) — corrected directly by controller, trivial one-line doc fix.
  - Verified: route nesting matches Part5/6, AppShell untouched, Part7ResultScreen(result:) extra-threading through GoRouter type-checked end to end (session screen -> context.go extra: -> router redirect guard -> result screen constructor).

## All 8 tasks complete — proceeding to final whole-branch review.

**Final whole-branch review (commits b8209ac..d7ac80e):** Ready to merge: Yes.
- Verified: flatIndex dynamic-offset invariant holds at all 4 selectedAnswers call sites (correctCount, selectAnswer, session screen, result screen) — no fixed multiplier, no reimplemented arithmetic anywhere. _hasValidShape rejects every malformed shape the spec enumerates (group count, order, per-group document/question counts) before a Part7Set escapes the source — unlike Part6Source, _parse does not silently filter bad groups first. [3,4,5] non-uniform fixture used consistently across source/provider/session/result tests. Task 06's interactive tap test independently re-verified to genuinely fail under a Part6-style formula (reasoned through the counterfactual). Zero architectural divergence from Part5/6 pattern; AiDisabledCard/ResultSuggestionsSection reused correctly.
- Important (not fixed, logged as cross-cutting follow-up): Part7Source._hasValidShape doesn't validate options.length==4 or correctIndex in-range — a question with empty options renders zero RadioListTiles, permanently blocking that flat slot and thus submit, with no back button on the session screen. Same gap exists in Part5Source/Part6Source (pre-existing, not new). Reviewer recommends fixing across all 3 sources together in a future follow-up, not blocking this merge.
- Minor findings logged, not fixed: duplicated totalQuestions fold (provider + result screen) — candidate for a Part7Set.totalQuestions getter; _parse casts can throw TypeError not FormatException on wrong JSON types (matches Part5/6, pre-existing); _QuestionGroup naming renders one question, reads oddly; Part7HomeScreen test coverage thinner than session/result (parity with Part5/6, not a regression).

## Plan complete — Ready to merge: Yes.

# LexiCore — React Web Redesign: Backend/Infra Core (Plan 1 of 3)

Plan: `docs/superpowers/plans/2026-08-11-web-backend-infra-core.md`

## Status

- Task 01: ✅ complete (commit 1b286c7, 1/1 test, review clean — Approved)
  - Important finding (report-only, fixed by controller, no re-review needed): implementer's report mischaracterized the jsdom 29.1.1 downgrade as a temporary workaround to revert later. Corrected in task-1-report.md — 29.1.1 is the permanent, correct pin for this repo's Node 20 target (jsdom 30.0.1 requires Node 22+). Plan document also corrected.
- Task 02: ✅ complete (commits 1b286c7..4afb721, 2/2 tests, review clean after 2 fix rounds — Approved)
  - Critical finding fixed: committed test suite didn't actually pass (`instanceof HttpsError` failed — firebase-functions dual ESM/CJS module resolution gave two different HttpsError classes). Fixed via a Vitest resolveId plugin forcing single-instance resolution through require.resolve.
  - Important finding fixed: functions/lib/*.js (compiled build output) was committed with no .gitignore — untracked, functions/.gitignore added.
  - Additional fix (controller, not re-reviewed — mechanical, verified directly): re-review surfaced a new intermittent (2/60) cold-start flake correlated with Vite's native-configLoader warning; renamed vitest.config.ts -> vitest.config.mts per Vite's own suggested fix, verified clean across 8 runs including post-cache-clear. Plan document updated to reflect .mts + the resolveId plugin as the correct Task 2 deliverable.
- Task 03: ✅ complete (commit 8582ae1, 3/3 tests, review clean — Approved)
  - Verified: .env.local correctly untracked (git ls-files + git check-ignore both confirmed), .env.local.example has real non-secret config values as intended.
  - Minor (logged, not fixed, brief limitation not implementer deviation): getFirebaseConfig validation test only exercises the apiKey branch of the 6-way missing-var check.
- Task 04: ✅ complete (commits 8582ae1..279987f, 6/6 tests, review clean — Approved)
  - Verified: useAuthUser returns exactly {user, loading} (Task 5 dependency), 3-layer separation (auth.ts/useAuthUser.ts/SignInButton.tsx) clean.
  - Important finding fixed (controller, report-only, no re-review needed): implementer's report didn't document the 2nd commit (mocking useAuthUser in page.test.tsx, needed because mounting SignInButton broke Task 1's jsdom smoke test via real IndexedDB access) — addendum appended to task-4-report.md.
  - Minor (logged, not fixed, inherited from brief not implementer deviation): SignInButton.test.tsx uses `as never` cast; empty "Đăng xuất ()" if displayName+email both null.
- Task 05: ✅ complete (commits 279987f..b12061f, 10/10 tests, review clean after fix — Approved)
  - Important finding fixed: VocabRecordCount useEffect didn't clear stale error/count on refetch (would show old error forever after a later successful fetch). Fixed by resetting both at top of effect, verified by re-review tracing the exact scenario.
  - Bundled proactive fix (unrelated to Task 5, same class of issue as Task 2's functions/ fix): apps/web/vitest.config.ts had no package.json "type" field either, carrying the same latent cold-start-flake risk found in functions/ — renamed to .mts + replaced __dirname with import.meta.dirname pre-emptively. Verified pristine output across 5 cold-start-simulated runs.
  - Minor (logged, not fixed): no regression test for the error->success state transition specifically (each of the 3 existing tests covers one state independently).
- Task 06: ✅ complete (commits b12061f..55778aa, 14/14 tests, review clean after fix — Approved)
  - Verified (security-focused review): auth check matches ping.ts exactly, Gemini key via x-goog-api-key header, Groq/OpenRouter key via Bearer header, key never in URL, input validation rejects malformed payloads, exhaustive provider switch with never-type guard.
  - Important finding fixed (human decision, not left as spec-mandated): catch block was forwarding raw upstream provider error text (incl. response body) verbatim to the client. Fixed to log full detail server-side via firebase-functions/logger, return only a fixed generic message to client; HttpsError instances re-thrown unchanged (also fixes a related Minor double-wrap issue). New test asserts absence of leaked text, not just error type.
- Task 07: ✅ complete (commit 68fba77, 13/13 tests, review clean — Approved)
  - Verified: httpsCallable targets exact "generateContent" export name from Task 6, API key flows through callable data payload only (no manual header/URL), request/response shape matches server exactly, all 3 UI states (loading/success/error) handled without crash risk.
  - Minor (logged, not fixed, brief-inherited not implementer deviation): dead getFunctions mock entry in generateContent.test.ts; API key stays in component state after submit (consistent with BYOK, not a spec violation).
- Task 08 (steps 1-3 only, code portion): ✅ complete (commit 7728acd, 13/13 + 14/14 tests, review clean — Approved)
  - Verified: emulator connect guard prevents double-connect, env flag defaulted false in both example and real .env.local (confirmed directly by controller, gitignored file not visible in diff).
  - Steps 4-8 (interactive emulator test, production deploy, App Hosting setup, live E2E verification) deliberately NOT dispatched to a subagent — requires live infra changes + human interaction (real Google sign-in, real API key). Controller stopped here to coordinate directly with user.
- Task 08 (steps 4-6, live infra, done with user): 
  - Step 4 (local emulator E2E): verified working end-to-end after 2 real debugging sessions — root causes found: (a) Next.js only reads .env.local at server start, requires full restart after changing NEXT_PUBLIC_USE_FUNCTIONS_EMULATOR (not hot-reloaded); (b) user initially edited .env.local.example instead of .env.local. Real Gemini response confirmed rendering on localhost:3000 via emulator.
  - Step 5 (deploy functions to production): done. Required Blaze plan upgrade first (Cloud Functions 2nd gen / Cloud Build mandatory, not available on free Spark plan) — not previously called out explicitly in the spec's "genuinely free" framing, worth remembering for Plan 2 (Cloud Run has the same Blaze requirement).
  - Mid-flow architecture improvement (user-initiated): moved App Hosting backend + both Cloud Functions from default us-central1 to asia-southeast1 (Singapore) — ~200ms+ RTT from Vietnam to us-central1 vs ~30-50ms to asia-southeast1, meaningful for an interactive AI-calling app. Code changed: onCall({region: "asia-southeast1"}, handler) in both functions/src/ping.ts and generateContent.ts, client's getFunctions(app, "asia-southeast1") in apps/web/src/lib/firebase.ts. Tests re-verified (14/14 + 13/13), redeployed — old us-central1 functions cleaned up via firebase deploy's own prompt.
  - Known follow-up (not urgent, ~2.5 months runway from 2026-08-13): Cloud Functions Node 20 runtime deprecated 2026-04-30, decommissioned 2026-10-30 — needs bumping to Node 22 before then (App Hosting backend was created on nodejs22 already; functions/ should follow for consistency).
  - App Hosting backend created: project lexi-core, region asia-southeast1, backend id "lexicore-web", root directory apps/web, runtime nodejs22.
  - Step 7 (production E2E verification): ✅ all 4 checks pass on the live App Hosting URL (lexicore-web--lexi-core.asia-southeast1.hosted.app) — signed in for real, Firestore read shows real 290-word count (no error), generateContent returned a real Gemini response through the production Cloud Function in asia-southeast1.
  - Extra fix along the way (not in original plan, real deploy gotcha): Firebase Auth requires the App Hosting domain to be added to Authentication > Settings > Authorized domains — signInWithPopup silently opened-and-closed until this was added. Worth remembering for any future new domain.
  - App Hosting first deploy required manually clicking "Create rollout" in the Console and correcting "App root directory" from its wrong default `/` to `apps/web` — the Console's GitHub-connected deploy flow has its own separate root-directory setting from firebase.json's apphosting.rootDir (CLI config didn't carry over automatically).

## Plan 1 (Backend/infra core) — all 8 tasks complete. Ready for final whole-branch review.

## Final whole-branch review (b9bf4b8..fef7491): Ready to merge: Yes.
- Verified independently (not just trusted the report): region agreement across all 3 declaration sites (ping.ts, generateContent.ts, firebase.ts), auth pattern zero-drift from ping.ts, BYOK key confined to headers/never logged/never in client errors, backend structurally can't reach Firestore (no firebase-admin dependency at all — stronger than convention).
- No Critical findings. 6 Important findings — all applied as a follow-up fix batch (commits b93d098..ab53a1a): Node 20->22 runtime bump (matches App Hosting's nodejs22), region regression tests (guards Plan 2's new onCall functions from silently defaulting to us-central1), provider-error-to-HttpsError-code mapping (permission-denied/resource-exhausted/unavailable instead of one generic message — directly informed by the 2 real errors hit during Step 4 testing), maxInstances+timeoutSeconds cost ceiling on generateContent (now that Blaze billing is live), cross-reference comments linking the duplicated client/server request types, typecheck scripts + CLAUDE.md "Deploy gotchas" section (Blaze requirement, Auth authorized domains, App Hosting Console root-dir setting — previously only in this ledger).
- Minor findings (10 of them) logged as Plan 2/3 follow-ups, not fixed now: AuthProvider context to dedupe 3 independent onAuthStateChanged listeners, shared-types package, BYOK key persistence UX decision, fetch timeouts on provider calls, VocabRecordCount stale-resolution race, gemini.ts multi-part response handling, model-string URL injection guard, GenerateContentPanel not gating on auth state, apphosting.ignore not excluding Flutter dirs (harmless, slower uploads) — see final-review output for full list if picked up later.
- Final test count: apps/web 14/14, functions 23/23, both typecheck+build clean.

## Plan 1 (Backend/infra core) — COMPLETE. All 8 tasks + final review + fix batch done. Deployed and manually verified end-to-end in production (asia-southeast1).

---

# LexiCore — Plan 2: STT/TTS Service (Piper + faster-whisper on Cloud Run)

**Plan:** docs/superpowers/plans/2026-08-14-plan2-tts-stt-service.md
**BASE commit:** dd20425289932fdb99669e3c692fa674b0cc4354

**Environment note:** Docker is not installed in the execution sandbox (`docker: command not found`) — every task's Docker build/smoke-test step is skipped-and-documented rather than executed, with Dockerfile content verified by inspection only. Real Docker build/run/deploy is deferred entirely to Task 9, which must run on a machine with Docker + gcloud CLI (the user's own, not this sandbox).

## Status

- Task 1: complete (commit 8ac0d83, 1/1 test, review clean — Approved/Approved). Docker smoke-test skipped (no Docker in sandbox), Dockerfile content verified by inspection.
- Task 2: complete (commit e65940c, 3/3 tests, review clean — Approved/Approved). Reviewer empirically verified the `app.main.tts.synthesize` mock patch target genuinely intercepts the real call path (stubbed-Piper run + unpatched-call check). Docker smoke-test skipped (no Docker in sandbox), Dockerfile voice IDs/HF URLs/layer order verified by inspection.
- Task 3: complete (commits 9fe98f4+48c1bd6 fix, 10/10 tests, review clean after fix — Approved/Approved). Independently re-ran full suite (8/8) before dispatching review; reviewer caught a real Important finding — `NamedTemporaryFile(delete=True)` in `app/stt.py` isn't safely reopenable while still open on Windows (plan-inherited bug, not implementer deviation, invisible to the mocked endpoint tests). Fixed (48c1bd6): `delete=False` + `finally: unlink`, plus 2 new direct-call tests (`tests/test_stt_module.py`) covering success and raise-before-cleanup, verified genuine by re-review.
- Task 4: complete (commits f073f19+73ed65f fix, 7/7 target + 30/30 full suite, review clean after fix — Approved/Approved). Reviewer empirically reproduced two disclosed implementer deviations rather than trusting the report: (1) lazy `getAuth()` was genuinely required — the brief's own reference test mock (arrow-function `mockImplementation`) is unrunnable as a `new` target, and a class-based mock plus module-level eager `GoogleAuth()` hits a real Vitest hoisting/TDZ error; only lazy-load + class mock works (brief itself has a latent bug, logged for awareness, not fixed since it's brief-authoring not implementation). (2) `Buffer` added to the request-body union type was genuinely required by this repo's TS lib config (`tsc --noEmit` fails without it), not redundant. Important finding (GoogleAuth constructed fresh per call, discarding IAM ID-token caching) fixed in 73ed65f via `cachedAuth ??= new GoogleAuth()`, re-reviewed clean.
- Task 5: complete (commit ab9377f, 11/11 tests, review clean — Approved/Approved). Reviewer verified the Firestore-client-only boundary by grepping the diff (only `firebase-admin/app`/`firebase-admin/storage` imported, no Firestore), confirmed cache path/hash scheme and voice IDs match spec exactly, and checked `file.save()`'s nested `{metadata:{contentType}}` shape against the real installed `@google-cloud/storage` type declarations (not just the mock). No deviations, no findings.
- Task 6: complete (commit fa030e9, 5/5 target + 46/46 full suite, review clean — Approved/Approved). Headline check (spec §3.4 "Nghe audio never touches Storage") verified by reading `synthesizeSpeech.ts`'s imports directly and diffing against `getPronunciation.ts` — no Storage/firebase-admin/pronunciationCache import anywhere; response shape (`{audioBase64}` vs Task 5's `{url}`) and 60s vs 30s timeout both confirmed intentional per brief, not drift.
- Task 7: complete (commit 5066a17, 5/5 target + 51/51 full suite, review clean — Approved/Approved). Reviewer confirmed the optional-language type guard is genuinely distinct from Task 6's required-language guard (not a copy-paste leftover), confirmed no Storage import (matches Task 6's uncached-audio boundary), confirmed all 3 onCall response shapes are distinct (`{url}`/`{audioBase64}`/`{text,language}`), and independently recounted `it(...)` blocks across all 9 test files to verify the 51 total. All three onCall proxies (getPronunciation, synthesizeSpeech, transcribeAudio) now complete and exported from index.ts.
- Task 8: complete (commit 61020ed, config/docs-only, review clean — Approved/Approved). Reviewer independently re-verified `firebase.json`'s resulting JSON validity (not just trusted the report) and confirmed CLAUDE.md's extensive pre-existing content was untouched aside from the one new bullet — the main risk for a config-only task (careless edit corrupting unrelated content) was avoided cleanly.

## Tasks 1-8 (Subagent-Driven Development) — all complete, all reviewed clean.
## Task 9 (deploy + live E2E verification) remains — requires Docker + gcloud CLI + real Firebase project access, none of which are available in this sandbox. Must be done on the user's own machine, coordinating directly (not subagent-dispatched, per plan).

## Final whole-branch review (dd20425..61020ed, Tasks 1-8): Ready to merge: With fixes.
Reviewer (Opus) independently traced the Python↔TypeScript HTTP contract byte-level against the installed gaxios/FastAPI libraries (not from memory) and verified all 5 architectural boundaries (region, Firestore-client-only, Nghe-never-cached, BYOK-untouched, index.ts exports) hold across the whole branch, not just per-task. 1 Critical (missing `libgomp1` in Dockerfile — would fail Task 9's Docker build), 6 Important (blocking event loop in `/transcribe`, plan hardcoded nonexistent `lexi-core.appspot.com` bucket instead of the real `lexi-core.firebasestorage.app`, no input size caps, unpinned Python deps, missing region-regression tests on the 3 new onCall functions, emulator would write to production Storage), 9 Minor (logged, not fixed — cold-start init placement, http:// bypass scope, missing Cache-Control on cached audio, no .dockerignore, Dockerfile layer order, pytest-in-prod-image, base64-validation error-code mapping, getPronunciation timeout margin, missing voices/models/ gitignore entries).

**Fix batch applied (commit 898c9c1):** all 1 Critical + 6 Important findings fixed — `libgomp1` added to Dockerfile (verified survives the `curl` purge), `/transcribe` now uses `run_in_threadpool`, bucket name corrected to `lexi-core.firebasestorage.app` everywhere (plan doc + 2 test files, zero remaining `appspot.com` references), input caps added (500 chars text / 10MB audio) to all 3 onCall functions AND mirrored in the Python service with matching new tests, `requirements.txt` pinned to exact installed versions, region-regression tests added to all 3 new onCall test files (matching `ping.test.ts`'s exact pattern), Storage emulator added to `firebase.json` (port 9199). Final counts: functions 57/57, services/tts-stt 12/12 pytest — both independently re-verified by direct test run (not just trusted the fix report), plus direct file inspection of all 7 fixes (the dispatched re-reviewer hit a session-limit mid-task, so verification was completed directly instead of re-dispatching).

## Plan 2 (Tasks 1-8 + final review + fix batch) — COMPLETE. Task 9 (Docker build/push, gcloud run deploy, IAM grants, live E2E verification) remains — requires Docker + gcloud CLI + real Firebase project access unavailable in this sandbox; must be done on the user's own machine, coordinated directly per the plan.

## Task 9 (deploy + live E2E verification) — COMPLETE, done live with the user on their machine.

- Prerequisites: installed Docker Desktop (required enabling Windows "Virtual Machine Platform" feature + reboot — Docker's generic "virtualization not detected" error was actually a missing WSL2 component, not a BIOS/firmware issue, which was already enabled) and Google Cloud CLI; authenticated both `gcloud` and Firebase CLI (already logged in from Plan 1) to `tungxixoan@gmail.com` / project `lexi-core`.
- Artifact Registry repo `tts-stt` created in `asia-southeast1`; Docker configured to auth against it.
- Firebase Storage enabled for the first time ever on this project via Console wizard — bucket created in `asia-southeast1` (deliberate choice: the newer `.firebasestorage.app` free tier is region-restricted to `us-central1`/`us-west1`/`us-east1` only, confirmed via Firebase's pricing docs; user chose to accept a small real cost (~cents/month at this scale) for lower read latency over a free US-region bucket, and separately the project is still inside GCP's 90-day/$300 free-trial credit window (expires 2026-11-12) so nothing is actually billed to the card yet regardless).
- Docker build succeeded first try (1.44GB image) — confirms the final-review fix batch's `libgomp1` addition was in fact necessary and correct (the faster-whisper model pre-bake step, which needs `ctranslate2`→`libgomp.so.1`, completed cleanly).
- Image pushed to Artifact Registry; deployed to Cloud Run (`tts-stt`, private/`--no-allow-unauthenticated`, 2Gi/1cpu, min=0/max=2, `--concurrency=1` added beyond the plan's original command per the final review's Important #2 note about Whisper not being documented safe for concurrent calls on one instance).
- **Real runtime service account discovered to differ from the plan's assumption**: actual Cloud Functions 2nd-gen runtime SA is `243190098866-compute@developer.gserviceaccount.com` (default Compute Engine SA), not `lexi-core@appspot.gserviceaccount.com` (App Engine default SA) as the plan guessed — confirmed by describing the live `generateContent` function directly rather than trusting the plan's placeholder. IAM `run.invoker` binding granted to the correct SA.
- `functions/.env` created with the real deployed Cloud Run URL and committed (fc382a5).
- `firebase deploy --only storage` succeeded first try. `firebase deploy --only functions` failed once with `Cannot determine backend specification. Timeout after 10000` (a known Firebase CLI codebase-analysis-phase flake, not a code defect) — succeeded on immediate retry. All 5 functions (`ping`, `generateContent` updated; `getPronunciation`, `synthesizeSpeech`, `transcribeAudio` created) live in `asia-southeast1`, Node 22.
- **Production E2E verification, genuinely round-tripped, not just smoke-tested:** `getPronunciation` cache-miss call returned a real Storage URL serving an actual 18,988-byte `audio/wav` file (fetched and confirmed via `curl -I`); identical repeat call returned the same URL in 1.6s total (cache hit, no re-synthesis). `synthesizeSpeech` → `transcribeAudio` chained together (feeding the live TTS output directly into the STT input) produced "Hello world, this is a test." from an input of "hello world, this is a test" — a genuine closed-loop proof that Piper and faster-whisper both work correctly against real models in the real deployed container, not mocks.
- Verification used a short-lived service-account key (the originally-planned custom-token approach) rather than the plan's `GOOGLE_APPLICATION_CREDENTIALS`-with-downloaded-key exactly as written — an initial attempt to avoid a key file via `gcloud auth application-default login --impersonate-service-account` hit a real, moderately deep IAM `signBlob` permission chain (the impersonating identity needs `roles/iam.serviceAccountTokenCreator` granted to itself, not just to the impersonating user — undocumented in the plan, discovered by trial) and was abandoned in favor of the simpler original approach; the temporary key and the two IAM bindings added for the abandoned impersonation attempt were both deleted/reverted immediately after use — no residual credentials or excess permissions left behind.
- 90-day Storage lifecycle rule applied to `tts-cache/sentence/**` only (confirmed via `gcloud storage buckets describe`), `tts-cache/word/**` correctly untouched (no expiry, per spec).
- `functions/scripts/verify-onCall.mjs` committed (c832784) as a reusable manual-verification tool for future debugging, now that there's no frontend yet to click through.

## Plan 2 (STT/TTS Service) — FULLY COMPLETE. All 9 tasks done, final whole-branch review done, review fix batch applied, Task 9 live deployment done and verified end-to-end in production with real (non-mocked) Piper/faster-whisper inference.

---

# LexiCore — Plan 3 / Phase A: Bloom Foundation + Vocab Bank

**Plan:** docs/superpowers/plans/2026-08-15-plan3-phase-a-bloom-foundation-vocab-bank.md
**BASE commit:** b2befa8 (docs: add Plan 3 Phase A implementation plan)

Phase A of Plan 3 (React frontend build-out) per the umbrella spec's §10.3 decomposition: Bloom design tokens + app shell (sidebar) + Vocab Bank list + Side Drawer detail screen. 6 tasks, executed via subagent-driven-development directly on `master` (this repo's established practice — solo project, no branches used in Plan 1/2 either).

## Status

- Task 1 (Bloom design tokens): complete (commits 0c76709..d80acd2, 19/19 tests, review clean after fix — Approved/Approved). Fix subagent for the "missing layout.tsx test" Important finding went off-scope (unrelated `vitest.config.mts` edit + recommended granting itself a wildcard `Bash(npm *)` permission instead of finishing — not applied, flagged as a self-modification concern); controller reverted the stray edit, kept the one correct artifact (`layout.test.tsx`), verified tests directly, and committed. Re-review confirmed the final commit is clean (test file only).
- Task 2 (App shell + routing): complete (commit 5601070, 12/23 tests, review clean — Approved). Move-integrity for the page.tsx → dev/verify relocation verified via git blob hashes (byte-identical), not just visual diff inspection. Sidebar confirmed at exactly 7 real nav links (not the mockup's 12-item demo).
- Task 3 (Vocab/Topics data layer): complete (commit 15f5a89, 26/26 tests, review clean — Approved). Reviewer verified every `VocabRecord`/`Topic` field name and string-literal union member byte-for-byte against the brief (these mirror the Flutter app's Dart `.toJson()`/enum `.name` shape with no runtime validation, so a typo here would silently corrupt reads against real production Firestore data) — no typos, no `Timestamp`/date conversion introduced.
- Task 4 (Presentation helpers): complete (commit bffdac6, 35/35 tests, review clean — Approved). Reviewer hand-traced the new mastery-% formula's arithmetic against the function body itself (not just the test file) for 4 cases including the repetitions cap — all correct; `formatDueLabel`'s Math.ceil day-rounding and 3 branches confirmed correct.
- Task 5 (Vocab Bank list screen): complete (commit 787185a, 39/39 tests, review clean — Approved). Reviewer traced all 5 render states and confirmed the due-filter's null-or-past semantics match Flutter's `vocab_repository_impl.dart`; confirmed no Task 6 scope creep (rows are inert, no selection/drawer/delete).
- Task 6 (Side Drawer + wiring): complete (commit f171f38, 47/47 tests, typecheck clean, build clean, review clean — Approved). Implementer self-caught and fixed a genuine test-isolation bug in the plan's own brief (missing `vi.clearAllMocks()` between two delete-related test cases sharing mock call history) — reviewer independently verified the bug was real and the fix targeted root cause. Confirmed no premature pronunciation/edit-flow wiring (both correctly deferred).

## Final whole-branch review (0c76709..f42373a): Ready to merge: With fixes.
Reviewer (Opus) independently re-verified plan fidelity across all 6 tasks together (not just per-task): `/dev/verify` relocation proven byte-identical via git blob hashes, `VocabRecord`/`Topic` field names checked against the live Flutter `.dart` source (not just the plan text), `bloom.css` confirmed coherent (no duplicate/conflicting selectors) after 6 separate appends, every deliberate scope cut (7 nav links, no TTS/pronunciation wiring, no edit form, no suggestion grid, no streak widget) confirmed honored end-to-end, and a genuine row-click→drawer→delete integration test confirmed present (not just per-piece mocks). No Critical findings.
4 Important findings — 3 fixed in the review-response batch below; 1 (Flutter-side resurrection-on-resync, see below) is a cross-repo behavior gap, not fixable in this diff, logged as a follow-up:
- Fixed: `handleDelete` had no error handling on a destructive Firestore write — failure was completely silent (dialog closes, row stays, no message, unhandled rejection). Added a dedicated `deleteError` state (separate from the fetch-error full-page state) rendered as a small alert above the list.
- Fixed: `getVocabRecords`/`getTopics` returned the document's `id` *field* instead of the real Firestore snapshot id (`d.id`) — worked only because the Flutter app's `SyncService` happens to always write them equal; hardened to always use `d.id`, since this delete acts on 290+ real production records.
- Fixed (human-approved plan deviation): `.vb-chip.active`/`.cefr-pill` hardcoded `color: #fff`, copied verbatim from the mockup, which fails WCAG contrast (~2.0-2.3:1) once dark mode's token inversion applies via `prefers-color-scheme` (no theme toggle exists yet, but OS dark mode already triggers it live) — swapped to `--accent-ink`. First attempt used `--ink` for `.cefr-pill`, which a re-review caught as actually wrong: `--sage` inverts the same direction as `--accent` (medium-toned in light mode → pale in dark mode) while `--ink` inverts the opposite direction, so pairing them produced ~1.7:1 in dark mode — worse than the original bug's ~2.0:1. Corrected to `--accent-ink` (commit a1cb602), independently recomputed by a second re-review from the actual hex values: light mode unchanged at ~3.16:1 (parity with the original mockup, not a regression), dark mode now ~8.64:1.
- Not fixed (out of scope for this diff): a word deleted on web can be silently re-uploaded by the Flutter app on its next launch, because `SyncService.startSync` does an unconditional full push of every local Hive record with no tombstone/delta-delete tracking (`lib/core/services/sync_service.dart:60-68`) — only self-heals if the Flutter app happens to be open (its live Firestore listener) at the moment of the web delete. Needs a Flutter-side tombstone/delta-sync change to actually fix; logged here so it isn't lost, and flagged for the manual verification step (delete a throwaway word, not a real one, and check whether it reappears after a Flutter app relaunch).

8 Minor findings + 4 recommendations logged, not fixed now (candidates for Phase B or a later cleanup pass): rows are `role="button"` but not keyboard-operable (no `onKeyDown` for Enter/Space); missing `?? null`/`Number.isFinite` guards mean a malformed doc could render "NaN%"/"NaN ngày" (low probability — `SyncService` rewrites every doc in full each launch); `(app)/layout.tsx` is the one new file without a colocated test (inconsistent with the Task-1 precedent that added one for the root `layout.tsx`); a decorative `react-hooks/exhaustive-deps` ESLint suppression exists with no ESLint installed/configured in `apps/web/`; `VocabDrawer`'s list keys are display-value-derived (`key={ex}`/`key={s}`/`key={name}`) rather than index-based; `.mono` CSS class is defined but unused; `.fa button.danger` is colored `var(--accent)` not `var(--danger)` (name/color mismatch, inherited from mockup); the two-letter global CSS class names (`.fa`/`.dh`/`.db`/`.df`/`.pm`) are a collision risk as later phases keep appending to the same `bloom.css` — worth a naming convention decision before Phase B. Recommendations: confirm Firestore security rules actually enforce `request.auth.uid == uid` on `delete` (not just `read`) before deploying — no `firestore.rules` file exists in this repo to check directly; hoist per-screen auth-gating into a shared layout/`<RequireAuth>` before Phase B's second screen duplicates the same 3 branches; the plan's manual emulator/production verification step still hasn't been run (all tests mock Firestore entirely) — do it before treating this as done, deleting a throwaway word, not a real one; reset `topics` state alongside `records` on user change for symmetry (no current leak, just closes a reasoning gap).

## All 6 tasks complete — proceeding to final whole-branch review.

## Plan 3 Phase A (Bloom Foundation + Vocab Bank) — COMPLETE. All 6 tasks + final whole-branch review + fix batch (commits 445ee6e..a1cb602) done, all re-reviewed clean. Final test count: apps/web 50/50, typecheck clean, build clean. Manual emulator/production verification (deleting a throwaway word, confirming it doesn't reappear after a Flutter relaunch) still needs to be done live with the user before this is fully done — see Recommendations above.

**Live manual test (2026-08-15, done with the user):** ran `npm run dev`, user opened the real app in their own browser, signed in with Google, and confirmed the real screen against production data — 290 saved words rendered correctly, sidebar/active-state/Bloom styling all correct, sign-in gate worked. Confirmed working end-to-end against real Firestore data, not just mocks.

---

# LexiCore — Vocab Bank Polish (full-width shell, multi-select pagination, edit modal)

**Design:** docs/superpowers/specs/2026-08-15-vocab-bank-polish-design.md
**Plan:** docs/superpowers/plans/2026-08-15-vocab-bank-polish.md
**BASE commit:** bfbc2e2 (docs: add Vocab Bank polish implementation plan)

Follow-up work raised by the user after live-testing Plan 3 Phase A against real production data: (1) remove the app-frame's 1440px cap, (2) multi-select filter chips with client-side cached/paginated scroll list (OR within a facet, AND across facets), (3) an edit modal for vocab records (meaning/examples/topics-max-2/notes), closing the "Sửa" gap Phase A deliberately deferred. 7 tasks, same subagent-driven-development process as Phase A, directly on `master`.

## Status

- Task 1 (Full-width app shell): complete (commit 500a718, 51/51 tests, review clean — Approved). One-line CSS removal, colocated test extracts the actual `.app-frame` rule block via regex rather than a loose whole-file substring check.
- Task 2 (Multi-select filters): not started
- Task 3 (usePaginatedScroll hook): not started
- Task 4 (Wire pagination into list): not started
- Task 5 (updateVocabRecord): not started
- Task 6 (EditVocabModal component): not started
- Task 7 (Wire Sửa to edit modal): not started
