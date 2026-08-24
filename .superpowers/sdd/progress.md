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

# LexiCore — React Web Redesign: Backend/Infra Core (React Web Plan 1 of 3)

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
  - Step 5 (deploy functions to production): done. Required Blaze plan upgrade first (Cloud Functions 2nd gen / Cloud Build mandatory, not available on free Spark plan) — not previously called out explicitly in the spec's "genuinely free" framing, worth remembering for React Web Plan 2 (Cloud Run has the same Blaze requirement).
  - Mid-flow architecture improvement (user-initiated): moved App Hosting backend + both Cloud Functions from default us-central1 to asia-southeast1 (Singapore) — ~200ms+ RTT from Vietnam to us-central1 vs ~30-50ms to asia-southeast1, meaningful for an interactive AI-calling app. Code changed: onCall({region: "asia-southeast1"}, handler) in both functions/src/ping.ts and generateContent.ts, client's getFunctions(app, "asia-southeast1") in apps/web/src/lib/firebase.ts. Tests re-verified (14/14 + 13/13), redeployed — old us-central1 functions cleaned up via firebase deploy's own prompt.
  - Known follow-up (not urgent, ~2.5 months runway from 2026-08-13): Cloud Functions Node 20 runtime deprecated 2026-04-30, decommissioned 2026-10-30 — needs bumping to Node 22 before then (App Hosting backend was created on nodejs22 already; functions/ should follow for consistency).
  - App Hosting backend created: project lexi-core, region asia-southeast1, backend id "lexicore-web", root directory apps/web, runtime nodejs22.
  - Step 7 (production E2E verification): ✅ all 4 checks pass on the live App Hosting URL (lexicore-web--lexi-core.asia-southeast1.hosted.app) — signed in for real, Firestore read shows real 290-word count (no error), generateContent returned a real Gemini response through the production Cloud Function in asia-southeast1.
  - Extra fix along the way (not in original plan, real deploy gotcha): Firebase Auth requires the App Hosting domain to be added to Authentication > Settings > Authorized domains — signInWithPopup silently opened-and-closed until this was added. Worth remembering for any future new domain.
  - App Hosting first deploy required manually clicking "Create rollout" in the Console and correcting "App root directory" from its wrong default `/` to `apps/web` — the Console's GitHub-connected deploy flow has its own separate root-directory setting from firebase.json's apphosting.rootDir (CLI config didn't carry over automatically).

## React Web Plan 1 (Backend/infra core) — all 8 tasks complete. Ready for final whole-branch review.

## Final whole-branch review (b9bf4b8..fef7491): Ready to merge: Yes.
- Verified independently (not just trusted the report): region agreement across all 3 declaration sites (ping.ts, generateContent.ts, firebase.ts), auth pattern zero-drift from ping.ts, BYOK key confined to headers/never logged/never in client errors, backend structurally can't reach Firestore (no firebase-admin dependency at all — stronger than convention).
- No Critical findings. 6 Important findings — all applied as a follow-up fix batch (commits b93d098..ab53a1a): Node 20->22 runtime bump (matches App Hosting's nodejs22), region regression tests (guards React Web Plan 2's new onCall functions from silently defaulting to us-central1), provider-error-to-HttpsError-code mapping (permission-denied/resource-exhausted/unavailable instead of one generic message — directly informed by the 2 real errors hit during Step 4 testing), maxInstances+timeoutSeconds cost ceiling on generateContent (now that Blaze billing is live), cross-reference comments linking the duplicated client/server request types, typecheck scripts + CLAUDE.md "Deploy gotchas" section (Blaze requirement, Auth authorized domains, App Hosting Console root-dir setting — previously only in this ledger).
- Minor findings (10 of them) logged as React Web Plan 2/3 follow-ups, not fixed now: AuthProvider context to dedupe 3 independent onAuthStateChanged listeners, shared-types package, BYOK key persistence UX decision, fetch timeouts on provider calls, VocabRecordCount stale-resolution race, gemini.ts multi-part response handling, model-string URL injection guard, GenerateContentPanel not gating on auth state, apphosting.ignore not excluding Flutter dirs (harmless, slower uploads) — see final-review output for full list if picked up later.
- Final test count: apps/web 14/14, functions 23/23, both typecheck+build clean.

## React Web Plan 1 (Backend/infra core) — COMPLETE. All 8 tasks + final review + fix batch done. Deployed and manually verified end-to-end in production (asia-southeast1).

---

# LexiCore — React Web Plan 2: STT/TTS Service (Piper + faster-whisper on Cloud Run)

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

## React Web Plan 2 (Tasks 1-8 + final review + fix batch) — COMPLETE. Task 9 (Docker build/push, gcloud run deploy, IAM grants, live E2E verification) remains — requires Docker + gcloud CLI + real Firebase project access unavailable in this sandbox; must be done on the user's own machine, coordinated directly per the plan.

## Task 9 (deploy + live E2E verification) — COMPLETE, done live with the user on their machine.

- Prerequisites: installed Docker Desktop (required enabling Windows "Virtual Machine Platform" feature + reboot — Docker's generic "virtualization not detected" error was actually a missing WSL2 component, not a BIOS/firmware issue, which was already enabled) and Google Cloud CLI; authenticated both `gcloud` and Firebase CLI (already logged in from React Web Plan 1) to `tungxixoan@gmail.com` / project `lexi-core`.
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

## React Web Plan 2 (STT/TTS Service) — FULLY COMPLETE. All 9 tasks done, final whole-branch review done, review fix batch applied, Task 9 live deployment done and verified end-to-end in production with real (non-mocked) Piper/faster-whisper inference.

---

# LexiCore — React Web Plan 3 / Phase A: Bloom Foundation + Vocab Bank

**Plan:** docs/superpowers/plans/2026-08-15-react-web-plan3-phase-a-bloom-foundation-vocab-bank.md
**BASE commit:** b2befa8 (docs: add React Web Plan 3 Phase A implementation plan)

Phase A of React Web Plan 3 (React frontend build-out) per the umbrella spec's §10.3 decomposition: Bloom design tokens + app shell (sidebar) + Vocab Bank list + Side Drawer detail screen. 6 tasks, executed via subagent-driven-development directly on `master` (this repo's established practice — solo project, no branches used in React Web Plan 1/2 either).

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

## React Web Plan 3 Phase A (Bloom Foundation + Vocab Bank) — COMPLETE. All 6 tasks + final whole-branch review + fix batch (commits 445ee6e..a1cb602) done, all re-reviewed clean. Final test count: apps/web 50/50, typecheck clean, build clean. Manual emulator/production verification (deleting a throwaway word, confirming it doesn't reappear after a Flutter relaunch) still needs to be done live with the user before this is fully done — see Recommendations above.

**Live manual test (2026-08-15, done with the user):** ran `npm run dev`, user opened the real app in their own browser, signed in with Google, and confirmed the real screen against production data — 290 saved words rendered correctly, sidebar/active-state/Bloom styling all correct, sign-in gate worked. Confirmed working end-to-end against real Firestore data, not just mocks.

---

# LexiCore — Vocab Bank Polish (full-width shell, multi-select pagination, edit modal)

**Design:** docs/superpowers/specs/2026-08-15-vocab-bank-polish-design.md
**Plan:** docs/superpowers/plans/2026-08-15-vocab-bank-polish.md
**BASE commit:** bfbc2e2 (docs: add Vocab Bank polish implementation plan)

Follow-up work raised by the user after live-testing React Web Plan 3 Phase A against real production data: (1) remove the app-frame's 1440px cap, (2) multi-select filter chips with client-side cached/paginated scroll list (OR within a facet, AND across facets), (3) an edit modal for vocab records (meaning/examples/topics-max-2/notes), closing the "Sửa" gap Phase A deliberately deferred. 7 tasks, same subagent-driven-development process as Phase A, directly on `master`.

## Status

- Task 1 (Full-width app shell): complete (commit 500a718, 51/51 tests, review clean — Approved). One-line CSS removal, colocated test extracts the actual `.app-frame` rule block via regex rather than a loose whole-file substring check.
- Task 2 (Multi-select filters): complete (commit 94bed35, 61/61 tests, review clean — Approved). OR-within/AND-across semantics hand-verified by reviewer against `matchesFilters` with 2 concrete scenarios. Implementer disclosed and fixed 2 real bugs in the plan's own brief test code (topic chip test needed a `getTopics` fixture to render at all; `getByText("B2")`/`getByText("C1")` were ambiguous against row `.dot` badges showing the same text) — reviewer independently confirmed the ambiguity was real (row is a `role="button"` div with 4 concatenated spans as its accessible name) and the `getByRole` fix correctly disambiguates without weakening intent.
- Task 3 (usePaginatedScroll hook): complete (commit a597d7c, 6/6 hook tests + 67/67 full suite, review clean — Approved/DONE_WITH_CONCERNS). Hook implementation verified byte-for-byte identical to the brief (zero production-code changes). Implementer's sole deviation — wrapping `FakeIntersectionObserver.trigger()`/native `.click()`/`rerender()` in RTL's `act()`, required under React 19's automatic batching when state updates originate outside a real React event handler — was independently reproduced empirically by the reviewer (stripped the `act()` calls, reran, got the exact same stale-DOM failures the implementer described, then restored). Genuine React 19/RTL requirement, not a masked bug. **Note for Task 4:** its new tests also drive `FakeIntersectionObserver` directly — must use the same `act()` pattern.
- Task 4 (Wire pagination into list): complete (commit e423164, 69/69 tests, review clean — Approved). Reviewer confirmed the DOM positional contract (rows-then-sentinel) is honored and the empty-state check correctly kept `filtered.length` (semantically correct) rather than switching to `visibleItems.length`. No `act()` gap — this task's new tests only drive `fireEvent.click` (self-wrapping), never manually trigger the fake IntersectionObserver. Controller cleanup along the way: deleted a stray untracked reproduction file left by Task 3's reviewer (`usePaginatedScroll.noact.test.tsx`, never committed) and separately committed unrelated auto-generated Next.js files (`apps/web/AGENTS.md`/`CLAUDE.md`/`next-env.d.ts`, commit 205033f) that had accumulated from earlier manual dev-server testing.
- Task 5 (updateVocabRecord): complete (commit b4c0017, 70/70 tests, review clean — Approved). `doc()` ref construction verified identical to `deleteVocabRecord`'s existing pattern; test asserts real `updateDoc` call arguments, not just success.
- Task 6 (EditVocabModal component): complete (commit 877c491, 77/77 tests, review clean — Approved). Reviewer hand-traced the max-2-topics cap logic and confirmed the component only ever calls the `onSave` prop, never Firestore directly (type-only imports from vocabRecords.ts, no `updateVocabRecord` import) — correctly keeps Firestore isolation for Task 7 to wire.
- Task 7 (Wire Sửa to edit modal): complete (commit 893769e, 79/79 tests, typecheck clean, build clean, review clean — Approved). Reviewer verified the in-place update never triggers a refetch (traced `setRecords` map vs the gated `getVocabRecords` call), and independently confirmed a disclosed test-assertion change (getByText → getAllByText length 2, needed because Tasks 2/4 added inline row meaning text after this plan was written) genuinely strengthens rather than weakens the in-place-update check — both text sources trace to the same `records` state, so a partial-update bug would fail the assertion, not coincidentally pass it.

## All 7 tasks complete — proceeding to final whole-branch review.

## Final whole-branch review (ec82319..6ce09f3): Ready to merge: With fixes.
Reviewer (Opus) independently re-verified all 7 tasks together, re-ran the suite/typecheck, and confirmed `updateVocabRecord` keys off the real Firestore document id (Phase A's earlier id-vs-field bug was NOT reintroduced), no dead code from the old single-select `FilterKey` design, `bloom.css` still coherent after 7 more appends on top of Phase A's 6, and a genuine row→drawer→Sửa→save→both-update integration test exists. No Critical findings.
2 Important findings, both empirically reproduced by the reviewer (not just read from code) — logged as follow-up Tasks 8-10 below rather than fixed in a same-day batch, since they needed real design decisions from the user:
- Saving an edit or deleting a record collapsed the paginated list back to page 1, because `usePaginatedScroll` reset whenever `items` (the filtered array) got a new reference — which happens on every `setRecords` call, not just a filter change.
- The page-number bar's active highlight only ever increased (tracked "how much has been revealed", not "which page the user last clicked") — flagged as a plan flaw for the human to confirm, not just an implementation bug, since the plan's own Task 3 code (verbatim) had this shape.
9 Minor findings + 4 recommendations logged, not fixed: rows not keyboard-operable, no `Number.isFinite` guard on malformed docs, `handleUpdate`'s early-return guard can wedge the modal's Lưu button forever if `!selected` (unreachable today), `updatedAt` not mirrored into local state after an edit, `usePaginatedScroll`'s `PAGE_SIZE` hardcoded not parameterized, positional-DOM-contract fragility undocumented, stale-closure risk in an effect keyed on `items.length` instead of `items`, `EditVocabModal` a11y gaps (no `aria-modal`, no focus trap/restore, no Escape-to-close), `.vb-list-wrap`'s fixed 560px max-height now sits inside an uncapped full-width frame (Task 1 × Task 4 interaction). Recommendation: confirm Firestore security rules actually permit `update` on `vocab_records` (not just `read`/`delete`) before trusting a real "Lưu" — no `firestore.rules` file exists in this repo to check directly.

## User follow-up after live testing (2026-08-15): asked why Vocab Bank's topic filter only showed ~7 of the 20+ topics that exist in the Flutter app's predefined list. Investigated `lib/features/vocabulary/presentation/screens/vocab_bank_screen.dart` — Flutter doesn't use inline chips at all, it opens a bottom-sheet multi-select over ALL synced topics (plus lets users add custom ones, not in scope here). Used the brainstorming skill's visual companion (browser mockup, `.superpowers/brainstorm/336-1786806843/`) to mock up and let the user visually compare two web-appropriate display strategies (an anchored multi-select popover vs. an inline "Xem thêm" expand) side by side with real Bloom-styled chips — user picked the popover (matches spec §7.3's already-established pattern for the same problem). Folded into the plan as Task 9, alongside Task 8 (fixing the pagination-reset bug above) and Task 10 (windowing the page-number bar — user separately noticed 29 page buttons rendering at once and asked for it, confirmed pattern `1 … 4 5 [6] 7 8 … 29`). Design addendum: `docs/superpowers/specs/2026-08-15-vocab-bank-polish-design.md` §6.

## Status (addendum)

- Task 8 (Fix pagination reset-on-mutation + track real scroll position): complete (commit 7de0599, 81/81 tests, review clean — Approved/DONE_WITH_CONCERNS). Implementer self-caught a real gap in the plan's own hook code (sentinel-triggered auto-reveal never advanced the tracked page, only manual jump-to-page did) and fixed it with an optimistic `setViewedPage` mirroring `jumpToPage`'s existing pattern. Reviewer independently ran the hook's test file directly (8/8 pass) and algebraically proved both call sites compute the identical page number via two different formula shapes — not a divergent fix that happens to pass tests. Confirmed the backward-correction path (scrolling back up) still works, so bug #2 (page bar only increasing) was not reintroduced.
- Task 9 (Topic filter — popover): complete (commit ecf20d4, 86/86 tests, review clean — Approved). Reviewer specifically confirmed the popover shows every topic unfiltered (no `.filter()` narrowing it back down to the old "only topics with saved words" behavior — the exact bug this task exists to fix) and that both pieces of required dead code (`topicChips`, `toggleTopic`) were fully deleted, not left unreferenced.
- Task 10 (Windowed page-number bar): complete (commit 156b83f, 92/92 tests, review clean — Approved). Reviewer hand-traced `getPageWindow` at every boundary (middle/near-start/near-end/single-page) against the actual algorithm, confirmed no off-by-one duplicate-page-number bugs, and confirmed the diff's 25 changed `page.tsx` lines are entirely the `.vb-pagination` block + import — Task 8's `usePaginatedScroll` call and Task 9's `TopicFilterPopover` wiring verified untouched.

## All 10 tasks complete — proceeding to addendum whole-branch review.

## Addendum whole-branch review (99532e1..3be1bba): Ready to merge: With fixes.
Reviewer (Opus) traced all 4 named cross-task interactions directly against the current file state (not per-task diffs): confirmed `filterSignature` is built from filter *values* not identity (so a no-op "Áp dụng" doesn't spuriously reset pagination, and a genuine topic change correctly does), confirmed `getPageWindow(currentPage, totalPages)` is evaluated inline every render so scrolling genuinely re-centers the window, confirmed Task 9's dead code (`topicChips`/`toggleTopic`) is fully gone with zero orphan references, and hand-traced the two-observer design to rule out feedback-loop oscillation between the reveal and scroll-tracking `IntersectionObserver`s. No Critical findings.
2 Important findings, both fixed in the review-response batch below:
- `usePaginatedScroll`'s sentinel-reveal handler called `setViewedPage` from inside a `setVisibleCount` state updater — a React rules-of-hooks violation (updaters must be pure; React can invoke them multiple times including during render, e.g. under StrictMode). Converged correctly today by coincidence (deterministic inputs), but a trap for future edits to that code. Fixed by hoisting `visibleCount` into a ref mirrored via its own effect, read from (not written from within) the updater.
- No test exercised the actual Task 8×9×10 seams — the exact shape of gap that let the two original bugs through a green suite in the first place. Added 2 tests: clicking a distant page re-centers the windowed bar (8×10), and applying a topic filter resets pagination while a same-filter edit/delete does not (9×8).
5 Minor findings bundled into the same fix batch (all cheap, same files already being touched): `currentPage` now clamped to `totalPages` (was capable of pointing past the end transiently after a narrowing filter, or persistently after deleting from a late page); scroll-tracking effect's dependency array now includes `items` (was stale after a delete — could map a phantom page marker onto the sentinel once `visibleCount` exceeded the shrunk `items.length`); `pageWindow.ts`'s local `window` variable renamed to `pages` (was shadowing the DOM global); `getTopics` now falls back to `📌` for a missing `emoji` field (mirrors Flutter's own defensive read) since `TopicFilterPopover` newly renders that field for every synced topic, unvalidated; `TopicFilterPopover`'s dead `useState` initializer (computed a throwaway `Set` every render, immediately overwritten on open) simplified to an empty `Set()`.
3 Minor findings + 1 recommendation logged, not fixed — deferred: `EditVocabModal`/`TopicFilterPopover` a11y gaps (no `aria-modal`, focus trap/restore, Escape-to-close, click-outside — same class already logged for Tasks 1-7, new component instance); the topic popover can overflow the right edge on narrow viewports (fixed 320px width, position depends on toolbar wrap); account-switching no longer resets the revealed row count (Task 8's `resetKey` deliberately excludes `user` — cosmetic at this single-user-app scale, noted for the record only, explicitly not to be "fixed"). Recommendation (carried over from the Tasks 1-7 review, still open, unaffected by this addendum since it adds zero Firestore operations): confirm Firestore security rules permit `update` on `vocab_records`, not just `read`/`delete`.

**Fix batch applied (commit 4a37f43):** all 7 fixes (2 Important + 5 bundled Minor) applied. Re-review found 6/7 genuinely correct but caught that the Task 8×9 reset-boundary test only proved the reset-*on*-filter-change half, not the equally-important reset-*not*-happening-on-same-filter-edit/delete half — the actual point of the finding, since that's the exact bug Task 8 exists to fix. Controller added the missing test directly (commit b212d4c: jump to page 3 of 250 records, delete a page-3 record, assert page-3 content — e.g. a different record — is still visible, not collapsed back to page 1) and verified 95/95 passing. Final re-review confirmed the test is a genuine, non-vacuous regression guard (traced that it would fail if the hook's reset effect were keyed on `items` instead of `resetKey`) — Approved.

## Vocab Bank Polish (all 10 tasks + addendum whole-branch review + fix batch, commits ec82319..b212d4c) — COMPLETE, all re-reviewed clean. Final test count: apps/web 95/95, typecheck clean, build clean.

**Live manual verification (2026-08-15, done with the user):** user ran the app locally and confirmed the full flow works — full-width shell, multi-select filter combining, topic popover, scroll/page-bar behavior, and editing a real word (confirming Firestore `update` permission is actually granted, closing the one recommendation that couldn't be verified from source). User confirmed "ổn rồi" (all good). Plan fully done, nothing outstanding.

---

# LexiCore — React Web Plan 3 / Phase B (Part 1): Cài đặt (Settings)

**Design:** docs/superpowers/specs/2026-08-16-react-web-plan3-phase-b-settings-design.md
**Plan:** docs/superpowers/plans/2026-08-16-react-web-plan3-phase-b-settings.md
**BASE commit:** 80d171e (docs: add Cài đặt (Settings) implementation plan)

First of two ordered sub-specs for React Web Plan 3 Phase B (Settings, then Tra từ + Luyện tập). Settings goes first because neither of the other two screens can make repeated AI calls without a persisted BYOK key. 9 tasks: Cloud KMS backend (Tasks 1-2), web data layer (Task 3), UI components (Tasks 4-7), page assembly (Task 8), live GCP infra + deploy (Task 9, not subagent-dispatched). Executed via subagent-driven-development directly on `master`, same as every prior React Web plan.

## Status

- Task 1 (Cloud KMS service + `encryptApiKey` onCall function): complete (commit 3d7c1b0, 67/67 tests, typecheck clean, review clean — Approved). Reviewer verified the no-leak constraint directly (KMS errors wrapped in a generic `HttpsError`, original error discarded not interpolated) and confirmed the region-regression test matches the established per-function convention (`getPronunciation`/`generateContent`/`synthesizeSpeech`/`transcribeAudio`/`ping` all follow the same pattern). Implementer deviated from the brief's suggested Vitest mock construction for `@google-cloud/kms` (class-based mock instead of `vi.fn().mockImplementation()`, which isn't constructor-callable under this project's Vitest 4.1.10) — reviewer independently confirmed this matches pre-existing precedent (`cloudRunClient.test.ts`'s identical class-based mock of `GoogleAuth`) and that every assertion from the brief survived unchanged. 2 Minor findings logged, not fixed: KMS errors aren't logged server-side before being wrapped (matches existing `toHttpsError` convention elsewhere, not a regression — candidate for a codebase-wide logging pass later); whitespace-only `apiKey` input untested (low value, boundary already covered by empty-string case).
- Task 2 (`generateContent` Cloud KMS ciphertext support): complete (commit 212f9d5, functions 71/71 + apps/web 95/95 tests, typecheck clean both sides, review clean — Approved). Reviewer specifically verified the plan-author's own self-review fix (replacing a buggy `not.toHaveBeenCalled()` assertion — which would have spuriously failed since `generateContent.test.ts` accumulates mock call history across the whole file with no reset — with a before/after call-count delta) was carried through correctly by the implementer, and confirmed it's a genuine regression guard, not a weakened one. Confirmed all pre-existing tests untouched/still passing, KMS decrypt failures never reach the provider call, and the client/server duplicated-type sync comments are correct. 1 Minor finding logged, not fixed: `apps/web/src/lib/generateContent.ts`'s colocated test wasn't extended with an `apiKeyCiphertext` case (low value — the client function is a pure `httpsCallable` passthrough with no branching to exercise).
- Task 3 (`apps/web` settings data layer — modelPresets, settings CRUD, useSettings hook, encryptApiKey client): complete (commit 67fd874, 108/108 tests, typecheck clean, review clean — Approved). Largest single task in the plan (8 files). Implementer flagged a flaky failure mid-session in an unrelated pre-existing test (`vocab-bank/page.test.tsx` pagination timing) that reran clean twice; reviewer independently grepped for any import of this task's 4 new modules from the vocab-bank directory (zero matches) and confirmed the flake is genuinely out of scope for this diff. Reviewer confirmed the 4-file separation (static data / Firestore CRUD / React hook / callable wrapper) has no responsibility bleed, and that `useSettings.test.ts` exercises the real async lifecycle (logged-out fast path, error path, save round-trip) rather than happy-path-only. 3 Minor findings logged, not fixed, all narrow/currently-unreachable: `getSettings`'s provider merge is shallow (a partial per-provider doc would lose that provider's individual defaults — not reachable today since `saveSettings` always round-trips the full object); `getSettings` returns the shared `DEFAULT_SETTINGS` object by reference for logged-out/no-doc callers (risk only under a future in-place mutation); `useSettings`'s effect has no stale-response guard for rapid `uid` changes (e.g. fast logout/login racing two `getSettings` calls).
- Task 4 (`ModelPicker` component — preset dropdown + free-text custom model): complete (commit aec779f, 5/5 new tests, typecheck clean, review clean — Approved). Reviewer manually traced the `customMode` state fix (from the plan's own self-review, see plan commit) step-by-step through 6 render cycles and confirmed the dead-end bug it exists to prevent (custom input can never appear because visibility was derived from a `model` prop that can't change until the not-yet-rendered input fires `onChange`) does not regress — selecting "Khác..." genuinely reveals the input on the very next render, independent of the `model` prop. 1 Minor finding logged, not fixed, flagged forward for Task 5: `customMode` is plain local state with no reconciliation on prop change, so if Task 5 renders `<ModelPicker provider={active} .../>` without a `key={active}`, switching AI provider while mid-custom-entry would leave a stale custom input showing over the new provider's (possibly preset) model — controller is passing this to Task 5's dispatch as a `key`-based fix, not touching `ModelPicker.tsx` itself.
- Task 5 (`AiProviderSection` — provider/model/API key UI): complete (commits c84adaf..9da6cd6, 119/119 tests, review clean — Approved). First review returned "Needs fixes" — 1 Important finding: English UI labels ("AI Provider & API Key", "Provider", "API key") violating the plan's Vietnamese-only global constraint, traced to the *plan's own brief* (controller-authored bug, not an implementer deviation). Fix translated the 3 strings ("Nhà cung cấp AI & Khoá API"/"Nhà cung cấp"/"Khoá API") and updated the colocated test's label selectors. Re-review confirmed: all 3 strings translated in final file state, provider proper nouns (Gemini/Groq/OpenRouter) correctly left untouched, fix stayed surgical (encrypt-then-save logic, `key={active}` remount fix from Task 4, masked-placeholder, disabled-button all byte-identical to the already-approved pre-fix version). `ModelPicker`'s own "Model" label (Task 4, out of this task's file scope) was correctly left untouched by the fix — not yet flagged by any reviewer, noted for awareness only.
- Task 6 (`AppearanceSection` + `AppShell` theme/font-size wiring): complete (commit fc1a469, 126/126 tests across 28 files, typecheck clean, review clean — Approved). Widest-blast-radius task so far — modifies `AppShell`, which every real screen renders through. Reviewer independently re-verified (not just trusted the report) that no other screen's tests were put at risk: grepped for every `AppShell` reference in `apps/web/src`, confirmed it's only reachable via the untested `(app)/layout.tsx`, and cross-checked the reported 28-test-file count against the actual file count on disk. All `AppearanceSection` UI text confirmed Vietnamese (heading "Giao diện", labels "Chủ đề"/"Cỡ chữ", options Sáng/Tối/Theo hệ thống and Nhỏ/Vừa/Lớn) — the Task 5 English-label mistake was not repeated. 2 Minor findings logged, not fixed, both inherent to the plan's own client-effect-only design (not implementer deviations): a real (not theoretical) flash-of-wrong-theme on hard page load while `useAuthUser`/`useSettings` are still resolving, since there's no blocking inline script or SSR cookie; `zoom` CSS property is non-standard but broadly supported by this project's target browsers (Firefox added support in 2024).
- Task 7 (`AccountSection` + `DangerZoneSection`): complete (commit f437ba8, review clean — Approved). Smallest task in the plan; byte-for-byte match to the brief, zero scope creep. Vietnamese text re-confirmed correct (no repeat of Task 5's mistake). Reviewer verified `signOutOfFirebase` is a real export (not a broken/fabricated import) and that the sign-out test asserts a real mock call, not just button presence. 1 Minor finding logged, not fixed: `AccountSection` has no fallback for a null `displayName`/`email` (Firebase `User` fields are nullable) — deferred to Task 8 if needed, not required by this task's own brief.
- Task 8 (assemble the `/settings` page): complete (commits 832c609..733ca79, review clean — Approved). `next build` confirmed `/settings` is now a real route, resolving the sidebar link that had 404'd since React Web Plan 3 Phase A. Implementer correctly caught and fixed a brief-staleness bug on their own: the brief's page test still asserted `AiProviderSection`'s pre-Task-5-fix English heading text, corrected to the actual Vietnamese text and verified against the real component source. First review returned "Needs fixes" — 1 Important finding: the new `button.danger` CSS rule (bloom.css, for the Settings sign-out button) had equal specificity to a pre-existing, unrelated `.fa button.danger` rule and sat later in the file, winning the cascade tiebreak and silently restyling the Vocab Bank drawer's already-shipped "Xoá" (delete) button too (also `className="danger"`, matched both selectors) — a real, concrete, untested visual regression, not caught by any test since no CSS regression tests exist in this project. Fix renamed the Settings button's class to `btn-danger`. Re-review independently traced the cascade structurally (not just re-checked specificity/ordering) and confirmed the two selectors now key off fully disjoint class names — VocabDrawer's button still has class `danger` only, Settings' button has `btn-danger` only, zero shared selector surface, not a narrower fix that leaves an edge case.

## All 8 code tasks complete (Tasks 1-8) — Task 9 (live GCP infra + deploy + manual E2E verification) remains. Per the plan's explicit instruction, Task 9 is NOT dispatched to a subagent — it requires live `gcloud`/Firebase CLI access and human interaction, done directly with the user.

## Task 9 (live GCP infra) — steps 1-7 done directly with the user: Cloud KMS API enabled, keyring `lexicore-keys` + key `byok-api-keys` created in `asia-southeast1`, runtime SA confirmed live (`243190098866-compute@developer.gserviceaccount.com`, matches React Web Plan 2's notes), IAM `roles/cloudkms.cryptoKeyEncrypterDecrypter` granted, `functions/.env` updated with KMS config, `generateContent`+`encryptApiKey` deployed live and confirmed. Firestore security rules pulled directly from the live deployment via the Firebase Security Rules REST API (no `firestore.rules` file has ever existed in this repo — a gap flagged by multiple prior reviews, now actually resolved by reading the live rule instead of guessing): `match /users/{uid}/{document=**} { allow read, write: if request.auth != null && request.auth.uid == uid; }` — a recursive wildcard already covering the new `settings/config` doc with zero changes needed.

**Live manual verification with the user surfaced 2 real bugs before the checklist could be honestly marked passed** — both fixed as addendum tasks, same rigor (TDD, dispatch, review) as Tasks 1-8:

- **Task A (cross-component settings staleness):** `AppShell` (app-wide theme/font-size) and the `/settings` page each independently called `useSettings(uid)` — separate hook instances, no shared cache. Changing theme/font-size on the Settings page updated only that page's own local state (plus Firestore); `AppShell`'s separate instance never learned about the change, so the app-wide effect only applied after a full page reload. User found this live, not caught by any prior test (no test exercised two simultaneously-mounted consumers of the same hook). Fix: complete (commit c53284e, 136/136 tests across 33 files, typecheck clean, build clean, review clean — Approved). Introduced `SettingsContext`/`SettingsProvider`/`useSettingsContext` (`apps/web/src/lib/SettingsContext.tsx`), mounted once in `(app)/layout.tsx` above `AppShell`; both `AppShell` and `/settings` now read exclusively through the shared context. Reviewer traced this structurally (not just "does each file have a test"): confirmed the raw `useSettings(` hook has exactly one remaining call site (inside `SettingsProvider`), confirmed `SettingsProvider` is mounted exactly once, and confirmed the new `SettingsContext.test.tsx` genuinely proves single-instantiation (`useSettings` called exactly once) and cross-consumer sharing (two consumers under one provider reach the same `save`). Also fixed a pre-existing gap while touching the file: `(app)/layout.tsx` had no colocated test since React Web Plan 3 Phase A — added one that exercises the real, un-mocked `SettingsProvider`+`AppShell` wiring. Controller independently grepped `apps/web/src/app` to confirm `vocab-bank/page.tsx` (the only other real screen) doesn't duplicate the bug — it calls `useAuthUser` for its own sign-in gate (fine, Firebase's `onAuthStateChanged` is a live listener with no staleness risk) but never calls `useSettings` directly. 2 Minor findings logged, not fixed: `SettingsContextValue` manually re-declares `useSettings`'s return shape instead of `ReturnType<typeof useSettings>` (duplication risk if they drift); the sharing test proves cross-consumer sync via a triggered side effect rather than a direct reference-equality assertion (sufficient given the call-count test, but less literal).
- **Task B (Cài đặt has no Bloom visual design):** complete (commit 628fb7d + spacing fix 98ec259, 136/136 tests, review clean — Approved). The Settings screen shipped functionally complete but visually unstyled (bare HTML form controls, no card grouping, no spacing system) unlike every other screen's `.vb-*`/`.dh`/`.db`-style Bloom CSS — traced to a real plan-authoring gap (the Cài đặt design spec never extracted actual Bloom visual styling for these components, only reused generic `.scr-title`/`.btn-danger`). Fix was a pure additive-className + new-CSS-rules change (new `.settings-page`/`.settings-card`/`.settings-account-name`/`.settings-account-email`/`button.btn-primary` classes) — zero behavior/text/a11y changes, so zero test files needed touching, which the reviewer independently confirmed by checking the diff's file list contained no test files and no accessible-name-affecting changes. Reviewer specifically re-checked for the exact CSS-collision bug class Task 8 hit (grepped the new class names for pre-existing occurrences — none found; confirmed `button.btn-primary` doesn't collide with `.fa button`/`.fa button.danger` the way `button.danger` once did) and confirmed `AiProviderSection.tsx`'s stateful logic (`key={active}`, encrypt-then-save) was byte-identical, only the two intended classNames added. 1 Minor finding — the given CSS's `.settings-card label:last-of-type { margin-bottom: 0; }` rule doesn't work as intended because `ModelPicker` wraps its own "Model" label in a separate `<div>`, so it always independently qualifies as "last" and collapses the gap before the following "Khoá API" field — this was the plan-author's own CSS design flaw (not an implementer deviation), fixed directly by the controller (commit 98ec259, removed the rule entirely rather than trying to scope it more narrowly — leaves a small harmless extra margin below each card's true last field instead of a crowded gap), re-ran the full suite clean (136/136) before committing.
- **Task C (missing "Ngôn ngữ mục tiêu" / target language setting):** complete (commits 64e0072 + 3a2b369, 140/140 tests, review clean — Approved). Found by the user live: Flutter's Settings has a "Ngôn ngữ mục tiêu" picker (5 languages: Việt/Anh/Trung/Hàn/Nhật, `lib/features/dictionary/domain/entities/language.dart`'s `Language` enum, default English) used by the dictionary lookup feature, completely absent from the web Cài đặt design — another real scope gap from the original plan, not just a bug. Added `targetLanguage: TargetLanguage` to `UserSettings` (default `"english"`) and a new `LanguageSection` component between `AccountSection` and `AiProviderSection`. Reviewer did not accept "labels look right" — ran a programmatic codepoint-by-codepoint diff of all 5 `LANGUAGE_LABELS` values (including the 3 non-Latin scripts, 中文/한국어/日本語) against the Dart enum's `label` getter specifically (not `code`/`ttsLocale`, which share the same enum-case names and could be confused) — all exact matches. Also independently traced `getSettings`'s merge logic against a synthetic pre-existing Firestore doc with no `targetLanguage` key at all (the real shape of every production doc written before this field existed) and confirmed it correctly falls through to the `"english"` default, matching the implementer's claim. 1 Minor finding — that exact fallback scenario was traced/claimed but never actually asserted in the test suite — fixed directly by the controller (commit 3a2b369, one-line regression assertion added to the existing merge test), re-verified passing before committing.

## Task 9 + all 3 live-QA addendum tasks (A, B, C) complete. Full web suite: 140/140 tests across 35 files, typecheck clean, build clean.

**Two more live-QA follow-ups (2026-08-16), both handled directly by the controller (no subagent — trivial/documentation-only):**
- **2-column layout** (commit 0f9d9bc): user found the single-column `.settings-page` (capped at 620px) left most of the wide `.app-frame` empty. Switched to a 2-column CSS grid (`max-width: 980px`, `grid-template-columns: 1fr 1fr`), page title spans both columns via `grid-column: 1 / -1`. Pure CSS change, no JSX/test changes needed. 140/140 tests still pass.
- **Per-language `vocab_records` collections — decision recorded, NOT implemented**: user wants `users/{uid}/vocab_records` (one flat collection today, ~290+ real records) split into one Firestore subcollection per target language, now that Cài đặt has the new "Ngôn ngữ mục tiêu" setting. Explicitly scoped to `vocab_records` only (`topics` stays shared). User explicitly chose to record this as a spec decision now rather than implement/migrate real data in this pass — documented in `docs/superpowers/specs/2026-08-11-react-web-redesign-design.md` §9 and in memory (`per_language_vocab_records.md`) with the full list of what implementation will require later: a `getVocabRecords(uid, language)` signature change, a real-data migration script, and a matching Flutter-side change (`vocab_repository_impl.dart`) since both apps share the same Firestore data — needs its own spec → plan cycle before implementation.

Remaining: final live re-verification with the user of the original Task 9 checklist plus these follow-ups — confirm theme/font-size apply without reload, confirm the Settings screen now has real Bloom styling in a 2-column layout, confirm the new Ngôn ngữ mục tiêu field saves/persists correctly.

**Live re-verification (2026-08-16, done with the user): confirmed "ok rồi"** — theme/font-size apply without reload, Bloom styling + 2-column layout both correct, Ngôn ngữ mục tiêu field present and working.

## Final whole-branch review (80d171e..0f9d9bc, 16 commits, reviewed on Opus): Ready to merge: With fixes.
Reviewer independently verified every named cross-task interaction against current file state (not per-commit diffs): `SettingsContext` single-mount point, the Cloud KMS encrypt→decrypt round trip never reaching the provider on failure, `ModelPicker`'s `key={active}` fix still present, CSS layering across 3 successive changes composing cleanly, Vietnamese text held everywhere, `targetLanguage` merge-default correctness. No Critical findings.
4 Important findings, all fixed in one dispatched batch + directly by the controller:
- `functions/.env`, the progress ledger, and the master spec's §9 addition were never actually committed — HEAD couldn't deploy working functions (`encryptApiKey` would throw "Missing Cloud KMS configuration"). Fixed directly by the controller (commit f56805e) before dispatching the rest of the batch.
- **Credential-misrouting bug**: `AiProviderSection`'s `keyDraft`/`error` weren't scoped to the active provider — typing a key for one provider then switching providers before saving would silently encrypt and store that key under the *new* provider. Fixed (commit a012ce9): implementer found the originally-specified `useEffect([active])`-only approach couldn't actually close the window in practice (in the real app, `active` only changes after a Firestore round-trip repopulates the `settings` prop — a window during which a stale draft could still be submitted) and added an imperative clear directly inside the provider `<select>`'s `onChange`, closing the bug the instant the dropdown changes rather than waiting on a prop update. Re-review independently verified this is strictly stronger than the original spec, not a rationalization — traced the exact original bug scenario against the current code and confirmed it's closed via two independent mechanisms (the imperative clear, and the disabled-button guard).
- **KMS ciphertext not bound to the owning user**: `encryptWithKms`/`decryptWithKms` took no Additional Authenticated Data, so a ciphertext wasn't cryptographically tied to the user it was created for (Firestore rules prevented exploitation today, but this removed a defense-in-depth layer for the single most sensitive value in the system). Fixed (commit 498aecb): both functions now require an `aad` parameter; `encryptApiKey`/`generateContent` both pass `request.auth.uid`. Re-review confirmed the same uid is used on both sides of the round trip (required for it to work at all) and that `kms.test.ts` asserts the exact AAD value via whole-object `toHaveBeenCalledWith`, not just a call-count check. **Breaking change, expected and accepted**: the one API key already stored in production (the developer's own Gemini key, from Task 9's manual verification) needs to be re-saved in Cài đặt after this deploys — old ciphertexts can't be migrated (would require the raw key, defeating the point of KMS).
- `AppearanceSection`/`LanguageSection` silently swallowed Firestore write failures (`void onSave(...)` with no `.catch`) — a failed save just snapped the UI back with no message. Fixed (commit 492d721) with the same local-`error`-state pattern `AiProviderSection` already had.
5 Minor findings, 2 fixed directly by the controller (commit 58f8f25, docs/CSS only) and 2 more fixed in the same dispatched batch (commits a7e0893 `AccountSection` null-fallback, a1896e9): the master spec's §7 Key Decisions table still contradicted the already-recorded §3.5 BYOK reversal; a stray double blank line left from an earlier CSS edit; the sign-in/error/loading branches of `settings/page.tsx` reused the 2-column `.settings-page` grid class meant for the 5-card loaded screen; `AccountSection` had no fallback for a null `displayName`/email. 3 further Minors logged, not fixed: `apiKeyCiphertext`'s decrypt path has never run against real KMS yet (nothing calls `generateContent` with a ciphertext until the next sub-spec builds Lookup/Practice hub — worth a one-off manual check before that work starts, not now); `fs-large`'s `zoom: 1.15` combined with `.app-frame`'s `min-height: calc(100vh - 48px)` produces a spurious vertical scrollbar (needs a bigger redesign — a font-size custom property instead of `zoom` — not a quick fix); the encrypt/decrypt error alert shown to the user is in English (`HttpsError` messages aren't translated) despite the Vietnamese-only constraint.

**Fix batch re-review (58f8f25..a1896e9, 5 commits, reviewed on Opus): Sound, Ready to merge: Yes.** Reviewer specifically verified the implementer's Finding-#1 deviation from spec was a genuine improvement (traced the non-optimistic `useSettings.save` to confirm the retained `useEffect` couldn't wipe a freshly-set error, ruling out the one way it could have conflicted with the new imperative clear) and confirmed the KMS AAD values match on both the sole encrypt and sole decrypt call site in the whole codebase (grepped to confirm no other call sites exist). 3 further Minors logged, 2 fixed directly by the controller (commit 608eca2 — stale comment corrected, `authLoading` branch given the missing "Cài đặt" title matching the other 3 non-loaded states), 1 not fixed (a friendlier "khoá API đã bị xoá" hint after a failed provider-switch clears the draft — UX nicety, not a bug).

## React Web Plan 3 Phase B Part 1 (Cài đặt / Settings) — COMPLETE. Design spec, plan, all 8 original tasks, 3 live-QA addendum tasks (A/B/C), a 2-column layout fix, a per-language-vocab-records spec decision (documented, not implemented), final whole-branch review + fix batch + re-review — all done, all re-reviewed clean. Final counts: apps/web 147/147 tests (2 known-flaky pagination-timing tests under heavy machine load, unrelated to this work, independently re-verified passing in isolation multiple times throughout this branch), functions 71/71 tests, both typechecks clean, production build clean. Live-deployed and manually verified end-to-end by the user, including the theme/font-size cross-component sync fix, the Bloom-styled 2-column layout, and the new Ngôn ngữ mục tiêu field.

## React Web Plan 3 Phase B Part 2 (Tra từ / Lookup + Ôn tập / Practice, full-flow) — spec + plan complete, execution not yet started.

Brainstormed (including 4 live visual-companion iterations to finalize the flashcard flip mechanic — settled on a diagonal `rotate3d(1,1,0,...)` hinge with a monotonically-increasing rotation counter, "flashcard-v4-360.html"), spec written and committed (`docs/superpowers/specs/2026-08-16-react-web-plan3-phase-b-part2-lookup-practice-design.md`), and a 12-task implementation plan written and committed (`docs/superpowers/plans/2026-08-16-react-web-plan3-phase-b-part2-lookup-practice.md`).

Key decisions baked into the plan: Ôn tập is **zero-AI** (pure SM-2 flashcard review, deliberately diverging from Flutter's ~70%-AI-generated-exercise behavior — user's explicit simplification call); Lookup's save-to-Vocab-Bank flow reuses `EditVocabModal` in a new "create" mode, edited in-place on the Lookup screen itself; sentence lookups stay translation-only, never saveable (matches Flutter exactly); SM-2 is batch-computed and written only at the session result screen (Task 12), with every per-word result already carrying `vocabRecordId`+`quality` so a future streak/stats feature can hook in without refactoring; sidebar "Luyện tập" renamed to "Ôn tập" (Task 6).

12 tasks: (1) Lookup domain logic — `parseAiJson.ts`, `inputDetector.ts`, `lookup.ts`; (2) Vocab Bank data-layer additions — `getVocabRecordByHeadword`, `saveVocabRecord`; (3) `EditVocabModal` create mode; (4) Lookup page search+display; (5) wire the save flow into Lookup; (6) sidebar rename; (7) SM-2 compute (`sm2.ts`) + `updateVocabRecordSm2`; (8) practice session word-pool selection (`practiceSession.ts`); (9) `FlashcardCard` component; (10) `/practice` setup phase; (11) `/practice` session review loop; (12) `/practice` result screen + batch SM-2 write. Self-review (spec coverage, placeholder scan, type consistency across all 12 tasks) done inline, no gaps found.

**Next up:** dispatch Task 1 (Subagent-Driven execution, matching Part 1's pattern) once the user confirms execution approach. Still outstanding, deferred by explicit user decision: Dashboard + streak collection (its own later phase), Flutter-side sync of both the streak collection and the settings doc, and the per-language `vocab_records` collection split (documented in the master spec §9, needs its own spec → plan cycle).

Task 3: complete (commit f247db4..e103c27, review clean)

Task 4: complete (commit e103c27..59eef67, review found 1 Important — missing settings-loading gate causing a silent no-op click window, baked into the brief itself, fixed directly by the controller in 3 further commits: 32c5dcb pre-existing Task-2 typecheck fix found by the implementer, d47d76e the settings-loading gate). 3 Minor findings logged, not fixed: raw English error text on generateContent failure (pre-existing app-wide convention), search input has no label/aria-label, synonym chip React key could collide on duplicate AI output.

Task 5: complete (commits d47d76e..4680036, review found 1 Important — save-button-absence tests were mislabeled/hollow, fixed in commit 4680036, re-review clean). 2 Minor findings logged, not fixed: preselectTopicIds has no dedup guard against duplicate AI-suggested topic names, buildDraftRecord is called twice per save action (harmless duplicate work).

Task 6: complete (commit 4680036..896468d, review clean)

Task 7: complete (commit 896468d..0387651, review clean — SM-2 formula independently verified branch-by-branch against compute_sm2_use_case.dart, no discrepancy; 2 implementer-flagged deviations (mock-leak test fix, updateDoc spread for a Firestore UpdateData typing quirk) both independently confirmed legitimate)

Task 8: complete (commits 0387651..c5611c3, review found 1 Important — shuffle() had zero test coverage capable of detecting an identity-function regression, fixed in commit c5611c3 with a Math.random-pinned deterministic test, re-review verified the hand-traced permutation independently, clean). 2 Minor findings logged, not fixed: no explicit empty-records test, no explicit count-larger-than-pool test (both trivially correct by inspection).

Task 9: complete (commit c5611c3..8f51b5b, review clean — rotation/showingFront math hand-traced correct at 0/180/360/540, click-gating and peek-vs-grade separation verified, record.id independence confirmed for Task 11 no-key reuse, CSS collision-free. 1 pre-existing unrelated test flake confirmed (vocab-bank pagination-timing tests, already documented). 2 Minor findings logged, not fixed: no explicit re-click-while-flipped-is-noop test, asymmetric JS guard between front/back handlers (relies on CSS backface-visibility, standard idiom).

Task 10: complete (commit 8f51b5b..b734ffe, review clean — setup-phase-only scope confirmed, TopicFilterPopover usage verified against real source, reactive preview count real-tested). 2 Minor findings logged, not fixed: authLoading branch omits the scr-title wrapper (matches brief verbatim), preview count reruns the Fisher-Yates shuffle every render just to read .length.

Task 11: complete (commit b734ffe..20f107c, review clean — critical no-key constraint on FlashcardCard verified with certainty, off-by-one session-completion logic traced correct at both boundaries, Math.random test pin confirmed legitimate/precedented not masking). 1 Minor logged, not fixed: randomSpy.mockRestore() not wrapped in try/finally, low practical impact given current file contents.

Task 12: complete (commit 20f107c..bfbc202, review clean — exactly-once write guard verified (ref set before async work, reset in handleStart for a second session), single shared now confirmed, no SM-2 reimplementation, per-word write failures independent/non-blocking via individual .catch). 2 Minor findings logged, not fixed: batch-write test asserts only a partial Sm2Fields via objectContaining rather than the full object, console.error is English (dev-facing log, not UI).

## All 12 tasks complete. Proceeding to final whole-branch review.

## Final whole-branch review (d0a7c6f..bfbc202, 16 commits, reviewed on Opus): Ready to merge: With fixes.

Reviewer independently verified the SM-2 port against the Dart source again at whole-branch scope, confirmed the sentence-never-saveable constraint is enforced at 3 independent layers, confirmed zero-AI-in-Ôn-tập and single-SM2-write-site hold app-wide (grepped the whole src tree), and confirmed "Ôn tập" naming is consistent everywhere. No issues with per-task work standing alone.

1 Critical, found only at whole-branch scope (no single task diff could see it): `saveVocabRecord` wrote new vocab_records documents with no `id` field in the body. Flutter's sync_service.dart caches the raw doc into Hive and does a non-nullable `json['id'] as String` cast when decoding it (both in `_buildHeadwordIndex`, called OUTSIDE startSync's try/catch, and in every VocabRecord.fromJson call site) — a single word saved from the web would crash Flutter sync and poison the entire Vocab Bank/practice/reading/listening word lists on next mobile launch, until deleted. This was a plan defect (the plan itself prescribed the id-less write), faithfully implemented and missed by the Task-2 reviewer because nothing in that task's diff alone revealed the cross-app contract. Fixed directly by the controller (commit 1299deb): `setDoc(ref, { ...record, id: ref.id })`, test tightened to assert the full written shape. Re-review independently traced the Dart-side crash path end-to-end and confirmed the fix closes it.

2 Important, both fixed directly by the controller:
- No duplicate-save guard: the AI can return a re-cased/re-lemmatized headword different from the user's raw query, so the lookup-time cache-check can miss an existing record and create a duplicate on save. Fixed (commit 4cf3072): handleSaveNewRecord re-checks getVocabRecordByHeadword immediately before writing; on a hit, sets existingRecord and skips the write. Re-review confirmed this is the correctly-scoped minimum fix (full case-insensitive matching needs a Flutter-side headwordLower schema addition, out of scope) and that the normal create path is undisturbed.
- Stale local `records` after the result screen's batch SM-2 write: "Ôn tập lại" re-selected from the pre-session snapshot, so a just-reviewed word still looked due and a repeat grade would compute SM-2 from its stale base, silently overwriting the just-written progress. Fixed (commit 7d69b1f): the write effect now merges computed Sm2Fields into `records` state alongside the Firestore write. Re-review confirmed the exactly-once write guard and effect dependencies are undisturbed, untouched records keep referential identity, and the fix resolves the reported symptom via selectSessionWords' due-filter.

Re-review of all 3 fixes (bfbc202..7d69b1f, reviewed on Opus): Ready to merge: Yes. Flagged one operational (non-blocking) follow-up: scan production users/{uid}/vocab_records for any id-less docs written during manual testing of this branch before/around merge, since the fix is write-path-only and does not remediate documents already written pre-fix. Also logged, not fixed: no regression test added for Fix 2 or Fix 3 (only Fix 1 tightened); a duplicate-hit silently discards the user's in-modal edits with no message; the "concurrent save from another tab" comment on Fix 2 overstates what a non-transactional read-then-write actually guarantees; Fix 3's local merge is optimistic (applies even if the Firestore write itself later fails, only console.error'd).

## React Web Plan 3 Phase B Part 2 (Tra từ / Lookup + Ôn tập / Practice) — COMPLETE.
All 12 tasks implemented, individually reviewed (11 clean or fixed-then-clean at task scope, 1 Critical + 2 Important found only at final whole-branch scope and fixed). 16 task/fix commits + 3 final-review fix commits = 19 commits total on top of the plan doc commit. Ready to merge per two independent final reviews.

Final verification (2026-08-17): apps/web typecheck clean, build clean (/lookup and /practice routes present), full test suite 209/211 passing (2 known-flaky pagination-timing tests, independently re-confirmed passing in isolation, unrelated to this work — same pre-existing flake documented under Phase B Part 1). All 19 commits already on master (no separate feature branch was used, matching Part 1's pattern). Not yet deployed/live-tested by the user.

## Live-testing follow-up fixes (2026-08-17, post-completion, all on master):
- Topic pre-selection in Tra từ was strict-equality-only, missing AI phrasing variants ("food and drink" vs "Food & Drink") and could push duplicate topic ids — loosened to normalized matching + dedup (commit 51a6248).
- Multi-sense meanings (e.g. "recommend": to suggest vs. to advise) had no delimiter when the AI's prompt only covered cross-part-of-speech senses, rendering as one garbled string — broadened the prompt + added splitMeaningSenses() so both Lookup and FlashcardCard render each sense on its own line (commit 55afc0f).
- Added "Khám phá từ mới" (discover a new word) to Tra từ, porting Flutter's lookup_provider.dart discover()/gemini_dictionary_source.dart discoverWord() — a sparkle button that asks the AI for a word with no query typed, fills the search box, and runs the normal cache-check-then-lookup flow (commit 3c5e244).
- Ôn tập result screen: split the single "Ôn tập lại" button into "Về Ôn tập" (back to setup) and "Ôn tập lại ngay" (calls handleStart() directly, reusing the exact filters already in state — no need to re-pick); restyled the CEFR/word-count <select>s to match the Topic filter's chip look + active-state highlight (commit d00f0bc).
- A screenshot the user shared showing a blank/unstyled Ôn tập session screen and a stale sidebar label ("Luyện tập") turned out NOT to be a code bug — curled the running localhost:3000 dev server directly and confirmed it already serves the correct "Ôn tập" label and fully-bundled Bloom CSS (.fc-card, .practice-progress-row, etc. all present in the served chunk). Diagnosed as a stale browser tab; told the user to hard-refresh. Worth remembering: this dev server auto-picks up file changes correctly, so a user-reported "still looks old" complaint should default to a browser-cache explanation before assuming a code regression, when the server itself can be curled to check.

## Live-testing follow-up round 2 (2026-08-17/18, all on master):
- Merged Khám phá's 2 AI calls into 1 (buildDiscoverPrompt now returns word+full entry together) — user flagged the extra AI-cost/latency directly (commit 303f0d3).
- Fixed .practice-select's default black browser focus outline, themed to match the rest of the app (same commit).
- Added pronunciation playback (🔊) to both Tra từ and Ngân hàng từ vựng, wiring up the getPronunciation Cloud Function (built in React Web Plan 2, never called from the web client until now) via a new apps/web/src/lib/pronunciation.ts wrapper + reusable PronunciationButton component (commit f8d85fd). Only vi/en have deployed Piper voices — button silently hides for chinese/korean/japanese records rather than offering a call that would fail.

Full round-2 fix list from this live-testing session: topic pre-selection loosened + deduped (51a6248), multi-sense meaning display + prompt broadened (55afc0f), Khám phá từ mới added then merged to 1 AI call (3c5e244, 303f0d3), Ôn tập result screen split into 2 actions + dropdown Bloom restyle + focus fix (d00f0bc, 303f0d3), pronunciation playback added to both screens (f8d85fd). All typecheck clean, full suite 235/235 passing (0 flakes this run), production build clean.

## Live-testing follow-up round 3 (2026-08-18, all on master):
- Replaced Ôn tập's native <select> CEFR/word-count dropdowns with a reusable SimpleDropdown component (same vb-chip trigger + floating panel pattern as TopicFilterPopover) — native selects couldn't be restyled past the OS-rendered open-list chrome (blue highlight, black focus ring), which the user screenshotted as clashing with the rest of the page (commit 7b0c5aa).
- Extended pronunciation playback (🔊) to VocabDrawer (the Vocab Bank detail view) — headword/IPA + each example — the third place after Tra từ and EditVocabModal (commit 7575089).

Full round-3 fix list: SimpleDropdown (7b0c5aa), VocabDrawer pronunciation (7575089). All typecheck clean, full suite 241/241 passing (0 flakes this run), production build clean.

## Live-testing follow-up round 4 (2026-08-18, all on master):
- User explicitly asked: "I want ALL dropdown spots to have the same UI as the Chủ đề select" — converted every remaining native <select> in the app (Cài đặt's target language, theme, font size, AI provider, model picker) to SimpleDropdown (commit b70504b). Only /dev/verify's GenerateContentPanel keeps a native select, left alone as an internal diagnostic page.
- Non-obvious bug hit mid-conversion: wrapping a SimpleDropdown's trigger <button> in a <label> (as the old <select>s all were) overrides the button's accessible name with the label text, since <button> is a labelable element per the HTML accname spec — every trigger's computed name became the field label ("Ngôn ngữ đang học") instead of its own visible text ("English ▾"). Fixed by using a sibling `.settings-field` div + `<span>` instead of `<label>` wrapping wherever the control became a SimpleDropdown; native `<input>`s (API key, custom model name) kept real `<label>` wrapping since they don't have this problem. Worth remembering for any future custom-button-as-form-control component: `<label>` wrapping ANY labelable element (button included, not just input/select) claims its accessible name.

All 5 Settings dropdown tests rewritten for click-open-then-click-option interaction instead of fireEvent.change. Typecheck clean, full suite 241/241 passing, production build clean.

## Live-testing follow-up round 5 (2026-08-18, all on master):
- User called out that SimpleDropdown was not actually reusing vb-topic-popover — it had its own invented vertical list-menu look (simple-dropdown-panel/opt) instead of the real wrapped-chip-grid Topic filter markup. Fixed to render its panel as literal `.vb-topic-popover` > `.vb-topic-popover-opts` > `.vb-chip` buttons, byte-identical structure to TopicFilterPopover, and deleted the dead custom CSS (commit d379c83). Lesson: when asked to make something's UI "giống hệt X" (identical to X), reuse X's actual DOM structure/classes directly rather than approximating the visual with new CSS — an approximation can drift from the real thing in ways that are obvious to the user but easy to miss in code review.

Typecheck clean, full suite 241/241 passing, production build clean.

## React Web Plan 3 Phase C Part 1 (Đọc & gõ) — execution started 2026-08-18 via subagent-driven-development. Base commit a1b97fa. Plan: docs/superpowers/plans/2026-08-18-react-web-plan3-phase-c-reading-typing.md (10 tasks).

Task 1: complete (commits a1b97fa..38d5531, review found 1 real gap — prompt never told the AI what CEFR level to target despite the setup screen already having that filter value — fixed directly by adding a 3rd maxCefr parameter, plan text updated to match before Task 8 dispatch). 1 Minor logged, not fixed: brief/test code was a verbatim transcription with no independent test-design judgment (expected for a tightly-specified port task).

Task 2: complete (commits e58185e..6d1ed24, review found 1 Important — upper finalScore clamp boundary never tested, fixed in commit 6d1ed24, re-review confirmed the new test genuinely exercises Math.min(1,...)). 1 Minor logged, not fixed: multi-sentence aggregation test only checks overallAccuracy, not the other 3 fields for the same input.

## React Web Plan 3 Phase C Part 1 (Đọc & gõ) — execution log (retroactively reconstructed 2026-08-20, see incident note below)

Task 1: complete (commits 9fa3d95..38d5531, 2026-08-18 — review found a real gap: buildReadingPassagePrompt needed an explicit maxCefr instruction, not just implied difficulty from the word list; fixed same-day). Plan doc's own Task 1 section was never updated with this fix (only Task 8's downstream reference was) — see incident below.
Task 2: complete (commits 3b81567..6d1ed24, 2026-08-18 — review found aggregateSentenceStats' upper Math.min(1,...) clamp was never exercised by any test; added one test, no source change).
Task 3: complete (commit 365c9f0, 2026-08-18 — approved clean, no fixes).

**INCIDENT (2026-08-20):** This conversation resumed today after a gap (2 real days) with "tiếp tục". No ledger entries existed yet for Tasks 1-3 (the 2026-08-18 session ended before writing them), so the resume re-dispatched Task 1 from scratch. Because the plan doc's Task 1 section still had the pre-fix 2-arg signature (see above), the fresh implementer regenerated the OLD version, regressing apps/web/src/lib/readingPassage.ts from the correct 3-arg (maxCefr) form back to 2-arg — commit f83a7b1. Caught immediately by inspecting the review-package diff (showed 7 commits instead of the expected 1) before dispatching the task reviewer. Fixed: git revert f83a7b1 (commit 5b87754, verified clean 10/10 readingPassage tests + tsc), then corrected the plan doc itself (commit 338bd43) so Task 1's own section matches what actually shipped, and retroactively marked Tasks 1-3 complete in both the plan checkboxes and this ledger. Full suite re-verified 271/271 passing after the revert, before resuming at Task 4.

**Lesson:** when a task-review finds a fix that changes a function's own signature/behavior, the fix must update THAT task's own section in the plan doc, not just downstream tasks' "Consumes" notes referencing it — otherwise a future resume (especially after a context/session gap) can regenerate the pre-fix version verbatim. Also: always write the ledger entry for a completed task in the SAME message as marking it complete, not deferred to "later" — the entire failure mode here was a session ending before that write happened.

Task 4: complete (commit 4e6dce2..6387af4, review clean — verified byte-for-byte faithful extraction, lookup/page.test.tsx confirmed untouched, behavior equivalence traced field-by-field). 1 Minor logged, not fixed: the cap-at-2 test fixture only has 2 distinct topics so doesn't truly exercise the cap-triggering branch — originates in the brief itself, not an implementer deviation.

Task 5: complete (commit 6387af4..4f61c80, review clean — byte-identical to the brief, design constraints (plain input + separate color span, no contentEditable, no future-sentence leakage, no vocab highlighting) all verified structurally). Content was already present on disk from earlier work, implementer verified+tested+committed rather than rewriting. 2 Minor findings logged, not fixed: smoke-test-only assertion for no-future-sentence-leakage, typed.split("") wont handle multi-codepoint chars correctly (non-issue for current English-only passage text).

Task 6: complete (commits 4f61c80..1f0e3d0, review found 1 Important — handleSaveAll silently swallowed a mid-batch error with zero user feedback, fixed in commit 1f0e3d0 with try/catch + surfaced alert + preserved partial-save state, re-review verified with a genuine 2-item-batch-fails-on-item-2 test). Both implementer-flagged deviations (span-wrap for RTL text matching, pre-existing unscoped .link-btn CSS gap) confirmed real/legitimate on independent check. 3 Minor findings logged, not fixed: unstyled bulk-save error paragraph (matches pre-existing pattern), reused empty-state message for zero-suggestions vs all-dismissed, no direct test for duplicate-skip on the single tap-to-save path (logic is shared/symmetric with the tested bulk path).

Task 7: complete (commit 1f0e3d0..fb2a3cf, review clean).

Task 8: complete (commit fb2a3cf..e5bfd6b, review clean — buildReadingPassagePrompt 3-arg call independently re-verified against the live readingPassage.ts, min-words gate confirmed to use an untruncated count via a deliberately separate selectSessionWords call). 2 Minor findings logged, not fixed: test suite (inherited from the brief) varies behavior only via mock data not simulated UI interaction with the dropdowns, loadError surfaces raw err.message which could be non-Vietnamese (pre-existing pattern copied from /practice).

Task 9: complete (commit e5bfd6b..576c649, review clean — deletion-tracking local-variable pattern hand-traced correct for the completing-keystroke-is-itself-a-deletion scenario, session-state reset/off-by-one boundary/partial-match-non-advancement/zero-SM2-writeback all verified). 1 Minor logged, not fixed: same-length select-all-retype registers zero deleted chars (inherent limitation of length-diffing, also present in the ported Flutter logic, out of scope).

Task 10: complete (commit 576c649..5135833, review clean — 4 stat cards, vocab-used matching, VocabSuggestionsSection props, "Sinh bài mới" reset-vs-regenerate distinction, real button vs Link for "Về trang chính", ReadingSessionResult confirmed type-only/never constructed, zero SM-2 writes all independently verified). No stub comments remain, genuinely terminal task. Test fix (getAllByText for a legitimate two-card 100% collision) confirmed a real bugfix not a weakened assertion.

## All 10 tasks of React Web Plan 3 Phase C Part 1 (Đọc & gõ) complete. Proceeding to final whole-branch review.

## Final whole-branch review (d0a7ce4..5135833, 20 commits — scoped to Đọc & gõ work from 9a56b0e onward, reviewed on Opus): Ready to merge: With fixes.

Reviewer independently re-verified the Task 1 incident is fully resolved (3-arg signature confirmed live, exactly 1 call site, no stale references anywhere), zero SM-2/streak writes confirmed by grep not claim, phase-state threading correct on both the reset-to-setup and fresh-generate paths (belt-and-braces: both handleNewPassage AND handleGenerate independently clear all 6 session fields), VocabSuggestionsSection confirmed genuinely reusable (no reading-specific coupling), and buildVocabRecordDraft confirmed identically used by both its original (Tra từ) and new (VocabSuggestionsSection) call sites. Independently re-ran typecheck (clean) and full suite (54 files / 304 passing) rather than trusting task reports.

4 Important findings:
- Plan doc had Tasks 4-10 still unchecked/undated despite being complete, with completion only recorded in the previously-uncommitted ledger — reviewer flagged this as re-arming the exact precondition that caused the Task 1 incident. Fixed directly by the controller (commit f277826): all 10 tasks now carry ALREADY IMPLEMENTED + commit SHA markers, all steps checked, ledger committed.
- `.link-btn` ("Lưu tất cả"/"Thử lại" in VocabSuggestionsSection) had no CSS rule outside EditVocabModal's scoped `.modal-field button.link-btn`, rendering as unstyled default buttons on the result screen's primary call-to-action row — inherited verbatim from the plan's own prescribed code. Reviewer explicitly recommended fixing now over deferring (cheap, high-visibility). Fixed (commit 41ebea0): added an unscoped base `.link-btn` rule, kept the modal-specific `align-self` override scoped separately so EditVocabModal's existing "+ Thêm ví dụ" button is unaffected.
- `handleSaveAll` had no in-flight guard — two overlapping invocations (e.g. a double-click during a 10-item batch) could both pass the per-item duplicate check for the same headword before either write completed, creating duplicate vocab_records. Fixed (commit 41ebea0): added `bulkSaving` state, guards entry, disables the button with "Đang lưu…" label during the operation, resets in the existing finally alongside the already-shipped error-surfacing fix from Task 6's own review.
- **Accuracy stat is architecturally pinned to 100%**: computeSentenceStats only ever runs on the exact keystroke where typed===target (by construction), so overallAccuracy is always 1 and finalScore reduces to a pure deletion-penalty score. Reviewer traced this to Flutter's reading_practice_provider.dart (identical structure) and the design spec's own §3.2 wording ("index-wise match count against the target at completion time") — a faithful port of an already-approved spec decision, not an implementer bug. **Not fixed — surfaced to the user as a design decision**, not unilaterally redesigned during a review-fix pass.

12 Minor findings logged, not fixed (representative subset): upcoming sentences never shown (spec says "upcoming dimmer", current impl only shows completed+current — may be intentional simplification, worth confirming); typing placeholder hardcoded to "tiếng Anh" regardless of target language; single-save duplicate path silently discards the user's just-made edits instead of switching to the existing record (Tra từ's equivalent does switch); bulk-save does up to 10 sequential Firestore round-trips when existingRecords is already available for a local pre-check; selectSessionWords reruns shuffle every setup-phase render just for .length; ~30 lines duplicated verbatim between practice/page.tsx and reading/bilingual/page.tsx (CEFR/word-count constants, Phase type, load effect) — recommended extracting before Part 5/6/7 copies it a 3rd time; parseVocabSuggestions hardcodes inputType:"word" even though the prompt allows phrases; records never refetched after saving suggestions (won't count toward the min-5 gate until reload); no test for a second clean session after "Sinh bài mới" (verified correct by reading, not test-locked).

**Recommendations logged for future sub-specs**: extract a shared session-setup surface (constants + dropdown options + Phase type + load effect) before Part 5/6/7/Nghe each copy it again; consider a lint/test check connecting className strings to bloom.css rules (would have caught .link-btn); move formatDuration out of the component into readingScoring.ts alongside the other pure helpers.

## React Web Plan 3 Phase C Part 1 (Đọc & gõ) — COMPLETE

All 10 tasks implemented, individually reviewed (9 clean or fixed-then-clean at task scope, all clean), 1 real incident (Task 1 stale re-dispatch) caught and fully resolved mid-execution, final whole-branch review found 3 Important issues (2 fixed, 1 surfaced as a design decision) + 12 Minor (logged). Independently re-verified: typecheck clean, full suite 305/305, production build clean (9 routes prerendered).

**4th Important finding resolved (commit 3d6e2c4):** offered the user 3 options for the always-100%-accuracy finding (keep as Flutter-parity, track peak mistakes for a real signal, or drop the card) — user chose to implement real tracking. Added `countMismatches()` to readingScoring.ts and a live-tracked `mistakeChars` peak per sentence (same caller-tracks-it-across-keystrokes pattern as the existing `deletedChars`), aggregated into a new `typingAccuracy` field. The result screen's "Độ chính xác" card now reads `typingAccuracy` instead of the always-1 `overallAccuracy`; `overallAccuracy`/`finalScore`/`deletionRatio` are untouched (finalScore's spec-defined formula still uses overallAccuracy, deliberately not touched — that wasn't part of the ask). Added a new test simulating an in-place typo-then-correction (same length, so deletedChars stays 0) verifying the card shows 67% not 100%. Re-verified independently: typecheck clean, readingScoring.test.ts + bilingual page.test.tsx 30/30, full suite 309/312 (3 failures are the same pre-existing vocab-bank pagination test timeouts under full-suite CPU contention — confirmed by passing 19/19 in isolation, unrelated to this change).

Branch considered done. Direct-to-master workflow (no feature branch/PR in this repo), so `finishing-a-development-branch`'s merge/PR menu doesn't apply — reported status directly instead, matching the pattern from the end of the prior Ôn tập plan.

## Saved Reading Exercises (Đọc & gõ pilot) — execution log

Task 1: complete (commits 1b04537..05a6b77, review clean - matching semantics topic-overlap/CEFR-at-or-below/word-count-exact-null-match/excludeId/random-among-multiple all independently re-verified as real assertions not mock theater, vocabIds confirmed never used as a matching criterion, CEFR_ORDER export confirmed to have exactly 1 new consumer with no other call site at risk). 2 Minor logged, not fixed: getRandomSavedExercise fetches the whole per-user collection and filters client-side (by design per spec, scales linearly - forward-looking note for a future composite-index pass), no try/catch in savedReadingExercises.ts (matches the existing vocabRecords.ts convention exactly, not a gap).

Task 2: complete (commit 5062a10..a2b770b, review clean/Approved — independently verified the implementer's own flagged deviation: the brief's literal Step 1 mock code (flat-object vi.mock) would have thrown at runtime since page.tsx also calls the real prioritizeUnusedWords from the same module; the vi.importActual+spread fix is correctly diagnosed and correctly applied, confirmed via the count:null->prioritize->slice ordering math and confirmed savedReadingExercises.ts has no top-level Firestore side effects making importActual safe). Corrected Task 3/4's own plan text (commit 850a10a) to show the real shipped mock pattern instead of the now-known-flawed flat-object one, applying the Task-1-incident lesson proactively before it could cause a stale re-dispatch. 1 Minor logged, not fixed: the importActual spread leaves saveReadingExercise/getRandomSavedExercise as real (Firestore-backed) implementations until Tasks 3-5 explicitly override them — already the documented plan for those tasks, just flagged for the next implementer to double check.

Task 3: complete (commit d27ec17..9c13318, review clean/Approved — fetchSavedExercise's 3-way branching (found/not-found-with-fallback/not-found-no-fallback), never-gated-by-min-words button state, vocabIds-never-a-matching-criterion, and error surfacing via generateError all independently re-verified against the diff). DONE_WITH_CONCERNS from the implementer: 1 test needed a manually-resolvable generateContent promise instead of mockResolvedValue, to fix a real (deterministic, not flaky) React-batching artifact where every mocked promise in the fetchSavedExercise->handleGenerate->generateContent chain resolved in one microtask burst, letting React flush past the intermediate "notice visible" state before screen.findByText could observe it. Reviewer independently traced the await chain and confirmed the diagnosis, confirmed the fix strengthens rather than weakens the test (now also asserts the session actually starts, not just that generateContent was called), and confirmed production page.tsx is byte-for-byte unmodified from the brief. 2 Minor logged, not fixed: no test for the getRandomSavedExercise-rejection->generateError path (out of the brief's specified 4 tests, not a compliance gap), fetchSavedExercise's "found" branch duplicates handleGenerate's session-reset boilerplate verbatim (plan-mandated, brief's own code is written this way).

Task 4: complete (commit fe6e9ff..986cffb, review clean/Approved — saveReadingExercise's 4-arg call order independently cross-checked against the real signature in savedReadingExercises.ts, "Lưu bài"/"Đã lưu" swap confirmed genuine DOM replacement not CSS hiding, VocabSuggestionsSection confirmed genuinely absent from DOM for reused sessions via queryByTestId, handleNewPassage/"Sinh bài mới" confirmed completely untouched by the diff with no drift into Task 5's territory). 2 Minor logged, not fixed: no direct test for the in-flight "saving" double-click guard itself (not in the brief's specified 3 tests), the save-error test asserts by text rather than by role="alert" so it wouldn't catch a dropped role attribute (matches the brief's own prescribed test code, not an implementer deviation).

Task 5: complete (commits 168c550..3474751..2454d2d, review found 1 Important — generateError had the exact same result-phase visibility gap the implementer had already self-caught and fixed for savedNotice, but hadn't extended the same audit to; fixed in commit 2454d2d with a 1-line mirror of the existing pattern, re-review independently traced every generateError-clearing call site to confirm the fix introduces no stale-error regression, confirmed the new test proves "visible on the result screen" not just "error state exists somewhere"). handleNewSession's 2-way branching, fetchSavedExercise reuse (not duplicated), and handleNewPassage's full removal all independently re-verified across both the original and re-review passes. DONE_WITH_CONCERNS from the implementer on Step 8 (manual Firestore-rules sanity check) — could not be performed in either implementer's environment (no browser/UI access, no firestore.rules file in-repo per this project's Console-managed rules setup) — still needs a manual check by the user or a browser-capable agent before the feature is considered fully verified end-to-end. 2 Minor logged, not fixed: "Sinh bài mới" has no disabled-while-in-flight guard or loading label unlike its setup-phase sibling buttons (a rapid double-click could fire 2 concurrent replay calls, no data corruption results since last-write-wins).

## All 5 tasks of Saved Reading Exercises (Đọc & gõ pilot) complete. Proceeding to final whole-branch review.

## Final whole-branch review (2f8bba0..2db43ed, 16 commits — spec+plan+5 tasks, reviewed on Opus): Ready to merge: With fixes.

Independently re-verified: typecheck clean, full suite 356/357 (1 pre-existing unrelated bloom.test.ts failure), production build clean (10 routes). Confirmed all 3 "already-resolved per-task" items genuinely held at the whole-feature level (vi.importActual mock pattern intact across Tasks 3-4, both savedNotice and generateError render in the result phase, records-fetched-once-on-mount reasoning verified structurally not hand-waved), confirmed the justSavedId-exclusion-never-fires limitation is still accurately true and untouched, confirmed word-priority has exactly one call site, confirmed no existing Firestore document shape changed (purely additive new collection).

4 Important findings, all with concrete reachable paths — the exact kind of cross-task integration bug a whole-branch review exists to catch (each individually correct in isolation, the interaction is what leaked):
- savedNotice never cleared after handleGenerate() succeeds -> stale "đang tạo bài mới bằng AI..." message leaks onto the finished result screen.
- saveError never cleared on session start -> a failed-save alert leaks into the NEXT session's result screen next to a fresh, never-clicked "Lưu bài" button.
- getAllUsedVocabIds awaited inside handleGenerate's main try -> a Firestore hiccup on the brand-new, not-yet-rules-verified reading_exercises collection hard-fails ALL AI generation, though word-priority is documented as a soft preference only.
- type: "bilingual" discriminant written on save but never enforced on read (matchesFilters, getAllUsedVocabIds) -> landmine for the next exercise type (Part5/6/7/Nghe) this schema is explicitly designed to grow into; a foreign-typed future document would either get handed to the Đọc & gõ typing session or crash getAllUsedVocabIds on a missing passage.vocabIds.

Fixed in one dispatched fix wave (commit 70584c5): savedNotice cleared in handleGenerate's finally (not the top, since fetchSavedExercise needs it visible during generation); saveError cleared at all 3 session-start sites (handleGenerate success, fetchSavedExercise's found branch, resetToSetup); getAllUsedVocabIds wrapped in .catch(() => new Set()) so a read failure degrades word-priority to a no-op instead of blocking generation; matchesFilters and getAllUsedVocabIds both gained a hardcoded (deliberately not parameterized) type !== "bilingual" guard. Added 1 integration test proving the saveError-leak fix specifically (generate -> save fails -> Sinh bài mới -> new session -> assert no stale alert), verified red-before/green-after.

Re-review (Opus) independently re-verified all 4 fixes at the exact required locations/ordering (savedNotice in finally not top; saveError's 3 sites enumerated with no 4th path missed; the .catch genuinely lets generation proceed with prioritizeUnusedWords degrading to a true no-op, not just relocating the error; the type guards sit ahead of the dereferences that would've thrown) and found no adverse interaction between the 4 fixes. Verdict: Ready to merge: Yes.

3 Minor findings from the re-review, not fixed: 3 of the 4 fixes (savedNotice-in-finally, getAllUsedVocabIds .catch, both type guards) have no DIRECT test coverage even though manually traced correct (only the saveError fix got a test); savedNotice can still survive handleGenerate's early-return guards (missing API key, no matching pool) since those return before the finally's setGenerating(true) — confirmed cosmetic-only, confined to the setup phase, cannot reach session/result screens; "Sinh bài mới" still has no in-flight double-click guard (already logged as an accepted Minor in Task 5's own review, unchanged).

**Open item for the human, not a code defect**: the Firestore security-rules manual sanity check (spec's own explicit ask — save via the real UI, confirm the write succeeds, confirm a subsequent "Lấy bài có sẵn" read succeeds) was never performed by any implementer or reviewer in this whole execution — no browser/UI access in any subagent's environment, and this repo has no firestore.rules file (Console-managed). The expectation that reading_exercises inherits the same per-owner rule as sibling vocab_records/topics is reasonable but genuinely unverified. This should be checked before considering the feature fully shipped end-to-end — Finding 3's fix (commit 70584c5) specifically softens the blast radius if this turns out to be wrong (a missing read rule now only breaks reuse/word-priority, not all of AI generation), but a manual check is still the right next step.

## Saved Reading Exercises (Đọc & gõ pilot, React web) — COMPLETE

All 5 tasks implemented and individually reviewed (Tasks 1/2/3/4 clean on first pass except Task 2's self-caught mock fix; Task 5 needed 1 review-driven fix), final whole-branch review found 4 Important cross-task integration bugs (all fixed in 1 dispatch, re-reviewed and confirmed correct with no new issues), several Minor findings logged throughout not fixed. 17 commits total (spec+plan+5 tasks+3 fix commits+ledger entries) on top of 2f8bba0. Independently re-verified at every stage: typecheck clean, full suite green apart from 1 known pre-existing unrelated CSS-lock failure, production build clean. Flutter port explicitly deferred to its own future spec per the original brainstorming decomposition (Option A). Manual Firestore-rules verification still needed from the user before considering this fully shipped end-to-end (see above).

## TOEIC Reading Part 5 (web, save/reuse from day one) — execution log

Task 1: complete (commits 0cfe9df..4606844, review clean/Approved — confirmed byte-for-byte match to the plan's prescribed code, the ex.type!==type guard confirmed unconditional and independent of filter-shape coincidences (satisfies "never return wrong-typed doc" for all inputs, not just the test's specific fixture), generic FiltersFor<T>/Extract<> machinery and its `as` casts confirmed sound via the compile-time+runtime dual guarantee, bilingual/page.tsx confirmed to have exactly the 2 call-site changes with no other line touched, bilingual/page.test.tsx confirmed same test count with only the 2 signature-sensitive assertions changed). 3 Minor logged, not fixed: the "never returns wrong type" test's premise slightly overstates what it proves (BilingualFilters/ToeicFilters share no fields so can't actually structurally collide, though the guard itself is still correct and unconditional), no negative-overlap test for part5 volumes (both-populated-disjoint branch), matchesBilingual/matchesToeic have slightly asymmetric parameter typing (harmless, matches brief).

Task 2: complete (commits c5a1bcd..489d089, review clean/Approved — all 8 ToeicContext values/labels and all 4 EconomyVolume values/labels verified verbatim against the brief including diacritics; VOLUME_PROMPT_HINTS independently cross-checked character-for-character against Flutter's real economy_volume.dart source, confirmed exact match not a paraphrase; correctly has no test file per the pure-data-constants convention). No findings.

Task 3: complete (commits ad25bc9..1f13f4d, review clean/Approved — prompt independently cross-checked line-by-line against Flutter's real part5_source.dart, confirmed verbatim on the 15-question/4-option/blank-marker/Vietnamese-script-explanation requirements and the empty-volumes-falls-back-to-all-hints behavior; parsePart5Set confirmed non-throwing on missing/malformed input with sane field defaults). 1 Minor logged, not fixed: cosmetic prompt wording diverges from Dart ("TOEIC difficulty levels" vs "Economy TOEIC difficulty volumes") with zero behavioral impact.

Task 4: complete (commits 88c545b..9da8dfd, review clean/Approved — session/result mode gating on correctIndex!==undefined (avoiding the falsy-0 trap) confirmed, disabled-click-does-not-fire-onSelect confirmed via a real behavioral test not just an attribute check, correct-always-highlighted/wrong-only-when-wrong confirmed mutually exclusive via the else-if construction, component confirmed fully generic with no Part5/6/7 leakage, confirmed stateless/pure). Reviewer's 1 ⚠️ item (CSS custom properties used by the new .mc-* rules actually defined, no class-name collision) independently resolved by the controller via grep: all referenced vars exist, no pre-existing .mc- classes conflict. 2 Minor logged, not fixed: aria-pressed applied even in disabled result mode (arguably wrong ARIA semantic for a disabled reveal state), className built via string concatenation rather than template literal (stylistic only).

Task 5: complete (commits d547e55..050458c, review clean/Approved — confirmed byte-for-byte match to the brief's page code, no word-count gate anywhere in the file, literal "part5" type argument used at both saveReadingExercise/getRandomSavedExercise call sites (not "bilingual"), handleNewSession's mode-replay branching correct with no dead MIN_VOCAB_WORDS fallback needed, Nộp bài submit-gating and score calculation both independently verified against test evidence, VocabSuggestionsSection gating confirmed, hub page confirmed to add exactly 1 new card/test without touching the existing Đọc & gõ one). Race-condition test-fix concern independently verified: confirmed same documented React-18-batching pattern already established in bilingual/page.test.tsx for the structurally identical notice-then-fallback scenario, confirmed the fix proves MORE not less than a naive version, confirmed production page.tsx character-for-character unmodified from the brief at that point. 2 Minor logged, not fixed: fetchSavedExercise's !handled branch is dead code inherited verbatim from the brief (user/settings already guaranteed loaded by the time it's reachable), 2 role="alert" nodes could theoretically coexist in an untested narrow edge case.

## All 5 tasks of TOEIC Reading Part 5 (web) complete. Proceeding to final whole-branch review.

## Final whole-branch review (c115136..d4ec530, 12 commits — spec+plan+5 tasks, reviewed on Opus): Ready to merge: With fixes.

Independently re-verified: typecheck clean, full suite 391/392 (1 pre-existing unrelated bloom.test.ts failure), production build clean. Confirmed all 3 "already-resolved per-task" items held at the whole-feature level (bilingual/page.tsx confirmed to have only the 2 signature-migration changes and nothing else, getRandomSavedExercise's type guard confirmed unconditional/precedes filter dispatch, part5/page.tsx confirmed byte-identical to the plan). Confirmed the sessionMode/justSavedId state machine traces correctly end-to-end against Task 1's new generic API, confirmed Part 5 has zero contact with getAllUsedVocabIds/prioritizeUnusedWords (the word-priority mechanism it has no business being part of), confirmed the empty-volumes-matches-anything rule engages correctly from UI state through to the Firestore matcher, confirmed McQuestionCard used identically at both session/result call sites with no Part5-specific leakage, confirmed Task 1's union is genuinely extensible for a future Part 6 with no further signature change needed.

3 Important findings, all real cross-task-integration/plan gaps no single task-scoped review could have caught alone:
- .mc-score (the result screen's score display) had no CSS rule anywhere in bloom.css -- rendered unstyled. Root cause: Task 4 reviewed CSS without the page, Task 5 reviewed the page without CSS -- a plan defect (the plan's own Task 4 CSS block omitted a class the plan's own Task 5 code used), faithfully implemented by both task implementers.
- No test coverage for a reused session's result screen (VocabSuggestionsSection/"Lưu bài" hidden, "Bài khác" replays fetchSavedExercise not AI) or for the save-error role="alert" path -- exactly the generate->save->reuse->result integration seam a whole-branch review exists to close.
- SavedReadingExercise's "part5" variant typed passage as unknown based on an incorrect belief that importing Part5Set into savedReadingExercises.ts would create an import cycle -- verified false (part5.ts only imports languages.ts/toeicFilters.ts, neither imports back), and the spec explicitly specified passage: Part5Set. An incorrect self-imposed constraint during Task 1's planning, not a deliberate tradeoff.

Fixed in one dispatched fix wave (commit 5624dd0): added a real .mc-score CSS rule (30px/800 weight/centered); added 3 tests for the reused-session path (VocabSuggestionsSection+Lưu bài genuine DOM absence via queryByTestId/queryByRole, "Bài khác" proven to call getRandomSavedExercise again and NOT generateContent) plus a save-error role="alert" test; imported the real Part5Set type into savedReadingExercises.ts, removed both now-unnecessary `as Part5Set` casts in part5/page.tsx, verified no import cycle by reading the actual chain (part5.ts -> languages.ts/toeicFilters.ts, neither imports back).

Re-review (Opus) independently re-verified all 3 fixes: the CSS rule is real and theme-valid (not a throwaway 1px rule); the reused-session tests genuinely await the result screen rendering before asserting absence (not vacuous) and the "Bài khác" test proves the correct branch fired by confirming generateContent was never called (which would have thrown on undefined text had the wrong branch run); the Part5Set typing is honestly satisfied by savedReadingExercises.test.ts's pre-existing FakePart5Set fixture (structurally identical, no as any escape hatch) and the no-cycle claim reconfirmed by reading part5.ts's actual imports. Confirmed the unknown->Part5Set tightening is purely compile-time with no runtime safety net lost (both before and after, a malformed stored doc throws at the identical point). Verdict: Ready to merge: Yes.

2 Minor findings from the re-review, not fixed: a stale comment in savedReadingExercises.test.ts still claims part5.ts "doesn't exist yet" (it does, and is now directly imported) -- misleading to a future reader though the fixture itself remains valid; the reused-session test fixtures use `as never` (an existing codebase convention for mocking generic functions) so they aren't compile-time-checked against the real Part5Set, meaning a future Part5Set shape change would break page.tsx but not flag these test fixtures as stale.

## TOEIC Reading Part 5 (web, save/reuse from day one) — COMPLETE

All 5 tasks implemented and individually reviewed clean on first pass (no fix cycles needed at task scope -- a first for this session's plans). Final whole-branch review found 3 Important cross-task-integration findings (all fixed in 1 dispatch, re-reviewed and confirmed correct with no new issues). 13 commits total (spec+plan+5 tasks+1 final-review-fix) on top of c115136. Independently re-verified at every stage: typecheck clean, full suite green apart from the 1 known pre-existing unrelated CSS-lock failure, production build clean. Part 6 and Part 7 remain for future plans per the original spec/scope decomposition -- Task 1's generic savedReadingExercises.ts API is confirmed to need no further signature change for them, and the process recommendation (extract a shared useSavedExerciseSession hook once a 3rd near-duplicate page appears) is logged for whoever writes Part 6's plan.

## Reading Hub / Setup Merge — execution log

Task 1: complete (commits 8a7caa1..cb82326, review clean/Approved — ToeicFilters/matchesToeic confirmed byte-for-byte match to brief and independently confirmed to mirror matchesBilingual's topic-overlap logic exactly; buildPart5Prompt's new signature and empty-topics-omits-clause behavior confirmed; ToeicContext/TOEIC_CONTEXTS/CONTEXT_LABELS confirmed deleted with zero remaining references anywhere in apps/web/src via independent grep; part5/page.tsx confirmed to use TopicFilterPopover with SimpleDropdown import fully removed; all 3 test files confirmed updated). No findings.

Task 2: complete (commits d334901..4b1bfbe, review clean/Approved — query-string encoding verified exact (topicIds/volumes/maxCefr omitted when empty/null, wordCount always present, action always set); min-5-word gate confirmed to apply only to Đọc & gõ's "Tạo bài luyện" via selectSessionWords(...).length >= MIN_VOCAB_WORDS, "Lấy bài có sẵn" unconditional for both modes, Part 5's "Tạo bài luyện" never gated; no default-selected mode confirmed; CSS addition confirmed non-colliding via grep; test file confirmed to cover all required scenarios; one disclosed justified fix to the brief's own test scaffolding, no scope deviation). No findings. A flaky unrelated vocab-bank/page.test.tsx timeout was observed once during a full-suite run and confirmed to be resource-contention flake (19/19 pass in isolation), not caused by this diff.

Task 3: complete (commits 62e262d..80ba674, review clean/Approved — all required dead imports/constants confirmed deleted via independent grep (TopicFilterPopover, SimpleDropdown/SimpleDropdownOption, CEFR_LEVELS, WORD_COUNT_OPTIONS, DEFAULT_WORD_COUNT, CEFR_DROPDOWN_OPTIONS, WORD_COUNT_DROPDOWN_OPTIONS); MIN_VOCAB_WORDS and exported ReadingSessionResult confirmed preserved; triggeredRef-guarded mount effect confirmed to redirect via router.replace on missing/invalid action and fire exactly once otherwise; both deliberate behavior changes (fetchSavedExercise's explicit generateError instead of silent no-op; handleNewSession's reused-branch no longer force-navigating) confirmed correctly wired, not just commented; Suspense confirmed wrapping the actual useSearchParams-calling component; npm run build independently re-run and confirmed /reading/bilingual is statically prerendered with no missing-Suspense-boundary error). No findings. Same flaky unrelated vocab-bank/page.test.tsx full-suite timeout observed again (19/19 in isolation) — confirmed pre-existing environmental flake, not caused by any task in this plan.

Task 4: complete (commits 48c1ad7..6f28724, review clean/Approved — implementer caught and fixed a genuine race condition in the plan's own brief code: the auto-trigger effect's literal gating (!user || !settings only) let handleGenerate() call buildPart5Prompt before the best-effort Promise.all([getVocabRecords, getTopics]) resolved, so topicIds never resolved to topic names in the AI prompt; fixed via a contextLoaded flag set in .finally() and added to the effect's guard/deps. Reviewer independently EMPIRICALLY verified the race by reverting to the brief's literal code and re-running the test suite -- 16/17 pass with the exact named test failing with the exact predicted error, then restored the fix and confirmed no diff. Confirmed no scope creep (only the contextLoaded gate touched, no Vietnamese text/CSS/param changes), confirmed .finally() correctly unblocks on fetch failure too, confirmed npm run build succeeds with /reading/part5 statically prerendered and no missing-Suspense-boundary error. 2 Minor logged, not fixed: contextLoaded gates action=existing too even though that path doesn't need resolved topic names (small unnecessary wait, not incorrect); an indefinite network stall on the best-effort fetch would leave the auto-trigger never firing for either action (same risk profile already accepted in Task 3's analogous records===null gate, not a new risk class).

## Final whole-branch review (8decfcc..d6d3aea, 10 commits — spec+plan+4 tasks, reviewed on Opus): Ready to merge: With fixes.

Independently re-verified: typecheck clean, full suite 405/406 (1 pre-existing unrelated bloom.test.ts failure), production build clean, all 3 pages statically prerendered with Suspense boundaries working correctly. Confirmed cross-task items no per-task review could see: query-param contract matches exactly in both directions for both modes (URLSearchParams percent-encoding of commas round-trips correctly); the hypothesized bilingual/part5 contextLoaded asymmetry does NOT exist as a bug (bilingual never needs resolved topic names, records!==null already implies topics populated -- Part5's gate really was the one that mattered); "always leaves visible feedback" invariant holds on all 4 fetchSavedExercise branches on both pages; Suspense pattern byte-identical on both pages, useSearchParams confirmed used nowhere else; zero remaining references anywhere to ToeicContext/TOEIC_CONTEXTS/CONTEXT_LABELS/appContext/CONTEXT_DROPDOWN_OPTIONS/resetToSetup; min-5-word bypass (1-4 words) degrades gracefully as documented.

2 Important findings, both genuine cross-task integration bugs invisible to per-task review:
- matchesToeic threw TypeError on pre-feature-shipped Part5 saved docs (old {appContext, volumes} shape, no topicIds field) -- newly reachable because Task 2 made topic-based navigation the primary flow.
- bilingual/page.tsx's handleGenerate had a silent `if (pool.length === 0) return;` with zero feedback -- newly reachable because Task 2/3 removed the setup-phase button-gating that used to prevent this path from ever firing with 0 words; a stale/hand-edited URL now hits a permanently blank loading screen.

Fixed in one dispatched fix wave (commit e5c58c9): matchesToeic guarded with `(exercise.generationFilters.topicIds ?? [])`; matchesBilingual correctly left untouched (topicIds has been a required field in every bilingual doc shape since day one, confirmed via git history, so no equivalent risk); handleGenerate's empty-pool branch now sets a Vietnamese generateError ("Không tìm thấy từ vựng nào khớp với bộ lọc đã chọn để tạo bài.") landing correctly in the existing loading-phase error UI with both Thử lại/Về trang chính buttons; Part5's page correctly left alone (no word-pool concept, no parallel bug). Added tests for both: a missing-topicIds-entirely fixture (not topicIds:[]) proving the crash is fixed, and a 0-word action=generate test asserting the exact error text plus both buttons.

Re-review (Opus) independently re-verified both fixes at the exact code paths, confirmed the test fixtures reproduce the original bugs via mutation testing (reverted fixes, confirmed 2 tests fail with the exact predicted symptoms, restored and reconfirmed green), confirmed matchesBilingual's guard-skip was correctly judged via git history not just trusted, confirmed no scope creep (4 files, +48/-2), confirmed npm run build still succeeds with all pages statically prerendered. Verdict: Ready to merge: Yes.

1 non-blocking coverage nicety noted, not fixed: no test for the empty-filter-against-missing-topicIds-doc case (provably safe by short-circuit, verified by reading the code).

## Reading Hub / Setup Merge — COMPLETE

All 4 tasks implemented and individually reviewed clean on first pass (Task 4 needed one implementer-caught, reviewer-empirically-verified fix to the plan's own brief code for a genuine mount-effect race condition; no other fix cycles needed at task scope). Final whole-branch review found 2 Important cross-task-integration findings (both fixed in 1 dispatch, re-reviewed and confirmed correct with no new issues). 12 commits total (spec+plan+4 tasks+1 final-review-fix) on top of 8decfcc. Independently re-verified at every stage: typecheck clean, full suite green apart from the 1 known pre-existing unrelated CSS-lock failure (plus one confirmed-flaky, confirmed-pre-existing vocab-bank timeout under full-suite load, unrelated to this feature), production build clean with all 3 reading pages statically prerendered. Part 6/7/Nghe are explicitly deferred to their own future spec/plan cycles, adopting this same hub pattern from the start per the spec's own "Deferred" section.

## TOEIC Reading Part 6 (web) — execution log

Task 1: complete (commits a73a13d..1c65d45, review clean/Approved — buildPart6Prompt/parsePart6Set confirmed byte-for-byte match to brief; prompt wording independently cross-checked word-for-word against Flutter's real part6_source.dart, the empty-topics-omits-register-clause deviation confirmed deliberate (mirrors part5.ts's identical pattern); parsePart6Set's question-count filter confirmed applied AFTER defaulting malformed fields, not before, via direct trace of the loop; test suite confirmed to exercise both filter-ordering cases precisely (4 malformed-but-present survives, fewer-than-4 dropped)). No findings.

Task 2: complete (commits d7fd829..abb545f, review clean/Approved — "part6" union member confirmed byte-for-byte match to brief, Part6Set confirmed imported from Task 1's real module not a duck-typed stand-in, no existing function body touched (matchesToeic/saveReadingExercise/getRandomSavedExercise/getAllUsedVocabIds/FiltersFor/PassageFor all byte-identical), union semicolon placement confirmed syntactically correct; the critical cross-type test (does not return a part5 exercise when requesting part6, despite byte-identical ToeicFilters) confirmed to be a genuine regression guard by tracing getRandomSavedExercise's ex.type!==type guard runs unconditionally before any filter dispatch; test fixtures confirmed to avoid the earlier Part5 addition's stale-comment/type-drift Minor by typing directly against the real Part6Set import). No findings.

Task 3: complete (commits 0517651..fd62354, review clean/Approved — Mode type/buildQuery/navigate/gating-condition/volume-chip-guard/new-card all confirmed byte-for-byte match to brief; navigate's 3-way ternary routing traced for all 3 modes with no misrouting; gating condition's mode!=="bilingual" simplification confirmed logically equivalent to mode==="part5"||mode==="part6" by hand-tracing all 3 mode values; existing Đọc & gõ/Part 5 cards confirmed completely untouched; no new query param introduced). No findings.

Task 4: complete (commits 0ebc4dc..4d150cf, review clean/Approved — page/test/CSS confirmed byte-for-byte match to brief; flat-index formula passageIndex*4+questionIndex confirmed consistently applied via a single flatIndex() helper at every read/write site (handleSelectAnswer, both array-sizing sites in handleGenerate and fetchSavedExercise, session-phase selected prop, result-phase selected/correctCount); contextLoaded gate confirmed correctly ported from Part 5 (set via .finally(), included in both guard and deps); parsePart6Set's outer passages.length===0 check confirmed correct given the module's own internal 4-questions-per-passage filter; "Chỗ trống (N)" labeling confirmed to reset per-passage (qi+1, not a running total) in both session and result JSX; literal "part6" confirmed at both save/fetch call sites, no part5 copy-paste; VocabSuggestionsSection text confirmed to join all 3 passages not just the first; CSS classes confirmed non-colliding via grep; npm run build independently re-run confirming /reading/part6 statically prerendered with no missing-Suspense-boundary error). No findings.

## All 4 tasks of TOEIC Reading Part 6 (web) complete. Proceeding to final whole-branch review.

## Final whole-branch review (3753233..86492a9, 9 commits — plan+4 tasks, reviewed on Opus): Ready to merge: With fixes.

Independently re-verified: typecheck clean, full suite 445/446 (1 pre-existing unrelated bloom.test.ts failure), production build clean, /reading/part6 statically prerendered. Confirmed cross-task items no per-task review could see: query-param contract round-trips correctly for both actions with/without topics/volumes (including percent-encoded commas and special characters); cross-type save/reuse correctness proven via 400 randomized draws against real Part5Set/Part6Set-shaped Firestore mocks (part6 never returns part5-shaped data or vice versa, type guard runs before any filter dispatch); "always leaves visible feedback" invariant holds across 9 traced failure scenarios; Suspense pattern has zero drift from Part5/Đọc & gõ; part5/part6 page duplication confirmed to be the spec's own deliberate stated choice, not a defect, with a note to consider extracting a shared hook at Part 7's spec stage (a third copy); hub card grid confirmed to already have a 3rd auto-fill track reserved (zero layout change to the 2 existing cards).

1 Important finding: no automated test ever exercised a multi-passage (3-passage/12-blank) Part6Set, so flatIndex's cross-passage arithmetic was completely unguarded -- every existing fixture had exactly 1 passage, which degenerates almost any indexing formula to the same result, meaning an off-by-one or wrong-multiplier bug would pass the whole suite green.

Fixed in one dispatched fix wave (commit 9a97c09, test-only, no production code changed): added THREE_PASSAGE_SET (genuine 3-passage/12-blank fixture, all 48 options unique) plus 4 new tests covering full 3-passage rendering, cross-passage independent slot mapping, submit-gating across all 12 slots (11 spread across all 3 passages, not clustered), and scoring across all 3 passages (8/12 from a deliberate correct/incorrect mix). Re-review (Opus) independently verified via actual mutation testing: temporarily broke flatIndex to passageIndex+questionIndex and to passageIndex*questionIndex, reran, confirmed the new tests fail at the exact predicted lines with the exact predicted aria-pressed symptom while all 18 pre-existing tests still passed under the broken formula (proving the gap was real), then reverted and reconfirmed 22/22 clean with an empty git diff on page.tsx. Confirmed scoring arithmetic correct by hand-checking all 12 clicks against their correctIndex. Confirmed test isolation via 3 shuffled runs all giving 22/22. Verdict: Ready to merge: Yes.

4 Minor findings logged, not fixed (consistent with prior features' precedent of accepting known small trade-offs): notice/error paragraphs can visually stack on the result screen in a rare fallback-after-fallback sequence (cosmetic only, same pattern already accepted in the hub-merge feature); part5/page.tsx and part6/page.tsx share ~170 near-identical lines with no shared hook extracted -- explicitly the spec's own stated design choice ("structurally identical to part5/page.tsx"), not a defect, flagged as a good extraction point once Part 7 makes it a third copy; QUESTIONS_PER_PASSAGE (page.tsx) duplicates BLANKS_PER_PASSAGE (part6.ts, module-private) rather than sharing one constant; a stale pre-existing untracked file test-results-before.txt sits at the repo root, unrelated to this feature. One re-review process note (not a code defect): the fix wave's own report undercounted the full suite (53/420) due to a transient Windows fork-worker flake silently dropping 7 files from that one run -- both the controller's and the re-reviewer's independent re-runs confirmed the true clean count is 60 files/450 tests.

## TOEIC Reading Part 6 (web) — COMPLETE

All 4 tasks implemented and individually reviewed clean on first pass. Final whole-branch review found 1 Important cross-task-integration finding (test coverage gap on multi-passage flat-indexing, fixed in 1 dispatch and re-verified via actual mutation testing, not just re-reading). 11 commits total (plan+4 tasks+1 final-review-fix, plus their ledger-log commits) on top of 3753233. Independently re-verified at every stage: typecheck clean, full suite green apart from the 1 known pre-existing unrelated CSS-lock failure, production build clean with /reading/part6 statically prerendered alongside /reading/bilingual and /reading/part5. Part 7 and Nghe remain for future spec/plan cycles, adopting this same hub-integrated pattern from the start per this feature's own spec's "Deferred" section -- and Part 7 is the natural point to consider extracting a shared session hook from the now-3-times-duplicated page pattern (Đọc & gõ is structurally different enough not to count as a 4th copy, but part5/page.tsx and part6/page.tsx are near-identical).

## TOEIC Reading Part 7 (web) — execution log

Task 1: complete (commits 62e686b..cdb2e53, review clean/Approved — buildPart7Prompt/parsePart7Set/hasValidPart7Shape confirmed byte-for-byte match to brief; prompt text independently cross-checked word-for-word against Flutter's real part7_source.dart; hasValidPart7Shape confirmed a line-for-line port of Flutter's _hasValidShape with boundary cases verified (accepts 3/4, rejects 2/5 for single groups, rejects non-5 for double group); parsePart7Set confirmed to never throw and do no shape filtering of its own, correctly deferring to hasValidPart7Shape; test suite confirmed to exercise real boundary cases not just happy-path). No findings. Confirmed pre-existing unrelated vocab-bank/page.test.tsx timeout via the repo's own test-results-before.txt baseline predating this task.

Task 2: complete (commits a4b4855..4804d03, review clean/Approved — "part7" union member confirmed byte-for-byte match to brief, Part7Set confirmed imported from Task 1's real module; no existing function body touched; union semicolon placement confirmed syntactically correct; the critical 3-way discrimination test (part7 vs part5 vs part6, all sharing identical ToeicFilters shape) confirmed to be a genuine regression guard by tracing getRandomSavedExercise's ex.type!==type guard runs unconditionally before any filter dispatch, independent of how many types share a filter shape). No findings.

Task 3: complete (commits 4b02283..2e59ad8, review clean/Approved — Mode type/buildQuery/navigate/volume-chip-guard/new-card all confirmed byte-for-byte match to brief; navigate's nested 4-way ternary confirmed correctly routes all 4 modes to distinct paths; volume-chip guard's mode!=="bilingual"&&mode!==null simplification confirmed to correctly preserve the null-hides-filter behavior (the && mode!==null clause was NOT forgotten); existing 3 cards confirmed untouched). No findings. Full-suite run showed transient timeouts on vocab-bank and (for the first time) one of Part6's own multi-passage tests under Windows fork-pool load -- both independently re-confirmed passing 100% in isolation (Part6: 22/22, vocab-bank: 19/19), consistent with growing suite size increasing resource contention, not a regression from this diff (which touches only reading/page.tsx and its own test file).

Task 4: complete (commits af52bc7..66bd226, review clean/Approved — page/test confirmed byte-for-byte match to brief; flatIndex's running-sum formula hand-traced against the (3,4,5) fixture confirming correct offsets (0, 3, 7) with no off-by-one/multiplier/+1 bugs, and confirmed the shipped test suite genuinely exercises cross-group indices (group0 vs group2), not just group 0 -- the exact test a broken formula would fail; totalQuestions confirmed a true sum used consistently in both array-sizing sites; hasValidPart7Shape confirmed called immediately after parsePart7Set and throwing the exact Vietnamese string matching Part5/6's own; question numbering confirmed to reset per group; double-document heading confirmed derived from documents.length===2 (data-driven, not position-assumed); literal "part7" confirmed at both save/fetch call sites; VocabSuggestionsSection text confirmed to flatten every document of every group; no new CSS added, confirmed reuse of Part6's existing classes; npm run build independently re-run confirming /reading/part7 statically prerendered with no missing-Suspense-boundary error). No findings.

## All 4 tasks of TOEIC Reading Part 7 (web) complete. Proceeding to final whole-branch review.

## Final whole-branch review (d78c3e4..c3c69e5, 9 commits — plan+4 tasks, reviewed on Opus): Ready to merge: Yes.

No Critical or Important findings. Independently re-verified: typecheck clean, full suite 498/499 (1 pre-existing unrelated bloom.test.ts failure, no worker flakes this run), production build clean, /reading/part7 statically prerendered. Confirmed cross-task items no per-task review could see: end-to-end query-param contract verified empirically for all 4 modes x both actions including no cross-mode filter leakage (bilingual's wordCount/maxCefr never leaks to part7, part5's volumes selection correctly carries to part7); three-way cross-type save/reuse (part5/part6/part7 sharing identical ToeicFilters) verified end-to-end with real getRandomSavedExercise against a mocked 3-doc Firestore response, confirming Part7Set never gets rendered from Part5Set/Part6Set-shaped data; "always leaves visible feedback" invariant confirmed to hold even for hasValidPart7Shape failing on a Bài khác-triggered regenerate (not just initial mount), not swallowed; Suspense pattern confirmed zero drift across all 4 reading pages; shape-validation design intent (parsePart7Set non-throwing, hasValidPart7Shape as the page's own separate throw-trigger) confirmed followed consistently via full-tree grep showing exactly one call site, never called on saved-exercise read-back; hub card grid confirmed to have no hardcoded card-count assumption anywhere; part5/part6/part7 duplication confirmed to be exactly the spec's own predicted, deliberate trade-off with no new urgency to extract a shared hook (would reconsider if Nghe becomes a 4th near-copy).

4 Minor findings logged, not fixed (3 are pre-existing patterns already carried by Part 5/6, not new to Part 7): the 4th hub card orphans onto its own grid row (cosmetic, no functional impact, no hardcoded assumptions broken); a malformed saved Part7 doc would surface a raw untranslated English TypeError message (caught and shown via generateError, so the "always visible feedback" invariant still holds -- same exposure Part5/6 already have); an empty passageGroups:[] on a saved doc would vacuously enable Nộp bài for a 0/0 result (unreachable given hasValidPart7Shape gates everything that gets saved, same as Part5/6's equivalent gap); hasValidPart7Shape doesn't validate per-question option counts, matching Flutter's own _hasValidShape which also doesn't check this -- a faithful port limitation, not a regression.

## TOEIC Reading Part 7 (web) — COMPLETE

All 4 tasks implemented and individually reviewed clean on first pass, no fix cycles needed at task scope. Final whole-branch review found zero Critical/Important findings -- clean "Ready to merge: Yes" with only 4 Minor observations, 3 of which are pre-existing patterns shared with Part 5/6 rather than anything Part 7 introduced. 9 commits total (plan+4 tasks+their ledger entries) on top of d78c3e4. Independently re-verified at every stage: typecheck clean, full suite green apart from the 1 known pre-existing unrelated CSS-lock failure, production build clean with all 4 reading pages (/reading/bilingual, /reading/part5, /reading/part6, /reading/part7) statically prerendered. This closes out the full TOEIC Reading Parts 5/6/7 initiative on web (Nghe/Listening remains for its own future spec/plan cycle, adopting this same hub-integrated pattern from the start).

## Nghe chép (Dictation, web) — execution log

Task 1: complete (commits 015421e..99de18e, review clean/Approved — synthesizeSpeech confirmed byte-for-byte match to brief with exact signature (request {text, language:"vi"|"en"} -> Promise<{audioBase64}>), confirmed calls Cloud Function by the exact string "synthesizeSpeech" (no typo that would silently fail at runtime); toAudioDataUrl confirmed builds exactly data:audio/wav;base64,... matching the confirmed Piper Content-Type; scope confirmed exactly 2 new files). No findings.

Task 2: complete (commits 43ab494..cc6e896, review clean/Approved — dictation.ts confirmed byte-for-byte match to brief; every claimed "exact port" independently cross-checked against the real Flutter source (dictation_source.dart, select_dictation_blanks_use_case.dart, dictation_practice_provider.dart): buildDictationPrompt word-for-word except deliberately omitted level/context clauses (matches this feature's own no-topic-filter scope decision, not a defect); selectDictationBlanks/easy/medium confirmed line-for-line identical including the 30-attempt retry cap, hand-traced to prove no infinite loop possible; normalizeForComparison confirmed to strip edge punctuation per-word (not whole-string) matching Dart's exact order; charAccuracy confirmed divides by target.length not typed.length; computeDictationScore/sm2QualityFromScore confirmed exact clamp order and all SM-2 boundary values including the deliberately-missing "1" tier). 2 Minor findings logged, not fixed: prioritizeDueWords uses <= where Flutter uses strict < for the due-time comparison (unreachable in practice, millisecond-exact tie); parseDictationItem's vocabWords.map(String) silently coerces non-strings where Dart's List<String>.from would throw (a reasonable robustness improvement, not a bug).

Task 3: complete (commits 630162d..537bc22, review clean/Approved — savedListeningExercises.ts confirmed byte-for-byte match to brief; confirmed no audio field anywhere in the saved document shape via grep; saveListeningExercise confirmed to write its own id field in the document body matching the established savedReadingExercises.ts pattern; getRandomSavedListeningExercise confirmed to filter targetLanguage via the Firestore query and difficulty via exact in-memory equality (not overlap), correctly excluding excludeId; scope confirmed exactly 2 new files). No findings.

Task 4: complete (commits d4b2cdd..37b39c0, review clean/Approved — useDictationAudio.ts confirmed byte-for-byte match to brief; all state-transition rules traced through the actual code and confirmed exact (play()'s fullClipUrlRef-gated fetch correctly handles the seek-before-play interaction so a first play after a seek still doesn't increment replayCount; seekTo() confirmed to always re-fetch fresh, never cache; the no-penalty-on-first-seek asymmetry confirmed exact); error handling confirmed to never corrupt hasPlayedOnce/replayCount/seekCount/seekPenaltyTotal state on a rejected synthesizeSpeech call; setSpeed() confirmed pure client-side with no backend call; the jsdom "no workaround needed" claim empirically verified by running the isolated test file and confirming the brief's own defensive guard correctly no-ops jsdom's unimplemented HTMLMediaElement.play()). No findings.

Task 5: complete (commits 361e3ca..ae78fda, review clean/Approved — ClozeInput/DiffText/tests/CSS confirmed byte-for-byte match to brief; ClozeResult.tsx has one deliberate 1-line deviation (adds .toLowerCase() to the hint text) that the implementer made and the reviewer independently VERIFIED was necessary, not implementer error -- reverting to the plan's literal brief code and re-running the brief's own test causes it to fail, since the fixture sentence "Apple is red" makes targetTextForBlank return "Apple" (capital A) while the brief's own test used a case-sensitive /đúng: apple/ regex; a genuine inconsistency in the plan itself, correctly caught and fixed. Word-index bookkeeping for both cloze components hand-traced correct across all test cases; DiffText confirmed no out-of-bounds access; all CSS classes confirmed matching between TSX and bloom.css with no typos; scope confirmed exactly 6 new files + 1 CSS edit). No blocking findings.

Task 6: complete (commits c12be66..ccd5b86, review clean/Approved — page.tsx confirmed byte-for-byte match to brief; language gate confirmed to check before any word-eligibility computation and render zero buttons (not disabled state); eligible-word count confirmed to filter specifically on record.targetLanguage==="english" via getVocabRecords returning all-language records client-side; "Lấy bài có sẵn" confirmed structurally identical to the established reading-hub ungated pattern; default difficulty="hard" and query-string shape confirmed to exactly match what Task 7's destination page expects). page.test.tsx has one necessary 3-line deviation from the brief: the brief's own "prompts sign-in" test never configured a useSettingsContext mock, but the component calls that hook unconditionally (before the !user check, since hooks can't be conditional) -- an unconfigured vi.fn() mock returns undefined, crashing the destructure. Implementer added a default beforeEach mock; reviewer independently verified by reverting to the brief's literal code and confirming it throws. Checked Task 7's own brief for the same gap -- not present, since its sign-in test explicitly sets both useAuthUser and useSettingsContext together, not relying on a beforeEach default. No blocking findings.

Task 7: complete (commits 35942b5..4ab4428, fix e36b351, review clean/Approved after 1 fix cycle — /listening/dictation/page.tsx confirmed byte-for-byte match to brief; word selection, wordMap/parseDictationItem correctness, blank recomputation for both generated and reused sessions, the submit gate, SM-2 update correctness, and save/reuse state hiding all confirmed on the first pass). First-pass review found 1 Critical cross-task bug invisible to any single task's own tests: `useDictationAudio(item?.target ?? "")` lives on a persistent page-component instance, so starting a second session in the same visit (e.g. "Câu khác") inherited the first session's `hasPlayedOnce`/`replayCount`/`seekCount`/`seekPenaltyTotal`/cached audio clip — silently bypassing the listen-before-submit gate, replaying the wrong sentence's audio, and corrupting the score fed into SM-2. Neither Task 4's hook tests (never re-rendered with a changed sentence) nor Task 7's own tests (never exercised a second session per render) could have caught this. Fix (e36b351): added a `useRef` tracking the previous `sentence` plus a `useEffect` keyed on `[sentence]` that resets all six state pieces and pauses in-flight audio on a genuine sentence change, explicitly skipping the reset on initial mount. Fix re-review independently verified rather than trusted: hand-traced the mount-vs-change distinction (`useRef(sentence)` seeds the ref with the first render's value, so the first effect run always sees "no change"); confirmed all six state pieces are reset, not a subset; confirmed in-flight audio is paused; confirmed the new test uses `rerender` on the same hook instance (not a fresh `renderHook`, which would trivially pass without exercising the reset path) and asserts `synthesizeSpeech` is called with the NEW sentence on the next `play()` (proving the cache was actually invalidated, not just the counters); empirically confirmed the test is load-bearing by temporarily short-circuiting the reset effect and re-running it (failed exactly as predicted), then restoring and re-confirming a clean suite; confirmed `play()`/`setSpeed()`/`seekTo()` bodies are byte-identical to the pre-fix version (purely additive fix, no rewrite); confirmed the consuming page file has zero diff in the fix commit (fix lives entirely in the hook, no `key`-prop workaround). Independently re-ran: hook tests 11/11, page tests 17/17 (unchanged, no regression), full suite 590 passed/1 pre-existing unrelated bloom.test.ts failure, tsc --noEmit clean. Verdict: Ready to merge: Yes.

## Final Whole-Branch Review

**Commits reviewed:** 872c021..f40e7c8 (17 commits — plan+7 tasks+their ledger entries), reviewed on Opus.
**Status:** Ready to merge: With fixes (1 Critical, 3 Important).

Independently re-verified: full suite 590/1 pre-existing unrelated bloom.test.ts failure, tsc --noEmit clean, production build clean with /listening and /listening/dictation both statically prerendered. Scoring-formula port audit cross-checked every formula (charAccuracy, blockAccuracy, normalizeForComparison, seekPenaltyFraction, computeDictationScore, sm2QualityFromScore, selectDictationBlanks, buildDictationPrompt) line-by-line against the real Flutter source — no simplification found. Save/reuse confirmed to never persist audio and to always recompute blanks fresh from the current difficulty. SM-2 update confirmed best-effort per-word with the same displayed/graded score. Suspense pattern confirmed structurally identical to the reading pages. All 8 error paths across both difficulty modes and both session origins traced and confirmed to leave visible feedback — no silent-freeze path found.

**Critical:** the e36b351 reset-on-sentence-change fix from Task 7 was keyed on the sentence *string*, not session identity — a reused session that re-picks the SAME saved exercise (e.g. only one match exists, so "Câu khác" on a reused session returns the identical document) never triggers the reset, since `item.target` is byte-identical. Playback state (hasPlayedOnce/replayCount/seekCount/seekPenaltyTotal/cached clip) leaks exactly as Task 7's original finding described, just for a narrower trigger the fix's own test didn't cover.

**Important (3):** (1) the seek slider called `audio.seekTo` directly from `onChange`, so a single drag across many words fired one `synthesizeSpeech` call and one seek penalty per intermediate tick — Flutter's reference only seeks on `onChangeEnd`. (2) the `targetLanguage !== "english"` gate existed only on the hub, never on `/listening/dictation` itself — reachable directly via bookmark/back-button/live Settings change in another tab. (3) local `records` state was never refreshed after an SM-2 write, so a second same-visit session via "Câu khác" could re-select an already-reviewed word and recompute `computeSm2` from a stale repetitions:0 base, silently failing to advance its schedule on the repeat review — `practice/page.tsx` already solves this exact problem and was the pattern to mirror.

**Minor (8, not fixed, logged for awareness):** TTS errors surface in raw English, not Vietnamese, contradicting spec §Error handling (the plan's own test was already internally inconsistent about this); ClozeResult lowercases the correct-answer hint, diverging from Flutter's original-casing display (a reasoned Task 5 deviation, not new); the hub has no named "🎤 Nghe chép" card per spec, just a bare picker; the seek slider is uncontrolled and doesn't reset its thumb between sessions, and Flutter's while-dragging "Từ N/M" indicator wasn't ported; `speed` is not reset by the sentence-change effect (arguably correct — preserves user preference); `blankAnswers.every(...)` is vacuously true on an empty array (unreachable in practice); no "Về trang chính" escape on the session screen if TTS keeps failing (consistent with the reading session screens); "Câu khác" has no in-flight indicator/disable (byte-identical pre-existing pattern in `reading/part5/page.tsx`, not a regression).

**Fix applied (commit ca70e98):** all 4 blocking findings fixed in one consolidated commit. (1) added a `sessionKey` argument to `useDictationAudio`, bumped by `startSession` on every call (both generated and reused paths), reset effect now fires on sentence-OR-sessionKey change. (2) seek slider's `onChange` now only updates local preview state; the actual `seekTo` call moved to `onMouseUp`/`onTouchEnd`/`onKeyUp` (covering drag, touch, and keyboard release), slider disabled while `audio.isLoading`. (3) added the same language gate to `DictationPageContent`, checked before the auto-trigger effect can invoke `handleGenerate`/`fetchSavedExercise`. (4) merged the just-written SM-2 fields into local `records` state after each successful Firestore write, mirroring `practice/page.tsx`'s established pattern exactly.

**Fix re-review (independently verified, not trusted):** all 4 fixes confirmed via revert-and-observe-failure experiments — reverting each fix in turn made its own new test fail with exactly the predicted symptom, then restored to a clean, zero-diff state. Confirmed the sessionKey bump happens on both `handleGenerate` and `fetchSavedExercise` (not just one, which would have silently reintroduced the exact reused-same-item leak this fix targets). Confirmed the seek release handlers read the live DOM value at release, not a stale closure. Confirmed the language gate blocks at the effect level (traced with instrumented logging, not just the JSX render) — `generateContent`/`synthesizeSpeech` genuinely never fire when gated. Confirmed the SM-2 merge uses the actually-written fields (not a re-derived value) and is independent per-word (one word's Firestore failure doesn't block the other's merge); verified the merged math against `sm2.ts` by hand (repetitions:0→quality 5 gives interval:1/repetitions:1; repetitions:1→quality 5 gives interval:6/repetitions:2 — matches the test's asserted values). Full suite 596 passed/1 pre-existing unrelated bloom.test.ts failure, tsc --noEmit clean. Verdict: Ready to merge: Yes.

**New Minor (from fix re-review, not fixed):** the language-gate test (`page.test.tsx`) is racy — its `screen.findByText` assertion resolves on the gate message's unconditional first synchronous render, before the async `getVocabRecords`-then-effect-refire chain would have had a chance to fire `generateContent` if the effect-level guard were absent. Production code is confirmed correct by direct trace; the test itself just doesn't provide real regression protection for the effect-level half of the fix. Suggested follow-up: add `await waitFor(() => expect(getVocabRecords).toHaveBeenCalled())` before the `not.toHaveBeenCalled()` assertion.

## Nghe chép (Dictation, web) — COMPLETE

All 7 tasks implemented and reviewed clean (1 task-level fix cycle: Task 7's audio-state-leak). Final whole-branch review found 1 Critical + 3 Important cross-task findings invisible to any single task's own review — all 4 fixed in one consolidated commit (ca70e98) and independently re-verified via revert-and-observe experiments, each confirmed to close its exact failure scenario. 19 commits total (spec+plan+7 tasks+their ledger entries+final review fix+this closeout) on top of 872c021. This closes out the Nghe chép (Dictation) initiative on web — English-only scope (forced by `synthesizeSpeech`'s `"vi"|"en"` backend constraint), save/reuse supported despite Flutter's version having none (audio is cheap to regenerate from saved text, never persisted). Nghe hiểu (Listening Comprehension) remains deferred to its own future spec/plan cycle.

---

# LexiCore — Nghe chép Audio Playback Improvements

**BASE commit (plan start):** 872c021
**Spec:** docs/superpowers/specs/2026-08-24-nghe-chep-audio-playback-improvements-design.md (commit 0f9f5d3)
**Plan file:** docs/superpowers/plans/2026-08-24-nghe-chep-audio-playback-improvements.md (commit 1f75f4c)

## Status

Task 1: complete (commit c6a2944, review clean/Approved — play()'s 3-branch restructuring traced by hand for all paths (cached-clip, in-flight-prefetch-await, fresh-fetch), confirmed prefetch never sets hasPlayedOnce in either .then()/.catch(), confirmed reset effect clears prefetchPromiseRef (not just fullClipUrlRef) preventing a stale cross-session promise leak, confirmed effect declaration order (reset-effect-then-prefetch-effect) prevents a new prefetch being clobbered by a stale reset. Implementer found and fixed 5 additional pre-existing tests beyond the brief's named 2 — a genuine unavoidable consequence of prefetch now calling synthesizeSpeech earlier, not scope creep; reviewer independently read each of the 5 fixes and confirmed none weakened its original assertion's intent. "Reuses in-flight prefetch" test confirmed non-vacuous via a manually-controlled never-resolving mock proving no duplicate call fires before the await settles). No findings.

Task 2: complete (commit 16b95e9, review clean/Approved — timeupdate listener confirmed attached exactly once (same lazy-creation guard as the <audio> element), confirmed reads sentenceRef.current (not a stale closure) so a "Câu khác" sentence swap with a different word count is picked up correctly rather than staying stuck on the old count; NaN/Infinity duration guard traced to prevent setEstimatedWordIndex from ever firing before metadata loads; clamp formula confirmed to bound output to [0, totalWords-1] including 1-word and currentTime-overshoot edge cases; all 3 required baseWordIndexRef/estimatedWordIndex call sites confirmed present (play's cached-clip branch, play's fetched branch, seekTo's success path); reset effect confirmed to zero both on session change. Reviewer empirically mutation-tested twice (hardcoded-0 clamp, disconnected-Audio-instance spy) confirming the relevant tests genuinely fail with the predicted symptom, then restored both to a clean, zero-diff state). No findings.

Task 3: complete (commit 6622419, review clean/Approved — page.tsx confirmed verbatim match to brief (isDraggingSeekRef, sync effect, all 5 slider handlers); ref-ordering confirmed isDraggingSeekRef set false as the FIRST statement in the release handlers, before seekTo fires, so no window where sync stays blocked after a seek completes. Implementer flagged a test-only race (the sync effect's flush could land after a subsequent synchronous test interaction, stomping a fresh value) fixed via an added waitFor in the test — reviewer did not accept this at face value: independently reproduced the race by removing the waitFor (failed 4/4 with the exact predicted symptom, restored and passed 4/4), then reasoned through real-browser event-loop/scheduler timing to confirm it's genuinely unreachable outside the test harness's synchronous zero-delay event dispatch (human/programmatic DOM events are separated by tens of ms at minimum; React's passive-effect flush completes in microseconds, and the effect is self-healing via continuous timeupdate events regardless). Both new tests confirmed non-vacuous by deliberately reverting the drag guard and confirming the predicted test failure. Step 2 (fixing 3 pre-existing tests) independently confirmed a genuine no-op — Task 1 had already fixed all 3 via an equivalent pattern). No findings.

Task 4: complete (commit aa08d14, review clean/Approved — SPEEDS constant confirmed fully removed with zero remaining references, replaced with named MIN_SPEED/MAX_SPEED/SPEED_STEP constants (no inlined magic numbers); old 3-button JSX confirmed fully removed not left dead; useDictationAudio.ts confirmed untouched (empty diff); onChange confirmed to call audio.setSpeed directly per-tick with no release-gating, confirmed meaningful since useDictationAudio is the real unmocked hook in these tests; new test confirmed non-vacuous (would fail if release-gating were mistakenly copied from the seek slider); aria-label confirmed Vietnamese; CSS classes confirmed non-colliding via grep, single definition/single use each. npm run build independently re-run confirming /listening/dictation still statically prerenders). No findings.

## Final Whole-Branch Review

**Commits reviewed:** c22dc4b..da18ff3 (10 commits — spec+plan+4 tasks+their ledger entries), reviewed on Opus.
**Status:** Ready to merge: With fixes (3 Important, 4 Minor).

Independently re-verified: full suite 607/1 pre-existing unrelated bloom.test.ts failure, tsc --noEmit clean, production build clean with /listening/dictation statically prerendered. Confirmed the invariant "no scoring/backend changes" held across the whole branch (diff touches exactly 6 files: 2 source, 2 test, bloom.css, docs). Confirmed prefetch never touches the <audio> element (timeupdate listener only attached inside playUrl, which prefetch never calls). Confirmed sentenceRef staleness fix from Task 2 still correct after Tasks 3/4. Confirmed no dead code (SPEEDS fully gone, old button JSX removed, no orphaned CSS). Cross-session reset audit ran on all 4 new state pieces the plan added (baseWordIndexRef, estimatedWordIndex, prefetchPromiseRef, isDraggingSeekRef) — the specific class of bug this review was asked to hunt for, given it was the Critical finding in the original Nghe chép plan.

**Important (3), all found via the cross-session audit and confirmed empirically, not speculatively:**
1. Stale `speed` value baked into `playUrl` via `useCallback`'s dep array (`[sentence, hasPlayedOnce]` excludes `speed`) — first play, every replay, and every seek silently played at 1x regardless of the slider's real value/label. Predates this branch (same defect existed in the old 3-button UI) but Task 4's entire deliverable was making speed a first-class live control, so this is exactly the gap Task 4's own reviewer couldn't see (verified setSpeed is called per-tick, not that the value survives into playback).
2. The seek slider's drag-guard (`isDraggingSeekRef`) covered mouse/touch but not keyboard — a keyboard user scrubbing with arrow keys could have the live-playhead sync effect stomp their in-progress value before release, landing on the wrong word AND charging the wrong `seekPenaltyFraction` (a genuine, if narrow, violation of the "estimatedWordIndex never feeds scoring" invariant).
3. A late-resolving prefetch from a DISCARDED session (e.g. user seeks — which doesn't force the prefetch to settle, unlike play() — then starts a new session before the old prefetch resolves) had no guard against clobbering the new session's cached clip; the reset effect only stopped the new session's play() from awaiting the stale promise, not the stale promise's own callback from writing into the shared ref afterward. Latent (unreachable via the ordinary Play path) but a genuine variant of the exact state-leak class that was the original plan's Critical finding — the design spec's own reasoning for why this needed no handling was factually wrong and has been corrected.

**Minor (4, 2 fixed alongside the Important fixes, 2 logged only):** a related stale-rejection variant of finding 3 (wasted duplicate fetch, closed by the same guard); `isDraggingSeekRef` never reset on a new session, freezing live-tracking forever if a drag gesture is abandoned without a release event (fixed); the design spec's incorrect line 33 claim (corrected); a test using persistent `mockRejectedValue` instead of `mockRejectedValueOnce` twice (cosmetic, not fixed).

**Fix applied (commit 6d0f0f3):** all 3 Important findings plus the 2 related Minors fixed in one consolidated commit. (1) added `speedRef` mirroring the existing `sentenceRef` pattern, `playUrl` now reads `speedRef.current`. (2) added `onKeyDown` to the seek slider's guard-arming handlers alongside `onMouseDown`/`onTouchStart`. (3) added a `cancelled` flag to the prefetch effect, set in its cleanup function, guarding both `.then()`/`.catch()` bodies. (Minor) `isDraggingSeekRef` reset added to `startSession`; design spec's incorrect paragraph corrected.

**Fix re-review (independently verified via revert-and-observe, not trusted):** all 3 fixes confirmed by reverting each in turn and observing its new test fail with exactly the predicted symptom, then restoring to a byte-exact clean state. Finding 1's test specifically checks the real `<audio>` element's `playbackRate` (not just the reported `speed` state, which was never wrong — this is the detail that would have missed the original bug). Finding 2's test genuinely fires a competing `timeupdate` mid-keyboard-gesture. Finding 3's two tests cover both the success and rejection stale-callback branches. Full suite 613 passed/1 pre-existing unrelated bloom.test.ts failure, tsc --noEmit clean. Verdict: Ready to merge: Yes.

## Nghe chép Audio Playback Improvements — COMPLETE

All 4 tasks implemented and reviewed clean (no task-level fix cycles needed — Tasks 1-4 all passed on first review, including two tasks where the reviewer empirically mutation-tested the implementation and a race-condition claim before approving). Final whole-branch review found 3 Important cross-task findings invisible to any single task's own review — all fixed in one consolidated commit (6d0f0f3) and independently re-verified via revert-and-observe experiments, each confirmed to close its exact failure scenario. 12 commits total (spec+plan+4 tasks+their ledger entries+final review fix+this closeout) on top of c22dc4b. This closes out the audio playback improvements initiative for Nghe chép on web: prefetch now genuinely speeds up the first Play click (not just replays), the seek slider shows a live time-proportional estimated playhead that correctly tracks mouse/touch/keyboard interaction without fighting the user, and speed control is a continuous 0.5x-2x slider with correctly-applied real-time playback.

---

# LexiCore — Nghe hiểu (Listening Comprehension) on Web

**BASE commit (plan start):** c22dc4b
**Spec:** docs/superpowers/specs/2026-08-24-nghe-hieu-listening-comprehension-design.md (commit 5cf5dad, corrected ad1b7bc)
**Plan file:** docs/superpowers/plans/2026-08-24-nghe-hieu-listening-comprehension.md (commit ad1b7bc, Task 1 corrected 473ddc7)

**Pre-flight correction (before Task 1 dispatch):** discovered while about to dispatch that services/tts-stt/voices/ does not exist in the repo — Piper model files are downloaded fresh at Docker build time via curl, never git-committed. The original Task 1 draft would have had the implementer download 3 .onnx files locally and git-add them, and would have required real voice files for its own new tests to pass (no test in this service has ever exercised real Piper synthesis before). Fixed before dispatch: Task 1 now extends the Dockerfile's existing curl block instead, and its tests mock PiperVoice entirely, matching this codebase's established boundary-mocking convention.

## Status

Task 1: complete (commit ae097c1, review clean/Approved — 4-voice registry confirmed byte-for-byte match to brief; _load_voice fallback logic confirmed exact (unsupported voice on single-voice language falls back silently, on multi-voice language raises); Dockerfile's 3 new curl pairs confirmed correctly placed and URL-exact; confirmed zero binary files/voices directory committed anywhere. Implementer found a genuinely pre-existing test file (tests/test_synthesize.py) the brief's own research had missed, with one stale assertion broken by the new 3-arg synthesize() signature — reviewer independently confirmed via git log this file predates the task, confirmed it covers different boundary/cases than the new tests (no coverage lost), and empirically reverted the fix to confirm it fails with exactly the predicted stale-arity symptom before restoring. Mock genuineness confirmed for the 4-distinct-voice-paths test — real production path-resolution code runs under the mock, a real aliasing bug would genuinely fail it). No findings.

Task 2: complete (commit 19ca383, review clean/Approved — SynthesizeSpeechRequest/VALID_VOICES/validation confirmed byte-for-byte match to brief; cloudRunClient.ts's voice threading confirmed to produce a genuinely absent JSON key when omitted (not null/"undefined"), verified via a live `JSON.stringify` check; grep confirmed no other apps/web caller of synthesizeSpeech needs updating. Implementer independently found and fixed a pre-existing test broken by the handler now always forwarding a 4th argument (even undefined) to synthesizeViaCloudRun — reviewer did not take this at face value: empirically confirmed via a throwaway vitest file that toHaveBeenCalledWith genuinely distinguishes a 3-arg call from a 4-arg call with a trailing explicit undefined, confirmed the fix adds a real non-vacuous 4th-arg expectation matching the brief's own new test pattern, and checked 2 other files with similar-shaped assertions for the same latent bug class (both confirmed unaffected, correct reasoning given for each)). No findings.

Task 3: complete (commit c98f54c, review clean/Approved — all 8 AppContext values/labels/emoji independently cross-checked value-by-value against app_context.dart, confirmed exact match; test coverage confirmed to check every one of the 8 contexts has a non-empty label AND emoji, not just object existence). No findings.

Task 4: complete (commit fdc40a4, review clean/Approved — buildListeningPassagePrompt independently line-diffed against listening_passage_source.dart's real _buildPrompt, confirmed word-for-word except the one documented gender addition; ListeningKind/ListeningTurn/ListeningQuestion confirmed matching listening_passage.dart's shape; scoreComprehension confirmed logically equivalent to Flutter's correctCount getter, correctly expressed as a ratio. speakerGenders first-seen-wins loop hand-traced with a gender-flip scenario, confirmed first value sticks. assignVoices hand-traced for all 5 cases (male-female, female-male, male-male, female-female, solo) confirmed always 2 distinct slots for same-gender pairs. Tests confirmed non-vacuous on the trickiest cases including a genuine null-vs-correctIndex-0 off-by-one-style test). No findings. Minor doc-only note carried over: brief's "Consumes" list mentions targetWords reuse that this task's code never actually needs (harmless, targetWords is genuinely used in Task 5 instead).

Task 5: complete (commits fdc40a4..983c9b4, fix 63147b3, review clean/Approved after 1 fix cycle — the most complex task in the plan (per-turn prefetch maps, auto-advance recursion with play-token supersession, two-level global word-index scheme). First-pass review found 1 Critical bug via empirical probing, not just inspection: currentTurnIndexRef was synced via a delayed useEffect instead of synchronous assignment at each mutation site (the one outlier vs. baseGlobalWordIndexRef/playTokenRef's established synchronous pattern in this same file), so two mutator calls in one React batch (e.g. nextTurn();nextTurn(); or nextTurn();play();) had the second call act on a stale pre-update turn index — reproduced with a throwaway probe showing both a stuck-at-1-instead-of-2 case and a wrong-turn-audio case. All other things the review brief asked to trace independently (N-turn cancelled-guard sharing one closure across the whole prefetch loop, speedRef read fresh through every playback path including auto-advance, 3 play-token race scenarios, global word-index math against a concrete 3/5/2-word example, the speakerFor hygiene wiring, hardcoded language:"en") confirmed correct on inspection and empirical testing. Fix (63147b3): removed the delayed effect, added synchronous currentTurnIndexRef assignments at all 6 setCurrentTurnIndex call sites, added 2 regression tests chaining calls within one act() block. Fix re-review independently confirmed all 6 sites fixed (none skipped), the delayed effect fully removed, both new tests genuinely non-vacuous (single act() block, not two), and empirically reverted the fix to confirm both tests fail with the predicted symptom — the re-reviewer's own revert additionally surfaced that the pre-fix bug was actually WORSE than first characterized: play()'s own setCurrentTurnIndex(0) call (using the stale ref) could win a state-update race against nextTurn()'s setCurrentTurnIndex(1) in the same batch, snapping the index backward, not just leaving a stale ref. Full suite 11/11 clean, tsc clean. Verdict: Ready to merge: Yes.
