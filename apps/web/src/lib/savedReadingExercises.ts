import { collection, doc, getDocs, query, setDoc, where } from "firebase/firestore";
import { getFirebaseDb } from "./firebase";
import { CEFR_ORDER } from "./practiceSession";
import type { ReadingPassage } from "./readingPassage";
import type { VocabRecord } from "./vocabRecords";
import type { TargetLanguage } from "./languages";

export interface BilingualFilters {
  topicIds: string[];
  maxCefr: VocabRecord["cefrLevel"] | null;
  wordCount: number | null; // null = "Tất cả" was selected at generation time
}

// Part 5/6/7 all share this same shape — one topic/context filter plus a
// TOEIC-specific difficulty tier, unrelated to CEFR and unrelated to the
// user's own Vocab Bank. Defined here (not in a per-type file) since it's
// genuinely one shared shape, not three coincidentally-similar ones.
export interface ToeicFilters {
  appContext: string;
  volumes: string[]; // empty = "all volumes" — mirrors Flutter's own default
}

// Each variant's own file (part5.ts, part6.ts, part7.ts, ...) owns its
// `passage` shape; this module only needs to know the discriminant and the
// two filter shapes that exist across all current and near-future types.
export type SavedReadingExercise =
  | {
      id: string;
      type: "bilingual";
      passage: ReadingPassage;
      generationFilters: BilingualFilters;
      targetLanguage: TargetLanguage;
      createdAt: string;
    }
  | {
      id: string;
      type: "part5";
      // Deliberately untyped as a specific Part5Set here — this module must
      // not depend on part5.ts (a sibling domain module), only on the shape
      // discriminant. Callers get full type safety via the generic
      // functions below, which infer the real passage/filter types from
      // the `type` argument at the call site.
      passage: unknown;
      generationFilters: ToeicFilters;
      targetLanguage: TargetLanguage;
      createdAt: string;
    };

type FiltersFor<T extends SavedReadingExercise["type"]> = Extract<SavedReadingExercise, { type: T }>["generationFilters"];
type PassageFor<T extends SavedReadingExercise["type"]> = Extract<SavedReadingExercise, { type: T }>["passage"];

function readingExercisesCol(uid: string) {
  return collection(getFirebaseDb(), "users", uid, "reading_exercises");
}

export async function saveReadingExercise<T extends SavedReadingExercise["type"]>(
  uid: string,
  type: T,
  passage: PassageFor<T>,
  generationFilters: FiltersFor<T>,
  targetLanguage: TargetLanguage
): Promise<string> {
  const ref = doc(readingExercisesCol(uid));
  // Carries its own id field, matching vocabRecords.ts's saveVocabRecord —
  // a doc that only relies on the caller reading ref.id separately breaks
  // any future Flutter Hive-cache sync that reads json['id'] directly.
  const record = {
    type,
    passage,
    generationFilters,
    targetLanguage,
    createdAt: new Date().toISOString(),
  };
  await setDoc(ref, { ...record, id: ref.id });
  return ref.id;
}

function matchesBilingual(
  exercise: Extract<SavedReadingExercise, { type: "bilingual" }>,
  filters: BilingualFilters
): boolean {
  if (filters.topicIds.length > 0) {
    const overlaps = exercise.generationFilters.topicIds.some((id) => filters.topicIds.includes(id));
    if (!overlaps) return false;
  }
  if (filters.maxCefr !== null) {
    if (exercise.generationFilters.maxCefr === null) return false;
    const savedIndex = CEFR_ORDER.indexOf(exercise.generationFilters.maxCefr);
    const maxIndex = CEFR_ORDER.indexOf(filters.maxCefr);
    if (savedIndex > maxIndex) return false;
  }
  if (exercise.generationFilters.wordCount !== filters.wordCount) return false;
  return true;
}

function matchesToeic(exercise: { generationFilters: ToeicFilters }, filters: ToeicFilters): boolean {
  if (exercise.generationFilters.appContext !== filters.appContext) return false;
  if (filters.volumes.length > 0 && exercise.generationFilters.volumes.length > 0) {
    const overlaps = exercise.generationFilters.volumes.some((v) => filters.volumes.includes(v));
    if (!overlaps) return false;
  }
  return true;
}

export async function getRandomSavedExercise<T extends SavedReadingExercise["type"]>(
  uid: string,
  targetLanguage: TargetLanguage,
  type: T,
  filters: FiltersFor<T>,
  excludeId?: string
): Promise<Extract<SavedReadingExercise, { type: T }> | null> {
  const q = query(readingExercisesCol(uid), where("targetLanguage", "==", targetLanguage));
  const snapshot = await getDocs(q);
  const candidates: Extract<SavedReadingExercise, { type: T }>[] = [];
  for (const d of snapshot.docs) {
    const ex = { ...(d.data() as SavedReadingExercise), id: d.id };
    if (ex.id === excludeId) continue;
    if (ex.type !== type) continue;
    // Safe: `type` narrows `ex` to the matching union member at runtime,
    // even though TypeScript can't express that narrowing through a
    // generic `T` — `filters`' own generic type already forces the caller
    // to pass the matching filter shape for this exact `type`.
    const matches =
      ex.type === "bilingual" ? matchesBilingual(ex, filters as BilingualFilters) : matchesToeic(ex, filters as ToeicFilters);
    if (matches) candidates.push(ex as Extract<SavedReadingExercise, { type: T }>);
  }
  if (candidates.length === 0) return null;
  return candidates[Math.floor(Math.random() * candidates.length)];
}

export async function getAllUsedVocabIds(uid: string): Promise<Set<string>> {
  const snapshot = await getDocs(readingExercisesCol(uid));
  const ids = new Set<string>();
  for (const d of snapshot.docs) {
    const data = d.data() as SavedReadingExercise;
    // A non-bilingual document (part5/6/7/Nghe) sharing this same
    // collection has no passage.vocabIds in this shape — skip it rather
    // than throw.
    if (data.type !== "bilingual") continue;
    for (const id of data.passage.vocabIds) ids.add(id);
  }
  return ids;
}

// AI-generation preference, not saved-exercise matching: words never used in
// any saved exercise are preferred over words that have been, so repeated
// generation doesn't keep reusing the same easy-to-match words.
export function prioritizeUnusedWords(words: VocabRecord[], usedVocabIds: Set<string>): VocabRecord[] {
  const unused = words.filter((w) => !usedVocabIds.has(w.id));
  const used = words.filter((w) => usedVocabIds.has(w.id));
  return [...unused, ...used];
}
