# Knowledge Notes ("Kiến thức") — Web Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port the "Kiến thức" (Knowledge Notes) reference-library feature to the React web app (`apps/web/`), reading/writing the same Firestore collection the Flutter app already writes so a note created on either platform opens on the other.

**Architecture:** Mirror the Flutter feature (shipped `docs/superpowers/plans/2026-09-07-knowledge-notes-flutter.md`, commits `1c10f35..d270504` on master). Web has no Riverpod — plain React hooks + client-side Firestore via the Firebase JS SDK, exactly like `src/lib/vocabRecords.ts` / `src/lib/savedReadingExercises.ts`. Pure logic (search normalisation, `**bold**` parser, taxonomy, dedup, filters, AI prompt/parse) is ported 1:1 as testable `src/lib/*.ts` modules; the `**bold**` parser reuses the **same** `test/fixtures/bold_markup_vectors.json` the Flutter test uses; the starter library is a committed copy of `assets/knowledge/starter_en.json` guarded by a drift test. UI is Next.js app-router pages under `src/app/(app)/knowledge/` + components under `src/components/knowledge/`.

**Tech Stack:** Next.js 16 (app router — **read `apps/web/AGENTS.md` first, this is a non-standard Next.js build**), React 19, Firebase JS SDK 12 (`firebase/firestore`), TypeScript, Vitest 4 + `@testing-library/react` + jsdom. No new dependencies.

## Global Constraints

- **Same Firestore collections as Flutter:** `users/{uid}/knowledge_notes/{id}` and `users/{uid}/knowledge_meta/seed`. No security-rules change (covered by `users/{uid}/{document=**}`).
- **Doc shape is fixed and shared** — every field name, type, and serialisation must match `lib/features/knowledge/domain/entities/knowledge_note.dart`'s `toJson()`:
  `id, title, summary, explanation, patterns: string[], examples: {text,translation}[], pitfalls: string[], groupId, tags: string[], cefrLevel: "a1".."c2" | null, targetLanguage: "english"|"chinese"|"korean"|"japanese"|"vietnamese", source: "ai"|"manual"|"starter", sourcePrompt: string | null, createdAt: ISO-8601 string, updatedAt: ISO-8601 string`.
- **`id` is duplicated into the doc body** (`setDoc(ref, { ...record, id: ref.id })`), matching `vocabRecords.ts` / `savedReadingExercises.ts`.
- **Timestamps written as `new Date().toISOString()`** (matches `savedReadingExercises.ts`). Parse defensively — accept an ISO string, a Firestore `Timestamp`, or an epoch-millis number (the Flutter client may write any; see Flutter whole-branch fix #4).
- **`cefrLevel` lowercase or `null`.** `groupId` stable keys (`en_tenses`, …).
- **No version history, no SM-2, no user-created groups. Markup is only `\n\n` + `**bold**`. English-only starter library.**
- **Writes throw; reads/seeding are best-effort** (matches the Flutter whole-branch fix: `upsertKnowledgeNote`/`deleteKnowledgeNote` propagate errors so the UI can show a failure; `getKnowledgeNotes`/`seedStartersIfNeeded`/`restoreStarters` swallow and return a safe default; `getKnowledgeNotes` skips an undecodable doc rather than returning nothing).
- **AI availability** = `Boolean(settings.providers[settings.activeProvider].apiKeyCiphertext)` — the web idiom (there is no `aiAvailable` field; see `word-radar/page.tsx:49-50`). The AI compose flow must gate on it and show a "no API key" hint linking to Settings, like `word-radar/page.tsx:108-112`.
- **All LLM calls go through `generateContent()` (`src/lib/generateContent.ts`)** with `{ provider, model, apiKeyCiphertext, prompt }`, then `parseAiJsonObject()` (`src/lib/parseAiJson.ts`). Pure `buildXPrompt` + `parseXSet` split, tested without the network — exactly like `src/lib/part5.ts` + `part5.test.ts`.
- Vietnamese UI copy throughout.
- Every task ends: `npm run typecheck` clean + `npm test` green + a commit. Run commands from `apps/web/`. **Baseline: 804 tests pass** (occasionally 1 flakes on an async media test — re-run once before assuming a regression; a real drop is `< 804 + your new tests`).
- Path alias `@/*` → `apps/web/src/*` (`tsconfig.json`, `vitest.config.mts`). `apps/web/tsconfig.json` already has `strict: true`, `moduleResolution: "bundler"`, `resolveJsonModule: true`, `jsx: "react-jsx"` — no tsconfig change needed for the JSON import in Task 6.
- **No dynamic routes exist in `apps/web/src/app/` yet** — Task 11 is the first. Resolve the Next 16 `params` API (Promise vs plain object; `use(params)` vs `await`) against `apps/web/AGENTS.md` + `node_modules/next/dist/docs/` before writing it.
- Firestore lib tests use `vi.mock("firebase/firestore", ...)` + `vi.mock("@/lib/firebase")` — see `src/lib/vocabRecords.test.ts:14-28` for the exact mock shape.

---

## File Structure

**Create — `src/lib/` (pure + Firestore, each with a sibling `.test.ts`):**

| Path | Responsibility |
|---|---|
| `src/lib/normalizeSearch.ts` | `normalizeForSearch(s)` — port of `lib/core/utils/text_normalize.dart`: lowercase, fold Vietnamese diacritics (+ `đ→d`), non-`[a-z0-9]`→space, collapse, trim. |
| `src/lib/boldMarkup.ts` | `TextRun { text; bold }`, `parseBoldMarkup(s): TextRun[][]` — port of `lib/core/utils/bold_markup.dart`. |
| `src/lib/knowledgeGroups.ts` | `KnowledgeGroup { id; label }`, `knowledgeGroupsFor(lang)`, `knowledgeGroupLabel(id)`, `knowledgeOtherGroupId(lang)` — port of `knowledge_group.dart` (spec §3 tables verbatim). |
| `src/lib/knowledgeNotes.ts` | `KnowledgeNote` type, `parseKnowledgeNote(raw): KnowledgeNote`, Firestore CRUD + seeding — port of `knowledge_notes_service.dart` (+ whole-branch fixes). |
| `src/lib/knowledgeStarters.ts` | `startersFor(lang): KnowledgeNote[]` — reads the committed `src/data/knowledge/starter_en.json`. |
| `src/lib/knowledgeDedup.ts` | `findRelatedNotes({ prompt, notes }): KnowledgeNote[]` — port of `knowledge_dedup.dart` (incl. whole-branch fix: `thi`/`the` are NOT stopwords). |
| `src/lib/knowledgeFilters.ts` | `KnowledgeFilter`, `applyKnowledgeFilter`, `knowledgeGroupCounts`, `knowledgeAllTags` — port of `knowledge_filters.dart`. |
| `src/lib/knowledgeNoteSource.ts` | `KnowledgeNoteDraft` type, `buildKnowledgeNotePrompt(...)`, `parseKnowledgeNoteDraft(json)` — port of `knowledge_note_source.dart` (+ whole-branch fix #3: validate `suggestedGroupId`). |

**Create — data + components:**

| Path | Responsibility |
|---|---|
| `src/data/knowledge/starter_en.json` | Committed copy of repo-root `assets/knowledge/starter_en.json` (drift-guarded by a test). |
| `src/components/shared/BoldText.tsx` | Renders `parseBoldMarkup` output — one `<p>` per paragraph, `<strong>` for bold runs. |
| `src/components/knowledge/KnowledgeNoteCard.tsx` | List row: title, summary (2-line clamp), group + CEFR + "Mẫu" pills. |
| `src/components/knowledge/KnowledgeGroupGrid.tsx` | Grid of group cards with counts; empty groups dimmed. |
| `src/components/knowledge/KnowledgeNoteView.tsx` | Rendered note (sections gated on emptiness) + edit/delete actions. |
| `src/components/knowledge/EditKnowledgeNoteModal.tsx` | The shared write / edit / review-draft form — mirror `src/components/vocab-bank/EditVocabModal.tsx`. |
| `src/components/knowledge/RelatedNotesBanner.tsx` | "Bạn đã có N ghi chú liên quan" + per-note Mở / Bổ sung + shared Vẫn tạo mới. |
| `src/components/knowledge/AiComposeModal.tsx` | "Nhờ AI soạn" flow: request → dedup (Layer 1) → `generateContent` → Layer 2 → hand off to the edit form. Gates on API key. |

**Create — pages (`src/app/(app)/knowledge/`):**

| Path | Responsibility |
|---|---|
| `knowledge/page.tsx` | Home: group grid + search + tag chips + "Nhờ AI soạn" / "Tự viết". |
| `knowledge/group/[groupId]/page.tsx` | Notes in one group, sectioned by CEFR. |
| `knowledge/note/[id]/page.tsx` | Detail view. |
| `knowledge/note/[id]/edit/page.tsx` | Edit an existing note (opens `EditKnowledgeNoteModal` seeded from the loaded note). |
| `knowledge/new/page.tsx` | Blank "Tự viết" form. |

Each page gets a sibling `page.test.tsx` where the plan specifies one.

**Modify:**

| Path | Change |
|---|---|
| `src/components/shell/Sidebar.tsx` | Add a `{ label: "Kiến thức", items: [{ href: "/knowledge", label: "📖 Kiến thức" }] }` group (after "Quét từ"). |
| `src/styles/bloom.css` | Append a `/* Knowledge Notes */` block (class names introduced by the components). |
| `apps/web/src/data/` | New dir (holds `knowledge/starter_en.json`). |
| root `README.md` | One line under the web section noting the web UI now ships. |

**Shared-asset drift guards (test-only, no runtime coupling):**
- `src/lib/boldMarkup.test.ts` reads `../../../../test/fixtures/bold_markup_vectors.json` via `fs`/`path` (repo-root, 4 levels up from `src/lib/`).
- `src/data/knowledge/starter_en.json` has a sibling check in `src/lib/knowledgeStarters.test.ts` that `fs`-reads repo-root `assets/knowledge/starter_en.json` and asserts deep equality.

---

## Task 1: `normalizeForSearch` — port

**Files:**
- Create: `src/lib/normalizeSearch.ts`
- Test: `src/lib/normalizeSearch.test.ts`

**Interfaces:**
- Produces: `export function normalizeForSearch(input: string): string`

- [ ] **Step 1: Write the failing test**

```ts
import { describe, expect, it } from "vitest";
import { normalizeForSearch } from "./normalizeSearch";

describe("normalizeForSearch", () => {
  it("folds Vietnamese diacritics and đ", () => {
    expect(normalizeForSearch("Câu điều kiện")).toBe("cau dieu kien");
    expect(normalizeForSearch("ĐIỀU")).toBe("dieu");
  });
  it("lowercases, strips punctuation to spaces, collapses whitespace", () => {
    expect(normalizeForSearch("Present  Perfect!!  (tense)")).toBe("present perfect tense");
  });
  it("empty / punctuation-only input", () => {
    expect(normalizeForSearch("   ")).toBe("");
    expect(normalizeForSearch("***")).toBe("");
  });
  it("keeps digits", () => {
    expect(normalizeForSearch("loại 2 và 3")).toBe("loai 2 va 3");
  });
});
```

- [ ] **Step 2: Run, verify fail**

Run: `npm test -- normalizeSearch`
Expected: FAIL — module not found.

- [ ] **Step 3: Implement** (port of `lib/core/utils/text_normalize.dart`)

```ts
// src/lib/normalizeSearch.ts

// Vietnamese diacritic folding: each accented form → its base ASCII letter.
const DIACRITIC_FOLDS: Record<string, string> = {
  a: "áàảãạăắằẳẵặâấầẩẫậ",
  e: "éèẻẽẹêếềểễệ",
  i: "íìỉĩị",
  o: "óòỏõọôốồổỗộơớờởỡợ",
  u: "úùủũụưứừửữự",
  y: "ýỳỷỹỵ",
  d: "đ",
};

function foldChar(lower: string): string {
  for (const [base, accented] of Object.entries(DIACRITIC_FOLDS)) {
    if (accented.includes(lower)) return base;
  }
  return lower;
}

/**
 * Lowercase, fold Vietnamese diacritics (and đ→d), turn every non `[a-z0-9]`
 * char into a space, collapse whitespace, trim. Shared by the Knowledge
 * search box and the duplicate-check tokeniser so "câu điều kiện" and
 * "cau dieu kien" match. Port of lib/core/utils/text_normalize.dart.
 */
export function normalizeForSearch(input: string): string {
  let folded = "";
  for (const ch of input.toLowerCase()) {
    folded += foldChar(ch);
  }
  return folded.replace(/[^a-z0-9]+/g, " ").trim();
}
```

- [ ] **Step 4: Run, verify pass**

Run: `npm test -- normalizeSearch` → PASS (4). Then `npm run typecheck` → clean.

- [ ] **Step 5: Commit**

```bash
git add apps/web/src/lib/normalizeSearch.ts apps/web/src/lib/normalizeSearch.test.ts
git commit -m "feat(web/knowledge): normalizeForSearch port"
```

---

## Task 2: `parseBoldMarkup` — port, reusing the shared test vectors

**Files:**
- Create: `src/lib/boldMarkup.ts`
- Test: `src/lib/boldMarkup.test.ts`

**Interfaces:**
- Produces:
  - `export interface TextRun { text: string; bold: boolean }`
  - `export function parseBoldMarkup(source: string): TextRun[][]`

- [ ] **Step 1: Write the failing test (drives off the shared fixture)**

```ts
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";
import { parseBoldMarkup, type TextRun } from "./boldMarkup";

// The SAME fixture the Flutter test uses (test/fixtures/bold_markup_vectors.json).
// From apps/web/src/lib/ the repo root is 4 levels up.
const vectors = JSON.parse(
  readFileSync(resolve(__dirname, "../../../../test/fixtures/bold_markup_vectors.json"), "utf8"),
) as { name: string; in: string; out: { t: string; b: boolean }[][] }[];

function toRuns(out: { t: string; b: boolean }[][]): TextRun[][] {
  return out.map((para) => para.map((r) => ({ text: r.t, bold: r.b })));
}

describe("parseBoldMarkup — shared vectors", () => {
  for (const v of vectors) {
    it(`vector: ${v.name}`, () => {
      expect(parseBoldMarkup(v.in)).toEqual(toRuns(v.out));
    });
  }
});

describe("parseBoldMarkup — nested **", () => {
  it("treats an inner ** as a boundary (non-overlapping matches)", () => {
    expect(parseBoldMarkup("**a **b** c**")).toEqual([
      [
        { text: "a ", bold: true },
        { text: "b", bold: true },
        { text: " c**", bold: false },
      ],
    ]);
  });
});
```

- [ ] **Step 2: Run, verify fail** — `npm test -- boldMarkup` → module not found.

- [ ] **Step 3: Implement** (port of `lib/core/utils/bold_markup.dart`, matching the Flutter regex `/\*\*([^*]+?)\*\*/` exactly)

```ts
// src/lib/boldMarkup.ts

export interface TextRun {
  text: string;
  bold: boolean;
}

const BOLD_PATTERN = /\*\*([^*]+?)\*\*/g;

/**
 * Parses the app's tiny markup: `\n\n` splits paragraphs, `**x**` marks a
 * bold run. Everything else is literal — a lone `**` renders as the two
 * characters, `*`/`_`/`#` are plain text. No nesting, italics, links.
 * Port of lib/core/utils/bold_markup.dart — keep in exact sync (the shared
 * test vectors guard both).
 */
export function parseBoldMarkup(source: string): TextRun[][] {
  const paragraphs = source
    .split(/\n\n+/)
    .map((p) => p.trim())
    .filter((p) => p.length > 0);
  return paragraphs.map(runsForParagraph);
}

function runsForParagraph(para: string): TextRun[] {
  const runs: TextRun[] = [];
  let cursor = 0;
  BOLD_PATTERN.lastIndex = 0;
  let m: RegExpExecArray | null;
  while ((m = BOLD_PATTERN.exec(para)) !== null) {
    if (m.index > cursor) runs.push({ text: para.slice(cursor, m.index), bold: false });
    runs.push({ text: m[1], bold: true });
    cursor = m.index + m[0].length;
  }
  if (cursor < para.length) runs.push({ text: para.slice(cursor), bold: false });
  const nonEmpty = runs.filter((r) => r.bold || r.text.length > 0);
  return nonEmpty.length > 0 ? nonEmpty : [{ text: "", bold: false }];
}
```

- [ ] **Step 4: Run, verify pass** — all vectors + nested case. `npm run typecheck` clean.

- [ ] **Step 5: Commit**

```bash
git add apps/web/src/lib/boldMarkup.ts apps/web/src/lib/boldMarkup.test.ts
git commit -m "feat(web/knowledge): parseBoldMarkup port (shared test vectors)"
```

---

## Task 3: `BoldText` component

**Files:**
- Create: `src/components/shared/BoldText.tsx`
- Test: `src/components/shared/BoldText.test.tsx`

**Interfaces:**
- Consumes: `parseBoldMarkup`, `TextRun` (Task 2).
- Produces: `export function BoldText({ source }: { source: string }): JSX.Element` — a `<div className="bold-text">` containing one `<p>` per paragraph; bold runs wrapped in `<strong>`.

- [ ] **Step 1: Write the failing test**

```tsx
import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { BoldText } from "./BoldText";

describe("BoldText", () => {
  it("renders one <p> per paragraph", () => {
    const { container } = render(<BoldText source={"para **one**\n\npara two"} />);
    expect(container.querySelectorAll("p")).toHaveLength(2);
  });
  it("wraps bold runs in <strong>", () => {
    render(<BoldText source={"a **b** c"} />);
    expect(screen.getByText("b").tagName).toBe("STRONG");
  });
  it("renders nothing meaningful for empty source", () => {
    const { container } = render(<BoldText source="" />);
    expect(container.querySelectorAll("p")).toHaveLength(0);
  });
});
```

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement**

```tsx
// src/components/shared/BoldText.tsx
import { parseBoldMarkup } from "@/lib/boldMarkup";

export function BoldText({ source }: { source: string }) {
  const paragraphs = parseBoldMarkup(source);
  return (
    <div className="bold-text">
      {paragraphs.map((runs, i) => (
        <p key={i}>
          {runs.map((run, j) =>
            run.bold ? <strong key={j}>{run.text}</strong> : <span key={j}>{run.text}</span>,
          )}
        </p>
      ))}
    </div>
  );
}
```

- [ ] **Step 4: Run, verify pass.** `npm run typecheck` clean.

- [ ] **Step 5: Commit**

```bash
git add apps/web/src/components/shared/BoldText.tsx apps/web/src/components/shared/BoldText.test.tsx
git commit -m "feat(web/knowledge): BoldText render component"
```

---

## Task 4: `knowledgeGroups.ts` — taxonomy port

**Files:**
- Create: `src/lib/knowledgeGroups.ts`
- Test: `src/lib/knowledgeGroups.test.ts`

**Interfaces:**
- Consumes: `TargetLanguage` (`@/lib/languages`).
- Produces:
  - `export interface KnowledgeGroup { id: string; label: string }`
  - `export function knowledgeGroupsFor(language: TargetLanguage): KnowledgeGroup[]`
  - `export function knowledgeGroupLabel(groupId: string): string` (unknown id → the id itself)
  - `export function knowledgeOtherGroupId(language: TargetLanguage): string` (the language's `*_other` id)

- [ ] **Step 1: Write the failing test**

```ts
import { describe, expect, it } from "vitest";
import { knowledgeGroupsFor, knowledgeGroupLabel, knowledgeOtherGroupId } from "./knowledgeGroups";

describe("knowledgeGroups", () => {
  it("English taxonomy: 12 groups, first en_tenses, last en_other", () => {
    const ids = knowledgeGroupsFor("english").map((g) => g.id);
    expect(ids[0]).toBe("en_tenses");
    expect(ids[ids.length - 1]).toBe("en_other");
    expect(ids).toContain("en_conditionals");
    expect(ids).toHaveLength(12);
  });
  it("per-language sizes match the spec", () => {
    expect(knowledgeGroupsFor("english")).toHaveLength(12);
    expect(knowledgeGroupsFor("chinese")).toHaveLength(11);
    expect(knowledgeGroupsFor("korean")).toHaveLength(9);
    expect(knowledgeGroupsFor("japanese")).toHaveLength(9);
    expect(knowledgeGroupsFor("vietnamese")).toHaveLength(5);
  });
  it("every language ends with an _other group", () => {
    for (const l of ["english", "chinese", "korean", "japanese", "vietnamese"] as const) {
      const ids = knowledgeGroupsFor(l).map((g) => g.id);
      expect(ids[ids.length - 1]).toMatch(/_other$/);
      expect(ids[ids.length - 1]).toBe(knowledgeOtherGroupId(l));
    }
  });
  it("all group ids are globally unique", () => {
    const all = (["english", "chinese", "korean", "japanese", "vietnamese"] as const)
      .flatMap((l) => knowledgeGroupsFor(l).map((g) => g.id));
    expect(new Set(all).size).toBe(all.length);
  });
  it("label lookup resolves a known id, passes an unknown one through", () => {
    expect(knowledgeGroupLabel("en_tenses")).toBe("Thì");
    expect(knowledgeGroupLabel("nope_nope")).toBe("nope_nope");
  });
});
```

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement** — copy the tables verbatim from `lib/features/knowledge/domain/entities/knowledge_group.dart` (which matches spec §3). Keep the Vietnamese labels incl. CJK annotations exactly.

```ts
// src/lib/knowledgeGroups.ts
import type { TargetLanguage } from "./languages";

export interface KnowledgeGroup {
  id: string;
  label: string;
}

const EN: KnowledgeGroup[] = [
  { id: "en_tenses", label: "Thì" },
  { id: "en_conditionals", label: "Câu điều kiện" },
  { id: "en_relative_clauses", label: "Mệnh đề quan hệ" },
  { id: "en_passive", label: "Câu bị động" },
  { id: "en_reported_speech", label: "Câu tường thuật" },
  { id: "en_modals", label: "Động từ khuyết thiếu" },
  { id: "en_gerunds_infinitives", label: "Danh động từ & Nguyên mẫu" },
  { id: "en_articles_nouns", label: "Mạo từ & Danh từ" },
  { id: "en_prepositions", label: "Giới từ" },
  { id: "en_conjunctions_linking", label: "Liên từ & Nối câu" },
  { id: "en_spoken_structures", label: "Cấu trúc nói thông dụng" },
  { id: "en_other", label: "Khác" },
];

const ZH: KnowledgeGroup[] = [
  { id: "zh_aspect_particles", label: "Thể & Trợ từ động thái (了/着/过)" },
  { id: "zh_complements", label: "Bổ ngữ (kết quả/xu hướng/khả năng/mức độ)" },
  { id: "zh_ba", label: "Câu chữ 把" },
  { id: "zh_bei", label: "Câu chữ 被 (bị động)" },
  { id: "zh_measure_words", label: "Lượng từ" },
  { id: "zh_modal_particles", label: "Trợ từ ngữ khí (吗/呢/吧/啊)" },
  { id: "zh_comparison", label: "Cấu trúc so sánh (比/没有/一样)" },
  { id: "zh_conjunctions", label: "Liên từ & Phức câu" },
  { id: "zh_word_order", label: "Trật tự từ & Trạng ngữ" },
  { id: "zh_spoken_structures", label: "Cấu trúc nói thông dụng" },
  { id: "zh_other", label: "Khác" },
];

const KO: KnowledgeGroup[] = [
  { id: "ko_particles", label: "Trợ từ (조사)" },
  { id: "ko_endings_honorifics", label: "Đuôi câu & Kính ngữ (존댓말/반말)" },
  { id: "ko_tense_aspect", label: "Thì & Thể" },
  { id: "ko_clause_connectors", label: "Liên kết vế câu (연결어미)" },
  { id: "ko_modifiers", label: "Định ngữ (관형사형)" },
  { id: "ko_grammar_patterns", label: "Mẫu ngữ pháp thông dụng" },
  { id: "ko_irregulars", label: "Bất quy tắc (불규칙 활용)" },
  { id: "ko_spoken_structures", label: "Cấu trúc nói thông dụng" },
  { id: "ko_other", label: "Khác" },
];

const JA: KnowledgeGroup[] = [
  { id: "ja_particles", label: "Trợ từ (助詞)" },
  { id: "ja_verb_forms", label: "Chia động từ (辞書形/て形/た形…)" },
  { id: "ja_politeness_keigo", label: "Thể lịch sự & Kính ngữ (敬語)" },
  { id: "ja_tense_aspect", label: "Thì & Thể" },
  { id: "ja_connectors", label: "Liên kết câu (接続)" },
  { id: "ja_grammar_patterns", label: "Mẫu ngữ pháp (文型)" },
  { id: "ja_voice", label: "Khả năng / Bị động / Sai khiến" },
  { id: "ja_spoken_structures", label: "Cấu trúc nói thông dụng" },
  { id: "ja_other", label: "Khác" },
];

const VI: KnowledgeGroup[] = [
  { id: "vi_sentence_structure", label: "Cấu trúc câu" },
  { id: "vi_word_classes", label: "Từ loại & chức năng" },
  { id: "vi_linking", label: "Liên kết câu" },
  { id: "vi_spoken_structures", label: "Cấu trúc nói thông dụng" },
  { id: "vi_other", label: "Khác" },
];

const BY_LANGUAGE: Record<TargetLanguage, KnowledgeGroup[]> = {
  english: EN,
  chinese: ZH,
  korean: KO,
  japanese: JA,
  vietnamese: VI,
};

export function knowledgeGroupsFor(language: TargetLanguage): KnowledgeGroup[] {
  return BY_LANGUAGE[language];
}

const LABEL_BY_ID: Record<string, string> = Object.fromEntries(
  [...EN, ...ZH, ...KO, ...JA, ...VI].map((g) => [g.id, g.label]),
);

export function knowledgeGroupLabel(groupId: string): string {
  return LABEL_BY_ID[groupId] ?? groupId;
}

export function knowledgeOtherGroupId(language: TargetLanguage): string {
  const groups = knowledgeGroupsFor(language);
  return groups[groups.length - 1].id;
}
```

- [ ] **Step 4: Run, verify pass. `npm run typecheck` clean.**

- [ ] **Step 5: Commit**

```bash
git add apps/web/src/lib/knowledgeGroups.ts apps/web/src/lib/knowledgeGroups.test.ts
git commit -m "feat(web/knowledge): per-language group taxonomy port"
```

---

## Task 5: `knowledgeNotes.ts` — types + parse + Firestore CRUD + seeding

**Files:**
- Create: `src/lib/knowledgeNotes.ts`
- Test: `src/lib/knowledgeNotes.test.ts`

**Interfaces:**
- Consumes: `getFirebaseDb` (`@/lib/firebase`), `TargetLanguage`, `Timestamp` type from `firebase/firestore`.
- Produces:
  - ```ts
    export interface KnowledgeExample { text: string; translation: string }
    export type KnowledgeNoteOrigin = "ai" | "manual" | "starter";
    export interface KnowledgeNote {
      id: string; title: string; summary: string; explanation: string;
      patterns: string[]; examples: KnowledgeExample[]; pitfalls: string[];
      groupId: string; tags: string[];
      cefrLevel: "a1" | "a2" | "b1" | "b2" | "c1" | "c2" | null;
      targetLanguage: TargetLanguage;
      source: KnowledgeNoteOrigin; sourcePrompt: string | null;
      createdAt: string; updatedAt: string;
    }
    export type NewKnowledgeNote = Omit<KnowledgeNote, "id">;
    ```
  - `export function parseKnowledgeNote(raw: unknown): KnowledgeNote` — defensive: missing arrays → `[]`; unknown `source` → `"manual"`; unknown `targetLanguage` → `"english"`; bad/absent `cefrLevel` → `null`; dates via `parseDate` (accepts ISO string / Firestore `Timestamp` / epoch-millis number; else → `new Date(0).toISOString()`).
  - `export async function getKnowledgeNotes(uid: string, language: TargetLanguage): Promise<KnowledgeNote[]>` — reads `users/{uid}/knowledge_notes`, filters `targetLanguage === language`, sorts `updatedAt` desc. Per-doc `try/catch` (skip a bad doc). Outer `try/catch` → `[]`.
  - `export async function upsertKnowledgeNote(uid: string, note: KnowledgeNote): Promise<void>` — `setDoc(doc(col, note.id), { ...note })`. **Throws** on failure.
  - `export async function deleteKnowledgeNote(uid: string, id: string): Promise<void>` — **Throws** on failure.
  - `export async function seedStartersIfNeeded(uid, language, starters: KnowledgeNote[]): Promise<KnowledgeNote[]>` — if the `knowledge_meta/seed` doc's `[language]` field is not `true` AND the collection has no notes for `language`: write every starter whose id is absent, set the flag, return what was written; if the language already has notes, set the flag and return `[]`. Best-effort (`try/catch` → `[]`).
  - `export async function restoreStarters(uid, language, starters: KnowledgeNote[]): Promise<KnowledgeNote[]>` — write only starters whose id is absent from the collection; never touch existing; return what was written. Best-effort.

- [ ] **Step 1: Write the failing test** — mirror `src/lib/vocabRecords.test.ts` mock style.

```ts
import { describe, expect, it, vi, beforeEach } from "vitest";
import { getDocs, setDoc, deleteDoc } from "firebase/firestore";
import {
  parseKnowledgeNote,
  getKnowledgeNotes,
  upsertKnowledgeNote,
  deleteKnowledgeNote,
  seedStartersIfNeeded,
  restoreStarters,
  type KnowledgeNote,
} from "./knowledgeNotes";

vi.mock("firebase/firestore", () => ({
  collection: vi.fn(() => "col"),
  doc: vi.fn((...args: unknown[]) => ({ id: args[args.length - 1] ?? "generated-id" })),
  getDoc: vi.fn(),
  getDocs: vi.fn(),
  setDoc: vi.fn(),
  deleteDoc: vi.fn(),
  query: vi.fn(() => "q"),
  where: vi.fn(() => "w"),
  Timestamp: class {
    constructor(private ms: number) {}
    toDate() { return new Date(this.ms); }
  },
}));
vi.mock("@/lib/firebase", () => ({ getFirebaseDb: vi.fn(() => "db") }));

const note = (over: Partial<KnowledgeNote> = {}): KnowledgeNote => ({
  id: "n1", title: "T", summary: "s", explanation: "e", patterns: [], examples: [],
  pitfalls: [], groupId: "en_other", tags: [], cefrLevel: null, targetLanguage: "english",
  source: "manual", sourcePrompt: null,
  createdAt: "2026-01-01T00:00:00.000Z", updatedAt: "2026-01-01T00:00:00.000Z", ...over,
});

function snap(docs: KnowledgeNote[]) {
  return { docs: docs.map((d) => ({ id: d.id, data: () => d })) };
}

beforeEach(() => vi.clearAllMocks());

describe("parseKnowledgeNote", () => {
  it("defends against missing arrays / unknown enums / a Timestamp date", async () => {
    const { Timestamp } = await import("firebase/firestore");
    const parsed = parseKnowledgeNote({
      id: "n2", title: "t", summary: "s", explanation: "e", groupId: "en_other",
      targetLanguage: "english", source: "weird", cefrLevel: "zz",
      createdAt: new (Timestamp as unknown as { new (n: number): unknown })(0),
      updatedAt: 1_700_000_000_000,
    });
    expect(parsed.patterns).toEqual([]);
    expect(parsed.examples).toEqual([]);
    expect(parsed.source).toBe("manual");
    expect(parsed.cefrLevel).toBeNull();
    expect(typeof parsed.createdAt).toBe("string");
    expect(typeof parsed.updatedAt).toBe("string");
  });
  it("null date → epoch string, does not throw", () => {
    const p = parseKnowledgeNote({ id: "n", title: "t", summary: "", explanation: "",
      groupId: "en_other", targetLanguage: "english", source: "manual", cefrLevel: null,
      createdAt: null, updatedAt: null });
    expect(p.createdAt).toBe(new Date(0).toISOString());
  });
});

describe("getKnowledgeNotes", () => {
  it("filters by language and sorts updatedAt desc", async () => {
    vi.mocked(getDocs).mockResolvedValue(snap([
      note({ id: "old", updatedAt: "2026-01-01T00:00:00.000Z" }),
      note({ id: "new", updatedAt: "2026-06-01T00:00:00.000Z" }),
      note({ id: "zh", targetLanguage: "chinese" }),
    ]) as never);
    const out = await getKnowledgeNotes("u", "english");
    expect(out.map((n) => n.id)).toEqual(["new", "old"]);
  });
  it("skips an undecodable doc, keeps the rest; returns [] on a getDocs throw", async () => {
    vi.mocked(getDocs).mockResolvedValueOnce({
      docs: [
        { id: "bad", data: () => ({ examples: "not-a-list", createdAt: {}, /* throws in parse */ }) },
        { id: "good", data: () => note({ id: "good" }) },
      ],
    } as never);
    const out = await getKnowledgeNotes("u", "english");
    expect(out.map((n) => n.id)).toEqual(["good"]);
    vi.mocked(getDocs).mockRejectedValueOnce(new Error("offline"));
    expect(await getKnowledgeNotes("u", "english")).toEqual([]);
  });
});

describe("writes throw", () => {
  it("upsert rejects when setDoc rejects", async () => {
    vi.mocked(setDoc).mockRejectedValueOnce(new Error("permission-denied"));
    await expect(upsertKnowledgeNote("u", note())).rejects.toThrow("permission-denied");
  });
  it("delete rejects when deleteDoc rejects", async () => {
    vi.mocked(deleteDoc).mockRejectedValueOnce(new Error("nope"));
    await expect(deleteKnowledgeNote("u", "n1")).rejects.toThrow("nope");
  });
});

describe("seeding", () => {
  it("seeds once, respects the flag, does not seed a non-empty language", async () => {
    const { getDoc } = await import("firebase/firestore");
    vi.mocked(getDoc).mockResolvedValue({ data: () => ({}) } as never); // flag not set
    vi.mocked(getDocs).mockResolvedValue(snap([]) as never); // empty collection
    const wrote = await seedStartersIfNeeded("u", "english", [note({ id: "starter_en_x" })]);
    expect(wrote.map((n) => n.id)).toEqual(["starter_en_x"]);

    vi.mocked(getDoc).mockResolvedValue({ data: () => ({ english: true }) } as never);
    expect(await seedStartersIfNeeded("u", "english", [note({ id: "starter_en_x" })])).toEqual([]);
  });
  it("restoreStarters writes only absent ids", async () => {
    vi.mocked(getDocs).mockResolvedValue(snap([note({ id: "starter_en_a", title: "EDIT" })]) as never);
    const wrote = await restoreStarters("u", "english", [
      note({ id: "starter_en_a" }), note({ id: "starter_en_b" }),
    ]);
    expect(wrote.map((n) => n.id)).toEqual(["starter_en_b"]);
  });
});
```

> The undecodable-doc test needs `parseKnowledgeNote` to actually throw on `{ examples: "not-a-list", createdAt: {} }` — make `parseDate` throw on an object it doesn't recognise (not the documented-fallback path; the fallback is for `null`/`undefined`/unparseable-string, an unexpected object type is a real decode failure). Confirm the two paths are distinct in your implementation and adjust the test's bad-doc shape to whatever reliably triggers the per-doc `catch`.

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement** — port of `lib/features/knowledge/data/knowledge_notes_service.dart` (post whole-branch-fix) + `knowledge_note.dart`'s `fromJson`.

```ts
// src/lib/knowledgeNotes.ts
import {
  collection, deleteDoc, doc, getDoc, getDocs, query, setDoc, where, Timestamp,
} from "firebase/firestore";
import { getFirebaseDb } from "./firebase";
import type { TargetLanguage } from "./languages";

export interface KnowledgeExample { text: string; translation: string }
export type KnowledgeNoteOrigin = "ai" | "manual" | "starter";
export type CefrLevel = "a1" | "a2" | "b1" | "b2" | "c1" | "c2";

export interface KnowledgeNote {
  id: string;
  title: string;
  summary: string;
  explanation: string;
  patterns: string[];
  examples: KnowledgeExample[];
  pitfalls: string[];
  groupId: string;
  tags: string[];
  cefrLevel: CefrLevel | null;
  targetLanguage: TargetLanguage;
  source: KnowledgeNoteOrigin;
  sourcePrompt: string | null;
  createdAt: string;
  updatedAt: string;
}
export type NewKnowledgeNote = Omit<KnowledgeNote, "id">;

const LANGUAGES: TargetLanguage[] = ["vietnamese", "english", "chinese", "korean", "japanese"];
const CEFRS: CefrLevel[] = ["a1", "a2", "b1", "b2", "c1", "c2"];
const ORIGINS: KnowledgeNoteOrigin[] = ["ai", "manual", "starter"];
const EPOCH = new Date(0).toISOString();

function strList(raw: unknown): string[] {
  return Array.isArray(raw) ? raw.filter((x): x is string => typeof x === "string") : [];
}

// ISO string | Firestore Timestamp | epoch-millis number → ISO string.
// null/undefined/unparsable → EPOCH (documented fallback). An unrecognised
// object THROWS so getKnowledgeNotes can skip that one doc.
function parseDate(raw: unknown): string {
  if (raw == null) return EPOCH;
  if (typeof raw === "string") {
    const t = Date.parse(raw);
    return Number.isNaN(t) ? EPOCH : new Date(t).toISOString();
  }
  if (typeof raw === "number") return new Date(raw).toISOString();
  if (raw instanceof Timestamp) return raw.toDate().toISOString();
  if (typeof raw === "object" && typeof (raw as { toDate?: unknown }).toDate === "function") {
    return (raw as { toDate(): Date }).toDate().toISOString();
  }
  throw new Error("knowledge note: unrecognised date value");
}

export function parseKnowledgeNote(raw: unknown): KnowledgeNote {
  const j = (raw ?? {}) as Record<string, unknown>;
  const lang = LANGUAGES.includes(j.targetLanguage as TargetLanguage)
    ? (j.targetLanguage as TargetLanguage)
    : "english";
  return {
    id: typeof j.id === "string" ? j.id : "",
    title: typeof j.title === "string" ? j.title : "",
    summary: typeof j.summary === "string" ? j.summary : "",
    explanation: typeof j.explanation === "string" ? j.explanation : "",
    patterns: strList(j.patterns),
    examples: Array.isArray(j.examples)
      ? j.examples
          .filter((e): e is Record<string, unknown> => typeof e === "object" && e !== null)
          .map((e) => ({
            text: typeof e.text === "string" ? e.text : "",
            translation: typeof e.translation === "string" ? e.translation : "",
          }))
      : [],
    pitfalls: strList(j.pitfalls),
    groupId: typeof j.groupId === "string" ? j.groupId : "",
    tags: strList(j.tags),
    cefrLevel: CEFRS.includes(j.cefrLevel as CefrLevel) ? (j.cefrLevel as CefrLevel) : null,
    targetLanguage: lang,
    source: ORIGINS.includes(j.source as KnowledgeNoteOrigin)
      ? (j.source as KnowledgeNoteOrigin)
      : "manual",
    sourcePrompt: typeof j.sourcePrompt === "string" ? j.sourcePrompt : null,
    createdAt: parseDate(j.createdAt),
    updatedAt: parseDate(j.updatedAt),
  };
}

function notesCol(uid: string) {
  return collection(getFirebaseDb(), "users", uid, "knowledge_notes");
}
function seedRef(uid: string) {
  return doc(getFirebaseDb(), "users", uid, "knowledge_meta", "seed");
}

export async function getKnowledgeNotes(
  uid: string,
  language: TargetLanguage,
): Promise<KnowledgeNote[]> {
  try {
    const snapshot = await getDocs(notesCol(uid));
    const notes: KnowledgeNote[] = [];
    for (const d of snapshot.docs) {
      try {
        const n = parseKnowledgeNote({ ...(d.data() as object), id: d.id });
        if (n.targetLanguage === language) notes.push(n);
      } catch {
        /* skip one undecodable doc */
      }
    }
    notes.sort((a, b) => (a.updatedAt < b.updatedAt ? 1 : a.updatedAt > b.updatedAt ? -1 : 0));
    return notes;
  } catch {
    return [];
  }
}

export async function upsertKnowledgeNote(uid: string, note: KnowledgeNote): Promise<void> {
  await setDoc(doc(notesCol(uid), note.id), { ...note });
}

export async function deleteKnowledgeNote(uid: string, id: string): Promise<void> {
  await deleteDoc(doc(notesCol(uid), id));
}

async function writeMissing(
  uid: string,
  language: TargetLanguage,
  starters: KnowledgeNote[],
): Promise<KnowledgeNote[]> {
  if (starters.length === 0) return [];
  const existing = new Set((await getDocs(notesCol(uid))).docs.map((d) => d.id));
  const toWrite = starters.filter((s) => !existing.has(s.id));
  for (const s of toWrite) await setDoc(doc(notesCol(uid), s.id), { ...s });
  return toWrite;
}

export async function seedStartersIfNeeded(
  uid: string,
  language: TargetLanguage,
  starters: KnowledgeNote[],
): Promise<KnowledgeNote[]> {
  try {
    const flag = (await getDoc(seedRef(uid))).data()?.[language] === true;
    if (flag) return [];
    const all = await getDocs(notesCol(uid));
    const hasForLang = all.docs.some((d) => (d.data() as { targetLanguage?: string }).targetLanguage === language);
    if (hasForLang) {
      await setDoc(seedRef(uid), { [language]: true }, { merge: true });
      return [];
    }
    const wrote = await writeMissing(uid, language, starters);
    await setDoc(seedRef(uid), { [language]: true }, { merge: true });
    return wrote;
  } catch {
    return [];
  }
}

export async function restoreStarters(
  uid: string,
  language: TargetLanguage,
  starters: KnowledgeNote[],
): Promise<KnowledgeNote[]> {
  try {
    return await writeMissing(uid, language, starters);
  } catch {
    return [];
  }
}
```

- [ ] **Step 4: Run, verify pass. `npm run typecheck` clean.**

- [ ] **Step 5: Commit**

```bash
git add apps/web/src/lib/knowledgeNotes.ts apps/web/src/lib/knowledgeNotes.test.ts
git commit -m "feat(web/knowledge): KnowledgeNote type + parse + Firestore CRUD + seeding"
```

---

## Task 6: `knowledgeStarters.ts` + committed starter JSON + drift guard

**Files:**
- Create: `src/data/knowledge/starter_en.json` (copy of repo-root `assets/knowledge/starter_en.json`)
- Create: `src/lib/knowledgeStarters.ts`
- Test: `src/lib/knowledgeStarters.test.ts`

**Interfaces:**
- Consumes: `parseKnowledgeNote`, `KnowledgeNote` (Task 5), `TargetLanguage`.
- Produces: `export function startersFor(language: TargetLanguage): KnowledgeNote[]` — English → the 12 parsed starter notes; every other language → `[]`.

- [ ] **Step 1: Copy the asset**

```bash
cp assets/knowledge/starter_en.json apps/web/src/data/knowledge/starter_en.json
```

- [ ] **Step 2: Write the failing test**

```ts
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";
import { startersFor } from "./knowledgeStarters";
import { knowledgeGroupsFor } from "./knowledgeGroups";

describe("knowledgeStarters", () => {
  it("English → 12 parsed starter notes in valid groups", () => {
    const notes = startersFor("english");
    expect(notes).toHaveLength(12);
    const valid = new Set(knowledgeGroupsFor("english").map((g) => g.id));
    for (const n of notes) {
      expect(n.source).toBe("starter");
      expect(valid.has(n.groupId)).toBe(true);
      expect(n.examples.length).toBeGreaterThanOrEqual(2);
    }
    expect(new Set(notes.map((n) => n.id)).size).toBe(12);
  });
  it("non-English → []", () => {
    expect(startersFor("chinese")).toEqual([]);
  });
  it("stays byte-identical to the Flutter source asset (drift guard)", () => {
    const web = readFileSync(resolve(__dirname, "../data/knowledge/starter_en.json"), "utf8");
    const flutter = readFileSync(
      resolve(__dirname, "../../../../assets/knowledge/starter_en.json"), "utf8",
    );
    expect(JSON.parse(web)).toEqual(JSON.parse(flutter));
  });
});
```

- [ ] **Step 3: Run, verify fail.**

- [ ] **Step 4: Implement**

```ts
// src/lib/knowledgeStarters.ts
import starterEn from "@/data/knowledge/starter_en.json";
import { parseKnowledgeNote, type KnowledgeNote } from "./knowledgeNotes";
import type { TargetLanguage } from "./languages";

const EN: KnowledgeNote[] = (starterEn as unknown[]).map(parseKnowledgeNote);

export function startersFor(language: TargetLanguage): KnowledgeNote[] {
  return language === "english" ? EN : [];
}
```

> If Next/TS complains about the JSON import, add `"resolveJsonModule": true` to `apps/web/tsconfig.json` (it's likely already on — check first).

- [ ] **Step 5: Run, verify pass. `npm run typecheck` clean.**

- [ ] **Step 6: Commit**

```bash
git add apps/web/src/data/knowledge/starter_en.json apps/web/src/lib/knowledgeStarters.ts apps/web/src/lib/knowledgeStarters.test.ts
git commit -m "feat(web/knowledge): starter library (copy of shared asset + drift guard)"
```

---

## Task 7: `knowledgeDedup.ts` — Layer-1 duplicate check port

**Files:**
- Create: `src/lib/knowledgeDedup.ts`
- Test: `src/lib/knowledgeDedup.test.ts`

**Interfaces:**
- Consumes: `normalizeForSearch` (Task 1), `KnowledgeNote` (Task 5), `knowledgeGroupLabel` (Task 4).
- Produces: `export function findRelatedNotes(args: { prompt: string; notes: KnowledgeNote[] }): KnowledgeNote[]` — notes scoring ≥ 3, highest first, max 3. Scoring per spec §5.2 (identical to `knowledge_dedup.dart` post whole-branch fix: `thi` / `the` are NOT stopwords).

- [ ] **Step 1: Write the failing test**

```ts
import { describe, expect, it } from "vitest";
import { findRelatedNotes } from "./knowledgeDedup";
import type { KnowledgeNote } from "./knowledgeNotes";

const n = (over: Partial<KnowledgeNote>): KnowledgeNote => ({
  id: "x", title: "", summary: "", explanation: "", patterns: [], examples: [], pitfalls: [],
  groupId: "en_other", tags: [], cefrLevel: null, targetLanguage: "english",
  source: "manual", sourcePrompt: null, createdAt: "2026-01-01T00:00:00.000Z",
  updatedAt: "2026-01-01T00:00:00.000Z", ...over,
});

describe("findRelatedNotes", () => {
  it("matches on a repeated phrase in the title", () => {
    const hits = findRelatedNotes({
      prompt: "giải thích câu điều kiện loại 2 khi nào dùng",
      notes: [n({ id: "a", title: "Câu điều kiện loại 2 và 3" }), n({ id: "b", title: "Mệnh đề quan hệ" })],
    });
    expect(hits.map((h) => h.id)).toEqual(["a"]);
  });
  it("matches cross-diacritic", () => {
    expect(findRelatedNotes({ prompt: "cau dieu kien loai 2", notes: [n({ id: "a", title: "Câu điều kiện loại 2" })] })
      .map((h) => h.id)).toEqual(["a"]);
  });
  it("tag exact match scores", () => {
    expect(findRelatedNotes({ prompt: "ôn toeic phần này", notes: [n({ id: "a", title: "Ghi chú", tags: ["toeic"] })] })
      .map((h) => h.id)).toEqual(["a"]);
  });
  it("thì / thể are content words (whole-branch fix)", () => {
    expect(findRelatedNotes({ prompt: "thì thể", notes: [n({ id: "a", title: "Thì thể" })] })
      .map((h) => h.id)).toEqual(["a"]);
  });
  it("below threshold → []", () => {
    expect(findRelatedNotes({ prompt: "hiện tại đơn", notes: [n({ id: "a", title: "Mệnh đề quan hệ" })] })).toEqual([]);
  });
  it("caps at 3, sorted by score desc", () => {
    const notes = ["hiện tại đơn", "hiện tại tiếp diễn", "hiện tại hoàn thành", "quá khứ đơn"]
      .map((t, i) => n({ id: String(i), title: t }));
    const hits = findRelatedNotes({ prompt: "hiện tại đơn giải thích", notes });
    expect(hits).toHaveLength(3);
    expect(hits[0].id).toBe("0");
  });
});
```

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement** — port of `lib/features/knowledge/domain/knowledge_dedup.dart` (post fix).

```ts
// src/lib/knowledgeDedup.ts
import { normalizeForSearch } from "./normalizeSearch";
import { knowledgeGroupLabel } from "./knowledgeGroups";
import type { KnowledgeNote } from "./knowledgeNotes";

// 'thi' / 'the' deliberately NOT here — see the Flutter whole-branch review.
const STOPWORDS = new Set([
  "va", "khi", "nao", "cho", "cua", "la", "cac", "mot", "voi",
  "dung", "giai", "thich", "vi", "du", "doi", "thuong", "cach", "nay",
  "a", "an", "and", "or", "when", "how", "what", "explain", "give", "example",
]);

function contentTokens(prompt: string): string[] {
  const norm = normalizeForSearch(prompt);
  if (!norm) return [];
  return norm.split(" ").filter((t) => t.length > 1 && !STOPWORDS.has(t));
}

function phrases(tokens: string[]): string[] {
  const out: string[] = [];
  for (let i = 0; i < tokens.length - 1; i++) {
    out.push(`${tokens[i]} ${tokens[i + 1]}`);
    if (i < tokens.length - 2) out.push(`${tokens[i]} ${tokens[i + 1]} ${tokens[i + 2]}`);
  }
  return out;
}

export function findRelatedNotes(args: { prompt: string; notes: KnowledgeNote[] }): KnowledgeNote[] {
  const tokens = contentTokens(args.prompt);
  if (tokens.length === 0) return [];
  const ph = phrases(tokens);
  const promptTerms = new Set([...tokens, ...ph]);

  const scored: { note: KnowledgeNote; score: number }[] = [];
  for (const note of args.notes) {
    const title = normalizeForSearch(note.title);
    const haystack = normalizeForSearch(
      [note.title, note.summary, note.tags.join(" "), knowledgeGroupLabel(note.groupId)].join(" "),
    );
    const noteTags = new Set(note.tags.map(normalizeForSearch));

    let score = 0;
    for (const p of ph) {
      if (haystack.includes(p)) {
        score += 3;
        if (title.includes(p)) score += 2;
      }
    }
    for (const term of promptTerms) if (noteTags.has(term)) score += 3;
    for (const t of tokens) if (haystack.includes(t)) score += 1;
    if (score >= 3) scored.push({ note, score });
  }
  scored.sort((a, b) => b.score - a.score);
  return scored.slice(0, 3).map((s) => s.note);
}
```

- [ ] **Step 4: Run, verify pass. `npm run typecheck` clean.**

- [ ] **Step 5: Commit**

```bash
git add apps/web/src/lib/knowledgeDedup.ts apps/web/src/lib/knowledgeDedup.test.ts
git commit -m "feat(web/knowledge): Layer-1 duplicate-check port"
```

---

## Task 8: `knowledgeFilters.ts` — search/filter/count port

**Files:**
- Create: `src/lib/knowledgeFilters.ts`
- Test: `src/lib/knowledgeFilters.test.ts`

**Interfaces:**
- Consumes: `normalizeForSearch` (Task 1), `KnowledgeNote` / `CefrLevel` (Task 5).
- Produces:
  - `export interface KnowledgeFilter { query: string; groupIds: Set<string>; levels: Set<CefrLevel>; tags: Set<string> }`
  - `export function applyKnowledgeFilter(notes: KnowledgeNote[], filter: KnowledgeFilter): KnowledgeNote[]` — group/level/tag AND-across / OR-within; empty set = no constraint; a non-empty `levels` rejects a `cefrLevel === null` note; `query` = folded substring over `title + summary + explanation + patterns + pitfalls + tags`.
  - `export function knowledgeGroupCounts(notes: KnowledgeNote[]): Record<string, number>`
  - `export function knowledgeAllTags(notes: KnowledgeNote[]): string[]` (sorted unique)

- [ ] **Step 1: Write the failing test**

```ts
import { describe, expect, it } from "vitest";
import { applyKnowledgeFilter, knowledgeGroupCounts, knowledgeAllTags, type KnowledgeFilter } from "./knowledgeFilters";
import type { KnowledgeNote } from "./knowledgeNotes";

const n = (over: Partial<KnowledgeNote>): KnowledgeNote => ({
  id: "x", title: "", summary: "", explanation: "", patterns: [], examples: [], pitfalls: [],
  groupId: "en_other", tags: [], cefrLevel: null, targetLanguage: "english", source: "manual",
  sourcePrompt: null, createdAt: "2026-01-01T00:00:00.000Z", updatedAt: "2026-01-01T00:00:00.000Z", ...over,
});
const empty = (o: Partial<KnowledgeFilter> = {}): KnowledgeFilter =>
  ({ query: "", groupIds: new Set(), levels: new Set(), tags: new Set(), ...o });

const notes = [
  n({ id: "a", title: "Câu điều kiện loại 2", groupId: "en_conditionals", cefrLevel: "b1", tags: ["toeic"] }),
  n({ id: "b", title: "Thì hiện tại đơn", groupId: "en_tenses", cefrLevel: "a1" }),
  n({ id: "c", explanation: "nói về **điều kiện**", groupId: "en_conditionals", cefrLevel: "b2" }),
];

describe("applyKnowledgeFilter", () => {
  it("folded query across fields", () => {
    expect(applyKnowledgeFilter(notes, empty({ query: "dieu kien" })).map((x) => x.id).sort()).toEqual(["a", "c"]);
  });
  it("group + level AND across, OR within", () => {
    expect(applyKnowledgeFilter(notes, empty({ groupIds: new Set(["en_conditionals"]), levels: new Set(["b1"]) }))
      .map((x) => x.id)).toEqual(["a"]);
  });
  it("tag filter", () => {
    expect(applyKnowledgeFilter(notes, empty({ tags: new Set(["toeic"]) })).map((x) => x.id)).toEqual(["a"]);
  });
});
describe("counts + tags", () => {
  it("group counts and sorted unique tags", () => {
    expect(knowledgeGroupCounts(notes).en_conditionals).toBe(2);
    expect(knowledgeAllTags(notes)).toEqual(["toeic"]);
  });
});
```

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement** — port of `lib/features/knowledge/domain/knowledge_filters.dart`.

```ts
// src/lib/knowledgeFilters.ts
import { normalizeForSearch } from "./normalizeSearch";
import type { CefrLevel, KnowledgeNote } from "./knowledgeNotes";

export interface KnowledgeFilter {
  query: string;
  groupIds: Set<string>;
  levels: Set<CefrLevel>;
  tags: Set<string>;
}

export function applyKnowledgeFilter(notes: KnowledgeNote[], filter: KnowledgeFilter): KnowledgeNote[] {
  const q = normalizeForSearch(filter.query);
  return notes.filter((n) => {
    if (filter.groupIds.size > 0 && !filter.groupIds.has(n.groupId)) return false;
    if (filter.levels.size > 0 && (n.cefrLevel === null || !filter.levels.has(n.cefrLevel))) return false;
    if (filter.tags.size > 0 && !n.tags.some((t) => filter.tags.has(t))) return false;
    if (q) {
      const hay = normalizeForSearch(
        [n.title, n.summary, n.explanation, n.patterns.join(" "), n.pitfalls.join(" "), n.tags.join(" ")].join(" "),
      );
      if (!hay.includes(q)) return false;
    }
    return true;
  });
}

export function knowledgeGroupCounts(notes: KnowledgeNote[]): Record<string, number> {
  const counts: Record<string, number> = {};
  for (const n of notes) counts[n.groupId] = (counts[n.groupId] ?? 0) + 1;
  return counts;
}

export function knowledgeAllTags(notes: KnowledgeNote[]): string[] {
  return [...new Set(notes.flatMap((n) => n.tags))].sort();
}
```

- [ ] **Step 4: Run, verify pass. `npm run typecheck` clean.**

- [ ] **Step 5: Commit**

```bash
git add apps/web/src/lib/knowledgeFilters.ts apps/web/src/lib/knowledgeFilters.test.ts
git commit -m "feat(web/knowledge): search/filter/count port"
```

---

## Task 9: `knowledgeNoteSource.ts` — AI prompt + draft parse

**Files:**
- Create: `src/lib/knowledgeNoteSource.ts`
- Test: `src/lib/knowledgeNoteSource.test.ts`

**Interfaces:**
- Consumes: `LANGUAGE_LABELS` / `TargetLanguage` (`@/lib/languages`), `knowledgeGroupsFor` / `knowledgeOtherGroupId` (Task 4), `KnowledgeNote` / `CefrLevel` (Task 5).
- Produces:
  - ```ts
    export interface KnowledgeNoteDraft {
      title: string; summary: string; explanation: string;
      patterns: string[]; examples: { text: string; translation: string }[]; pitfalls: string[];
      suggestedGroupId: string | null; suggestedCefr: CefrLevel | null;
      suggestedTags: string[]; relatedNoteId: string | null;
    }
    ```
  - `export function buildKnowledgeNotePrompt(args: { request: string; targetLanguage: TargetLanguage; hintGroupId?: string | null; hintCefr?: CefrLevel | null; existingInScope: Pick<KnowledgeNote, "id" | "title" | "summary">[]; extendingNote?: KnowledgeNote | null }): string`
  - `export function parseKnowledgeNoteDraft(json: Record<string, unknown>, targetLanguage: TargetLanguage): KnowledgeNoteDraft` — defensive; **`suggestedGroupId` is validated against `knowledgeGroupsFor(targetLanguage)` — an out-of-set id falls back to `knowledgeOtherGroupId(targetLanguage)`** (Flutter whole-branch fix #3). Empty-string ids → `null`.

- [ ] **Step 1: Write the failing test** (mirror `part5.test.ts` structure)

```ts
import { describe, expect, it } from "vitest";
import { buildKnowledgeNotePrompt, parseKnowledgeNoteDraft } from "./knowledgeNoteSource";

describe("buildKnowledgeNotePrompt", () => {
  it("includes the language's group ids, the existing notes, Vietnamese + markup rules, JSON shape", () => {
    const p = buildKnowledgeNotePrompt({
      request: "giải thích loại 2", targetLanguage: "english",
      existingInScope: [{ id: "n9", title: "Loại 3", summary: "..." }],
    });
    expect(p).toContain("en_conditionals");
    expect(p).toContain("n9");
    expect(p).toContain("Vietnamese");
    expect(p).toContain("**");
    expect(p).toContain('"relatedNoteId"');
  });
  it("adds the merge clause only when extendingNote is set", () => {
    const base = buildKnowledgeNotePrompt({ request: "x", targetLanguage: "english", existingInScope: [] });
    expect(base).not.toContain("REVISING");
  });
});

describe("parseKnowledgeNoteDraft", () => {
  it("parses a well-formed draft", () => {
    const d = parseKnowledgeNoteDraft({
      title: "T", summary: "S", explanation: "E", patterns: ["p"],
      examples: [{ text: "a", translation: "b" }], pitfalls: [],
      suggestedGroupId: "en_conditionals", suggestedCefr: "b1", suggestedTags: ["x"], relatedNoteId: null,
    }, "english");
    expect(d.suggestedGroupId).toBe("en_conditionals");
    expect(d.suggestedCefr).toBe("b1");
  });
  it("a hallucinated groupId falls back to en_other", () => {
    expect(parseKnowledgeNoteDraft({ title: "T", summary: "S", explanation: "E", suggestedGroupId: "en_bogus" }, "english")
      .suggestedGroupId).toBe("en_other");
  });
  it("missing optionals default safely; empty-string relatedNoteId → null", () => {
    const d = parseKnowledgeNoteDraft({ title: "T", summary: "S", explanation: "E", relatedNoteId: "" }, "english");
    expect(d.patterns).toEqual([]);
    expect(d.suggestedGroupId).toBeNull();
    expect(d.suggestedCefr).toBeNull();
    expect(d.relatedNoteId).toBeNull();
  });
});
```

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement** — port of `lib/features/knowledge/data/sources/knowledge_note_source.dart` (post fix #3).

```ts
// src/lib/knowledgeNoteSource.ts
import { LANGUAGE_LABELS, type TargetLanguage } from "./languages";
import { knowledgeGroupsFor, knowledgeOtherGroupId } from "./knowledgeGroups";
import type { CefrLevel, KnowledgeNote } from "./knowledgeNotes";

const CEFRS: CefrLevel[] = ["a1", "a2", "b1", "b2", "c1", "c2"];

export interface KnowledgeNoteDraft {
  title: string;
  summary: string;
  explanation: string;
  patterns: string[];
  examples: { text: string; translation: string }[];
  pitfalls: string[];
  suggestedGroupId: string | null;
  suggestedCefr: CefrLevel | null;
  suggestedTags: string[];
  relatedNoteId: string | null;
}

function strList(v: unknown): string[] {
  if (Array.isArray(v)) return v.filter((x): x is string => typeof x === "string");
  return typeof v === "string" && v.length > 0 ? [v] : [];
}
function nonEmptyOrNull(v: unknown): string | null {
  return typeof v === "string" && v.trim().length > 0 ? v.trim() : null;
}

export function buildKnowledgeNotePrompt(args: {
  request: string;
  targetLanguage: TargetLanguage;
  hintGroupId?: string | null;
  hintCefr?: CefrLevel | null;
  existingInScope: Pick<KnowledgeNote, "id" | "title" | "summary">[];
  extendingNote?: KnowledgeNote | null;
}): string {
  const label = LANGUAGE_LABELS[args.targetLanguage];
  const groups = knowledgeGroupsFor(args.targetLanguage).map((g) => `${g.id} (${g.label})`).join("; ");
  const existing =
    args.existingInScope.length === 0
      ? "None."
      : args.existingInScope.map((n) => `- id=${n.id} | ${n.title} | ${n.summary}`).join("\n");
  const hint = [
    args.hintGroupId ? `Prefer groupId "${args.hintGroupId}".` : "",
    args.hintCefr ? `Target CEFR ${args.hintCefr.toUpperCase()}.` : "",
  ].filter(Boolean).join(" ");
  const extend = args.extendingNote
    ? `You are REVISING this existing note — merge the new request into it and return the full updated note:\n${JSON.stringify(args.extendingNote)}\n`
    : "";
  return (
    `You are a grammar reference assistant for a Vietnamese speaker learning ${label}. ` +
    `Write a single reference note answering this request: "${args.request}". ${hint}\n` +
    extend +
    `Available groupId values: ${groups}\n` +
    `Existing notes in the same area (for de-duplication):\n${existing}\n` +
    `All prose and translations must be in Vietnamese (Vietnamese script only). In "explanation" ` +
    `and each "pitfalls" item you may wrap key terms in **double asterisks** for bold; use \\n\\n ` +
    `between paragraphs; no other markup. ` +
    `Respond with JSON only (no code fences): ` +
    `{"title":"short Vietnamese title","summary":"1-2 Vietnamese sentences","explanation":"...",` +
    `"patterns":["form strings, may be empty"],"examples":[{"text":"target-language sentence",` +
    `"translation":"Vietnamese"}],"pitfalls":["common mistakes, may be empty"],` +
    `"suggestedGroupId":"one id from the list above","suggestedCefr":"a1|a2|b1|b2|c1|c2 or null",` +
    `"suggestedTags":["0-3 short kebab-case tags"],"relatedNoteId":"the id of an existing note this ` +
    `substantially duplicates, or null"}`
  );
}

export function parseKnowledgeNoteDraft(
  json: Record<string, unknown>,
  targetLanguage: TargetLanguage,
): KnowledgeNoteDraft {
  const validGroupIds = new Set(knowledgeGroupsFor(targetLanguage).map((g) => g.id));
  const rawGroup = nonEmptyOrNull(json.suggestedGroupId);
  const suggestedGroupId =
    rawGroup === null ? null : validGroupIds.has(rawGroup) ? rawGroup : knowledgeOtherGroupId(targetLanguage);
  const rawCefr = typeof json.suggestedCefr === "string" ? json.suggestedCefr.trim().toLowerCase() : "";
  return {
    title: typeof json.title === "string" ? json.title : "",
    summary: typeof json.summary === "string" ? json.summary : "",
    explanation: typeof json.explanation === "string" ? json.explanation : "",
    patterns: strList(json.patterns),
    examples: Array.isArray(json.examples)
      ? json.examples
          .filter((e): e is Record<string, unknown> => typeof e === "object" && e !== null)
          .map((e) => ({
            text: typeof e.text === "string" ? e.text : "",
            translation: typeof e.translation === "string" ? e.translation : "",
          }))
      : [],
    pitfalls: strList(json.pitfalls),
    suggestedGroupId,
    suggestedCefr: (CEFRS as string[]).includes(rawCefr) ? (rawCefr as CefrLevel) : null,
    suggestedTags: strList(json.suggestedTags),
    relatedNoteId: nonEmptyOrNull(json.relatedNoteId),
  };
}
```

- [ ] **Step 4: Run, verify pass. `npm run typecheck` clean.**

- [ ] **Step 5: Commit**

```bash
git add apps/web/src/lib/knowledgeNoteSource.ts apps/web/src/lib/knowledgeNoteSource.test.ts
git commit -m "feat(web/knowledge): AI prompt builder + draft parser port"
```

---

## Task 10: `EditKnowledgeNoteModal` — the shared form

**Files:**
- Create: `src/components/knowledge/EditKnowledgeNoteModal.tsx`
- Test: `src/components/knowledge/EditKnowledgeNoteModal.test.tsx`

**Interfaces:**
- Consumes: `KnowledgeNote` / `KnowledgeExample` / `NewKnowledgeNote` (Task 5), `KnowledgeNoteDraft` (Task 9), `knowledgeGroupsFor` / `knowledgeGroupLabel` (Task 4), `CEFRS`, `SimpleDropdown` (`@/components/shared/SimpleDropdown`).
- Produces: `export function EditKnowledgeNoteModal(props: { initial?: KnowledgeNote | null; draft?: KnowledgeNoteDraft | null; overwriteNoteId?: string | null; sourcePrompt?: string | null; targetLanguage: TargetLanguage; existingNotes: KnowledgeNote[]; onClose(): void; onSave(note: KnowledgeNote): Promise<void> }): JSX.Element`
  - Exactly one of `initial` / `draft` / neither. Prefills every field: `initial?.x ?? draft?.x ?? default`; `groupId` from `initial?.groupId ?? draft?.suggestedGroupId`; `cefrLevel` from `initial?.cefrLevel ?? draft?.suggestedCefr`; tags merged.
  - Fields: title (`<input>`), summary (`<textarea>`), explanation (`<textarea>` + hint "bọc **...** để in đậm"), patterns (add/remove rows), examples (add/remove `{text,translation}` row pairs), pitfalls (add/remove rows), group (`SimpleDropdown`, required), CEFR (`SimpleDropdown` with a "Không đặt" option → `null`), tags (chips + add input).
  - Save builds a `KnowledgeNote`:
    - `id = overwriteNoteId ?? initial?.id ?? crypto.randomUUID()`
    - `source`: if `draft` provided → an *overwrite* of an existing note keeps `existing.source` unless it was `"starter"` (→ `"ai"`); a fresh AI note → `"ai"`; else `existing?.source ?? "manual"` (Flutter whole-branch fix #6).
    - `existing` = `existingNotes.find(n => n.id === (overwriteNoteId ?? initial?.id))` **?? initial ?? null** (fall back to `initial`, per Flutter fix).
    - `createdAt` = `existing?.createdAt ?? now`; `updatedAt` = `now`; `sourcePrompt` = `props.sourcePrompt ?? existing?.sourcePrompt ?? null`.
  - Validation: empty title → inline "Nhập tiêu đề cho ghi chú."; no group → "Chọn một nhóm."; no save on either.
  - A `saving` guard disables the save button during `await onSave` and shows the error message on a throw (does NOT close).

Follow `src/components/vocab-bank/EditVocabModal.tsx` for the modal shell, backdrop, add/remove-row markup, and `SimpleDropdown` usage.

- [ ] **Step 1: Write the failing test**

```tsx
import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { EditKnowledgeNoteModal } from "./EditKnowledgeNoteModal";
import type { KnowledgeNoteDraft } from "@/lib/knowledgeNoteSource";
import type { KnowledgeNote } from "@/lib/knowledgeNotes";

const draft: KnowledgeNoteDraft = {
  title: "Câu điều kiện loại 2", summary: "S", explanation: "E", patterns: [], examples: [],
  pitfalls: [], suggestedGroupId: "en_conditionals", suggestedCefr: "b1", suggestedTags: [], relatedNoteId: null,
};

describe("EditKnowledgeNoteModal", () => {
  it("review-draft: prefills and saves an ai note with the suggested group + sourcePrompt", async () => {
    const onSave = vi.fn().mockResolvedValue(undefined);
    render(
      <EditKnowledgeNoteModal draft={draft} sourcePrompt="loại 2" targetLanguage="english"
        existingNotes={[]} onClose={() => {}} onSave={onSave} />,
    );
    expect(screen.getByDisplayValue("Câu điều kiện loại 2")).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "Lưu" }));
    await waitFor(() => expect(onSave).toHaveBeenCalled());
    const saved = onSave.mock.calls[0][0] as KnowledgeNote;
    expect(saved.source).toBe("ai");
    expect(saved.groupId).toBe("en_conditionals");
    expect(saved.sourcePrompt).toBe("loại 2");
  });
  it("blank-new: empty title blocks the save and shows the error", () => {
    const onSave = vi.fn();
    render(<EditKnowledgeNoteModal targetLanguage="english" existingNotes={[]} onClose={() => {}} onSave={onSave} />);
    fireEvent.click(screen.getByRole("button", { name: "Lưu" }));
    expect(onSave).not.toHaveBeenCalled();
    expect(screen.getByText(/Nhập tiêu đề/)).toBeInTheDocument();
  });
  it("AI overwrite of a manual note keeps origin manual", async () => {
    const onSave = vi.fn().mockResolvedValue(undefined);
    const existing: KnowledgeNote = { ...draft as unknown as KnowledgeNote, id: "m1", source: "manual",
      groupId: "en_conditionals", targetLanguage: "english", tags: [], cefrLevel: "b1",
      sourcePrompt: null, createdAt: "2020-01-01T00:00:00.000Z", updatedAt: "2020-01-01T00:00:00.000Z" };
    render(<EditKnowledgeNoteModal draft={draft} overwriteNoteId="m1" targetLanguage="english"
      existingNotes={[existing]} onClose={() => {}} onSave={onSave} />);
    fireEvent.click(screen.getByRole("button", { name: "Lưu" }));
    await waitFor(() => expect(onSave).toHaveBeenCalled());
    const saved = onSave.mock.calls[0][0] as KnowledgeNote;
    expect(saved.source).toBe("manual");
    expect(saved.createdAt).toBe("2020-01-01T00:00:00.000Z");
  });
});
```

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement** — following `EditVocabModal.tsx`. (Full component ~200 lines; structure per the Interfaces block above. `crypto.randomUUID()` is available in jsdom 29 + the browser.)

- [ ] **Step 4: Run, verify pass. `npm run typecheck` clean.**

- [ ] **Step 5: Commit**

```bash
git add apps/web/src/components/knowledge/EditKnowledgeNoteModal.tsx apps/web/src/components/knowledge/EditKnowledgeNoteModal.test.tsx
git commit -m "feat(web/knowledge): EditKnowledgeNoteModal (shared write/edit/review form)"
```

---

## Task 11: `KnowledgeNoteCard` + detail page + group page

**Files:**
- Create: `src/components/knowledge/KnowledgeNoteCard.tsx`
- Create: `src/components/knowledge/KnowledgeNoteView.tsx`
- Create: `src/app/(app)/knowledge/note/[id]/page.tsx`
- Create: `src/app/(app)/knowledge/note/[id]/edit/page.tsx`
- Create: `src/app/(app)/knowledge/group/[groupId]/page.tsx`
- Test: `src/components/knowledge/KnowledgeNoteView.test.tsx`, `src/app/(app)/knowledge/group/[groupId]/page.test.tsx`

**Interfaces:**
- Consumes: `KnowledgeNote` (Task 5), `BoldText` (Task 3), `knowledgeGroupLabel` (Task 4), `HighlightedText` (`@/components/shared/HighlightedText`, existing), `getKnowledgeNotes` / `deleteKnowledgeNote` (Task 5), `useAuthUser` / `useSettingsContext` (existing), `getVocabRecords` (existing).
- Produces:
  - `KnowledgeNoteCard({ note, href }: { note: KnowledgeNote; href: string })` — a `<Link>` card: title (bold), summary (`known-summary-clamp` 2-line), a row of pills `[knowledgeGroupLabel(note.groupId)]`, `[note.cefrLevel?.toUpperCase()]`, and `Mẫu` when `note.source === "starter"`.
  - `KnowledgeNoteView({ note, knownHeadwords, onDelete }: {...})` — client component: title (h2) → summary → `<BoldText source={note.explanation} />` → **Mẫu câu** section + `<code>` per pattern (only if non-empty) → **Ví dụ** + per example `<HighlightedText variant="static" text={ex.text} highlights={knownHeadwords} />` over `<p className="ex-translation">{ex.translation}</p>` (only if non-empty) → **Lỗi thường gặp** + `<BoldText>` per pitfall (only if non-empty) → pill row. A "Sửa" `<Link>` to `./edit` and a "Xoá" button → `window.confirm`-style modal or a simple inline confirm → `onDelete()`.
  - `knowledge/note/[id]/page.tsx` — `"use client"`; loads notes for the active language, finds by `id`, renders `KnowledgeNoteView`; not found → "Không tìm thấy ghi chú"; delete → `deleteKnowledgeNote` then `router.push("/knowledge")`, catch → an error toast/message, stay.
  - `knowledge/note/[id]/edit/page.tsx` — loads the note, renders `EditKnowledgeNoteModal initial={note}` with `onSave` = `upsertKnowledgeNote` then `router.push` to the detail; not found → "Không tìm thấy ghi chú" (not a blank form).
  - `knowledge/group/[groupId]/page.tsx` — loads notes for the active language filtered to `groupId`, sections by CEFR (a1→c2 then "Chưa gắn cấp độ"), each section a heading + `KnowledgeNoteCard`s. Page `<h2>` = `knowledgeGroupLabel(groupId)`.

- [ ] **Step 1: Write the failing tests**

```tsx
// KnowledgeNoteView.test.tsx — key assertions
it("renders present sections, hides empty ones", () => {
  render(<KnowledgeNoteView note={noteFixture({ explanation: "a **b**", patterns: ["If ..."], examples: [], pitfalls: [] })}
    knownHeadwords={[]} onDelete={() => {}} />);
  expect(screen.getByText("Mẫu câu")).toBeInTheDocument();
  expect(screen.queryByText("Lỗi thường gặp")).toBeNull();
});
it("shows a Mẫu pill for a starter note", () => {
  render(<KnowledgeNoteView note={noteFixture({ source: "starter" })} knownHeadwords={[]} onDelete={() => {}} />);
  expect(screen.getByText("Mẫu")).toBeInTheDocument();
});
```

```tsx
// group/[groupId]/page.test.tsx — mock getKnowledgeNotes + auth/settings; assert CEFR section headers
it("sections notes by CEFR", async () => {
  // getKnowledgeNotes resolves 3 notes in en_tenses at a1 / b2 / null
  render(<GroupPage params={Promise.resolve({ groupId: "en_tenses" })} />);
  expect(await screen.findByText("A1")).toBeInTheDocument();
  expect(screen.getByText("B2")).toBeInTheDocument();
  expect(screen.getByText("Chưa gắn cấp độ")).toBeInTheDocument();
});
```

> Next 16 route params: check `apps/web/AGENTS.md` and an existing dynamic route (e.g. is there one under `src/app/`?) for whether `params` is a Promise (`use(params)`) or a plain object in this version. Match the existing convention. If no dynamic route exists yet, read `node_modules/next/dist/docs/` for the params API.

Put a `noteFixture(...)` helper + a shared `renderKnowledgePage` (mocks `useAuthUser`, `useSettingsContext`, `getKnowledgeNotes`, `getVocabRecords`) in `src/components/knowledge/testUtils.tsx`.

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement the 5 files.**

- [ ] **Step 4: Run, verify pass. `npm run typecheck` clean.**

- [ ] **Step 5: Commit**

```bash
git add apps/web/src/components/knowledge apps/web/src/app/\(app\)/knowledge/note apps/web/src/app/\(app\)/knowledge/group
git commit -m "feat(web/knowledge): note card + detail + edit + group pages"
```

---

## Task 12: `knowledge/page.tsx` — home (group grid + search + tags)

**Files:**
- Create: `src/components/knowledge/KnowledgeGroupGrid.tsx`
- Create: `src/app/(app)/knowledge/page.tsx`
- Create: `src/app/(app)/knowledge/new/page.tsx`
- Test: `src/app/(app)/knowledge/page.test.tsx`

**Interfaces:**
- Consumes: `getKnowledgeNotes` / `seedStartersIfNeeded` (Task 5), `startersFor` (Task 6), `applyKnowledgeFilter` / `knowledgeGroupCounts` / `knowledgeAllTags` / `KnowledgeFilter` (Task 8), `knowledgeGroupsFor` (Task 4), `KnowledgeNoteCard` (Task 11), `useAuthUser` / `useSettingsContext`.
- Produces:
  - `KnowledgeGroupGrid({ language, counts }: { language: TargetLanguage; counts: Record<string, number> })` — a grid of `<Link href={/knowledge/group/{id}}>` cards, label + count, dimmed when count is 0.
  - `knowledge/page.tsx` — `"use client"`:
    - On load (signed in + settings): `await seedStartersIfNeeded(uid, language, startersFor(language))` then `getKnowledgeNotes(uid, language)`. Re-run when `language` changes.
    - Local `KnowledgeFilter` state (query + tags only). Search `<input>` + a tag chip row (`knowledgeAllTags`, toggle).
    - Body: query empty AND no tags → `KnowledgeGroupGrid`; else → flat list of `KnowledgeNoteCard` from `applyKnowledgeFilter`.
    - Empty state (loaded, no notes): a line + 2-3 example prompts + a "Nhờ AI soạn" button.
    - Actions: "Nhờ AI soạn" opens `AiComposeModal` (Task 13 — for THIS task, wire the button to a `useState` boolean and render a placeholder `null`; Task 13 drops in the real modal). "Tự viết" → `<Link href="/knowledge/new">`.
    - Signed-out → sign-in prompt (copy `word-radar/page.tsx:37-45`).
    - Overflow: a small "Khôi phục ghi chú mẫu" button, shown only when `language === "english"` → `restoreStarters(uid, language, startersFor(language))` then reload + a message.
  - `knowledge/new/page.tsx` — renders `EditKnowledgeNoteModal` (no `initial`/`draft`) with `onSave` = `upsertKnowledgeNote` then `router.push("/knowledge/note/{id}")`.

- [ ] **Step 1: Write the failing test**

```tsx
// page.test.tsx — mock the lib + hooks
it("shows a group grid with counts", async () => {
  // getKnowledgeNotes → 2 notes in en_tenses, 1 in en_conditionals
  render(<KnowledgePage />);
  expect(await screen.findByText("Thì")).toBeInTheDocument();
  expect(screen.getByText("2")).toBeInTheDocument();
});
it("typing in search switches to a filtered flat list", async () => {
  render(<KnowledgePage />);
  fireEvent.change(await screen.findByPlaceholderText(/Tìm/), { target: { value: "dieu kien" } });
  expect(await screen.findByText("Câu điều kiện loại 2")).toBeInTheDocument();
  expect(screen.queryByText("Thì hiện tại đơn")).toBeNull();
});
it("Khôi phục ghi chú mẫu calls restoreStarters", async () => {
  render(<KnowledgePage />);
  fireEvent.click(await screen.findByRole("button", { name: /Khôi phục/ }));
  await waitFor(() => expect(restoreStartersMock).toHaveBeenCalled());
});
```

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement.** Follow `word-radar/page.tsx` + `vocab-bank/page.tsx` for the auth/settings gating, the `"use client"` data-loading `useEffect`, and Bloom class names.

- [ ] **Step 4: Run, verify pass. `npm run typecheck` clean.**

- [ ] **Step 5: Commit**

```bash
git add apps/web/src/components/knowledge/KnowledgeGroupGrid.tsx apps/web/src/app/\(app\)/knowledge/page.tsx apps/web/src/app/\(app\)/knowledge/page.test.tsx apps/web/src/app/\(app\)/knowledge/new
git commit -m "feat(web/knowledge): home page (group grid + search + tags) + blank form page"
```

---

## Task 13: `AiComposeModal` + `RelatedNotesBanner` — the "Nhờ AI soạn" flow

**Files:**
- Create: `src/components/knowledge/RelatedNotesBanner.tsx`
- Create: `src/components/knowledge/AiComposeModal.tsx`
- Modify: `src/app/(app)/knowledge/page.tsx` (wire the button to the real modal)
- Test: `src/components/knowledge/AiComposeModal.test.tsx`

**Interfaces:**
- Consumes: `generateContent` (`@/lib/generateContent`), `parseAiJsonObject` (`@/lib/parseAiJson`), `buildKnowledgeNotePrompt` / `parseKnowledgeNoteDraft` / `KnowledgeNoteDraft` (Task 9), `findRelatedNotes` (Task 7), `KnowledgeNote` (Task 5), `knowledgeGroupsFor` (Task 4), `EditKnowledgeNoteModal` (Task 10), `useAuthUser` / `useSettingsContext`.
- Produces:
  - `RelatedNotesBanner({ related, onOpen, onExtend, onProceedNew }: { related: KnowledgeNote[]; onOpen(n: KnowledgeNote): void; onExtend(n: KnowledgeNote): void; onProceedNew(): void })` — "Bạn đã có N ghi chú liên quan" + one card per note (title + "Mở" + "Bổ sung vào ghi chú này") + a shared "Vẫn tạo mới".
  - `AiComposeModal({ existingNotes, targetLanguage, onClose, onSaved }: {...})` — a modal with an internal state machine:
    - `idle` — if `!aiAvailable` show a "no API key → Cài đặt" hint (copy `word-radar/page.tsx:108-112`), else a request `<textarea>` + optional group/CEFR `SimpleDropdown` hints + a "Soạn" button.
    - On "Soạn": Layer 1 — `findRelatedNotes({ prompt: request, notes: existingNotes })`. Non-empty → `related` state (render `RelatedNotesBanner`). Empty → `_generate(request, hints, { extendingNote: null, overwriteNoteId: null, resolveLayer2: true })`.
    - `_generate` → `loading` state → `generateContent({ provider, model, apiKeyCiphertext, prompt: buildKnowledgeNotePrompt(...) })` → `parseAiJsonObject` → `parseKnowledgeNoteDraft(json, targetLanguage)`. On success: if `resolveLayer2` and `draft.relatedNoteId` matches an `existingNotes` id → show `RelatedNotesBanner` for that one note; else → `ready` state rendering `EditKnowledgeNoteModal draft={draft} overwriteNoteId={overwriteNoteId} sourcePrompt={request}` whose `onSave` calls the caller's `onSaved(note)` (which `upsertKnowledgeNote`s + navigates). On throw → `error` state + "Thử lại" → back to `idle` (request text preserved).
    - `RelatedNotesBanner` callbacks: `onOpen` → `onClose()` + navigate to that note; `onProceedNew` → `_generate(request, hints, { resolveLayer2: false })`; `onExtend(n)` → `_generate(request, hints, { extendingNote: n, overwriteNoteId: n.id, resolveLayer2: false })`. **`request` must be carried across the whole state machine** (Flutter whole-branch fix — an earlier bug lost it on the Layer-2 path).

- [ ] **Step 1: Write the failing test** (mock `generateContent`)

```tsx
import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

vi.mock("@/lib/generateContent", () => ({ generateContent: vi.fn() }));
vi.mock("@/lib/useAuthUser", () => ({ useAuthUser: () => ({ user: { uid: "u" }, loading: false }) }));
vi.mock("@/lib/SettingsContext", () => ({
  useSettingsContext: () => ({
    settings: { activeProvider: "gemini", targetLanguage: "english",
      providers: { gemini: { model: "m", apiKeyCiphertext: "ct" } } },
  }),
}));

import { generateContent } from "@/lib/generateContent";
import { AiComposeModal } from "./AiComposeModal";
import { noteFixture } from "./testUtils";

const okDraft = JSON.stringify({
  title: "Câu điều kiện loại 2", summary: "S", explanation: "E",
  patterns: [], examples: [], pitfalls: [], suggestedGroupId: "en_conditionals",
  suggestedCefr: "b1", suggestedTags: [], relatedNoteId: null,
});

it("Layer-1 hit → shows the related banner; 'Vẫn tạo mới' generates and opens the editor", async () => {
  vi.mocked(generateContent).mockResolvedValue({ text: okDraft });
  render(<AiComposeModal existingNotes={[noteFixture({ id: "a", title: "Câu điều kiện loại 2 và 3" })]}
    targetLanguage="english" onClose={() => {}} onSaved={vi.fn()} />);
  fireEvent.change(screen.getByRole("textbox"), { target: { value: "câu điều kiện loại 2" } });
  fireEvent.click(screen.getByRole("button", { name: "Soạn" }));
  expect(await screen.findByText(/ghi chú liên quan/)).toBeInTheDocument();
  fireEvent.click(screen.getByRole("button", { name: "Vẫn tạo mới" }));
  await waitFor(() => expect(generateContent).toHaveBeenCalled());
  expect(await screen.findByDisplayValue("Câu điều kiện loại 2")).toBeInTheDocument();
});

it("no API key → shows the Cài đặt hint, no Soạn button", () => {
  // re-mock useSettingsContext with apiKeyCiphertext: null for this test
});

it("generateContent throws → error state + Thử lại", async () => {
  vi.mocked(generateContent).mockRejectedValue(new Error("boom"));
  render(<AiComposeModal existingNotes={[]} targetLanguage="english" onClose={() => {}} onSaved={vi.fn()} />);
  fireEvent.change(screen.getByRole("textbox"), { target: { value: "chủ đề mới toanh" } });
  fireEvent.click(screen.getByRole("button", { name: "Soạn" }));
  expect(await screen.findByText(/Không tạo được/)).toBeInTheDocument();
  expect(screen.getByRole("button", { name: "Thử lại" })).toBeInTheDocument();
});
```

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement both components; wire `knowledge/page.tsx`'s "Nhờ AI soạn" button + the empty-state button to render `<AiComposeModal>` when a `composing` state is true.** `onSaved` = `async (note) => { await upsertKnowledgeNote(uid, note); router.push(/knowledge/note/${note.id}); }`.

- [ ] **Step 4: Run, verify pass. `npm run typecheck` clean. Full `npm test`.**

- [ ] **Step 5: Commit**

```bash
git add apps/web/src/components/knowledge apps/web/src/app/\(app\)/knowledge/page.tsx
git commit -m "feat(web/knowledge): Nhờ AI soạn flow (compose modal + related-notes banner)"
```

---

## Task 14: Sidebar nav + styles + README + final verification

**Files:**
- Modify: `src/components/shell/Sidebar.tsx`
- Modify: `src/components/shell/Sidebar.test.tsx` (assert the new link)
- Modify: `src/styles/bloom.css`
- Modify: root `README.md`

- [ ] **Step 1: Sidebar** — add a nav group after "Quét từ":

```ts
{ label: "Kiến thức", items: [{ href: "/knowledge", label: "📖 Kiến thức" }] },
```

Extend `Sidebar.test.tsx` with `expect(screen.getByRole("link", { name: /Kiến thức/ })).toHaveAttribute("href", "/knowledge")`.

- [ ] **Step 2: Styles** — append a `/* --- Knowledge Notes --- */` block to `src/styles/bloom.css` covering every class the components introduced (`.bold-text`, `.knowledge-group-grid`, `.knowledge-group-card`, `.knowledge-note-card`, `.known-summary-clamp`, `.knowledge-pill-row`, `.knowledge-note-view`, `.related-notes-banner`, `.ai-compose-modal`, …). Reuse existing Bloom tokens/variables — grep `bloom.css` for `--` custom properties and existing card/pill/modal classes (`.suggestion-card`, `.cefr-pill`, `.word-radar-result-card`) and match their look.

- [ ] **Step 3: README** — under the web section (`## Tính năng` → the "Kiến thức" section added by the Flutter plan, or the web-app bullet), note that the **web app now has the Kiến thức UI** (previously "web theo sau"). Update the web test-count mention if one exists.

- [ ] **Step 4: Final verification**

```bash
cd apps/web
npm run typecheck   # must be clean
npm test            # must pass; record the exact count (was ~800 + ~55 new)
npm run build       # must succeed (Next.js production build — catches RSC/client boundary mistakes the tests miss)
```

Record all three outputs in the report and the commit body.

- [ ] **Step 5: Commit**

```bash
git add apps/web/src/components/shell apps/web/src/styles/bloom.css README.md
git commit -m "feat(web/knowledge): sidebar entry + styles + README; web UI complete"
```

---

## Self-Review

**Spec coverage (spec `docs/superpowers/specs/2026-09-06-knowledge-notes-design.md`, which is dual-platform):**

| Spec section | Web task(s) |
|---|---|
| §1 scope, §2 data model + shared shape | Global Constraints; Task 5 |
| §2 seed flag doc | Task 5 |
| §3 per-language taxonomy | Task 4 |
| §4.1 home | Task 12 |
| §4.2 group screen | Task 11 |
| §4.3 detail | Task 11 |
| §4.4 edit form | Task 10 |
| §5.1 AI flow | Task 13 |
| §5.2 Layer-1 tokeniser | Task 1 + Task 7 |
| §5.3 error handling | Task 5 (writes throw), Task 13 (error state) |
| §6 `**bold**` parser + shared vectors | Task 2, Task 3 (render) |
| §7 search & filters | Task 8 (pure) + Task 12 (UI) |
| §8.1–8.3 starter library + seeding + restore | Task 5 + Task 6 + Task 12 |
| §8.5 the 12 English notes | Task 6 (shared asset, no re-authoring) |
| §10 out of scope | respected |

**Carried Flutter whole-branch fixes** (so the web port doesn't reintroduce them): writes throw (Task 5), per-doc parse skip (Task 5), defensive dates incl. `Timestamp` (Task 5), `suggestedGroupId` validation (Task 9), `thi`/`the` not stopwords (Task 7), "Bổ sung" keeps `source` unless `starter` + `existing ?? initial` fallback (Task 10), `request` carried across the AI state machine (Task 13).

**Type consistency:** `KnowledgeNote`, `KnowledgeExample`, `KnowledgeNoteOrigin`, `CefrLevel`, `KnowledgeNoteDraft`, `KnowledgeFilter`, `KnowledgeGroup` are defined once (Tasks 4/5/8/9) and imported everywhere else. Firestore functions: `getKnowledgeNotes` / `upsertKnowledgeNote` / `deleteKnowledgeNote` / `seedStartersIfNeeded` / `restoreStarters` used with those exact names in Tasks 11–13.

**Open items for the implementer:**
- Next 16 dynamic-route `params` API (Promise vs object) — resolve against `apps/web/AGENTS.md` + `node_modules/next/dist/docs/` + an existing route before Task 11.
- `resolveJsonModule` in `apps/web/tsconfig.json` for Task 6's JSON import (likely already set).
- The exact Bloom class names / tokens for Task 14's CSS — grep `bloom.css`, match the nearest existing component.

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-09-09-knowledge-notes-web.md`. Two execution options:**

**1. Subagent-Driven (recommended)** — fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** — batch execution in this session with checkpoints.

**Which approach?**
