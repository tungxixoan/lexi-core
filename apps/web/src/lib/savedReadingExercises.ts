import { collection, doc, getDocs, query, setDoc, where } from "firebase/firestore";
import { getFirebaseDb } from "./firebase";
import { CEFR_ORDER } from "./practiceSession";
import type { ReadingPassage } from "./readingPassage";
import type { VocabRecord } from "./vocabRecords";
import type { TargetLanguage } from "./languages";

export interface SavedExerciseFilters {
  topicIds: string[];
  maxCefr: VocabRecord["cefrLevel"] | null;
  wordCount: number | null; // null = "Tất cả" was selected at generation time
}

export interface SavedReadingExercise {
  id: string;
  type: "bilingual"; // discriminant for future Part5/6/7/Nghe types
  passage: ReadingPassage;
  generationFilters: SavedExerciseFilters;
  targetLanguage: TargetLanguage;
  createdAt: string;
}

function readingExercisesCol(uid: string) {
  return collection(getFirebaseDb(), "users", uid, "reading_exercises");
}

export async function saveReadingExercise(
  uid: string,
  passage: ReadingPassage,
  generationFilters: SavedExerciseFilters,
  targetLanguage: TargetLanguage
): Promise<string> {
  const ref = doc(readingExercisesCol(uid));
  // Carries its own id field, matching vocabRecords.ts's saveVocabRecord —
  // a doc that only relies on the caller reading ref.id separately breaks
  // any future Flutter Hive-cache sync that reads json['id'] directly.
  const record: Omit<SavedReadingExercise, "id"> = {
    type: "bilingual",
    passage,
    generationFilters,
    targetLanguage,
    createdAt: new Date().toISOString(),
  };
  await setDoc(ref, { ...record, id: ref.id });
  return ref.id;
}

function matchesFilters(exercise: SavedReadingExercise, filters: SavedExerciseFilters): boolean {
  // Pilot for one type only — hard-coding "bilingual" here (rather than a
  // generic parameter) is deliberate; a future Part5/6/7/Nghe type gets its
  // own read path, not a parameterized version of this one.
  if (exercise.type !== "bilingual") return false;
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

export async function getRandomSavedExercise(
  uid: string,
  targetLanguage: TargetLanguage,
  filters: SavedExerciseFilters,
  excludeId?: string
): Promise<SavedReadingExercise | null> {
  const q = query(readingExercisesCol(uid), where("targetLanguage", "==", targetLanguage));
  const snapshot = await getDocs(q);
  const candidates = snapshot.docs
    .map((d) => ({ ...(d.data() as SavedReadingExercise), id: d.id }))
    .filter((ex) => ex.id !== excludeId && matchesFilters(ex, filters));
  if (candidates.length === 0) return null;
  return candidates[Math.floor(Math.random() * candidates.length)];
}

export async function getAllUsedVocabIds(uid: string): Promise<Set<string>> {
  const snapshot = await getDocs(readingExercisesCol(uid));
  const ids = new Set<string>();
  for (const d of snapshot.docs) {
    const data = d.data() as SavedReadingExercise;
    // A future foreign-typed document (Part5/6/7/Nghe) sharing this same
    // collection won't have passage.vocabIds in this shape — skip it rather
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
