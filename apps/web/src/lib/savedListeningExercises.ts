import { collection, doc, getDocs, query, setDoc, where } from "firebase/firestore";
import { getFirebaseDb } from "./firebase";
import type { DictationItem, DictationDifficulty } from "./dictation";
import type { TargetLanguage } from "./languages";

export interface DictationFilters {
  difficulty: DictationDifficulty;
}

// A parallel, independent module to savedReadingExercises.ts — deliberately
// not a member of that file's SavedReadingExercise union, since a dictation
// item's shape has nothing structurally in common with a reading passage
// (no topic/volume filter, no "passage" to speak of, just one sentence).
export interface SavedListeningExercise {
  id: string;
  type: "dictation";
  item: DictationItem;
  generationFilters: DictationFilters;
  targetLanguage: TargetLanguage;
  createdAt: string;
}

function listeningExercisesCol(uid: string) {
  return collection(getFirebaseDb(), "users", uid, "listening_exercises");
}

export async function saveListeningExercise(
  uid: string,
  item: DictationItem,
  generationFilters: DictationFilters,
  targetLanguage: TargetLanguage
): Promise<string> {
  const ref = doc(listeningExercisesCol(uid));
  // Carries its own id field, matching every other save*Exercise function in
  // this app — see savedReadingExercises.ts's saveReadingExercise for why.
  const record = {
    type: "dictation" as const,
    item,
    generationFilters,
    targetLanguage,
    createdAt: new Date().toISOString(),
  };
  await setDoc(ref, { ...record, id: ref.id });
  return ref.id;
}

export async function getRandomSavedListeningExercise(
  uid: string,
  targetLanguage: TargetLanguage,
  filters: DictationFilters,
  excludeId?: string
): Promise<SavedListeningExercise | null> {
  const q = query(listeningExercisesCol(uid), where("targetLanguage", "==", targetLanguage));
  const snapshot = await getDocs(q);
  const candidates: SavedListeningExercise[] = [];
  for (const d of snapshot.docs) {
    const ex = { ...(d.data() as SavedListeningExercise), id: d.id };
    if (ex.id === excludeId) continue;
    if (ex.generationFilters.difficulty !== filters.difficulty) continue;
    candidates.push(ex);
  }
  if (candidates.length === 0) return null;
  return candidates[Math.floor(Math.random() * candidates.length)];
}
