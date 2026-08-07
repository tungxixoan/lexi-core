# LexiCore — TOEIC "Đọc hiểu" Part 7 Design Spec

**Date:** 2026-08-07
**Status:** Approved
**Covers:** One plan — Part 7 (Reading Comprehension), single-passage + double-passage sets only (no triple-passage), added as a 4th card on the existing `/reading` hub.

**Depends on:** the Part 5/6 plan (`2026-08-03-toeic-reading-part5-part6-design.md`) — reuses `EconomyVolume`, the "generate → answer all → submit" session pattern, `AiDisabledCard`, and `ResultSuggestionsSection` (the last two built by the dedupe follow-up plan, `2026-08-05-dedupe-result-error-widgets-design.md`).

---

## 1. Goal

Add the third and final TOEIC-style reading drill this app will ship for now: **Part 7 — Reading Comprehension**. AI generates a short practice set mixing single-passage and double-passage items (the two most common real-exam formats — triple-passage is explicitly out of scope), each followed by multiple-choice questions testing main idea, detail, inference, or vocabulary-in-context.

## 2. Scope & Non-Goals

- **In scope:** single-passage sets (one document, 3-4 questions) and double-passage sets (two related documents, 5 questions).
- **Out of scope:** triple-passage sets. Nothing in the data model should need to change to add them later, but no triple-passage code is written now.
- No Vocab Bank dependency, no minimum-word gate — same as Part 5/6, content is fully AI-generated. No SM-2 impact.
- No new mobile-tab-visibility setting — `/reading` is still reached only via the Practice hub card, unchanged since the Part 5/6 plan.

---

## 3. Session Composition

Each generated practice set (`Part7Set`) always contains exactly 3 passage groups, in this fixed order:

1. Single-passage group — 1 document, 3 or 4 questions (AI's choice within that range).
2. Single-passage group — 1 document, 3 or 4 questions.
3. Double-passage group — 2 related documents, exactly 5 questions.

Total questions per session: 11-13, depending on how many questions the AI puts in each single-passage group. This lands in the same order of magnitude as Part 5 (15) and Part 6 (12), keeping session length consistent across all three parts.

Documents are realistic TOEIC-style business correspondence: email, letter, memo, notice, advertisement, article, or a short text-message/instant-message exchange. For a double-passage group, the two documents must be genuinely related (e.g. a job ad + an application email, an announcement + a reply, an invoice + a follow-up letter) — the second document should not be answerable from the first alone; at least one question per double-passage group should require cross-referencing both documents.

Difficulty uses the existing `EconomyVolume` enum (Vol 2-5, multi-select, empty selection = all 4) — no new difficulty concept.

---

## 4. Data Model

Single-passage and double-passage groups share one shape — `documents.length` (1 or 2) is what distinguishes them, not a separate type or enum. This avoids two near-duplicate entities for what the UI ends up rendering almost identically (a document card per document, then a list of question cards).

```dart
// lib/features/reading/domain/entities/part7_passage.dart
final class Part7Question {
  final String question;
  final List<String> options;   // always 4
  final int correctIndex;       // 0-3
  final String explanation;     // Vietnamese, why the correct option is right
}

final class Part7PassageGroup {
  final List<String> documents; // 1 (single-passage) or 2 (double-passage)
  final List<Part7Question> questions; // 3-4 for a single-passage group, 5 for a double-passage group
}

final class Part7Set {
  final String id;
  final List<Part7PassageGroup> passageGroups; // always 3: [single, single, double]
  final Set<EconomyVolume> volumes;
  final AppContext context;
  final Language targetLanguage;
  final DateTime generatedAt;
}
```

### Flat answer indexing (generalizing past the Part 6 bug class)

The whole-branch review of the Part 5/6 plan found a Critical bug in `Part6Source`: it never validated that every passage actually had the 4 questions `Part6SessionState.flatIndex`'s `passageIndex * 4 + questionIndex` formula silently assumed, so a malformed AI response could crash the session screen or permanently disable submission. Part 7 cannot reuse that fixed-multiplier trick at all — single-passage groups have a *variable* question count (3 or 4) — so the flat index must be computed from each group's *actual* question count, and the source must validate the AI's response shape before accepting it, not just before it's used:

```dart
/// Flat index for the [questionIndex]-th question of [groupIndex], computed
/// from each preceding group's actual question count (not a fixed constant
/// — single-passage groups may have 3 or 4 questions).
static int flatIndex(List<Part7PassageGroup> groups, int groupIndex, int questionIndex) {
  var offset = 0;
  for (var g = 0; g < groupIndex; g++) {
    offset += groups[g].questions.length;
  }
  return offset + questionIndex;
}
```

`Part7Source` validates, before returning a `Part7Set`, that: there are exactly 3 groups; groups 0 and 1 have `documents.length == 1` and `questions.length` in `{3, 4}`; group 2 has `documents.length == 2` and `questions.length == 5`. A response that doesn't fit — e.g. a single-passage group with 2 documents, or a double-passage group with 4 questions — is rejected and the source throws `FormatException` (same failure mode as an empty response), rather than being silently accepted and corrupting the flat index space the way the Part 6 bug did.

---

## 5. Generation

- `Part7Source` (new, `lib/features/reading/data/sources/part7_source.dart`), same shape as `Part5Source`/`Part6Source`: `.withModel()` test constructor, one AI call per `generate()`, `parseAiJsonObject` for decoding, `FormatException` on empty or malformed results (per §4's validation).
- Prompt requests exactly 3 groups in the fixed single/single/double order, with the format/relatedness constraints from §3, plus a brief Vietnamese `explanation` per question and the standard "Vietnamese script only" guard (the convention every other Vietnamese-output AI prompt in this app carries since commit `3e00740` — Part 5/6's prompts were initially missing this and had to be patched in after their own final review, so Part 7 includes it from the start).
- `GeneratePart7SetUseCase` — thin wrapper, same shape as the Part 5/6 use cases.

---

## 6. Session & Result UX

**Home screen** (`Part7HomeScreen`): same shape as `Part5HomeScreen`/`Part6HomeScreen` — Ngôn ngữ / Chủ đề (AppContext) / Độ khó (EconomyVolume multi-select) filters, `AiDisabledCard` for the AI-disabled gate (no other gate — no Vocab Bank dependency), "Tạo bài luyện" button.

**Session screen** (`Part7SessionScreen`): iterates `set.passageGroups` in order. For each group: render one document card if `documents.length == 1`, or two document cards side-by-side-or-stacked if `documents.length == 2` (single scrollable column on mobile; the existing `webScaled()` text-scaling helper applies to document text, matching every other reading/session screen), then that group's question cards below (radio-button multiple choice, same as Part 5/6). One "Nộp bài" button at the bottom, enabled once every question across all 3 groups has an answer (`selectedAnswers.every((a) => a != null)` over the full flat list, sized dynamically from `passageGroups.fold(0, (sum, g) => sum + g.questions.length)` — not a hardcoded 12 or 15).

**Result screen** (`Part7ResultScreen`): score `X/N` (N computed the same dynamic way), grouped breakdown per passage group (documents shown again for review + each question's correct/incorrect coloring + explanation line), `ResultSuggestionsSection` fed the concatenation of all documents' text across all 3 groups, `statsServiceProvider.recordPracticeSession(N)`.

---

## 7. Navigation

`ReadingHubScreen` gains a 4th card, "Part 7 — Đọc hiểu", alongside the existing Đọc & gõ / Part 5 / Part 6 cards. New routes, nested under the existing `/reading` hub exactly like Part 5/6:

```
/reading/part7                    → Part7HomeScreen
/reading/part7/session            → Part7SessionScreen
/reading/part7/session/result     → Part7ResultScreen
```

---

## 8. Key Design Decisions

| Decision | Choice | Reason |
| --- | --- | --- |
| Passage scope | Single + double only, no triple | User explicitly excluded triple-passage for this plan; single+double alone covers the majority of real Part 7 (29 of 54 real-exam questions are single-passage, the rest split across double/triple) |
| Single vs. double entity shape | One shared `Part7PassageGroup` type, `documents.length` distinguishes them | Avoids two near-duplicate entities/UI branches for what renders almost identically; keeps the type usable if triple-passage is added later (just `documents.length == 3`) |
| Session composition | Fixed 2 single + 1 double per session, in that order | User-specified; keeps total question count (11-13) in the same range as Part 5 (15) and Part 6 (12) |
| Flat answer indexing | Computed dynamically from each group's actual question count, not a fixed multiplier | Direct lesson from the Part 6 final-review Critical finding — Part 7's single-passage groups have a *variable* question count, so a fixed-multiplier formula isn't even available as a (wrong) shortcut this time; the dynamic version is also the correct fix pattern already applied to Part 6 |
| AI response validation | `Part7Source` validates group count/order/document-count/question-count before returning, throws `FormatException` on mismatch | Same lesson — never let a malformed AI response reach code that assumes a specific shape |
| Vietnamese-script prompt guard | Included from the start | Part 5/6 had to patch this in after their own final review flagged it as missing; Part 7 doesn't repeat that gap |
| Reused widgets | `AiDisabledCard`, `ResultSuggestionsSection`, `EconomyVolume`, the answer-all-then-submit session pattern | All already exist and are generic (built partly *for* being reused by Part 7 — see the dedupe plan's own stated motivation) |
| Difficulty | `EconomyVolume` Vol 2-5, multi-select, empty = all 4 | Same as Part 5/6 — no new difficulty concept for Part 7 |
| SM-2 / Vocab Bank | No impact / no dependency | Same as Part 5/6 — fully AI-generated content, no specific vocab word to attribute a score to |

---

## 9. Out of Scope (this plan)

- Triple-passage sets
- Per-question immediate feedback (grading happens only at submit, matching every other TOEIC drill in this app)
- Session history / past attempts log
- SM-2 / spaced-repetition integration
