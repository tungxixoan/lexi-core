# Tách `vocab_records` theo ngôn ngữ mục tiêu Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split `users/{uid}/vocab_records` into one Firestore collection per target language (`users/{uid}/vocab_records_{language}`) on both platforms, make `language` a required parameter everywhere vocab records are read/written (no more unfiltered cross-language pools anywhere), and migrate the ~290+ real production records with a one-time manual script.

**Architecture:** Web's `vocabRecords.ts` and Flutter's `VocabRepositoryImpl` both change their target collection path from the flat `vocab_records` to `vocab_records_{language}`, with `language` becoming a required parameter on every function/method that reads or writes records (the 2 that already took it — `getVocabRecordByHeadword`/`getByHeadword`, `existsByHeadword` — just change their internal path). Every call site on both platforms is updated in the SAME task as its library, so the repo compiles at every commit boundary. A standalone Node.js migration script (Firebase Admin SDK, not a Cloud Function) moves the real production data once, after both apps' code lands but before either is deployed.

## Global Constraints

- Collection naming: `users/{uid}/vocab_records_{language}` where `{language}` is the lowercase enum name shared identically between platforms (`vietnamese`, `english`, `chinese`, `korean`, `japanese`).
- `topics` stays a single shared collection, unsplit.
- `language` is a **required** parameter everywhere vocab records are read/written on both platforms — no optional/fan-out-and-merge mode remains. Every consumer (including Dashboard/Tổng quan and Vocab Bank/Ngân hàng từ vựng, previously unfiltered) now scopes to the current `targetLanguage`.
- The migration script does **not** delete the original `vocab_records` collection — left in place as a backup.
- Deploy order (not part of this plan's tasks — a manual step after all tasks land): code first, then migration script, then deploy both Flutter Web and the React web app together.

---

## Task 1: Web — `vocabRecords.ts` + all 13 call sites

**Files:**
- Modify: `apps/web/src/lib/vocabRecords.ts`
- Modify: `apps/web/src/lib/vocabRecords.test.ts`
- Modify: `apps/web/src/components/VocabRecordCount.tsx`
- Modify: `apps/web/src/app/(app)/dashboard/page.tsx`
- Modify: `apps/web/src/app/(app)/vocab-bank/page.tsx`
- Modify: `apps/web/src/app/(app)/practice/page.tsx`
- Modify: `apps/web/src/app/(app)/reading/page.tsx`
- Modify: `apps/web/src/app/(app)/reading/bilingual/page.tsx`
- Modify: `apps/web/src/app/(app)/reading/part5/page.tsx`
- Modify: `apps/web/src/app/(app)/reading/part6/page.tsx`
- Modify: `apps/web/src/app/(app)/reading/part7/page.tsx`
- Modify: `apps/web/src/app/(app)/reading/word-radar/page.tsx`
- Modify: `apps/web/src/app/(app)/listening/page.tsx`
- Modify: `apps/web/src/app/(app)/listening/dictation/page.tsx`
- Modify: `apps/web/src/app/(app)/listening/comprehension/page.tsx`
- Modify: `apps/web/src/app/(app)/lookup/page.tsx`
- Modify: `apps/web/src/components/shared/VocabSuggestionsSection.tsx`

This task changes the library and every one of its 13 call sites together, in one commit — splitting them across tasks would leave the repo non-compiling in between (the signature change breaks every caller simultaneously).

**Interfaces:**
- Consumes: `VocabRecord["targetLanguage"]` (existing type, unchanged) as the type for every new `language` parameter.
- Produces: no other task in this plan depends on web's internals — Task 2 (Flutter) and Task 3 (migration script) are independent of this task's exact code, only of the *collection naming convention* stated in Global Constraints.

- [ ] **Step 1: Update the failing/changed tests**

Read `apps/web/src/lib/vocabRecords.test.ts` in full (already shown above during planning — reproduced here for the exact edits). Every test that currently expects the bare `"vocab_records"` collection path must expect `"vocab_records_english"` instead (since every existing test's fixture record has `targetLanguage: "english"`), and every call to a function that's gaining a `language` parameter must pass `"english"` explicitly. Replace the whole file:

```ts
// apps/web/src/lib/vocabRecords.test.ts
import { describe, expect, it, vi } from "vitest";
import { deleteDoc, doc, getDocs, orderBy, query, setDoc, updateDoc, where } from "firebase/firestore";
import {
  countVocabRecords,
  deleteVocabRecord,
  getVocabRecordByHeadword,
  getVocabRecords,
  saveVocabRecord,
  updateVocabRecord,
  updateVocabRecordSm2,
  type VocabRecord,
} from "./vocabRecords";
import type { Sm2Fields } from "./sm2";

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

vi.mock("./firebase", () => ({
  getFirebaseDb: vi.fn(() => "mock-db"),
}));

const RECORD: VocabRecord = {
  id: "abc",
  headword: "meticulous",
  inputType: "word",
  ipa: "/məˈtɪkjələs/",
  meaning: "tỉ mỉ, cẩn thận",
  examples: ["She reviewed the contract with meticulous attention to detail."],
  personalNotes: "",
  topicIds: ["business"],
  targetLanguage: "english",
  cefrLevel: "c1",
  activeContext: "business",
  createdAt: "2026-08-10T00:00:00.000Z",
  updatedAt: "2026-08-10T00:00:00.000Z",
  nextReviewAt: null,
  sm2Repetitions: 0,
  sm2EaseFactor: 2.5,
  sm2Interval: 1,
  definition: "",
  synonyms: [],
};

describe("countVocabRecords", () => {
  it("returns the number of documents in the user's per-language vocab_records subcollection", async () => {
    vi.mocked(getDocs).mockResolvedValue({ size: 3 } as never);
    const count = await countVocabRecords("user-123", "english");
    expect(count).toBe(3);
  });
});

describe("getVocabRecords", () => {
  it("queries the language-scoped subcollection ordered by createdAt desc and returns the raw docs", async () => {
    vi.mocked(getDocs).mockResolvedValue({
      docs: [{ id: RECORD.id, data: () => RECORD }],
    } as never);

    const records = await getVocabRecords("user-123", "english");

    expect(orderBy).toHaveBeenCalledWith("createdAt", "desc");
    expect(query).toHaveBeenCalledWith("mock-collection-ref", "mock-order-by");
    expect(records).toEqual([RECORD]);
  });

  it("uses the Firestore snapshot document id, not the id field inside the document data", async () => {
    vi.mocked(getDocs).mockResolvedValue({
      docs: [
        {
          id: "real-doc-id",
          data: () => ({ ...RECORD, id: "stale-field-id" }),
        },
      ],
    } as never);

    const records = await getVocabRecords("user-123", "english");

    expect(records[0].id).toBe("real-doc-id");
  });
});

describe("deleteVocabRecord", () => {
  it("deletes the record document by id from the language-scoped collection", async () => {
    await deleteVocabRecord("user-123", "abc", "english");
    expect(doc).toHaveBeenCalledWith("mock-db", "users", "user-123", "vocab_records_english", "abc");
    expect(deleteDoc).toHaveBeenCalledWith("mock-doc-ref");
  });
});

describe("updateVocabRecord", () => {
  it("updates the editable fields plus updatedAt, by document id, in the language-scoped collection", async () => {
    await updateVocabRecord("user-123", "abc", {
      meaning: "nghĩa mới",
      examples: ["ví dụ mới"],
      topicIds: ["business"],
      personalNotes: "ghi chú",
    }, "english");

    expect(doc).toHaveBeenCalledWith("mock-db", "users", "user-123", "vocab_records_english", "abc");
    expect(updateDoc).toHaveBeenCalledWith(
      "mock-doc-ref",
      expect.objectContaining({
        meaning: "nghĩa mới",
        examples: ["ví dụ mới"],
        topicIds: ["business"],
        personalNotes: "ghi chú",
        updatedAt: expect.any(String),
      })
    );
  });
});

describe("getVocabRecordByHeadword", () => {
  it("queries the language-scoped collection by headword only, and returns null when nothing matches", async () => {
    vi.mocked(getDocs).mockResolvedValue({ empty: true, docs: [] } as never);

    const result = await getVocabRecordByHeadword("user-123", "meticulous", "english");

    expect(where).toHaveBeenCalledWith("headword", "==", "meticulous");
    expect(query).toHaveBeenCalledWith("mock-collection-ref", "mock-where");
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
  it("creates a new document in the collection matching the record's own targetLanguage", async () => {
    vi.mocked(doc).mockReturnValue({ id: "new-doc-id" } as never);
    const { id: _omit, ...newRecord } = RECORD; // targetLanguage: "english"

    const newId = await saveVocabRecord("user-123", newRecord);

    expect(doc).toHaveBeenCalledWith("mock-collection-ref");
    expect(setDoc).toHaveBeenCalledWith({ id: "new-doc-id" }, { ...newRecord, id: "new-doc-id" });
    expect(newId).toBe("new-doc-id");
  });
});

describe("updateVocabRecordSm2", () => {
  it("writes exactly the SM-2 fields, by document id, in the language-scoped collection, with no updatedAt override of its own", async () => {
    vi.mocked(doc).mockReturnValue("mock-doc-ref" as never);

    const sm2Fields: Sm2Fields = {
      sm2Repetitions: 3,
      sm2EaseFactor: 2.4,
      sm2Interval: 12,
      nextReviewAt: "2026-08-28T12:00:00.000Z",
      updatedAt: "2026-08-16T12:00:00.000Z",
    };

    await updateVocabRecordSm2("user-123", "abc", sm2Fields, "english");

    expect(doc).toHaveBeenCalledWith("mock-db", "users", "user-123", "vocab_records_english", "abc");
    expect(updateDoc).toHaveBeenCalledWith("mock-doc-ref", sm2Fields);
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd apps/web && npx vitest run src/lib/vocabRecords.test.ts`
Expected: FAIL — every test calls the new required-`language`-arg signatures against the old implementation (compile/type errors under `tsc`, or wrong-args-length at runtime for the untyped mock calls).

- [ ] **Step 3: Implement `vocabRecords.ts`**

Replace the whole file:

```ts
// apps/web/src/lib/vocabRecords.ts
import { collection, deleteDoc, doc, getDocs, orderBy, query, setDoc, updateDoc, where } from "firebase/firestore";
import { getFirebaseDb } from "./firebase";
import type { Sm2Fields } from "./sm2";

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
type TargetLanguage = VocabRecord["targetLanguage"];

function vocabRecordsCol(uid: string, language: TargetLanguage) {
  return collection(getFirebaseDb(), "users", uid, `vocab_records_${language}`);
}

export async function countVocabRecords(uid: string, language: TargetLanguage): Promise<number> {
  const snapshot = await getDocs(vocabRecordsCol(uid, language));
  return snapshot.size;
}

export async function getVocabRecords(uid: string, language: TargetLanguage): Promise<VocabRecord[]> {
  const q = query(vocabRecordsCol(uid, language), orderBy("createdAt", "desc"));
  const snapshot = await getDocs(q);
  return snapshot.docs.map((d) => ({ ...(d.data() as VocabRecord), id: d.id }));
}

export async function deleteVocabRecord(uid: string, id: string, language: TargetLanguage): Promise<void> {
  const ref = doc(getFirebaseDb(), "users", uid, `vocab_records_${language}`, id);
  await deleteDoc(ref);
}

export async function updateVocabRecord(
  uid: string,
  id: string,
  updates: VocabRecordUpdate,
  language: TargetLanguage
): Promise<void> {
  const ref = doc(getFirebaseDb(), "users", uid, `vocab_records_${language}`, id);
  await updateDoc(ref, { ...updates, updatedAt: new Date().toISOString() });
}

export async function getVocabRecordByHeadword(
  uid: string,
  headword: string,
  targetLanguage: TargetLanguage
): Promise<VocabRecord | null> {
  const q = query(vocabRecordsCol(uid, targetLanguage), where("headword", "==", headword));
  const snapshot = await getDocs(q);
  if (snapshot.empty) return null;
  const d = snapshot.docs[0];
  return { ...(d.data() as VocabRecord), id: d.id };
}

export async function saveVocabRecord(uid: string, record: NewVocabRecord): Promise<string> {
  const ref = doc(vocabRecordsCol(uid, record.targetLanguage));
  // Flutter's sync_service.dart caches the raw document body and reads
  // json['id'] from it directly (non-nullable) — the doc must carry its
  // own id field, not rely on the caller reading ref.id separately.
  await setDoc(ref, { ...record, id: ref.id });
  return ref.id;
}

export async function updateVocabRecordSm2(
  uid: string,
  id: string,
  sm2Fields: Sm2Fields,
  language: TargetLanguage
): Promise<void> {
  const ref = doc(getFirebaseDb(), "users", uid, `vocab_records_${language}`, id);
  await updateDoc(ref, { ...sm2Fields });
}
```

(Note: `getVocabRecordByHeadword`'s `where("targetLanguage", "==", targetLanguage)` clause is removed — the collection itself is now already scoped to that language, so the extra `where` is redundant. Kept `targetLanguage` as the parameter name here, matching every existing call site, rather than renaming to `language` — purely cosmetic, avoids an unnecessary rename ripple.)

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd apps/web && npx vitest run src/lib/vocabRecords.test.ts`
Expected: PASS, all tests green.

- [ ] **Step 5: Update every call site**

Read each file below in full before editing (some of these you may already be familiar with from earlier work on this app — verify current line numbers before editing, since other unrelated changes may have shifted them since this plan was written).

**`apps/web/src/components/VocabRecordCount.tsx`** — this file currently has NO settings context at all, only `useAuthUser()`. Add `useSettingsContext()` and thread `settings.targetLanguage` through:

```tsx
"use client";

import { useEffect, useState } from "react";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettingsContext } from "@/lib/SettingsContext";
import { countVocabRecords } from "@/lib/vocabRecords";

export function VocabRecordCount() {
  const { user } = useAuthUser();
  const { settings } = useSettingsContext();
  const [count, setCount] = useState<number | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    setError(null);
    if (!user || !settings) {
      setCount(null);
      return;
    }
    setCount(null);
    countVocabRecords(user.uid, settings.targetLanguage)
      .then(setCount)
      .catch((err: unknown) =>
        setError(err instanceof Error ? err.message : String(err))
      );
  }, [user, settings]);

  if (!user) return null;
  if (error) return <p role="alert">Lỗi đọc Firestore: {error}</p>;
  if (count === null) return <p>Đang tải số từ vựng…</p>;
  return <p>Bạn có {count} từ trong Ngân hàng từ vựng.</p>;
}
```

**`apps/web/src/app/(app)/dashboard/page.tsx`** — find `getVocabRecords(user.uid)` (around line 47, inside the `Promise.all`/fetch effect that already has `settings` in scope for other reasons — verify by reading the file). Change to `getVocabRecords(user.uid, settings.targetLanguage)`.

**`apps/web/src/app/(app)/vocab-bank/page.tsx`** — three changes:
1. Find `getVocabRecords(user.uid)` (around line 41). Change to `getVocabRecords(user.uid, settings.targetLanguage)` — read the file first to confirm `settings` is already in scope at that point (if not, this page needs `useSettingsContext()` added, matching the pattern in `VocabRecordCount.tsx` above).
2. Find `handleDelete`'s `await deleteVocabRecord(user.uid, id);` (around line 97). This function already looks up the record via `records?.find((r) => r.id === selectedId)` earlier in the file (the `selected` variable) — but `handleDelete(id)` receives a possibly-different `id` than `selected.id` in general; read the file to confirm whether `handleDelete` is only ever called with `selected.id` (if so, use `selected!.targetLanguage`) or with an arbitrary id from the list (if so, find that specific record via `records?.find((r) => r.id === id)?.targetLanguage` inside `handleDelete` itself, and guard against not finding it). Pass whichever gives the correct record's language: `await deleteVocabRecord(user.uid, id, language);`.
3. Find `handleUpdate`'s `await updateVocabRecord(user.uid, selected.id, updates);` (around line 107). `selected` is already the found `VocabRecord` object in scope — change to `await updateVocabRecord(user.uid, selected.id, updates, selected.targetLanguage);`.

**`apps/web/src/app/(app)/practice/page.tsx`** — two changes:
1. Find `getVocabRecords(user.uid)` inside the `Promise.all` (around line 60). Change to `getVocabRecords(user.uid, settings.targetLanguage)` — confirm `settings` is already in scope (this page already reads settings for AI-enabled checks and other purposes).
2. Find `updateVocabRecordSm2(user.uid, result.vocabRecordId, fields)` (around line 95). Read the surrounding code to find where `result` or the matching `VocabRecord` is available — the SM-2 write happens per-graded-word after a completed session, so the record (with its `targetLanguage`) should already be resolvable from the session's word list. Pass its `targetLanguage` as the 4th argument.

**`apps/web/src/app/(app)/reading/page.tsx`, `reading/bilingual/page.tsx`, `reading/part5/page.tsx`, `reading/part6/page.tsx`, `reading/part7/page.tsx`, `reading/word-radar/page.tsx`, `listening/page.tsx`, `listening/comprehension/page.tsx`** — each has exactly one `getVocabRecords(user.uid)` call inside a `Promise.all`/fetch effect (confirmed via grep before writing this plan). Each of these pages already reads `useSettingsContext()`/`settings` for other reasons (target language filtering, AI checks, etc. — Word Radar's page, for instance, already filters `records` client-side by `settings.targetLanguage` after fetching everything; with this change it can now delete that client-side filter entirely, since the fetch itself is already scoped). For each file: change `getVocabRecords(user.uid)` to `getVocabRecords(user.uid, settings.targetLanguage)`. For `reading/word-radar/page.tsx` specifically: also find and remove the now-redundant `records.filter((r) => r.targetLanguage === settings.targetLanguage)` client-side filter (search for `knownRecords` in that file) — the fetch is already scoped, so `knownRecords` can just be `records` directly.

**`apps/web/src/app/(app)/listening/dictation/page.tsx`** — two changes:
1. Find `getVocabRecords(user.uid)` (around line 95). Change to `getVocabRecords(user.uid, settings.targetLanguage)`.
2. Find `await updateVocabRecordSm2(user.uid, vocabId, fields);` (around line 231, inside a loop over `item.vocabIds` that already does `const record = (records ?? []).find((r) => r.id === vocabId); if (!record) continue;`). The found `record` is right there — change to `await updateVocabRecordSm2(user.uid, vocabId, fields, record.targetLanguage);`.

**`apps/web/src/app/(app)/lookup/page.tsx`** — 4 changes, all `getVocabRecordByHeadword`/`saveVocabRecord` calls (around lines 77, 144, 171, 178 per this plan's own grep — verify current line numbers by reading the file). `getVocabRecordByHeadword` already takes a `targetLanguage`/language argument at every one of these call sites (no signature change needed there — this function's parameter list didn't change). `saveVocabRecord(user.uid, newRecord)` (line 178) also needs no change — the record itself already carries `targetLanguage`. **This file needs NO edits** — included in this list only so its call sites were explicitly checked and confirmed unaffected, not overlooked. Verify this by reading the file: confirm no call in this file is to a function whose signature actually changed (`getVocabRecords`, `deleteVocabRecord`, `updateVocabRecord`, `updateVocabRecordSm2`, `countVocabRecords`) — if you find one, treat it as a real gap this plan missed and fix it.

**`apps/web/src/components/shared/VocabSuggestionsSection.tsx`** — same as `lookup/page.tsx`: its calls are `getVocabRecordByHeadword` (unchanged signature) and `saveVocabRecord` (unchanged signature). **No edits needed** — verify the same way.

- [ ] **Step 6: Run `npx tsc --noEmit` to confirm every call site compiles**

Run: `cd apps/web && npx tsc --noEmit`
Expected: clean, no errors. If any file still shows an error, you missed a call site or passed the wrong argument — fix before proceeding.

- [ ] **Step 7: Run the full web test suite**

Run: `cd apps/web && npx vitest run`
Expected: all tests pass (every touched page's own test file will need its `getVocabRecords`/`deleteVocabRecord`/`updateVocabRecord`/`updateVocabRecordSm2`/`countVocabRecords` mock assertions updated to expect the new `language` argument — update each test file alongside its page as you go, don't leave this for a separate pass). If any unrelated files fail, re-run just those files in isolation before concluding it's a real regression (this repo has known Windows/jsdom full-suite flakiness).

- [ ] **Step 8: Commit**

```bash
git add apps/web/src/lib/vocabRecords.ts apps/web/src/lib/vocabRecords.test.ts apps/web/src/components/VocabRecordCount.tsx "apps/web/src/app/(app)/dashboard/page.tsx" "apps/web/src/app/(app)/dashboard/page.test.tsx" "apps/web/src/app/(app)/vocab-bank/page.tsx" "apps/web/src/app/(app)/vocab-bank/page.test.tsx" "apps/web/src/app/(app)/practice/page.tsx" "apps/web/src/app/(app)/practice/page.test.tsx" "apps/web/src/app/(app)/reading/page.tsx" "apps/web/src/app/(app)/reading/page.test.tsx" "apps/web/src/app/(app)/reading/bilingual/page.tsx" "apps/web/src/app/(app)/reading/bilingual/page.test.tsx" "apps/web/src/app/(app)/reading/part5/page.tsx" "apps/web/src/app/(app)/reading/part5/page.test.tsx" "apps/web/src/app/(app)/reading/part6/page.tsx" "apps/web/src/app/(app)/reading/part6/page.test.tsx" "apps/web/src/app/(app)/reading/part7/page.tsx" "apps/web/src/app/(app)/reading/part7/page.test.tsx" "apps/web/src/app/(app)/reading/word-radar/page.tsx" "apps/web/src/app/(app)/reading/word-radar/page.test.tsx" "apps/web/src/app/(app)/listening/page.tsx" "apps/web/src/app/(app)/listening/page.test.tsx" "apps/web/src/app/(app)/listening/dictation/page.tsx" "apps/web/src/app/(app)/listening/dictation/page.test.tsx" "apps/web/src/app/(app)/listening/comprehension/page.tsx" "apps/web/src/app/(app)/listening/comprehension/page.test.tsx"
git commit -m "feat(web): split vocab_records into per-language collections"
```

---

## Task 2: Flutter — `VocabRepository`/`VocabRepositoryImpl` + `StatsService` + use cases + all call sites

**Files:**
- Modify: `lib/features/vocabulary/domain/repositories/vocab_repository.dart`
- Modify: `lib/features/vocabulary/data/repositories/vocab_repository_impl.dart`
- Modify: `test/features/vocabulary/data/repositories/vocab_repository_impl_test.dart`
- Modify: `lib/core/services/stats_service.dart`
- Modify: `test/core/services/stats_service_test.dart`
- Modify: `lib/features/practice/domain/use_cases/get_learning_stats_use_case.dart`
- Modify: `lib/features/practice/presentation/providers/notification_notifier.dart`
- Modify: `lib/features/vocabulary/domain/use_cases/get_vocab_list_use_case.dart`
- Modify: `lib/features/vocabulary/domain/use_cases/delete_vocab_use_case.dart`
- Modify: `lib/features/vocabulary/presentation/providers/vocab_bank_provider.dart`
- Modify: `lib/features/vocabulary/presentation/screens/vocab_detail_screen.dart`
- Modify: `lib/features/word_radar/domain/use_cases/find_known_headwords_use_case.dart`
- Modify: `lib/core/di/app_providers.dart`

This task changes the interface, its implementation, and every real call site together, in one commit — same reasoning as Task 1.

**Interfaces:**
- Consumes: `Language` enum (existing, unchanged, `lib/features/dictionary/domain/entities/language.dart`).
- Produces: no other task in this plan depends on Flutter's internals.

- [ ] **Step 1: Write the failing tests**

In `test/features/vocabulary/data/repositories/vocab_repository_impl_test.dart`, read the current file in full first (it already exists from the `2026-08-27-flutter-drop-hive` plan, using `fake_cloud_firestore`). Update every test to pass the record's language explicitly to whichever method now requires it, and update the Firestore-path assertions to expect `vocab_records_{language}` instead of `vocab_records`. Replace the whole file:

```dart
// test/features/vocabulary/data/repositories/vocab_repository_impl_test.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/vocabulary/data/repositories/vocab_repository_impl.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/vocab_record.dart';
import 'package:lexi_core/features/vocabulary/domain/repositories/vocab_repository.dart';

VocabRecord _record({
  required String id,
  String headword = 'test',
  Language language = Language.english,
  CEFRLevel cefr = CEFRLevel.b1,
  List<String> topicIds = const [],
  DateTime? createdAt,
}) =>
    VocabRecord(
      id: id,
      headword: headword,
      inputType: InputType.word,
      ipa: '',
      meaning: 'nghĩa',
      examples: const [],
      personalNotes: '',
      topicIds: topicIds,
      targetLanguage: language,
      cefrLevel: cefr,
      activeContext: AppContext.general,
      createdAt: createdAt ?? DateTime(2026, 1, 1),
      updatedAt: createdAt ?? DateTime(2026, 1, 1),
    );

void main() {
  late FakeFirebaseFirestore firestore;
  late VocabRepositoryImpl repo;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repo = VocabRepositoryImpl(uid: 'u1', firestore: firestore);
  });

  test('save() writes to users/u1/vocab_records_english/{id} for an English record', () async {
    await repo.save(_record(id: 'v1', headword: 'apple', language: Language.english));
    final doc = await firestore
        .collection('users/u1/vocab_records_english')
        .doc('v1')
        .get();
    expect(doc.exists, isTrue);
    expect(doc.data()!['headword'], 'apple');
  });

  test('save() writes a Chinese record to a different collection than an English one', () async {
    await repo.save(_record(id: 'v1', headword: 'apple', language: Language.english));
    await repo.save(_record(id: 'v2', headword: '苹果', language: Language.chinese));
    final englishDocs = await firestore.collection('users/u1/vocab_records_english').get();
    final chineseDocs = await firestore.collection('users/u1/vocab_records_chinese').get();
    expect(englishDocs.docs.map((d) => d.id), ['v1']);
    expect(chineseDocs.docs.map((d) => d.id), ['v2']);
  });

  test('getAll(language:) returns only that language\'s collection, newest first', () async {
    await repo.save(_record(id: 'v1', language: Language.english, createdAt: DateTime(2026, 1, 1)));
    await repo.save(_record(id: 'v2', language: Language.english, createdAt: DateTime(2026, 1, 5)));
    await repo.save(_record(id: 'v3', language: Language.chinese, createdAt: DateTime(2026, 1, 10)));
    final all = await repo.getAll(language: Language.english);
    expect(all.map((r) => r.id).toList(), ['v2', 'v1']);
  });

  test('getAll(language:) filters by topicId within that language', () async {
    await repo.save(_record(id: 'v1', language: Language.english, topicIds: ['travel']));
    await repo.save(_record(id: 'v2', language: Language.english, topicIds: ['business']));
    final all = await repo.getAll(language: Language.english, topicId: 'travel');
    expect(all.map((r) => r.id).toList(), ['v1']);
  });

  test('getAll(language:) filters by maxCefrLevel within that language', () async {
    await repo.save(_record(id: 'v1', language: Language.english, cefr: CEFRLevel.a1));
    await repo.save(_record(id: 'v2', language: Language.english, cefr: CEFRLevel.c2));
    final all = await repo.getAll(language: Language.english, maxCefrLevel: CEFRLevel.b1);
    expect(all.map((r) => r.id).toList(), ['v1']);
  });

  test('getById() with language: finds the record in that language\'s collection', () async {
    await repo.save(_record(id: 'v1', headword: 'apple', language: Language.english));
    expect((await repo.getById('v1', language: Language.english))?.headword, 'apple');
    expect(await repo.getById('missing', language: Language.english), isNull);
  });

  test('getById() with the wrong language does not find a record that exists in a different one', () async {
    await repo.save(_record(id: 'v1', headword: 'apple', language: Language.english));
    expect(await repo.getById('v1', language: Language.chinese), isNull);
  });

  test('update() overwrites the stored record using the record\'s own targetLanguage', () async {
    await repo.save(_record(id: 'v1', headword: 'apple', language: Language.english));
    final updated = _record(id: 'v1', headword: 'banana', language: Language.english);
    await repo.update(updated);
    expect((await repo.getById('v1', language: Language.english))?.headword, 'banana');
  });

  test('delete() with language: removes the record from that language\'s collection', () async {
    await repo.save(_record(id: 'v1', language: Language.english));
    await repo.delete('v1', language: Language.english);
    expect(await repo.getById('v1', language: Language.english), isNull);
  });

  test('existsByHeadword() is case-insensitive and language-scoped', () async {
    await repo.save(_record(id: 'v1', headword: 'Apple', language: Language.english));
    expect(await repo.existsByHeadword('apple', Language.english), isTrue);
    expect(await repo.existsByHeadword('apple', Language.chinese), isFalse);
  });

  test('getByHeadword() returns the matching record case-insensitively', () async {
    await repo.save(_record(id: 'v1', headword: 'Apple', language: Language.english));
    expect((await repo.getByHeadword('apple', Language.english))?.id, 'v1');
    expect(await repo.getByHeadword('nope', Language.english), isNull);
  });

  test('getTopics() seeds the 20 predefined topics into Firestore on first call when empty', () async {
    final topics = await repo.getTopics();
    expect(topics.length, 20);
    final stored = await firestore.collection('users/u1/topics').get();
    expect(stored.docs.length, 20);
  });

  test('getTopics() predefined-first then alphabetical, and does not reseed twice', () async {
    final first = await repo.getTopics();
    expect(first.length, 20);
    await repo.addTopic(Topic(
      id: 'custom1',
      name: 'Aardvarks',
      emoji: '🎯',
      isPredefined: false,
      createdAt: DateTime(2026, 2, 1),
    ));
    final second = await repo.getTopics();
    expect(second.length, 21);
    expect(second.first.isPredefined, isTrue);
    expect(second.last.name, 'Aardvarks');
  });

  test('deleteTopic() reassigns affected words to "other" across EVERY language collection, not just one', () async {
    await repo.getTopics();
    await repo.addTopic(Topic(
      id: 'custom1',
      name: 'Custom',
      emoji: '🎯',
      isPredefined: false,
      createdAt: DateTime(2026, 2, 1),
    ));
    await repo.save(_record(id: 'v1', language: Language.english, topicIds: ['custom1']));
    await repo.save(_record(id: 'v2', language: Language.chinese, topicIds: ['custom1']));
    await repo.deleteTopic('custom1');
    final englishRecord = await repo.getById('v1', language: Language.english);
    final chineseRecord = await repo.getById('v2', language: Language.chinese);
    expect(englishRecord!.topicIds, ['other']);
    expect(chineseRecord!.topicIds, ['other']);
    final topics = await repo.getTopics();
    expect(topics.any((t) => t.id == 'custom1'), isFalse);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/vocabulary/data/repositories/vocab_repository_impl_test.dart`
Expected: FAIL — `getAll`/`getById`/`delete` don't yet accept/require `language:`, `save`/`update` don't yet route by the record's own `targetLanguage` into a per-language collection (compile errors).

- [ ] **Step 3: Update `VocabRepository` (the abstract interface)**

Replace `lib/features/vocabulary/domain/repositories/vocab_repository.dart`'s `getAll`, `getById`, `delete` signatures (the rest of the file is unchanged):

```dart
  /// Returns all records for [language]. Optionally further filtered.
  /// Results are sorted newest-first by [createdAt].
  Future<List<VocabRecord>> getAll({
    required Language language,
    String? topicId,
    InputType? inputType,
    CEFRLevel? maxCefrLevel,
    bool dueOnly = false,
  });

  Future<VocabRecord?> getById(String id, {required Language language});

  Future<void> update(VocabRecord record);

  Future<void> delete(String id, {required Language language});
```

(`update(record)` and `save(record)` keep their existing signatures unchanged — both already receive a full `VocabRecord`, which carries its own `targetLanguage`, so the implementation routes internally without a new parameter.)

- [ ] **Step 4: Implement `VocabRepositoryImpl`**

Replace the whole file:

```dart
// lib/features/vocabulary/data/repositories/vocab_repository_impl.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/cefr_level.dart';
import '../../domain/entities/topic.dart';
import '../../domain/entities/vocab_record.dart';
import '../../domain/repositories/vocab_repository.dart';
import '../../../../features/dictionary/domain/entities/input_type.dart';
import '../../../../features/dictionary/domain/entities/language.dart';

class VocabRepositoryImpl implements VocabRepository {
  VocabRepositoryImpl({required this.uid, FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final String uid;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _vocabCol(Language language) => _firestore
      .collection('users')
      .doc(uid)
      .collection('vocab_records_${language.name}');
  CollectionReference<Map<String, dynamic>> get _topicsCol =>
      _firestore.collection('users').doc(uid).collection('topics');

  @override
  Future<void> save(VocabRecord record) async {
    await _vocabCol(record.targetLanguage).doc(record.id).set(record.toJson());
  }

  @override
  Future<List<VocabRecord>> getAll({
    required Language language,
    String? topicId,
    InputType? inputType,
    CEFRLevel? maxCefrLevel,
    bool dueOnly = false,
  }) async {
    final snapshot = await _vocabCol(language).get();
    var records =
        snapshot.docs.map((d) => VocabRecord.fromJson(d.data())).toList();
    if (topicId != null) {
      records = records.where((r) => r.topicIds.contains(topicId)).toList();
    }
    if (inputType != null) {
      records = records.where((r) => r.inputType == inputType).toList();
    }
    if (maxCefrLevel != null) {
      records = records
          .where((r) => r.cefrLevel.index <= maxCefrLevel.index)
          .toList();
    }
    if (dueOnly) {
      final now = DateTime.now();
      records = records
          .where((r) => r.nextReviewAt == null || r.nextReviewAt!.isBefore(now))
          .toList();
    }
    records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return records;
  }

  @override
  Future<VocabRecord?> getById(String id, {required Language language}) async {
    final doc = await _vocabCol(language).doc(id).get();
    if (!doc.exists) return null;
    return VocabRecord.fromJson(doc.data()!);
  }

  @override
  Future<void> update(VocabRecord record) async {
    await _vocabCol(record.targetLanguage).doc(record.id).set(record.toJson());
  }

  @override
  Future<void> delete(String id, {required Language language}) async {
    await _vocabCol(language).doc(id).delete();
  }

  @override
  Future<bool> existsByHeadword(String headword, Language language) async {
    return await getByHeadword(headword, language) != null;
  }

  @override
  Future<VocabRecord?> getByHeadword(String headword, Language language) async {
    final lc = headword.toLowerCase();
    final snapshot = await _vocabCol(language).get();
    for (final doc in snapshot.docs) {
      final data = doc.data();
      if ((data['headword'] as String).toLowerCase() == lc) {
        return VocabRecord.fromJson(data);
      }
    }
    return null;
  }

  @override
  Future<List<Topic>> getTopics() async {
    var snapshot = await _topicsCol.get();
    if (snapshot.docs.isEmpty) {
      await _seedTopics();
      snapshot = await _topicsCol.get();
    }
    final topics = snapshot.docs.map((d) => Topic.fromJson(d.data())).toList();
    topics.sort((a, b) {
      if (a.isPredefined && !b.isPredefined) return -1;
      if (!a.isPredefined && b.isPredefined) return 1;
      return a.name.compareTo(b.name);
    });
    return topics;
  }

  @override
  Future<void> addTopic(Topic topic) async {
    await _topicsCol.doc(topic.id).set(topic.toJson());
  }

  @override
  Future<void> deleteTopic(String id) async {
    // topics stays a single shared collection across all languages, but
    // vocab_records is now split — a topic could be referenced by records
    // in ANY language's collection, so reassignment must check every one.
    for (final language in Language.values) {
      final all = await getAll(language: language);
      for (final record in all) {
        if (record.topicIds.contains(id)) {
          final newTopicIds = record.topicIds.where((t) => t != id).toList();
          if (newTopicIds.isEmpty) newTopicIds.add('other');
          await update(record.copyWith(
            topicIds: newTopicIds,
            updatedAt: DateTime.now(),
          ));
        }
      }
    }
    await _topicsCol.doc(id).delete();
  }

  Future<void> _seedTopics() async {
    final batch = _firestore.batch();
    for (final topic in Topic.predefined) {
      batch.set(_topicsCol.doc(topic.id), topic.toJson());
    }
    await batch.commit();
  }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/vocabulary/data/repositories/vocab_repository_impl_test.dart`
Expected: PASS, all 15 tests green.

- [ ] **Step 6: Update `StatsService` and `GetLearningStatsUseCase`**

`StatsService.computeStats()` needs a `Language` parameter now (it calls `repository.getAll()`, which requires `language`). Read `lib/core/services/stats_service.dart` in full, then change its `computeStats()` signature and internal call:

```dart
  Future<LearningStats> computeStats(Language language) async {
    final now = DateTime.now();
    final records = await repository.getAll(language: language);
    // ...(rest of the method body — the due/mastered/CEFR-breakdown loop
    // and LearningStats(...) construction — is completely unchanged)...
```

Add `import '../../features/dictionary/domain/entities/language.dart';` to this file if not already present.

Update `lib/features/practice/domain/use_cases/get_learning_stats_use_case.dart`:

```dart
import '../../../../core/services/stats_service.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../entities/learning_stats.dart';

class GetLearningStatsUseCase {
  const GetLearningStatsUseCase(this._statsService);
  final StatsService _statsService;

  Future<LearningStats> execute(Language language) => _statsService.computeStats(language);
}
```

Update `test/core/services/stats_service_test.dart`: every `service.computeStats()` call in that file must become `service.computeStats(Language.english)` (the fake repository's records are all `Language.english` per the test file's own `_record` helper — read the current file to confirm before assuming, then update every call site accordingly).

- [ ] **Step 7: Update `notification_notifier.dart`**

This file's current shape (post the `2026-08-27-flutter-drop-hive` plan's own fix round) fetches `ref.read(vocabRepositoryProvider).getAll()` once inside `reschedule()` and derives both due-count and next-due-date from that single fetch — it does NOT go through `getLearningStatsUseCaseProvider` at all. Its only change for this task is adding the now-required `language:` argument to that one `getAll()` call, sourced from the `settings` value already read two lines above it. Change:

```dart
      final records = await ref.read(vocabRepositoryProvider).getAll();
```

to:

```dart
      final records = await ref.read(vocabRepositoryProvider).getAll(language: settings.targetLanguage);
```

No other line in this file changes.

- [ ] **Step 8: Update `GetVocabListUseCase`, `DeleteVocabUseCase`, `VocabBankNotifier`, `VocabDetailScreen`**

`lib/features/vocabulary/domain/use_cases/get_vocab_list_use_case.dart` — add `required Language language` and pass it through:

```dart
import '../../../dictionary/domain/entities/input_type.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../entities/cefr_level.dart';
import '../entities/vocab_record.dart';
import '../repositories/vocab_repository.dart';

class GetVocabListUseCase {
  const GetVocabListUseCase(this._repo);
  final VocabRepository _repo;

  Future<List<VocabRecord>> execute({
    required Language language,
    String? topicId,
    InputType? inputType,
    CEFRLevel? maxCefrLevel,
    bool dueOnly = false,
  }) =>
      _repo.getAll(
        language: language,
        topicId: topicId,
        inputType: inputType,
        maxCefrLevel: maxCefrLevel,
        dueOnly: dueOnly,
      );
}
```

`lib/features/vocabulary/domain/use_cases/delete_vocab_use_case.dart`:

```dart
import '../../../dictionary/domain/entities/language.dart';
import '../repositories/vocab_repository.dart';

class DeleteVocabUseCase {
  const DeleteVocabUseCase(this._repo);
  final VocabRepository _repo;

  Future<void> execute(String id, {required Language language}) =>
      _repo.delete(id, language: language);
}
```

`lib/features/vocabulary/presentation/providers/vocab_bank_provider.dart` — `VocabBankNotifier` operates on one language at a time (the currently-selected target language, read fresh from settings at each call, since the user could change it while this notifier's provider is still alive — `build()` re-runs automatically when `userSettingsNotifierProvider` changes, since it's `ref.watch`ed, so this notifier naturally re-fetches on a language switch):

```dart
// lib/features/vocabulary/presentation/providers/vocab_bank_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/di/app_providers.dart';
import '../../../dictionary/presentation/providers/user_settings_provider.dart';
import '../../domain/entities/vocab_record.dart';

part 'vocab_bank_provider.g.dart';

@riverpod
class VocabBankNotifier extends _$VocabBankNotifier {
  @override
  Future<List<VocabRecord>> build() {
    final language = ref.watch(userSettingsNotifierProvider).targetLanguage;
    return ref.read(getVocabListUseCaseProvider).execute(language: language);
  }

  Future<void> save(VocabRecord record) async {
    await ref.read(saveVocabUseCaseProvider).execute(record);
    ref.invalidateSelf();
  }

  Future<void> updateRecord(VocabRecord record) async {
    await ref.read(updateVocabUseCaseProvider).execute(record);
    ref.invalidateSelf();
  }

  Future<void> delete(String id) async {
    final language = ref.read(userSettingsNotifierProvider).targetLanguage;
    await ref.read(deleteVocabUseCaseProvider).execute(id, language: language);
    ref.invalidateSelf();
  }
}

/// Simple provider that returns the vocab list data synchronously.
/// Returns an empty list when loading or on error.
@riverpod
List<VocabRecord> vocabBank(Ref ref) {
  final asyncValue = ref.watch(vocabBankNotifierProvider);
  return asyncValue.when(
    data: (data) => data,
    loading: () => <VocabRecord>[],
    error: (_, __) => <VocabRecord>[],
  );
}
```

`lib/features/vocabulary/presentation/screens/vocab_detail_screen.dart` — read the file in full first. This screen is reached via `/vocab/:id` (no language in the route), navigated to only from `vocab_bank_screen.dart` and `word_radar_screen.dart`, both of which only ever show/link records already scoped to the current target language — so this screen can safely source `language` the same way `VocabBankNotifier` does, from `ref.read(userSettingsNotifierProvider).targetLanguage`, rather than requiring a route change. Find its `getById(widget.id)` call and change to `getById(widget.id, language: ref.read(userSettingsNotifierProvider).targetLanguage)` (adjust to `ref.watch` vs `ref.read` matching whatever pattern the surrounding method already uses for other provider reads in this file). Find its `vocabBankNotifierProvider.notifier).delete(widget.id)` call — `VocabBankNotifier.delete()`'s signature above already sources `language` internally, so this call site itself needs no change.

- [ ] **Step 9: `find_known_headwords_use_case.dart` — no change needed, verify only**

`lib/features/word_radar/domain/use_cases/find_known_headwords_use_case.dart` already calls `_repo.getAll(language: language)` (its own `execute()` already requires `language` as a named parameter and passes it straight through by name) — this already matches `VocabRepository.getAll`'s new signature exactly, since Dart named-parameter call sites don't depend on declaration order. Read the file to confirm this is still true (nothing else in this plan touches it), and move on with no edit.

- [ ] **Step 10: Update `app_providers.dart`**

Read `lib/core/di/app_providers.dart` in full. Find `learningStatsProvider` (currently `Future<LearningStats> learningStats(ref) => ref.watch(statsServiceProvider).computeStats();` per the drop-Hive plan's final state) and update it to pass the current target language:

```dart
@riverpod
Future<LearningStats> learningStats(LearningStatsRef ref) =>
    ref.watch(statsServiceProvider).computeStats(
      ref.watch(userSettingsNotifierProvider).targetLanguage,
    );
```

Check every other provider in this file that constructs or calls something touching `VocabRepository`/`GetVocabListUseCase`/`GetLearningStatsUseCase` for any other now-broken call needing a `language` argument — this file is the central DI wiring point, so it's the most likely place for a missed call site to surface as a compile error.

- [ ] **Step 11: Run `flutter analyze` and fix every remaining call site**

Run: `flutter analyze`
Expected initially: errors at every remaining call site this task's steps didn't already cover explicitly (this plan's own exploration found the ones listed above, but a full-project `flutter analyze` is the authoritative check — don't stop at the files this plan named if analyze finds more). Fix each one the same way: source `language` from `ref.read/watch(userSettingsNotifierProvider).targetLanguage` if no more specific record/language value is already in scope at that exact call site, or from a specific record's own `targetLanguage` if one is already loaded there. Repeat until `flutter analyze` is clean.

- [ ] **Step 12: Run the full Flutter test suite**

Run: `flutter test`
Expected: all tests pass. Any test file for a screen/provider touched in this task needs its own mocks/fakes updated to match the new required `language` arguments — update each alongside its source file.

- [ ] **Step 13: Commit**

```bash
git add lib/features/vocabulary/domain/repositories/vocab_repository.dart lib/features/vocabulary/data/repositories/vocab_repository_impl.dart test/features/vocabulary/data/repositories/vocab_repository_impl_test.dart lib/core/services/stats_service.dart test/core/services/stats_service_test.dart lib/features/practice/domain/use_cases/get_learning_stats_use_case.dart lib/features/practice/presentation/providers/notification_notifier.dart lib/features/vocabulary/domain/use_cases/get_vocab_list_use_case.dart lib/features/vocabulary/domain/use_cases/delete_vocab_use_case.dart lib/features/vocabulary/presentation/providers/vocab_bank_provider.dart lib/features/vocabulary/presentation/providers/vocab_bank_provider.g.dart lib/features/vocabulary/presentation/screens/vocab_detail_screen.dart lib/features/word_radar/domain/use_cases/find_known_headwords_use_case.dart lib/core/di/app_providers.dart lib/core/di/app_providers.g.dart
git commit -m "feat: split vocab_records into per-language collections on Flutter"
```

(This `git add` list is the set of files this plan's own exploration identified — if Step 11's `flutter analyze` pass found and fixed additional files, add those too before committing, so the commit captures the whole working change set.)

---

## Task 3: Migration script for real production data

**Files:**
- Create: `scripts/migrate-vocab-records-per-language.js`
- Create: `scripts/migrate-vocab-records-per-language.test.js` (or, if this repo's existing script/test conventions differ, check `scripts/` for any existing precedent before choosing a test runner/location — none is known to exist yet as of this plan's writing, so Node's built-in `node:test` + `node:assert` is the default choice, requiring no new dependency)

**Interfaces:**
- Consumes: the collection-naming convention from this plan's Global Constraints (`vocab_records_{language}`) — no code-level dependency on Task 1 or Task 2's actual implementations, since this is a standalone script using `firebase-admin` directly, not either app's library code.
- Produces: nothing consumed by other tasks — this is the last task, run manually after Tasks 1-2 are committed, as a manual production-migration step outside this plan's own task-by-task test cycle (though the script itself is developed test-first, per the steps below).

- [ ] **Step 1: Write the failing test**

Use `fake_cloud_firestore`-equivalent for Node — check `package.json` (repo root, if one exists for scripts) or `functions/package.json` for any existing Firestore-emulator-testing precedent; if none exists, use the Firebase Local Emulator Suite's Firestore emulator directly (already used by other parts of this project per `firebase-basics`/`firebase-firestore` conventions) rather than adding a new mocking dependency for a one-off script. Structure the script as an exported, testable function taking an already-initialized `firestore` instance (a `Firestore` from `firebase-admin`, or the emulator's equivalent), so the test can inject a test instance instead of hitting real production data:

```js
// scripts/migrate-vocab-records-per-language.test.js
const test = require("node:test");
const assert = require("node:assert/strict");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { migrateVocabRecords } = require("./migrate-vocab-records-per-language");

// Run against the Firestore emulator — start it first with:
//   firebase emulators:start --only firestore
// and set FIRESTORE_EMULATOR_HOST=localhost:8080 (or whatever port the
// emulator config uses) in the environment before running this test.

test("migrates each user's records into their own per-language collection, keyed by each record's targetLanguage", async () => {
  const app = initializeApp({ projectId: "test-migration" });
  const db = getFirestore(app);

  await db.collection("users/u1/vocab_records").doc("v1").set({
    id: "v1",
    headword: "apple",
    targetLanguage: "english",
  });
  await db.collection("users/u1/vocab_records").doc("v2").set({
    id: "v2",
    headword: "苹果",
    targetLanguage: "chinese",
  });

  const result = await migrateVocabRecords(db);

  const englishDocs = await db.collection("users/u1/vocab_records_english").get();
  const chineseDocs = await db.collection("users/u1/vocab_records_chinese").get();
  assert.equal(englishDocs.docs.length, 1);
  assert.equal(englishDocs.docs[0].data().headword, "apple");
  assert.equal(chineseDocs.docs.length, 1);
  assert.equal(chineseDocs.docs[0].data().headword, "苹果");
  assert.deepEqual(result, { migrated: 2, skipped: 0, users: 1 });
});

test("leaves the original vocab_records collection untouched (not deleted)", async () => {
  const app = initializeApp({ projectId: "test-migration-2" }, "app2");
  const db = getFirestore(app);

  await db.collection("users/u2/vocab_records").doc("v1").set({
    id: "v1",
    headword: "hello",
    targetLanguage: "english",
  });

  await migrateVocabRecords(db);

  const originalDocs = await db.collection("users/u2/vocab_records").get();
  assert.equal(originalDocs.docs.length, 1);
});

test("flags a record with a missing or invalid targetLanguage instead of silently dropping or guessing", async () => {
  const app = initializeApp({ projectId: "test-migration-3" }, "app3");
  const db = getFirestore(app);

  await db.collection("users/u3/vocab_records").doc("bad1").set({
    id: "bad1",
    headword: "mystery",
    // no targetLanguage field at all
  });

  const result = await migrateVocabRecords(db);

  assert.equal(result.skipped, 1);
  assert.equal(result.migrated, 0);
  const englishDocs = await db.collection("users/u3/vocab_records_english").get();
  assert.equal(englishDocs.docs.length, 0);
});

test("migrates every user found under the top-level users collection, not just one", async () => {
  const app = initializeApp({ projectId: "test-migration-4" }, "app4");
  const db = getFirestore(app);

  await db.collection("users/u4/vocab_records").doc("v1").set({
    id: "v1",
    headword: "one",
    targetLanguage: "english",
  });
  await db.collection("users/u5/vocab_records").doc("v1").set({
    id: "v1",
    headword: "two",
    targetLanguage: "vietnamese",
  });

  const result = await migrateVocabRecords(db);

  assert.equal(result.users, 2);
  assert.equal(result.migrated, 2);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node --test scripts/migrate-vocab-records-per-language.test.js` (against a running Firestore emulator — start it first: `firebase emulators:start --only firestore`)
Expected: FAIL — `migrate-vocab-records-per-language.js` doesn't exist yet.

- [ ] **Step 3: Implement the migration script**

```js
// scripts/migrate-vocab-records-per-language.js
const VALID_LANGUAGES = ["vietnamese", "english", "chinese", "korean", "japanese"];

/**
 * One-time migration: copies every document in each user's flat
 * `vocab_records` subcollection into a new per-language subcollection
 * (`vocab_records_{targetLanguage}`), keyed by each document's own
 * `targetLanguage` field. Does NOT delete the original `vocab_records`
 * collection — left in place as a backup, removed manually later once
 * both apps are confirmed working against the new collections.
 *
 * A record with a missing or invalid `targetLanguage` is skipped and
 * counted, never silently dropped or guessed into a default language.
 *
 * @param {import("firebase-admin/firestore").Firestore} db
 * @returns {Promise<{migrated: number, skipped: number, users: number}>}
 */
async function migrateVocabRecords(db) {
  const usersSnapshot = await db.collection("users").get();
  let migrated = 0;
  let skipped = 0;

  for (const userDoc of usersSnapshot.docs) {
    const uid = userDoc.id;
    const vocabSnapshot = await db.collection(`users/${uid}/vocab_records`).get();
    if (vocabSnapshot.empty) continue;

    let batch = db.batch();
    let batchCount = 0;

    for (const recordDoc of vocabSnapshot.docs) {
      const data = recordDoc.data();
      const language = data.targetLanguage;
      if (!VALID_LANGUAGES.includes(language)) {
        console.warn(
          `SKIPPED: users/${uid}/vocab_records/${recordDoc.id} has ` +
            `missing/invalid targetLanguage ("${language}") — needs manual review.`
        );
        skipped++;
        continue;
      }
      const targetRef = db.collection(`users/${uid}/vocab_records_${language}`).doc(recordDoc.id);
      batch.set(targetRef, data);
      migrated++;
      batchCount++;
      if (batchCount === 500) {
        await batch.commit();
        batch = db.batch();
        batchCount = 0;
      }
    }

    if (batchCount > 0) await batch.commit();
  }

  console.log(`Migration complete: ${migrated} record(s) migrated, ${skipped} skipped, ${usersSnapshot.docs.length} user(s) processed.`);
  return { migrated, skipped, users: usersSnapshot.docs.length };
}

module.exports = { migrateVocabRecords };

// Run directly (not imported as a module) against real production
// Firestore: `node scripts/migrate-vocab-records-per-language.js`
// Requires GOOGLE_APPLICATION_CREDENTIALS pointing at a service account
// key with Firestore access for the `lexi-core` project, or running
// from an environment already authenticated via `gcloud auth application-default login`.
if (require.main === module) {
  const { initializeApp } = require("firebase-admin/app");
  const { getFirestore } = require("firebase-admin/firestore");
  const app = initializeApp();
  const db = getFirestore(app);
  migrateVocabRecords(db)
    .then(() => process.exit(0))
    .catch((err) => {
      console.error("Migration failed:", err);
      process.exit(1);
    });
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `node --test scripts/migrate-vocab-records-per-language.test.js` (Firestore emulator still running)
Expected: PASS, 4/4.

- [ ] **Step 5: Commit**

```bash
git add scripts/migrate-vocab-records-per-language.js scripts/migrate-vocab-records-per-language.test.js
git commit -m "feat: add vocab_records per-language migration script"
```

**Note — running this script against real production data is a manual, deliberate step outside this plan's task-by-task execution**, per the spec's deploy-sequencing decision: run it only after Tasks 1-2's code has landed (not yet deployed), and before deploying either app. Do not run it against production as part of this plan's automated execution — surface it to the user as the next manual action once all 3 tasks are committed and reviewed.
