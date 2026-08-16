# React Web Plan 3 / Phase B (Part 2) — Tra từ (Lookup) + Ôn tập (Practice) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the Next.js web app two more real screens — `/lookup` (AI-backed dictionary lookup with save-to-Vocab-Bank) and `/practice` (relabeled "Ôn tập" in the sidebar — AI-free SM-2 flashcard review) — closing out React Web Plan 3 Phase B.

**Architecture:** Lookup checks the user's saved Vocab Bank first (a targeted Firestore query, not a full-bank fetch), falling back to `generateContent` (reusing the Cài đặt-stored provider/model/API-key-ciphertext) with a ported-from-Flutter prompt, parsed via a ported-from-Flutter JSON extractor. Saving reuses the existing `EditVocabModal` component in a new "create" mode. Ôn tập is entirely client-side Firestore CRUD, no AI: a session-setup screen (reusing the existing `TopicFilterPopover`) selects a word pool, a flashcard component (diagonal `rotate3d` flip, confirmed via the visual companion) runs the review loop in memory, and a result screen batch-writes SM-2 updates through a single well-defined completion point.

**Tech Stack:** Next.js 16 (App Router) on `apps/web/`, React 19, Firebase JS SDK v12 (`firebase/firestore`, `firebase/functions`), Vitest + React Testing Library + jsdom.

## Global Constraints

- All user-facing text is Vietnamese, matching every existing screen.
- Import alias `@/` maps to `apps/web/src/`.
- Every new/changed file gets a colocated Vitest test, following the existing mock style (`vi.mock("firebase/firestore", ...)`, `vi.mock("./firebase", () => ({ getFirebaseDb: vi.fn(() => "mock-db") }))`).
- Ôn tập makes **zero** `generateContent`/AI calls anywhere in its flow — a deliberate scope decision (spec §2 Non-goals), not an oversight. Do not add AI-generated exercise types.
- Sentence lookups in Tra từ are never saveable to Vocab Bank — display translation only, no save button.
- The SM-2 formula and its exact constants (rep 1 → 1 day, rep 2 → 6 days, further reps → `interval × easeFactor`; ease factor delta `+0.1 - (5-quality)×0.08` clamped to `[1.3, 2.5]`; quality < 3 resets repetitions to 0 and schedules tomorrow) must match `lib/features/practice/domain/use_cases/compute_sm2_use_case.dart` exactly — this is shared production data with the Flutter app.
- Verify each task with `npm --prefix apps/web test` (full suite) and finish the plan with `npm --prefix apps/web run typecheck` and `npm --prefix apps/web run build`.

---

## Task 1: Lookup domain logic (JSON parsing, input detection, prompts, result types)

**Files:**
- Create: `apps/web/src/lib/parseAiJson.ts`
- Create: `apps/web/src/lib/parseAiJson.test.ts`
- Create: `apps/web/src/lib/inputDetector.ts`
- Create: `apps/web/src/lib/inputDetector.test.ts`
- Create: `apps/web/src/lib/lookup.ts`
- Create: `apps/web/src/lib/lookup.test.ts`

**Interfaces:**
- Produces: `parseAiJsonObject(raw: string): Record<string, unknown>` (`@/lib/parseAiJson`); `type InputType = "word" | "phrase" | "sentence"`, `detectInputType(input: string): InputType` (`@/lib/inputDetector`); `WordPhraseResult`, `SentenceResult`, `LookupResult` (a union), `buildWordPhrasePrompt(query: string, targetLanguage: TargetLanguage): string`, `buildSentencePrompt(sentence: string): string`, `parseLookupResult(json: Record<string, unknown>, inputType: InputType, query: string): LookupResult` (`@/lib/lookup`). Used by Tasks 4-5.
- Consumes: `TargetLanguage`, `LANGUAGE_LABELS` (`@/lib/languages`, already exists from the Cài đặt sub-spec).

All three files are pure functions — no Firestore, no network, no React.

- [ ] **Step 1: Write the failing test for `parseAiJsonObject`**

Create `apps/web/src/lib/parseAiJson.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import { parseAiJsonObject } from "./parseAiJson";

describe("parseAiJsonObject", () => {
  it("parses a plain JSON object", () => {
    expect(parseAiJsonObject('{"a":1}')).toEqual({ a: 1 });
  });

  it("strips markdown code fences", () => {
    expect(parseAiJsonObject('```json\n{"a":1}\n```')).toEqual({ a: 1 });
    expect(parseAiJsonObject('```\n{"a":1}\n```')).toEqual({ a: 1 });
  });

  it("extracts a balanced JSON object even with trailing prose around it", () => {
    expect(parseAiJsonObject('Sure! {"a":1} Hope that helps.')).toEqual({ a: 1 });
  });

  it("does not get confused by braces inside string values", () => {
    expect(parseAiJsonObject('{"a":"contains { and } inside"}')).toEqual({
      a: "contains { and } inside",
    });
  });

  it("throws when no JSON object can be found", () => {
    expect(() => parseAiJsonObject("no json here")).toThrow();
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm --prefix apps/web test`
Expected: FAIL — `./parseAiJson` does not exist.

- [ ] **Step 3: Implement `parseAiJsonObject`**

Create `apps/web/src/lib/parseAiJson.ts`:

```ts
// Ports lib/core/utils/ai_json_parser.dart's parseAiJsonObject. Even when a
// provider is explicitly asked for JSON-only output, it can still wrap the
// object in markdown code fences or append trailing prose/garbage after it.
// Strip markdown fences first, then — if the text still doesn't parse as-is —
// fall back to extracting just the balanced-brace JSON object substring
// (respecting string literals, so a `{`/`}` inside a JSON string value
// doesn't throw off the brace count).
export function parseAiJsonObject(raw: string): Record<string, unknown> {
  const stripped = stripCodeFences(raw.trim());
  try {
    return JSON.parse(stripped) as Record<string, unknown>;
  } catch {
    const extracted = extractBalancedObject(stripped);
    if (extracted === null) {
      throw new Error("No JSON object found in AI response.");
    }
    return JSON.parse(extracted) as Record<string, unknown>;
  }
}

const FENCE_PATTERN = /^```(?:json)?\s*([\s\S]*?)\s*```$/;

function stripCodeFences(text: string): string {
  const match = FENCE_PATTERN.exec(text);
  return match ? match[1].trim() : text;
}

function extractBalancedObject(text: string): string | null {
  const start = text.indexOf("{");
  if (start === -1) return null;
  let depth = 0;
  let inString = false;
  let escaped = false;
  for (let i = start; i < text.length; i++) {
    const char = text[i];
    if (escaped) {
      escaped = false;
      continue;
    }
    if (char === "\\") {
      escaped = true;
      continue;
    }
    if (char === '"') {
      inString = !inString;
      continue;
    }
    if (inString) continue;
    if (char === "{") depth++;
    if (char === "}") {
      depth--;
      if (depth === 0) return text.slice(start, i + 1);
    }
  }
  return null;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm --prefix apps/web test`
Expected: PASS.

- [ ] **Step 5: Write the failing test for `detectInputType`**

Create `apps/web/src/lib/inputDetector.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import { detectInputType } from "./inputDetector";

describe("detectInputType", () => {
  it("detects a single word", () => {
    expect(detectInputType("meticulous")).toBe("word");
  });

  it("detects a short phrase (2-4 words)", () => {
    expect(detectInputType("break the ice")).toBe("phrase");
    expect(detectInputType("a piece of cake")).toBe("phrase");
  });

  it("detects a sentence by terminal punctuation, regardless of word count", () => {
    expect(detectInputType("Hi.")).toBe("sentence");
    expect(detectInputType("Is this correct?")).toBe("sentence");
    expect(detectInputType("Wow!")).toBe("sentence");
  });

  it("detects a sentence by word count alone (more than 4 words, no punctuation)", () => {
    expect(detectInputType("she reviewed the contract carefully")).toBe("sentence");
  });

  it("treats empty or whitespace-only input as a word", () => {
    expect(detectInputType("")).toBe("word");
    expect(detectInputType("   ")).toBe("word");
  });
});
```

- [ ] **Step 6: Run test to verify it fails**

Run: `npm --prefix apps/web test`
Expected: FAIL — `./inputDetector` does not exist.

- [ ] **Step 7: Implement `detectInputType`**

Create `apps/web/src/lib/inputDetector.ts`:

```ts
// Ports lib/core/utils/input_detector.dart's InputDetector.detect exactly —
// verified against that file, not guessed.
export type InputType = "word" | "phrase" | "sentence";

const PHRASE_MAX_WORDS = 4;
const TERMINAL_PUNCTUATION = /[.?!]\s*$/;

export function detectInputType(input: string): InputType {
  const trimmed = input.trim();
  if (trimmed === "") return "word";
  if (TERMINAL_PUNCTUATION.test(trimmed)) return "sentence";

  const wordCount = trimmed.split(/\s+/).length;
  if (wordCount > PHRASE_MAX_WORDS) return "sentence";
  if (wordCount >= 2) return "phrase";
  return "word";
}
```

- [ ] **Step 8: Run test to verify it passes**

Run: `npm --prefix apps/web test`
Expected: PASS.

- [ ] **Step 9: Write the failing test for prompts + result parsing**

Create `apps/web/src/lib/lookup.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import { buildWordPhrasePrompt, buildSentencePrompt, parseLookupResult, type WordPhraseResult } from "./lookup";

describe("buildWordPhrasePrompt", () => {
  it("includes the query and target language label, and asks for JSON only", () => {
    const prompt = buildWordPhrasePrompt("meticulous", "english");
    expect(prompt).toContain('"meticulous"');
    expect(prompt).toContain("English");
    expect(prompt).toContain("JSON only");
  });

  it("uses the target language's own label, not always English", () => {
    const prompt = buildWordPhrasePrompt("안녕", "korean");
    expect(prompt).toContain("한국어");
  });
});

describe("buildSentencePrompt", () => {
  it("includes the sentence and requires Vietnamese-script-only translation", () => {
    const prompt = buildSentencePrompt("Hello world.");
    expect(prompt).toContain('"Hello world."');
    expect(prompt).toContain("Vietnamese script");
  });
});

describe("parseLookupResult", () => {
  it("parses a word/phrase result, lowercasing the CEFR level", () => {
    const result = parseLookupResult(
      {
        headword: "meticulous",
        ipa: "/məˈtɪkjələs/",
        meaning: "tỉ mỉ, cẩn thận",
        definition: "Showing great attention to detail.",
        synonyms: ["thorough", "careful"],
        examples: ["She is meticulous."],
        suggestedTopics: ["Business"],
        cefrLevel: "C1",
      },
      "word",
      "meticulous"
    );
    expect(result).toEqual({
      kind: "wordPhrase",
      headword: "meticulous",
      inputType: "word",
      ipa: "/məˈtɪkjələs/",
      meaning: "tỉ mỉ, cẩn thận",
      examples: ["She is meticulous."],
      definition: "Showing great attention to detail.",
      synonyms: ["thorough", "careful"],
      suggestedTopics: ["Business"],
      cefrLevel: "c1",
    });
  });

  it("falls back to a null cefrLevel for a missing or invalid value, and to empty arrays for missing lists", () => {
    const result = parseLookupResult(
      { headword: "x", meaning: "y" },
      "word",
      "x"
    ) as WordPhraseResult;
    expect(result.cefrLevel).toBeNull();
    expect(result.examples).toEqual([]);
    expect(result.synonyms).toEqual([]);
    expect(result.suggestedTopics).toEqual([]);
  });

  it("falls back to the original query as headword when the AI omits it", () => {
    const result = parseLookupResult({ meaning: "y" }, "phrase", "break the ice") as WordPhraseResult;
    expect(result.headword).toBe("break the ice");
  });

  it("parses a sentence result using the original query, not anything from the AI response", () => {
    const result = parseLookupResult(
      { translation: "Xin chào thế giới." },
      "sentence",
      "Hello world."
    );
    expect(result).toEqual({
      kind: "sentence",
      original: "Hello world.",
      translation: "Xin chào thế giới.",
    });
  });
});
```

- [ ] **Step 10: Run test to verify it fails**

Run: `npm --prefix apps/web test`
Expected: FAIL — `./lookup` does not exist.

- [ ] **Step 11: Implement prompts + result parsing**

Create `apps/web/src/lib/lookup.ts`:

```ts
import type { InputType } from "./inputDetector";
import { LANGUAGE_LABELS, type TargetLanguage } from "./languages";

export interface WordPhraseResult {
  kind: "wordPhrase";
  headword: string;
  inputType: "word" | "phrase";
  ipa: string;
  meaning: string;
  examples: string[];
  definition: string;
  synonyms: string[];
  suggestedTopics: string[];
  cefrLevel: "a1" | "a2" | "b1" | "b2" | "c1" | "c2" | null;
}

export interface SentenceResult {
  kind: "sentence";
  original: string;
  translation: string;
}

export type LookupResult = WordPhraseResult | SentenceResult;

// Ports lib/features/dictionary/data/sources/gemini_dictionary_source.dart's
// _wordPhrasePrompt exactly (field names, topic list, multi-sense handling,
// Vietnamese-script-only instruction) — verified against that file.
export function buildWordPhrasePrompt(query: string, targetLanguage: TargetLanguage): string {
  const languageLabel = LANGUAGE_LABELS[targetLanguage];
  return (
    `You are a language learning assistant helping a Vietnamese speaker learn ${languageLabel}. ` +
    `Look up "${query}" and respond with JSON only (no markdown, no code fences): ` +
    `{"headword":"exact word or phrase","ipa":"IPA transcription",` +
    `"meaning":"Vietnamese definition",` +
    `"definition":"English definition",` +
    `"synonyms":["2-4 English synonyms for this sense, or empty array if none fit"],` +
    `"examples":["example 1 in ${languageLabel}","example 2"],` +
    `"suggestedTopics":["one topic from: Daily Life, Travel, Food & Drink, Business, Technology, Health, Education, Entertainment, Nature, Emotion, Academic, Idioms, Phrasal Verbs, Slang, Social/Casual, Sports, Art & Culture, Science, Law & Politics, Other"],` +
    `"cefrLevel":"a1, a2, b1, b2, c1, or c2 — the CEFR difficulty level of this word or phrase"} ` +
    `If the word has multiple common parts of speech (e.g. "record" as both noun and verb), ` +
    `cover each sense in both "meaning" and "definition" using this format: "(n) ...; (v) ...", ` +
    `and give an IPA per sense too, e.g. "N: /ˈrekɔːrd/; V: /rɪˈkɔːrd/". ` +
    `The "meaning" field must use only Vietnamese script — ` +
    `never Chinese, Japanese, or other non-Vietnamese characters.`
  );
}

// Ports gemini_dictionary_source.dart's _sentencePrompt exactly.
export function buildSentencePrompt(sentence: string): string {
  return (
    `Translate this sentence to Vietnamese: "${sentence}" ` +
    `Use only Vietnamese script in the translation — ` +
    `never Chinese, Japanese, or other non-Vietnamese characters. ` +
    `Respond with JSON only: {"translation":"translated sentence"}`
  );
}

const CEFR_LEVELS = new Set(["a1", "a2", "b1", "b2", "c1", "c2"]);

export function parseLookupResult(
  json: Record<string, unknown>,
  inputType: InputType,
  query: string
): LookupResult {
  if (inputType === "sentence") {
    return {
      kind: "sentence",
      original: query,
      translation: typeof json.translation === "string" ? json.translation : "",
    };
  }

  const rawCefr = typeof json.cefrLevel === "string" ? json.cefrLevel.toLowerCase() : null;
  return {
    kind: "wordPhrase",
    headword: typeof json.headword === "string" ? json.headword : query,
    inputType,
    ipa: typeof json.ipa === "string" ? json.ipa : "",
    meaning: typeof json.meaning === "string" ? json.meaning : "",
    examples: Array.isArray(json.examples) ? json.examples.map(String) : [],
    definition: typeof json.definition === "string" ? json.definition : "",
    synonyms: Array.isArray(json.synonyms) ? json.synonyms.map(String) : [],
    suggestedTopics: Array.isArray(json.suggestedTopics) ? json.suggestedTopics.map(String) : [],
    cefrLevel: rawCefr && CEFR_LEVELS.has(rawCefr) ? (rawCefr as WordPhraseResult["cefrLevel"]) : null,
  };
}
```

- [ ] **Step 12: Run test to verify it passes**

Run: `npm --prefix apps/web test`
Expected: PASS.

- [ ] **Step 13: Commit**

```bash
git add apps/web/src/lib/parseAiJson.ts apps/web/src/lib/parseAiJson.test.ts apps/web/src/lib/inputDetector.ts apps/web/src/lib/inputDetector.test.ts apps/web/src/lib/lookup.ts apps/web/src/lib/lookup.test.ts
git commit -m "feat(web): add Lookup domain logic (AI JSON parsing, input detection, prompts, result parsing)"
```

---

## Task 2: Vocab Bank data layer additions for Lookup

**Files:**
- Modify: `apps/web/src/lib/vocabRecords.ts`
- Modify: `apps/web/src/lib/vocabRecords.test.ts`

**Interfaces:**
- Consumes: `VocabRecord` (already exists in this file).
- Produces: `getVocabRecordByHeadword(uid: string, headword: string, targetLanguage: VocabRecord["targetLanguage"]): Promise<VocabRecord | null>`, `type NewVocabRecord = Omit<VocabRecord, "id">`, `saveVocabRecord(uid: string, record: NewVocabRecord): Promise<string>` (returns the new document's id). Used by Tasks 4-5.

- [ ] **Step 1: Write the failing tests**

Modify `apps/web/src/lib/vocabRecords.test.ts` — add `where` and `setDoc` to the `vi.mock("firebase/firestore", ...)` factory (replace the existing mock block with this one, which adds the two new named exports alongside every existing one):

```ts
vi.mock("firebase/firestore", () => ({
  collection: vi.fn(() => "mock-collection-ref"),
  doc: vi.fn(() => "mock-doc-ref"),
  deleteDoc: vi.fn(),
  updateDoc: vi.fn(),
  setDoc: vi.fn(),
  getDocs: vi.fn(),
  orderBy: vi.fn(() => "mock-order-by"),
  query: vi.fn(() => "mock-query"),
  where: vi.fn(() => "mock-where"),
}));
```

Update the top-level import line to pull in the new functions under test:

```ts
import { deleteDoc, doc, getDocs, orderBy, query, setDoc, updateDoc, where } from "firebase/firestore";
import {
  countVocabRecords,
  deleteVocabRecord,
  getVocabRecordByHeadword,
  getVocabRecords,
  saveVocabRecord,
  updateVocabRecord,
} from "./vocabRecords";
```

Add these test blocks at the end of the file (after the existing `updateVocabRecord` describe block):

```ts
describe("getVocabRecordByHeadword", () => {
  it("queries by headword and targetLanguage, and returns null when nothing matches", async () => {
    vi.mocked(getDocs).mockResolvedValue({ empty: true, docs: [] } as never);

    const result = await getVocabRecordByHeadword("user-123", "meticulous", "english");

    expect(where).toHaveBeenCalledWith("headword", "==", "meticulous");
    expect(where).toHaveBeenCalledWith("targetLanguage", "==", "english");
    expect(query).toHaveBeenCalledWith("mock-collection-ref", "mock-where", "mock-where");
    expect(result).toBeNull();
  });

  it("returns the first matching record with its real Firestore document id", async () => {
    vi.mocked(getDocs).mockResolvedValue({
      empty: false,
      docs: [{ id: "real-doc-id", data: () => RECORD }],
    } as never);

    const result = await getVocabRecordByHeadword("user-123", "meticulous", "english");

    expect(result?.id).toBe("real-doc-id");
    expect(result?.headword).toBe("meticulous");
  });
});

describe("saveVocabRecord", () => {
  it("creates a new document with an auto-generated id and returns it", async () => {
    vi.mocked(doc).mockReturnValue({ id: "new-doc-id" } as never);
    const { id: _omit, ...newRecord } = RECORD;

    const newId = await saveVocabRecord("user-123", newRecord);

    expect(doc).toHaveBeenCalledWith("mock-collection-ref");
    expect(setDoc).toHaveBeenCalledWith({ id: "new-doc-id" }, newRecord);
    expect(newId).toBe("new-doc-id");
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npm --prefix apps/web test`
Expected: FAIL — `getVocabRecordByHeadword`/`saveVocabRecord` not exported yet, and the existing tests fail too since `doc`'s mock return value changed shape (fix this in the next step, not before).

- [ ] **Step 3: Implement**

Replace `apps/web/src/lib/vocabRecords.ts`:

```ts
import { collection, deleteDoc, doc, getDocs, orderBy, query, setDoc, updateDoc, where } from "firebase/firestore";
import { getFirebaseDb } from "./firebase";

export interface VocabRecord {
  id: string;
  headword: string;
  inputType: "word" | "phrase" | "sentence";
  ipa: string;
  meaning: string;
  examples: string[];
  personalNotes: string;
  topicIds: string[];
  targetLanguage: "vietnamese" | "english" | "chinese" | "korean" | "japanese";
  cefrLevel: "a1" | "a2" | "b1" | "b2" | "c1" | "c2";
  activeContext:
    | "general"
    | "business"
    | "technology"
    | "travel"
    | "foodAndDrink"
    | "health"
    | "academic"
    | "socialCasual";
  createdAt: string;
  updatedAt: string;
  nextReviewAt: string | null;
  sm2Repetitions: number;
  sm2EaseFactor: number;
  sm2Interval: number;
  definition: string;
  synonyms: string[];
}

export type VocabRecordUpdate = Pick<VocabRecord, "meaning" | "examples" | "topicIds" | "personalNotes">;
export type NewVocabRecord = Omit<VocabRecord, "id">;

function vocabRecordsCol(uid: string) {
  return collection(getFirebaseDb(), "users", uid, "vocab_records");
}

export async function countVocabRecords(uid: string): Promise<number> {
  const snapshot = await getDocs(vocabRecordsCol(uid));
  return snapshot.size;
}

export async function getVocabRecords(uid: string): Promise<VocabRecord[]> {
  const q = query(vocabRecordsCol(uid), orderBy("createdAt", "desc"));
  const snapshot = await getDocs(q);
  return snapshot.docs.map((d) => ({ ...(d.data() as VocabRecord), id: d.id }));
}

export async function getVocabRecordByHeadword(
  uid: string,
  headword: string,
  targetLanguage: VocabRecord["targetLanguage"]
): Promise<VocabRecord | null> {
  const q = query(
    vocabRecordsCol(uid),
    where("headword", "==", headword),
    where("targetLanguage", "==", targetLanguage)
  );
  const snapshot = await getDocs(q);
  if (snapshot.empty) return null;
  const d = snapshot.docs[0];
  return { ...(d.data() as VocabRecord), id: d.id };
}

export async function deleteVocabRecord(uid: string, id: string): Promise<void> {
  const ref = doc(getFirebaseDb(), "users", uid, "vocab_records", id);
  await deleteDoc(ref);
}

export async function updateVocabRecord(
  uid: string,
  id: string,
  updates: VocabRecordUpdate
): Promise<void> {
  const ref = doc(getFirebaseDb(), "users", uid, "vocab_records", id);
  await updateDoc(ref, { ...updates, updatedAt: new Date().toISOString() });
}

export async function saveVocabRecord(uid: string, record: NewVocabRecord): Promise<string> {
  const ref = doc(vocabRecordsCol(uid));
  await setDoc(ref, record);
  return ref.id;
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `npm --prefix apps/web test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/web/src/lib/vocabRecords.ts apps/web/src/lib/vocabRecords.test.ts
git commit -m "feat(web): add getVocabRecordByHeadword and saveVocabRecord for the Lookup save flow"
```

---

## Task 3: `EditVocabModal` — add a "create" mode for Lookup's save flow

**Files:**
- Modify: `apps/web/src/components/vocab-bank/EditVocabModal.tsx`
- Modify: `apps/web/src/components/vocab-bank/EditVocabModal.test.tsx`

**Interfaces:**
- Produces: `EditVocabModal` gains an optional `mode?: "edit" | "create"` prop (default `"edit"`, so every existing Vocab Bank call site is unaffected). In `"create"` mode, the header text and dialog `aria-label` change from "Sửa" (edit) wording to "Lưu" (save) wording; all field behavior (meaning/examples/topics-max-2/notes, the `onSave`/`onClose` contract) is unchanged. Used by Task 5.

- [ ] **Step 1: Write the failing test**

Add this test to `apps/web/src/components/vocab-bank/EditVocabModal.test.tsx`, inside the existing `describe("EditVocabModal", ...)` block (near the top, after the "prefills the editable fields" test):

```ts
  it("shows 'save' wording instead of 'edit' wording when mode is 'create'", () => {
    render(
      <EditVocabModal
        record={RECORD}
        topics={TOPICS}
        mode="create"
        onClose={vi.fn()}
        onSave={vi.fn()}
      />
    );
    expect(screen.getByRole("dialog", { name: /Lưu từ meticulous/ })).toBeInTheDocument();
    expect(screen.getByText(/Lưu "meticulous" vào Ngân hàng từ vựng/)).toBeInTheDocument();
    expect(screen.queryByText(/^Sửa/)).not.toBeInTheDocument();
  });

  it("defaults to 'edit' wording when mode is omitted (existing Vocab Bank usage)", () => {
    render(<EditVocabModal record={RECORD} topics={TOPICS} onClose={vi.fn()} onSave={vi.fn()} />);
    expect(screen.getByRole("dialog", { name: /Sửa từ meticulous/ })).toBeInTheDocument();
    expect(screen.getByText('Sửa "meticulous"')).toBeInTheDocument();
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm --prefix apps/web test`
Expected: FAIL — `mode` prop not recognized, header text always says "Sửa".

- [ ] **Step 3: Implement the `mode` prop**

Modify `apps/web/src/components/vocab-bank/EditVocabModal.tsx` — add `mode` to the props interface and destructuring, and swap the two text spots that hardcode "Sửa" wording:

```tsx
interface EditVocabModalProps {
  record: VocabRecord;
  topics: Topic[];
  mode?: "edit" | "create";
  onClose: () => void;
  onSave: (updates: VocabRecordUpdate) => Promise<void>;
}

const MAX_TOPICS = 2;

export function EditVocabModal({ record, topics, mode = "edit", onClose, onSave }: EditVocabModalProps) {
```

(Keep every other line of the component body exactly as it is — the `useState` calls, `toggleTopic`, `updateExample`, `removeExample`, `addExample`, `handleSave` are all unchanged.)

Then change the two hardcoded-"Sửa" JSX spots:

```tsx
      <div
        className="modal"
        role="dialog"
        aria-label={mode === "create" ? `Lưu từ ${record.headword}` : `Sửa từ ${record.headword}`}
        onClick={(e) => e.stopPropagation()}
      >
        <div className="modal-header">
          <h3>
            {mode === "create"
              ? `Lưu "${record.headword}" vào Ngân hàng từ vựng`
              : `Sửa "${record.headword}"`}
          </h3>
```

Everything below `<div className="modal-header">`'s closing tag (the close button, `<div className="modal-body">` and everything inside it, and `<div className="modal-footer">`) is unchanged.

- [ ] **Step 4: Run test to verify it passes**

Run: `npm --prefix apps/web test`
Expected: PASS — including every pre-existing test in this file (none of them pass `mode`, so they exercise the default `"edit"` behavior, which is textually identical to before this change).

- [ ] **Step 5: Commit**

```bash
git add apps/web/src/components/vocab-bank/EditVocabModal.tsx apps/web/src/components/vocab-bank/EditVocabModal.test.tsx
git commit -m "feat(web): add a create mode to EditVocabModal for the Lookup save flow"
```

---

## Task 4: Tra từ (Lookup) page — search, cache-check, AI call, display

**Files:**
- Create: `apps/web/src/app/(app)/lookup/page.tsx`
- Create: `apps/web/src/app/(app)/lookup/page.test.tsx`
- Modify: `apps/web/src/styles/bloom.css` (append Lookup result display CSS)

**Interfaces:**
- Consumes: `useAuthUser` (`@/lib/useAuthUser`), `useSettingsContext` (`@/lib/SettingsContext`), `SignInButton` (`@/components/SignInButton`), `detectInputType` (`@/lib/inputDetector`, Task 1), `buildWordPhrasePrompt`/`buildSentencePrompt`/`parseLookupResult`/`LookupResult`/`WordPhraseResult` (`@/lib/lookup`, Task 1), `parseAiJsonObject` (`@/lib/parseAiJson`, Task 1), `generateContent` (`@/lib/generateContent`), `getVocabRecordByHeadword` (`@/lib/vocabRecords`, Task 2).
- Produces: the `/lookup` route (this task has **no save button yet** — Task 5 adds it to this same file).

- [ ] **Step 1: Write the failing test**

Create `apps/web/src/app/(app)/lookup/page.test.tsx`:

```tsx
import { describe, expect, it, vi } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import LookupPage from "./page";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettingsContext } from "@/lib/SettingsContext";
import { getVocabRecordByHeadword } from "@/lib/vocabRecords";
import { generateContent } from "@/lib/generateContent";
import { DEFAULT_SETTINGS } from "@/lib/settings";

vi.mock("@/lib/useAuthUser", () => ({ useAuthUser: vi.fn() }));
vi.mock("@/lib/SettingsContext", () => ({ useSettingsContext: vi.fn() }));
vi.mock("@/lib/vocabRecords", () => ({ getVocabRecordByHeadword: vi.fn() }));
vi.mock("@/lib/generateContent", () => ({ generateContent: vi.fn() }));
vi.mock("@/components/SignInButton", () => ({
  SignInButton: () => <button>Đăng nhập với Google</button>,
}));

const SETTINGS_WITH_KEY = {
  ...DEFAULT_SETTINGS,
  activeProvider: "gemini" as const,
  providers: {
    ...DEFAULT_SETTINGS.providers,
    gemini: { model: "gemini-2.5-flash", apiKeyCiphertext: "cipher-abc" },
  },
};

function mockSignedIn(settings = SETTINGS_WITH_KEY) {
  vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" }, loading: false } as never);
  vi.mocked(useSettingsContext).mockReturnValue({
    settings,
    loading: false,
    error: null,
    save: vi.fn(),
  });
}

describe("LookupPage", () => {
  it("prompts sign-in when logged out", () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: null, loading: false } as never);
    vi.mocked(useSettingsContext).mockReturnValue({
      settings: null,
      loading: false,
      error: null,
      save: vi.fn(),
    });
    render(<LookupPage />);
    expect(screen.getByText("Đăng nhập với Google")).toBeInTheDocument();
  });

  it("shows the cached Vocab Bank record instantly, with no AI call, when the headword is already saved", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecordByHeadword).mockResolvedValue({
      id: "existing-1",
      headword: "meticulous",
      inputType: "word",
      ipa: "/məˈtɪkjələs/",
      meaning: "tỉ mỉ, cẩn thận",
      examples: ["She is meticulous."],
      personalNotes: "",
      topicIds: [],
      targetLanguage: "english",
      cefrLevel: "c1",
      activeContext: "general",
      createdAt: "2026-01-01T00:00:00.000Z",
      updatedAt: "2026-01-01T00:00:00.000Z",
      nextReviewAt: null,
      sm2Repetitions: 0,
      sm2EaseFactor: 2.5,
      sm2Interval: 1,
      definition: "",
      synonyms: [],
    });

    render(<LookupPage />);
    fireEvent.change(screen.getByRole("textbox"), { target: { value: "meticulous" } });
    fireEvent.click(screen.getByRole("button", { name: "Tra từ" }));

    expect(await screen.findByText("tỉ mỉ, cẩn thận")).toBeInTheDocument();
    expect(screen.getByText(/đã có trong Ngân hàng từ vựng/)).toBeInTheDocument();
    expect(generateContent).not.toHaveBeenCalled();
  });

  it("calls generateContent with the active provider/model/ciphertext when not cached, and displays the parsed result", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecordByHeadword).mockResolvedValue(null);
    vi.mocked(generateContent).mockResolvedValue({
      text: JSON.stringify({
        headword: "meticulous",
        ipa: "/məˈtɪkjələs/",
        meaning: "tỉ mỉ, cẩn thận",
        definition: "Showing great attention to detail.",
        synonyms: ["thorough"],
        examples: ["She is meticulous."],
        suggestedTopics: ["Business"],
        cefrLevel: "C1",
      }),
    });

    render(<LookupPage />);
    fireEvent.change(screen.getByRole("textbox"), { target: { value: "meticulous" } });
    fireEvent.click(screen.getByRole("button", { name: "Tra từ" }));

    await waitFor(() =>
      expect(generateContent).toHaveBeenCalledWith({
        provider: "gemini",
        model: "gemini-2.5-flash",
        apiKeyCiphertext: "cipher-abc",
        prompt: expect.stringContaining('"meticulous"'),
      })
    );
    expect(await screen.findByText("tỉ mỉ, cẩn thận")).toBeInTheDocument();
    expect(screen.getByText("Showing great attention to detail.")).toBeInTheDocument();
    expect(screen.getByText("thorough")).toBeInTheDocument();
  });

  it("shows a sentence result as translation-only, with no 'already saved' or save affordance", async () => {
    mockSignedIn();
    vi.mocked(generateContent).mockResolvedValue({
      text: JSON.stringify({ translation: "Xin chào thế giới." }),
    });

    render(<LookupPage />);
    fireEvent.change(screen.getByRole("textbox"), { target: { value: "Hello world." } });
    fireEvent.click(screen.getByRole("button", { name: "Tra từ" }));

    expect(await screen.findByText("Xin chào thế giới.")).toBeInTheDocument();
    expect(getVocabRecordByHeadword).not.toHaveBeenCalled();
  });

  it("shows a helpful message instead of calling the AI when the active provider has no API key saved", async () => {
    mockSignedIn({
      ...DEFAULT_SETTINGS,
      providers: { ...DEFAULT_SETTINGS.providers, gemini: { model: "gemini-2.5-flash", apiKeyCiphertext: null } },
    });
    vi.mocked(getVocabRecordByHeadword).mockResolvedValue(null);

    render(<LookupPage />);
    fireEvent.change(screen.getByRole("textbox"), { target: { value: "meticulous" } });
    fireEvent.click(screen.getByRole("button", { name: "Tra từ" }));

    expect(await screen.findByRole("alert")).toHaveTextContent("Cài đặt");
    expect(generateContent).not.toHaveBeenCalled();
  });

  it("shows an alert when the AI call fails", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecordByHeadword).mockResolvedValue(null);
    vi.mocked(generateContent).mockRejectedValue(new Error("unavailable"));

    render(<LookupPage />);
    fireEvent.change(screen.getByRole("textbox"), { target: { value: "meticulous" } });
    fireEvent.click(screen.getByRole("button", { name: "Tra từ" }));

    await waitFor(() => expect(screen.getByRole("alert")).toHaveTextContent("unavailable"));
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm --prefix apps/web test`
Expected: FAIL — `./page` does not exist under `lookup/`.

- [ ] **Step 3: Implement the page**

Create `apps/web/src/app/(app)/lookup/page.tsx`:

```tsx
"use client";

import { useState } from "react";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettingsContext } from "@/lib/SettingsContext";
import { SignInButton } from "@/components/SignInButton";
import { detectInputType } from "@/lib/inputDetector";
import {
  buildSentencePrompt,
  buildWordPhrasePrompt,
  parseLookupResult,
  type LookupResult,
} from "@/lib/lookup";
import { parseAiJsonObject } from "@/lib/parseAiJson";
import { generateContent } from "@/lib/generateContent";
import { getVocabRecordByHeadword, type VocabRecord } from "@/lib/vocabRecords";

export default function LookupPage() {
  const { user, loading: authLoading } = useAuthUser();
  const { settings } = useSettingsContext();

  const [queryText, setQueryText] = useState("");
  const [result, setResult] = useState<LookupResult | null>(null);
  const [existingRecord, setExistingRecord] = useState<VocabRecord | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleLookup() {
    const trimmed = queryText.trim();
    if (!trimmed || !user || !settings) return;

    setLoading(true);
    setError(null);
    setResult(null);
    setExistingRecord(null);

    try {
      const inputType = detectInputType(trimmed);

      if (inputType !== "sentence") {
        const cached = await getVocabRecordByHeadword(user.uid, trimmed, settings.targetLanguage);
        if (cached) {
          setExistingRecord(cached);
          setResult({
            kind: "wordPhrase",
            headword: cached.headword,
            inputType: cached.inputType === "sentence" ? "word" : cached.inputType,
            ipa: cached.ipa,
            meaning: cached.meaning,
            examples: cached.examples,
            definition: cached.definition,
            synonyms: cached.synonyms,
            suggestedTopics: [],
            cefrLevel: cached.cefrLevel,
          });
          setLoading(false);
          return;
        }
      }

      const activeConfig = settings.providers[settings.activeProvider];
      if (!activeConfig.apiKeyCiphertext) {
        setError("Chưa có API key cho nhà cung cấp AI đang chọn — vào Cài đặt để thêm.");
        setLoading(false);
        return;
      }

      const prompt =
        inputType === "sentence"
          ? buildSentencePrompt(trimmed)
          : buildWordPhrasePrompt(trimmed, settings.targetLanguage);

      const response = await generateContent({
        provider: settings.activeProvider,
        model: activeConfig.model,
        apiKeyCiphertext: activeConfig.apiKeyCiphertext,
        prompt,
      });

      const json = parseAiJsonObject(response.text);
      setResult(parseLookupResult(json, inputType, trimmed));
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setLoading(false);
    }
  }

  if (authLoading) {
    return (
      <div>
        <h2 className="scr-title">Tra từ</h2>
        <p>Đang tải…</p>
      </div>
    );
  }

  if (!user) {
    return (
      <div>
        <h2 className="scr-title">Tra từ</h2>
        <p className="scr-sub">Đăng nhập để tra từ.</p>
        <SignInButton />
      </div>
    );
  }

  return (
    <div>
      <h2 className="scr-title">Tra từ</h2>
      <p className="scr-sub">Tra từ, cụm từ, hoặc cả câu — dịch bằng AI theo Cài đặt của bạn.</p>
      <div className="lookup-search-row">
        <input
          value={queryText}
          onChange={(e) => setQueryText(e.target.value)}
          placeholder="Nhập từ, cụm từ, hoặc câu…"
        />
        <button className="btn-primary" onClick={() => void handleLookup()} disabled={loading || !queryText.trim()}>
          {loading ? "Đang tra…" : "Tra từ"}
        </button>
      </div>
      {error && <p role="alert">{error}</p>}
      {result?.kind === "sentence" && (
        <div className="lookup-result-card">
          <p className="lookup-sentence-original">{result.original}</p>
          <p className="lookup-sentence-translation">{result.translation}</p>
        </div>
      )}
      {result?.kind === "wordPhrase" && (
        <div className="lookup-result-card">
          {existingRecord && (
            <p className="lookup-already-saved">Từ này đã có trong Ngân hàng từ vựng của bạn.</p>
          )}
          <div className="lookup-headword-row">
            <h3>{result.headword}</h3>
            {result.cefrLevel && <span className="cefr-pill">{result.cefrLevel.toUpperCase()}</span>}
          </div>
          {result.ipa && <p className="lookup-ipa">{result.ipa}</p>}
          <p className="lookup-meaning">{result.meaning}</p>
          {result.definition && <p className="lookup-definition">{result.definition}</p>}
          {result.synonyms.length > 0 && (
            <div className="chip-row">
              {result.synonyms.map((s) => (
                <span className="chip" key={s}>
                  {s}
                </span>
              ))}
            </div>
          )}
          {result.examples.map((ex, i) => (
            <p className="lookup-example" key={i}>
              {ex}
            </p>
          ))}
        </div>
      )}
    </div>
  );
}
```

- [ ] **Step 4: Append Lookup result display CSS**

Modify `apps/web/src/styles/bloom.css` — append at the end:

```css

.lookup-search-row {
  display: flex;
  gap: 10px;
  margin-bottom: 20px;
  max-width: 560px;
}

.lookup-search-row input {
  flex: 1;
  padding: 10px 14px;
  border-radius: 999px;
  border: 1px solid var(--border);
  background: var(--surface-2);
  color: var(--ink);
  font-size: 14px;
}

.lookup-result-card {
  max-width: 560px;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 20px;
  padding: 22px 26px;
}

.lookup-already-saved {
  color: var(--sage);
  font-size: 12.5px;
  font-weight: 700;
  margin: 0 0 12px;
}

.lookup-headword-row {
  display: flex;
  align-items: center;
  gap: 10px;
}

.lookup-headword-row h3 {
  margin: 0;
  font-size: 22px;
}

.lookup-ipa {
  color: var(--ink-soft);
  font-family: ui-monospace, monospace;
  font-size: 13px;
  margin: 4px 0 14px;
}

.lookup-meaning {
  font-size: 16px;
  font-weight: 600;
  margin: 0 0 8px;
}

.lookup-definition {
  color: var(--ink-soft);
  font-style: italic;
  font-size: 13.5px;
  margin: 0 0 14px;
}

.lookup-example {
  color: var(--ink-soft);
  font-size: 13.5px;
  margin: 6px 0;
}

.lookup-sentence-original {
  font-size: 15px;
  margin: 0 0 10px;
}

.lookup-sentence-translation {
  color: var(--ink-soft);
  font-size: 15px;
  margin: 0;
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `npm --prefix apps/web test`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add "apps/web/src/app/(app)/lookup" apps/web/src/styles/bloom.css
git commit -m "feat(web): add Tra từ (Lookup) page — cache-check, AI call, result display"
```

---

## Task 5: Wire the save-to-Vocab-Bank flow into Tra từ

**Files:**
- Modify: `apps/web/src/app/(app)/lookup/page.tsx`
- Modify: `apps/web/src/app/(app)/lookup/page.test.tsx`
- Modify: `apps/web/src/styles/bloom.css` (append the "Lưu" button spacing rule)

**Interfaces:**
- Consumes: `EditVocabModal` (`@/components/vocab-bank/EditVocabModal`, Task 3, in `mode="create"`), `getTopics`/`Topic` (`@/lib/topics`), `saveVocabRecord`/`NewVocabRecord` (`@/lib/vocabRecords`, Task 2).
- Produces: nothing new for later tasks — this is the last Lookup task.

**Important known gap, deliberate, not to be silently "fixed" here:** `VocabRecord.activeContext` has no corresponding field in `UserSettings` (Cài đặt never added a "ngữ cảnh" setting — only `targetLanguage` was added, per that sub-spec). Saved records default `activeContext` to `"general"`. This also means `buildWordPhrasePrompt` (Task 1) does not include Flutter's "Shape examples for context: ..." prompt line — there's no web setting to source it from. If context customization is wanted later, that's new scope for its own spec, not a bug in this task.

- [ ] **Step 1: Write the failing tests**

Add these imports to the top of `apps/web/src/app/(app)/lookup/page.test.tsx` (alongside the existing ones):

```tsx
import { getTopics } from "@/lib/topics";
import { saveVocabRecord } from "@/lib/vocabRecords";
```

Add these two `vi.mock` calls alongside the existing ones:

```tsx
vi.mock("@/lib/topics", () => ({ getTopics: vi.fn() }));
```

(`saveVocabRecord` is already covered by the existing `vi.mock("@/lib/vocabRecords", ...)` factory — extend that factory to include it: replace `vi.mock("@/lib/vocabRecords", () => ({ getVocabRecordByHeadword: vi.fn() }));` with `vi.mock("@/lib/vocabRecords", () => ({ getVocabRecordByHeadword: vi.fn(), saveVocabRecord: vi.fn() }));`.)

Add a default `getTopics` mock resolution inside the `mockSignedIn` helper, right after the existing `vi.mocked(useSettingsContext).mockReturnValue(...)` line:

```tsx
  vi.mocked(getTopics).mockResolvedValue([]);
```

Add these test cases at the end of the `describe("LookupPage", ...)` block:

```tsx
  it("shows a Lưu button for a fresh word/phrase result, but not for an already-saved one or a sentence", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecordByHeadword).mockResolvedValue(null);
    vi.mocked(generateContent).mockResolvedValue({
      text: JSON.stringify({ headword: "meticulous", meaning: "tỉ mỉ" }),
    });

    render(<LookupPage />);
    fireEvent.change(screen.getByRole("textbox"), { target: { value: "meticulous" } });
    fireEvent.click(screen.getByRole("button", { name: "Tra từ" }));

    expect(await screen.findByRole("button", { name: /Lưu vào Ngân hàng từ vựng/ })).toBeInTheDocument();
  });

  it("opens EditVocabModal in create mode when Lưu is clicked, and saves via saveVocabRecord", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecordByHeadword).mockResolvedValue(null);
    vi.mocked(generateContent).mockResolvedValue({
      text: JSON.stringify({
        headword: "meticulous",
        ipa: "/məˈtɪkjələs/",
        meaning: "tỉ mỉ, cẩn thận",
        examples: ["She is meticulous."],
        cefrLevel: "C1",
      }),
    });
    vi.mocked(saveVocabRecord).mockResolvedValue("new-id");

    render(<LookupPage />);
    fireEvent.change(screen.getByRole("textbox"), { target: { value: "meticulous" } });
    fireEvent.click(screen.getByRole("button", { name: "Tra từ" }));
    fireEvent.click(await screen.findByRole("button", { name: /Lưu vào Ngân hàng từ vựng/ }));

    expect(screen.getByRole("dialog", { name: /Lưu từ meticulous/ })).toBeInTheDocument();

    fireEvent.click(screen.getByRole("button", { name: "Lưu" }));

    await waitFor(() =>
      expect(saveVocabRecord).toHaveBeenCalledWith(
        "u1",
        expect.objectContaining({
          headword: "meticulous",
          ipa: "/məˈtɪkjələs/",
          meaning: "tỉ mỉ, cẩn thận",
          examples: ["She is meticulous."],
          cefrLevel: "c1",
          targetLanguage: "english",
          activeContext: "general",
          topicIds: [],
          personalNotes: "",
        })
      )
    );
  });

  it("pre-selects a suggested topic that matches an existing topic name (case-insensitive), capped at 2", async () => {
    mockSignedIn();
    vi.mocked(getTopics).mockResolvedValue([
      { id: "biz-1", name: "Business", emoji: "💼", isPredefined: true, createdAt: "2026-01-01" },
    ]);
    vi.mocked(getVocabRecordByHeadword).mockResolvedValue(null);
    vi.mocked(generateContent).mockResolvedValue({
      text: JSON.stringify({
        headword: "meticulous",
        meaning: "tỉ mỉ",
        suggestedTopics: ["business"],
      }),
    });

    render(<LookupPage />);
    fireEvent.change(screen.getByRole("textbox"), { target: { value: "meticulous" } });
    fireEvent.click(screen.getByRole("button", { name: "Tra từ" }));
    fireEvent.click(await screen.findByRole("button", { name: /Lưu vào Ngân hàng từ vựng/ }));

    expect(screen.getByRole("button", { name: "Business" })).toHaveClass("active");
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npm --prefix apps/web test`
Expected: FAIL — no "Lưu" button rendered, `getTopics`/`saveVocabRecord` not called.

- [ ] **Step 3: Implement**

Replace `apps/web/src/app/(app)/lookup/page.tsx`:

```tsx
"use client";

import { useEffect, useState } from "react";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettingsContext } from "@/lib/SettingsContext";
import { SignInButton } from "@/components/SignInButton";
import { EditVocabModal } from "@/components/vocab-bank/EditVocabModal";
import { detectInputType } from "@/lib/inputDetector";
import {
  buildSentencePrompt,
  buildWordPhrasePrompt,
  parseLookupResult,
  type LookupResult,
  type WordPhraseResult,
} from "@/lib/lookup";
import { parseAiJsonObject } from "@/lib/parseAiJson";
import { generateContent } from "@/lib/generateContent";
import { getTopics, type Topic } from "@/lib/topics";
import {
  getVocabRecordByHeadword,
  saveVocabRecord,
  type NewVocabRecord,
  type VocabRecord,
  type VocabRecordUpdate,
} from "@/lib/vocabRecords";

const MAX_PRESELECTED_TOPICS = 2;

function preselectTopicIds(suggestedTopics: string[], topics: Topic[]): string[] {
  const selected: string[] = [];
  for (const suggestion of suggestedTopics) {
    if (selected.length >= MAX_PRESELECTED_TOPICS) break;
    const match = topics.find((t) => t.name.toLowerCase() === suggestion.toLowerCase());
    if (match) selected.push(match.id);
  }
  return selected;
}

export default function LookupPage() {
  const { user, loading: authLoading } = useAuthUser();
  const { settings } = useSettingsContext();

  const [queryText, setQueryText] = useState("");
  const [result, setResult] = useState<LookupResult | null>(null);
  const [existingRecord, setExistingRecord] = useState<VocabRecord | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [topics, setTopics] = useState<Topic[]>([]);
  const [saveModalOpen, setSaveModalOpen] = useState(false);

  useEffect(() => {
    if (!user) return;
    getTopics(user.uid).then(setTopics).catch(() => setTopics([]));
  }, [user]);

  async function handleLookup() {
    const trimmed = queryText.trim();
    if (!trimmed || !user || !settings) return;

    setLoading(true);
    setError(null);
    setResult(null);
    setExistingRecord(null);

    try {
      const inputType = detectInputType(trimmed);

      if (inputType !== "sentence") {
        const cached = await getVocabRecordByHeadword(user.uid, trimmed, settings.targetLanguage);
        if (cached) {
          setExistingRecord(cached);
          setResult({
            kind: "wordPhrase",
            headword: cached.headword,
            inputType: cached.inputType === "sentence" ? "word" : cached.inputType,
            ipa: cached.ipa,
            meaning: cached.meaning,
            examples: cached.examples,
            definition: cached.definition,
            synonyms: cached.synonyms,
            suggestedTopics: [],
            cefrLevel: cached.cefrLevel,
          });
          setLoading(false);
          return;
        }
      }

      const activeConfig = settings.providers[settings.activeProvider];
      if (!activeConfig.apiKeyCiphertext) {
        setError("Chưa có API key cho nhà cung cấp AI đang chọn — vào Cài đặt để thêm.");
        setLoading(false);
        return;
      }

      const prompt =
        inputType === "sentence"
          ? buildSentencePrompt(trimmed)
          : buildWordPhrasePrompt(trimmed, settings.targetLanguage);

      const response = await generateContent({
        provider: settings.activeProvider,
        model: activeConfig.model,
        apiKeyCiphertext: activeConfig.apiKeyCiphertext,
        prompt,
      });

      const json = parseAiJsonObject(response.text);
      setResult(parseLookupResult(json, inputType, trimmed));
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setLoading(false);
    }
  }

  function buildDraftRecord(wordResult: WordPhraseResult): VocabRecord {
    const now = new Date().toISOString();
    return {
      id: "",
      headword: wordResult.headword,
      inputType: wordResult.inputType,
      ipa: wordResult.ipa,
      meaning: wordResult.meaning,
      examples: wordResult.examples,
      personalNotes: "",
      topicIds: preselectTopicIds(wordResult.suggestedTopics, topics),
      // No "ngữ cảnh" (context) setting exists in Cài đặt yet — default to
      // "general" for every web-saved record (see Task 5's plan note).
      targetLanguage: settings?.targetLanguage ?? "english",
      cefrLevel: wordResult.cefrLevel ?? "b1",
      activeContext: "general",
      createdAt: now,
      updatedAt: now,
      nextReviewAt: null,
      sm2Repetitions: 0,
      sm2EaseFactor: 2.5,
      sm2Interval: 1,
      definition: wordResult.definition,
      synonyms: wordResult.synonyms,
    };
  }

  async function handleSaveNewRecord(updates: VocabRecordUpdate) {
    if (!user || result?.kind !== "wordPhrase") return;
    const draft = buildDraftRecord(result);
    const { id: _omit, ...newRecord }: { id: string } & NewVocabRecord = { ...draft, ...updates };
    const newId = await saveVocabRecord(user.uid, newRecord);
    setSaveModalOpen(false);
    setExistingRecord({ ...draft, ...updates, id: newId });
  }

  if (authLoading) {
    return (
      <div>
        <h2 className="scr-title">Tra từ</h2>
        <p>Đang tải…</p>
      </div>
    );
  }

  if (!user) {
    return (
      <div>
        <h2 className="scr-title">Tra từ</h2>
        <p className="scr-sub">Đăng nhập để tra từ.</p>
        <SignInButton />
      </div>
    );
  }

  return (
    <div>
      <h2 className="scr-title">Tra từ</h2>
      <p className="scr-sub">Tra từ, cụm từ, hoặc cả câu — dịch bằng AI theo Cài đặt của bạn.</p>
      <div className="lookup-search-row">
        <input
          value={queryText}
          onChange={(e) => setQueryText(e.target.value)}
          placeholder="Nhập từ, cụm từ, hoặc câu…"
        />
        <button className="btn-primary" onClick={() => void handleLookup()} disabled={loading || !queryText.trim()}>
          {loading ? "Đang tra…" : "Tra từ"}
        </button>
      </div>
      {error && <p role="alert">{error}</p>}
      {result?.kind === "sentence" && (
        <div className="lookup-result-card">
          <p className="lookup-sentence-original">{result.original}</p>
          <p className="lookup-sentence-translation">{result.translation}</p>
        </div>
      )}
      {result?.kind === "wordPhrase" && (
        <div className="lookup-result-card">
          {existingRecord && (
            <p className="lookup-already-saved">Từ này đã có trong Ngân hàng từ vựng của bạn.</p>
          )}
          <div className="lookup-headword-row">
            <h3>{result.headword}</h3>
            {result.cefrLevel && <span className="cefr-pill">{result.cefrLevel.toUpperCase()}</span>}
          </div>
          {result.ipa && <p className="lookup-ipa">{result.ipa}</p>}
          <p className="lookup-meaning">{result.meaning}</p>
          {result.definition && <p className="lookup-definition">{result.definition}</p>}
          {result.synonyms.length > 0 && (
            <div className="chip-row">
              {result.synonyms.map((s) => (
                <span className="chip" key={s}>
                  {s}
                </span>
              ))}
            </div>
          )}
          {result.examples.map((ex, i) => (
            <p className="lookup-example" key={i}>
              {ex}
            </p>
          ))}
          {!existingRecord && (
            <button className="btn-primary lookup-save-btn" onClick={() => setSaveModalOpen(true)}>
              Lưu vào Ngân hàng từ vựng
            </button>
          )}
        </div>
      )}
      {saveModalOpen && result?.kind === "wordPhrase" && (
        <EditVocabModal
          record={buildDraftRecord(result)}
          topics={topics}
          mode="create"
          onClose={() => setSaveModalOpen(false)}
          onSave={handleSaveNewRecord}
        />
      )}
    </div>
  );
}
```

- [ ] **Step 4: Append the "Lưu" button spacing rule**

Modify `apps/web/src/styles/bloom.css` — append at the end:

```css

.lookup-save-btn {
  margin-top: 18px;
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `npm --prefix apps/web test`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add "apps/web/src/app/(app)/lookup" apps/web/src/styles/bloom.css
git commit -m "feat(web): wire the save-to-Vocab-Bank flow into Tra từ"
```

---

## Task 6: Sidebar — rename "Luyện tập" to "Ôn tập"

**Files:**
- Modify: `apps/web/src/components/shell/Sidebar.tsx`
- Modify: `apps/web/src/components/shell/Sidebar.test.tsx`

**Interfaces:** none — display-label-only change, route path `/practice` unchanged.

- [ ] **Step 1: Write the failing test**

Modify `apps/web/src/components/shell/Sidebar.test.tsx` — the file's existing tests don't query by the "Luyện tập"/"Ôn tập" text directly, so no test currently pins the label text. Add a new test to the existing `describe("Sidebar", ...)` block:

```tsx
  it("labels the practice nav item 'Ôn tập', not 'Luyện tập'", () => {
    vi.mocked(usePathname).mockReturnValue("/vocab-bank");
    render(<Sidebar />);
    expect(screen.getByRole("link", { name: /Ôn tập/ })).toHaveAttribute("href", "/practice");
    expect(screen.queryByText(/Luyện tập/)).not.toBeInTheDocument();
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm --prefix apps/web test`
Expected: FAIL — the link's accessible name is still "🎯 Luyện tập".

- [ ] **Step 3: Rename the label**

Modify `apps/web/src/components/shell/Sidebar.tsx` — change one line inside `NAV_GROUPS`:

```tsx
      { href: "/practice", label: "🎯 Ôn tập" },
```

(This replaces the existing `{ href: "/practice", label: "🎯 Luyện tập" },` line — nothing else in the file changes.)

- [ ] **Step 4: Run test to verify it passes**

Run: `npm --prefix apps/web test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/web/src/components/shell/Sidebar.tsx apps/web/src/components/shell/Sidebar.test.tsx
git commit -m "feat(web): rename Sidebar's Luyện tập nav item to Ôn tập"
```

---

## Task 7: SM-2 compute utility + Firestore write

**Files:**
- Create: `apps/web/src/lib/sm2.ts`
- Create: `apps/web/src/lib/sm2.test.ts`
- Modify: `apps/web/src/lib/vocabRecords.ts`
- Modify: `apps/web/src/lib/vocabRecords.test.ts`

**Interfaces:**
- Produces: `interface Sm2Fields { sm2Repetitions: number; sm2EaseFactor: number; sm2Interval: number; nextReviewAt: string; updatedAt: string }`, `computeSm2(record: { sm2Repetitions: number; sm2EaseFactor: number; sm2Interval: number }, quality: number, now?: Date): Sm2Fields` (`@/lib/sm2`); `updateVocabRecordSm2(uid: string, id: string, sm2Fields: Sm2Fields): Promise<void>` (`@/lib/vocabRecords`). Used by Task 12 (session result screen).

- [ ] **Step 1: Write the failing test for `computeSm2`**

Create `apps/web/src/lib/sm2.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import { computeSm2 } from "./sm2";

const NOW = new Date("2026-08-16T12:00:00.000Z");

describe("computeSm2", () => {
  it("resets repetitions and schedules tomorrow when quality is below 3, leaving ease factor unchanged", () => {
    const result = computeSm2({ sm2Repetitions: 4, sm2EaseFactor: 2.3, sm2Interval: 12 }, 1, NOW);
    expect(result.sm2Repetitions).toBe(0);
    expect(result.sm2Interval).toBe(1);
    expect(result.sm2EaseFactor).toBe(2.3);
    expect(result.nextReviewAt).toBe("2026-08-17T12:00:00.000Z");
    expect(result.updatedAt).toBe("2026-08-16T12:00:00.000Z");
  });

  it("uses a 1-day interval for the first successful repetition", () => {
    const result = computeSm2({ sm2Repetitions: 0, sm2EaseFactor: 2.5, sm2Interval: 1 }, 5, NOW);
    expect(result.sm2Repetitions).toBe(1);
    expect(result.sm2Interval).toBe(1);
    expect(result.nextReviewAt).toBe("2026-08-17T12:00:00.000Z");
  });

  it("uses a 6-day interval for the second successful repetition", () => {
    const result = computeSm2({ sm2Repetitions: 1, sm2EaseFactor: 2.5, sm2Interval: 1 }, 5, NOW);
    expect(result.sm2Repetitions).toBe(2);
    expect(result.sm2Interval).toBe(6);
    expect(result.nextReviewAt).toBe("2026-08-22T12:00:00.000Z");
  });

  it("uses interval × easeFactor, rounded, for the third and later repetitions", () => {
    const result = computeSm2({ sm2Repetitions: 2, sm2EaseFactor: 2.0, sm2Interval: 6 }, 5, NOW);
    expect(result.sm2Repetitions).toBe(3);
    expect(result.sm2Interval).toBe(12); // round(6 * 2.0)
  });

  it("increases ease factor for quality 5, clamped at the 2.5 maximum", () => {
    const result = computeSm2({ sm2Repetitions: 2, sm2EaseFactor: 2.5, sm2Interval: 6 }, 5, NOW);
    expect(result.sm2EaseFactor).toBe(2.5); // 2.5 + 0.1 - 0 = 2.6, clamped down to 2.5
  });

  it("decreases ease factor for a barely-passing quality 3, clamped at the 1.3 minimum", () => {
    const result = computeSm2({ sm2Repetitions: 2, sm2EaseFactor: 1.3, sm2Interval: 6 }, 3, NOW);
    expect(result.sm2EaseFactor).toBe(1.3); // 1.3 + 0.1 - 0.16 = 1.24, clamped up to 1.3
  });

  it("matches the exact quality-4 ease-factor formula with no clamping needed", () => {
    const result = computeSm2({ sm2Repetitions: 2, sm2EaseFactor: 2.0, sm2Interval: 6 }, 4, NOW);
    expect(result.sm2EaseFactor).toBeCloseTo(2.02, 5); // 2.0 + 0.1 - (5-4)*0.08 = 2.02
  });

  it("defaults `now` to the current time when omitted", () => {
    const before = Date.now();
    const result = computeSm2({ sm2Repetitions: 0, sm2EaseFactor: 2.5, sm2Interval: 1 }, 5);
    const after = Date.now();
    const updatedAtMs = new Date(result.updatedAt).getTime();
    expect(updatedAtMs).toBeGreaterThanOrEqual(before);
    expect(updatedAtMs).toBeLessThanOrEqual(after);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm --prefix apps/web test`
Expected: FAIL — `./sm2` does not exist.

- [ ] **Step 3: Implement `computeSm2`**

Create `apps/web/src/lib/sm2.ts`:

```ts
// Ports lib/features/practice/domain/use_cases/compute_sm2_use_case.dart
// exactly — verified against that file. This is shared production data with
// the Flutter app; do not change the constants or branch structure without
// updating both sides.
export interface Sm2Fields {
  sm2Repetitions: number;
  sm2EaseFactor: number;
  sm2Interval: number;
  nextReviewAt: string;
  updatedAt: string;
}

const MIN_EASE_FACTOR = 1.3;
const MAX_EASE_FACTOR = 2.5;

function addDays(date: Date, days: number): Date {
  const result = new Date(date);
  result.setUTCDate(result.getUTCDate() + days);
  return result;
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(Math.max(value, min), max);
}

export function computeSm2(
  record: { sm2Repetitions: number; sm2EaseFactor: number; sm2Interval: number },
  quality: number,
  now: Date = new Date()
): Sm2Fields {
  if (quality < 3) {
    return {
      sm2Repetitions: 0,
      sm2EaseFactor: record.sm2EaseFactor,
      sm2Interval: 1,
      nextReviewAt: addDays(now, 1).toISOString(),
      updatedAt: now.toISOString(),
    };
  }

  const newInterval =
    record.sm2Repetitions === 0
      ? 1
      : record.sm2Repetitions === 1
        ? 6
        : Math.round(record.sm2Interval * record.sm2EaseFactor);

  const newEaseFactor = clamp(
    record.sm2EaseFactor + 0.1 - (5 - quality) * 0.08,
    MIN_EASE_FACTOR,
    MAX_EASE_FACTOR
  );

  return {
    sm2Repetitions: record.sm2Repetitions + 1,
    sm2EaseFactor: newEaseFactor,
    sm2Interval: newInterval,
    nextReviewAt: addDays(now, newInterval).toISOString(),
    updatedAt: now.toISOString(),
  };
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm --prefix apps/web test`
Expected: PASS.

- [ ] **Step 5: Write the failing test for `updateVocabRecordSm2`**

Add this import to `apps/web/src/lib/vocabRecords.test.ts` (alongside the existing ones):

```ts
import type { Sm2Fields } from "./sm2";
```

And add `updateVocabRecordSm2` to the existing named-import line from `./vocabRecords`:

```ts
import {
  countVocabRecords,
  deleteVocabRecord,
  getVocabRecordByHeadword,
  getVocabRecords,
  saveVocabRecord,
  updateVocabRecord,
  updateVocabRecordSm2,
} from "./vocabRecords";
```

Add this test block at the end of the file:

```ts
describe("updateVocabRecordSm2", () => {
  it("writes exactly the SM-2 fields, by document id, with no updatedAt override of its own", async () => {
    const sm2Fields: Sm2Fields = {
      sm2Repetitions: 3,
      sm2EaseFactor: 2.4,
      sm2Interval: 12,
      nextReviewAt: "2026-08-28T12:00:00.000Z",
      updatedAt: "2026-08-16T12:00:00.000Z",
    };

    await updateVocabRecordSm2("user-123", "abc", sm2Fields);

    expect(doc).toHaveBeenCalledWith("mock-db", "users", "user-123", "vocab_records", "abc");
    expect(updateDoc).toHaveBeenCalledWith("mock-doc-ref", sm2Fields);
  });
});
```

- [ ] **Step 6: Run test to verify it fails**

Run: `npm --prefix apps/web test`
Expected: FAIL — `updateVocabRecordSm2` not exported yet.

- [ ] **Step 7: Implement `updateVocabRecordSm2`**

Modify `apps/web/src/lib/vocabRecords.ts` — add the import and the new function. Change the top import line to:

```ts
import { collection, deleteDoc, doc, getDocs, orderBy, query, setDoc, updateDoc, where } from "firebase/firestore";
import { getFirebaseDb } from "./firebase";
import type { Sm2Fields } from "./sm2";
```

Add this function at the end of the file (after `saveVocabRecord`):

```ts
export async function updateVocabRecordSm2(uid: string, id: string, sm2Fields: Sm2Fields): Promise<void> {
  const ref = doc(getFirebaseDb(), "users", uid, "vocab_records", id);
  await updateDoc(ref, sm2Fields);
}
```

(Unlike `updateVocabRecord`, this does **not** append its own `updatedAt: new Date().toISOString()` — the caller (Task 12's result screen) already computed `updatedAt` as part of `Sm2Fields` via `computeSm2`, using one consistent `now` for the whole batch rather than a slightly-different timestamp per Firestore write.)

- [ ] **Step 8: Run tests to verify they pass**

Run: `npm --prefix apps/web test`
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add apps/web/src/lib/sm2.ts apps/web/src/lib/sm2.test.ts apps/web/src/lib/vocabRecords.ts apps/web/src/lib/vocabRecords.test.ts
git commit -m "feat(web): add SM-2 compute utility and updateVocabRecordSm2"
```

---

## Task 8: Ôn tập session word-pool selection

**Files:**
- Create: `apps/web/src/lib/practiceSession.ts`
- Create: `apps/web/src/lib/practiceSession.test.ts`

**Interfaces:**
- Consumes: `VocabRecord` (`@/lib/vocabRecords`).
- Produces: `interface SessionWordFilters { topicIds: Set<string>; maxCefr: VocabRecord["cefrLevel"] | null; count: number | null }`, `selectSessionWords(records: VocabRecord[], filters: SessionWordFilters, now?: Date): VocabRecord[]` (`@/lib/practiceSession`). Used by Task 10 (session setup screen).

Pure function, no Firestore — operates on an already-loaded `VocabRecord[]` (matches how Vocab Bank's own filters already work entirely client-side over an already-fetched list).

- [ ] **Step 1: Write the failing test**

Create `apps/web/src/lib/practiceSession.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import { selectSessionWords } from "./practiceSession";
import type { VocabRecord } from "./vocabRecords";

function makeRecord(overrides: Partial<VocabRecord>): VocabRecord {
  return {
    id: "id",
    headword: "word",
    inputType: "word",
    ipa: "",
    meaning: "nghĩa",
    examples: [],
    personalNotes: "",
    topicIds: [],
    targetLanguage: "english",
    cefrLevel: "b1",
    activeContext: "general",
    createdAt: "2026-01-01T00:00:00.000Z",
    updatedAt: "2026-01-01T00:00:00.000Z",
    nextReviewAt: null,
    sm2Repetitions: 0,
    sm2EaseFactor: 2.5,
    sm2Interval: 1,
    definition: "",
    synonyms: [],
    ...overrides,
  };
}

const NOW = new Date("2026-08-16T12:00:00.000Z");

describe("selectSessionWords", () => {
  it("prefers due words (null or past nextReviewAt) over not-yet-due ones", () => {
    const due = makeRecord({ id: "due-1", nextReviewAt: null });
    const notDue = makeRecord({ id: "not-due-1", nextReviewAt: "2099-01-01T00:00:00.000Z" });

    const result = selectSessionWords(
      [due, notDue],
      { topicIds: new Set(), maxCefr: null, count: null },
      NOW
    );

    expect(result.map((r) => r.id)).toEqual(["due-1"]);
  });

  it("falls back to any matching word when none are due", () => {
    const notDue1 = makeRecord({ id: "a", nextReviewAt: "2099-01-01T00:00:00.000Z" });
    const notDue2 = makeRecord({ id: "b", nextReviewAt: "2099-01-01T00:00:00.000Z" });

    const result = selectSessionWords(
      [notDue1, notDue2],
      { topicIds: new Set(), maxCefr: null, count: null },
      NOW
    );

    expect(result.map((r) => r.id).sort()).toEqual(["a", "b"]);
  });

  it("treats a nextReviewAt exactly equal to now as due", () => {
    const dueNow = makeRecord({ id: "x", nextReviewAt: NOW.toISOString() });
    const result = selectSessionWords(
      [dueNow],
      { topicIds: new Set(), maxCefr: null, count: null },
      NOW
    );
    expect(result.map((r) => r.id)).toEqual(["x"]);
  });

  it("filters by topic (OR within the selected topics)", () => {
    const business = makeRecord({ id: "biz", topicIds: ["business"] });
    const travel = makeRecord({ id: "travel", topicIds: ["travel"] });
    const neither = makeRecord({ id: "neither", topicIds: ["academic"] });

    const result = selectSessionWords(
      [business, travel, neither],
      { topicIds: new Set(["business", "travel"]), maxCefr: null, count: null },
      NOW
    );

    expect(result.map((r) => r.id).sort()).toEqual(["biz", "travel"]);
  });

  it("filters by maximum CEFR level", () => {
    const a1 = makeRecord({ id: "a1", cefrLevel: "a1" });
    const c1 = makeRecord({ id: "c1", cefrLevel: "c1" });

    const result = selectSessionWords([a1, c1], { topicIds: new Set(), maxCefr: "b1", count: null }, NOW);

    expect(result.map((r) => r.id)).toEqual(["a1"]);
  });

  it("truncates to the requested count", () => {
    const records = Array.from({ length: 10 }, (_, i) => makeRecord({ id: `w${i}` }));

    const result = selectSessionWords(records, { topicIds: new Set(), maxCefr: null, count: 3 }, NOW);

    expect(result).toHaveLength(3);
  });

  it("returns every matching word when count is null ('Tất cả')", () => {
    const records = Array.from({ length: 10 }, (_, i) => makeRecord({ id: `w${i}` }));

    const result = selectSessionWords(records, { topicIds: new Set(), maxCefr: null, count: null }, NOW);

    expect(result).toHaveLength(10);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm --prefix apps/web test`
Expected: FAIL — `./practiceSession` does not exist.

- [ ] **Step 3: Implement**

Create `apps/web/src/lib/practiceSession.ts`:

```ts
import type { VocabRecord } from "./vocabRecords";

const CEFR_ORDER: readonly VocabRecord["cefrLevel"][] = ["a1", "a2", "b1", "b2", "c1", "c2"];

export interface SessionWordFilters {
  topicIds: Set<string>;
  maxCefr: VocabRecord["cefrLevel"] | null;
  count: number | null; // null = "Tất cả" — no truncation
}

function isDue(record: VocabRecord, now: Date): boolean {
  return record.nextReviewAt === null || new Date(record.nextReviewAt).getTime() <= now.getTime();
}

function matchesFilters(record: VocabRecord, filters: SessionWordFilters): boolean {
  if (filters.topicIds.size > 0 && !record.topicIds.some((id) => filters.topicIds.has(id))) {
    return false;
  }
  if (filters.maxCefr !== null) {
    const recordIndex = CEFR_ORDER.indexOf(record.cefrLevel);
    const maxIndex = CEFR_ORDER.indexOf(filters.maxCefr);
    if (recordIndex > maxIndex) return false;
  }
  return true;
}

function shuffle<T>(items: T[]): T[] {
  const result = [...items];
  for (let i = result.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [result[i], result[j]] = [result[j], result[i]];
  }
  return result;
}

// Due words matching the filters, if any exist; otherwise every matching
// word regardless of due date (never leaves the user with an empty session).
export function selectSessionWords(
  records: VocabRecord[],
  filters: SessionWordFilters,
  now: Date = new Date()
): VocabRecord[] {
  const matching = records.filter((r) => matchesFilters(r, filters));
  const due = matching.filter((r) => isDue(r, now));
  const pool = due.length > 0 ? due : matching;
  const shuffled = shuffle(pool);
  return filters.count === null ? shuffled : shuffled.slice(0, filters.count);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm --prefix apps/web test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/web/src/lib/practiceSession.ts apps/web/src/lib/practiceSession.test.ts
git commit -m "feat(web): add Ôn tập session word-pool selection (due-first, filtered, shuffled)"
```

---

## Task 9: `FlashcardCard` component (diagonal flip, confirmed via visual companion)

**Files:**
- Create: `apps/web/src/components/practice/FlashcardCard.tsx`
- Create: `apps/web/src/components/practice/FlashcardCard.test.tsx`
- Modify: `apps/web/src/styles/bloom.css` (append flashcard CSS — verified no `.fc-*`/`flip-scene`/`flip-card` collision exists yet, safe to add fresh)

**Interfaces:**
- Produces: `<FlashcardCard record onGrade />` where `onGrade: (quality: 1 | 5) => void`. Used by Task 11.
- **Important for Task 11's implementer:** do NOT put a `key={record.id}` on this component when rendering it across a session's word list — remounting it on every word would abruptly reset the rotation counter to 0 instead of continuing the "always spins forward" illusion this component's whole design depends on. Keep the same component instance mounted for the entire session; only its `record` prop should change between words.

The flip mechanics implement the design confirmed live via the brainstorming skill's visual companion: a diagonal hinge (`rotate3d(1, 1, 0, Ndeg)`, not a straight horizontal/vertical axis) where `N` only ever increases by 180 per interaction (tap front → back, tap back's peek area → front, or grade → front) — the card always spins the same rotational direction, two consecutive flips complete a visual 360°.

- [ ] **Step 1: Write the failing test**

Create `apps/web/src/components/practice/FlashcardCard.test.tsx`:

```tsx
import { describe, expect, it, vi } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import { FlashcardCard } from "./FlashcardCard";
import type { VocabRecord } from "@/lib/vocabRecords";

const RECORD: VocabRecord = {
  id: "1",
  headword: "meticulous",
  inputType: "word",
  ipa: "/məˈtɪkjələs/",
  meaning: "tỉ mỉ, cẩn thận",
  examples: ["She is meticulous.", "Second example."],
  personalNotes: "",
  topicIds: [],
  targetLanguage: "english",
  cefrLevel: "c1",
  activeContext: "general",
  createdAt: "2026-01-01T00:00:00.000Z",
  updatedAt: "2026-01-01T00:00:00.000Z",
  nextReviewAt: null,
  sm2Repetitions: 0,
  sm2EaseFactor: 2.5,
  sm2Interval: 1,
  definition: "",
  synonyms: [],
};

describe("FlashcardCard", () => {
  it("shows the headword and IPA on the front, and the meaning + only the first example on the back", () => {
    render(<FlashcardCard record={RECORD} onGrade={vi.fn()} />);
    expect(screen.getByText("meticulous")).toBeInTheDocument();
    expect(screen.getByText("/məˈtɪkjələs/")).toBeInTheDocument();
    expect(screen.getByText("tỉ mỉ, cẩn thận")).toBeInTheDocument();
    expect(screen.getByText('"She is meticulous."')).toBeInTheDocument();
    expect(screen.queryByText('"Second example."')).not.toBeInTheDocument();
  });

  it("rotates by 180 degrees when the card is clicked", () => {
    render(<FlashcardCard record={RECORD} onGrade={vi.fn()} />);
    const card = screen.getByTestId("flashcard-card");
    expect(card).toHaveStyle({ transform: "rotate3d(1,1,0,0deg)" });
    fireEvent.click(card);
    expect(card).toHaveStyle({ transform: "rotate3d(1,1,0,180deg)" });
  });

  it("rotates forward another 180 degrees (never backward) when the back's peek area is clicked, without grading", () => {
    const onGrade = vi.fn();
    render(<FlashcardCard record={RECORD} onGrade={onGrade} />);
    const card = screen.getByTestId("flashcard-card");
    fireEvent.click(card); // front -> back (180)
    fireEvent.click(screen.getByText("tỉ mỉ, cẩn thận")); // peek back to front
    expect(card).toHaveStyle({ transform: "rotate3d(1,1,0,360deg)" });
    expect(onGrade).not.toHaveBeenCalled();
  });

  it("calls onGrade(1) for Chưa hiểu and onGrade(5) for Đã hiểu, rotating forward either way", () => {
    const onGrade = vi.fn();
    render(<FlashcardCard record={RECORD} onGrade={onGrade} />);
    const card = screen.getByTestId("flashcard-card");
    fireEvent.click(card); // -> 180
    fireEvent.click(screen.getByRole("button", { name: "Đã hiểu" }));
    expect(onGrade).toHaveBeenCalledWith(5);
    expect(card).toHaveStyle({ transform: "rotate3d(1,1,0,360deg)" });
  });

  it("calls onGrade(1), not 5, for Chưa hiểu", () => {
    const onGrade = vi.fn();
    render(<FlashcardCard record={RECORD} onGrade={onGrade} />);
    fireEvent.click(screen.getByTestId("flashcard-card")); // -> 180
    fireEvent.click(screen.getByRole("button", { name: "Chưa hiểu" }));
    expect(onGrade).toHaveBeenCalledWith(1);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm --prefix apps/web test`
Expected: FAIL — `./FlashcardCard` does not exist.

- [ ] **Step 3: Implement**

Create `apps/web/src/components/practice/FlashcardCard.tsx`:

```tsx
"use client";

import { useState } from "react";
import type { VocabRecord } from "@/lib/vocabRecords";

interface FlashcardCardProps {
  record: VocabRecord;
  onGrade: (quality: 1 | 5) => void;
}

export function FlashcardCard({ record, onGrade }: FlashcardCardProps) {
  const [rotation, setRotation] = useState(0);
  const showingFront = Math.round(rotation / 180) % 2 === 0;

  function spin() {
    setRotation((r) => r + 180);
  }

  function handleFrontClick() {
    if (showingFront) spin();
  }

  function handlePeekClick(e: React.MouseEvent) {
    e.stopPropagation();
    spin();
  }

  function handleGrade(e: React.MouseEvent, quality: 1 | 5) {
    e.stopPropagation();
    spin();
    onGrade(quality);
  }

  return (
    <div className="fc-scene">
      <div
        className="fc-card"
        data-testid="flashcard-card"
        style={{ transform: `rotate3d(1,1,0,${rotation}deg)` }}
        onClick={handleFrontClick}
      >
        <div className="fc-face">
          <p className="fc-headword">{record.headword}</p>
          {record.ipa && <p className="fc-ipa">{record.ipa}</p>}
          <div className="fc-hint">👆 Chạm vào thẻ để xem đáp án</div>
        </div>
        <div className="fc-face fc-face-back" onClick={handlePeekClick}>
          <p className="fc-meaning">{record.meaning}</p>
          {record.examples[0] && <p className="fc-example">&quot;{record.examples[0]}&quot;</p>}
          <div className="fc-back-hint">↩ Chạm vùng này để xem lại mặt trước</div>
          <div className="fc-grade-row">
            <button type="button" className="fc-grade-no" onClick={(e) => handleGrade(e, 1)}>
              Chưa hiểu
            </button>
            <button type="button" className="fc-grade-yes" onClick={(e) => handleGrade(e, 5)}>
              Đã hiểu
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
```

- [ ] **Step 4: Append the flashcard CSS**

Modify `apps/web/src/styles/bloom.css` — append at the end:

```css

.fc-scene {
  perspective: 1400px;
}

.fc-card {
  position: relative;
  min-height: 280px;
  width: 100%;
  max-width: 460px;
  margin: 0 auto;
  transform-style: preserve-3d;
  transition: transform 0.55s cubic-bezier(0.4, 0.2, 0.2, 1);
  cursor: pointer;
}

.fc-face {
  position: absolute;
  inset: 0;
  backface-visibility: hidden;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 22px;
  box-shadow: 0 24px 56px -28px rgba(120, 70, 90, 0.35);
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 28px;
  text-align: center;
}

.fc-face-back {
  transform: rotate3d(1, 1, 0, 180deg);
  cursor: pointer;
}

.fc-headword {
  font-size: 30px;
  font-weight: 700;
  margin: 0;
}

.fc-ipa {
  margin-top: 6px;
  color: var(--ink-soft);
  font-style: italic;
  font-family: ui-monospace, monospace;
  font-size: 13px;
}

.fc-hint {
  margin-top: 26px;
  color: var(--ink-faint);
  font-size: 12px;
}

.fc-meaning {
  font-size: 17px;
  font-weight: 600;
  margin: 0;
}

.fc-example {
  margin-top: 12px;
  color: var(--ink-soft);
  font-style: italic;
  font-size: 13.5px;
}

.fc-back-hint {
  margin-top: 16px;
  color: var(--ink-faint);
  font-size: 11px;
}

.fc-grade-row {
  display: flex;
  gap: 10px;
  margin-top: 26px;
  width: 100%;
}

.fc-grade-no,
.fc-grade-yes {
  flex: 1;
  padding: 11px 0;
  border-radius: 999px;
  font-weight: 700;
  font-size: 13.5px;
  cursor: pointer;
  font-family: inherit;
}

.fc-grade-no {
  background: var(--danger-bg);
  color: var(--danger);
  border: 1px solid var(--danger);
}

.fc-grade-yes {
  background: var(--accent);
  color: var(--accent-ink);
  border: none;
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `npm --prefix apps/web test`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add apps/web/src/components/practice/FlashcardCard.tsx apps/web/src/components/practice/FlashcardCard.test.tsx apps/web/src/styles/bloom.css
git commit -m "feat(web): add FlashcardCard (diagonal continuous-rotation flip, confirmed via visual companion)"
```

---

## Task 10: `/practice` page — session setup phase

**Files:**
- Create: `apps/web/src/app/(app)/practice/page.tsx`
- Create: `apps/web/src/app/(app)/practice/page.test.tsx`
- Modify: `apps/web/src/styles/bloom.css` (append session-setup CSS)

**Interfaces:**
- Consumes: `useAuthUser` (`@/lib/useAuthUser`), `SignInButton` (`@/components/SignInButton`), `getVocabRecords`/`VocabRecord` (`@/lib/vocabRecords`), `getTopics`/`Topic` (`@/lib/topics`), `TopicFilterPopover` (`@/components/vocab-bank/TopicFilterPopover` — already exists, props `{topics, selectedTopicIds, onApply}`), `selectSessionWords`/`SessionWordFilters` (`@/lib/practiceSession`, Task 8).
- Produces: the `/practice` route, with a `Phase = "setup" | "session" | "result"` state machine — this task only renders the `"setup"` phase; Tasks 11-12 extend this same file to render `"session"`/`"result"`. This task's own `handleStart` already sets `phase` to `"session"` and computes the word list, so later tasks build on real state rather than re-deriving it.

- [ ] **Step 1: Write the failing test**

Create `apps/web/src/app/(app)/practice/page.test.tsx`:

```tsx
import { describe, expect, it, vi } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import PracticePage from "./page";
import { useAuthUser } from "@/lib/useAuthUser";
import { getVocabRecords, type VocabRecord } from "@/lib/vocabRecords";
import { getTopics } from "@/lib/topics";

vi.mock("@/lib/useAuthUser", () => ({ useAuthUser: vi.fn() }));
vi.mock("@/lib/vocabRecords", () => ({ getVocabRecords: vi.fn() }));
vi.mock("@/lib/topics", () => ({ getTopics: vi.fn() }));
vi.mock("@/components/SignInButton", () => ({
  SignInButton: () => <button>Đăng nhập với Google</button>,
}));

function makeRecord(overrides: Partial<VocabRecord>): VocabRecord {
  return {
    id: "id",
    headword: "word",
    inputType: "word",
    ipa: "",
    meaning: "nghĩa",
    examples: ["ví dụ"],
    personalNotes: "",
    topicIds: [],
    targetLanguage: "english",
    cefrLevel: "b1",
    activeContext: "general",
    createdAt: "2026-01-01T00:00:00.000Z",
    updatedAt: "2026-01-01T00:00:00.000Z",
    nextReviewAt: null,
    sm2Repetitions: 0,
    sm2EaseFactor: 2.5,
    sm2Interval: 1,
    definition: "",
    synonyms: [],
    ...overrides,
  };
}

describe("PracticePage (setup phase)", () => {
  it("prompts sign-in when logged out", () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: null, loading: false } as never);
    render(<PracticePage />);
    expect(screen.getByText("Đăng nhập với Google")).toBeInTheDocument();
  });

  it("shows the matching word count and enables Bắt đầu once records load", async () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" }, loading: false } as never);
    vi.mocked(getVocabRecords).mockResolvedValue([makeRecord({ id: "1" }), makeRecord({ id: "2" })]);
    vi.mocked(getTopics).mockResolvedValue([]);

    render(<PracticePage />);

    expect(await screen.findByText("2 từ khớp bộ lọc hiện tại.")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Bắt đầu" })).not.toBeDisabled();
  });

  it("disables Bắt đầu when no word matches the filters", async () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" }, loading: false } as never);
    vi.mocked(getVocabRecords).mockResolvedValue([]);
    vi.mocked(getTopics).mockResolvedValue([]);

    render(<PracticePage />);

    expect(await screen.findByText("0 từ khớp bộ lọc hiện tại.")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Bắt đầu" })).toBeDisabled();
  });

  it("filters the preview count by the selected maximum CEFR level", async () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" }, loading: false } as never);
    vi.mocked(getVocabRecords).mockResolvedValue([
      makeRecord({ id: "1", cefrLevel: "a1" }),
      makeRecord({ id: "2", cefrLevel: "c1" }),
    ]);
    vi.mocked(getTopics).mockResolvedValue([]);

    render(<PracticePage />);
    await screen.findByText("2 từ khớp bộ lọc hiện tại.");

    fireEvent.change(screen.getByDisplayValue("Mọi trình độ"), { target: { value: "a1" } });

    expect(await screen.findByText("1 từ khớp bộ lọc hiện tại.")).toBeInTheDocument();
  });

  it("leaves the setup screen when Bắt đầu is clicked with matching words", async () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" }, loading: false } as never);
    vi.mocked(getVocabRecords).mockResolvedValue([makeRecord({ id: "1" })]);
    vi.mocked(getTopics).mockResolvedValue([]);

    render(<PracticePage />);
    fireEvent.click(await screen.findByRole("button", { name: "Bắt đầu" }));

    await waitFor(() =>
      expect(screen.queryByRole("button", { name: "Bắt đầu" })).not.toBeInTheDocument()
    );
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm --prefix apps/web test`
Expected: FAIL — `./page` does not exist under `practice/`.

- [ ] **Step 3: Implement the setup phase**

Create `apps/web/src/app/(app)/practice/page.tsx`:

```tsx
"use client";

import { useEffect, useState } from "react";
import { useAuthUser } from "@/lib/useAuthUser";
import { SignInButton } from "@/components/SignInButton";
import { getVocabRecords, type VocabRecord } from "@/lib/vocabRecords";
import { getTopics, type Topic } from "@/lib/topics";
import { TopicFilterPopover } from "@/components/vocab-bank/TopicFilterPopover";
import { selectSessionWords, type SessionWordFilters } from "@/lib/practiceSession";

type CefrLevel = VocabRecord["cefrLevel"];
const CEFR_LEVELS: CefrLevel[] = ["a1", "a2", "b1", "b2", "c1", "c2"];
const WORD_COUNT_OPTIONS = [5, 10, 20, null] as const;

type Phase = "setup" | "session" | "result";

export default function PracticePage() {
  const { user, loading: authLoading } = useAuthUser();
  const [records, setRecords] = useState<VocabRecord[] | null>(null);
  const [topics, setTopics] = useState<Topic[]>([]);
  const [loadError, setLoadError] = useState<string | null>(null);

  const [selectedTopicIds, setSelectedTopicIds] = useState<Set<string>>(new Set());
  const [maxCefr, setMaxCefr] = useState<CefrLevel | null>(null);
  const [wordCount, setWordCount] = useState<number | null>(10);

  const [phase, setPhase] = useState<Phase>("setup");

  useEffect(() => {
    if (!user) return;
    setLoadError(null);
    Promise.all([getVocabRecords(user.uid), getTopics(user.uid)])
      .then(([r, t]) => {
        setRecords(r);
        setTopics(t);
      })
      .catch((err: unknown) => setLoadError(err instanceof Error ? err.message : String(err)));
  }, [user]);

  function handleStart() {
    if (!records) return;
    const filters: SessionWordFilters = { topicIds: selectedTopicIds, maxCefr, count: wordCount };
    const words = selectSessionWords(records, filters);
    if (words.length === 0) return;
    setPhase("session");
    // Session-phase state (current word, results-so-far) is wired in Task 11.
  }

  if (authLoading) return <p>Đang tải…</p>;

  if (!user) {
    return (
      <div>
        <h2 className="scr-title">Ôn tập</h2>
        <p className="scr-sub">Đăng nhập để ôn tập.</p>
        <SignInButton />
      </div>
    );
  }

  if (loadError) return <p role="alert">Lỗi: {loadError}</p>;
  if (records === null) return <p>Đang tải từ vựng…</p>;

  if (phase === "setup") {
    const previewWords = selectSessionWords(
      records,
      { topicIds: selectedTopicIds, maxCefr, count: wordCount },
      new Date()
    );

    return (
      <div>
        <h2 className="scr-title">Ôn tập</h2>
        <p className="scr-sub">Chọn bộ lọc rồi bắt đầu phiên ôn tập.</p>
        <div className="practice-filters">
          <TopicFilterPopover
            topics={topics}
            selectedTopicIds={selectedTopicIds}
            onApply={setSelectedTopicIds}
          />
          <select
            value={maxCefr ?? ""}
            onChange={(e) => setMaxCefr((e.target.value || null) as CefrLevel | null)}
          >
            <option value="">Mọi trình độ</option>
            {CEFR_LEVELS.map((level) => (
              <option key={level} value={level}>
                Tối đa {level.toUpperCase()}
              </option>
            ))}
          </select>
          <select
            value={wordCount ?? "all"}
            onChange={(e) => setWordCount(e.target.value === "all" ? null : Number(e.target.value))}
          >
            {WORD_COUNT_OPTIONS.map((count) => (
              <option key={count ?? "all"} value={count ?? "all"}>
                {count === null ? "Tất cả" : `${count} từ`}
              </option>
            ))}
          </select>
        </div>
        <p className="practice-preview-count">{previewWords.length} từ khớp bộ lọc hiện tại.</p>
        <button className="btn-primary" onClick={handleStart} disabled={previewWords.length === 0}>
          Bắt đầu
        </button>
      </div>
    );
  }

  return null; // "session"/"result" phases wired in Tasks 11-12
}
```

- [ ] **Step 4: Append session-setup CSS**

Modify `apps/web/src/styles/bloom.css` — append at the end:

```css

.practice-filters {
  display: flex;
  gap: 10px;
  align-items: center;
  margin-bottom: 16px;
}

.practice-filters select {
  padding: 8px 12px;
  border-radius: 999px;
  border: 1px solid var(--border);
  background: var(--surface-2);
  color: var(--ink);
  font-size: 13px;
}

.practice-preview-count {
  color: var(--ink-soft);
  font-size: 13px;
  margin-bottom: 18px;
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `npm --prefix apps/web test`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add "apps/web/src/app/(app)/practice" apps/web/src/styles/bloom.css
git commit -m "feat(web): add Ôn tập session setup screen (filters, word-pool preview)"
```

---

## Task 11: `/practice` page — session review loop

**Files:**
- Modify: `apps/web/src/app/(app)/practice/page.tsx`
- Modify: `apps/web/src/app/(app)/practice/page.test.tsx`
- Modify: `apps/web/src/styles/bloom.css` (append session progress-bar CSS)

**Interfaces:**
- Consumes: `FlashcardCard` (`@/components/practice/FlashcardCard`, Task 9 — **do not** put a `key` on it across re-renders within the session, per Task 9's note).
- Produces: `interface SessionGradeResult { vocabRecordId: string; quality: 1 | 5 }`, `sessionWords`/`sessionResults` state — Task 12 reads both when the session completes.

- [ ] **Step 1: Write the failing test**

Add this import to `apps/web/src/app/(app)/practice/page.test.tsx` (alongside the existing ones):

```tsx
import { waitFor } from "@testing-library/react";
```

(If `waitFor` is already imported from `@testing-library/react` in this file's existing import line, add it there instead of a separate line — check the file first.)

Add this new `describe` block at the end of the file:

```tsx
describe("PracticePage (session phase)", () => {
  it("shows the current word's flashcard and a progress indicator, advancing on each grade", async () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" }, loading: false } as never);
    vi.mocked(getVocabRecords).mockResolvedValue([
      makeRecord({ id: "1", headword: "first" }),
      makeRecord({ id: "2", headword: "second" }),
    ]);
    vi.mocked(getTopics).mockResolvedValue([]);

    render(<PracticePage />);
    fireEvent.click(await screen.findByRole("button", { name: "Bắt đầu" }));

    expect(await screen.findByText("Từ 1 / 2")).toBeInTheDocument();
    expect(screen.getByText("first")).toBeInTheDocument();

    fireEvent.click(screen.getByTestId("flashcard-card"));
    fireEvent.click(screen.getByRole("button", { name: "Đã hiểu" }));

    expect(await screen.findByText("Từ 2 / 2")).toBeInTheDocument();
    expect(screen.getByText("second")).toBeInTheDocument();
  });

  it("transitions past the session UI once the last word is graded", async () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" }, loading: false } as never);
    vi.mocked(getVocabRecords).mockResolvedValue([makeRecord({ id: "1", headword: "only" })]);
    vi.mocked(getTopics).mockResolvedValue([]);

    render(<PracticePage />);
    fireEvent.click(await screen.findByRole("button", { name: "Bắt đầu" }));
    await screen.findByText("only");

    fireEvent.click(screen.getByTestId("flashcard-card"));
    fireEvent.click(screen.getByRole("button", { name: "Chưa hiểu" }));

    await waitFor(() => expect(screen.queryByTestId("flashcard-card")).not.toBeInTheDocument());
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm --prefix apps/web test`
Expected: FAIL — clicking "Bắt đầu" moves to `phase === "session"`, which currently renders nothing (Task 10 left it as `return null`).

- [ ] **Step 3: Implement the session phase**

Replace `apps/web/src/app/(app)/practice/page.tsx`:

```tsx
"use client";

import { useEffect, useState } from "react";
import { useAuthUser } from "@/lib/useAuthUser";
import { SignInButton } from "@/components/SignInButton";
import { getVocabRecords, type VocabRecord } from "@/lib/vocabRecords";
import { getTopics, type Topic } from "@/lib/topics";
import { TopicFilterPopover } from "@/components/vocab-bank/TopicFilterPopover";
import { selectSessionWords, type SessionWordFilters } from "@/lib/practiceSession";
import { FlashcardCard } from "@/components/practice/FlashcardCard";

type CefrLevel = VocabRecord["cefrLevel"];
const CEFR_LEVELS: CefrLevel[] = ["a1", "a2", "b1", "b2", "c1", "c2"];
const WORD_COUNT_OPTIONS = [5, 10, 20, null] as const;

type Phase = "setup" | "session" | "result";

export interface SessionGradeResult {
  vocabRecordId: string;
  quality: 1 | 5;
}

export default function PracticePage() {
  const { user, loading: authLoading } = useAuthUser();
  const [records, setRecords] = useState<VocabRecord[] | null>(null);
  const [topics, setTopics] = useState<Topic[]>([]);
  const [loadError, setLoadError] = useState<string | null>(null);

  const [selectedTopicIds, setSelectedTopicIds] = useState<Set<string>>(new Set());
  const [maxCefr, setMaxCefr] = useState<CefrLevel | null>(null);
  const [wordCount, setWordCount] = useState<number | null>(10);

  const [phase, setPhase] = useState<Phase>("setup");
  const [sessionWords, setSessionWords] = useState<VocabRecord[]>([]);
  const [currentIndex, setCurrentIndex] = useState(0);
  const [sessionResults, setSessionResults] = useState<SessionGradeResult[]>([]);

  useEffect(() => {
    if (!user) return;
    setLoadError(null);
    Promise.all([getVocabRecords(user.uid), getTopics(user.uid)])
      .then(([r, t]) => {
        setRecords(r);
        setTopics(t);
      })
      .catch((err: unknown) => setLoadError(err instanceof Error ? err.message : String(err)));
  }, [user]);

  function handleStart() {
    if (!records) return;
    const filters: SessionWordFilters = { topicIds: selectedTopicIds, maxCefr, count: wordCount };
    const words = selectSessionWords(records, filters);
    if (words.length === 0) return;
    setSessionWords(words);
    setCurrentIndex(0);
    setSessionResults([]);
    setPhase("session");
  }

  function handleGrade(quality: 1 | 5) {
    const current = sessionWords[currentIndex];
    const nextResults = [...sessionResults, { vocabRecordId: current.id, quality }];
    setSessionResults(nextResults);

    if (currentIndex + 1 < sessionWords.length) {
      setCurrentIndex(currentIndex + 1);
    } else {
      setPhase("result");
      // The batch SM-2 update runs on entering the result phase — wired in Task 12.
    }
  }

  if (authLoading) return <p>Đang tải…</p>;

  if (!user) {
    return (
      <div>
        <h2 className="scr-title">Ôn tập</h2>
        <p className="scr-sub">Đăng nhập để ôn tập.</p>
        <SignInButton />
      </div>
    );
  }

  if (loadError) return <p role="alert">Lỗi: {loadError}</p>;
  if (records === null) return <p>Đang tải từ vựng…</p>;

  if (phase === "setup") {
    const previewWords = selectSessionWords(
      records,
      { topicIds: selectedTopicIds, maxCefr, count: wordCount },
      new Date()
    );

    return (
      <div>
        <h2 className="scr-title">Ôn tập</h2>
        <p className="scr-sub">Chọn bộ lọc rồi bắt đầu phiên ôn tập.</p>
        <div className="practice-filters">
          <TopicFilterPopover
            topics={topics}
            selectedTopicIds={selectedTopicIds}
            onApply={setSelectedTopicIds}
          />
          <select
            value={maxCefr ?? ""}
            onChange={(e) => setMaxCefr((e.target.value || null) as CefrLevel | null)}
          >
            <option value="">Mọi trình độ</option>
            {CEFR_LEVELS.map((level) => (
              <option key={level} value={level}>
                Tối đa {level.toUpperCase()}
              </option>
            ))}
          </select>
          <select
            value={wordCount ?? "all"}
            onChange={(e) => setWordCount(e.target.value === "all" ? null : Number(e.target.value))}
          >
            {WORD_COUNT_OPTIONS.map((count) => (
              <option key={count ?? "all"} value={count ?? "all"}>
                {count === null ? "Tất cả" : `${count} từ`}
              </option>
            ))}
          </select>
        </div>
        <p className="practice-preview-count">{previewWords.length} từ khớp bộ lọc hiện tại.</p>
        <button className="btn-primary" onClick={handleStart} disabled={previewWords.length === 0}>
          Bắt đầu
        </button>
      </div>
    );
  }

  if (phase === "session") {
    const progressPct = Math.round(((currentIndex + 1) / sessionWords.length) * 100);
    return (
      <div>
        <div className="practice-progress-row">
          <span>
            Từ {currentIndex + 1} / {sessionWords.length}
          </span>
          <span>Ôn tập</span>
        </div>
        <div className="practice-progress-track">
          <div className="practice-progress-fill" style={{ width: `${progressPct}%` }} />
        </div>
        <FlashcardCard record={sessionWords[currentIndex]} onGrade={handleGrade} />
      </div>
    );
  }

  return null; // "result" phase wired in Task 12
}
```

- [ ] **Step 4: Append progress-bar CSS**

Modify `apps/web/src/styles/bloom.css` — append at the end:

```css

.practice-progress-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 14px;
  font-size: 12.5px;
  font-weight: 700;
  color: var(--ink-soft);
  max-width: 460px;
  margin-left: auto;
  margin-right: auto;
}

.practice-progress-track {
  height: 6px;
  background: var(--surface);
  border-radius: 999px;
  overflow: hidden;
  border: 1px solid var(--border);
  margin-bottom: 22px;
  max-width: 460px;
  margin-left: auto;
  margin-right: auto;
}

.practice-progress-fill {
  height: 100%;
  background: linear-gradient(90deg, var(--accent), var(--sage));
  border-radius: 999px;
  transition: width 0.35s ease;
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `npm --prefix apps/web test`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add "apps/web/src/app/(app)/practice" apps/web/src/styles/bloom.css
git commit -m "feat(web): wire the Ôn tập session review loop (FlashcardCard, progress, in-memory grading)"
```

---

## Task 12: `/practice` page — session result screen + batch SM-2 write

**Files:**
- Modify: `apps/web/src/app/(app)/practice/page.tsx`
- Modify: `apps/web/src/app/(app)/practice/page.test.tsx`
- Modify: `apps/web/src/styles/bloom.css` (append result-screen CSS)

**Interfaces:**
- Consumes: `computeSm2(record: VocabRecord, quality: 1 | 5, now?: Date): Sm2Fields` (`@/lib/sm2`, Task 7), `updateVocabRecordSm2(uid: string, id: string, fields: Sm2Fields): Promise<void>` (`@/lib/vocabRecords`, Task 7), `SessionGradeResult` (Task 11, same file).
- Produces: nothing further — this is the last task in the plan. The batch SM-2 write fires exactly once per session, at the moment `phase` becomes `"result"`, using one shared `now` for the whole batch (matching Flutter's `session_result_screen.dart`, and satisfying the spec's future-streak-hook note: every result row already carries `vocabRecordId` + `quality`, enough for a later streak feature to read without touching this task's code).

- [ ] **Step 1: Write the failing test**

Modify `apps/web/src/app/(app)/practice/page.test.tsx`. First, update the top-of-file imports and mocks (around lines 2346-2354) — replace:

```tsx
import { describe, expect, it, vi } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import PracticePage from "./page";
import { useAuthUser } from "@/lib/useAuthUser";
import { getVocabRecords, type VocabRecord } from "@/lib/vocabRecords";
import { getTopics } from "@/lib/topics";

vi.mock("@/lib/useAuthUser", () => ({ useAuthUser: vi.fn() }));
vi.mock("@/lib/vocabRecords", () => ({ getVocabRecords: vi.fn() }));
vi.mock("@/lib/topics", () => ({ getTopics: vi.fn() }));
```

with:

```tsx
import { describe, expect, it, vi } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import PracticePage from "./page";
import { useAuthUser } from "@/lib/useAuthUser";
import { getVocabRecords, updateVocabRecordSm2, type VocabRecord } from "@/lib/vocabRecords";
import { getTopics } from "@/lib/topics";
import { computeSm2 } from "@/lib/sm2";

vi.mock("@/lib/useAuthUser", () => ({ useAuthUser: vi.fn() }));
vi.mock("@/lib/vocabRecords", () => ({ getVocabRecords: vi.fn(), updateVocabRecordSm2: vi.fn() }));
vi.mock("@/lib/topics", () => ({ getTopics: vi.fn() }));
vi.mock("@/lib/sm2", () => ({ computeSm2: vi.fn() }));
```

Then append this new `describe` block at the end of the file:

```tsx
describe("PracticePage (result phase)", () => {
  it("shows the percentage and per-word results, and writes one batch SM-2 update per word", async () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" }, loading: false } as never);
    vi.mocked(getVocabRecords).mockResolvedValue([
      makeRecord({ id: "1", headword: "first", meaning: "nghĩa 1" }),
    ]);
    vi.mocked(getTopics).mockResolvedValue([]);
    vi.mocked(computeSm2).mockReturnValue({
      sm2Repetitions: 1,
      sm2EaseFactor: 2.5,
      sm2Interval: 1,
      nextReviewAt: "2026-08-18T00:00:00.000Z",
      updatedAt: "2026-08-17T00:00:00.000Z",
    });
    vi.mocked(updateVocabRecordSm2).mockResolvedValue(undefined);

    render(<PracticePage />);
    fireEvent.click(await screen.findByRole("button", { name: "Bắt đầu" }));
    await screen.findByText("first");

    fireEvent.click(screen.getByTestId("flashcard-card"));
    fireEvent.click(screen.getByRole("button", { name: "Đã hiểu" }));

    expect(await screen.findByText("100%")).toBeInTheDocument();
    expect(screen.getByText("Đúng 1 / 1 từ")).toBeInTheDocument();
    expect(screen.getByText("nghĩa 1")).toBeInTheDocument();

    await waitFor(() =>
      expect(updateVocabRecordSm2).toHaveBeenCalledWith(
        "u1",
        "1",
        expect.objectContaining({ sm2Repetitions: 1 })
      )
    );
    expect(computeSm2).toHaveBeenCalledTimes(1);
  });

  it('returns to the setup phase when "Ôn tập lại" is clicked', async () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" }, loading: false } as never);
    vi.mocked(getVocabRecords).mockResolvedValue([makeRecord({ id: "1", headword: "first" })]);
    vi.mocked(getTopics).mockResolvedValue([]);
    vi.mocked(computeSm2).mockReturnValue({
      sm2Repetitions: 1,
      sm2EaseFactor: 2.5,
      sm2Interval: 1,
      nextReviewAt: "2026-08-18T00:00:00.000Z",
      updatedAt: "2026-08-17T00:00:00.000Z",
    });
    vi.mocked(updateVocabRecordSm2).mockResolvedValue(undefined);

    render(<PracticePage />);
    fireEvent.click(await screen.findByRole("button", { name: "Bắt đầu" }));
    await screen.findByText("first");
    fireEvent.click(screen.getByTestId("flashcard-card"));
    fireEvent.click(screen.getByRole("button", { name: "Đã hiểu" }));

    fireEvent.click(await screen.findByRole("button", { name: "Ôn tập lại" }));
    expect(await screen.findByRole("button", { name: "Bắt đầu" })).toBeInTheDocument();
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm --prefix apps/web test`
Expected: FAIL — `phase === "result"` currently renders nothing (`return null`), so neither "100%" nor the "Ôn tập lại" button exist, and `updateVocabRecordSm2` is never called.

- [ ] **Step 3: Implement the result phase**

Modify `apps/web/src/app/(app)/practice/page.tsx`. First, update the imports at the top — replace:

```tsx
import { useEffect, useState } from "react";
import { useAuthUser } from "@/lib/useAuthUser";
import { SignInButton } from "@/components/SignInButton";
import { getVocabRecords, type VocabRecord } from "@/lib/vocabRecords";
import { getTopics, type Topic } from "@/lib/topics";
import { TopicFilterPopover } from "@/components/vocab-bank/TopicFilterPopover";
import { selectSessionWords, type SessionWordFilters } from "@/lib/practiceSession";
import { FlashcardCard } from "@/components/practice/FlashcardCard";
```

with:

```tsx
import { useEffect, useRef, useState } from "react";
import { useAuthUser } from "@/lib/useAuthUser";
import { SignInButton } from "@/components/SignInButton";
import { getVocabRecords, updateVocabRecordSm2, type VocabRecord } from "@/lib/vocabRecords";
import { getTopics, type Topic } from "@/lib/topics";
import { TopicFilterPopover } from "@/components/vocab-bank/TopicFilterPopover";
import { selectSessionWords, type SessionWordFilters } from "@/lib/practiceSession";
import { FlashcardCard } from "@/components/practice/FlashcardCard";
import { computeSm2 } from "@/lib/sm2";
```

Next, add a ref (right after the existing `sessionResults` state declaration) so the batch write fires exactly once per session:

```tsx
  const [sessionResults, setSessionResults] = useState<SessionGradeResult[]>([]);
  const sm2WrittenRef = useRef(false);
```

In `handleStart`, reset the ref alongside the other session-start resets:

```tsx
  function handleStart() {
    if (!records) return;
    const filters: SessionWordFilters = { topicIds: selectedTopicIds, maxCefr, count: wordCount };
    const words = selectSessionWords(records, filters);
    if (words.length === 0) return;
    setSessionWords(words);
    setCurrentIndex(0);
    setSessionResults([]);
    sm2WrittenRef.current = false;
    setPhase("session");
  }
```

Add a new `useEffect` (right after the existing data-loading `useEffect`) that performs the one-time batch SM-2 write when the session completes:

```tsx
  useEffect(() => {
    if (phase !== "result" || sm2WrittenRef.current || !user) return;
    sm2WrittenRef.current = true;
    const now = new Date();
    for (const result of sessionResults) {
      const record = sessionWords.find((w) => w.id === result.vocabRecordId);
      if (!record) continue;
      const fields = computeSm2(record, result.quality, now);
      updateVocabRecordSm2(user.uid, result.vocabRecordId, fields).catch((err: unknown) => {
        console.error("Failed to save SM-2 result", err);
      });
    }
  }, [phase, sessionResults, sessionWords, user]);
```

Finally, replace the closing `return null; // "result" phase wired in Task 12` with the result screen:

```tsx
  const correctCount = sessionResults.filter((r) => r.quality === 5).length;
  const totalCount = sessionResults.length;
  const percent = totalCount === 0 ? 0 : Math.round((correctCount / totalCount) * 100);

  return (
    <div>
      <h2 className="scr-title">Kết quả ôn tập</h2>
      <div className="practice-result-circle" style={{ ["--pct" as unknown as string]: `${percent}%` }}>
        <span>{percent}%</span>
      </div>
      <p className="practice-result-sub">
        Đúng {correctCount} / {totalCount} từ
      </p>
      <ul className="practice-result-list">
        {sessionResults.map((result) => {
          const record = sessionWords.find((w) => w.id === result.vocabRecordId);
          if (!record) return null;
          return (
            <li
              key={result.vocabRecordId}
              className={result.quality === 5 ? "practice-result-item-ok" : "practice-result-item-no"}
            >
              <span>{result.quality === 5 ? "✔" : "✘"}</span>
              <span className="practice-result-headword">{record.headword}</span>
              <span className="practice-result-meaning">{record.meaning}</span>
            </li>
          );
        })}
      </ul>
      <button className="btn-primary" onClick={() => setPhase("setup")}>
        Ôn tập lại
      </button>
    </div>
  );
}
```

(This last block replaces everything from the `if (phase === "session") { ... }` block's closing `}` through the end of the file — the `if (phase === "session")` block itself is unchanged.)

- [ ] **Step 4: Append result-screen CSS**

Modify `apps/web/src/styles/bloom.css` — append at the end:

```css

.practice-result-circle {
  --pct: 0%;
  width: 140px;
  height: 140px;
  border-radius: 50%;
  margin: 8px auto 24px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 26px;
  font-weight: 800;
  color: var(--ink);
  background: conic-gradient(var(--accent) var(--pct), var(--surface-3) var(--pct));
}

.practice-result-circle span {
  background: var(--surface);
  width: 108px;
  height: 108px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
}

.practice-result-sub {
  text-align: center;
  color: var(--ink-soft);
  margin-bottom: 18px;
}

.practice-result-list {
  list-style: none;
  margin: 0 0 22px;
  padding: 0;
  max-width: 460px;
  margin-left: auto;
  margin-right: auto;
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.practice-result-list li {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 14px;
  border-radius: 14px;
  border: 1px solid var(--border);
  background: var(--surface);
}

.practice-result-item-ok {
  color: var(--success);
}

.practice-result-item-no {
  color: var(--danger);
}

.practice-result-headword {
  font-weight: 700;
  color: var(--ink);
}

.practice-result-meaning {
  color: var(--ink-soft);
  font-size: 13px;
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `npm --prefix apps/web test`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add "apps/web/src/app/(app)/practice" apps/web/src/styles/bloom.css
git commit -m "feat(web): add Ôn tập session result screen with batch SM-2 write"
```

---

## Self-Review

**1. Spec coverage.**

- Tra từ (Lookup) — Vocab-Bank-cache-first check (Task 4), AI fallback + JSON parsing for word/phrase and sentence inputs (Tasks 1, 4), edit-before-save via `EditVocabModal` "create" mode reused from Vocab Bank (Tasks 3, 5), sentence results never saveable — Task 4's UI only renders a save affordance for `WordPhraseResult`, never for `SentenceResult`, matching "giữ nguyên tác này". Covered.
- Ôn tập (Practice/Review) — sidebar rename (Task 6), zero-AI flashcard review (Task 9), diagonal continuous-rotation flip (Task 9, `rotate3d(1,1,0,...)` with a monotonically-increasing rotation counter, per the visual companion's finalized `flashcard-v4-360.html`), due-then-fallback word pool with topic/CEFR/count filters (Task 8), session setup screen (Task 10), session review loop reusing one persistent `FlashcardCard` instance across the whole session (Task 11), batch SM-2 compute + Firestore write at the result screen using one shared `now` (Task 12), and the future-streak hook — every `SessionGradeResult` already carries `vocabRecordId` + `quality`, and the batch-write `useEffect` is the single point a later streak feature would extend. Covered.
- Global Vietnamese-only UI text constraint — checked every user-facing string introduced across all 12 tasks (headers, buttons, labels, empty/error states); none are in English. Covered.

No gaps found.

**2. Placeholder scan.** Searched all 12 tasks for "TBD"/"TODO"/"implement later"/"add appropriate error handling"/"similar to Task N"-style shortcuts. None found — every step has complete, runnable code, including full test bodies and full CSS blocks.

**3. Type consistency.** Traced identifiers across task boundaries:

- `VocabRecord` (Task 2, re-exported from `@/lib/vocabRecords`) is used with the same field names (`headword`, `meaning`, `examples`, `ipa`, `cefrLevel`, `topicIds`, `nextReviewAt`, `sm2Repetitions`, `sm2EaseFactor`, `sm2Interval`, `targetLanguage`) in Tasks 4, 5, 8, 9, 10, 11, 12 — consistent.
- `NewVocabRecord`/`saveVocabRecord` (Task 2) ↔ Task 5's `buildDraftRecord`/`handleSaveNewRecord` — consistent signatures.
- `Sm2Fields`/`computeSm2` (Task 7) ↔ Task 12's `computeSm2(record, result.quality, now)` call and `updateVocabRecordSm2(uid, id, fields)` — parameter order and field names match.
- `SessionWordFilters`/`selectSessionWords` (Task 8) ↔ Task 10's `handleStart`/preview-count call — consistent (`topicIds: Set<string>`, `maxCefr`, `count`).
- `FlashcardCard`'s `onGrade: (quality: 1 | 5) => void` (Task 9) ↔ Task 11's `handleGrade(quality: 1 | 5)` — consistent, and Task 11 never adds a `key` prop to `<FlashcardCard>`, matching Task 9's explicit constraint.
- `SessionGradeResult` (Task 11) ↔ Task 12's `sessionResults.map`/`.filter` usage — consistent (`vocabRecordId`, `quality`).

No mismatches found.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-08-16-react-web-plan3-phase-b-part2-lookup-practice.md`. Two execution options:

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**
