# Knowledge Notes ("Kiến thức") — Flutter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a per-language grammar/structure reference library ("Kiến thức") to the Flutter app — browse by fixed per-language groups, search, hand-write or AI-draft structured notes, with a seeded English starter library.

**Architecture:** A new `lib/features/knowledge/` feature slice following the repo's Clean-Architecture-ish layout (`domain/entities`, `domain/use_cases`, `data`, `presentation/{providers,screens,widgets}`). Notes live in `users/{uid}/knowledge_notes` and are read/written **directly via Firestore** by a plain injectable service (`KnowledgeNotesService`), mirroring `SavedExercisesService` exactly — no Hive, no `SyncService`. AI drafting reuses `AiClientFactory` → the `generateContent` Cloud Function, like every other AI source. Two shared pure utilities (a `**bold**` parser and an accent-folding tokeniser) get test-vector files that the later Web plan will reuse.

**Tech Stack:** Flutter, Riverpod (`@riverpod` codegen), go_router, cloud_firestore, `fake_cloud_firestore` (tests), `google_generative_ai` (Content type only), Bloom design system.

## Global Constraints

- **Firestore only** for `knowledge_notes` — no Hive box, no `SyncService`. Follow `lib/core/services/saved_exercises_service.dart`.
- **Region / collections:** `users/{uid}/knowledge_notes/{id}` and `users/{uid}/knowledge_meta/seed`. Covered by the existing `users/{uid}/{document=**}` rule — **no security-rules change**.
- **`targetLanguage` field stores `Language.name`** — `"english"`, `"chinese"`, `"korean"`, `"japanese"`, `"vietnamese"` — matching `reading_exercises` / `listening_exercises`.
- **`createdAt` / `updatedAt`** stored as ISO-8601 UTC strings (`DateTime.now().toUtc().toIso8601String()`), matching `SavedExercisesService`.
- **`cefrLevel`** stored lowercase (`CEFRLevel.name`: `"a1"`..`"c2"`) or `null`.
- **`id` is duplicated into the doc body** (matches `SavedExercisesService`).
- **No version history**, no offline support, no full Markdown (only `\n\n` + `**bold**`), no user-created groups, no SM-2 involvement.
- **Reference-only v1** — no "Luyện cái này" button.
- **Starter library is English only** in v1.
- After editing any `@riverpod` provider or adding an `@riverpod` function, run `dart run build_runner build --delete-conflicting-outputs`.
- Every task ends: `flutter analyze` clean + new tests green + a commit. No drop in the ~923 baseline test count.
- Vietnamese UI copy throughout (match existing screens).
- Spec: `docs/superpowers/specs/2026-09-06-knowledge-notes-design.md`.

---

## File Structure

**Create:**

| Path | Responsibility |
|---|---|
| `lib/core/utils/text_normalize.dart` | `normalizeForSearch(String)` — lowercase, strip Vietnamese diacritics, drop non-alphanumerics, collapse spaces. |
| `lib/core/utils/bold_markup.dart` | `parseBoldMarkup(String) → List<List<TextRun>>`; `TextRun({text, bold})`. Paragraph split on `\n\n+`, `**x**` → bold run, lone `**` literal. |
| `lib/core/widgets/bold_text.dart` | `BoldText(source)` — renders `parseBoldMarkup` output as `Text.rich`, one paragraph per block with spacing. |
| `lib/core/widgets/highlighted_text.dart` | `HighlightedText({text, highlights, style})` — substring-highlights `highlights` in `text` (accent-insensitive, case-insensitive). Extracted from the private copy in `reading_session_screen.dart` (that copy is left as-is). |
| `lib/features/knowledge/domain/entities/knowledge_note.dart` | `KnowledgeNote`, `KnowledgeExample`, `KnowledgeNoteSource` enum (`ai`/`manual`/`starter`), `fromJson` / `toJson`. |
| `lib/features/knowledge/domain/entities/knowledge_group.dart` | `KnowledgeGroup({id, label})`; `knowledgeGroupsFor(Language) → List<KnowledgeGroup>`; `knowledgeGroupLabel(String id) → String`. The fixed per-language taxonomy tables (spec §3). |
| `lib/features/knowledge/domain/knowledge_dedup.dart` | `findRelatedNotes({required String prompt, required List<KnowledgeNote> notes}) → List<KnowledgeNote>` — Layer-1 tokenise + score + threshold (spec §5.2). |
| `lib/features/knowledge/data/knowledge_notes_service.dart` | Firestore CRUD for `knowledge_notes` + seeding (`seedIfNeeded`, `restoreStarters`) + the `knowledge_meta/seed` flag. |
| `lib/features/knowledge/data/knowledge_starter_library.dart` | Loads & decodes `assets/knowledge/starter_en.json` into `List<KnowledgeNote>` (via `rootBundle`, injectable for tests). |
| `lib/features/knowledge/data/sources/knowledge_note_source.dart` | `KnowledgeNoteSource` — builds the AI prompt, calls the model, parses JSON → `KnowledgeNoteDraft`. |
| `lib/features/knowledge/domain/use_cases/generate_knowledge_note_use_case.dart` | Thin wrapper over `KnowledgeNoteSource` (parity with other features). |
| `lib/features/knowledge/presentation/providers/knowledge_notes_provider.dart` | `KnowledgeNotesNotifier` — `AsyncValue<List<KnowledgeNote>>` for the active language, seeds on first load, CRUD, `restoreStarters`. |
| `lib/features/knowledge/presentation/providers/knowledge_draft_provider.dart` | `KnowledgeDraftNotifier` — the "Nhờ AI soạn" flow (request → Layer 1 → AI → Layer 2 → draft). |
| `lib/features/knowledge/presentation/screens/knowledge_home_screen.dart` | Group grid + search + tag chips + FAB actions + overflow "Khôi phục ghi chú mẫu". |
| `lib/features/knowledge/presentation/screens/knowledge_group_screen.dart` | Notes in one group, sectioned by CEFR. |
| `lib/features/knowledge/presentation/screens/knowledge_detail_screen.dart` | Rendered note + edit/delete. |
| `lib/features/knowledge/presentation/screens/knowledge_edit_screen.dart` | Shared form: write / edit / review-AI-draft. |
| `lib/features/knowledge/presentation/widgets/knowledge_note_row.dart` | List row (title + summary + group/CEFR chips). |
| `lib/features/knowledge/presentation/widgets/knowledge_ai_request_sheet.dart` | The free-text request sheet + optional group/CEFR hints. |
| `lib/features/knowledge/presentation/widgets/related_notes_banner.dart` | "Bạn đã có N ghi chú liên quan" + per-card actions. |
| `assets/knowledge/starter_en.json` | The ~12 English starter notes (spec §8.5). |
| `test/fixtures/bold_markup_vectors.json` | Shared parser test vectors (Web plan reuses this file). |

**Modify:**

| Path | Change |
|---|---|
| `pubspec.yaml` | Add `- assets/knowledge/` under `flutter: assets:`. |
| `lib/core/di/app_providers.dart` | Add `@riverpod` providers: `knowledgeNotesService`, `knowledgeStarterLibrary`, `knowledgeNoteSource`, `generateKnowledgeNoteUseCase`. |
| `lib/core/router/app_router.dart` | Add `/knowledge` + `/knowledge/group/:groupId` + `/knowledge/note/:id` + `/knowledge/note/:id/edit` + `/knowledge/new` under the `ShellRoute`. |
| `lib/features/practice/presentation/screens/practice_hub_screen.dart` | Add a "Kiến thức" `BloomNavCard` after "Quét từ vựng". |
| `README.md` | Document the feature under Tính năng + add `knowledge_notes` / `knowledge_meta` to the Firestore structure block + tick a Roadmap item. |

---

## Task 1: `normalizeForSearch` text utility

**Files:**
- Create: `lib/core/utils/text_normalize.dart`
- Test: `test/core/utils/text_normalize_test.dart`

**Interfaces:**
- Produces: `String normalizeForSearch(String input)` — lowercase, strip Vietnamese diacritics (including `đ→d`), replace every char that is not `[a-z0-9]` with a space, collapse runs of whitespace, trim.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/utils/text_normalize.dart';

void main() {
  test('folds Vietnamese diacritics and đ', () {
    expect(normalizeForSearch('Câu điều kiện'), 'cau dieu kien');
    expect(normalizeForSearch('ĐIỀU'), 'dieu');
  });

  test('lowercases and strips punctuation to spaces, collapses whitespace', () {
    expect(normalizeForSearch('Present  Perfect!!  (tense)'),
        'present perfect tense');
  });

  test('empty / punctuation-only input', () {
    expect(normalizeForSearch('   '), '');
    expect(normalizeForSearch('***'), '');
  });

  test('keeps digits', () {
    expect(normalizeForSearch('loại 2 và 3'), 'loai 2 va 3');
  });
}
```

- [ ] **Step 2: Run test, verify it fails**

Run: `flutter test test/core/utils/text_normalize_test.dart`
Expected: FAIL — `text_normalize.dart` not found / `normalizeForSearch` undefined.

- [ ] **Step 3: Implement**

```dart
// lib/core/utils/text_normalize.dart

// Vietnamese diacritic folding: each accented form → its base ASCII letter.
const Map<String, String> _diacriticFolds = {
  'a': 'áàảãạăắằẳẵặâấầẩẫậ',
  'e': 'éèẻẽẹêếềểễệ',
  'i': 'íìỉĩị',
  'o': 'óòỏõọôốồổỗộơớờởỡợ',
  'u': 'úùủũụưứừửữự',
  'y': 'ýỳỷỹỵ',
  'd': 'đ',
};

String _foldChar(String lower) {
  for (final entry in _diacriticFolds.entries) {
    if (entry.value.contains(lower)) return entry.key;
  }
  return lower;
}

/// Lowercase, fold Vietnamese diacritics (and đ→d), turn every non
/// `[a-z0-9]` char into a space, collapse whitespace, trim. Shared by the
/// Knowledge search box and the duplicate-check tokeniser so "câu điều
/// kiện" and "cau dieu kien" match.
String normalizeForSearch(String input) {
  final folded = StringBuffer();
  for (final rune in input.toLowerCase().runes) {
    final ch = String.fromCharCode(rune);
    folded.write(_foldChar(ch));
  }
  return folded
      .toString()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();
}
```

- [ ] **Step 4: Run test, verify it passes**

Run: `flutter test test/core/utils/text_normalize_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/utils/text_normalize.dart test/core/utils/text_normalize_test.dart
git commit -m "feat(knowledge): normalizeForSearch accent-folding text utility"
```

---

## Task 2: `**bold**` markup parser + shared test vectors

**Files:**
- Create: `lib/core/utils/bold_markup.dart`
- Create: `test/fixtures/bold_markup_vectors.json`
- Test: `test/core/utils/bold_markup_test.dart`

**Interfaces:**
- Produces:
  - `class TextRun { final String text; final bool bold; const TextRun(this.text, {this.bold = false}); }` with `==`/`hashCode`.
  - `List<List<TextRun>> parseBoldMarkup(String source)` — outer list = paragraphs (split on `/\n\n+/`, each trimmed; empty paragraphs dropped), inner list = runs. `**x**` (x non-empty, no nested `**`, non-greedy) → `TextRun(x, bold: true)`. Unpaired `**` is literal. No other syntax.

- [ ] **Step 1: Write the shared test-vector fixture**

```json
[
  { "name": "plain", "in": "just text", "out": [[{"t": "just text", "b": false}]] },
  { "name": "two paragraphs", "in": "one\n\ntwo",
    "out": [[{"t": "one", "b": false}], [{"t": "two", "b": false}]] },
  { "name": "collapses blank runs", "in": "one\n\n\n\ntwo",
    "out": [[{"t": "one", "b": false}], [{"t": "two", "b": false}]] },
  { "name": "one bold span", "in": "a **b** c",
    "out": [[{"t": "a ", "b": false}, {"t": "b", "b": true}, {"t": " c", "b": false}]] },
  { "name": "bold at start", "in": "**x** y",
    "out": [[{"t": "x", "b": true}, {"t": " y", "b": false}]] },
  { "name": "bold at end", "in": "y **x**",
    "out": [[{"t": "y ", "b": false}, {"t": "x", "b": true}]] },
  { "name": "adjacent bold", "in": "**a****b**",
    "out": [[{"t": "a", "b": true}, {"t": "b", "b": true}]] },
  { "name": "two spans one paragraph", "in": "**a** and **b**",
    "out": [[{"t": "a", "b": true}, {"t": " and ", "b": false}, {"t": "b", "b": true}]] },
  { "name": "unpaired trailing", "in": "a **b",
    "out": [[{"t": "a **b", "b": false}]] },
  { "name": "unpaired leading", "in": "** a b",
    "out": [[{"t": "** a b", "b": false}]] },
  { "name": "empty stars literal", "in": "a **** b",
    "out": [[{"t": "a **** b", "b": false}]] },
  { "name": "single star literal", "in": "2 * 3 = 6 and _x_ #y",
    "out": [[{"t": "2 * 3 = 6 and _x_ #y", "b": false}]] },
  { "name": "trims paragraph whitespace", "in": "  hi  \n\n  bye  ",
    "out": [[{"t": "hi", "b": false}], [{"t": "bye", "b": false}]] },
  { "name": "empty string", "in": "", "out": [] }
]
```

- [ ] **Step 2: Write the failing test (drives the fixture)**

```dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/utils/bold_markup.dart';

void main() {
  final vectors = (jsonDecode(
    File('test/fixtures/bold_markup_vectors.json').readAsStringSync(),
  ) as List).cast<Map<String, dynamic>>();

  for (final v in vectors) {
    test('vector: ${v['name']}', () {
      final expected = (v['out'] as List)
          .map((para) => (para as List)
              .map((r) => TextRun(r['t'] as String, bold: r['b'] as bool))
              .toList())
          .toList();
      expect(parseBoldMarkup(v['in'] as String), expected);
    });
  }

  test('rejects nested ** inside a span (treats inner as boundary)', () {
    // "**a **b** c**" → first pair is "a " (bold), then "b" plain, then
    // " c" plain, then unpaired "**".
    expect(parseBoldMarkup('**a **b** c**'), [
      [
        const TextRun('a ', bold: true),
        const TextRun('b', bold: true),
        const TextRun(' c**'),
      ]
    ]);
  });
}
```

- [ ] **Step 3: Run test, verify it fails**

Run: `flutter test test/core/utils/bold_markup_test.dart`
Expected: FAIL — `bold_markup.dart` not found.

- [ ] **Step 4: Implement**

```dart
// lib/core/utils/bold_markup.dart

class TextRun {
  const TextRun(this.text, {this.bold = false});
  final String text;
  final bool bold;

  @override
  bool operator ==(Object other) =>
      other is TextRun && other.text == text && other.bold == bold;

  @override
  int get hashCode => Object.hash(text, bold);

  @override
  String toString() => 'TextRun(${jsonEncodeSafe(text)}, bold: $bold)';
}

// Small helper so toString() is readable in test failures without importing
// dart:convert at the call site.
String jsonEncodeSafe(String s) => '"${s.replaceAll('\n', r'\n')}"';

/// Parses the app's tiny markup: `\n\n` splits paragraphs, `**x**` marks a
/// bold run. Everything else is literal — a lone `**` renders as the two
/// characters, `*`/`_`/`#` are plain text. No nesting, italics, links.
List<List<TextRun>> parseBoldMarkup(String source) {
  final paragraphs = source
      .split(RegExp(r'\n\n+'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty);

  final result = <List<TextRun>>[];
  for (final para in paragraphs) {
    result.add(_runsForParagraph(para));
  }
  return result;
}

final _boldPattern = RegExp(r'\*\*([^*]+?)\*\*');

List<TextRun> _runsForParagraph(String para) {
  final runs = <TextRun>[];
  var cursor = 0;
  for (final m in _boldPattern.allMatches(para)) {
    if (m.start > cursor) {
      runs.add(TextRun(para.substring(cursor, m.start)));
    }
    runs.add(TextRun(m.group(1)!, bold: true));
    cursor = m.end;
  }
  if (cursor < para.length) {
    runs.add(TextRun(para.substring(cursor)));
  }
  // Merge accidental empty leading/trailing plain runs (e.g. "**x**" → the
  // leading "" before the match).
  runs.removeWhere((r) => !r.bold && r.text.isEmpty);
  return runs.isEmpty ? [const TextRun('')] : runs;
}
```

> Note on the nested-`**` vector in Step 2: `RegExp(r'\*\*([^*]+?)\*\*')` on `**a **b** c**` matches `**a **` (group `a `) then `**b**` (group `b`), leaving ` c**` literal. `[^*]+?` forbids `*` inside a span, so nesting can't happen. Confirm the test expectation matches this behaviour; if the regex engine yields a different split, adjust the vector to the actual deterministic output and document it — the rule is "defined behaviour", not a specific aesthetic.

- [ ] **Step 5: Run test, verify it passes**

Run: `flutter test test/core/utils/bold_markup_test.dart`
Expected: PASS (all vectors + nested case).

- [ ] **Step 6: Commit**

```bash
git add lib/core/utils/bold_markup.dart test/core/utils/bold_markup_test.dart test/fixtures/bold_markup_vectors.json
git commit -m "feat(knowledge): **bold** markup parser + shared test vectors"
```

---

## Task 3: `BoldText` + `HighlightedText` widgets

**Files:**
- Create: `lib/core/widgets/bold_text.dart`
- Create: `lib/core/widgets/highlighted_text.dart`
- Test: `test/core/widgets/bold_text_test.dart`
- Test: `test/core/widgets/highlighted_text_test.dart`

**Interfaces:**
- Consumes: `parseBoldMarkup`, `TextRun` (Task 2); `normalizeForSearch` (Task 1).
- Produces:
  - `BoldText({required String source, TextStyle? style})` — a `Column` of `Text.rich`, one per paragraph, `SizedBox(height: 8)` between.
  - `HighlightedText({required String text, required List<String> highlights, TextStyle? style, TextStyle? highlightStyle})` — `RichText` with matched substrings in `highlightStyle` (defaults to `style` + `fontWeight: w700` + `context.bloom.accent` colour). Matching is case- and accent-insensitive on `normalizeForSearch`-folded strings but slices the **original** `text` so display keeps diacritics.

- [ ] **Step 1: Write failing tests**

```dart
// test/core/widgets/bold_text_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/widgets/bold_text.dart';

void main() {
  testWidgets('renders one Text.rich per paragraph', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: BoldText(source: 'para **one**\n\npara two')),
    ));
    expect(find.byType(RichText), findsNWidgets(2));
  });

  testWidgets('bold run gets FontWeight.bold', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: BoldText(source: 'a **b** c')),
    ));
    final rich = tester.widget<RichText>(find.byType(RichText).first);
    final root = rich.text as TextSpan;
    final boldSpan = (root.children!).firstWhere(
      (s) => (s as TextSpan).text == 'b',
    ) as TextSpan;
    expect(boldSpan.style!.fontWeight, FontWeight.bold);
  });
}
```

```dart
// test/core/widgets/highlighted_text_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/app_theme.dart';
import 'package:lexi_core/core/widgets/highlighted_text.dart';

void main() {
  testWidgets('no highlights → plain Text', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(
        body: HighlightedText(text: 'hello world', highlights: []),
      ),
    ));
    expect(find.text('hello world'), findsOneWidget);
  });

  testWidgets('accent-insensitive match splits into spans', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(
        body: HighlightedText(
          text: 'Tôi thích điều kiện', highlights: ['dieu kien'],
        ),
      ),
    ));
    final rich = tester.widget<RichText>(find.byType(RichText));
    final root = rich.text as TextSpan;
    final matched = (root.children!).map((s) => (s as TextSpan).text).toList();
    expect(matched, ['Tôi thích ', 'điều kiện']);
  });
}
```

- [ ] **Step 2: Run tests, verify they fail**

Run: `flutter test test/core/widgets/bold_text_test.dart test/core/widgets/highlighted_text_test.dart`
Expected: FAIL — widgets not found.

- [ ] **Step 3: Implement `bold_text.dart`**

```dart
// lib/core/widgets/bold_text.dart
import 'package:flutter/material.dart';
import '../utils/bold_markup.dart';

/// Renders the app's tiny `\n\n` + `**bold**` markup (see [parseBoldMarkup]).
class BoldText extends StatelessWidget {
  const BoldText({super.key, required this.source, this.style});

  final String source;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    final paragraphs = parseBoldMarkup(source);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < paragraphs.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              children: [
                for (final run in paragraphs[i])
                  TextSpan(
                    text: run.text,
                    style: run.bold
                        ? base.copyWith(fontWeight: FontWeight.bold)
                        : base,
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
```

- [ ] **Step 4: Implement `highlighted_text.dart`**

```dart
// lib/core/widgets/highlighted_text.dart
import 'package:flutter/material.dart';
import '../theme/bloom/bloom.dart';
import '../utils/text_normalize.dart';

/// Highlights each of [highlights] wherever it appears in [text], matching
/// case- and accent-insensitively (via [normalizeForSearch]) but slicing the
/// original [text] so the display keeps its diacritics.
class HighlightedText extends StatelessWidget {
  const HighlightedText({
    super.key,
    required this.text,
    required this.highlights,
    this.style,
    this.highlightStyle,
  });

  final String text;
  final List<String> highlights;
  final TextStyle? style;
  final TextStyle? highlightStyle;

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    final hi = highlightStyle ??
        base.copyWith(
          fontWeight: FontWeight.w700,
          color: context.bloom.accent,
        );

    final terms = highlights
        .map(normalizeForSearch)
        .where((t) => t.isNotEmpty)
        .toList();
    if (terms.isEmpty) return Text(text, style: base);

    // Fold the text the same way, keeping a char-index map back to the
    // original. normalizeForSearch can change length (diacritic → 1 char,
    // punctuation → space), so build the folded string char-by-char.
    final folded = StringBuffer();
    final map = <int>[]; // folded index -> original index
    for (var i = 0; i < text.length; i++) {
      final f = normalizeForSearch(text[i]);
      for (var k = 0; k < f.length; k++) {
        folded.write(f[k]);
        map.add(i);
      }
    }
    final foldedStr = folded.toString();

    final spans = <TextSpan>[];
    var origCursor = 0;
    var foldedCursor = 0;
    while (foldedCursor < foldedStr.length) {
      int? bestStart;
      int? bestEnd;
      for (final term in terms) {
        final idx = foldedStr.indexOf(term, foldedCursor);
        if (idx >= 0 && (bestStart == null || idx < bestStart)) {
          bestStart = idx;
          bestEnd = idx + term.length;
        }
      }
      if (bestStart == null || bestEnd == null) break;
      final origStart = map[bestStart];
      final origEnd = bestEnd < map.length ? map[bestEnd] : text.length;
      if (origStart > origCursor) {
        spans.add(TextSpan(text: text.substring(origCursor, origStart), style: base));
      }
      spans.add(TextSpan(text: text.substring(origStart, origEnd), style: hi));
      origCursor = origEnd;
      foldedCursor = bestEnd;
    }
    if (origCursor < text.length) {
      spans.add(TextSpan(text: text.substring(origCursor), style: base));
    }
    return RichText(text: TextSpan(children: spans));
  }
}
```

- [ ] **Step 5: Run tests, verify they pass**

Run: `flutter test test/core/widgets/bold_text_test.dart test/core/widgets/highlighted_text_test.dart`
Expected: PASS. If the folded-index mapping test is off by one on the trailing space, adjust `origEnd` handling and update the test to the real deterministic output.

- [ ] **Step 6: `flutter analyze` + commit**

```bash
flutter analyze
git add lib/core/widgets/bold_text.dart lib/core/widgets/highlighted_text.dart test/core/widgets/bold_text_test.dart test/core/widgets/highlighted_text_test.dart
git commit -m "feat(knowledge): BoldText + HighlightedText render widgets"
```

---

## Task 4: `KnowledgeNote` entity + `KnowledgeGroup` taxonomy

**Files:**
- Create: `lib/features/knowledge/domain/entities/knowledge_note.dart`
- Create: `lib/features/knowledge/domain/entities/knowledge_group.dart`
- Test: `test/features/knowledge/domain/entities/knowledge_note_test.dart`
- Test: `test/features/knowledge/domain/entities/knowledge_group_test.dart`

**Interfaces:**
- Consumes: `Language` (`lib/features/dictionary/domain/entities/language.dart`), `CEFRLevel` (`lib/features/vocabulary/domain/entities/cefr_level.dart`).
- Produces:
  - `enum KnowledgeNoteOrigin { ai, manual, starter }` with `.name` round-tripping the `source` field.
  - `class KnowledgeExample { final String text; final String translation; ... fromJson/toJson; ==/hashCode }`.
  - `class KnowledgeNote` — fields per spec §2: `id, title, summary, explanation, patterns (List<String>), examples (List<KnowledgeExample>), pitfalls (List<String>), groupId, tags (List<String>), cefrLevel (CEFRLevel?), targetLanguage (Language), origin (KnowledgeNoteOrigin), sourcePrompt (String?), createdAt (DateTime), updatedAt (DateTime)`. `KnowledgeNote.fromJson(Map<String,dynamic>)` (defensive: missing lists → `[]`, bad enum → fallback), `toJson()` (writes `source`, `targetLanguage` as `Language.name`, `cefrLevel` as `CEFRLevel?.name`, dates as `toUtc().toIso8601String()`, `id` in body). `copyWith(...)`.
  - `class KnowledgeGroup { final String id; final String label; const ... }`.
  - `List<KnowledgeGroup> knowledgeGroupsFor(Language language)` — the spec §3 tables.
  - `String knowledgeGroupLabel(String groupId)` — reverse lookup across all languages; returns the id itself if unknown.
  - `String knowledgeOtherGroupId(Language language)` — the `*_other` id for that language.

- [ ] **Step 1: Write failing tests**

```dart
// test/features/knowledge/domain/entities/knowledge_note_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/knowledge/domain/entities/knowledge_note.dart';

void main() {
  final json = {
    'id': 'n1',
    'title': 'Câu điều kiện loại 2',
    'summary': 'Giả định không có thật ở hiện tại.',
    'explanation': 'Dùng **were** cho mọi ngôi.',
    'patterns': ['If + S + V-past, S + would + V'],
    'examples': [
      {'text': 'If I were you...', 'translation': 'Nếu tôi là bạn...'}
    ],
    'pitfalls': ['Không dùng "was" trong văn trang trọng.'],
    'groupId': 'en_conditionals',
    'tags': ['ngu-phap'],
    'cefrLevel': 'b1',
    'targetLanguage': 'english',
    'source': 'ai',
    'sourcePrompt': 'giải thích loại 2',
    'createdAt': '2026-09-07T00:00:00.000Z',
    'updatedAt': '2026-09-07T00:00:00.000Z',
  };

  test('fromJson / toJson round-trip', () {
    final note = KnowledgeNote.fromJson(json);
    expect(note.targetLanguage, Language.english);
    expect(note.cefrLevel, CEFRLevel.b1);
    expect(note.origin, KnowledgeNoteOrigin.ai);
    expect(note.examples.single.translation, 'Nếu tôi là bạn...');
    expect(note.toJson(), json);
  });

  test('fromJson defends against missing lists and unknown enums', () {
    final note = KnowledgeNote.fromJson({
      'id': 'n2',
      'title': 't',
      'summary': 's',
      'explanation': 'e',
      'groupId': 'en_other',
      'targetLanguage': 'english',
      'source': 'weird',
      'cefrLevel': null,
      'createdAt': '2026-09-07T00:00:00.000Z',
      'updatedAt': '2026-09-07T00:00:00.000Z',
    });
    expect(note.patterns, isEmpty);
    expect(note.examples, isEmpty);
    expect(note.pitfalls, isEmpty);
    expect(note.tags, isEmpty);
    expect(note.cefrLevel, isNull);
    expect(note.origin, KnowledgeNoteOrigin.manual); // fallback
  });
}
```

```dart
// test/features/knowledge/domain/entities/knowledge_group_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/knowledge/domain/entities/knowledge_group.dart';

void main() {
  test('English taxonomy has the spec groups, ending with Khác', () {
    final ids = knowledgeGroupsFor(Language.english).map((g) => g.id).toList();
    expect(ids.first, 'en_tenses');
    expect(ids.last, 'en_other');
    expect(ids, contains('en_conditionals'));
    expect(ids.length, 12);
  });

  test('every language ends with an _other group', () {
    for (final lang in Language.values) {
      final ids = knowledgeGroupsFor(lang).map((g) => g.id).toList();
      expect(ids, isNotEmpty, reason: lang.name);
      expect(ids.last, knowledgeOtherGroupId(lang), reason: lang.name);
    }
  });

  test('label lookup resolves a known id and passes through an unknown one', () {
    expect(knowledgeGroupLabel('en_tenses'), 'Thì');
    expect(knowledgeGroupLabel('nope_nope'), 'nope_nope');
  });
}
```

- [ ] **Step 2: Run tests, verify they fail**

Run: `flutter test test/features/knowledge/domain/entities/`
Expected: FAIL — entities not found.

- [ ] **Step 3: Implement `knowledge_group.dart`**

Use the spec §3 tables verbatim. Structure:

```dart
// lib/features/knowledge/domain/entities/knowledge_group.dart
import '../../../dictionary/domain/entities/language.dart';

class KnowledgeGroup {
  const KnowledgeGroup(this.id, this.label);
  final String id;
  final String label;
}

const _en = <KnowledgeGroup>[
  KnowledgeGroup('en_tenses', 'Thì'),
  KnowledgeGroup('en_conditionals', 'Câu điều kiện'),
  KnowledgeGroup('en_relative_clauses', 'Mệnh đề quan hệ'),
  KnowledgeGroup('en_passive', 'Câu bị động'),
  KnowledgeGroup('en_reported_speech', 'Câu tường thuật'),
  KnowledgeGroup('en_modals', 'Động từ khuyết thiếu'),
  KnowledgeGroup('en_gerunds_infinitives', 'Danh động từ & Nguyên mẫu'),
  KnowledgeGroup('en_articles_nouns', 'Mạo từ & Danh từ'),
  KnowledgeGroup('en_prepositions', 'Giới từ'),
  KnowledgeGroup('en_conjunctions_linking', 'Liên từ & Nối câu'),
  KnowledgeGroup('en_spoken_structures', 'Cấu trúc nói thông dụng'),
  KnowledgeGroup('en_other', 'Khác'),
];

const _zh = <KnowledgeGroup>[
  KnowledgeGroup('zh_aspect_particles', 'Thể & Trợ từ động thái (了/着/过)'),
  KnowledgeGroup('zh_complements', 'Bổ ngữ (kết quả/xu hướng/khả năng/mức độ)'),
  KnowledgeGroup('zh_ba', 'Câu chữ 把'),
  KnowledgeGroup('zh_bei', 'Câu chữ 被 (bị động)'),
  KnowledgeGroup('zh_measure_words', 'Lượng từ'),
  KnowledgeGroup('zh_modal_particles', 'Trợ từ ngữ khí (吗/呢/吧/啊)'),
  KnowledgeGroup('zh_comparison', 'Cấu trúc so sánh (比/没有/一样)'),
  KnowledgeGroup('zh_conjunctions', 'Liên từ & Phức câu'),
  KnowledgeGroup('zh_word_order', 'Trật tự từ & Trạng ngữ'),
  KnowledgeGroup('zh_spoken_structures', 'Cấu trúc nói thông dụng'),
  KnowledgeGroup('zh_other', 'Khác'),
];

const _ko = <KnowledgeGroup>[
  KnowledgeGroup('ko_particles', 'Trợ từ (조사)'),
  KnowledgeGroup('ko_endings_honorifics', 'Đuôi câu & Kính ngữ (존댓말/반말)'),
  KnowledgeGroup('ko_tense_aspect', 'Thì & Thể'),
  KnowledgeGroup('ko_clause_connectors', 'Liên kết vế câu (연결어미)'),
  KnowledgeGroup('ko_modifiers', 'Định ngữ (관형사형)'),
  KnowledgeGroup('ko_grammar_patterns', 'Mẫu ngữ pháp thông dụng'),
  KnowledgeGroup('ko_irregulars', 'Bất quy tắc (불규칙 활용)'),
  KnowledgeGroup('ko_spoken_structures', 'Cấu trúc nói thông dụng'),
  KnowledgeGroup('ko_other', 'Khác'),
];

const _ja = <KnowledgeGroup>[
  KnowledgeGroup('ja_particles', 'Trợ từ (助詞)'),
  KnowledgeGroup('ja_verb_forms', 'Chia động từ (辞書形/て形/た形…)'),
  KnowledgeGroup('ja_politeness_keigo', 'Thể lịch sự & Kính ngữ (敬語)'),
  KnowledgeGroup('ja_tense_aspect', 'Thì & Thể'),
  KnowledgeGroup('ja_connectors', 'Liên kết câu (接続)'),
  KnowledgeGroup('ja_grammar_patterns', 'Mẫu ngữ pháp (文型)'),
  KnowledgeGroup('ja_voice', 'Khả năng / Bị động / Sai khiến'),
  KnowledgeGroup('ja_spoken_structures', 'Cấu trúc nói thông dụng'),
  KnowledgeGroup('ja_other', 'Khác'),
];

const _vi = <KnowledgeGroup>[
  KnowledgeGroup('vi_sentence_structure', 'Cấu trúc câu'),
  KnowledgeGroup('vi_word_classes', 'Từ loại & chức năng'),
  KnowledgeGroup('vi_linking', 'Liên kết câu'),
  KnowledgeGroup('vi_spoken_structures', 'Cấu trúc nói thông dụng'),
  KnowledgeGroup('vi_other', 'Khác'),
];

List<KnowledgeGroup> knowledgeGroupsFor(Language language) => switch (language) {
      Language.english => _en,
      Language.chinese => _zh,
      Language.korean => _ko,
      Language.japanese => _ja,
      Language.vietnamese => _vi,
    };

final Map<String, String> _labelById = {
  for (final g in [..._en, ..._zh, ..._ko, ..._ja, ..._vi]) g.id: g.label,
};

String knowledgeGroupLabel(String groupId) => _labelById[groupId] ?? groupId;

String knowledgeOtherGroupId(Language language) =>
    knowledgeGroupsFor(language).last.id;
```

- [ ] **Step 4: Implement `knowledge_note.dart`**

```dart
// lib/features/knowledge/domain/entities/knowledge_note.dart
import '../../../dictionary/domain/entities/language.dart';
import '../../../vocabulary/domain/entities/cefr_level.dart';

enum KnowledgeNoteOrigin { ai, manual, starter }

KnowledgeNoteOrigin _originFrom(Object? raw) =>
    KnowledgeNoteOrigin.values.asNameMap()[raw] ?? KnowledgeNoteOrigin.manual;

class KnowledgeExample {
  const KnowledgeExample({required this.text, required this.translation});
  final String text;
  final String translation;

  factory KnowledgeExample.fromJson(Map<String, dynamic> j) => KnowledgeExample(
        text: j['text'] as String? ?? '',
        translation: j['translation'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {'text': text, 'translation': translation};

  @override
  bool operator ==(Object o) =>
      o is KnowledgeExample && o.text == text && o.translation == translation;
  @override
  int get hashCode => Object.hash(text, translation);
}

class KnowledgeNote {
  const KnowledgeNote({
    required this.id,
    required this.title,
    required this.summary,
    required this.explanation,
    this.patterns = const [],
    this.examples = const [],
    this.pitfalls = const [],
    required this.groupId,
    this.tags = const [],
    this.cefrLevel,
    required this.targetLanguage,
    required this.origin,
    this.sourcePrompt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String summary;
  final String explanation;
  final List<String> patterns;
  final List<KnowledgeExample> examples;
  final List<String> pitfalls;
  final String groupId;
  final List<String> tags;
  final CEFRLevel? cefrLevel;
  final Language targetLanguage;
  final KnowledgeNoteOrigin origin;
  final String? sourcePrompt;
  final DateTime createdAt;
  final DateTime updatedAt;

  static List<String> _stringList(Object? raw) =>
      raw is List ? raw.whereType<String>().toList() : const [];

  factory KnowledgeNote.fromJson(Map<String, dynamic> j) => KnowledgeNote(
        id: j['id'] as String? ?? '',
        title: j['title'] as String? ?? '',
        summary: j['summary'] as String? ?? '',
        explanation: j['explanation'] as String? ?? '',
        patterns: _stringList(j['patterns']),
        examples: (j['examples'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(KnowledgeExample.fromJson)
            .toList(),
        pitfalls: _stringList(j['pitfalls']),
        groupId: j['groupId'] as String? ?? '',
        tags: _stringList(j['tags']),
        cefrLevel:
            CEFRLevel.values.asNameMap()[(j['cefrLevel'] as String?) ?? ''],
        targetLanguage: Language.values.asNameMap()[j['targetLanguage']] ??
            Language.english,
        origin: _originFrom(j['source']),
        sourcePrompt: j['sourcePrompt'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
        updatedAt: DateTime.parse(j['updatedAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'summary': summary,
        'explanation': explanation,
        'patterns': patterns,
        'examples': examples.map((e) => e.toJson()).toList(),
        'pitfalls': pitfalls,
        'groupId': groupId,
        'tags': tags,
        'cefrLevel': cefrLevel?.name,
        'targetLanguage': targetLanguage.name,
        'source': origin.name,
        'sourcePrompt': sourcePrompt,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  KnowledgeNote copyWith({
    String? title,
    String? summary,
    String? explanation,
    List<String>? patterns,
    List<KnowledgeExample>? examples,
    List<String>? pitfalls,
    String? groupId,
    List<String>? tags,
    CEFRLevel? cefrLevel,
    bool clearCefr = false,
    KnowledgeNoteOrigin? origin,
    String? sourcePrompt,
    DateTime? updatedAt,
  }) =>
      KnowledgeNote(
        id: id,
        title: title ?? this.title,
        summary: summary ?? this.summary,
        explanation: explanation ?? this.explanation,
        patterns: patterns ?? this.patterns,
        examples: examples ?? this.examples,
        pitfalls: pitfalls ?? this.pitfalls,
        groupId: groupId ?? this.groupId,
        tags: tags ?? this.tags,
        cefrLevel: clearCefr ? null : (cefrLevel ?? this.cefrLevel),
        targetLanguage: targetLanguage,
        origin: origin ?? this.origin,
        sourcePrompt: sourcePrompt ?? this.sourcePrompt,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
```

- [ ] **Step 5: Run tests, verify they pass**

Run: `flutter test test/features/knowledge/domain/entities/`
Expected: PASS. The round-trip test asserts `toJson()` equals the input map exactly — key order doesn't matter for `Map` equality, but every key must be present with the same value.

- [ ] **Step 6: `flutter analyze` + commit**

```bash
flutter analyze
git add lib/features/knowledge/domain/entities test/features/knowledge/domain/entities
git commit -m "feat(knowledge): KnowledgeNote entity + per-language group taxonomy"
```

---

## Task 5: `findRelatedNotes` — Layer-1 duplicate check

**Files:**
- Create: `lib/features/knowledge/domain/knowledge_dedup.dart`
- Test: `test/features/knowledge/domain/knowledge_dedup_test.dart`

**Interfaces:**
- Consumes: `normalizeForSearch` (Task 1), `KnowledgeNote` + `knowledgeGroupLabel` (Task 4).
- Produces: `List<KnowledgeNote> findRelatedNotes({required String prompt, required List<KnowledgeNote> notes})` — returns notes scoring ≥ 3, highest first, max 3. Scoring per spec §5.2: phrase (bi/trigram) substring of haystack = +3; that phrase also in title = +2 more; a note tag exactly equals a prompt token/phrase = +3; single prompt token substring of haystack = +1. Haystack = `normalizeForSearch(title + ' ' + summary + ' ' + tags.join(' ') + ' ' + knowledgeGroupLabel(groupId))`.
- Also produces (private but tested via the public fn): stopword filtering.

- [ ] **Step 1: Write failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/knowledge/domain/entities/knowledge_note.dart';
import 'package:lexi_core/features/knowledge/domain/knowledge_dedup.dart';

KnowledgeNote _n({
  required String id,
  required String title,
  String summary = '',
  List<String> tags = const [],
  String groupId = 'en_other',
}) {
  final t = DateTime.utc(2026, 1, 1);
  return KnowledgeNote(
    id: id, title: title, summary: summary, explanation: '',
    groupId: groupId, tags: tags, targetLanguage: Language.english,
    origin: KnowledgeNoteOrigin.manual, createdAt: t, updatedAt: t,
  );
}

void main() {
  test('matches on a repeated phrase in the title', () {
    final notes = [
      _n(id: 'a', title: 'Câu điều kiện loại 2 và 3'),
      _n(id: 'b', title: 'Mệnh đề quan hệ'),
    ];
    final hits = findRelatedNotes(
      prompt: 'giải thích câu điều kiện loại 2 khi nào dùng', notes: notes);
    expect(hits.map((n) => n.id), ['a']);
  });

  test('matches cross-diacritic (folded)', () {
    final notes = [_n(id: 'a', title: 'Câu điều kiện loại 2')];
    final hits = findRelatedNotes(prompt: 'cau dieu kien loai 2', notes: notes);
    expect(hits.single.id, 'a');
  });

  test('tag exact match scores', () {
    final notes = [_n(id: 'a', title: 'Ghi chú', tags: ['toeic'])];
    final hits = findRelatedNotes(prompt: 'ôn toeic phần này', notes: notes);
    expect(hits.single.id, 'a');
  });

  test('below threshold → no match', () {
    final notes = [_n(id: 'a', title: 'Mệnh đề quan hệ')];
    final hits = findRelatedNotes(prompt: 'thì hiện tại đơn', notes: notes);
    expect(hits, isEmpty);
  });

  test('caps at 3, sorted by score desc', () {
    final notes = [
      _n(id: 'a', title: 'thì hiện tại đơn'),
      _n(id: 'b', title: 'thì hiện tại tiếp diễn'),
      _n(id: 'c', title: 'thì hiện tại hoàn thành'),
      _n(id: 'd', title: 'thì quá khứ đơn'),
    ];
    final hits = findRelatedNotes(
        prompt: 'thì hiện tại đơn giải thích', notes: notes);
    expect(hits.length, 3);
    expect(hits.first.id, 'a'); // full phrase "thi hien tai don" in title
  });
}
```

- [ ] **Step 2: Run tests, verify they fail**

Run: `flutter test test/features/knowledge/domain/knowledge_dedup_test.dart`
Expected: FAIL — `knowledge_dedup.dart` not found.

- [ ] **Step 3: Implement**

```dart
// lib/features/knowledge/domain/knowledge_dedup.dart
import '../../../core/utils/text_normalize.dart';
import 'entities/knowledge_note.dart';
import 'entities/knowledge_group.dart';

const _stopwords = {
  'va', 'khi', 'nao', 'cho', 'cua', 'la', 'cac', 'mot', 'voi', 'thi',
  'dung', 'giai', 'thich', 'vi', 'du', 'doi', 'thuong', 'cach', 'nay',
  'the', 'a', 'an', 'and', 'or', 'when', 'how', 'what', 'explain', 'give',
  'example',
};

int _cefrScoreThreshold = 3; // kept as a name for the plan; inline 3 below.

List<String> _contentTokens(String prompt) {
  final norm = normalizeForSearch(prompt);
  if (norm.isEmpty) return const [];
  return norm
      .split(' ')
      .where((t) => t.isNotEmpty && !_stopwords.contains(t) && t.length > 1)
      .toList();
}

List<String> _phrases(List<String> tokens) {
  final out = <String>[];
  for (var i = 0; i < tokens.length - 1; i++) {
    out.add('${tokens[i]} ${tokens[i + 1]}');
    if (i < tokens.length - 2) {
      out.add('${tokens[i]} ${tokens[i + 1]} ${tokens[i + 2]}');
    }
  }
  return out;
}

List<KnowledgeNote> findRelatedNotes({
  required String prompt,
  required List<KnowledgeNote> notes,
}) {
  final tokens = _contentTokens(prompt);
  if (tokens.isEmpty) return const [];
  final phrases = _phrases(tokens);
  final promptTerms = {...tokens, ...phrases};

  final scored = <({KnowledgeNote note, int score})>[];
  for (final note in notes) {
    final title = normalizeForSearch(note.title);
    final haystack = normalizeForSearch([
      note.title,
      note.summary,
      note.tags.join(' '),
      knowledgeGroupLabel(note.groupId),
    ].join(' '));
    final noteTags = note.tags.map(normalizeForSearch).toSet();

    var score = 0;
    for (final phrase in phrases) {
      if (haystack.contains(phrase)) {
        score += 3;
        if (title.contains(phrase)) score += 2;
      }
    }
    for (final term in promptTerms) {
      if (noteTags.contains(term)) score += 3;
    }
    for (final token in tokens) {
      if (haystack.contains(token)) score += 1;
    }
    if (score >= 3) scored.add((note: note, score: score));
  }

  scored.sort((a, b) => b.score.compareTo(a.score));
  return scored.take(3).map((e) => e.note).toList();
}
```

> Remove the unused `_cefrScoreThreshold` line before committing — it's a leftover; the threshold is the literal `3`. (Left visible here only so a reviewer sees the number is deliberate.)

- [ ] **Step 4: Run tests, verify they pass**

Run: `flutter test test/features/knowledge/domain/knowledge_dedup_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: `flutter analyze` + commit**

```bash
flutter analyze
git add lib/features/knowledge/domain/knowledge_dedup.dart test/features/knowledge/domain/knowledge_dedup_test.dart
git commit -m "feat(knowledge): Layer-1 local duplicate-check (findRelatedNotes)"
```

---

## Task 6: `KnowledgeNotesService` — Firestore CRUD + seeding

**Files:**
- Create: `lib/features/knowledge/data/knowledge_notes_service.dart`
- Create: `lib/features/knowledge/data/knowledge_starter_library.dart`
- Create: `assets/knowledge/starter_en.json` (start with 2 entries; Task 15 fills all 12)
- Modify: `pubspec.yaml` (add `- assets/knowledge/`)
- Test: `test/features/knowledge/data/knowledge_notes_service_test.dart`
- Test: `test/features/knowledge/data/knowledge_starter_library_test.dart`

**Interfaces:**
- Consumes: `KnowledgeNote` (Task 4), `Language`.
- Produces:
  - `class KnowledgeStarterLibrary { Future<List<KnowledgeNote>> notesFor(Language language); }` — reads `assets/knowledge/starter_${language.code}.json` via an injected loader `Future<String> Function(String assetKey)` (default `rootBundle.loadString`); returns `[]` for a language with no asset (catches the missing-asset error).
  - `class KnowledgeNotesService`:
    - ctor `({FirebaseFirestore? firestore, String? Function()? currentUid, KnowledgeStarterLibrary? starterLibrary})`.
    - `Future<List<KnowledgeNote>> all(Language language)` — reads the whole collection, filters `targetLanguage == language.name`, sorts by `updatedAt` desc. `[]` if signed out / offline (catch).
    - `Future<void> upsert(KnowledgeNote note)` — `set` at `knowledge_notes/{note.id}` with `note.toJson()`. No-op if signed out.
    - `Future<void> delete(String id)`.
    - `Future<List<KnowledgeNote>> seedIfNeeded(Language language)` — if the seed flag (`knowledge_meta/seed`, field `language.name`) is not `true` AND `all(language)` is empty: write every starter note whose id is not already present, set the flag `true`. Returns the notes it wrote (`[]` if nothing seeded). Best-effort (catch → `[]`).
    - `Future<List<KnowledgeNote>> restoreStarters(Language language)` — write every starter note whose id is absent from the collection; do not touch existing ids; returns what it wrote.
- `id` is written into the body by `toJson()` already; use it as the doc id too.

- [ ] **Step 1: Write `starter_en.json` (2 stub entries for now)**

```json
[
  {
    "id": "starter_en_present_simple",
    "title": "Hiện tại đơn",
    "summary": "Diễn tả thói quen, sự thật hiển nhiên, lịch trình cố định.",
    "explanation": "Dùng **hiện tại đơn** cho thói quen và sự thật.\n\nNgôi thứ ba số ít thêm **-s/-es** vào động từ.",
    "patterns": ["S + V(s/es) + O", "S + do/does + not + V", "Do/Does + S + V?"],
    "examples": [
      {"text": "She works in a bank.", "translation": "Cô ấy làm việc ở ngân hàng."},
      {"text": "Water boils at 100°C.", "translation": "Nước sôi ở 100°C."}
    ],
    "pitfalls": ["Quên **-s** ở ngôi thứ ba số ít.", "Dùng hiện tại đơn cho việc đang diễn ra ngay lúc nói."],
    "groupId": "en_tenses",
    "tags": ["ngu-phap-co-ban"],
    "cefrLevel": "a1",
    "targetLanguage": "english",
    "source": "starter",
    "sourcePrompt": null,
    "createdAt": "2026-09-07T00:00:00.000Z",
    "updatedAt": "2026-09-07T00:00:00.000Z"
  },
  {
    "id": "starter_en_conditionals_2_3",
    "title": "Câu điều kiện loại 2 và 3",
    "summary": "Loại 2: giả định trái hiện tại. Loại 3: giả định trái quá khứ.",
    "explanation": "**Loại 2** nói về điều không có thật ở hiện tại: *If + quá khứ đơn, would + V*.\n\n**Loại 3** nói về điều đã không xảy ra trong quá khứ: *If + had + P.P, would have + P.P*.",
    "patterns": ["If + S + V-past, S + would + V", "If + S + had + P.P, S + would have + P.P"],
    "examples": [
      {"text": "If I had more time, I would learn piano.", "translation": "Nếu tôi có nhiều thời gian hơn, tôi sẽ học piano."},
      {"text": "If she had studied, she would have passed.", "translation": "Nếu cô ấy đã học, cô ấy đã đậu rồi."}
    ],
    "pitfalls": ["Dùng \"would\" trong mệnh đề if.", "Nhầm loại 2 với loại 3 khi mốc thời gian là quá khứ."],
    "groupId": "en_conditionals",
    "tags": ["ngu-phap-co-ban"],
    "cefrLevel": "b1",
    "targetLanguage": "english",
    "source": "starter",
    "sourcePrompt": null,
    "createdAt": "2026-09-07T00:00:00.000Z",
    "updatedAt": "2026-09-07T00:00:00.000Z"
  }
]
```

- [ ] **Step 2: Add the asset dir to `pubspec.yaml`**

```yaml
  assets:
    - assets/fonts/
    - assets/knowledge/
```

- [ ] **Step 3: Write failing tests**

```dart
// test/features/knowledge/data/knowledge_starter_library_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/knowledge/data/knowledge_starter_library.dart';

void main() {
  test('decodes the bundled English starter file', () async {
    final lib = KnowledgeStarterLibrary(); // uses rootBundle
    TestWidgetsFlutterBinding.ensureInitialized();
    final notes = await lib.notesFor(Language.english);
    expect(notes, isNotEmpty);
    expect(notes.every((n) => n.origin.name == 'starter'), isTrue);
    expect(notes.map((n) => n.id).toSet().length, notes.length); // unique ids
  });

  test('returns [] for a language with no starter asset', () async {
    final lib = KnowledgeStarterLibrary(
      loadAsset: (_) async => throw Exception('asset not found'),
    );
    expect(await lib.notesFor(Language.korean), isEmpty);
  });
}
```

```dart
// test/features/knowledge/data/knowledge_notes_service_test.dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/knowledge/data/knowledge_notes_service.dart';
import 'package:lexi_core/features/knowledge/data/knowledge_starter_library.dart';
import 'package:lexi_core/features/knowledge/domain/entities/knowledge_note.dart';

const _uid = 'u1';

KnowledgeNote _note(String id, {String lang = 'english', String group = 'en_other'}) {
  final t = DateTime.utc(2026, 1, 1);
  return KnowledgeNote(
    id: id, title: 'T $id', summary: 's', explanation: 'e', groupId: group,
    targetLanguage: Language.values.byName(lang),
    origin: KnowledgeNoteOrigin.manual, createdAt: t, updatedAt: t,
  );
}

KnowledgeNotesService _svc(
  FakeFirebaseFirestore fs, {
  String? uid = _uid,
  KnowledgeStarterLibrary? starter,
}) =>
    KnowledgeNotesService(
      firestore: fs,
      currentUid: () => uid,
      starterLibrary: starter ??
          KnowledgeStarterLibrary(loadAsset: (_) async => '[]'),
    );

void main() {
  test('upsert then all() round-trips and filters by language', () async {
    final fs = FakeFirebaseFirestore();
    final svc = _svc(fs);
    await svc.upsert(_note('a'));
    await svc.upsert(_note('b', lang: 'chinese'));
    final en = await svc.all(Language.english);
    expect(en.map((n) => n.id), ['a']);
  });

  test('all() sorts by updatedAt desc', () async {
    final fs = FakeFirebaseFirestore();
    final svc = _svc(fs);
    await svc.upsert(_note('old').copyWith(updatedAt: DateTime.utc(2026, 1, 1)));
    await svc.upsert(_note('new').copyWith(updatedAt: DateTime.utc(2026, 6, 1)));
    final all = await svc.all(Language.english);
    expect(all.map((n) => n.id), ['new', 'old']);
  });

  test('delete removes the doc', () async {
    final fs = FakeFirebaseFirestore();
    final svc = _svc(fs);
    await svc.upsert(_note('a'));
    await svc.delete('a');
    expect(await svc.all(Language.english), isEmpty);
  });

  test('seedIfNeeded seeds once, respects the flag', () async {
    final fs = FakeFirebaseFirestore();
    final starter = KnowledgeStarterLibrary(
      loadAsset: (_) async =>
          '[${_note('starter_en_x').toJson().toString().replaceAll("'", '"')}]',
    );
    // Simpler: build the starter lib from real JSON — see note below.
    final svc = KnowledgeNotesService(
      firestore: fs,
      currentUid: () => _uid,
      starterLibrary: _StubStarter([_note('starter_en_x')]),
    );
    final first = await svc.seedIfNeeded(Language.english);
    expect(first.map((n) => n.id), ['starter_en_x']);
    final second = await svc.seedIfNeeded(Language.english);
    expect(second, isEmpty); // flag set
    expect((await svc.all(Language.english)).length, 1);
  });

  test('seedIfNeeded does not seed when the collection is non-empty', () async {
    final fs = FakeFirebaseFirestore();
    final svc = KnowledgeNotesService(
      firestore: fs, currentUid: () => _uid,
      starterLibrary: _StubStarter([_note('starter_en_x')]),
    );
    await svc.upsert(_note('user1'));
    final seeded = await svc.seedIfNeeded(Language.english);
    expect(seeded, isEmpty);
  });

  test('restoreStarters re-adds only absent ids, keeps edited ones', () async {
    final fs = FakeFirebaseFirestore();
    final svc = KnowledgeNotesService(
      firestore: fs, currentUid: () => _uid,
      starterLibrary: _StubStarter([
        _note('starter_en_a'),
        _note('starter_en_b'),
      ]),
    );
    await svc.upsert(_note('starter_en_a').copyWith(title: 'MY EDIT'));
    final restored = await svc.restoreStarters(Language.english);
    expect(restored.map((n) => n.id), ['starter_en_b']);
    final a = (await svc.all(Language.english)).firstWhere((n) => n.id == 'starter_en_a');
    expect(a.title, 'MY EDIT'); // untouched
  });

  test('signed out: all() empty, upsert no-op', () async {
    final fs = FakeFirebaseFirestore();
    final svc = _svc(fs, uid: null);
    await svc.upsert(_note('a'));
    expect(await svc.all(Language.english), isEmpty);
  });
}

class _StubStarter implements KnowledgeStarterLibrary {
  _StubStarter(this._notes);
  final List<KnowledgeNote> _notes;
  @override
  Future<List<KnowledgeNote>> notesFor(Language language) async =>
      language == Language.english ? _notes : [];
}
```

> Simplify the `seedIfNeeded seeds once` test to use `_StubStarter` (as the later tests do) rather than the string hack — drop the first `starter` variable. The `_StubStarter` implements the same interface.

- [ ] **Step 4: Implement `knowledge_starter_library.dart`**

```dart
// lib/features/knowledge/data/knowledge_starter_library.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../../dictionary/domain/entities/language.dart';
import '../domain/entities/knowledge_note.dart';

class KnowledgeStarterLibrary {
  KnowledgeStarterLibrary({Future<String> Function(String assetKey)? loadAsset})
      : _load = loadAsset ?? rootBundle.loadString;

  final Future<String> Function(String assetKey) _load;

  /// Starter notes bundled for [language], or `[]` when the app ships none
  /// for it (v1: only English).
  Future<List<KnowledgeNote>> notesFor(Language language) async {
    try {
      final raw = await _load('assets/knowledge/starter_${language.code}.json');
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      return list.map(KnowledgeNote.fromJson).toList();
    } catch (_) {
      return const [];
    }
  }
}
```

- [ ] **Step 5: Implement `knowledge_notes_service.dart`**

```dart
// lib/features/knowledge/data/knowledge_notes_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../dictionary/domain/entities/language.dart';
import '../domain/entities/knowledge_note.dart';
import 'knowledge_starter_library.dart';

/// Reads/writes `users/{uid}/knowledge_notes` directly (no Hive, no
/// SyncService) — same shape/trust model as SavedExercisesService. The
/// per-language seed flag lives in `users/{uid}/knowledge_meta/seed`.
class KnowledgeNotesService {
  KnowledgeNotesService({
    FirebaseFirestore? firestore,
    String? Function()? currentUid,
    KnowledgeStarterLibrary? starterLibrary,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _currentUid =
            currentUid ?? (() => FirebaseAuth.instance.currentUser?.uid),
        _starter = starterLibrary ?? KnowledgeStarterLibrary();

  final FirebaseFirestore _firestore;
  final String? Function() _currentUid;
  final KnowledgeStarterLibrary _starter;

  CollectionReference<Map<String, dynamic>>? _notes() {
    final uid = _currentUid();
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).collection('knowledge_notes');
  }

  DocumentReference<Map<String, dynamic>>? _seedDoc() {
    final uid = _currentUid();
    if (uid == null) return null;
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('knowledge_meta')
        .doc('seed');
  }

  Future<List<KnowledgeNote>> all(Language language) async {
    final col = _notes();
    if (col == null) return const [];
    try {
      final snap = await col.get();
      final notes = snap.docs
          .map((d) => d.data())
          .where((m) => m['targetLanguage'] == language.name)
          .map(KnowledgeNote.fromJson)
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return notes;
    } catch (_) {
      return const [];
    }
  }

  Future<void> upsert(KnowledgeNote note) async {
    final col = _notes();
    if (col == null) return;
    try {
      await col.doc(note.id).set(note.toJson());
    } catch (_) {/* best-effort */}
  }

  Future<void> delete(String id) async {
    final col = _notes();
    if (col == null) return;
    try {
      await col.doc(id).delete();
    } catch (_) {}
  }

  Future<List<KnowledgeNote>> seedIfNeeded(Language language) async {
    final col = _notes();
    final seedDoc = _seedDoc();
    if (col == null || seedDoc == null) return const [];
    try {
      final flag = (await seedDoc.get()).data()?[language.name] == true;
      if (flag) return const [];
      final existing = await col.get();
      if (existing.docs.isNotEmpty &&
          existing.docs.any((d) => d.data()['targetLanguage'] == language.name)) {
        // Language already has notes — mark seeded, write nothing.
        await seedDoc.set({language.name: true}, SetOptions(merge: true));
        return const [];
      }
      final written = await _writeMissing(col, language);
      await seedDoc.set({language.name: true}, SetOptions(merge: true));
      return written;
    } catch (_) {
      return const [];
    }
  }

  Future<List<KnowledgeNote>> restoreStarters(Language language) async {
    final col = _notes();
    if (col == null) return const [];
    try {
      return await _writeMissing(col, language);
    } catch (_) {
      return const [];
    }
  }

  Future<List<KnowledgeNote>> _writeMissing(
    CollectionReference<Map<String, dynamic>> col,
    Language language,
  ) async {
    final starters = await _starter.notesFor(language);
    if (starters.isEmpty) return const [];
    final existingIds = (await col.get()).docs.map((d) => d.id).toSet();
    final toWrite = starters.where((n) => !existingIds.contains(n.id)).toList();
    for (final n in toWrite) {
      await col.doc(n.id).set(n.toJson());
    }
    return toWrite;
  }
}
```

- [ ] **Step 6: Run tests, verify they pass; fix the seed test per the note in Step 3**

Run: `flutter test test/features/knowledge/data/`
Expected: PASS.

- [ ] **Step 7: `flutter analyze` + commit**

```bash
flutter analyze
git add lib/features/knowledge/data assets/knowledge pubspec.yaml test/features/knowledge/data
git commit -m "feat(knowledge): KnowledgeNotesService (Firestore CRUD + lazy seeding)"
```

---

## Task 7: `KnowledgeNoteSource` — AI draft

**Files:**
- Create: `lib/features/knowledge/data/sources/knowledge_note_source.dart`
- Create: `lib/features/knowledge/domain/use_cases/generate_knowledge_note_use_case.dart`
- Test: `test/features/knowledge/data/sources/knowledge_note_source_test.dart`

**Interfaces:**
- Consumes: `AiClientFactory` / `GenerativeModelClient` (`lib/core/services/ai_client_factory.dart`), `parseAiJsonObject` (`lib/core/utils/ai_json_parser.dart`), `UserSettingsState`, `Language`, `CEFRLevel`, `KnowledgeNote` + `knowledgeGroupsFor`.
- Produces:
  - `class KnowledgeNoteDraft { final String title, summary, explanation; final List<String> patterns, pitfalls, suggestedTags; final List<KnowledgeExample> examples; final String? suggestedGroupId; final CEFRLevel? suggestedCefr; final String? relatedNoteId; }`.
  - `class KnowledgeNoteSource`:
    - `KnowledgeNoteSource(UserSettingsState settings)` → `AiClientFactory.buildClient`.
    - `KnowledgeNoteSource.withModel(GenerativeModelClient client)`.
    - `Future<KnowledgeNoteDraft> draft({ required String request, required Language targetLanguage, String? hintGroupId, CEFRLevel? hintCefr, required List<KnowledgeNote> existingInScope, KnowledgeNote? extendingNote })` — builds the prompt (include the language's group id/label list, the `{id,title,summary}` of `existingInScope`, and — if `extendingNote != null` — its full current content with an instruction to merge), calls `generateContent`, `parseAiJsonObject`, maps to `KnowledgeNoteDraft` defensively.
  - `re-export ... show GenerativeModelClient;` (match `word_radar_source.dart`).
  - `class GenerateKnowledgeNoteUseCase { const GenerateKnowledgeNoteUseCase(this._source); Future<KnowledgeNoteDraft> execute({...same named params...}) => _source.draft(...); }`.

- [ ] **Step 1: Write failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:google_generative_ai/google_generative_ai.dart' hide Language;
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/knowledge/data/sources/knowledge_note_source.dart';

class _FakeClient implements GenerativeModelClient {
  _FakeClient(this.response);
  final String response;
  String? capturedPrompt;
  @override
  Future<GenerateContentResponse> generateContent(Iterable<Content> prompt) async {
    capturedPrompt = prompt
        .expand((c) => c.parts)
        .whereType<TextPart>()
        .map((p) => p.text)
        .join('\n');
    return GenerateContentResponse(
      [Candidate(Content.text(response), null, null, null, null)], null);
  }
}

void main() {
  const good = '''
{"title":"Câu điều kiện loại 2","summary":"Giả định trái hiện tại.",
"explanation":"Dùng **were**.","patterns":["If + S + V-past, S + would + V"],
"examples":[{"text":"If I were you","translation":"Nếu tôi là bạn"}],
"pitfalls":["Đừng dùng was."],"suggestedGroupId":"en_conditionals",
"suggestedCefr":"b1","suggestedTags":["ngu-phap"],"relatedNoteId":null}
''';

  test('parses a well-formed draft', () async {
    final client = _FakeClient(good);
    final draft = await KnowledgeNoteSource.withModel(client).draft(
      request: 'giải thích loại 2',
      targetLanguage: Language.english,
      existingInScope: const [],
    );
    expect(draft.title, 'Câu điều kiện loại 2');
    expect(draft.suggestedGroupId, 'en_conditionals');
    expect(draft.suggestedCefr, CEFRLevel.b1);
    expect(draft.examples.single.translation, 'Nếu tôi là bạn');
    expect(draft.relatedNoteId, isNull);
  });

  test('prompt lists the language group ids and the existing notes', () async {
    final client = _FakeClient(good);
    await KnowledgeNoteSource.withModel(client).draft(
      request: 'x', targetLanguage: Language.english, existingInScope: const []);
    expect(client.capturedPrompt, contains('en_conditionals'));
  });

  test('garbage response throws (best-effort caller handles it)', () async {
    final client = _FakeClient('not json at all');
    expect(
      () => KnowledgeNoteSource.withModel(client).draft(
        request: 'x', targetLanguage: Language.english, existingInScope: const []),
      throwsA(anything),
    );
  });

  test('missing optional fields default safely', () async {
    final client = _FakeClient('{"title":"T","summary":"S","explanation":"E"}');
    final draft = await KnowledgeNoteSource.withModel(client).draft(
      request: 'x', targetLanguage: Language.english, existingInScope: const []);
    expect(draft.patterns, isEmpty);
    expect(draft.suggestedGroupId, isNull);
    expect(draft.suggestedCefr, isNull);
  });
}
```

- [ ] **Step 2: Run test, verify it fails**

Run: `flutter test test/features/knowledge/data/sources/knowledge_note_source_test.dart`
Expected: FAIL — source not found.

- [ ] **Step 3: Implement `knowledge_note_source.dart`**

```dart
// lib/features/knowledge/data/sources/knowledge_note_source.dart
import 'package:google_generative_ai/google_generative_ai.dart' hide Language;
import '../../../../core/services/ai_client_factory.dart';
import '../../../../core/utils/ai_json_parser.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../../../dictionary/domain/entities/user_settings_state.dart';
import '../../../vocabulary/domain/entities/cefr_level.dart';
import '../../domain/entities/knowledge_group.dart';
import '../../domain/entities/knowledge_note.dart';

export '../../../../core/services/ai_client_factory.dart'
    show GenerativeModelClient;

class KnowledgeNoteDraft {
  const KnowledgeNoteDraft({
    required this.title,
    required this.summary,
    required this.explanation,
    this.patterns = const [],
    this.examples = const [],
    this.pitfalls = const [],
    this.suggestedGroupId,
    this.suggestedCefr,
    this.suggestedTags = const [],
    this.relatedNoteId,
  });

  final String title;
  final String summary;
  final String explanation;
  final List<String> patterns;
  final List<KnowledgeExample> examples;
  final List<String> pitfalls;
  final String? suggestedGroupId;
  final CEFRLevel? suggestedCefr;
  final List<String> suggestedTags;
  final String? relatedNoteId;
}

class KnowledgeNoteSource {
  KnowledgeNoteSource(UserSettingsState settings)
      : _client = AiClientFactory.buildClient(settings);
  KnowledgeNoteSource.withModel(GenerativeModelClient client)
      : _client = client;

  final GenerativeModelClient _client;

  static List<String> _stringList(Object? v) =>
      v is List ? v.whereType<String>().toList() : (v is String && v.isNotEmpty ? [v] : const []);

  Future<KnowledgeNoteDraft> draft({
    required String request,
    required Language targetLanguage,
    String? hintGroupId,
    CEFRLevel? hintCefr,
    required List<KnowledgeNote> existingInScope,
    KnowledgeNote? extendingNote,
  }) async {
    final prompt = _buildPrompt(
      request: request,
      targetLanguage: targetLanguage,
      hintGroupId: hintGroupId,
      hintCefr: hintCefr,
      existingInScope: existingInScope,
      extendingNote: extendingNote,
    );
    final response = await _client.generateContent([Content.text(prompt)]);
    final json = parseAiJsonObject(response.text ?? '');
    return KnowledgeNoteDraft(
      title: json['title'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      explanation: json['explanation'] as String? ?? '',
      patterns: _stringList(json['patterns']),
      examples: (json['examples'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(KnowledgeExample.fromJson)
          .toList(),
      pitfalls: _stringList(json['pitfalls']),
      suggestedGroupId: (json['suggestedGroupId'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['suggestedGroupId'] as String).trim(),
      suggestedCefr: CEFRLevel.values
          .asNameMap()[(json['suggestedCefr'] as String?)?.trim().toLowerCase()],
      suggestedTags: _stringList(json['suggestedTags']),
      relatedNoteId: (json['relatedNoteId'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['relatedNoteId'] as String).trim(),
    );
  }

  String _buildPrompt({
    required String request,
    required Language targetLanguage,
    String? hintGroupId,
    CEFRLevel? hintCefr,
    required List<KnowledgeNote> existingInScope,
    KnowledgeNote? extendingNote,
  }) {
    final groups = knowledgeGroupsFor(targetLanguage)
        .map((g) => '${g.id} (${g.label})')
        .join('; ');
    final existing = existingInScope.isEmpty
        ? 'None.'
        : existingInScope
            .map((n) => '- id=${n.id} | ${n.title} | ${n.summary}')
            .join('\n');
    final hintClause = [
      if (hintGroupId != null) 'Prefer groupId "$hintGroupId".',
      if (hintCefr != null) 'Target CEFR ${hintCefr.label}.',
    ].join(' ');
    final extendClause = extendingNote == null
        ? ''
        : 'You are REVISING this existing note — merge the new request into it '
            'and return the full updated note:\n'
            '${extendingNote.toJson()}\n';
    return 'You are a grammar reference assistant for a Vietnamese speaker '
        'learning ${targetLanguage.label}. Write a single reference note '
        'answering this request: "$request". $hintClause\n'
        '$extendClause'
        'Available groupId values: $groups\n'
        'Existing notes in the same area (for de-duplication):\n$existing\n'
        'All prose and translations must be in Vietnamese (Vietnamese script '
        'only). In "explanation" and each "pitfalls" item you may wrap key '
        'terms in **double asterisks** for bold; use \\n\\n between paragraphs; '
        'no other markup. '
        'Respond with JSON only (no code fences): '
        '{"title":"short Vietnamese title","summary":"1-2 Vietnamese sentences",'
        '"explanation":"...","patterns":["form strings, may be empty"],'
        '"examples":[{"text":"target-language sentence","translation":"Vietnamese"}],'
        '"pitfalls":["common mistakes, may be empty"],'
        '"suggestedGroupId":"one id from the list above",'
        '"suggestedCefr":"a1|a2|b1|b2|c1|c2 or null",'
        '"suggestedTags":["0-3 short kebab-case Vietnamese-friendly tags"],'
        '"relatedNoteId":"the id of an existing note this substantially '
        'duplicates, or null"}';
  }
}
```

- [ ] **Step 4: Implement `generate_knowledge_note_use_case.dart`**

```dart
// lib/features/knowledge/domain/use_cases/generate_knowledge_note_use_case.dart
import '../../../dictionary/domain/entities/language.dart';
import '../../../vocabulary/domain/entities/cefr_level.dart';
import '../../data/sources/knowledge_note_source.dart';
import '../entities/knowledge_note.dart';

class GenerateKnowledgeNoteUseCase {
  const GenerateKnowledgeNoteUseCase(this._source);
  final KnowledgeNoteSource _source;

  Future<KnowledgeNoteDraft> execute({
    required String request,
    required Language targetLanguage,
    String? hintGroupId,
    CEFRLevel? hintCefr,
    required List<KnowledgeNote> existingInScope,
    KnowledgeNote? extendingNote,
  }) =>
      _source.draft(
        request: request,
        targetLanguage: targetLanguage,
        hintGroupId: hintGroupId,
        hintCefr: hintCefr,
        existingInScope: existingInScope,
        extendingNote: extendingNote,
      );
}
```

- [ ] **Step 5: Run test, verify it passes**

Run: `flutter test test/features/knowledge/data/sources/knowledge_note_source_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 6: `flutter analyze` + commit**

```bash
flutter analyze
git add lib/features/knowledge/data/sources lib/features/knowledge/domain/use_cases test/features/knowledge/data/sources
git commit -m "feat(knowledge): KnowledgeNoteSource AI draft + use case"
```

---

## Task 8: DI providers

**Files:**
- Modify: `lib/core/di/app_providers.dart` (add 4 `@riverpod` fns near the word-radar/reading source providers, ~line 215)
- Then: `dart run build_runner build --delete-conflicting-outputs`
- Test: none new — covered by Task 9's notifier test compiling.

**Interfaces:**
- Produces: `knowledgeNotesServiceProvider`, `knowledgeStarterLibraryProvider`, `knowledgeNoteSourceProvider`, `generateKnowledgeNoteUseCaseProvider`.

- [ ] **Step 1: Add the providers**

Add to `lib/core/di/app_providers.dart` (imports at top, providers in the body):

```dart
// imports
import '../../features/knowledge/data/knowledge_notes_service.dart';
import '../../features/knowledge/data/knowledge_starter_library.dart';
import '../../features/knowledge/data/sources/knowledge_note_source.dart';
import '../../features/knowledge/domain/use_cases/generate_knowledge_note_use_case.dart';
```

```dart
@riverpod
KnowledgeStarterLibrary knowledgeStarterLibrary(KnowledgeStarterLibraryRef ref) =>
    KnowledgeStarterLibrary();

@riverpod
KnowledgeNotesService knowledgeNotesService(KnowledgeNotesServiceRef ref) =>
    KnowledgeNotesService(
      currentUid: () => ref.read(currentUidProvider),
      starterLibrary: ref.watch(knowledgeStarterLibraryProvider),
    );

@riverpod
KnowledgeNoteSource knowledgeNoteSource(KnowledgeNoteSourceRef ref) {
  final settings = ref.watch(userSettingsNotifierProvider);
  return KnowledgeNoteSource(settings);
}

@riverpod
GenerateKnowledgeNoteUseCase generateKnowledgeNoteUseCase(
        GenerateKnowledgeNoteUseCaseRef ref) =>
    GenerateKnowledgeNoteUseCase(ref.watch(knowledgeNoteSourceProvider));
```

- [ ] **Step 2: Regenerate**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `app_providers.g.dart` updated, no errors.

- [ ] **Step 3: `flutter analyze` + commit**

```bash
flutter analyze
git add lib/core/di/app_providers.dart lib/core/di/app_providers.g.dart
git commit -m "feat(knowledge): DI providers for service/source/use-case"
```

---

## Task 9: `KnowledgeNotesNotifier`

**Files:**
- Create: `lib/features/knowledge/presentation/providers/knowledge_notes_provider.dart`
- Then: `dart run build_runner build --delete-conflicting-outputs`
- Test: `test/features/knowledge/presentation/providers/knowledge_notes_provider_test.dart`

**Interfaces:**
- Consumes: `knowledgeNotesServiceProvider` (Task 8), `userSettingsNotifierProvider` (`.select((s) => s.targetLanguage)`).
- Produces: `KnowledgeNotesNotifier extends _$KnowledgeNotesNotifier`:
  - `FutureOr<List<KnowledgeNote>> build()` — reads active `targetLanguage`; calls `service.seedIfNeeded(language)` then `service.all(language)`; returns the list. Rebuilds when `targetLanguage` changes.
  - `Future<void> saveNote(KnowledgeNote note)` — `service.upsert(note)` then refresh state (optimistic: update in place).
  - `Future<void> deleteNote(String id)` — `service.delete(id)` then remove from state.
  - `Future<void> restoreStarters()` — `service.restoreStarters(language)` then refresh.
- Non-state helpers live in the screen layer, not here (filtering/search are pure — see Task 10's `knowledge_filters.dart`).

- [ ] **Step 1: Write failing test**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/di/app_providers.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/dictionary/domain/entities/user_settings_state.dart';
import 'package:lexi_core/features/dictionary/presentation/providers/user_settings_provider.dart';
import 'package:lexi_core/features/knowledge/data/knowledge_notes_service.dart';
import 'package:lexi_core/features/knowledge/domain/entities/knowledge_note.dart';
import 'package:lexi_core/features/knowledge/presentation/providers/knowledge_notes_provider.dart';

class _FakeSettings extends UserSettingsNotifier {
  _FakeSettings(this._s);
  final UserSettingsState _s;
  @override
  UserSettingsState build() => _s;
}

class _FakeService implements KnowledgeNotesService {
  final List<KnowledgeNote> store = [];
  int seedCalls = 0;
  @override
  Future<List<KnowledgeNote>> all(Language language) async =>
      store.where((n) => n.targetLanguage == language).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  @override
  Future<void> upsert(KnowledgeNote note) async {
    store.removeWhere((n) => n.id == note.id);
    store.add(note);
  }
  @override
  Future<void> delete(String id) async => store.removeWhere((n) => n.id == id);
  @override
  Future<List<KnowledgeNote>> seedIfNeeded(Language language) async {
    seedCalls++;
    return const [];
  }
  @override
  Future<List<KnowledgeNote>> restoreStarters(Language language) async => const [];
}

KnowledgeNote _note(String id, {Language lang = Language.english}) {
  final t = DateTime.utc(2026, 1, 1);
  return KnowledgeNote(
    id: id, title: 'T $id', summary: 's', explanation: 'e', groupId: 'en_other',
    targetLanguage: lang, origin: KnowledgeNoteOrigin.manual,
    createdAt: t, updatedAt: t,
  );
}

ProviderContainer _container(_FakeService svc, {Language lang = Language.english}) {
  return ProviderContainer(overrides: [
    knowledgeNotesServiceProvider.overrideWithValue(svc),
    userSettingsNotifierProvider.overrideWith(() => _FakeSettings(
      UserSettingsState.initial().copyWith(targetLanguage: lang),
    )),
  ]);
}

void main() {
  test('build() seeds then loads notes for the active language', () async {
    final svc = _FakeService()..store.addAll([_note('a'), _note('b', lang: Language.chinese)]);
    final c = _container(svc);
    final notes = await c.read(knowledgeNotesNotifierProvider.future);
    expect(svc.seedCalls, 1);
    expect(notes.map((n) => n.id), ['a']);
  });

  test('saveNote upserts and refreshes', () async {
    final svc = _FakeService();
    final c = _container(svc);
    await c.read(knowledgeNotesNotifierProvider.future);
    await c.read(knowledgeNotesNotifierProvider.notifier).saveNote(_note('x'));
    final notes = await c.read(knowledgeNotesNotifierProvider.future);
    expect(notes.map((n) => n.id), contains('x'));
  });

  test('deleteNote removes from state', () async {
    final svc = _FakeService()..store.add(_note('x'));
    final c = _container(svc);
    await c.read(knowledgeNotesNotifierProvider.future);
    await c.read(knowledgeNotesNotifierProvider.notifier).deleteNote('x');
    final notes = await c.read(knowledgeNotesNotifierProvider.future);
    expect(notes, isEmpty);
  });
}
```

> Check `UserSettingsState`'s real constructor — if there is no `.initial()` / `.copyWith`, build the state the way `word_radar_provider_test.dart` does (it constructs `UserSettingsState(...)` directly). Match that test's approach exactly.

- [ ] **Step 2: Run test, verify it fails**

Run: `flutter test test/features/knowledge/presentation/providers/knowledge_notes_provider_test.dart`
Expected: FAIL — provider not found.

- [ ] **Step 3: Implement**

```dart
// lib/features/knowledge/presentation/providers/knowledge_notes_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/di/app_providers.dart';
import '../../../dictionary/presentation/providers/user_settings_provider.dart';
import '../../domain/entities/knowledge_note.dart';

part 'knowledge_notes_provider.g.dart';

@riverpod
class KnowledgeNotesNotifier extends _$KnowledgeNotesNotifier {
  @override
  Future<List<KnowledgeNote>> build() async {
    final language = ref.watch(
      userSettingsNotifierProvider.select((s) => s.targetLanguage),
    );
    final service = ref.read(knowledgeNotesServiceProvider);
    await service.seedIfNeeded(language);
    return service.all(language);
  }

  Future<void> saveNote(KnowledgeNote note) async {
    await ref.read(knowledgeNotesServiceProvider).upsert(note);
    final current = [...?state.valueOrNull]
      ..removeWhere((n) => n.id == note.id)
      ..add(note);
    current.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    state = AsyncData(current);
  }

  Future<void> deleteNote(String id) async {
    await ref.read(knowledgeNotesServiceProvider).delete(id);
    state = AsyncData(
      [...?state.valueOrNull]..removeWhere((n) => n.id == id),
    );
  }

  Future<void> restoreStarters() async {
    final language = ref.read(
      userSettingsNotifierProvider.select((s) => s.targetLanguage),
    );
    await ref.read(knowledgeNotesServiceProvider).restoreStarters(language);
    ref.invalidateSelf();
    await future;
  }
}
```

- [ ] **Step 4: Regenerate + run test**

Run: `dart run build_runner build --delete-conflicting-outputs`
Run: `flutter test test/features/knowledge/presentation/providers/knowledge_notes_provider_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: `flutter analyze` + commit**

```bash
flutter analyze
git add lib/features/knowledge/presentation/providers/knowledge_notes_provider.dart lib/features/knowledge/presentation/providers/knowledge_notes_provider.g.dart test/features/knowledge/presentation/providers/knowledge_notes_provider_test.dart
git commit -m "feat(knowledge): KnowledgeNotesNotifier (seed-on-load + CRUD state)"
```

---

## Task 10: `knowledge_filters.dart` — pure search/filter/group-count helpers

**Files:**
- Create: `lib/features/knowledge/domain/knowledge_filters.dart`
- Test: `test/features/knowledge/domain/knowledge_filters_test.dart`

**Interfaces:**
- Consumes: `normalizeForSearch` (Task 1), `KnowledgeNote`.
- Produces:
  - `class KnowledgeFilter { final String query; final Set<String> groupIds; final Set<CEFRLevel> levels; final Set<String> tags; const ...; bool get isActive; }`.
  - `List<KnowledgeNote> applyKnowledgeFilter(List<KnowledgeNote> notes, KnowledgeFilter filter)` — query does an accent-folded substring match over `title + summary + explanation + patterns + pitfalls + tags`; group/level/tag are OR-within, AND-across (a note passes a non-empty `groupIds` only if its `groupId` is in the set; etc.).
  - `Map<String, int> knowledgeGroupCounts(List<KnowledgeNote> notes)` — `groupId → count`.
  - `List<String> knowledgeAllTags(List<KnowledgeNote> notes)` — sorted unique tags.

- [ ] **Step 1: Write failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/knowledge/domain/entities/knowledge_note.dart';
import 'package:lexi_core/features/knowledge/domain/knowledge_filters.dart';

KnowledgeNote _n(String id, {
  String title = '', String explanation = '', String group = 'en_other',
  CEFRLevel? level, List<String> tags = const [],
}) {
  final t = DateTime.utc(2026, 1, 1);
  return KnowledgeNote(
    id: id, title: title, summary: '', explanation: explanation, groupId: group,
    tags: tags, cefrLevel: level, targetLanguage: Language.english,
    origin: KnowledgeNoteOrigin.manual, createdAt: t, updatedAt: t,
  );
}

void main() {
  final notes = [
    _n('a', title: 'Câu điều kiện loại 2', group: 'en_conditionals', level: CEFRLevel.b1, tags: ['toeic']),
    _n('b', title: 'Thì hiện tại đơn', group: 'en_tenses', level: CEFRLevel.a1),
    _n('c', explanation: 'nói về **điều kiện** trong quá khứ', group: 'en_conditionals', level: CEFRLevel.b2),
  ];

  test('query matches folded across fields', () {
    final r = applyKnowledgeFilter(notes,
        const KnowledgeFilter(query: 'dieu kien'));
    expect(r.map((n) => n.id), containsAll(['a', 'c']));
  });

  test('group + level filters AND across, OR within', () {
    final r = applyKnowledgeFilter(notes, const KnowledgeFilter(
      groupIds: {'en_conditionals'}, levels: {CEFRLevel.b1},
    ));
    expect(r.map((n) => n.id), ['a']);
  });

  test('tag filter', () {
    final r = applyKnowledgeFilter(notes, const KnowledgeFilter(tags: {'toeic'}));
    expect(r.map((n) => n.id), ['a']);
  });

  test('group counts and all tags', () {
    expect(knowledgeGroupCounts(notes)['en_conditionals'], 2);
    expect(knowledgeAllTags(notes), ['toeic']);
  });
}
```

- [ ] **Step 2: Run tests, verify they fail**

Run: `flutter test test/features/knowledge/domain/knowledge_filters_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

```dart
// lib/features/knowledge/domain/knowledge_filters.dart
import '../../../core/utils/text_normalize.dart';
import '../../vocabulary/domain/entities/cefr_level.dart';
import 'entities/knowledge_note.dart';

class KnowledgeFilter {
  const KnowledgeFilter({
    this.query = '',
    this.groupIds = const {},
    this.levels = const {},
    this.tags = const {},
  });

  final String query;
  final Set<String> groupIds;
  final Set<CEFRLevel> levels;
  final Set<String> tags;

  bool get isActive =>
      query.trim().isNotEmpty ||
      groupIds.isNotEmpty ||
      levels.isNotEmpty ||
      tags.isNotEmpty;

  KnowledgeFilter copyWith({
    String? query,
    Set<String>? groupIds,
    Set<CEFRLevel>? levels,
    Set<String>? tags,
  }) =>
      KnowledgeFilter(
        query: query ?? this.query,
        groupIds: groupIds ?? this.groupIds,
        levels: levels ?? this.levels,
        tags: tags ?? this.tags,
      );
}

List<KnowledgeNote> applyKnowledgeFilter(
  List<KnowledgeNote> notes,
  KnowledgeFilter filter,
) {
  final q = normalizeForSearch(filter.query);
  return notes.where((n) {
    if (filter.groupIds.isNotEmpty && !filter.groupIds.contains(n.groupId)) {
      return false;
    }
    if (filter.levels.isNotEmpty &&
        (n.cefrLevel == null || !filter.levels.contains(n.cefrLevel))) {
      return false;
    }
    if (filter.tags.isNotEmpty && !n.tags.any(filter.tags.contains)) {
      return false;
    }
    if (q.isNotEmpty) {
      final hay = normalizeForSearch([
        n.title,
        n.summary,
        n.explanation,
        n.patterns.join(' '),
        n.pitfalls.join(' '),
        n.tags.join(' '),
      ].join(' '));
      if (!hay.contains(q)) return false;
    }
    return true;
  }).toList();
}

Map<String, int> knowledgeGroupCounts(List<KnowledgeNote> notes) {
  final counts = <String, int>{};
  for (final n in notes) {
    counts[n.groupId] = (counts[n.groupId] ?? 0) + 1;
  }
  return counts;
}

List<String> knowledgeAllTags(List<KnowledgeNote> notes) =>
    (notes.expand((n) => n.tags).toSet().toList()..sort());
```

- [ ] **Step 4: Run tests, verify they pass**

Run: `flutter test test/features/knowledge/domain/knowledge_filters_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: `flutter analyze` + commit**

```bash
flutter analyze
git add lib/features/knowledge/domain/knowledge_filters.dart test/features/knowledge/domain/knowledge_filters_test.dart
git commit -m "feat(knowledge): pure search/filter/group-count helpers"
```

---

## Task 11: `KnowledgeEditScreen` — shared write / edit / review form

**Files:**
- Create: `lib/features/knowledge/presentation/screens/knowledge_edit_screen.dart`
- Test: `test/features/knowledge/presentation/screens/knowledge_edit_screen_test.dart`

**Interfaces:**
- Consumes: `knowledgeNotesNotifierProvider` (Task 9), `userSettingsNotifierProvider` (targetLanguage), `knowledgeGroupsFor` (Task 4), `showSingleSelectSheet` / `SelectOption` (`lib/core/widgets/selection_sheets.dart`), Bloom widgets (`BloomScaffold`, `BloomAppBar`, `BloomTextField`, `BloomSectionHeader`, `BloomPillButton`, `BloomIconButton`, `BloomChip`).
- Produces: `KnowledgeEditScreen({ KnowledgeNote? initial, KnowledgeNoteDraft? draft, String? overwriteNoteId })` — a `ConsumerStatefulWidget`.
  - Exactly one of `initial` (edit existing) / `draft` (review AI) / neither (blank new). `overwriteNoteId` set → Save writes that id (the "Bổ sung" path).
  - Fields: title, summary, explanation (multiline, hint `"bọc **...**  để in đậm"`), patterns (add/remove rows), examples (add/remove `{text, translation}` row pairs), pitfalls (add/remove rows), group (required, `showSingleSelectSheet` over `knowledgeGroupsFor(language)`), CEFR (optional, `showSingleSelectSheet` with a "Không đặt" entry), tags (chips + a text field to add).
  - Save builds a `KnowledgeNote`:
    - id: `overwriteNoteId ?? initial?.id ?? const Uuid().v4()`.
    - origin: `initial?.origin` if editing; `manual` if blank-new; `ai` if from draft; if `overwriteNoteId` targeted a `starter` note, becomes `ai` (draft) / keep for a plain edit.
    - `createdAt`: preserve when editing/overwriting an existing note (look it up from the notifier's current list), else `DateTime.now()`. `updatedAt`: `DateTime.now()`.
    - `sourcePrompt`: `draft`-flow passes the request text in via a `sourcePrompt` constructor arg — add `String? sourcePrompt` to the widget.
  - Calls `ref.read(knowledgeNotesNotifierProvider.notifier).saveNote(note)` then `context.pop()` (or `context.go('/knowledge/note/{id}')`).
  - Validation: empty title or no group → inline error, no save.

- [ ] **Step 1: Write failing widget test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lexi_core/core/theme/app_theme.dart';
import 'package:lexi_core/features/knowledge/data/sources/knowledge_note_source.dart';
import 'package:lexi_core/features/knowledge/presentation/providers/knowledge_notes_provider.dart';
import 'package:lexi_core/features/knowledge/presentation/screens/knowledge_edit_screen.dart';
// + the fakes from Task 9's test (extract them to test/features/knowledge/_fakes.dart in Step 1 of THIS task and import from both).

void main() {
  testWidgets('review-draft mode pre-fills the form and saves an ai note',
      (tester) async {
    final svc = FakeKnowledgeService();
    const draft = KnowledgeNoteDraft(
      title: 'Câu điều kiện loại 2', summary: 'S', explanation: 'E',
      suggestedGroupId: 'en_conditionals',
    );
    await tester.pumpWidget(ProviderScope(
      overrides: knowledgeTestOverrides(svc),
      child: MaterialApp(
        theme: AppTheme.light,
        home: const KnowledgeEditScreen(draft: draft, sourcePrompt: 'loại 2'),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Câu điều kiện loại 2'), findsOneWidget);

    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(svc.store.single.origin.name, 'ai');
    expect(svc.store.single.groupId, 'en_conditionals');
    expect(svc.store.single.sourcePrompt, 'loại 2');
  });

  testWidgets('blank-new with empty title shows a validation error', (tester) async {
    final svc = FakeKnowledgeService();
    await tester.pumpWidget(ProviderScope(
      overrides: knowledgeTestOverrides(svc),
      child: MaterialApp(theme: AppTheme.light, home: const KnowledgeEditScreen()),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(svc.store, isEmpty);
    expect(find.textContaining('Nhập tiêu đề'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Extract shared test fakes**

Create `test/features/knowledge/_fakes.dart` holding `FakeKnowledgeService` (implements `KnowledgeNotesService`), `FakeSettings`, and `List<Override> knowledgeTestOverrides(FakeKnowledgeService, {Language language})`. Update Task 9's test to import these instead of its local copies (keep Task 9's test green).

- [ ] **Step 3: Run test, verify it fails**

Run: `flutter test test/features/knowledge/presentation/screens/knowledge_edit_screen_test.dart`
Expected: FAIL — screen not found.

- [ ] **Step 4: Implement the screen**

Follow the field/layout conventions of `lib/features/dictionary/presentation/widgets/save_vocab_sheet.dart` (add/remove example rows, `BloomSectionHeader`, `BloomTextField`, `BloomIconButton(icon: Icons.close)` to remove a row). Group/CEFR pickers use `showSingleSelectSheet`. Skeleton:

```dart
// lib/features/knowledge/presentation/screens/knowledge_edit_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/bloom/bloom.dart';
import '../../../../core/widgets/selection_sheets.dart';
import '../../../dictionary/presentation/providers/user_settings_provider.dart';
import '../../../vocabulary/domain/entities/cefr_level.dart';
import '../../data/sources/knowledge_note_source.dart';
import '../../domain/entities/knowledge_group.dart';
import '../../domain/entities/knowledge_note.dart';
import '../providers/knowledge_notes_provider.dart';

class KnowledgeEditScreen extends ConsumerStatefulWidget {
  const KnowledgeEditScreen({
    super.key,
    this.initial,
    this.draft,
    this.overwriteNoteId,
    this.sourcePrompt,
  });

  final KnowledgeNote? initial;
  final KnowledgeNoteDraft? draft;
  final String? overwriteNoteId;
  final String? sourcePrompt;

  @override
  ConsumerState<KnowledgeEditScreen> createState() => _KnowledgeEditScreenState();
}

class _KnowledgeEditScreenState extends ConsumerState<KnowledgeEditScreen> {
  late final TextEditingController _title;
  late final TextEditingController _summary;
  late final TextEditingController _explanation;
  late List<TextEditingController> _patterns;
  late List<(TextEditingController, TextEditingController)> _examples;
  late List<TextEditingController> _pitfalls;
  final _tagInput = TextEditingController();
  String? _groupId;
  CEFRLevel? _cefr;
  late List<String> _tags;
  String? _error;

  @override
  void initState() {
    super.initState();
    final d = widget.draft;
    final n = widget.initial;
    _title = TextEditingController(text: n?.title ?? d?.title ?? '');
    _summary = TextEditingController(text: n?.summary ?? d?.summary ?? '');
    _explanation =
        TextEditingController(text: n?.explanation ?? d?.explanation ?? '');
    _patterns = [
      for (final p in n?.patterns ?? d?.patterns ?? const <String>[])
        TextEditingController(text: p),
    ];
    _examples = [
      for (final e in n?.examples ?? d?.examples ?? const <KnowledgeExample>[])
        (
          TextEditingController(text: e.text),
          TextEditingController(text: e.translation)
        ),
    ];
    _pitfalls = [
      for (final p in n?.pitfalls ?? d?.pitfalls ?? const <String>[])
        TextEditingController(text: p),
    ];
    _groupId = n?.groupId ?? d?.suggestedGroupId;
    _cefr = n?.cefrLevel ?? d?.suggestedCefr;
    _tags = [...?n?.tags, ...?d?.suggestedTags];
  }

  // dispose all controllers ...

  Future<void> _save() async {
    final language =
        ref.read(userSettingsNotifierProvider.select((s) => s.targetLanguage));
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Nhập tiêu đề cho ghi chú.');
      return;
    }
    if (_groupId == null) {
      setState(() => _error = 'Chọn một nhóm.');
      return;
    }
    final existing = ref
        .read(knowledgeNotesNotifierProvider)
        .valueOrNull
        ?.where((x) =>
            x.id == (widget.overwriteNoteId ?? widget.initial?.id))
        .firstOrNull;
    final now = DateTime.now();
    final origin = widget.draft != null
        ? KnowledgeNoteOrigin.ai
        : (existing?.origin ?? KnowledgeNoteOrigin.manual);
    final note = KnowledgeNote(
      id: widget.overwriteNoteId ?? widget.initial?.id ?? const Uuid().v4(),
      title: _title.text.trim(),
      summary: _summary.text.trim(),
      explanation: _explanation.text.trim(),
      patterns: _patterns.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList(),
      examples: _examples
          .map((e) => KnowledgeExample(
              text: e.$1.text.trim(), translation: e.$2.text.trim()))
          .where((e) => e.text.isNotEmpty || e.translation.isNotEmpty)
          .toList(),
      pitfalls: _pitfalls.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList(),
      groupId: _groupId!,
      tags: _tags,
      cefrLevel: _cefr,
      targetLanguage: language,
      origin: origin,
      sourcePrompt: widget.sourcePrompt ?? existing?.sourcePrompt,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    await ref.read(knowledgeNotesNotifierProvider.notifier).saveNote(note);
    if (mounted) context.go('/knowledge/note/${note.id}');
  }

  @override
  Widget build(BuildContext context) {
    final language =
        ref.watch(userSettingsNotifierProvider.select((s) => s.targetLanguage));
    final groups = knowledgeGroupsFor(language);
    // BloomScaffold + BloomAppBar(title: widget.initial == null ? 'Ghi chú mới' : 'Sửa ghi chú')
    // ListView with the field sections; bottom BloomPillButton(label: 'Lưu', onPressed: _save)
    // Group tile: shows knowledgeGroupLabel(_groupId) / 'Chưa chọn', onTap → showSingleSelectSheet
    //   options: groups.map((g) => SelectOption(value: g.id, label: g.label))
    // CEFR tile similar, options: [SelectOption(value: null, label: 'Không đặt'), ...CEFRLevel.values]
    // if (_error != null) a red Text above the save button
    throw UnimplementedError('fill in the build body per the notes above');
  }
}
```

Fill in the `build` body (roughly 120 lines) following `save_vocab_sheet.dart`'s structure. Keep it a normal scrolling screen (not a sheet).

- [ ] **Step 5: Run test, verify it passes**

Run: `flutter test test/features/knowledge/presentation/screens/knowledge_edit_screen_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 6: `flutter analyze` + commit**

```bash
flutter analyze
git add lib/features/knowledge/presentation/screens/knowledge_edit_screen.dart test/features/knowledge
git commit -m "feat(knowledge): KnowledgeEditScreen (shared write/edit/review form)"
```

---

## Task 12: `KnowledgeDetailScreen` + `KnowledgeGroupScreen` + `KnowledgeNoteRow`

**Files:**
- Create: `lib/features/knowledge/presentation/widgets/knowledge_note_row.dart`
- Create: `lib/features/knowledge/presentation/screens/knowledge_detail_screen.dart`
- Create: `lib/features/knowledge/presentation/screens/knowledge_group_screen.dart`
- Test: `test/features/knowledge/presentation/screens/knowledge_detail_screen_test.dart`
- Test: `test/features/knowledge/presentation/screens/knowledge_group_screen_test.dart`

**Interfaces:**
- Consumes: `knowledgeNotesNotifierProvider`, `BoldText` / `HighlightedText` (Task 3), `knowledgeGroupLabel`, Bloom widgets, `CEFRLevel`, `vocabBankNotifierProvider` (for example highlighting — read `.valueOrNull` headwords for the active language; if unavailable, pass `[]`).
- Produces:
  - `KnowledgeNoteRow({ required KnowledgeNote note, VoidCallback? onTap })` — a `BloomCard`/`BloomListRow`: title (w700), summary (1–2 lines, ellipsis), a chip row `[knowledgeGroupLabel(note.groupId)] [note.cefrLevel?.label]` and a small "Mẫu" chip when `note.origin == starter`.
  - `KnowledgeDetailScreen({ required String id })` — watches the notifier list, finds the note by id (if missing → "Không tìm thấy ghi chú" + back). Renders sections per spec §4.3. AppBar actions: edit (`context.go('/knowledge/note/$id/edit')`), delete (confirm `AlertDialog` → `deleteNote(id)` → `context.go('/knowledge')`).
  - `KnowledgeGroupScreen({ required String groupId })` — watches the notifier list filtered to `groupId`, groups by `cefrLevel` into sections A1→C2 then "Chưa gắn cấp độ", each section a `BloomSectionHeader` + `KnowledgeNoteRow`s.

- [ ] **Step 1: Write failing widget tests**

```dart
// knowledge_detail_screen_test.dart — key assertions
testWidgets('renders sections and hides empty ones', (tester) async {
  final svc = FakeKnowledgeService()
    ..store.add(noteFixture(
      id: 'n1', title: 'Câu điều kiện loại 2',
      explanation: 'Dùng **were**.', patterns: ['If ...'],
      examples: [], pitfalls: [],
    ));
  await pumpDetail(tester, svc, id: 'n1'); // helper wiring GoRouter + ProviderScope
  expect(find.text('Câu điều kiện loại 2'), findsOneWidget);
  expect(find.text('Mẫu câu'), findsOneWidget);          // patterns present
  expect(find.text('Lỗi thường gặp'), findsNothing);     // pitfalls empty
});

testWidgets('delete asks for confirmation then removes', (tester) async {
  final svc = FakeKnowledgeService()..store.add(noteFixture(id: 'n1'));
  await pumpDetail(tester, svc, id: 'n1');
  await tester.tap(find.byIcon(Icons.delete_outline));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Xoá'));
  await tester.pumpAndSettle();
  expect(svc.store, isEmpty);
});

// knowledge_group_screen_test.dart
testWidgets('sections notes by CEFR', (tester) async {
  final svc = FakeKnowledgeService()..store.addAll([
    noteFixture(id: 'a', group: 'en_tenses', level: CEFRLevel.a1),
    noteFixture(id: 'b', group: 'en_tenses', level: CEFRLevel.b2),
    noteFixture(id: 'c', group: 'en_tenses', level: null),
  ]);
  await pumpGroup(tester, svc, groupId: 'en_tenses');
  expect(find.text('A1'), findsOneWidget);
  expect(find.text('B2'), findsOneWidget);
  expect(find.text('Chưa gắn cấp độ'), findsOneWidget);
});
```

Add `noteFixture(...)` + `pumpDetail` / `pumpGroup` helpers to `test/features/knowledge/_fakes.dart`. `pumpDetail`/`pumpGroup` build a minimal `GoRouter` with just the route under test plus `/knowledge` and `/knowledge/note/:id/edit` stubs so `context.go` calls don't throw.

- [ ] **Step 2: Run tests, verify they fail**

Run: `flutter test test/features/knowledge/presentation/screens/knowledge_detail_screen_test.dart test/features/knowledge/presentation/screens/knowledge_group_screen_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement the three files**

`knowledge_note_row.dart`: a `BloomCard` with an `InkWell`, `Column` of `Text(note.title, w700)`, `Text(note.summary, maxLines: 2, overflow: ellipsis)`, and a `Wrap` of `BloomChip`s.

`knowledge_group_screen.dart`:

```dart
final notes = ref.watch(knowledgeNotesNotifierProvider).valueOrNull ?? [];
final inGroup = notes.where((n) => n.groupId == widget.groupId).toList();
// sections: for each CEFRLevel in order + a null bucket, filter inGroup,
// skip empty, render BloomSectionHeader(level?.label ?? 'Chưa gắn cấp độ')
// then the rows.
```

`knowledge_detail_screen.dart`: watch the list, `firstWhereOrNull((n) => n.id == widget.id)`. Render:
- `Text(note.title, style 22/w800)`
- `Text(note.summary)`
- `BoldText(source: note.explanation)`
- if patterns: `BloomSectionHeader('Mẫu câu')` + each in a monospace `Text`
- if examples: `BloomSectionHeader('Ví dụ')` + for each, `HighlightedText(text: ex.text, highlights: knownHeadwords)` over `Text(ex.translation, italic, inkSoft)`
- if pitfalls: `BloomSectionHeader('Lỗi thường gặp')` + `BoldText` per item
- chip row: group label, CEFR, tags, "Mẫu" if starter
- AppBar: `BloomIconButton(Icons.edit_outlined ...)`, `BloomIconButton(Icons.delete_outline ...)`

- [ ] **Step 4: Run tests, verify they pass**

Run: `flutter test test/features/knowledge/presentation/screens/`
Expected: PASS.

- [ ] **Step 5: `flutter analyze` + commit**

```bash
flutter analyze
git add lib/features/knowledge/presentation test/features/knowledge
git commit -m "feat(knowledge): detail + group screens + note row"
```

---

## Task 13: `KnowledgeHomeScreen` — group grid + search + tags

**Files:**
- Create: `lib/features/knowledge/presentation/screens/knowledge_home_screen.dart`
- Test: `test/features/knowledge/presentation/screens/knowledge_home_screen_test.dart`

**Interfaces:**
- Consumes: `knowledgeNotesNotifierProvider`, `userSettingsNotifierProvider` (targetLanguage), `knowledgeGroupsFor` + `knowledgeGroupCounts` + `knowledgeAllTags` (Tasks 4, 10), `applyKnowledgeFilter` + `KnowledgeFilter` (Task 10), `KnowledgeNoteRow` (Task 12), Bloom widgets.
- Produces: `KnowledgeHomeScreen` — `ConsumerStatefulWidget` holding a local `KnowledgeFilter` in state (search text + selected tags; group/CEFR filters are reachable from within a group screen, so Home only needs query + tags).
  - `BloomScaffold` + `BloomAppBar(title: 'Kiến thức', actions: [overflow menu])`.
  - Overflow menu: "Khôi phục ghi chú mẫu" — visible only when `knowledgeGroupsFor(language)` has a starter set (English; check via a const `_hasStarter(language) => language == Language.english`). Calls `notifier.restoreStarters()` + a snackbar.
  - Body when search empty: search `BloomTextField` → tag chip `Wrap` (from `knowledgeAllTags`, toggles filter) → a grid (`GridView` / `Wrap` of cards) of `knowledgeGroupsFor(language)` each showing label + count (`knowledgeGroupCounts`), tap → `context.go('/knowledge/group/${g.id}')`. Empty groups render dimmed.
  - Body when search non-empty OR tags selected: a flat `ListView` of `KnowledgeNoteRow`s from `applyKnowledgeFilter(allNotes, filter)`, tap → `context.go('/knowledge/note/${n.id}')`.
  - Two FAB-ish actions (a `Row` of `BloomPillButton`s pinned bottom, or a `BloomAppBar` action): "Nhờ AI soạn" → opens `KnowledgeAiRequestSheet` (Task 14); "Tự viết" → `context.go('/knowledge/new')`.
  - Empty state (notes list empty after seeding): centered text + example prompts + "Nhờ AI soạn" button.

- [ ] **Step 1: Write failing widget test**

```dart
testWidgets('shows a group grid with counts', (tester) async {
  final svc = FakeKnowledgeService()..store.addAll([
    noteFixture(id: 'a', group: 'en_tenses'),
    noteFixture(id: 'b', group: 'en_tenses'),
    noteFixture(id: 'c', group: 'en_conditionals'),
  ]);
  await pumpHome(tester, svc);
  expect(find.text('Thì'), findsOneWidget);
  expect(find.text('2'), findsWidgets); // count badge
});

testWidgets('typing in search switches to a flat result list', (tester) async {
  final svc = FakeKnowledgeService()..store.addAll([
    noteFixture(id: 'a', title: 'Câu điều kiện loại 2'),
    noteFixture(id: 'b', title: 'Thì hiện tại đơn'),
  ]);
  await pumpHome(tester, svc);
  await tester.enterText(find.byType(TextField).first, 'dieu kien');
  await tester.pumpAndSettle();
  expect(find.text('Câu điều kiện loại 2'), findsOneWidget);
  expect(find.text('Thì hiện tại đơn'), findsNothing);
});

testWidgets('Khôi phục ghi chú mẫu calls restoreStarters', (tester) async {
  final svc = FakeKnowledgeService();
  await pumpHome(tester, svc);
  await tester.tap(find.byIcon(Icons.more_vert));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Khôi phục ghi chú mẫu'));
  await tester.pumpAndSettle();
  expect(svc.restoreCalls, 1);
});
```

Add `restoreCalls` counter to `FakeKnowledgeService` and a `pumpHome` helper.

- [ ] **Step 2: Run test, verify it fails**

Run: `flutter test test/features/knowledge/presentation/screens/knowledge_home_screen_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

Follow `word_radar_screen.dart` and `vocab_bank_screen.dart` for the search-field + chip-row + list patterns. ~180 lines.

- [ ] **Step 4: Run test, verify it passes**

Run: `flutter test test/features/knowledge/presentation/screens/knowledge_home_screen_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: `flutter analyze` + commit**

```bash
flutter analyze
git add lib/features/knowledge/presentation/screens/knowledge_home_screen.dart test/features/knowledge
git commit -m "feat(knowledge): KnowledgeHomeScreen (group grid + search + tags)"
```

---

## Task 14: "Nhờ AI soạn" flow — draft notifier + request sheet + related banner

**Files:**
- Create: `lib/features/knowledge/presentation/providers/knowledge_draft_provider.dart`
- Create: `lib/features/knowledge/presentation/widgets/knowledge_ai_request_sheet.dart`
- Create: `lib/features/knowledge/presentation/widgets/related_notes_banner.dart`
- Then: `dart run build_runner build --delete-conflicting-outputs`
- Test: `test/features/knowledge/presentation/providers/knowledge_draft_provider_test.dart`
- Test: `test/features/knowledge/presentation/widgets/knowledge_ai_request_sheet_test.dart`

**Interfaces:**
- Consumes: `generateKnowledgeNoteUseCaseProvider` (Task 8), `knowledgeNotesNotifierProvider` (Task 9), `findRelatedNotes` (Task 5), `userSettingsNotifierProvider` (targetLanguage, `aiAvailable`), `KnowledgeNoteDraft`.
- Produces:
  - `sealed class KnowledgeDraftState` with cases:
    - `KnowledgeDraftIdle()`
    - `KnowledgeDraftRelated(List<KnowledgeNote> related, String request, String? hintGroupId, CEFRLevel? hintCefr)` — Layer-1 hit, awaiting the user's Mở/Bổ sung/Tạo mới choice.
    - `KnowledgeDraftLoading()`
    - `KnowledgeDraftReady(KnowledgeNoteDraft draft, String request, String? overwriteNoteId, KnowledgeNote? layer2Related)` — go to the edit screen; if `layer2Related != null` show the banner again first.
    - `KnowledgeDraftError(String message)`
  - `KnowledgeDraftNotifier extends _$KnowledgeDraftNotifier`:
    - `KnowledgeDraftState build() => const KnowledgeDraftIdle();`
    - `Future<void> submit({required String request, String? hintGroupId, CEFRLevel? hintCefr})` — Layer 1: `findRelatedNotes(prompt: request, notes: <all notes for the language>)`. If non-empty → `KnowledgeDraftRelated`. Else → `_generate(request, hintGroupId, hintCefr, extendingNote: null, overwriteNoteId: null)`.
    - `Future<void> proceedNew()` — from `KnowledgeDraftRelated`, call `_generate(..., overwriteNoteId: null)`.
    - `Future<void> extend(KnowledgeNote note)` — from `KnowledgeDraftRelated`, `_generate(..., extendingNote: note, overwriteNoteId: note.id)`.
    - `void dismiss()` → `KnowledgeDraftIdle`.
    - private `_generate(...)` — set `KnowledgeDraftLoading`; `AsyncValue.guard` the use-case call; on success map to `KnowledgeDraftReady` with `layer2Related` resolved by matching `draft.relatedNoteId` against the current notes list (only when it wasn't already the `RelatedNotes` path); on failure → `KnowledgeDraftError`.
  - `KnowledgeAiRequestSheet` — a `showModalBottomSheet` body: request `BloomTextField` (multiline), optional group + CEFR pickers (`showSingleSelectSheet`), a "Soạn" button calling `notifier.submit(...)`. Listens to `KnowledgeDraftState`:
    - `Related` → renders `RelatedNotesBanner`
    - `Loading` → spinner
    - `Ready` → `Navigator.pop(context)` then `context.go` to the edit screen carrying the draft via `extra` (a small record `({KnowledgeNoteDraft draft, String request, String? overwriteNoteId})`), OR, when `layer2Related != null`, show the banner first.
    - `Error` → error text + retry
  - `RelatedNotesBanner({ required List<KnowledgeNote> related, required void Function() onProceedNew, required void Function(KnowledgeNote) onExtend, required void Function(KnowledgeNote) onOpen })` — "Bạn đã có N ghi chú liên quan" + a card per note with **Mở** / **Bổ sung vào ghi chú này**, and one shared **Vẫn tạo mới** button.

- [ ] **Step 1: Write failing tests**

```dart
// knowledge_draft_provider_test.dart
test('submit with a Layer-1 hit → Related state', () async {
  final svc = FakeKnowledgeService()
    ..store.add(noteFixture(id: 'a', title: 'Câu điều kiện loại 2'));
  final c = draftContainer(svc, useCase: _StubUseCase(_okDraft));
  await c.read(knowledgeNotesNotifierProvider.future);
  await c.read(knowledgeDraftNotifierProvider.notifier)
      .submit(request: 'giải thích câu điều kiện loại 2');
  expect(c.read(knowledgeDraftNotifierProvider), isA<KnowledgeDraftRelated>());
});

test('submit with no hit → Ready state, overwriteNoteId null', () async {
  final svc = FakeKnowledgeService();
  final c = draftContainer(svc, useCase: _StubUseCase(_okDraft));
  await c.read(knowledgeNotesNotifierProvider.future);
  await c.read(knowledgeDraftNotifierProvider.notifier)
      .submit(request: 'chủ đề hoàn toàn mới lạ');
  final s = c.read(knowledgeDraftNotifierProvider);
  expect(s, isA<KnowledgeDraftReady>());
  expect((s as KnowledgeDraftReady).overwriteNoteId, isNull);
});

test('extend(note) → Ready with overwriteNoteId == note.id', () async {
  final svc = FakeKnowledgeService()..store.add(noteFixture(id: 'a', title: 'Câu điều kiện loại 2'));
  final c = draftContainer(svc, useCase: _StubUseCase(_okDraft));
  await c.read(knowledgeNotesNotifierProvider.future);
  await c.read(knowledgeDraftNotifierProvider.notifier).submit(request: 'câu điều kiện loại 2');
  await c.read(knowledgeDraftNotifierProvider.notifier)
      .extend(svc.store.first);
  final s = c.read(knowledgeDraftNotifierProvider) as KnowledgeDraftReady;
  expect(s.overwriteNoteId, 'a');
});

test('use-case throwing → Error state', () async {
  final svc = FakeKnowledgeService();
  final c = draftContainer(svc, useCase: _ThrowingUseCase());
  await c.read(knowledgeNotesNotifierProvider.future);
  await c.read(knowledgeDraftNotifierProvider.notifier).submit(request: 'x y z mới');
  expect(c.read(knowledgeDraftNotifierProvider), isA<KnowledgeDraftError>());
});

test('Layer 2: draft.relatedNoteId matches a note → layer2Related set', () async {
  final svc = FakeKnowledgeService()..store.add(noteFixture(id: 'z', title: 'khác hẳn'));
  final c = draftContainer(svc, useCase: _StubUseCase(
    const KnowledgeNoteDraft(title: 'T', summary: 'S', explanation: 'E',
      relatedNoteId: 'z')));
  await c.read(knowledgeNotesNotifierProvider.future);
  await c.read(knowledgeDraftNotifierProvider.notifier).submit(request: 'chủ đề mới toanh');
  final s = c.read(knowledgeDraftNotifierProvider) as KnowledgeDraftReady;
  expect(s.layer2Related?.id, 'z');
});
```

`_StubUseCase` / `_ThrowingUseCase` implement `GenerateKnowledgeNoteUseCase`. `draftContainer` overrides `generateKnowledgeNoteUseCaseProvider` + the knowledge service + settings.

- [ ] **Step 2: Run tests, verify they fail**

Run: `flutter test test/features/knowledge/presentation/providers/knowledge_draft_provider_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement `knowledge_draft_provider.dart`**

```dart
// lib/features/knowledge/presentation/providers/knowledge_draft_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/di/app_providers.dart';
import '../../../dictionary/presentation/providers/user_settings_provider.dart';
import '../../../vocabulary/domain/entities/cefr_level.dart';
import '../../data/sources/knowledge_note_source.dart';
import '../../domain/entities/knowledge_note.dart';
import '../../domain/knowledge_dedup.dart';
import 'knowledge_notes_provider.dart';

part 'knowledge_draft_provider.g.dart';

sealed class KnowledgeDraftState {
  const KnowledgeDraftState();
}
class KnowledgeDraftIdle extends KnowledgeDraftState {
  const KnowledgeDraftIdle();
}
class KnowledgeDraftRelated extends KnowledgeDraftState {
  const KnowledgeDraftRelated(
      this.related, this.request, this.hintGroupId, this.hintCefr);
  final List<KnowledgeNote> related;
  final String request;
  final String? hintGroupId;
  final CEFRLevel? hintCefr;
}
class KnowledgeDraftLoading extends KnowledgeDraftState {
  const KnowledgeDraftLoading();
}
class KnowledgeDraftReady extends KnowledgeDraftState {
  const KnowledgeDraftReady(
      this.draft, this.request, this.overwriteNoteId, this.layer2Related);
  final KnowledgeNoteDraft draft;
  final String request;
  final String? overwriteNoteId;
  final KnowledgeNote? layer2Related;
}
class KnowledgeDraftError extends KnowledgeDraftState {
  const KnowledgeDraftError(this.message);
  final String message;
}

@riverpod
class KnowledgeDraftNotifier extends _$KnowledgeDraftNotifier {
  @override
  KnowledgeDraftState build() => const KnowledgeDraftIdle();

  List<KnowledgeNote> get _notes =>
      ref.read(knowledgeNotesNotifierProvider).valueOrNull ?? const [];

  Future<void> submit({
    required String request,
    String? hintGroupId,
    CEFRLevel? hintCefr,
  }) async {
    final related = findRelatedNotes(prompt: request, notes: _notes);
    if (related.isNotEmpty) {
      state = KnowledgeDraftRelated(related, request, hintGroupId, hintCefr);
      return;
    }
    await _generate(
      request: request,
      hintGroupId: hintGroupId,
      hintCefr: hintCefr,
      extendingNote: null,
      overwriteNoteId: null,
      resolveLayer2: true,
    );
  }

  Future<void> proceedNew() async {
    final s = state;
    if (s is! KnowledgeDraftRelated) return;
    await _generate(
      request: s.request,
      hintGroupId: s.hintGroupId,
      hintCefr: s.hintCefr,
      extendingNote: null,
      overwriteNoteId: null,
      resolveLayer2: false, // user already saw the banner
    );
  }

  Future<void> extend(KnowledgeNote note) async {
    final s = state;
    final request = s is KnowledgeDraftRelated ? s.request : '';
    await _generate(
      request: request,
      hintGroupId: s is KnowledgeDraftRelated ? s.hintGroupId : null,
      hintCefr: s is KnowledgeDraftRelated ? s.hintCefr : null,
      extendingNote: note,
      overwriteNoteId: note.id,
      resolveLayer2: false,
    );
  }

  void dismiss() => state = const KnowledgeDraftIdle();

  Future<void> _generate({
    required String request,
    required String? hintGroupId,
    required CEFRLevel? hintCefr,
    required KnowledgeNote? extendingNote,
    required String? overwriteNoteId,
    required bool resolveLayer2,
  }) async {
    state = const KnowledgeDraftLoading();
    final language = ref.read(
      userSettingsNotifierProvider.select((s) => s.targetLanguage),
    );
    final scope = _notes
        .where((n) => n.groupId == (hintGroupId ?? extendingNote?.groupId) ||
            hintGroupId == null)
        .toList();
    try {
      final draft = await ref.read(generateKnowledgeNoteUseCaseProvider).execute(
            request: request,
            targetLanguage: language,
            hintGroupId: hintGroupId,
            hintCefr: hintCefr,
            existingInScope: scope,
            extendingNote: extendingNote,
          );
      KnowledgeNote? layer2;
      if (resolveLayer2 && draft.relatedNoteId != null) {
        layer2 = _notes
            .where((n) => n.id == draft.relatedNoteId)
            .cast<KnowledgeNote?>()
            .firstOrNull;
      }
      state = KnowledgeDraftReady(draft, request, overwriteNoteId, layer2);
    } catch (_) {
      state = const KnowledgeDraftError('Không tạo được ghi chú. Thử lại.');
    }
  }
}
```

- [ ] **Step 4: Implement `related_notes_banner.dart` + `knowledge_ai_request_sheet.dart`**

`related_notes_banner.dart` — a `BloomCard` per note, `Text(note.title)`, a `Row` of `BloomPillButton(label: 'Mở', variant: link)` + `BloomPillButton(label: 'Bổ sung vào ghi chú này')`, then a single `BloomPillButton(label: 'Vẫn tạo mới')` below the list.

`knowledge_ai_request_sheet.dart` — `showKnowledgeAiRequestSheet(BuildContext)` opening a `DraggableScrollableSheet`. A `Consumer` watches `knowledgeDraftNotifierProvider`. Use `ref.listen` to react to `KnowledgeDraftReady`: pop the sheet, then `context.go('/knowledge/new', extra: (draft: s.draft, request: s.request, overwriteNoteId: s.overwriteNoteId))` — unless `s.layer2Related != null`, in which case swap the body to a `RelatedNotesBanner` for that single note (Mở → go to it; Bổ sung → `notifier.extend`; Vẫn tạo mới → navigate with the draft as-is).

> The edit screen (Task 11) is reached at `/knowledge/new` with `extra` carrying the draft record, and at `/knowledge/note/:id/edit` with no extra (loads `initial` from the notifier). Task 15 wires both routes. When `extra` is the draft record, `KnowledgeEditScreen(draft: extra.draft, overwriteNoteId: extra.overwriteNoteId, sourcePrompt: extra.request)`.

- [ ] **Step 5: request-sheet widget test**

```dart
testWidgets('Related banner: "Vẫn tạo mới" triggers generation', (tester) async {
  final svc = FakeKnowledgeService()..store.add(noteFixture(id: 'a', title: 'Câu điều kiện loại 2'));
  final c = ... _StubUseCase(_okDraft);
  await pumpRequestSheet(tester, svc, useCase: ...);
  await tester.enterText(find.byType(TextField).first, 'câu điều kiện loại 2');
  await tester.tap(find.text('Soạn'));
  await tester.pumpAndSettle();
  expect(find.textContaining('ghi chú liên quan'), findsOneWidget);
  await tester.tap(find.text('Vẫn tạo mới'));
  await tester.pumpAndSettle();
  // navigation stub records the pushed location + extra
  expect(lastPushedLocation, '/knowledge/new');
});
```

- [ ] **Step 6: Regenerate, run all knowledge tests**

Run: `dart run build_runner build --delete-conflicting-outputs`
Run: `flutter test test/features/knowledge/`
Expected: PASS.

- [ ] **Step 7: `flutter analyze` + commit**

```bash
flutter analyze
git add lib/features/knowledge test/features/knowledge
git commit -m "feat(knowledge): Nhờ AI soạn flow (draft notifier + request sheet + related banner)"
```

---

## Task 15: Wire routes, hub card, and the AI-sheet entry point

**Files:**
- Modify: `lib/core/router/app_router.dart`
- Modify: `lib/features/practice/presentation/screens/practice_hub_screen.dart`
- Test: `test/core/router/knowledge_routes_test.dart`
- Test: update `test/features/practice/presentation/screens/practice_hub_screen_test.dart` (if it exists) or add coverage.

**Interfaces:**
- Consumes: all knowledge screens; the draft `extra` record type from Task 14.
- Produces: routes `/knowledge`, `/knowledge/new`, `/knowledge/group/:groupId`, `/knowledge/note/:id`, `/knowledge/note/:id/edit`.

- [ ] **Step 1: Write failing tests**

```dart
// knowledge_routes_test.dart — pump appRouter-like GoRouter with the knowledge
// subtree, navigate to each path, assert the right screen type shows.
testWidgets('/knowledge shows KnowledgeHomeScreen', (tester) async { ... });
testWidgets('/knowledge/group/en_tenses shows KnowledgeGroupScreen', (tester) async { ... });
testWidgets('/knowledge/note/x shows KnowledgeDetailScreen', (tester) async { ... });
```

```dart
// practice hub: the card is present and navigates
testWidgets('Kiến thức card navigates to /knowledge', (tester) async {
  // pump PracticeHubScreen inside a GoRouter with a /knowledge stub,
  // tap 'Kiến thức', expect location == '/knowledge'
});
```

- [ ] **Step 2: Run tests, verify they fail**

- [ ] **Step 3: Add routes to `app_router.dart`**

Inside the `ShellRoute` `routes:` list (e.g. after the `/progress` route), add:

```dart
GoRoute(
  path: '/knowledge',
  builder: (context, state) => const KnowledgeHomeScreen(),
  routes: [
    GoRoute(
      path: 'new',
      builder: (context, state) {
        final extra = state.extra;
        if (extra is ({KnowledgeNoteDraft draft, String request, String? overwriteNoteId})) {
          return KnowledgeEditScreen(
            draft: extra.draft,
            overwriteNoteId: extra.overwriteNoteId,
            sourcePrompt: extra.request,
          );
        }
        return const KnowledgeEditScreen();
      },
    ),
    GoRoute(
      path: 'group/:groupId',
      builder: (context, state) =>
          KnowledgeGroupScreen(groupId: state.pathParameters['groupId']!),
    ),
    GoRoute(
      path: 'note/:id',
      builder: (context, state) =>
          KnowledgeDetailScreen(id: state.pathParameters['id']!),
      routes: [
        GoRoute(
          path: 'edit',
          builder: (context, state) =>
              KnowledgeEditScreen(id: state.pathParameters['id']!),
        ),
      ],
    ),
  ],
),
```

> `KnowledgeEditScreen` needs an `id`-based constructor variant too (loads `initial` from the notifier). Add `this.id` to the widget; in `initState`, if `id != null && initial == null`, look the note up from `ref.read(knowledgeNotesNotifierProvider).valueOrNull` (post-frame or in `build`). Simpler: make the `/knowledge/note/:id/edit` builder read the note synchronously via a `Consumer` and pass `initial:`. Pick whichever keeps Task 11's tests green; update Task 11's interface note accordingly.

Add the imports for the 4 screens at the top of `app_router.dart`.

- [ ] **Step 4: Add the hub card**

In `practice_hub_screen.dart`, after the "Quét từ vựng" `BloomNavCard`:

```dart
const SizedBox(height: 12),
BloomNavCard(
  icon: Icons.auto_stories_outlined,
  title: 'Kiến thức',
  subtitle: 'Thư viện ngữ pháp & cấu trúc câu theo ngôn ngữ — tự viết hoặc nhờ AI soạn.',
  onTap: () => context.go('/knowledge'),
),
```

- [ ] **Step 5: Run tests, verify they pass**

Run: `flutter test test/core/router/knowledge_routes_test.dart test/features/practice/`
Expected: PASS.

- [ ] **Step 6: Full suite + analyze + commit**

```bash
flutter analyze
flutter test
git add lib/core/router/app_router.dart lib/features/practice/presentation/screens/practice_hub_screen.dart test/
git commit -m "feat(knowledge): wire routes + Luyện tập hub card"
```

Expected: all tests green, count ≥ baseline + the new knowledge tests.

---

## Task 16: Fill the English starter library (all 12 notes)

**Files:**
- Modify: `assets/knowledge/starter_en.json` (expand from 2 to 12 entries)
- Test: extend `test/features/knowledge/data/knowledge_starter_library_test.dart`

**Interfaces:** none — data only.

- [ ] **Step 1: Write the failing assertion**

Add to the starter-library test:

```dart
test('English starter set has all 12 spec ids in valid groups', () async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final notes = await KnowledgeStarterLibrary().notesFor(Language.english);
  const expectedIds = {
    'starter_en_tenses_overview', 'starter_en_present_simple',
    'starter_en_present_continuous', 'starter_en_present_simple_vs_continuous',
    'starter_en_past_simple', 'starter_en_present_perfect',
    'starter_en_present_perfect_vs_past', 'starter_en_future_forms',
    'starter_en_conditionals_0_1', 'starter_en_conditionals_2_3',
    'starter_en_articles', 'starter_en_comparatives_superlatives',
  };
  expect(notes.map((n) => n.id).toSet(), expectedIds);
  final validGroups = knowledgeGroupsFor(Language.english).map((g) => g.id).toSet();
  for (final n in notes) {
    expect(validGroups, contains(n.groupId), reason: n.id);
    expect(n.summary, isNotEmpty, reason: n.id);
    expect(n.explanation, isNotEmpty, reason: n.id);
    expect(n.examples.length, greaterThanOrEqualTo(2), reason: n.id);
  }
});
```

- [ ] **Step 2: Run it, verify it fails** (only 2 ids present)

- [ ] **Step 3: Author the remaining 10 notes**

Per spec §8.5 — ids/titles/groups/CEFR from the table. Each entry (JSON object in the array) must have: `id`, `title`, `summary`, `explanation` (with `**bold**` on key terms, `\n\n` paragraphs), `patterns` (2–4), `examples` (3–5 `{text, translation}` with Vietnamese translations), `pitfalls` (2–3), `groupId`, `tags` (`["ngu-phap-co-ban"]` plus 0–1 more), `cefrLevel`, `targetLanguage: "english"`, `source: "starter"`, `sourcePrompt: null`, `createdAt`/`updatedAt`: `"2026-09-07T00:00:00.000Z"`.

Group mapping (from spec §8.5): `starter_en_articles` → `en_articles_nouns`; `starter_en_comparatives_superlatives` → `en_articles_nouns`; `starter_en_conditionals_0_1` and `_2_3` → `en_conditionals`; the eight tense notes → `en_tenses`.

Write real, correct grammar content in Vietnamese — this is user-facing reference material. Keep each `explanation` to 2–4 short paragraphs.

- [ ] **Step 4: Run the test, verify it passes**

Run: `flutter test test/features/knowledge/data/knowledge_starter_library_test.dart`
Expected: PASS.

- [ ] **Step 5: Manual smoke (optional but recommended)**

Run the app signed in on a fresh test account, open Luyện tập → Kiến thức with target language English, confirm the 12 notes appear grouped, delete one, use "Khôi phục ghi chú mẫu", confirm it returns.

- [ ] **Step 6: Commit**

```bash
git add assets/knowledge/starter_en.json test/features/knowledge/data/knowledge_starter_library_test.dart
git commit -m "feat(knowledge): full English starter library (12 notes)"
```

---

## Task 17: Docs + final verification

**Files:**
- Modify: `README.md`
- Modify: `.superpowers/sdd/progress.md` (append a line if the file tracks features this way — check its format first)
- Modify: `CLAUDE.md` (only if a Knowledge-specific gotcha emerged; otherwise skip)

- [ ] **Step 1: README — feature section**

Under `## Tính năng`, after "Quét từ vựng", add a "### Kiến thức (Knowledge Notes)" section describing: per-language fixed group taxonomy + free tags; hand-written or AI-drafted structured notes (title/summary/explanation with `**đậm**`/patterns/examples song ngữ/pitfalls); two-layer duplicate check; English starter library seeded per account with "Khôi phục ghi chú mẫu"; search + filter mirroring Vocab Bank; Firestore `users/{uid}/knowledge_notes` shared-shape with web (web UI lands in a follow-up). Reference-only (no SM-2).

- [ ] **Step 2: README — Firestore structure block**

Add under `users/{uid}/`:

```
    knowledge_notes/
      {id}/
        id, title, summary, explanation, patterns[], examples[{text,translation}],
        pitfalls[], groupId, tags[], cefrLevel, targetLanguage,
        source (ai|manual|starter), sourcePrompt, createdAt, updatedAt
    knowledge_meta/
      seed/
        english: bool   # per-language starter-seed guard
```

- [ ] **Step 3: README — Roadmap**

Add a ticked entry: `- [x] **Kiến thức** — thư viện ghi chú ngữ pháp/cấu trúc câu theo ngôn ngữ, tự viết hoặc AI soạn, có bộ mẫu tiếng Anh (app Flutter; web theo sau)`.

- [ ] **Step 4: Full verification**

```bash
flutter analyze
flutter test
```

Expected: `No issues found!` and `All tests passed!` with a count of at least the baseline + ~40 new knowledge tests. Record the exact number in the commit message.

- [ ] **Step 5: Commit**

```bash
git add README.md .superpowers/sdd/progress.md
git commit -m "docs(knowledge): README feature + Firestore structure + roadmap"
```

---

## Self-Review (completed while writing — notes for the implementer)

**Spec coverage:**

| Spec section | Task(s) |
|---|---|
| §1 scope (reference-only, Flutter+web, Firestore-only) | Global Constraints; Task 6 |
| §2 data model | Task 4 (entity), Task 6 (persistence), Global Constraints (field formats) |
| §2 seeded flag doc | Task 6 |
| §3 per-language taxonomy | Task 4 |
| §4.1 home screen | Task 13 |
| §4.2 group screen | Task 12 |
| §4.3 detail screen | Task 12 |
| §4.4 edit screen | Task 11 |
| §5.1 AI flow steps | Task 14 |
| §5.2 Layer-1 tokeniser | Task 1 (normalize) + Task 5 (scoring) |
| §5.3 error handling | Task 7 (source throws) + Task 14 (Error state) |
| §6 `**bold**` parser + shared vectors | Task 2, Task 3 (render) |
| §7 search & filters | Task 10 (pure) + Task 13 (UI) |
| §8.1 starter JSON source | Task 6 (loader) + Task 16 (content) |
| §8.2 lazy per-language seeding | Task 6 |
| §8.3 "Khôi phục ghi chú mẫu" | Task 6 (`restoreStarters`) + Task 13 (menu) |
| §8.5 the 12 English notes | Task 16 |
| §10 out-of-scope | respected (no SM-2 provider, no versioning, no markdown lib) |

**Open items carried forward (spec §11):**

- Web starter-JSON + parser-vector sharing mechanism → the **Web plan** decides; this plan just puts the files at stable paths (`assets/knowledge/starter_en.json`, `test/fixtures/bold_markup_vectors.json`).
- Hub card is a 4th card in an existing `ListView` — no layout change needed (verified: `practice_hub_screen.dart` is a plain `ListView`).
- Stopword list / threshold → start as written in Task 5, tune if noisy.
- The 12 starter notes' exact prose → authored in Task 16, needs a human read-through (Step 5 of that task).

**Type-consistency check:** `KnowledgeNote` / `KnowledgeExample` / `KnowledgeNoteDraft` / `KnowledgeFilter` / `KnowledgeDraftState` names and their fields are used identically across Tasks 4–15. `KnowledgeNoteOrigin` (`ai`/`manual`/`starter`) round-trips the `source` string field. `knowledgeNotesNotifierProvider` / `knowledgeDraftNotifierProvider` / `knowledgeNotesServiceProvider` / `generateKnowledgeNoteUseCaseProvider` are the provider names throughout.

**Known deviation from spec wording:** spec §4.4 says the edit screen takes `initial` / `draft` / neither; the router also needs an `id`-loaded variant for `/knowledge/note/:id/edit` — Task 15 Step 3 resolves this by reading the note in the route builder and passing `initial:` (no new constructor shape). If a `Consumer` in the builder is awkward, add `String? id` to the widget instead; either is fine, pick one and keep tests green.

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-09-07-knowledge-notes-flutter.md`. Two execution options:**

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints.

**Which approach?**
